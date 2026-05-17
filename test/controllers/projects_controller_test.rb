require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "renders the project index" do
    get projects_url

    assert_response :success
  end

  test "renders a back link when opened from random selection" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")

    get project_url(project, from_random: true)

    assert_select "a", text: "Back to issues"
  end

  test "renders issue labels on the project page" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    issue = project.issues.create!(github_id: 200, number: 200, title: "Improve docs", state: "open", github_url: "https://example.test/200", opened_at: 2.days.ago, updated_at_from_github: Time.current)
    issue.labels << Label.create!(name: "good first issue")
    issue.labels << Label.create!(name: "documentation")

    get project_url(project)

    assert_response :success
    assert_select "span", text: "good first issue"
    assert_select "span", text: "documentation"
    assert_select "select[name=updated_since]"
    assert_select "p", text: /Opened/
  end
end
