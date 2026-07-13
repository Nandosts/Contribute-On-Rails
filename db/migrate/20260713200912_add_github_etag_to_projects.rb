class AddGithubEtagToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :github_etag, :string
  end
end
