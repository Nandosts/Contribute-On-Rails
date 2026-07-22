module Issues
  class SyncJob < ApplicationJob
    FULL_RECONCILIATIONS_PER_RUN = 10

    queue_as :default

    def perform(force_full: false, sync_run_id: nil)
      run = SyncRun.find_by(id: sync_run_id)
      projects = Project.active
      stats = {
        projects_total: projects.count,
        projects_succeeded: 0,
        projects_failed: 0,
        issues_upserted: 0,
        issues_deleted: 0,
        failure_details: {}
      }
      scheduled_full_ids = projects.where.not(last_full_synced_at: nil)
        .where("last_full_synced_at < ?", Issues::SyncService::FULL_RECONCILIATION_INTERVAL.ago)
        .order(:last_full_synced_at)
        .limit(FULL_RECONCILIATIONS_PER_RUN)
        .pluck(:id)

      projects.find_each do |project|
        result = SyncService.new.call(
          project,
          force_full:,
          allow_scheduled_full: scheduled_full_ids.include?(project.id)
        )
        stats[:projects_succeeded] += 1
        stats[:issues_upserted] += result.issues_upserted
        stats[:issues_deleted] += result.issues_deleted
      rescue StandardError => error
        project.sync_failed!(error)
        stats[:projects_failed] += 1
        stats[:failure_details]["#{project.github_owner}/#{project.github_repo}"] = error.message
        Rails.logger.warn("Issue sync failed for #{project.github_owner}/#{project.github_repo}: #{error.message}")
      end

      run&.update!(stats)
      stats
    end
  end
end
