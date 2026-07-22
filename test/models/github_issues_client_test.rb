require "test_helper"

class GithubIssuesClientTest < ActiveSupport::TestCase
  test "requires a github token" do
    error = assert_raises(RuntimeError) do
      Github::IssuesClient.new(token: nil).open_issues(owner: "rails", repo: "rails")
    end

    assert_equal "GITHUB_TOKEN is missing", error.message
  end

  test "deduplicates issues returned by multiple tracked labels" do
    client = Github::IssuesClient.new(token: "token")
    payload = [ { "id" => 1, "number" => 1 } ]
    client.define_singleton_method(:issues_for_label) { |**| { not_modified: false, issues: payload, etag: "etag" } }

    results = client.open_issues(owner: "rails", repo: "rails")
    assert_equal payload, results[:issues]
  end

  test "pull_requests_count parses body for pull request URLs when token is not present" do
    client = Github::IssuesClient.new(token: nil)
    body = "Fixes https://github.com/rails/rails/pull/12345 and https://github.com/rails/rails/pull/67890"

    count = client.pull_requests_count(owner: "rails", repo: "rails", number: 100, body: body)
    assert_equal 2, count
  end

  test "fetch_pull_requests_counts returns mapped PR counts for multiple issues" do
    client = Github::IssuesClient.new(token: nil)
    issues = [
      { "number" => 1, "body" => "Fixes https://github.com/rails/rails/pull/10" },
      { "number" => 2, "body" => "No PRs" }
    ]

    counts = client.fetch_pull_requests_counts(owner: "rails", repo: "rails", issues: issues)
    assert_equal({ 1 => 1, 2 => 0 }, counts)
  end
end
