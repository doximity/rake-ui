module RakeUi
  class RakeTasksController < RakeUi::ApplicationController
    def index
      @rake_tasks = RakeUi::RakeTask.all.select(&:internal_task?)

      respond_to do |format|
        format.json
        format.html
      end
    end

    def show
      @rake_task = RakeUi::RakeTask.find_by_id(params[:id])

      respond_to do |format|
        format.json
        format.html
      end
    end
  end
end
