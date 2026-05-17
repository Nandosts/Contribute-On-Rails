class Label < ApplicationRecord
  has_many :issue_labels, dependent: :destroy
  has_many :issues, through: :issue_labels

  validates :name, presence: true, uniqueness: true
end
