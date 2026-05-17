module Issues
  class SyncJob < ApplicationJob
    queue_as :default

    def perform
      Project.active.find_each { |project| SyncService.new.call(project) }
    end
  end
end
