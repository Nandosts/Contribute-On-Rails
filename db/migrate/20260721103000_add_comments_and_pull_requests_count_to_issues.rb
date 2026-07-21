class AddCommentsAndPullRequestsCountToIssues < ActiveRecord::Migration[8.1]
  def change
    add_column :issues, :comments_count, :integer, default: 0, null: false
    add_column :issues, :pull_requests_count, :integer, default: 0, null: false
  end
end
