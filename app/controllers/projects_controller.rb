class ProjectsController < ApplicationController
  def index
    @projects = Project.active.includes(:issues).order(:name)
  end

  def show
    @project = Project.find(params[:id])
    @issues = IssueSearchQuery.new(@project.issues, labels: params[:labels]).call
  end
end
