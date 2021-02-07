module RakeUi
  class RakeTaskLog < OpenStruct
    # year-month-day-hour(24hour time)-minute-second-utc
    ID_DATE_FORMAT = "%Y-%m-%d-%H-%M-%S%z"
    REPOSITORY_DIR = Rails.root.join('tmp', 'rake_ui')
    FILE_DELIMITER = "____"
    FINISHED_STRING = "+++++ COMMAND FINISHED +++++"
    TASK_HEADER_OUTPUT_DELIMITER = "-------------------------------"
    FILE_ITEM_SEPARATOR = ": "

    def self.truncate
      FileUtils.rm_rf(Dir.glob(REPOSITORY_DIR.to_s + '/*'))
    end

    def self.build_from_file(log_file_name)
      # date, task = log_file_name.split(FILE_DELIMITER)

      new(
        id: log_file_name.gsub('.txt', ''),
        log_file_name: log_file_name,
        log_file_full_path: Rails.root.join(REPOSITORY_DIR, log_file_name).to_s
      )
    end

    def self.build_new_for_command(name:, args: nil, environment: nil,rake_definition_file:, rake_command:, raker_id:)
      id = "#{Time.now.strftime(ID_DATE_FORMAT)}#{FILE_DELIMITER}#{raker_id}"
      log_file_name = "#{id}.txt"
      log_file_full_path = Rails.root.join('tmp', 'rake_ui', log_file_name).to_s

      File.open(log_file_full_path, 'w+') do |f|
        f.puts "id#{FILE_ITEM_SEPERATOR}#{id}"
        f.puts "name#{FILE_ITEM_SEPERATOR}#{name}"
        f.puts "args#{FILE_ITEM_SEPERATOR}#{args}"
        f.puts "environment#{FILE_ITEM_SEPERATOR}#{environment}"
        f.puts "rake_command#{FILE_ITEM_SEPERATOR}#{rake_command}"
        f.puts "rake_definition_file#{FILE_ITEM_SEPERATOR}#{rake_definition_file}"
        f.puts "log_file_name#{FILE_ITEM_SEPERATOR}#{log_file_name}"
        f.puts "log_file_full_path#{FILE_ITEM_SEPERATOR}#{log_file_full_path}"

        f.puts "#{TASK_HEADER_OUTPUT_DELIMITER}"
        f.puts " INVOKED RAKE TASK OUTPUT BELOW"
        f.puts "#{TASK_HEADER_OUTPUT_DELIMITER}"
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
      Dir.entries(REPOSITORY_DIR).reject do |file|
        file == '.' || file == '..'
      end.map do |log|
        RakeUi::RakeTaskLog.build_from_file(log)
      end
    end

    def self.find_by_id(id)
      all.find do |a|
        a.id == id || a.id == CGI.escape(id)
      end
    end

    def self.for(rake_ui_rake_task)
      all.select do |history|
        history.id == rake_ui_rake_task.id
      end
    end

    def name
      super || parsed_file_contents[:name]
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
        File.foreach(log_file_full_path).first(8).each do |line|
          name, value = line.split(FILE_ITEM_SEPARATOR, 2)
          next unless name

          parsed[name] = value && value.gsub("\n", '')
        end
      end.with_indifferent_access
    end
  end
end
