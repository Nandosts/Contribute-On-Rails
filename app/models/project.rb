class Project < ApplicationRecord
  has_many :issues, dependent: :destroy

  validates :github_owner, :github_repo, :name, :github_url, presence: true
  validates :github_repo, uniqueness: { scope: :github_owner }

  scope :active, -> { where(active: true) }

  def sync_failed!(error)
    failures = sync_failures_count + 1
    attributes = { last_sync_error: error.message, sync_failures_count: failures }
    attributes[:active] = false if error.respond_to?(:status) && error.status == 404 && failures >= 3
    update!(attributes)
  end
end
