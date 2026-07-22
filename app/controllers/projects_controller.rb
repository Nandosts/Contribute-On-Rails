class ProjectsController < ApplicationController
  def index
    submitted_filters = request.query_parameters.slice("q", "category")
    normalized_filters = submitted_filters.transform_values { |value| value.to_s.strip }.compact_blank
    if submitted_filters != normalized_filters
      return redirect_to projects_path(request.query_parameters.except("q", "category").merge(normalized_filters))
    end

    projects = Project.active
      .joins(:issues)
      .where(issues: { state: "open" })
      .select("projects.*, COUNT(issues.id) AS open_issues_count")
      .group("projects.id")

    @query = params[:q].to_s.strip
    @category = params[:category].presence
    @categories = projects.except(:select, :group, :order).where.not(source_category: nil).distinct.order(:source_category).pluck(:source_category)

    if @query.present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%"
      projects = projects.where(
        "LOWER(projects.name) LIKE :query OR LOWER(projects.github_owner) LIKE :query OR LOWER(projects.github_repo) LIKE :query",
        query: query
      )
    end
    projects = projects.where(source_category: @category) if @category

    @pagy, @projects = pagy(projects.order(:name), limit: 24, size: [ 1, 4, 4, 1 ])
  end

  def show
    @project = Project.find(params[:id])
    @active_labels = effective_issue_labels
    @active_labels = Issue::STARTER_LABELS if !params.key?(:labels) && starter_mode?
    scoped_issues = IssueSearchQuery.new(
      @project.issues,
      labels: @active_labels,
      updated_since: params[:updated_since],
      assignee_status: params[:assignee_status],
      include_project: false
    ).call
    @pagy, @issues = pagy(scoped_issues, limit: 30)
  end
end
