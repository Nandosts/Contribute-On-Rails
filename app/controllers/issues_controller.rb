class IssuesController < ApplicationController
  def index
    @issues = IssueSearchQuery.new(Issue.all, search_params).call
    @projects = Project.active.order(:name)
    @categories = Project.active.where.not(source_category: nil).distinct.order(:source_category).pluck(:source_category)
  end

  private

  def search_params
    params.permit(:q, :project_id, :category, labels: [])
  end
end
