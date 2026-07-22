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

ActiveRecord::Schema[8.1].define(version: 2026_07_22_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

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
    t.integer "comments_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "github_id", null: false
    t.string "github_url", null: false
    t.datetime "last_synced_at"
    t.integer "number", null: false
    t.datetime "opened_at"
    t.bigint "project_id", null: false
    t.integer "pull_requests_count", default: 0, null: false
    t.string "state", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.datetime "updated_at_from_github"
    t.index ["github_id"], name: "index_issues_on_github_id", unique: true
    t.index ["project_id", "number"], name: "index_issues_on_project_id_and_number", unique: true
    t.index ["project_id", "state"], name: "index_issues_on_project_id_and_state"
    t.index ["project_id"], name: "index_issues_on_project_id"
    t.index ["title"], name: "index_issues_on_title_trigram", opclass: :gin_trgm_ops, using: :gin
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
    t.datetime "last_full_synced_at"
    t.text "last_sync_error"
    t.datetime "last_synced_at"
    t.string "name", null: false
    t.string "source_category"
    t.integer "sync_failures_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_projects_on_active"
    t.index ["github_owner", "github_repo"], name: "index_projects_on_github_owner_and_github_repo", unique: true
    t.index ["source_category"], name: "index_projects_on_source_category"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "sync_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "errors", default: {}, null: false
    t.datetime "finished_at"
    t.integer "issues_deleted", default: 0, null: false
    t.integer "issues_upserted", default: 0, null: false
    t.integer "projects_failed", default: 0, null: false
    t.integer "projects_succeeded", default: 0, null: false
    t.integer "projects_total", default: 0, null: false
    t.datetime "started_at", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["started_at"], name: "index_sync_runs_on_started_at"
  end

  add_foreign_key "issue_labels", "issues"
  add_foreign_key "issue_labels", "labels"
  add_foreign_key "issues", "projects"
end
