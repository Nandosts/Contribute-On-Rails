class AddSyncObservability < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :last_full_synced_at, :datetime
    add_column :projects, :last_sync_error, :text
    add_column :projects, :sync_failures_count, :integer, default: 0, null: false

    create_table :sync_runs do |t|
      t.string :status, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :projects_total, default: 0, null: false
      t.integer :projects_succeeded, default: 0, null: false
      t.integer :projects_failed, default: 0, null: false
      t.integer :issues_upserted, default: 0, null: false
      t.integer :issues_deleted, default: 0, null: false
      t.jsonb :errors, default: {}, null: false
      t.timestamps
    end

    add_index :sync_runs, :started_at

    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
    add_index :issues, :title, using: :gin, opclass: :gin_trgm_ops, name: "index_issues_on_title_trigram"

    remove_column :projects, :fetch_all_issues, :boolean, default: false, null: false
    remove_column :projects, :github_etag, :string
    remove_column :issues, :body, :text
    remove_column :issues, :closed_at, :datetime
  end
end
