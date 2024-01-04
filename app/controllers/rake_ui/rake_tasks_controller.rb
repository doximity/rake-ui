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

    skip_before_action :verify_authenticity_token

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

      rake_task_log = @rake_task.call(args: params[:args], environment: params[:environment])

      redirect_to rake_task_log_path rake_task_log.id
    end

    private

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
