module Issues
  class SyncService
    def initialize(client: Github::IssuesClient.new)
      @client = client
    end

    def call(project, force_fetch: false)
      should_fetch_all = force_fetch || project.fetch_all_issues
      current_etags = project.github_etags

      response = client.open_issues(
        owner: project.github_owner,
        repo: project.github_repo,
        fetch_all: should_fetch_all,
        etags: current_etags
      )

      unless response[:any_modified]
        project.update!(last_synced_at: Time.current)
        return
      end

      seen_ids = []
      now = Time.current

      pr_counts = client.respond_to?(:fetch_pull_requests_counts) ?
        client.fetch_pull_requests_counts(owner: project.github_owner, repo: project.github_repo, issues: response[:issues]) : {}

      Issue.transaction do
        response[:issues].each do |payload|
          number = payload.fetch("number")
          comments_count = payload.fetch("comments", 0)
          pull_requests_count = payload["pull_requests_count"] || pr_counts[number] ||
            (client.respond_to?(:pull_requests_count) ? client.pull_requests_count(owner: project.github_owner, repo: project.github_repo, number: number, body: payload["body"]) : 0)

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
            assignees: payload["assignees"] || [],
            comments_count: comments_count,
            pull_requests_count: pull_requests_count
          )
          sync_labels(issue, payload.fetch("labels", []))
          seen_ids << issue.github_id
        end

        if should_fetch_all
          if response[:not_modified_labels].include?("all")
            seen_ids.concat(project.issues.pluck(:github_id))
          end
        else
          labels_304 = response[:not_modified_labels]
          if labels_304.any?
            issues_to_keep = project.issues.joins(:labels).where(labels: { name: labels_304 }).pluck(:github_id)
            seen_ids.concat(issues_to_keep)
          end
        end

        seen_ids.uniq!

        project.issues.where.not(github_id: seen_ids).destroy_all
        project.github_etags = response[:etags]
        project.last_synced_at = now
        project.save!
      end
    end

    private

    attr_reader :client

    def sync_labels(issue, labels)
      records = labels.map do |label_payload|
        normalized_name = Label.normalize_name(label_payload.fetch("name"))
        Label.find_or_create_by!(name: normalized_name) do |label|
          label.color = label_payload["color"]
        end
      end
      issue.labels = records
    end
  end
end
