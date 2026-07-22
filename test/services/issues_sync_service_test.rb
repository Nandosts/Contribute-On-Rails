require "test_helper"

class IssuesSyncServiceTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :state, :since

    def initialize(pages, error_after_pages: false, pr_counts: {})
      @pages = pages
      @error_after_pages = error_after_pages
      @pr_counts = pr_counts
    end

    def each_issues_page(owner:, repo:, state:, since:)
      @state = state
      @since = since
      @pages.each { |page| yield page }
      raise "request interrupted" if @error_after_pages
    end

    def fetch_pull_requests_counts(owner:, repo:, issues:)
      @pr_counts.slice(*issues.map { |issue| issue.fetch("number") })
    end
  end

  test "full reconciliation upserts open issues and deletes missing issues only after completion" do
    project = create_project
    old_issue = project.issues.create!(github_id: 1, number: 1, title: "Old", state: "open", github_url: "https://example.test/1")
    payload = issue_payload(id: 2, number: 2, labels: [ { "name" => "documentation", "color" => "ffffff" } ])
    client = FakeClient.new([ [ payload ] ], pr_counts: { 2 => 1 })

    result = Issues::SyncService.new(client:).call(project)

    refute Issue.exists?(old_issue.id)
    issue = Issue.find_by!(github_id: 2)
    assert_equal [ "Documentation" ], issue.labels.pluck(:name)
    assert_equal 1, issue.pull_requests_count
    assert_equal "open", client.state
    assert_nil client.since
    assert result.full_reconciliation
    assert_equal 1, result.issues_upserted
    assert_equal 1, result.issues_deleted
    assert project.reload.last_full_synced_at.present?
  end

  test "incremental sync preserves unseen issues and deletes issues returned as closed" do
    checkpoint = 1.day.ago
    project = create_project(last_synced_at: checkpoint, last_full_synced_at: 1.day.ago)
    preserved = project.issues.create!(github_id: 10, number: 10, title: "Unchanged", state: "open", github_url: "https://example.test/10")
    closed = project.issues.create!(github_id: 20, number: 20, title: "Closed", state: "open", github_url: "https://example.test/20")
    payloads = [ issue_payload(id: 20, number: 20, state: "closed"), issue_payload(id: 30, number: 30) ]
    client = FakeClient.new([ payloads ])

    result = Issues::SyncService.new(client:).call(project)

    assert Issue.exists?(preserved.id)
    refute Issue.exists?(closed.id)
    assert Issue.exists?(github_id: 30)
    assert_equal "all", client.state
    assert_in_delta checkpoint - 5.minutes, client.since, 1.second
    refute result.full_reconciliation
  end

  test "an interrupted full reconciliation never deletes unseen issues or advances the checkpoint" do
    project = create_project(last_synced_at: 2.days.ago)
    existing = project.issues.create!(github_id: 40, number: 40, title: "Keep", state: "open", github_url: "https://example.test/40")
    original_checkpoint = project.last_synced_at
    client = FakeClient.new([ [ issue_payload(id: 50, number: 50) ] ], error_after_pages: true)

    assert_raises(RuntimeError) do
      Issues::SyncService.new(client:).call(project)
    end

    assert Issue.exists?(existing.id)
    assert_equal original_checkpoint, project.reload.last_synced_at
  end

  test "replaces labels when an issue changes" do
    project = create_project(last_synced_at: 1.day.ago, last_full_synced_at: 1.day.ago)
    issue = project.issues.create!(github_id: 60, number: 60, title: "Issue", state: "open", github_url: "https://example.test/60", updated_at_from_github: 2.days.ago)
    issue.labels << Label.create!(name: "Good First Issue")
    payload = issue_payload(
      id: 60,
      number: 60,
      labels: [ { "name" => "bug", "color" => "ff0000" } ],
      assignees: [ { "login" => "contributor", "avatar_url" => "https://example.test/avatar.png" } ]
    )

    Issues::SyncService.new(client: FakeClient.new([ [ payload ] ])).call(project)

    assert_equal [ "Bug" ], issue.reload.labels.pluck(:name)
    assert_equal [ { "login" => "contributor" } ], issue.assignees
    refute Label.exists?(name: "Good First Issue")
  end

  private

  def create_project(**attributes)
    Project.create!({ github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails" }.merge(attributes))
  end

  def issue_payload(id:, number:, state: "open", labels: [], assignees: [])
    {
      "id" => id,
      "number" => number,
      "title" => "Issue #{number}",
      "state" => state,
      "html_url" => "https://github.com/rails/rails/issues/#{number}",
      "created_at" => 2.days.ago.iso8601,
      "updated_at" => Time.current.iso8601,
      "comments" => 3,
      "assignees" => assignees,
      "labels" => labels
    }
  end
end
