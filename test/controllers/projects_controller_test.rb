require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "renders the project index" do
    get projects_url

    assert_response :success
  end

  test "renders active projects with open issues regardless of update date" do
    active_recent = Project.create!(github_owner: "active", github_repo: "recent", name: "Active Recent", github_url: "https://github.com/active/recent")
    active_recent.issues.create!(github_id: 301, number: 301, title: "Recent issue", state: "open", github_url: "https://example.test/301", opened_at: 2.days.ago, updated_at_from_github: Time.current)

    active_stale = Project.create!(github_owner: "active", github_repo: "stale", name: "Active Stale", github_url: "https://github.com/active/stale")
    active_stale.issues.create!(github_id: 302, number: 302, title: "Stale issue", state: "open", github_url: "https://example.test/302", opened_at: 2.years.ago, updated_at_from_github: 2.years.ago)

    get projects_url
    assert_response :success
    assert_select "article h2 a", text: "Active Recent"
    assert_select "article h2 a", text: "Active Stale"
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

    get project_url(project, starter_mode: false)

    assert_response :success
    assert_select "span", text: "Good First Issue"
    assert_select "span", text: "Documentation"
    assert_select "select[name=updated_since]"
    assert_select "p", text: /Opened/
  end

  test "paginates issues on the project page" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    31.times do |number|
      project.issues.create!(github_id: 500 + number, number: 500 + number, title: "Issue #{number}", state: "open", github_url: "https://example.test/#{number}", opened_at: 2.days.ago, updated_at_from_github: Time.current)
    end

    get project_url(project, starter_mode: false)

    assert_response :success
    assert_select "article", count: 30
    assert_select "nav[aria-label]"
  end
end
