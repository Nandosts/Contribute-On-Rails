require "test_helper"

class IssuesSyncServiceTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:issues) do
    def open_issues(owner:, repo:, labels: Issue::DEFAULT_LABELS, fetch_all: false) = issues
  end

  test "syncs issues, labels, and destroys missing open issues and orphaned labels" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    
    # Create an old issue with a unique label "Stale Label"
    old_issue = project.issues.create!(github_id: 1, number: 1, title: "Old", state: "open", github_url: "https://github.com/rails/rails/issues/1")
    stale_label = Label.create!(name: "Stale Label")
    old_issue.labels << stale_label

    # Create a shared label "Good First Issue" which is also on another issue (so it shouldn't be deleted)
    shared_label = Label.create!(name: "Good First Issue")
    old_issue.labels << shared_label

    another_issue = project.issues.create!(github_id: 3, number: 3, title: "Another", state: "open", github_url: "https://github.com/rails/rails/issues/3")
    another_issue.labels << shared_label

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
      "labels" => [ { "name" => "Good First Issue", "color" => "ffffff" } ]
    } ]

    Issues::SyncService.new(client: FakeClient.new(payload)).call(project)

    refute Issue.exists?(old_issue.id)
    refute Label.exists?(stale_label.id) # Stale label should be cleaned up!
    assert Label.exists?(shared_label.id) # Shared label should persist!

    issue = Issue.find_by!(github_id: 2)
    assert_equal [ "Good First Issue" ], issue.labels.pluck(:name)
  end
end
