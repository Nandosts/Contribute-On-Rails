require "test_helper"

class IssueSearchQueryTest < ActiveSupport::TestCase
  test "uses default labels when none are selected" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    matching = project.issues.create!(github_id: 10, number: 10, title: "Starter", state: "open", github_url: "https://example.test/10")
    other = project.issues.create!(github_id: 11, number: 11, title: "Advanced", state: "open", github_url: "https://example.test/11")
    matching.labels << Label.create!(name: "good first issue")
    other.labels << Label.create!(name: "bug")

    assert_equal [ matching ], IssueSearchQuery.new.call
  end

  test "filters by title, label, and project" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    issue = project.issues.create!(github_id: 12, number: 12, title: "Improve docs", state: "open", github_url: "https://example.test/12")
    issue.labels << Label.create!(name: "help wanted")

    results = IssueSearchQuery.new(Issue.all, q: "docs", labels: [ "help wanted" ], project_id: project.id).call

    assert_equal [ issue ], results
  end

  test "filters by organization" do
    rails_project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    rubocop_project = Project.create!(github_owner: "rubocop", github_repo: "rubocop", name: "RuboCop", github_url: "https://github.com/rubocop/rubocop")
    rails_issue = rails_project.issues.create!(github_id: 13, number: 13, title: "Improve docs", state: "open", github_url: "https://example.test/13")
    rubocop_issue = rubocop_project.issues.create!(github_id: 14, number: 14, title: "Improve docs", state: "open", github_url: "https://example.test/14")
    label = Label.create!(name: "good first issue")
    rails_issue.labels << label
    rubocop_issue.labels << label

    assert_equal [ rails_issue ], IssueSearchQuery.new(Issue.all, organization: "rails").call
  end
end
