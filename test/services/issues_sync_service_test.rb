require "test_helper"

class IssuesSyncServiceTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:issues) do
    def open_issues(owner:, repo:, labels: Issue::DEFAULT_LABELS, fetch_all: false) = issues
  end

  test "syncs issues, labels, and closes missing open issues" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    old_issue = project.issues.create!(github_id: 1, number: 1, title: "Old", state: "open", github_url: "https://github.com/rails/rails/issues/1")
    payload = [ {
      "id" => 2,
      "number" => 2,
      "title" => "New issue",
      "body" => "Body",
      "state" => "open",
      "html_url" => "https://github.com/rails/rails/issues/2",
      "created_at" => Time.current.iso8601,
      "updated_at" => Time.current.iso8601,
      "closed_at" => nil,
      "labels" => [ { "name" => "good first issue", "color" => "ffffff" } ]
    } ]

    Issues::SyncService.new(client: FakeClient.new(payload)).call(project)

    assert_equal "closed", old_issue.reload.state
    issue = Issue.find_by!(github_id: 2)
    assert_equal [ "Good First Issue" ], issue.labels.pluck(:name)
  end
end
