class ProjectsController < ApplicationController
  def index
    @projects = Project.active
      .joins(:issues)
      .where(issues: { state: "open" })
      .where("issues.updated_at_from_github >= ?", 1.year.ago)
      .select("projects.*, COUNT(issues.id) AS open_issues_count")
      .group("projects.id")
      .order(:name)
  end

  def show
    @project = Project.find(params[:id])
    updated_since = params[:updated_since]
    updated_since = "365" if updated_since.nil?

    assignee_status = params[:assignee_status]
    assignee_status = "unassigned" if assignee_status.nil?

    @issues = IssueSearchQuery.new(@project.issues, labels: params[:labels], updated_since: updated_since, assignee_status: assignee_status).call
  end
end
