require "net/http"
require "json"

module Github
  class IssuesClient
    MAX_REDIRECTS = 3

    def initialize(token: ENV["GITHUB_TOKEN"])
      @token = token
    end

    def open_issues(owner:, repo:, labels: Issue::DEFAULT_LABELS, fetch_all: false, etags: {})
      raise "GITHUB_TOKEN is missing" if token.blank?

      result_etags = {}
      not_modified_labels = []
      any_modified = false

      if fetch_all
        etag = etags["all"]
        result = issues_for_label(owner:, repo:, label: nil, etag:)

        result_etags["all"] = result[:etag]
        if result[:not_modified]
          not_modified_labels << "all"
        else
          any_modified = true
        end

        issues_sem_pr = result[:issues].reject { |issue| issue.key?("pull_request") }
        issues_unicas = issues_sem_pr.uniq { |issue| issue.fetch("id") }

        {
          issues: issues_unicas,
          etags: result_etags,
          not_modified_labels: not_modified_labels,
          any_modified: any_modified
        }
      else
        issues_flat = []
        labels.each do |label|
          etag = etags[label]
          result = issues_for_label(owner:, repo:, label:, etag:)

          result_etags[label] = result[:etag]
          if result[:not_modified]
            not_modified_labels << label
          else
            any_modified = true
            issues_flat.concat(result[:issues])
          end
        end

        issues_sem_pr = issues_flat.reject { |issue| issue.key?("pull_request") }
        issues_unicas = issues_sem_pr.uniq { |issue| issue.fetch("id") }

        {
          issues: issues_unicas,
          etags: result_etags,
          not_modified_labels: not_modified_labels,
          any_modified: any_modified
        }
      end
    end

    def fetch_pull_requests_counts(owner:, repo:, issues:)
      return {} if issues.empty?

      counts = {}
      issues.each do |issue_hash|
        number = issue_hash["number"]
        body = issue_hash["body"]
        counts[number] = pull_requests_count(owner:, repo:, number:, body:)
      end

      if token.present?
        begin
          issues.each_slice(50) do |slice|
            query_parts = slice.map do |issue_hash|
              num = issue_hash["number"]
              "issue_#{num}: issue(number: #{num}) { closedByPullRequestsReferences { totalCount } }"
            end.join("\n")

            gql = <<~GQL
              query {
                repository(owner: "#{owner}", name: "#{repo}") {
                  #{query_parts}
                }
              }
            GQL

            uri = URI("https://api.github.com/graphql")
            req = Net::HTTP::Post.new(uri)
            req["Authorization"] = "Bearer #{token}"
            req["Content-Type"] = "application/json"
            req["Accept"] = "application/vnd.github+json"
            req.body = { query: gql }.to_json

            res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
            if res.is_a?(Net::HTTPSuccess)
              data = JSON.parse(res.body).dig("data", "repository") || {}
              data.each do |key, val|
                if key.start_with?("issue_") && val && val["closedByPullRequestsReferences"]
                  num = key.sub("issue_", "").to_i
                  gql_count = val.dig("closedByPullRequestsReferences", "totalCount").to_i
                  counts[num] = [ counts[num].to_i, gql_count ].max
                end
              end
            end
          end
        rescue StandardError => e
          Rails.logger.warn("Failed to fetch GraphQL linked PR counts for #{owner}/#{repo}: #{e.message}")
        end
      end

      counts
    end

    def pull_requests_count(owner:, repo:, number:, body: nil)
      return 0 if body.blank?

      pr_numbers = Set.new

      body.scan(%r{github\.com/#{Regexp.escape(owner)}/#{Regexp.escape(repo)}/pull/(\d+)}i).flatten.each do |pr_num|
        pr_numbers << pr_num.to_i
      end

      body.scan(/(?:pull\s*request|pull|pr)s?\s*[:#]\s*(\d+)/i).flatten.each do |pr_num|
        pr_numbers << pr_num.to_i
      end

      pr_numbers.size
    end

    private

    attr_reader :token

    def issues_for_label(owner:, repo:, label:, etag: nil)
      page = 1
      issues = []
      new_etag = nil
      loop do
        response = request(owner:, repo:, label:, page:, etag: (page == 1 ? etag : nil))

        if response.code == "304"
          return { not_modified: true, issues: [], etag: etag }
        end

        raise "GitHub issues request failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        if page == 1
          new_etag = response["ETag"]
        end

        payload = JSON.parse(response.body)
        issues.concat(payload)
        break if payload.length < 100

        page += 1
      end
      { not_modified: false, issues: issues, etag: new_etag }
    end

    def request(owner:, repo:, label:, page:, etag: nil)
      uri = URI("https://api.github.com/repos/#{owner}/#{repo}/issues")
      params = {
        state: "open",
        per_page: 100,
        page: page,
        since: 365.days.ago.utc.iso8601
      }
      params[:labels] = label if label.present?
      uri.query = URI.encode_www_form(params)
      get(uri, etag:)
    end

    def get(uri, etag: nil, redirects_remaining: MAX_REDIRECTS)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{token}"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      request["If-None-Match"] = etag if etag.present?
      retries = 0
      begin
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      rescue EOFError, Errno::ECONNRESET, OpenSSL::SSL::SSLError, Net::ReadTimeout, SocketError => e
        retries += 1
        raise e if retries > 3

        sleep(2 ** retries) # Exponential backoff: 2s, 4s, 8s
        retry
      end

      return response unless response.is_a?(Net::HTTPRedirection) && response.code != "304"
      raise "Too many GitHub redirects" if redirects_remaining.zero?

      get(URI(response.fetch("location")), etag: etag, redirects_remaining: redirects_remaining - 1)
    end
  end
end
