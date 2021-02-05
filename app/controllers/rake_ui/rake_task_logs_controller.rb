require 'pry'

module RakeUi
  class RakeTaskLogsController < ApplicationController
    def index
      @rake_task_logs = RakeUi::RakeTaskLog.all.sort_by(&:id)

      respond_to do |format|
        format.html
        format.json
      end
    end

    def show
      @rake_task_log = RakeUi::RakeTaskLog.find_by_id(params[:id])
      @rake_task_log_content = @rake_task_log.file_contents.gsub("\n", "<br />")

      @rake_task_log_content_url = rake_task_log_path(@rake_task_log.id, format: :json)

      respond_to do |format|
        format.html
        format.json
      end
    end
  end
end
