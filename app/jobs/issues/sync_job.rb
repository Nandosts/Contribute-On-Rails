module Issues
  class SyncJob < ApplicationJob
    queue_as :default

    def perform
      Project.active.find_each do |project|
        SyncService.new.call(project)
      rescue StandardError => error
        Rails.logger.warn("Issue sync failed for #{project.github_owner}/#{project.github_repo}: #{error.message}")
      end
    end
  end
end
