module Issues
  class SyncJob < ApplicationJob
    FULL_RECONCILIATIONS_PER_RUN = 10

    queue_as :default

    def perform(force_full: false, sync_run_id: nil, fetch_all: nil)
      unless fetch_all.nil?
        Rails.logger.warn("Issues::SyncJob fetch_all is deprecated; use force_full instead")
        force_full ||= ActiveModel::Type::Boolean.new.cast(fetch_all)
      end

      run = SyncRun.find_by(id: sync_run_id)
      sync_service = SyncService.new
      sync_service.validate! if sync_service.respond_to?(:validate!)
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

      projects.find_each.with_index(1) do |project, progress|
        print_progress(project, progress, stats[:projects_total])
        result = sync_service.call(
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

      print_summary(stats)
      run&.update!(stats)
      stats
    end

    private

    def print_progress(project, progress, total)
      return unless $stdout.tty?

      print "\rSyncing Issues: #{progress}/#{total} (#{project.github_owner}/#{project.github_repo})".ljust(100)
      $stdout.flush
    end

    def print_summary(stats)
      return unless $stdout.tty?

      puts "\nCompleted! Synced issues for #{stats[:projects_succeeded]}/#{stats[:projects_total]} projects " \
        "(upserted: #{stats[:issues_upserted]}, deleted: #{stats[:issues_deleted]}, failed: #{stats[:projects_failed]})."
    end
  end
end
