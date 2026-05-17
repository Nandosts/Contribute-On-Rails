require "test_helper"

class IssuesSyncJobTest < ActiveJob::TestCase
  test "continues syncing after one project fails" do
    first = Project.create!(github_owner: "missing", github_repo: "repo", name: "Missing", github_url: "https://github.com/missing/repo")
    second = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    calls = []
    service = Object.new
    service.define_singleton_method(:call) do |project|
      calls << project
      raise "not found" if project == first
    end

    original_new = Issues::SyncService.method(:new)
    Issues::SyncService.define_singleton_method(:new) { service }
    Issues::SyncJob.perform_now

    assert_equal [ first, second ], calls
  ensure
    Issues::SyncService.define_singleton_method(:new, original_new)
  end
end
