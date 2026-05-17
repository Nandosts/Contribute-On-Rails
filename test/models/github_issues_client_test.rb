require "test_helper"

class GithubIssuesClientTest < ActiveSupport::TestCase
  test "requires a github token" do
    error = assert_raises(RuntimeError) do
      Github::IssuesClient.new(token: nil).open_issues(owner: "rails", repo: "rails")
    end

    assert_equal "GITHUB_TOKEN is missing", error.message
  end
end
