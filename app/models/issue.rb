class Issue < ApplicationRecord
  DEFAULT_LABELS = [ "good first issue", "help wanted" ].freeze

  belongs_to :project
  has_many :issue_labels, dependent: :destroy
  has_many :labels, through: :issue_labels

  validates :github_id, :number, :title, :state, :github_url, presence: true
  validates :github_id, uniqueness: true
  validates :number, uniqueness: { scope: :project_id }

  scope :open, -> { where(state: "open") }
  scope :unassigned, -> { where("assignees IS NULL OR assignees = '[]'::jsonb") }
  scope :assigned, -> { where("assignees IS NOT NULL AND assignees != '[]'::jsonb") }

  def assigned?
    assignees.present?
  end

  def assignee_logins
    Array(assignees).map { |a| a["login"] }.compact
  end
end
