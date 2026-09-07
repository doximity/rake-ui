# frozen_string_literal: true

module RakeUi
  module DebugLogger
    module_function

    def debug(event, task_name: nil, task_log_id: nil)
      return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

      Rails.logger.debug(
        component: "rake-ui",
        event: event,
        rails_app: rails_app_name,
        task_name: task_name,
        task_log_id: task_log_id
      )
    end

    def rails_app_name
      application_class = Rails.application.class
      if application_class.respond_to?(:module_parent_name)
        application_class.module_parent_name
      else
        application_class.name.to_s.split("::").first
      end
    end
  end
end
