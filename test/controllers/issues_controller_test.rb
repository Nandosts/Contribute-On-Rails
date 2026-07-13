require "test_helper"

class IssuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    @issue = @project.issues.create!(github_id: 100, number: 100, title: "Improve docs", state: "open", github_url: "https://example.test/100", opened_at: 2.days.ago, updated_at_from_github: Time.current)
    @issue.labels << Label.create!(name: "Good First Issue")
  end

  test "renders accessible filters and grouped issues" do
    get issues_url

    assert_response :success
    assert_select "input[type=search][name=q]"
    assert_select "label[for=input_q]", text: "Search issue titles"
    assert_select "select[data-controller=select]", count: 7
    assert_select "select[name='labels[]']"
    assert_select "section[aria-labelledby] h2", text: "rails"
    assert_select "input[type=submit][value=Filter]"
    assert_select "select[name=updated_since]"
    assert_select "p", text: /Opened/

    # Collapsible project issues assertions
    assert_select "section[data-controller='collapsible']"
    assert_select "button[data-action='click->collapsible#toggle']"
    assert_select "div[data-collapsible-target='content']"
  end

  test "renders pt-BR locale without missing translations" do
    get issues_url, headers: { "HTTP_ACCEPT_LANGUAGE": "pt-BR" }

    assert_response :success
    refute_match "translation missing", response.body
    refute_match "translation_missing", response.body
  end

  test "sets session locale from params and persists it" do
    get issues_url, params: { locale: "pt-BR" }
    assert_response :success
    assert_equal "pt-BR", session[:locale]

    # Proxima chamada sem parametros deve carregar da sessao
    get issues_url
    assert_response :success
    assert_equal "pt-BR", I18n.locale.to_s
  end

  test "extracts locale from accept language header fallback" do
    get issues_url, headers: { "HTTP_ACCEPT_LANGUAGE": "pt-PT" }
    assert_response :success
    assert_equal "pt-BR", I18n.locale.to_s
  end

  test "extracts locale from accept language header and falls back to default if no match" do
    get issues_url, headers: { "HTTP_ACCEPT_LANGUAGE": "fr-FR" }
    assert_response :success
    assert_equal "en", I18n.locale.to_s
  end

  test "redirects random project to a project with matching issues" do
    get random_issues_url

    assert_redirected_to project_url(@project, from_random: true)
  end

  test "redirects empty filters back to the canonical issues url" do
    get issues_url, params: { q: "", project_id: "", organization: "", category: "", assignee_status: "", labels: [ "" ] }

    assert_redirected_to issues_url
  end

  test "renders an empty state when filters match nothing" do
    get issues_url, params: { q: "nope" }

    assert_response :success
    assert_select "p", text: "No issues match the current filters."
  end

  test "renders all active projects when timeframe is set to empty (any time)" do
    active_recent = Project.create!(github_owner: "recent_org", github_repo: "recent_repo", name: "Recent Project", github_url: "https://github.com/recent_org/recent_repo")
    issue_recent = active_recent.issues.create!(github_id: 401, number: 401, title: "Recent issue", state: "open", github_url: "https://example.test/401", opened_at: 2.days.ago, updated_at_from_github: Time.current)
    issue_recent.labels << Label.find_or_create_by!(name: "Good First Issue")

    active_stale = Project.create!(github_owner: "stale_org", github_repo: "stale_repo", name: "Stale Project", github_url: "https://github.com/stale_org/stale_repo")
    issue_stale = active_stale.issues.create!(github_id: 402, number: 402, title: "Stale issue", state: "open", github_url: "https://example.test/402", opened_at: 2.years.ago, updated_at_from_github: 2.years.ago)
    issue_stale.labels << Label.find_or_create_by!(name: "Good First Issue")

    get issues_url, params: { q: "issue", updated_since: "" }
    assert_response :success
    # Both projects should be in the select options when updated_since is empty
    assert_select "select[name=project_id] option", text: "recent_org/recent_repo"
    assert_select "select[name=project_id] option", text: "stale_org/stale_repo"
  end

  test "only includes projects with recent open issues in the filters by default" do
    active_recent = Project.create!(github_owner: "recent_org", github_repo: "recent_repo", name: "Recent Project", github_url: "https://github.com/recent_org/recent_repo")
    issue_recent = active_recent.issues.create!(github_id: 401, number: 401, title: "Recent issue", state: "open", github_url: "https://example.test/401", opened_at: 2.days.ago, updated_at_from_github: Time.current)
    issue_recent.labels << Label.find_or_create_by!(name: "Good First Issue")

    active_stale = Project.create!(github_owner: "stale_org", github_repo: "stale_repo", name: "Stale Project", github_url: "https://github.com/stale_org/stale_repo")
    issue_stale = active_stale.issues.create!(github_id: 402, number: 402, title: "Stale issue", state: "open", github_url: "https://example.test/402", opened_at: 2.years.ago, updated_at_from_github: 2.years.ago)
    issue_stale.labels << Label.find_or_create_by!(name: "Good First Issue")

    get issues_url(updated_since: 365)
    assert_response :success
    # The recent project should be in the select option
    assert_select "select[name=project_id] option", text: "recent_org/recent_repo"
    # The stale project should NOT be in the select option
    assert_select "select[name=project_id] option", text: "stale_org/stale_repo", count: 0
  end

  test "does not redirect pagination when no other filters are active" do
    label = Label.find_or_create_by!(name: "Good First Issue")
    31.times do |i|
      issue = @project.issues.create!(github_id: 200 + i, number: 200 + i, title: "Issue #{i}", state: "open", github_url: "https://example.test/200#{i}", opened_at: 2.days.ago, updated_at_from_github: Time.current)
      issue.labels << label
    end

    get issues_url, params: { page: 2 }
    assert_response :success
  end

  test "sorts issues correctly by oldest, newest, least_recently_updated, and recently_updated" do
    Issue.destroy_all
    Project.destroy_all

    projeto = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")

    issue_a = projeto.issues.create!(
      github_id: 1, number: 1, title: "Issue A", state: "open",
      github_url: "https://example.test/1",
      opened_at: 3.days.ago, updated_at_from_github: 1.day.ago
    )
    issue_a.labels << Label.find_or_create_by!(name: "Good First Issue")

    issue_b = projeto.issues.create!(
      github_id: 2, number: 2, title: "Issue B", state: "open",
      github_url: "https://example.test/2",
      opened_at: 1.day.ago, updated_at_from_github: 3.days.ago
    )
    issue_b.labels << Label.find_or_create_by!(name: "Good First Issue")

    # 1. Mais antiga (opened_at asc) -> Issue A depois Issue B
    get issues_url, params: { sort: "mais_antiga" }
    assert_response :success
    titulos = css_select("h3 a").map(&:text).map(&:strip)
    assert_equal [ "Issue A", "Issue B" ], titulos

    # 2. Mais nova (opened_at desc) -> Issue B depois Issue A
    get issues_url, params: { sort: "mais_nova" }
    assert_response :success
    titulos = css_select("h3 a").map(&:text).map(&:strip)
    assert_equal [ "Issue B", "Issue A" ], titulos

    # 3. Atualizada há mais tempo (updated_at_from_github asc) -> Issue B depois Issue A
    get issues_url, params: { sort: "atualizada_ha_mais_tempo" }
    assert_response :success
    titulos = css_select("h3 a").map(&:text).map(&:strip)
    assert_equal [ "Issue B", "Issue A" ], titulos

    # 4. Atualizada recentemente (updated_at_from_github desc) -> Issue A depois Issue B
    get issues_url, params: { sort: "atualizada_recentemente" }
    assert_response :success
    titulos = css_select("h3 a").map(&:text).map(&:strip)
    assert_equal [ "Issue A", "Issue B" ], titulos
  end

  test "extracts locale from params directly in extract_locale_from_accept_language_header" do
    controlador = IssuesController.new
    params_mock = ActionController::Parameters.new(locale: "pt-BR")
    controlador.define_singleton_method(:params) { params_mock }

    assert_equal "pt-BR", controlador.send(:extract_locale_from_accept_language_header)
  end
end
