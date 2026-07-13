class Project < ApplicationRecord
  has_many :issues, dependent: :destroy

  validates :github_owner, :github_repo, :name, :github_url, presence: true
  validates :github_repo, uniqueness: { scope: :github_owner }

  scope :active, -> { where(active: true) }

  def github_etags
    return {} if github_etag.blank?
    JSON.parse(github_etag) rescue {}
  end

  def github_etags=(hash)
    self.github_etag = hash.present? ? JSON.generate(hash) : nil
  end
end
