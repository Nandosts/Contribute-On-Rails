require "test_helper"

class IssuesSyncJobTest < ActiveJob::TestCase
  test "continues syncing after one project fails and records run statistics" do
    first = create_project(owner: "missing", repo: "repo")
    second = create_project(owner: "rails", repo: "rails")
    run = SyncRun.create!(status: "running", started_at: Time.current)
    calls = []
    service = Object.new
    service.define_singleton_method(:call) do |project, **|
      calls << project
      raise "temporary failure" if project == first

      Issues::SyncService::Result.new(issues_upserted: 2, issues_deleted: 1, full_reconciliation: false)
    end

    with_sync_service(service) do
      Issues::SyncJob.perform_now(sync_run_id: run.id)
    end

    assert_equal [ first, second ], calls
    run.reload
    assert_equal 1, run.projects_succeeded
    assert_equal 1, run.projects_failed
    assert_equal 2, run.issues_upserted
    assert_equal 1, run.issues_deleted
    assert_equal "temporary failure", first.reload.last_sync_error
  end

  test "deactivates a project only after three consecutive 404 responses" do
    project = create_project(owner: "missing", repo: "repo")
    error = Github::IssuesClient::RequestError.new("not found", status: 404)
    service = Object.new
    service.define_singleton_method(:call) { |*_args, **_kwargs| raise error }

    with_sync_service(service) do
      2.times { Issues::SyncJob.perform_now }
      assert project.reload.active?

      Issues::SyncJob.perform_now
    end

    refute project.reload.active?
    assert_equal 3, project.sync_failures_count
  end

  test "limits scheduled full reconciliations per run" do
    11.times do |number|
      create_project(owner: "owner#{number}", repo: "repo#{number}").update!(last_full_synced_at: 31.days.ago, last_synced_at: 1.day.ago)
    end
    scheduled_full = []
    service = Object.new
    service.define_singleton_method(:call) do |_project, allow_scheduled_full:, **|
      scheduled_full << allow_scheduled_full
      Issues::SyncService::Result.new(issues_upserted: 0, issues_deleted: 0, full_reconciliation: allow_scheduled_full)
    end

    with_sync_service(service) do
      Issues::SyncJob.perform_now
    end

    assert_equal 10, scheduled_full.count(true)
    assert_equal 1, scheduled_full.count(false)
  end

  test "accepts fetch_all as a legacy alias for force_full" do
    create_project(owner: "rails", repo: "rails")
    received_force_full = []
    service = Object.new
    service.define_singleton_method(:call) do |_project, force_full:, **|
      received_force_full << force_full
      Issues::SyncService::Result.new(issues_upserted: 0, issues_deleted: 0, full_reconciliation: force_full)
    end

    with_sync_service(service) do
      Issues::SyncJob.perform_now(fetch_all: true)
    end

    assert_equal [ true ], received_force_full
  end

  private

  def create_project(owner:, repo:)
    Project.create!(github_owner: owner, github_repo: repo, name: repo.titleize, github_url: "https://github.com/#{owner}/#{repo}")
  end

  def with_sync_service(service)
    original_new = Issues::SyncService.method(:new)
    Issues::SyncService.define_singleton_method(:new) { service }
    yield
  ensure
    Issues::SyncService.define_singleton_method(:new, original_new)
  end
end
