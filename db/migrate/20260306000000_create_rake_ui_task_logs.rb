# frozen_string_literal: true

class CreateRakeUiTaskLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :rake_ui_task_logs do |t|
      t.string :log_id, null: false, index: {unique: true}
      t.string :name
      t.string :date
      t.string :args
      t.string :environment
      t.string :rake_command
      t.string :rake_definition_file
      t.string :executed_by
      t.text :output
      t.boolean :finished, default: false, null: false

      t.timestamps
    end

    add_index :rake_ui_task_logs, :created_at
  end
end
