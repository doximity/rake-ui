# frozen_string_literal: true

require "test_helper"

class DebugLoggerTest < ActiveSupport::TestCase
  test "emits public safe structured debug logs with a stable shape" do
    messages = []
    logger = Class.new do
      def initialize(messages)
        @messages = messages
      end

      def debug(message)
        @messages << message
      end
    end.new(messages)

    Rails.stub(:logger, logger) do
      RakeUi::DebugLogger.debug(
        "rake_ui.task_execution.requested",
        task_name: "db:migrate",
        task_log_id: "2026-05-11-10-22-33-0400____db%3Amigrate"
      )
    end

    assert_equal 1, messages.length
    assert_equal(
      {
        component: "rake-ui",
        event: "rake_ui.task_execution.requested",
        rails_app: "Dummy",
        task_name: "db:migrate",
        task_log_id: "2026-05-11-10-22-33-0400____db%3Amigrate"
      },
      messages.first
    )
  end

  test "keeps the same keys when task log id is not available yet" do
    messages = []
    logger = Class.new do
      def initialize(messages)
        @messages = messages
      end

      def debug(message)
        @messages << message
      end
    end.new(messages)

    Rails.stub(:logger, logger) do
      RakeUi::DebugLogger.debug("rake_ui.task_execution.requested", task_name: "db:migrate")
    end

    assert_equal [:component, :event, :rails_app, :task_name, :task_log_id], messages.first.keys
    assert_nil messages.first[:task_log_id]
  end
end
