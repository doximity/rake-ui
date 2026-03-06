# frozen_string_literal: true

module RakeUi
  module Storage
    class FileStore
      REPOSITORY_DIR = -> { Rails.root.join("tmp", "rake_ui") }
      FILE_DELIMITER = "____"
      FILE_ITEM_SEPARATOR = ": "
      FINISHED_STRING = "+++++ COMMAND FINISHED +++++"
      TASK_HEADER_OUTPUT_DELIMITER = "-------------------------------"
      ID_DATE_FORMAT = "%Y-%m-%d-%H-%M-%S%z"

      def create_log(name:, rake_definition_file:, rake_command:, raker_id:, args: nil, environment: nil, executed_by: nil)
        create_tmp_file_dir

        date = Time.now.strftime(ID_DATE_FORMAT)
        id = "#{date}#{FILE_DELIMITER}#{raker_id}"
        log_file_name = "#{id}.txt"
        log_file_full_path = repository_dir.join(log_file_name).to_s

        File.open(log_file_full_path, "w+") do |f|
          f.puts "id#{FILE_ITEM_SEPARATOR}#{id}"
          f.puts "name#{FILE_ITEM_SEPARATOR}#{name}"
          f.puts "date#{FILE_ITEM_SEPARATOR}#{date}"
          f.puts "args#{FILE_ITEM_SEPARATOR}#{args}"
          f.puts "environment#{FILE_ITEM_SEPARATOR}#{environment}"
          f.puts "rake_command#{FILE_ITEM_SEPARATOR}#{rake_command}"
          f.puts "rake_definition_file#{FILE_ITEM_SEPARATOR}#{rake_definition_file}"
          f.puts "log_file_name#{FILE_ITEM_SEPARATOR}#{log_file_name}"
          f.puts "log_file_full_path#{FILE_ITEM_SEPARATOR}#{log_file_full_path}"
          f.puts "executed_by#{FILE_ITEM_SEPARATOR}#{executed_by}"

          f.puts TASK_HEADER_OUTPUT_DELIMITER.to_s
          f.puts " INVOKED RAKE TASK OUTPUT BELOW"
          f.puts TASK_HEADER_OUTPUT_DELIMITER.to_s
        end

        RakeUi::RakeTaskLog.new(
          id: id,
          name: name,
          args: args,
          environment: environment,
          rake_command: rake_command,
          rake_definition_file: rake_definition_file,
          log_file_name: log_file_name,
          log_file_full_path: log_file_full_path,
          executed_by: executed_by
        )
      end

      def all
        create_tmp_file_dir

        Dir.children(repository_dir)
          .sort!
          .reverse!
          .first(200)
          .map { |log| build_from_file(log) }
      end

      def find_by_id(id)
        all.find do |a|
          a.id == id || a.id == RakeUi::RakeTask.to_safe_identifier(id)
        end
      end

      def truncate
        FileUtils.rm_rf(Dir.glob(repository_dir.to_s + "/*"))
      end

      def cleanup_old_logs
        create_tmp_file_dir

        all_files = Dir.children(repository_dir).sort.reverse
        files_to_delete = all_files.drop(200)

        files_to_delete.each do |file|
          File.delete(File.join(repository_dir, file))
        rescue => e
          Rails.logger.warn("RakeUi: Failed to delete old log #{file} - #{e.message}")
        end

        files_to_delete.size
      end

      def file_contents(log)
        File.read(log.log_file_full_path)
      end

      def finished?(log)
        file_contents(log).include?(FINISHED_STRING)
      end

      def rake_command_with_logging(log)
        "#{log.rake_command} 2>&1 >> #{log.log_file_full_path}"
      end

      def command_to_mark_log_finished(log)
        "echo #{FINISHED_STRING} >> #{log.log_file_full_path}"
      end

      private

      def repository_dir
        REPOSITORY_DIR.call
      end

      def create_tmp_file_dir
        FileUtils.mkdir_p(repository_dir.to_s)
      end

      def build_from_file(log_file_name)
        RakeUi::RakeTaskLog.new(
          id: log_file_name.gsub(".txt", ""),
          log_file_name: log_file_name,
          log_file_full_path: Rails.root.join(repository_dir, log_file_name).to_s
        )
      end
    end
  end
end

