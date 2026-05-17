class IssueSearchQuery
  def initialize(relation = Issue.all, params = {})
    @relation = relation
    @params = params
  end

  def call
    scoped = relation.open.includes(:project)
    scoped = filter_by_query(scoped)
    scoped = filter_by_project(scoped)
    scoped = filter_by_organization(scoped)
    scoped = filter_by_category(scoped)
    scoped = filter_by_labels(scoped)
    scoped = filter_by_updated_since(scoped)
    scoped = filter_by_assignee_status(scoped)
    scoped.order(updated_at_from_github: :desc)
  end

  private

  attr_reader :relation, :params

  def filter_by_assignee_status(scoped)
    case params[:assignee_status]
    when "unassigned"
      scoped.unassigned
    when "assigned"
      scoped.assigned
    else
      scoped
    end
  end

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

  def filter_by_updated_since(scoped)
    return scoped if params[:updated_since].blank? || params[:updated_since] == "all"

    scoped.where("issues.updated_at_from_github >= ?", updated_since_date)
  end

  def updated_since_date
    params[:updated_since].to_i.days.ago
  end

  def filter_by_labels(scoped)
    names = Array(params[:labels]).reject(&:blank?)
    return scoped.preload(:labels) if names.empty?

    scoped.joins(:labels).where("LOWER(labels.name) IN (?)", names.map(&:downcase)).distinct.preload(:labels)
  end
end
