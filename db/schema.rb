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

ActiveRecord::Schema[8.1].define(version: 2025_11_24_012833) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "conference_roles", force: :cascade do |t|
    t.bigint "conference_id", null: false
    t.datetime "created_at", null: false
    t.string "role_name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["conference_id"], name: "index_conference_roles_on_conference_id"
    t.index ["user_id", "conference_id", "role_name"], name: "index_conference_roles_unique", unique: true
    t.index ["user_id"], name: "index_conference_roles_on_user_id"
  end

  create_table "conferences", force: :cascade do |t|
    t.time "conference_hours_end"
    t.time "conference_hours_start"
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "location"
    t.string "name"
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.bigint "village_id", null: false
    t.index ["village_id"], name: "index_conferences_on_village_id"
  end

  create_table "programs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "village_id", null: false
    t.index ["village_id", "name"], name: "index_programs_on_village_id_and_name", unique: true
    t.index ["village_id"], name: "index_programs_on_village_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "user_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "discord"
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "handle"
    t.string "name"
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "signal"
    t.string "twitter"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "villages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "setup_complete", default: false, null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "conference_roles", "conferences"
  add_foreign_key "conference_roles", "users"
  add_foreign_key "conferences", "villages"
  add_foreign_key "programs", "villages"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
end
