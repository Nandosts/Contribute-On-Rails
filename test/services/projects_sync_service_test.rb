require "test_helper"

class ProjectsSyncServiceTest < ActiveSupport::TestCase
  FakeReadmeClient = Struct.new(:content) do
    def call = content
  end

  test "creates projects and deactivates missing ones" do
    existing = Project.create!(github_owner: "old", github_repo: "repo", name: "Old Repo", github_url: "https://github.com/old/repo")
    markdown = "## Rails\n- [Discourse](https://github.com/discourse/discourse)\n"

    class << $stdout
      alias_method :original_tty?, :tty?
      def tty? = true
    end

    begin
      Projects::SyncService.new(readme_client: FakeReadmeClient.new(markdown)).call
    ensure
      class << $stdout
        alias_method :tty?, :original_tty?
        remove_method :original_tty?
      end
    end

    assert Project.find_by!(github_owner: "discourse", github_repo: "discourse").active?
    assert_not existing.reload.active?
  end

  test "deduplicates catalog entries and lets curated metadata win" do
    markdown = "## Apps\n- [Discourse](https://github.com/discourse/discourse)\n"

    Projects::SyncService.new(readme_client: FakeReadmeClient.new(markdown)).call

    project = Project.find_by!(github_owner: "discourse", github_repo: "discourse")
    assert_equal "Rails Applications", project.source_category
    assert_equal 1, Project.where(github_owner: "discourse", github_repo: "discourse").count
  end

  test "ignores upstream projects when IGNORE_UPSTREAM_PROJECTS is true" do
    Project.delete_all
    markdown = "## Apps\n- [Fictional](https://github.com/fictional/fictional-repo)\n"
    ENV["IGNORE_UPSTREAM_PROJECTS"] = "true"

    begin
      Projects::SyncService.new(readme_client: FakeReadmeClient.new(markdown)).call
    ensure
      ENV.delete("IGNORE_UPSTREAM_PROJECTS")
    end

    assert_nil Project.find_by(github_owner: "fictional", github_repo: "fictional-repo")
    assert Project.find_by!(github_owner: "rails", github_repo: "rails").active?
  end
end
