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

ActiveRecord::Schema[7.1].define(version: 2026_11_03_000500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "notices", force: :cascade do |t|
    t.string "company"
    t.string "category"
    t.date "drive_date"
    t.string "eligible_branches", default: [], array: true
    t.decimal "minimum_cgpa", precision: 4, scale: 2
    t.decimal "minimum_class_x_percentage", precision: 5, scale: 2
    t.decimal "minimum_class_xii_percentage", precision: 5, scale: 2
    t.string "arrears_rule"
    t.string "ctc"
    t.string "stipend"
    t.datetime "registration_deadline"
    t.string "registration_url"
    t.string "location"
    t.text "source_text"
    t.jsonb "uncertainties", default: []
    t.string "unrestricted_fields", default: [], array: true
    t.string "status", default: "draft", null: false
    t.bigint "publisher_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company"], name: "index_notices_on_company"
    t.index ["publisher_id"], name: "index_notices_on_publisher_id"
    t.index ["registration_deadline"], name: "index_notices_on_registration_deadline"
    t.index ["status"], name: "index_notices_on_status"
    t.check_constraint "arrears_rule IS NULL OR (arrears_rule::text = ANY (ARRAY['no_standing_arrears'::character varying, 'standing_arrears_allowed'::character varying]::text[]))", name: "notices_arrears_rule_check"
    t.check_constraint "minimum_cgpa IS NULL OR minimum_cgpa >= 0::numeric AND minimum_cgpa <= 10::numeric", name: "notices_minimum_cgpa_range_check"
    t.check_constraint "minimum_class_x_percentage IS NULL OR minimum_class_x_percentage >= 0::numeric AND minimum_class_x_percentage <= 100::numeric", name: "notices_minimum_class_x_range_check"
    t.check_constraint "minimum_class_xii_percentage IS NULL OR minimum_class_xii_percentage >= 0::numeric AND minimum_class_xii_percentage <= 100::numeric", name: "notices_minimum_class_xii_range_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'published'::character varying]::text[])", name: "notices_status_check"
  end

  create_table "registrations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "notice_id", null: false
    t.string "status", default: "registered", null: false
    t.datetime "registered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notice_id"], name: "index_registrations_on_notice_id"
    t.index ["user_id", "notice_id"], name: "index_registrations_on_user_id_and_notice_id", unique: true
    t.index ["user_id"], name: "index_registrations_on_user_id"
  end

  create_table "reminders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "notice_id", null: false
    t.string "kind", null: false
    t.datetime "scheduled_at", null: false
    t.datetime "sent_at"
    t.datetime "failed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notice_id"], name: "index_reminders_on_notice_id"
    t.index ["scheduled_at"], name: "index_reminders_on_scheduled_at"
    t.index ["sent_at"], name: "index_reminders_on_sent_at"
    t.index ["user_id", "notice_id", "kind"], name: "index_reminders_on_user_id_and_notice_id_and_kind", unique: true
    t.index ["user_id"], name: "index_reminders_on_user_id"
    t.check_constraint "kind::text = ANY (ARRAY['publication'::character varying, 'reminder_24h'::character varying, 'reminder_2h'::character varying]::text[])", name: "reminders_kind_check"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "student", null: false
    t.string "branch"
    t.decimal "cgpa", precision: 4, scale: 2
    t.decimal "class_x_percentage", precision: 5, scale: 2
    t.decimal "class_xii_percentage", precision: 5, scale: 2
    t.boolean "standing_arrears", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.check_constraint "cgpa IS NULL OR cgpa >= 0::numeric AND cgpa <= 10::numeric", name: "users_cgpa_range_check"
    t.check_constraint "class_x_percentage IS NULL OR class_x_percentage >= 0::numeric AND class_x_percentage <= 100::numeric", name: "users_class_x_range_check"
    t.check_constraint "class_xii_percentage IS NULL OR class_xii_percentage >= 0::numeric AND class_xii_percentage <= 100::numeric", name: "users_class_xii_range_check"
    t.check_constraint "role::text = ANY (ARRAY['student'::character varying, 'coordinator'::character varying]::text[])", name: "users_role_check"
  end

  add_foreign_key "notices", "users", column: "publisher_id"
  add_foreign_key "registrations", "notices"
  add_foreign_key "registrations", "users"
  add_foreign_key "reminders", "notices"
  add_foreign_key "reminders", "users"
  add_foreign_key "sessions", "users"
end
