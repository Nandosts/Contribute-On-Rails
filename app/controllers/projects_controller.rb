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
    scoped_issues = IssueSearchQuery.new(
      @project.issues,
      labels: params[:labels],
      updated_since: params[:updated_since],
      assignee_status: params[:assignee_status],
      starter_mode: starter_mode?,
      include_project: false
    ).call
    @pagy, @issues = pagy(scoped_issues, limit: 30)
  end
end
