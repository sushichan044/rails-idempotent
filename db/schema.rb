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

ActiveRecord::Schema[8.0].define(version: 2025_03_08_065613) do
  create_table "idempotent_requests", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "locked_at"
    t.string "request_method", default: "", null: false
    t.string "request_path", default: "", null: false
    t.json "request_params", default: {}, null: false
    t.integer "response_code", default: 0, null: false
    t.string "response_body", default: "", null: false
    t.json "response_headers", default: {}, null: false
    t.index ["key"], name: "index_idempotent_requests_on_key", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.string "title", null: false
    t.string "content", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "posts", "users"
end
