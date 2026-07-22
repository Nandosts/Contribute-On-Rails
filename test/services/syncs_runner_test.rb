require "test_helper"

class SyncsRunnerTest < ActiveSupport::TestCase
  test "runs project and issue synchronization and records the result" do
    original_projects_perform_now = Projects::SyncJob.method(:perform_now)
    original_issues_perform_now = Issues::SyncJob.method(:perform_now)
    Projects::SyncJob.define_singleton_method(:perform_now) { true }
    Issues::SyncJob.define_singleton_method(:perform_now) do |sync_run_id:, **|
      SyncRun.find(sync_run_id).update!(projects_total: 1, projects_succeeded: 1, issues_upserted: 3)
    end

    result = Syncs::Runner.new.call

    assert_equal :succeeded, result.status
    assert_equal "succeeded", result.sync_run.status
    assert_equal 1, result.sync_run.projects_succeeded
    assert_equal 3, result.sync_run.issues_upserted
    assert result.sync_run.finished_at.present?
  ensure
    Projects::SyncJob.define_singleton_method(:perform_now, original_projects_perform_now)
    Issues::SyncJob.define_singleton_method(:perform_now, original_issues_perform_now)
  end
end
