# frozen_string_literal: true

module RakeUi
  class TaskLogRecord < ActiveRecord::Base
    self.table_name = "rake_ui_task_logs"
  end
end
