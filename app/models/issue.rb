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

  def assigned?
    assignees.present?
  end

  def assignee_logins
    Array(assignees).map { |a| a["login"] }.compact
  end
end
