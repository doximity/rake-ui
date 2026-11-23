# frozen_string_literal: true

require "ostruct"
require "open3"
require "shellwords"

module RakeUi
  class RakeTaskLog < OpenStruct
    # Raised when the pod serving the request no longer has the log file, for
    # example when the file was removed between listing and reading it.
    class MissingLogFile < StandardError; end

    # year-month-day-hour(24hour time)-minute-second-nanosecond-utc
    ID_DATE_FORMAT = "%Y-%m-%d-%H-%M-%S-%N%z"
    REPOSITORY_DIR = Rails.root.join("tmp", "rake_ui")
    FILE_DELIMITER = "____"
    FINISHED_STRING = "+++++ COMMAND FINISHED +++++"
    TASK_HEADER_OUTPUT_DELIMITER = "-------------------------------"
    FILE_ITEM_SEPARATOR = ": "

    def self.repository_dir
      if RakeUi.log_directory.present?
        Pathname.new(RakeUi.log_directory.to_s)
      else
        REPOSITORY_DIR
      end
    end

    def self.create_tmp_file_dir
      FileUtils.mkdir_p(repository_dir.to_s)
    end

    def self.truncate
      return if repository_dir.root?

      FileUtils.rm_rf(repository_dir.children)
    end

    def self.build_from_file(log_file_name)
      log_file_name.split(FILE_DELIMITER)

      new(
        id: log_file_name.gsub(".txt", ""),
        log_file_name: log_file_name,
        log_file_full_path: repository_dir.join(log_file_name).to_s
      )
    end

    def self.build_new_for_command(name:, rake_definition_file:, rake_command:, raker_id:, args: nil, environment: nil)
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

        f.puts TASK_HEADER_OUTPUT_DELIMITER.to_s
        f.puts " INVOKED RAKE TASK OUTPUT BELOW"
        f.puts TASK_HEADER_OUTPUT_DELIMITER.to_s
      end

      new(id: id,
        name: name,
        args: args,
        environment: environment,
        rake_command: rake_command,
        rake_definition_file: rake_definition_file,
        log_file_name: log_file_name,
        log_file_full_path: log_file_full_path)
    end

    def self.all
      create_tmp_file_dir

      local = Dir.entries(repository_dir).reject { |file|
        file == "." || file == ".."
      }.map do |log|
        RakeUi::RakeTaskLog.build_from_file(log)
      end

      remote = log_list_ids.map { |id| build_from_id(id) }
      (local + remote).uniq(&:id)
    end

    def self.log_list_ids
      Array(RakeUi.log_list&.call)
    rescue => e
      Rails.logger&.warn("[rake_ui] log list failed error=#{e.class}: #{e.message.to_s[0, 200]}")
      []
    end

    def self.build_from_id(id)
      id = id.to_s.delete_suffix(".txt")
      new(id: id, log_file_name: "#{id}.txt")
    end

    def self.find_by_id(id)
      if RakeUi.log_reader
        log_file_name = "#{id.to_s.delete_suffix(".txt")}.txt"
        local_path = begin
          path = repository_dir.join(log_file_name)
          build_from_file(log_file_name) if path.basename.to_s == log_file_name && path.exist?
        rescue ArgumentError, SystemCallError
          nil
        end
        return local_path if local_path

        return build_from_id(id)
      end

      all.find do |a|
        a.id == id || a.id == RakeUi::RakeTask.to_safe_identifier(id)
      end
    end

    def self.for(rake_ui_rake_task)
      all.select do |history|
        history.id == rake_ui_rake_task.id
      end
    end

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

    def rake_command_with_logging
      "#{rake_command} >> #{Shellwords.escape(log_file_full_path)} 2>&1"
    end

    def log_source
      if log_file_full_path.present? || RakeUi.log_reader.nil?
        return {content: file_contents, finished: finished?}
      end

      result = begin
        RakeUi.log_reader.call(self)
      rescue => e
        Rails.logger&.warn("[rake_ui] log reader failed id=#{id.to_s.inspect} error=#{e.class}: #{e.message.to_s[0, 200]}")
        nil
      end
      raise MissingLogFile, id unless result.is_a?(Hash)

      {content: result[:content].to_s, finished: !!result[:finished]}
    end

    def run_with_log_writer(writer)
      publish_log_event(writer, :start)

      status = nil
      last_line = nil

      File.open(log_file_full_path, "a") do |file|
        Open3.popen2e(rake_command) do |stdin, stdout_and_stderr, wait_thread|
          stdin.close

          stdout_and_stderr.each_line do |line|
            last_line = line
            file.write(line)
            file.flush
            publish_log_event(writer, :progress, line)
          end

          status = wait_thread.value
        end
      ensure
        file.write("\n") if last_line && !last_line.end_with?("\n")
        file.puts FINISHED_STRING
        file.flush
      end

      if status&.success?
        publish_log_event(writer, :finished)
      else
        publish_log_event(writer, :error, status ? status.to_s : "command failed")
      end
    rescue => e
      publish_log_event(writer, :error, e.message)
    end

    def file_contents
      path = log_file_full_path
      raise MissingLogFile, id if path.blank?

      @file_contents ||= File.read(path)
    rescue Errno::ENOENT
      raise MissingLogFile, path
    end

    def command_to_mark_log_finished
      "echo #{Shellwords.escape(FINISHED_STRING)} >> #{Shellwords.escape(log_file_full_path)}"
    end

    def finished?
      file_contents.b.include? FINISHED_STRING.b
    end

    private

    # A failing writer must not abort the task.
    def publish_log_event(writer, event, payload = nil)
      writer.call(self, event, payload)
    rescue => e
      Rails.logger&.warn("[rake_ui] log writer failed event=#{event} error=#{e.class}: #{e.message.to_s[0, 200]}")
    end

    # converts standard formatted file id into an object
    def parsed_log_file_name
      @parsed_log_file_name ||= {}.tap do |parsed|
        date, name = id.split(FILE_DELIMITER, 2)
        parsed[:date] = date
        parsed[:name] = name && RakeUi::RakeTask.from_safe_identifier(name)
      end
    end

    # converts our persisted rake logs files into an object
    # name: foo
    # id: baz
    #
    # into
    #
    # { name: 'foo', id: 'baz' }
    def parsed_file_contents
      return @parsed_file_contents if defined? @parsed_file_contents

      path = self[:log_file_full_path]
      return @parsed_file_contents = {}.with_indifferent_access if path.blank?

      @parsed_file_contents = {}.tap do |parsed|
        File.foreach(path).first(9).each do |line|
          name, value = line.split(FILE_ITEM_SEPARATOR, 2)
          next unless name

          parsed[name] = value && value.delete("\n")
        end
      end.with_indifferent_access
    rescue Errno::ENOENT
      @parsed_file_contents = {}.with_indifferent_access
    end
  end
end
