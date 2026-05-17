class IssuesController < ApplicationController
  def index
    return redirect_to issues_path if request.query_parameters.except("page").present? && normalized_search_params.values.all?(&:blank?)

    active_search_params = search_params.to_h

    scoped_issues = IssueSearchQuery.new(Issue.all, active_search_params).call
    @project_issue_counts = scoped_issues.unscope(:includes, :order).group(:project_id).count
    @pagy, @issues = pagy(scoped_issues, limit: 30, size: [ 1, 4, 4, 1 ])
    @grouped_issues = @issues.group_by { |issue| [ issue.project.github_owner, issue.project ] }

    timeframe = active_search_params["updated_since"]
    if timeframe.present?
      active_projects = Project.active.joins(:issues).where(issues: { state: "open" }).where("issues.updated_at_from_github >= ?", timeframe.to_i.days.ago).distinct
    else
      active_projects = Project.active
    end

    @projects = active_projects.order(:github_owner, :github_repo)
    @organizations = active_projects.distinct.order(:github_owner).pluck(:github_owner)
    @categories = active_projects.where.not(source_category: nil).distinct.order(:source_category).pluck(:source_category)
  end

  def random
    project_ids = IssueSearchQuery.new(Issue.all, search_params.to_h).call.unscope(:order).pluck(:project_id).uniq
    project = Project.active.where(id: project_ids).order(Arel.sql("RANDOM()")).first

    redirect_to(project ? project_path(project, request.query_parameters.merge(from_random: true)) : projects_path)
  end

  private

  def search_params
    params.permit(:q, :project_id, :organization, :category, :updated_since, :assignee_status, labels: [])
  end

  def normalized_search_params
    search_params.to_h.tap do |filters|
      filters["labels"] = Array(filters["labels"]).reject(&:blank?)
    end
  end
end
