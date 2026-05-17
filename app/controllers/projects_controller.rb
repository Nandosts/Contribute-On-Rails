class ProjectsController < ApplicationController
  def index
    @projects = Project.active
      .left_joins(:issues)
      .select("projects.*, COUNT(CASE WHEN issues.state = 'open' THEN 1 END) AS open_issues_count")
      .group("projects.id")
      .order(:name)
  end

  def show
    @project = Project.find(params[:id])
    @issues = IssueSearchQuery.new(@project.issues, labels: params[:labels], updated_since: params[:updated_since]).call
  end
end
