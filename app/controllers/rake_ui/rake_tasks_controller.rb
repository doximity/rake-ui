# frozen_string_literal: true

module RakeUi
  class RakeTasksController < RakeUi::ApplicationController
    RAKE_TASK_ATTRS = [:id,
      :name,
      :name_with_args,
      :arg_description,
      :full_comment,
      :locations,
      :is_internal_task,
      :sources].freeze

    def index
      @rake_tasks = RakeUi::RakeTask.all

      unless params[:show_all]
        @rake_tasks = @rake_tasks.select(&:internal_task?)
      end

      respond_to do |format|
        format.html
        format.json do
          render json: {
            rake_tasks: rake_tasks_as_json(@rake_tasks)
          }
        end
      end
    end

    def show
      @rake_task = RakeUi::RakeTask.find_by_id(params[:id])

      respond_to do |format|
        format.html
        format.json do
          render json: {
            rake_task: rake_task_as_json(@rake_task)
          }
        end
      end
    end

    def execute
      @rake_task = RakeUi::RakeTask.find_by_id(params[:id])

      args = build_args_from_params
      current_user_identifier = get_current_user_identifier

      rake_task_log = @rake_task.call(
        args: args,
        environment: params[:environment],
        executed_by: current_user_identifier
      )

      redirect_to rake_task_log_path rake_task_log.id
    end

    private

    def get_current_user_identifier
      unless RakeUi.current_user_method.respond_to?(:call)
        Rails.logger.debug("RakeUi: current_user_method not configured")
        return nil
      end

      result = RakeUi.current_user_method.call(self)
      Rails.logger.debug("RakeUi: current_user_identifier = #{result.inspect}")
      result
    rescue => e
      Rails.logger.warn("RakeUi: Failed to get current user - #{e.message}")
      Rails.logger.warn("RakeUi: Backtrace: #{e.backtrace.first(5).join("\n")}")
      nil
    end

    def build_args_from_params
      individual_args = []
      index = 0

      while params.key?("arg_#{index}")
        individual_args << params["arg_#{index}"]
        index += 1
      end

      individual_args.any? ? individual_args.join(",") : params[:args]
    end

    def rake_task_as_json(task)
      RAKE_TASK_ATTRS.each_with_object({}) do |param, obj|
        obj[param] = task.send(param)
      end
    end

    def rake_tasks_as_json(tasks)
      tasks.map { |task| rake_task_as_json(task) }
    end
  end
end
