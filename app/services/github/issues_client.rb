require "net/http"
require "json"

module Github
  class IssuesClient
    MAX_REDIRECTS = 3
    MAX_RETRIES = 3
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 20
    WRITE_TIMEOUT = 20

    class RequestError < StandardError
      attr_reader :status, :headers

      def initialize(message, status:, headers: {})
        @status = status
        @headers = headers
        super(message)
      end
    end

    def initialize(token: ENV["GITHUB_TOKEN"])
      @token = token
    end

    def each_issues_page(owner:, repo:, state:, since: nil)
      return enum_for(__method__, owner:, repo:, state:, since:) unless block_given?

      raise "GITHUB_TOKEN is missing" if token.blank?

      page = 1
      loop do
        response = request_issues_page(owner:, repo:, state:, since:, page:)
        payload = JSON.parse(response.body)
        issues = payload.reject { |issue| issue.key?("pull_request") }
        yield issues

        break if payload.length < 100

        page += 1
      end
    end

    def fetch_pull_requests_counts(owner:, repo:, issues:)
      return {} if issues.empty?

      counts = {}
      issues.each_slice(50) do |slice|
        fields = slice.map do |issue|
          number = Integer(issue.fetch("number"))
          "issue_#{number}: issue(number: #{number}) { closedByPullRequestsReferences { totalCount } }"
        end.join("\n")

        query = <<~GQL
          query($owner: String!, $repo: String!) {
            repository(owner: $owner, name: $repo) {
              #{fields}
            }
          }
        GQL

        payload = graphql(query:, variables: { owner:, repo: })
        repository = payload.dig("data", "repository") || {}
        repository.each do |key, value|
          next unless key.start_with?("issue_") && value

          number = key.delete_prefix("issue_").to_i
          counts[number] = value.dig("closedByPullRequestsReferences", "totalCount").to_i
        end
      end

      counts
    rescue StandardError => error
      Rails.logger.warn("Failed to fetch linked pull request counts for #{owner}/#{repo}: #{error.message}")
      counts
    end

    private

    attr_reader :token

    def request_issues_page(owner:, repo:, state:, since:, page:)
      uri = URI("https://api.github.com/repos/#{owner}/#{repo}/issues")
      params = {
        state:,
        sort: "updated",
        direction: "asc",
        per_page: 100,
        page:
      }
      params[:since] = since.utc.iso8601 if since
      uri.query = URI.encode_www_form(params)

      request = Net::HTTP::Get.new(uri)
      add_github_headers(request)
      response = perform(uri, request)
      return response if response.is_a?(Net::HTTPSuccess)

      raise_request_error(response)
    end

    def graphql(query:, variables:)
      uri = URI("https://api.github.com/graphql")
      request = Net::HTTP::Post.new(uri)
      add_github_headers(request)
      request["Content-Type"] = "application/json"
      request.body = { query:, variables: }.to_json

      response = perform(uri, request)
      raise_request_error(response) unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body)
      raise "GitHub GraphQL request failed: #{payload.fetch("errors").to_json}" if payload["errors"].present?

      payload
    end

    def add_github_headers(request)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{token}"
      request["X-GitHub-Api-Version"] = "2022-11-28"
    end

    def perform(uri, request, redirects_remaining: MAX_REDIRECTS)
      response = perform_with_retries(uri, request)
      return response unless response.is_a?(Net::HTTPRedirection)
      raise RequestError.new("Too many GitHub redirects", status: response.code.to_i) if redirects_remaining.zero?

      location = response["location"]
      raise RequestError.new("GitHub redirect is missing a location", status: response.code.to_i) if location.blank?

      redirected_uri = URI(location)
      unless redirected_uri.is_a?(URI::HTTPS) && redirected_uri.host == "api.github.com"
        raise RequestError.new("Refused GitHub redirect to an untrusted host", status: response.code.to_i)
      end

      redirected_request = Net::HTTP::Get.new(redirected_uri)
      add_github_headers(redirected_request)
      perform(redirected_uri, redirected_request, redirects_remaining: redirects_remaining - 1)
    end

    def perform_with_retries(uri, request)
      retries = 0

      loop do
        begin
          response = http_for(uri).request(request)
        rescue EOFError, Errno::ECONNRESET, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError
          raise if retries >= MAX_RETRIES

          sleep(2**retries)
          retries += 1
          next
        end

        return response unless retryable_response?(response)
        raise_request_error(response) if retries >= MAX_RETRIES

        sleep(retry_delay(response, retries))
        retries += 1
      end
    end

    def http_for(uri)
      Net::HTTP.new(uri.hostname, uri.port).tap do |http|
        http.use_ssl = true
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT
        http.write_timeout = WRITE_TIMEOUT
      end
    end

    def retryable_response?(response)
      response.code.to_i >= 500 || rate_limited?(response)
    end

    def rate_limited?(response)
      response.code == "429" || response.code == "403" && (
        response["Retry-After"].present? ||
        response["X-RateLimit-Remaining"] == "0" ||
        response.body.to_s.downcase.include?("rate limit")
      )
    end

    def retry_delay(response, retries)
      retry_after = response["Retry-After"].to_i
      return retry_after.clamp(1, 60) if retry_after.positive?

      reset_at = response["X-RateLimit-Reset"].to_i
      return (reset_at - Time.now.to_i).clamp(1, 60) if reset_at.positive?

      (2**retries) + rand
    end

    def raise_request_error(response)
      headers = response.each_header.to_h
      raise RequestError.new("GitHub request failed: #{response.code}", status: response.code.to_i, headers:)
    end
  end
end
