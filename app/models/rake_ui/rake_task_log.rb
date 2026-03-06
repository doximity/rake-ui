# frozen_string_literal: true

module RakeUi
  class RakeTaskLog < OpenStruct
    # year-month-day-hour(24hour time)-minute-second-utc
    ID_DATE_FORMAT = "%Y-%m-%d-%H-%M-%S%z"
    REPOSITORY_DIR = -> { Rails.root.join("tmp", "rake_ui") }
    FILE_DELIMITER = "____"
    FINISHED_STRING = "+++++ COMMAND FINISHED +++++"
    TASK_HEADER_OUTPUT_DELIMITER = "-------------------------------"
    FILE_ITEM_SEPARATOR = ": "

    # Legacy constant accessor kept for backward compatibility
    def self.repository_dir
      REPOSITORY_DIR.call
    end

    # --- Delegated class methods (route through the configured store) ---

    def self.create_tmp_file_dir
      store = RakeUi.store
      store.send(:create_tmp_file_dir) if store.respond_to?(:create_tmp_file_dir, true)
    end

    def self.truncate
      RakeUi.store.truncate
    end

    def self.cleanup_old_logs
      RakeUi.store.cleanup_old_logs
    end

    def self.build_from_file(log_file_name)
      # Only meaningful for file store; kept for backward compatibility
      if RakeUi.store.is_a?(RakeUi::Storage::FileStore)
        RakeUi.store.send(:build_from_file, log_file_name)
      else
        raise NotImplementedError, "build_from_file is only available with the :file storage backend"
      end
    end

    def self.build_new_for_command(name:, rake_definition_file:, rake_command:, raker_id:, args: nil, environment: nil, executed_by: nil)
      RakeUi.store.create_log(
        name: name,
        rake_definition_file: rake_definition_file,
        rake_command: rake_command,
        raker_id: raker_id,
        args: args,
        environment: environment,
        executed_by: executed_by
      )
    end

    def self.all
      RakeUi.store.all
    end

    def self.find_by_id(id)
      RakeUi.store.find_by_id(id)
    end

    def self.for(rake_ui_rake_task)
      all.select do |history|
        history.id == rake_ui_rake_task.id
      end
    end

    # --- Instance methods ---

    def name
      super || parsed_log_file_name[:name] || parsed_file_contents[:name]
    end

    def date
      super || parsed_log_file_name[:date] || parsed_file_contents[:date]
    end

    def args
      super || parsed_file_contents[:args]
    end

    def environment
      super || parsed_file_contents[:environment]
    end

    def rake_command
      super || parsed_file_contents[:rake_command]
    end

    def rake_definition_file
      super || parsed_file_contents[:rake_definition_file]
    end

    def log_file_name
      super || parsed_file_contents[:log_file_name]
    end

    def log_file_full_path
      super || parsed_file_contents[:log_file_full_path]
    end

    def executed_by
      super || parsed_file_contents[:executed_by]
    end

    def rake_command_with_logging
      RakeUi.store.rake_command_with_logging(self)
    end

    def file_contents
      @file_contents ||= RakeUi.store.file_contents(self)
    end

    def command_to_mark_log_finished
      RakeUi.store.command_to_mark_log_finished(self)
    end

    def finished?
      RakeUi.store.finished?(self)
    end

    private

    def parsed_log_file_name
      @parsed_log_file_name ||= {}.tap do |parsed|
        date, name = id.split(FILE_DELIMITER, 2)
        parsed[:date] = date
        parsed[:name] = RakeUi::RakeTask.from_safe_identifier(name)
      end
    end

    def parsed_file_contents
      return @parsed_file_contents if defined? @parsed_file_contents

      # For database backend, there's no file to parse — data comes from attributes
      unless RakeUi.store.is_a?(RakeUi::Storage::FileStore) && log_file_full_path
        @parsed_file_contents = {}.with_indifferent_access
        return @parsed_file_contents
      end

      @parsed_file_contents = {}.tap do |parsed|
        File.foreach(log_file_full_path).first(10).each do |line|
          name, value = line.split(FILE_ITEM_SEPARATOR, 2)
          next unless name

          parsed[name] = value && value.delete("\n")
        end
      end.with_indifferent_access
    end
  end
end
