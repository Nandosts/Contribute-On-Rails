class ProjectsController < ApplicationController
  def index
    @projects = Project.active
      .joins(:issues)
      .where(issues: { state: "open" })
      .select("projects.*, COUNT(issues.id) AS open_issues_count")
      .group("projects.id")
      .order(:name)
  end

  def show
    @project = Project.find(params[:id])
    @active_labels = Array(params[:labels]).reject(&:blank?)
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
