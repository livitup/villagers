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

ActiveRecord::Schema[8.1].define(version: 2025_11_24_035319) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "conference_programs", force: :cascade do |t|
    t.bigint "conference_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "day_schedules", default: {}
    t.bigint "program_id", null: false
    t.text "public_description"
    t.datetime "updated_at", null: false
    t.index ["conference_id", "program_id"], name: "index_conference_programs_on_conference_id_and_program_id", unique: true
    t.index ["conference_id"], name: "index_conference_programs_on_conference_id"
    t.index ["program_id"], name: "index_conference_programs_on_program_id"
  end

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

  create_table "program_qualifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "program_id", null: false
    t.bigint "qualification_id", null: false
    t.datetime "updated_at", null: false
    t.index ["program_id"], name: "index_program_qualifications_on_program_id"
    t.index ["qualification_id"], name: "index_program_qualifications_on_qualification_id"
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

  create_table "qualifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "village_id", null: false
    t.index ["village_id", "name"], name: "index_qualifications_on_village_id_and_name", unique: true
    t.index ["village_id"], name: "index_qualifications_on_village_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "timeslots", force: :cascade do |t|
    t.bigint "conference_program_id", null: false
    t.datetime "created_at", null: false
    t.integer "current_volunteers_count", default: 0, null: false
    t.datetime "end_time", null: false
    t.integer "max_volunteers", default: 1, null: false
    t.datetime "start_time", null: false
    t.datetime "updated_at", null: false
    t.index ["conference_program_id", "start_time"], name: "index_timeslots_on_conference_program_id_and_start_time", unique: true
    t.index ["conference_program_id"], name: "index_timeslots_on_conference_program_id"
    t.index ["start_time"], name: "index_timeslots_on_start_time"
  end

  create_table "user_qualifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "qualification_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["qualification_id"], name: "index_user_qualifications_on_qualification_id"
    t.index ["user_id", "qualification_id"], name: "index_user_qualifications_on_user_id_and_qualification_id", unique: true
    t.index ["user_id"], name: "index_user_qualifications_on_user_id"
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

  create_table "volunteer_signups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "timeslot_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["timeslot_id"], name: "index_volunteer_signups_on_timeslot_id"
    t.index ["user_id", "timeslot_id"], name: "index_volunteer_signups_on_user_id_and_timeslot_id", unique: true
    t.index ["user_id"], name: "index_volunteer_signups_on_user_id"
  end

  add_foreign_key "conference_programs", "conferences"
  add_foreign_key "conference_programs", "programs"
  add_foreign_key "conference_roles", "conferences"
  add_foreign_key "conference_roles", "users"
  add_foreign_key "conferences", "villages"
  add_foreign_key "program_qualifications", "programs"
  add_foreign_key "program_qualifications", "qualifications"
  add_foreign_key "programs", "villages"
  add_foreign_key "qualifications", "villages"
  add_foreign_key "timeslots", "conference_programs"
  add_foreign_key "user_qualifications", "qualifications"
  add_foreign_key "user_qualifications", "users"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "volunteer_signups", "timeslots"
  add_foreign_key "volunteer_signups", "users"
end
