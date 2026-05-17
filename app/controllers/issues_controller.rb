class IssuesController < ApplicationController
  def index
    return redirect_to issues_path if request.query_parameters.present? && normalized_search_params.values.all?(&:blank?)

    scoped_issues = IssueSearchQuery.new(Issue.all, search_params).call
    @project_issue_counts = scoped_issues.unscope(:includes, :order).group(:project_id).count
    @pagy, @issues = pagy(scoped_issues, limit: 30)
    @grouped_issues = @issues.group_by { |issue| [ issue.project.github_owner, issue.project ] }
    @projects = Project.active.order(:github_owner, :github_repo)
    @organizations = Project.active.distinct.order(:github_owner).pluck(:github_owner)
    @categories = Project.active.where.not(source_category: nil).distinct.order(:source_category).pluck(:source_category)
  end

  def random
    project_ids = IssueSearchQuery.new.call.unscope(:order).pluck(:project_id).uniq
    project = Project.active.where(id: project_ids).order(Arel.sql("RANDOM()")).first

    redirect_to(project ? project_path(project, from_random: true) : projects_path)
  end

  private

  def search_params
    params.permit(:q, :project_id, :organization, :category, labels: [])
  end

  def normalized_search_params
    search_params.to_h.tap do |filters|
      filters["labels"] = Array(filters["labels"]).reject(&:blank?)
    end
  end
end
