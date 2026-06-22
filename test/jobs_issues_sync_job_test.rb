require "test_helper"

class IssuesSyncJobTest < ActiveJob::TestCase
  test "continues syncing after one project fails" do
    first = Project.create!(github_owner: "missing", github_repo: "repo", name: "Missing", github_url: "https://github.com/missing/repo")
    second = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    calls = []
    service = Object.new
    service.define_singleton_method(:call) do |project, **_kwargs|
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

  test "prints progress and completion when not in test env" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    service = Object.new
    service.define_singleton_method(:call) { |*args, **_kwargs| nil }

    original_new = Issues::SyncService.method(:new)
    Issues::SyncService.define_singleton_method(:new) { service }

    captured_stdout = StringIO.new
    original_stdout = $stdout
    $stdout = captured_stdout

    class << Rails.env
      alias_method :original_test?, :test?
      def test? = false
    end

    begin
      Issues::SyncJob.perform_now
    ensure
      class << Rails.env
        alias_method :test?, :original_test?
        remove_method :original_test?
      end
    end

    assert_match(/Syncing Issues/, captured_stdout.string)
    assert_match(/Completed!/, captured_stdout.string)
  ensure
    $stdout = original_stdout
    Issues::SyncService.define_singleton_method(:new, original_new)
  end
end
