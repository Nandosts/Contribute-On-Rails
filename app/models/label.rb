class Label < ApplicationRecord
  has_many :issue_labels, dependent: :destroy
  has_many :issues, through: :issue_labels

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  before_validation :normalize_name

  def self.normalize_name(name)
    return name if name.blank?

    # Replace hyphens with spaces and capitalize each word (Title Case)
    name.gsub("-", " ").squish.titleize
  end

  private

  def normalize_name
    self.name = self.class.normalize_name(name)
  end
end
