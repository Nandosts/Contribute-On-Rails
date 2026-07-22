class IssuesController < ApplicationController
  def index
    return redirect_to issues_path(request.query_parameters.slice("group_by_project")) if request.query_parameters.except("page", "locale", "group_by_project").present? && normalized_search_params.values.all?(&:blank?)

    @active_search_params = normalized_search_params
    @group_by_project = params.fetch(:group_by_project, "true") == "true"

    base_scope = Issue.joins(:project).where(projects: { active: true })
    scoped_issues = IssueSearchQuery.new(base_scope, @active_search_params).call
    @project_issue_counts = scoped_issues.unscope(:includes, :order).group(:project_id).count
    @pagy, @issues = pagy(scoped_issues, limit: 30, size: [ 1, 4, 4, 1 ])

    @grouped_issues = @group_by_project ? @issues.group_by { |issue| [ issue.project.github_owner, issue.project ] } : {}

    active_projects = Project.active.where(id: scoped_issues.unscope(:order).select(:project_id)).distinct

    @projects = active_projects.order(:github_owner, :github_repo)
    @organizations = active_projects.distinct.order(:github_owner).pluck(:github_owner)
    @categories = active_projects.where.not(source_category: nil).distinct.order(:source_category).pluck(:source_category)
    @all_labels = Label.joins(issues: :project).where(projects: { active: true }).distinct.order(:name).pluck(:name)
  end

  def random
    base_scope = Issue.joins(:project).where(projects: { active: true })
    project_ids = IssueSearchQuery.new(base_scope, normalized_search_params).call.unscope(:order).distinct.pluck(:project_id)
    project = Project.active.where(id: project_ids).order(Arel.sql("RANDOM()")).first

    redirect_to(project ? project_path(project, request.query_parameters.merge(from_random: true)) : projects_path)
  end

  private

  def search_params
    params.permit(:q, :project_id, :organization, :category, :updated_since, :assignee_status, :sort, labels: [])
  end

  def normalized_search_params
    search_params.to_h.tap do |filters|
      if request.query_parameters.except("page", "locale", "group_by_project").empty?
        filters["labels"] = []
        filters["updated_since"] = "365"
        filters["assignee_status"] = "unassigned"
        filters["sort"] = "recently_updated"
      else
        filters["labels"] = Array(filters["labels"]).reject(&:blank?)
      end
    end
  end
end
