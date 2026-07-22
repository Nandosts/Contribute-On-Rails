require "time"

module Issues
  class SyncService
    FULL_RECONCILIATION_INTERVAL = 30.days
    CHECKPOINT_OVERLAP = 5.minutes
    Result = Data.define(:issues_upserted, :issues_deleted, :full_reconciliation)

    def initialize(client: Github::IssuesClient.new)
      @client = client
    end

    def call(project, force_full: false, allow_scheduled_full: true)
      started_at = Time.current
      full_reconciliation = full_reconciliation?(project, force_full:, allow_scheduled_full:, now: started_at)
      since = project.last_synced_at - CHECKPOINT_OVERLAP unless full_reconciliation || project.last_synced_at.nil?
      state = full_reconciliation ? "open" : "all"
      upserted = 0
      deleted = 0

      client.each_issues_page(owner: project.github_owner, repo: project.github_repo, state:, since:) do |payloads|
        page_result = sync_page(project, payloads, started_at)
        upserted += page_result[:upserted]
        deleted += page_result[:deleted]
      end

      deleted += delete_missing_issues(project, started_at) if full_reconciliation
      Label.where.missing(:issue_labels).delete_all
      project.update!(
        last_synced_at: started_at,
        last_full_synced_at: full_reconciliation ? started_at : project.last_full_synced_at,
        last_sync_error: nil,
        sync_failures_count: 0
      )

      Result.new(issues_upserted: upserted, issues_deleted: deleted, full_reconciliation:)
    end

    private

    attr_reader :client

    def full_reconciliation?(project, force_full:, allow_scheduled_full:, now:)
      force_full || project.last_full_synced_at.nil? ||
        allow_scheduled_full && full_reconciliation_due?(project, now)
    end

    def full_reconciliation_due?(project, now)
      project.last_full_synced_at.nil? || project.last_full_synced_at < now - FULL_RECONCILIATION_INTERVAL
    end

    def sync_page(project, payloads, synced_at)
      closed_ids = payloads.select { |payload| payload["state"] == "closed" }.map { |payload| payload.fetch("id") }
      open_payloads = payloads.reject { |payload| payload["state"] == "closed" }

      deleted = delete_issues(project.issues.where(github_id: closed_ids))
      upsert_open_issues(project, open_payloads, synced_at)

      { upserted: open_payloads.size, deleted: }
    end

    def upsert_open_issues(project, payloads, synced_at)
      return if payloads.empty?

      github_ids = payloads.map { |payload| payload.fetch("id") }
      existing = project.issues.where(github_id: github_ids)
        .pluck(:github_id, :updated_at_from_github, :pull_requests_count)
        .to_h { |github_id, updated_at, pr_count| [ github_id, { updated_at:, pr_count: } ] }

      enrichment_payloads = payloads.select { |payload| enrich_pull_requests?(payload, existing[payload.fetch("id")]) }
      pr_counts = client.fetch_pull_requests_counts(
        owner: project.github_owner,
        repo: project.github_repo,
        issues: enrichment_payloads
      )

      rows = payloads.map do |payload|
        current = existing[payload.fetch("id")]
        number = payload.fetch("number")
        {
          project_id: project.id,
          github_id: payload.fetch("id"),
          number:,
          title: payload.fetch("title"),
          state: payload.fetch("state"),
          github_url: payload.fetch("html_url"),
          opened_at: payload["created_at"],
          updated_at_from_github: payload["updated_at"],
          last_synced_at: synced_at,
          assignees: normalized_assignees(payload),
          comments_count: payload.fetch("comments", 0),
          pull_requests_count: pr_counts.fetch(number, current&.fetch(:pr_count, 0) || 0),
          created_at: synced_at,
          updated_at: synced_at
        }
      end

      Issue.transaction do
        Issue.upsert_all(
          rows,
          unique_by: :index_issues_on_github_id,
          update_only: %i[project_id number title state github_url opened_at updated_at_from_github last_synced_at assignees comments_count pull_requests_count]
        )
        sync_labels(payloads, synced_at)
      end
    end

    def enrich_pull_requests?(payload, existing)
      return false if payload["assignees"].present?

      updated_at = Time.iso8601(payload.fetch("updated_at"))
      existing.nil? || existing.fetch(:updated_at) != updated_at
    end

    def normalized_assignees(payload)
      Array(payload["assignees"]).filter_map do |assignee|
        login = assignee["login"]
        { "login" => login } if login.present?
      end
    end

    def sync_labels(payloads, synced_at)
      labels_by_issue = payloads.to_h do |payload|
        labels = payload.fetch("labels", []).map do |label|
          [ Label.normalize_name(label.fetch("name")), label["color"] ]
        end
        [ payload.fetch("id"), labels ]
      end
      all_labels = labels_by_issue.values.flatten(1).to_h

      Label.insert_all(
        all_labels.map { |name, color| { name:, color:, created_at: synced_at, updated_at: synced_at } },
        unique_by: :index_labels_on_name
      ) if all_labels.any?

      issues = Issue.where(github_id: labels_by_issue.keys).pluck(:github_id, :id).to_h
      labels = Label.where(name: all_labels.keys).pluck(:name, :id).to_h
      issue_ids = issues.values
      IssueLabel.where(issue_id: issue_ids).delete_all

      joins = labels_by_issue.flat_map do |github_id, issue_labels|
        issue_labels.filter_map do |name, _color|
          label_id = labels[name]
          { issue_id: issues.fetch(github_id), label_id:, created_at: synced_at, updated_at: synced_at } if label_id
        end
      end
      IssueLabel.insert_all(joins, unique_by: :index_issue_labels_on_issue_id_and_label_id) if joins.any?
    end

    def delete_missing_issues(project, synced_at)
      delete_issues(project.issues.where("last_synced_at IS NULL OR last_synced_at < ?", synced_at))
    end

    def delete_issues(relation)
      count = relation.count
      return 0 if count.zero?

      Issue.transaction do
        IssueLabel.where(issue_id: relation.select(:id)).delete_all
        relation.delete_all
      end
      count
    end
  end
end
