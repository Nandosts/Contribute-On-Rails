class AddFetchAllIssuesToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :fetch_all_issues, :boolean, default: false, null: false
  end
end
