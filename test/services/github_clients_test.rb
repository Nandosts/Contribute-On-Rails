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

  test "sends authenticated GraphQL requests with variables" do
    client = Github::IssuesClient.new(token: "token")
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { { "data" => { "repository" => {} } }.to_json }
    captured = nil
    client.define_singleton_method(:perform) do |uri, request|
      captured = [ uri, request ]
      response
    end

    payload = client.send(:graphql, query: "query($owner: String!) { repository(owner: $owner, name: \"rails\") { id } }", variables: { owner: "rails" })

    uri, request = captured
    assert_equal "https://api.github.com/graphql", uri.to_s
    assert_equal "Bearer token", request["Authorization"]
    assert_equal "application/json", request["Content-Type"]
    assert_equal({ "owner" => "rails" }, JSON.parse(request.body)["variables"])
    assert_equal({ "repository" => {} }, payload["data"])
  end

  test "returns partial pull request counts when GraphQL fails" do
    client = Github::IssuesClient.new(token: "token")
    calls = 0
    client.define_singleton_method(:graphql) do |**|
      calls += 1
      return { "data" => { "repository" => { "issue_1" => { "closedByPullRequestsReferences" => { "totalCount" => 1 } } } } } if calls == 1

      raise "GraphQL unavailable"
    end
    issues = (1..51).map { |number| { "number" => number } }

    counts = client.fetch_pull_requests_counts(owner: "rails", repo: "rails", issues:)

    assert_equal({ 1 => 1 }, counts)
  end

  test "follows redirects only within the GitHub API host" do
    client = Github::IssuesClient.new(token: "token")
    redirect = Net::HTTPFound.new("1.1", "302", "Found")
    redirect["location"] = "https://api.github.com/redirected"
    success = Net::HTTPOK.new("1.1", "200", "OK")
    responses = [ redirect, success ]
    requests = []
    client.define_singleton_method(:perform_with_retries) do |_uri, request|
      requests << request
      responses.shift
    end

    result = client.send(:perform, URI("https://api.github.com/original"), Net::HTTP::Get.new("/original"))

    assert_equal success, result
    assert_equal "/redirected", requests.last.path
    assert_equal "Bearer token", requests.last["Authorization"]
  end

  test "rejects redirects to untrusted hosts" do
    client = Github::IssuesClient.new(token: "token")
    redirect = Net::HTTPFound.new("1.1", "302", "Found")
    redirect["location"] = "https://example.com/steal-token"
    client.define_singleton_method(:perform_with_retries) { |_uri, _request| redirect }

    error = assert_raises(Github::IssuesClient::RequestError) do
      client.send(:perform, URI("https://api.github.com/original"), Net::HTTP::Get.new("/original"))
    end

    assert_equal 302, error.status
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

  test "retries transient network errors" do
    client = Github::IssuesClient.new(token: "token")
    attempts = 0
    success = Net::HTTPOK.new("1.1", "200", "OK")
    http = Object.new
    http.define_singleton_method(:request) do |_request|
      attempts += 1
      raise EOFError if attempts == 1

      success
    end
    client.define_singleton_method(:http_for) { |_uri| http }
    client.define_singleton_method(:sleep) { |_seconds| nil }

    response = client.send(:perform_with_retries, URI("https://api.github.com/test"), Net::HTTP::Get.new("/test"))

    assert_equal success, response
    assert_equal 2, attempts
  end

  test "configures bounded HTTP timeouts" do
    client = Github::IssuesClient.new(token: "token")

    http = client.send(:http_for, URI("https://api.github.com/test"))

    assert http.use_ssl?
    assert_equal Github::IssuesClient::OPEN_TIMEOUT, http.open_timeout
    assert_equal Github::IssuesClient::READ_TIMEOUT, http.read_timeout
    assert_equal Github::IssuesClient::WRITE_TIMEOUT, http.write_timeout
  end

  test "recognizes rate limit responses" do
    client = Github::IssuesClient.new(token: "token")
    response = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
    response["Retry-After"] = "5"

    assert client.send(:rate_limited?, response)
    assert_equal 5, client.send(:retry_delay, response, 0)
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
