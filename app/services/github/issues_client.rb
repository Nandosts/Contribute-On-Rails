require "net/http"
require "json"

module Github
  class IssuesClient
    def initialize(token: ENV["GITHUB_TOKEN"])
      @token = token
    end

    def open_issues(owner:, repo:)
      raise "GITHUB_TOKEN is missing" if token.blank?

      page = 1
      issues = []
      loop do
        response = request(owner:, repo:, page:)
        payload = JSON.parse(response.body)
        raise "GitHub issues request failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        batch = payload.reject { |issue| issue.key?("pull_request") }
        issues.concat(batch)
        break if payload.length < 100

        page += 1
      end
      issues
    end

    private

    attr_reader :token

    def request(owner:, repo:, page:)
      uri = URI("https://api.github.com/repos/#{owner}/#{repo}/issues")
      uri.query = URI.encode_www_form(state: "open", per_page: 100, page:)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{token}"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    end
  end
end
