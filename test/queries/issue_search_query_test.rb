require "test_helper"

class IssueSearchQueryTest < ActiveSupport::TestCase
  test "does not use default labels when none are selected" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    starter = project.issues.create!(github_id: 10, number: 10, title: "Starter", state: "open", github_url: "https://example.test/10")
    advanced = project.issues.create!(github_id: 11, number: 11, title: "Advanced", state: "open", github_url: "https://example.test/11")
    starter.labels << Label.create!(name: "good first issue")
    advanced.labels << Label.create!(name: "bug")

    results = IssueSearchQuery.new(Issue.all, labels: []).call

    assert_includes results, starter
    assert_includes results, advanced
  end

  test "filters by title, label, and project" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    issue = project.issues.create!(github_id: 12, number: 12, title: "Improve docs", state: "open", github_url: "https://example.test/12")
    issue.labels << Label.create!(name: "help wanted")

    results = IssueSearchQuery.new(Issue.all, q: "docs", labels: [ "help wanted" ], project_id: project.id).call

    assert_equal [ issue ], results
  end

  test "starter mode includes good first issue and help wanted labels" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    good_first_issue = project.issues.create!(github_id: 21, number: 21, title: "Starter", state: "open", github_url: "https://example.test/21")
    help_wanted = project.issues.create!(github_id: 22, number: 22, title: "Help", state: "open", github_url: "https://example.test/22")
    advanced = project.issues.create!(github_id: 23, number: 23, title: "Advanced", state: "open", github_url: "https://example.test/23")
    good_first_issue.labels << Label.create!(name: "Good First Issue")
    help_wanted.labels << Label.create!(name: "Help Wanted")
    advanced.labels << Label.create!(name: "Bug")

    results = IssueSearchQuery.new(Issue.all, starter_mode: true).call

    assert_includes results, good_first_issue
    assert_includes results, help_wanted
    assert_not_includes results, advanced
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

  test "filters by recent updates" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    recent = project.issues.create!(github_id: 15, number: 15, title: "Recent", state: "open", github_url: "https://example.test/15", updated_at_from_github: 10.days.ago)
    stale = project.issues.create!(github_id: 16, number: 16, title: "Stale", state: "open", github_url: "https://example.test/16", updated_at_from_github: 2.years.ago)
    label = Label.create!(name: "good first issue")
    recent.labels << label
    stale.labels << label

    assert_equal [ recent ], IssueSearchQuery.new(Issue.all, updated_since: 90).call
  end

  test "filters by category" do
    project_matching = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails", source_category: "Rails Applications")
    project_other = Project.create!(github_owner: "rubocop", github_repo: "rubocop", name: "RuboCop", github_url: "https://github.com/rubocop/rubocop", source_category: "Ruby Gems")

    issue_matching = project_matching.issues.create!(github_id: 17, number: 17, title: "Matching", state: "open", github_url: "https://example.test/17")
    issue_other = project_other.issues.create!(github_id: 18, number: 18, title: "Other", state: "open", github_url: "https://example.test/18")

    label = Label.create!(name: "good first issue")
    issue_matching.labels << label
    issue_other.labels << label

    assert_equal [ issue_matching ], IssueSearchQuery.new(Issue.all, category: "Rails Applications").call
  end

  test "filters by assignee status" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    unassigned_issue = project.issues.create!(github_id: 19, number: 19, title: "Unassigned", state: "open", github_url: "https://example.test/19", assignees: [])
    assigned_issue = project.issues.create!(github_id: 20, number: 20, title: "Assigned", state: "open", github_url: "https://example.test/20", assignees: [ { "login" => "octocat" } ])

    label = Label.create!(name: "good first issue")
    unassigned_issue.labels << label
    assigned_issue.labels << label

    assert_equal [ unassigned_issue ], IssueSearchQuery.new(Issue.all, assignee_status: "unassigned").call
    assert_equal [ assigned_issue ], IssueSearchQuery.new(Issue.all, assignee_status: "assigned").call

    results = IssueSearchQuery.new(Issue.all, assignee_status: "").call
    assert_includes results, unassigned_issue
    assert_includes results, assigned_issue
  end

  test "includes or excludes project relation based on include_project parameter" do
    query_with = IssueSearchQuery.new(Issue.all, include_project: true).call
    query_without = IssueSearchQuery.new(Issue.all, include_project: false).call

    assert_includes query_with.includes_values, :project
    assert_not_includes query_without.includes_values, :project
  end
end
