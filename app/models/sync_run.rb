class SyncRun < ApplicationRecord
  STATUSES = %w[running succeeded failed].freeze

  validates :status, inclusion: { in: STATUSES }
end
