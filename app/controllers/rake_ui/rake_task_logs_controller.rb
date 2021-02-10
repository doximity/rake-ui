# frozen_string_literal: true

module RakeUi
  class RakeTaskLogsController < ApplicationController
    def index
      @rake_task_logs = RakeUi::RakeTaskLog.all.sort_by(&:id)

      respond_to do |format|
        format.html
        format.json do
          render json: {
            rake_task_logs: rake_task_logs_as_json(@rake_task_logs)
          }
        end
      end
    end

    def show
      @rake_task_log = RakeUi::RakeTaskLog.find_by_id(params[:id])

      @rake_task_log_content = @rake_task_log.file_contents.gsub("\n", "<br />")
      @rake_task_log_content_url = rake_task_log_path(@rake_task_log.id, format: :json)
      @is_rake_task_log_finished = @rake_task_log.finished?

      respond_to do |format|
        format.html
        format.json do
          render json: {
            rake_task_log: rake_task_log_as_json(@rake_task_log),
            rake_task_log_content: @rake_task_log_content,
            rake_task_log_content_url: @rake_task_log_content_url,
            is_rake_task_log_finished: @is_rake_task_log_finished
          }
        end
      end
    end

    private


    RAKE_TASK_LOG_ATTRS = [:id,
                 :name,
                 :args,
                 :environment,
                 :rake_command,
                 :rake_definition_file,
                 :log_file_name,
                 :log_file_full_path]
    def rake_task_log_as_json(task)
      RAKE_TASK_LOG_ATTRS.each_with_object({}) do |param, obj|
        obj[param] = task.send(param)
      end
    end

    def rake_task_logs_as_json(tasks = [])
      tasks.map { |task| rake_task_log_as_json(task) }
    end
  end
end
