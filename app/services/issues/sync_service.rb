module Issues
  class SyncService
    def initialize(client: Github::IssuesClient.new)
      @client = client
    end

    def call(project)
      payloads = client.open_issues(owner: project.github_owner, repo: project.github_repo)
      seen_ids = []
      now = Time.current

      Issue.transaction do
        payloads.each do |payload|
          issue = Issue.find_or_initialize_by(github_id: payload.fetch("id"))
          issue.update!(
            project:,
            number: payload.fetch("number"),
            title: payload.fetch("title"),
            body: payload["body"],
            state: payload.fetch("state"),
            github_url: payload.fetch("html_url"),
            opened_at: payload["created_at"],
            updated_at_from_github: payload["updated_at"],
            closed_at: payload["closed_at"],
            last_synced_at: now,
            assignees: payload["assignees"] || []
          )
          sync_labels(issue, payload.fetch("labels", []))
          seen_ids << issue.github_id
        end

        project.issues.open.where.not(github_id: seen_ids).update_all(state: "closed", closed_at: now, updated_at: now)
        project.update!(last_synced_at: now)
      end
    end

    private

    attr_reader :client

    def sync_labels(issue, labels)
      records = labels.map do |label_payload|
        Label.find_or_create_by!(name: label_payload.fetch("name")) do |label|
          label.color = label_payload["color"]
        end
      end
      issue.labels = records
    end
  end
end
