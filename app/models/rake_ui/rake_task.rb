# frozen_string_literal: true

module RakeUi
  class RakeTask
    def self.load
      Rails.application.load_tasks
      Rake::Task.tasks
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
      i = CGI.unescape(id)

      t.find do |task|
        task.name == i
      end
    end

    attr_reader :task
    delegate :name, :actions, :name_with_args, :arg_description, :full_comment, :locations, :sources, to: :task

    def initialize(task)
      @task = task
    end

    def id
      CGI.escape(name)
    end

    # actions will be something like #<Proc:0x000055a2737fe778@/some/rails/app/lib/tasks/auto_annotate_models.rake:4>
    def rake_definition_file
      actions.first
    rescue StandardError
      "unable_to_determine_defining_file"
    end

    def is_internal_task
      internal_task?
    end

    # thinking this is the sanest way to discern application vs gem defined tasks (like rails, devise etc)
    def internal_task?
      actions.any? { |a| !a.to_s.include? "/ruby/gems" }

      # this was my initial thought here, leaving for posterity in case we need to or the definition of custom
      # from initial investigation the actions seemed like the most consistent as locations is sometimes empty
      # locations.any? do |location|
      #   !location.match(/\/bundle\/gems/)
      # end
    end

    def call(args: nil, environment: nil)
      rake_command = build_rake_command(args: args, environment: environment)

      rake_task_log = RakeUi::RakeTaskLog.build_new_for_command(
        name: name,
        args: args,
        environment: environment,
        rake_command: rake_command,
        rake_definition_file: rake_definition_file,
        raker_id: id
      )

      puts "[rake_ui] [rake_task] [forked] #{rake_task_log.rake_command_with_logging}"

      fork do
        system(rake_task_log.rake_command_with_logging)

        system(rake_task_log.command_to_mark_log_finished)
      end

      rake_task_log
    end

    # returns an invokable rake command
    # FOO=bar rake create_something[1,2,3]
    # rake create_something[1,2,3]
    # rake create_something
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
