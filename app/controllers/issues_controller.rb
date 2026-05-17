class IssuesController < ApplicationController
  def index
    scoped_issues = IssueSearchQuery.new(Issue.all, search_params).call
    @project_issue_counts = scoped_issues.unscope(:includes, :order).group(:project_id).count
    @pagy, @issues = pagy(scoped_issues, limit: 30)
    @grouped_issues = @issues.group_by { |issue| [ issue.project.github_owner, issue.project ] }
    @projects = Project.active.order(:github_owner, :github_repo)
    @organizations = Project.active.distinct.order(:github_owner).pluck(:github_owner)
    @categories = Project.active.where.not(source_category: nil).distinct.order(:source_category).pluck(:source_category)
  end

  def random
    project = Project.active.joins(:issues)
      .merge(Issue.open.joins(:labels).where(labels: { name: Issue::DEFAULT_LABELS }))
      .distinct
      .order(Arel.sql("RANDOM()"))
      .first

    redirect_to(project || projects_path)
  end

  private

  def search_params
    params.permit(:q, :project_id, :organization, :category, labels: [])
  end
end
