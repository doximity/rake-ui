# frozen_string_literal: true

module RakeUi
  module Storage
    class DatabaseStore
      FINISHED_STRING = "+++++ COMMAND FINISHED +++++"
      TASK_HEADER_OUTPUT_DELIMITER = "-------------------------------"
      ID_DATE_FORMAT = "%Y-%m-%d-%H-%M-%S%z"
      FILE_DELIMITER = "____"
      TMP_DIR = -> { Rails.root.join("tmp", "rake_ui") }

      # Maximum lengths for database string columns (VARCHAR 255 default)
      MAX_STRING_LENGTH = 255
      # Maximum length for text column output (~16 MB, safe for MySQL MEDIUMTEXT / unlimited in Postgres & SQLite)
      MAX_OUTPUT_LENGTH = 16_777_215

      def create_log(name:, rake_definition_file:, rake_command:, raker_id:, args: nil, environment: nil, executed_by: nil)
        ensure_tmp_dir

        date = Time.now.strftime(ID_DATE_FORMAT)
        id = "#{date}#{FILE_DELIMITER}#{raker_id}"
        tmp_file = tmp_file_path(id)

        # Write initial header to the temp file (used for live streaming)
        File.open(tmp_file, "w+") do |f|
          f.puts TASK_HEADER_OUTPUT_DELIMITER.to_s
          f.puts " INVOKED RAKE TASK OUTPUT BELOW"
          f.puts TASK_HEADER_OUTPUT_DELIMITER.to_s
        end

        # Persist metadata to the database (truncate to fit column limits)
        RakeUi::TaskLogRecord.create!(
          log_id: truncate_string(id),
          name: truncate_string(name),
          date: truncate_string(date),
          args: truncate_string(args),
          environment: truncate_string(environment),
          rake_command: truncate_string(rake_command),
          rake_definition_file: truncate_string(rake_definition_file),
          executed_by: truncate_string(executed_by),
          output: nil,
          finished: false
        )

        RakeUi::RakeTaskLog.new(
          id: id,
          name: name,
          date: date,
          args: args,
          environment: environment,
          rake_command: rake_command,
          rake_definition_file: rake_definition_file,
          executed_by: executed_by,
          log_file_name: nil,
          log_file_full_path: tmp_file
        )
      end

      def all
        RakeUi::TaskLogRecord
          .order(created_at: :desc)
          .limit(200)
          .map { |record| record_to_log(record) }
      end

      def find_by_id(id)
        safe_id = RakeUi::RakeTask.to_safe_identifier(id)
        record = RakeUi::TaskLogRecord.find_by(log_id: id) ||
          RakeUi::TaskLogRecord.find_by(log_id: safe_id)

        record_to_log(record) if record
      end

      def truncate
        # Delete temp files for tracked records only
        RakeUi::TaskLogRecord.pluck(:log_id).each do |log_id|
          tmp = tmp_file_path(log_id)
          File.delete(tmp) if File.exist?(tmp)
        end
        RakeUi::TaskLogRecord.delete_all
      end

      def cleanup_old_logs
        ids_to_keep = RakeUi::TaskLogRecord
          .order(created_at: :desc)
          .limit(200)
          .pluck(:id)

        RakeUi::TaskLogRecord.where.not(id: ids_to_keep).delete_all
      end

      def file_contents(log)
        record = find_record(log)

        # If finished and output is persisted in DB, return from DB
        if record&.finished? && record.output.present?
          return record.output
        end

        # Otherwise, read from the temp file (live streaming)
        tmp_file = tmp_file_path(log.id)
        if File.exist?(tmp_file)
          content = File.read(tmp_file)

          # If the task just finished, persist to DB
          if content.include?(FINISHED_STRING) && record
            record.update!(output: truncate_output(content), finished: true)
            # begin
            #   File.delete(tmp_file)
            # rescue
            #   nil
            # end
          end

          content
        else
          record&.output || ""
        end
      end

      def finished?(log)
        record = find_record(log)
        return true if record&.finished?

        # Check temp file as fallback
        tmp_file = tmp_file_path(log.id)
        if File.exist?(tmp_file)
          content = File.read(tmp_file)
          if content.include?(FINISHED_STRING)
            # Persist to DB and mark finished
            record&.update!(output: truncate_output(content), finished: true)
            begin
              File.delete(tmp_file)
            rescue
              nil
            end
            return true
          end
        end

        false
      end

      def rake_command_with_logging(log)
        tmp_file = tmp_file_path(log.id)
        "#{log.rake_command} 2>&1 >> #{tmp_file}"
      end

      def command_to_mark_log_finished(log)
        tmp_file = tmp_file_path(log.id)
        "echo #{FINISHED_STRING} >> #{tmp_file}"
      end

      private

      def find_record(log)
        RakeUi::TaskLogRecord.find_by(log_id: log.id)
      end

      def tmp_file_path(id)
        TMP_DIR.call.join("#{id}.txt").to_s
      end

      def ensure_tmp_dir
        FileUtils.mkdir_p(TMP_DIR.call.to_s)
      end

      def truncate_string(value)
        return value unless value.is_a?(String) && value.length > MAX_STRING_LENGTH

        value[0, MAX_STRING_LENGTH]
      end

      def truncate_output(value)
        return value unless value.is_a?(String) && value.length > MAX_OUTPUT_LENGTH

        value[0, MAX_OUTPUT_LENGTH]
      end

      def record_to_log(record)
        tmp_file = tmp_file_path(record.log_id)
        full_path = File.exist?(tmp_file) ? tmp_file : nil

        RakeUi::RakeTaskLog.new(
          id: record.log_id,
          name: record.name,
          date: record.date,
          args: record.args,
          environment: record.environment,
          rake_command: record.rake_command,
          rake_definition_file: record.rake_definition_file,
          executed_by: record.executed_by,
          log_file_name: nil,
          log_file_full_path: full_path
        )
      end
    end
  end
end
