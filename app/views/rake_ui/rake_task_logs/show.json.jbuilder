# frozen_string_literal: true

json.rake_task_log @rake_task_log, partial: "rake_ui/rake_task_logs/rake_task_log", as: :rake_task_log

json.rake_task_log_content @rake_task_log_content

json.is_rake_task_log_finished @is_rake_task_log_finished
