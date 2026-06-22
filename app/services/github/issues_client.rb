require "net/http"
require "json"

module Github
  class IssuesClient
    MAX_REDIRECTS = 3

    def initialize(token: ENV["GITHUB_TOKEN"])
      @token = token
    end

    def open_issues(owner:, repo:, labels: Issue::DEFAULT_LABELS, fetch_all: false)
      raise "GITHUB_TOKEN is missing" if token.blank?

      if fetch_all
        issues_filtradas = issues_for_label(owner:, repo:, label: nil)
        issues_sem_pr = issues_filtradas.reject { |issue| issue.key?("pull_request") }
        issues_sem_pr.uniq { |issue| issue.fetch("id") }
      else
        issues_flat = labels.flat_map { |label| issues_for_label(owner:, repo:, label:) }
        issues_sem_pr = issues_flat.reject { |issue| issue.key?("pull_request") }
        issues_sem_pr.uniq { |issue| issue.fetch("id") }
      end
    end

    private

    attr_reader :token

    def issues_for_label(owner:, repo:, label:)
      page = 1
      issues = []
      loop do
        response = request(owner:, repo:, label:, page:)
        payload = JSON.parse(response.body)
        raise "GitHub issues request failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        issues.concat(payload)
        break if payload.length < 100

        page += 1
      end
      issues
    end

    def request(owner:, repo:, label:, page:)
      uri = URI("https://api.github.com/repos/#{owner}/#{repo}/issues")
      params = {
        state: "open",
        per_page: 100,
        page: page,
        since: 365.days.ago.utc.iso8601
      }
      params[:labels] = label if label.present?
      uri.query = URI.encode_www_form(params)
      get(uri)
    end

    def get(uri, redirects_remaining: MAX_REDIRECTS)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{token}"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

      return response unless response.is_a?(Net::HTTPRedirection)
      raise "Too many GitHub redirects" if redirects_remaining.zero?

      get(URI(response.fetch("location")), redirects_remaining: redirects_remaining - 1)
    end
  end
end
