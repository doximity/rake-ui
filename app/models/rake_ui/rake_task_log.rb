# frozen_string_literal: true

module RakeUi
  class RakeTaskLog < OpenStruct
    # year-month-day-hour(24hour time)-minute-second-utc
    ID_DATE_FORMAT = "%Y-%m-%d-%H-%M-%S%z"
    REPOSITORY_DIR = Rails.root.join("tmp", "rake_ui")
    FILE_DELIMITER = "____"
    FINISHED_STRING = "+++++ COMMAND FINISHED +++++"
    TASK_HEADER_OUTPUT_DELIMITER = "-------------------------------"
    FILE_ITEM_SEPARATOR = ": "

    def self.create_tmp_file_dir
      FileUtils.mkdir_p(REPOSITORY_DIR.to_s)
    end

    def self.truncate
      FileUtils.rm_rf(Dir.glob(REPOSITORY_DIR.to_s + "/*"))
    end

    def self.build_from_file(log_file_name)
      log_file_name.split(FILE_DELIMITER)

      new(
        id: log_file_name.gsub(".txt", ""),
        log_file_name: log_file_name,
        log_file_full_path: Rails.root.join(REPOSITORY_DIR, log_file_name).to_s
      )
    end

    def self.build_new_for_command(
      name:,
      rake_definition_file:,
      rake_command:,
      raker_id:,
      args: nil,
      environment: nil,
      user_email: nil
    )
      create_tmp_file_dir

      date = Time.now.strftime(ID_DATE_FORMAT)
      id = "#{date}#{FILE_DELIMITER}#{raker_id}"
      log_file_name = "#{id}.txt"
      log_file_full_path = REPOSITORY_DIR.join(log_file_name).to_s

      File.open(log_file_full_path, "w+") do |f|
        f.puts "ran by#{FILE_ITEM_SEPARATOR}#{user_email}"
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

      Dir.entries(REPOSITORY_DIR).reject { |file|
        file == "." || file == ".."
      }.map do |log|
        RakeUi::RakeTaskLog.build_from_file(log)
      end
    end

    def self.find_by_id(id)
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
      "#{rake_command} 2>&1 >> #{log_file_full_path}"
    end

    def file_contents
      @file_contents ||= File.read(log_file_full_path)
    end

    def command_to_mark_log_finished
      "echo #{FINISHED_STRING} >> #{log_file_full_path}"
    end

    def finished?
      file_contents.include? FINISHED_STRING
    end

    private

    # converts standard formatted file id into an object
    def parsed_log_file_name
      @parsed_log_file_name ||= {}.tap do |parsed|
        date, name = id.split(FILE_DELIMITER, 2)
        parsed[:date] = date
        parsed[:name] = RakeUi::RakeTask.from_safe_identifier(name)
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

      @parsed_file_contents = {}.tap do |parsed|
        File.foreach(log_file_full_path).first(9).each do |line|
          name, value = line.split(FILE_ITEM_SEPARATOR, 2)
          next unless name

          parsed[name] = value && value.delete("\n")
        end
      end.with_indifferent_access
    end
  end
end
