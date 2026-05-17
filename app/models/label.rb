class Label < ApplicationRecord
  has_many :issue_labels, dependent: :destroy
  has_many :issues, through: :issue_labels

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  before_validation :normalize_name

  private

  def normalize_name
    return if name.blank?

    # Replace hyphens with spaces and capitalize each word (Title Case)
    self.name = name.gsub("-", " ").squish.titleize
  end
end
