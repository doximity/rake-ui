# frozen_string_literal: true

module RakeUi
  class RakeTask
    @@tasks_loaded = false

    def self.to_safe_identifier(id)
      CGI.escape(id)
    end

    def self.from_safe_identifier(id)
      CGI.unescape(id)
    end

    def self.load
      # Enables 'desc' to show up as full_comments
      if Rake::TaskManager.respond_to? :record_task_metadata
        Rake::TaskManager.record_task_metadata = true
      end

      # Only load tasks once to prevent duplicate descriptions
      unless @@tasks_loaded
        Rails.application.load_tasks
        @@tasks_loaded = true
      end

      if RakeUi.configuration.whitelisted_prefixes.empty?
        return Rake::Task.tasks
      else
        return Rake::Task.tasks.select do |task|
          RakeUi.configuration.whitelisted_prefixes.any? do |prefix|
            task.name.start_with?(prefix)
          end
        end
      end
    end

    def self.reload
      # Reset the flag to allow reloading tasks (useful in development)
      @@tasks_loaded = false
      Rake::Task.clear
      load
    end

    def self.all
      self.load.map do |task|
        new(task)
      end
    end

    def self.internal
      self.load.map { |task|
        new(task)
      }.select(&:is_internal_task)
    end

    def self.find_by_id(id)
      t = all
      i = from_safe_identifier(id)

      t.find do |task|
        task.name == i
      end
    end

    attr_reader :task
    delegate :name, :actions, :name_with_args, :arg_description, :arg_names, :full_comment, :locations, :sources, to: :task

    def initialize(task)
      @task = task
    end

    def has_arguments?
      arg_names && arg_names.any?
    end

    def argument_names
      return [] unless has_arguments?
      arg_names.map(&:to_s)
    end

    def argument_count
      argument_names.length
    end

    def id
      RakeUi::RakeTask.to_safe_identifier(name)
    end

    def rake_definition_file
      definition = actions.first || ""

      if definition.respond_to?(:source_location)
        definition.source_location.join(":")
      else
        definition
      end
    rescue
      "unable_to_determine_defining_file"
    end

    def is_internal_task
      internal_task?
    end

    def internal_task?
      actions.any? { |a| !a.to_s.include? "/ruby/gems" }
    end

    def call(args: nil, environment: nil, executed_by: nil)
      rake_command = build_rake_command(args: args, environment: environment)

      rake_task_log = RakeUi::RakeTaskLog.build_new_for_command(
        name: name,
        args: args,
        environment: environment,
        rake_command: rake_command,
        rake_definition_file: rake_definition_file,
        raker_id: id,
        executed_by: executed_by
      )

      puts "[rake_ui] [rake_task] [forked] #{rake_task_log.rake_command_with_logging}"

      fork do
        system(rake_task_log.rake_command_with_logging)

        system(rake_task_log.command_to_mark_log_finished)
      end

      rake_task_log
    end

    def build_rake_command(args: nil, environment: nil)
      command = ""

      if environment
        command += "#{environment} "
      end

      command += "rake #{name}"

      if args
        command += "[#{args}]"
      end

      command
    end
  end
end
