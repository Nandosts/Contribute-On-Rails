module Issues
  class SyncJob < ApplicationJob
    queue_as :default

    def perform(fetch_all: false)
      projects = Project.active
      total = projects.count
      progress = 0

      projects.find_each do |project|
        progress += 1
        print "\rSyncing Issues: #{progress}/#{total} (#{project.github_owner}/#{project.github_repo})".ljust(80) if $stdout.tty?

        SyncService.new.call(project, force_fetch: fetch_all)
      rescue StandardError => error
        Rails.logger.warn("Issue sync failed for #{project.github_owner}/#{project.github_repo}: #{error.message}")
      end

      puts "\nCompleted!" if $stdout.tty?
    end
  end
end
