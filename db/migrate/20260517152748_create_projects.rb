class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :github_owner, null: false
      t.string :github_repo, null: false
      t.string :name, null: false
      t.text :description
      t.string :source_category
      t.string :github_url, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_synced_at
      t.timestamps
    end

    add_index :projects, %i[github_owner github_repo], unique: true
    add_index :projects, :active
    add_index :projects, :source_category
  end
end
