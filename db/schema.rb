# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_17_163527) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "issue_labels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "issue_id", null: false
    t.bigint "label_id", null: false
    t.datetime "updated_at", null: false
    t.index ["issue_id", "label_id"], name: "index_issue_labels_on_issue_id_and_label_id", unique: true
    t.index ["issue_id"], name: "index_issue_labels_on_issue_id"
    t.index ["label_id"], name: "index_issue_labels_on_label_id"
  end

  create_table "issues", force: :cascade do |t|
    t.jsonb "assignees"
    t.text "body"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.bigint "github_id", null: false
    t.string "github_url", null: false
    t.datetime "last_synced_at"
    t.integer "number", null: false
    t.datetime "opened_at"
    t.bigint "project_id", null: false
    t.string "state", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.datetime "updated_at_from_github"
    t.index ["github_id"], name: "index_issues_on_github_id", unique: true
    t.index ["project_id", "number"], name: "index_issues_on_project_id_and_number", unique: true
    t.index ["project_id", "state"], name: "index_issues_on_project_id_and_state"
    t.index ["project_id"], name: "index_issues_on_project_id"
    t.index ["updated_at_from_github"], name: "index_issues_on_updated_at_from_github"
  end

  create_table "labels", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_labels_on_name", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "github_owner", null: false
    t.string "github_repo", null: false
    t.string "github_url", null: false
    t.datetime "last_synced_at"
    t.string "name", null: false
    t.string "source_category"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_projects_on_active"
    t.index ["github_owner", "github_repo"], name: "index_projects_on_github_owner_and_github_repo", unique: true
    t.index ["source_category"], name: "index_projects_on_source_category"
  end

  add_foreign_key "issue_labels", "issues"
  add_foreign_key "issue_labels", "labels"
  add_foreign_key "issues", "projects"
end
