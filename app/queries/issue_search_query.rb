class IssueSearchQuery
  def initialize(relation = Issue.all, params = {})
    @relation = relation
    @params = params
  end

  def call
    scoped = relation.open.includes(:labels, :project)
    scoped = filter_by_query(scoped)
    scoped = filter_by_project(scoped)
    scoped = filter_by_organization(scoped)
    scoped = filter_by_category(scoped)
    scoped = filter_by_labels(scoped)
    scoped.order(updated_at_from_github: :desc)
  end

  private

  attr_reader :relation, :params

  def filter_by_query(scoped)
    return scoped if params[:q].blank?

    scoped.where("issues.title ILIKE ?", "%#{Issue.sanitize_sql_like(params[:q])}%")
  end

  def filter_by_project(scoped)
    return scoped if params[:project_id].blank?

    scoped.where(project_id: params[:project_id])
  end

  def filter_by_organization(scoped)
    return scoped if params[:organization].blank?

    scoped.joins(:project).where(projects: { github_owner: params[:organization] })
  end

  def filter_by_category(scoped)
    return scoped if params[:category].blank?

    scoped.joins(:project).where(projects: { source_category: params[:category] })
  end

  def filter_by_labels(scoped)
    names = Array(params[:labels]).reject(&:blank?)
    names = Issue::DEFAULT_LABELS if names.empty?
    scoped.joins(:labels).where(labels: { name: names }).distinct
  end
end
