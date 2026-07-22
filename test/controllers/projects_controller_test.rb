require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "renders the project index" do
    get projects_url

    assert_response :success
    assert_select "title", text: "Projects | Contribute on Rails"
    assert_select "link[rel=canonical][href='http://www.example.com/projects?locale=en']"
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

  test "filters projects by query and category" do
    rails = Project.create!(github_owner: "rails", github_repo: "rails", name: "Ruby on Rails", github_url: "https://github.com/rails/rails", source_category: "Frameworks")
    rails.issues.create!(github_id: 303, number: 303, title: "Rails issue", state: "open", github_url: "https://example.test/303")
    rubocop = Project.create!(github_owner: "rubocop", github_repo: "rubocop", name: "RuboCop", github_url: "https://github.com/rubocop/rubocop", source_category: "Tooling")
    rubocop.issues.create!(github_id: 304, number: 304, title: "RuboCop issue", state: "open", github_url: "https://example.test/304")

    get projects_url, params: { q: "rails", category: "Frameworks" }

    assert_response :success
    assert_select "article h2 a", text: "Ruby on Rails"
    assert_select "article h2 a", text: "RuboCop", count: 0
    assert_select "a", text: "Clear"
  end

  test "removes blank project filters from the url" do
    get projects_url, params: { q: " rails ", category: "" }

    assert_redirected_to projects_path(q: "rails")
  end

  test "paginates the project catalog" do
    25.times do |number|
      project = Project.create!(github_owner: "org", github_repo: "repo-#{number}", name: "Project #{number}", github_url: "https://github.com/org/repo-#{number}")
      project.issues.create!(github_id: 1_000 + number, number: number, title: "Issue #{number}", state: "open", github_url: "https://example.test/#{number}")
    end

    get projects_url

    assert_response :success
    assert_select "article", count: 24
    assert_select "nav[aria-label='Project pages']"
  end

  test "renders a back link when opened from random selection" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")

    get project_url(project, from_random: true)

    assert_select "a", text: "Back to issues"
    assert_select "title", text: "Rails | Contribute on Rails"
    assert_select "meta[name=description][content*='Rails']"
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
    assert_select "button[role=switch][aria-checked=false]"
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
