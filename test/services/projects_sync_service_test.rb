require "test_helper"

class ProjectsSyncServiceTest < ActiveSupport::TestCase
  FakeReadmeClient = Struct.new(:content) do
    def call = content
  end

  test "creates projects and deactivates missing ones" do
    existing = Project.create!(github_owner: "old", github_repo: "repo", name: "Old Repo", github_url: "https://github.com/old/repo")
    markdown = "## Rails\n- [Discourse](https://github.com/discourse/discourse)\n"

    Projects::SyncService.new(readme_client: FakeReadmeClient.new(markdown)).call

    assert Project.find_by!(github_owner: "discourse", github_repo: "discourse").active?
    assert_not existing.reload.active?
  end
end
