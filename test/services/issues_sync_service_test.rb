require "test_helper"

class IssuesSyncServiceTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:issues) do
    def open_issues(owner:, repo:, labels: Issue::DEFAULT_LABELS, fetch_all: false, etags: {})
      {
        issues: issues,
        etags: {},
        not_modified_labels: [],
        any_modified: true
      }
    end
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
      "comments" => 5,
      "pull_requests_count" => 1,
      "labels" => [
        { "name" => "Good First Issue", "color" => "ffffff" },
        { "name" => "New Label", "color" => "000000" }
      ]
    } ]

    Issues::SyncService.new(client: FakeClient.new(payload)).call(project)

    refute Issue.exists?(old_issue.id)
    refute Label.exists?(stale_label.id) # Stale label should be cleaned up!
    assert Label.exists?(shared_label.id) # Shared label should persist!

    issue = Issue.find_by!(github_id: 2)
    assert_equal [ "Good First Issue", "New Label" ], issue.labels.pluck(:name).sort
    assert_equal 5, issue.comments_count
    assert_equal 1, issue.pull_requests_count
  end

  test "preserves local issues for labels that return 304 Not Modified" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")

    gfi_label = Label.create!(name: "Good First Issue")
    hw_label = Label.create!(name: "Help Wanted")

    issue_gfi = project.issues.create!(github_id: 10, number: 10, title: "Good issue", state: "open", github_url: "https://github.com/rails/rails/issues/10")
    issue_gfi.labels << gfi_label

    issue_hw = project.issues.create!(github_id: 20, number: 20, title: "Help issue", state: "open", github_url: "https://github.com/rails/rails/issues/20")
    issue_hw.labels << hw_label

    fake_response = {
      issues: [
        {
          "id" => 30,
          "number" => 30,
          "title" => "New help issue",
          "body" => "Body",
          "state" => "open",
          "html_url" => "https://github.com/rails/rails/issues/30",
          "created_at" => Time.current.iso8601,
          "updated_at" => Time.current.iso8601,
          "closed_at" => nil,
          "labels" => [
            { "name" => "Help Wanted", "color" => "111111" }
          ]
        }
      ],
      etags: { "Good First Issue" => "etag_gfi_old", "Help Wanted" => "etag_hw_new" },
      not_modified_labels: [ "Good First Issue" ],
      any_modified: true
    }

    mock_client = Object.new
    mock_client.define_singleton_method(:open_issues) do |owner:, repo:, labels: nil, fetch_all: false, etags: {}|
      fake_response
    end

    Issues::SyncService.new(client: mock_client).call(project)

    # 1. GFI issue must be preserved
    assert Issue.exists?(issue_gfi.id)

    # 2. Old HW issue must be deleted
    refute Issue.exists?(issue_hw.id)

    # 3. New HW issue must be created
    assert Issue.exists?(github_id: 30)

    # 4. Project ETags must be updated
    assert_equal "etag_gfi_old", project.github_etags["Good First Issue"]
    assert_equal "etag_hw_new", project.github_etags["Help Wanted"]
  end
  test "returns early if no issues were modified" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails", last_synced_at: 1.day.ago)

    mock_client = Object.new
    mock_client.define_singleton_method(:open_issues) do |owner:, repo:, labels: nil, fetch_all: false, etags: {}|
      { any_modified: false }
    end

    assert_changes -> { project.reload.last_synced_at } do
      Issues::SyncService.new(client: mock_client).call(project)
    end
  end

  test "preserves all issues when fetch_all is true and not modified" do
    project = Project.create!(github_owner: "rails", github_repo: "rails", name: "Rails", github_url: "https://github.com/rails/rails")
    issue = project.issues.create!(github_id: 100, number: 100, title: "Keep me", state: "open", github_url: "https://github.com/rails/rails/issues/100")

    fake_response = {
      issues: [],
      etags: { "all" => "etag_all_new" },
      not_modified_labels: [ "all" ],
      any_modified: true
    }

    mock_client = Object.new
    mock_client.define_singleton_method(:open_issues) do |**_kwargs|
      fake_response
    end

    Issues::SyncService.new(client: mock_client).call(project, force_fetch: true)

    assert Issue.exists?(issue.id)
    assert_equal "etag_all_new", project.github_etags["all"]
  end
end
