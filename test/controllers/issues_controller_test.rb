require "test_helper"

class IssuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    @issue = @project.issues.create!(github_id: 100, number: 100, title: "Improve docs", state: "open", github_url: "https://example.test/100", opened_at: 2.days.ago, updated_at_from_github: Time.current)
    @issue.labels << Label.create!(name: "good first issue")
  end

  test "renders accessible filters and grouped issues" do
    get issues_url

    assert_response :success
    assert_select "input[type=search][name=q]"
    assert_select "label.sr-only[for=q]", text: "Search issue titles"
    assert_select "select[data-controller=select]", count: 4
    assert_select "fieldset legend.sr-only", text: "Labels"
    assert_select "section[aria-labelledby] h2", text: "rails"
    assert_select "input[type=submit][value=Filter]"
    assert_select "select[name=updated_since]"
    assert_select "p", text: /Opened/
  end

  test "redirects random project to a project with matching issues" do
    get random_issues_url

    assert_redirected_to project_url(@project, from_random: true)
  end

  test "redirects empty filters back to the canonical issues url" do
    get issues_url, params: { q: "", project_id: "", organization: "", category: "", labels: [ "" ] }

    assert_redirected_to issues_url
  end

  test "renders an empty state when filters match nothing" do
    get issues_url, params: { q: "nope" }

    assert_response :success
    assert_select "p", text: "No issues match the current filters."
  end

  test "only includes projects with recent open issues in the filters by default" do
    active_recent = Project.create!(github_owner: "recent_org", github_repo: "recent_repo", name: "Recent Project", github_url: "https://github.com/recent_org/recent_repo")
    issue_recent = active_recent.issues.create!(github_id: 401, number: 401, title: "Recent issue", state: "open", github_url: "https://example.test/401", opened_at: 2.days.ago, updated_at_from_github: Time.current)
    issue_recent.labels << Label.find_or_create_by!(name: "good first issue")

    active_stale = Project.create!(github_owner: "stale_org", github_repo: "stale_repo", name: "Stale Project", github_url: "https://github.com/stale_org/stale_repo")
    issue_stale = active_stale.issues.create!(github_id: 402, number: 402, title: "Stale issue", state: "open", github_url: "https://example.test/402", opened_at: 2.years.ago, updated_at_from_github: 2.years.ago)
    issue_stale.labels << Label.find_or_create_by!(name: "good first issue")

    get issues_url
    assert_response :success
    # The recent project should be in the select option
    assert_select "select[name=project_id] option", text: "recent_org/recent_repo"
    # The stale project should NOT be in the select option
    assert_select "select[name=project_id] option", text: "stale_org/stale_repo", count: 0
  end
end
