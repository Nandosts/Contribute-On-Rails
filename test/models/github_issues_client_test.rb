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
    client.define_singleton_method(:issues_for_label) { |**| payload }

    assert_equal payload, client.open_issues(owner: "rails", repo: "rails")
  end
end
