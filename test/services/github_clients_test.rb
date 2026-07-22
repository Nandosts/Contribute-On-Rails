require "test_helper"

class GithubClientsTest < ActiveSupport::TestCase
  Response = Struct.new(:body)

  test "requires a token" do
    client = Github::IssuesClient.new(token: nil)

    error = assert_raises(RuntimeError) do
      client.each_issues_page(owner: "rails", repo: "rails", state: "open").to_a
    end

    assert_equal "GITHUB_TOKEN is missing", error.message
  end

  test "streams pages and excludes pull requests" do
    client = Github::IssuesClient.new(token: "token")
    first_page = 99.times.map { |number| { "id" => number, "number" => number } }
    first_page << { "id" => 100, "number" => 100, "pull_request" => {} }
    second_page = [ { "id" => 101, "number" => 101 } ]
    responses = [ Response.new(first_page.to_json), Response.new(second_page.to_json) ]
    client.define_singleton_method(:request_issues_page) { |**| responses.shift }

    pages = client.each_issues_page(owner: "rails", repo: "rails", state: "open").to_a

    assert_equal 2, pages.size
    assert_equal 100, pages.flatten.size
    refute pages.flatten.any? { |issue| issue.key?("pull_request") }
  end

  test "returns linked open pull request counts from GraphQL" do
    client = Github::IssuesClient.new(token: "token")
    client.define_singleton_method(:graphql) do |**|
      {
        "data" => {
          "repository" => {
            "issue_10" => { "closedByPullRequestsReferences" => { "totalCount" => 2 } }
          }
        }
      }
    end

    counts = client.fetch_pull_requests_counts(owner: "rails", repo: "rails", issues: [ { "number" => 10 } ])

    assert_equal({ 10 => 2 }, counts)
  end

  test "retries transient server errors" do
    client = Github::IssuesClient.new(token: "token")
    responses = [
      Net::HTTPInternalServerError.new("1.1", "500", "Error"),
      Net::HTTPOK.new("1.1", "200", "OK")
    ]
    http = Object.new
    http.define_singleton_method(:request) { |_request| responses.shift }
    client.define_singleton_method(:http_for) { |_uri| http }
    client.define_singleton_method(:sleep) { |_seconds| nil }

    response = client.send(:perform_with_retries, URI("https://api.github.com/test"), Net::HTTP::Get.new("/test"))

    assert_equal "200", response.code
    assert_empty responses
  end

  test "raises a typed error for permanent HTTP failures" do
    client = Github::IssuesClient.new(token: "token")
    response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    client.define_singleton_method(:perform) { |*_args| response }

    error = assert_raises(Github::IssuesClient::RequestError) do
      client.send(:request_issues_page, owner: "missing", repo: "repo", state: "open", since: nil, page: 1)
    end

    assert_equal 404, error.status
  end
end
