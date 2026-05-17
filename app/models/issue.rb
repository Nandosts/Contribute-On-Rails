class Issue < ApplicationRecord
  DEFAULT_LABELS = [ "Good First Issue", "Help Wanted" ].freeze

  belongs_to :project
  has_many :issue_labels, dependent: :destroy
  has_many :labels, through: :issue_labels

  validates :github_id, :number, :title, :state, :github_url, presence: true
  validates :github_id, uniqueness: true
  validates :number, uniqueness: { scope: :project_id }

  scope :open, -> { where(state: "open") }
  scope :unassigned, -> { where("assignees IS NULL OR jsonb_array_length(assignees) = 0") }
  scope :assigned, -> { where("jsonb_array_length(assignees) > 0") }

  before_destroy :remember_labels, prepend: true
  after_destroy :cleanup_orphaned_labels

  def assigned?
    assignees.present?
  end

  def assignee_logins
    Array(assignees).map { |a| a["login"] }.compact
  end

  private

  def remember_labels
    @associated_labels = labels.to_a
  end

  def cleanup_orphaned_labels
    Array(@associated_labels).each do |label|
      unless IssueLabel.where(label_id: label.id).where.not(issue_id: id).exists?
        label.destroy
      end
    end
  end
end
