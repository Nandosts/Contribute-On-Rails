class Project < ApplicationRecord
  has_many :issues, dependent: :destroy

  validates :github_owner, :github_repo, :name, :github_url, presence: true
  validates :github_repo, uniqueness: { scope: :github_owner }

  scope :active, -> { where(active: true) }
end
