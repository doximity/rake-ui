# frozen_string_literal: true

json.extract! rake_task_log,
              :id,
              :name,
              :args,
              :environment,
              :rake_command,
              :rake_definition_file,
              :log_file_name,
              :log_file_full_path
