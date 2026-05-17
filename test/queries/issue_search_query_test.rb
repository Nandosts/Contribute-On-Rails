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
end
