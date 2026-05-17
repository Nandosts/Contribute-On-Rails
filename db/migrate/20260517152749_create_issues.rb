class CreateIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :issues do |t|
      t.references :project, null: false, foreign_key: true
      t.bigint :github_id, null: false
      t.integer :number, null: false
      t.string :title, null: false
      t.text :body
      t.string :state, null: false
      t.string :github_url, null: false
      t.datetime :opened_at
      t.datetime :updated_at_from_github
      t.datetime :closed_at
      t.datetime :last_synced_at
      t.timestamps
    end

    add_index :issues, :github_id, unique: true
    add_index :issues, %i[project_id number], unique: true
    add_index :issues, %i[project_id state]
    add_index :issues, :updated_at_from_github
  end
end
