class RenameSyncRunErrors < ActiveRecord::Migration[8.1]
  def change
    rename_column :sync_runs, :errors, :failure_details
  end
end
