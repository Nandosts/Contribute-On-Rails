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
end
