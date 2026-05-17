module Issues
  class SyncJob < ApplicationJob
    queue_as :default

    def perform(fetch_all: false)
      projects = Project.active
      total = projects.count
      progress = 0
      synced_names = []

      # Silence SQL logging to prevent stdout pollution breaking carriage returns
      original_logger = ActiveRecord::Base.logger
      ActiveRecord::Base.logger = nil

      original_sync = $stdout.sync
      $stdout.sync = true

      begin
        projects.find_each do |project|
          progress += 1

          unless Rails.env.test?
            print "\rSyncing Issues: #{progress}/#{total} (#{project.github_owner}/#{project.github_repo})\e[K"
            $stdout.flush
          end

          SyncService.new.call(project, force_fetch: fetch_all)
          synced_names << "#{project.github_owner}/#{project.github_repo}"
        rescue StandardError => error
          Rails.logger.warn("Issue sync failed for #{project.github_owner}/#{project.github_repo}: #{error.message}")
        end
      ensure
        ActiveRecord::Base.logger = original_logger
        $stdout.sync = original_sync
      end

      unless Rails.env.test?
        puts "\nCompleted! Synced projects: #{synced_names.join(', ')}"
      end
    end
  end
end
