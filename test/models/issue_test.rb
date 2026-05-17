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
end
