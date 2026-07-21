require "test_helper"

class IssueTest < ActiveSupport::TestCase
  test "assigned? returns true when there are assignees" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    issue_empty = project.issues.build(assignees: [])
    issue_present = project.issues.build(assignees: [ { "login" => "octocat" } ])

    assert_not issue_empty.assigned?
    assert issue_present.assigned?
  end

  test "assignee_logins returns names of assignees" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    issue = project.issues.build(assignees: [ { "login" => "octocat" }, { "login" => "railsguy" } ])

    assert_equal [ "octocat", "railsguy" ], issue.assignee_logins
  end

  test "has_pull_requests? returns true when pull_requests_count is greater than 0" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    issue_without_pr = project.issues.build(pull_requests_count: 0)
    issue_with_pr = project.issues.build(pull_requests_count: 2)

    assert_not issue_without_pr.has_pull_requests?
    assert issue_with_pr.has_pull_requests?
  end
end
