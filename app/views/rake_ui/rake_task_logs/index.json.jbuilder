# frozen_string_literal: true

json.rake_task_logs do
  json.array! @rake_task_logs, partial: 'rake_ui/rake_task_logs/rake_task_log', as: :rake_task_log
end
