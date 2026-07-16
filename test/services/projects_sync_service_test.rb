require "test_helper"

class ProjectsSyncServiceTest < ActiveSupport::TestCase
  test "creates projects and deactivates missing ones" do
    existing = Project.create!(github_owner: "old", github_repo: "repo", name: "Old Repo", github_url: "https://github.com/old/repo")

    class << $stdout
      alias_method :original_tty?, :tty?
      def tty? = true
    end

    begin
      Projects::SyncService.new.call
    ensure
      class << $stdout
        alias_method :tty?, :original_tty?
        remove_method :original_tty?
      end
    end

    assert Project.find_by!(github_owner: "rails", github_repo: "rails").active?
    assert_not existing.reload.active?
  end
end
