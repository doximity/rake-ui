# frozen_string_literal: true

module RakeUi
  class TaskLogRecord < ActiveRecord::Base
    self.table_name = "rake_ui_task_logs"

    MAX_STRING_LENGTH = 255
    MAX_OUTPUT_LENGTH = 16_777_215

    validates :log_id, length: {maximum: MAX_STRING_LENGTH}
    validates :name, length: {maximum: MAX_STRING_LENGTH}, allow_nil: true
    validates :date, length: {maximum: MAX_STRING_LENGTH}, allow_nil: true
    validates :args, length: {maximum: MAX_STRING_LENGTH}, allow_nil: true
    validates :environment, length: {maximum: MAX_STRING_LENGTH}, allow_nil: true
    validates :rake_command, length: {maximum: MAX_STRING_LENGTH}, allow_nil: true
    validates :rake_definition_file, length: {maximum: MAX_STRING_LENGTH}, allow_nil: true
    validates :executed_by, length: {maximum: MAX_STRING_LENGTH}, allow_nil: true
    validates :output, length: {maximum: MAX_OUTPUT_LENGTH}, allow_nil: true
  end
end
