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

ActiveRecord::Schema[7.0].define(version: 2026_03_06_000000) do
  create_table "rake_ui_task_logs", force: :cascade do |t|
    t.string "log_id", null: false
    t.string "name"
    t.string "date"
    t.string "args"
    t.string "environment"
    t.string "rake_command"
    t.string "rake_definition_file"
    t.string "executed_by"
    t.text "output"
    t.boolean "finished", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_rake_ui_task_logs_on_created_at"
    t.index ["log_id"], name: "index_rake_ui_task_logs_on_log_id", unique: true
  end
end
