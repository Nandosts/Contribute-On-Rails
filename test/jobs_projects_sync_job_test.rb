require "test_helper"

class ProjectsSyncJobTest < ActiveJob::TestCase
  test "performs sync successfully" do
    called = false
    service = Object.new
    service.define_singleton_method(:call) do
      called = true
    end

    original_new = Projects::SyncService.method(:new)
    Projects::SyncService.define_singleton_method(:new) { |*args| service }
    Projects::SyncJob.perform_now

    assert called
  ensure
    Projects::SyncService.define_singleton_method(:new, original_new)
  end
end
