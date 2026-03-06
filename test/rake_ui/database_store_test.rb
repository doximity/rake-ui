# frozen_string_literal: true

require "test_helper"

class DatabaseStoreTest < ActiveSupport::TestCase
  setup do
    @original_backend = RakeUi.storage_backend
    RakeUi.storage_backend = :database
    # Reset the cached store instance
    RakeUi.instance_variable_set(:@store, nil)
    RakeUi.instance_variable_set(:@last_storage_backend, nil)

    # Clean up only database records (preserve file fixtures)
    RakeUi::TaskLogRecord.delete_all
    @created_tmp_files = []
  end

  teardown do
    RakeUi.storage_backend = @original_backend
    RakeUi.instance_variable_set(:@store, nil)
    RakeUi.instance_variable_set(:@last_storage_backend, nil)

    # Clean up database records created during tests
    RakeUi::TaskLogRecord.delete_all

    # Clean up only temp files created by this test
    @created_tmp_files.each { |f| File.delete(f) if File.exist?(f) }
  end

  test "store returns DatabaseStore when configured" do
    assert_instance_of RakeUi::Storage::DatabaseStore, RakeUi.store
  end

  test "create_log persists a record to the database" do
    log = create_test_log(
      args: "arg1,arg2",
      environment: "FOO=bar",
      executed_by: "test_user"
    )

    assert_equal 1, RakeUi::TaskLogRecord.count

    record = RakeUi::TaskLogRecord.first
    assert_equal log.id, record.log_id
    assert_equal "test:task", record.name
    assert_equal "arg1,arg2", record.args
    assert_equal "FOO=bar", record.environment
    assert_equal "rake test:task", record.rake_command
    assert_equal "test.rake:1", record.rake_definition_file
    assert_equal "test_user", record.executed_by
    assert_equal false, record.finished
  end

  test "create_log returns a RakeTaskLog instance with correct attributes" do
    log = create_test_log(
      args: "arg1",
      environment: "FOO=bar",
      executed_by: "someone"
    )

    assert_instance_of RakeUi::RakeTaskLog, log
    assert_equal "test:task", log.name
    assert_equal "arg1", log.args
    assert_equal "FOO=bar", log.environment
    assert_equal "rake test:task", log.rake_command
    assert_equal "someone", log.executed_by
    assert_match(/____test%3Atask$/, log.id)
  end

  test "create_log creates a temp file for live streaming" do
    log = create_test_log

    assert log.log_file_full_path.present?
    assert File.exist?(log.log_file_full_path)
    assert_includes File.read(log.log_file_full_path), "INVOKED RAKE TASK OUTPUT BELOW"
  end

  test "all returns logs from the database" do
    3.times do |i|
      create_test_log(
        name: "test:task_#{i}",
        rake_definition_file: "test.rake:#{i}",
        rake_command: "rake test:task_#{i}",
        raker_id: "test%3Atask_#{i}"
      )
      sleep 0.01  # ensure different timestamps
    end

    logs = RakeUi::RakeTaskLog.all
    assert_equal 3, logs.length
    assert_instance_of RakeUi::RakeTaskLog, logs.first
  end

  test "find_by_id finds a log by its id" do
    log = create_test_log(
      name: "test:findme",
      rake_definition_file: "test.rake:1",
      rake_command: "rake test:findme",
      raker_id: "test%3Afindme"
    )

    found = RakeUi::RakeTaskLog.find_by_id(log.id)
    assert_not_nil found
    assert_equal log.id, found.id
    assert_equal "test:findme", found.name
  end

  test "truncate removes all records" do
    create_test_log

    assert_equal 1, RakeUi::TaskLogRecord.count
    RakeUi::RakeTaskLog.truncate
    assert_equal 0, RakeUi::TaskLogRecord.count
  end

  test "file_contents reads from temp file while task is running" do
    log = create_test_log

    # Append some output to the temp file
    File.open(log.log_file_full_path, "a") do |f|
      f.puts "some task output"
    end

    content = log.file_contents
    assert_includes content, "some task output"
    assert_includes content, "INVOKED RAKE TASK OUTPUT BELOW"
  end

  test "finished? returns false while task is running" do
    log = create_test_log

    refute log.finished?
  end

  test "finished? returns true and persists output after task completes" do
    log = create_test_log

    # Simulate task finishing by appending the finished string
    File.open(log.log_file_full_path, "a") do |f|
      f.puts "task output here"
      f.puts "+++++ COMMAND FINISHED +++++"
    end

    assert log.finished?

    # After finished? is called, output should be persisted to DB
    record = RakeUi::TaskLogRecord.find_by(log_id: log.id)
    assert record.finished?
    assert_includes record.output, "task output here"
    assert_includes record.output, "+++++ COMMAND FINISHED +++++"

    # Temp file should be cleaned up
    refute File.exist?(log.log_file_full_path)
  end

  test "file_contents returns from DB after task is persisted" do
    log = create_test_log

    # Simulate task finishing
    File.open(log.log_file_full_path, "a") do |f|
      f.puts "final output"
      f.puts "+++++ COMMAND FINISHED +++++"
    end

    # Trigger persist
    log.finished?

    # Now re-fetch and check content comes from DB
    found = RakeUi::RakeTaskLog.find_by_id(log.id)
    content = found.file_contents
    assert_includes content, "final output"
  end

  test "rake_command_with_logging redirects to temp file" do
    log = create_test_log

    cmd = log.rake_command_with_logging
    assert_includes cmd, "rake test:task"
    assert_includes cmd, "2>&1 >>"
    assert_includes cmd, ".txt"
  end

  test "command_to_mark_log_finished echoes finished string to temp file" do
    log = create_test_log

    cmd = log.command_to_mark_log_finished
    assert_includes cmd, "+++++ COMMAND FINISHED +++++"
    assert_includes cmd, ".txt"
  end

  test "cleanup_old_logs removes excess records" do
    205.times do |i|
      RakeUi::TaskLogRecord.create!(
        log_id: "test-log-#{format("%04d", i)}",
        name: "test:task_#{i}",
        date: Time.now.strftime("%Y-%m-%d-%H-%M-%S%z"),
        finished: true
      )
    end

    assert_equal 205, RakeUi::TaskLogRecord.count
    RakeUi::RakeTaskLog.cleanup_old_logs
    assert_equal 200, RakeUi::TaskLogRecord.count
  end

  private

  def create_test_log(**opts)
    defaults = {
      name: "test:task",
      rake_definition_file: "test.rake:1",
      rake_command: "rake test:task",
      raker_id: "test%3Atask"
    }
    log = RakeUi::RakeTaskLog.build_new_for_command(**defaults.merge(opts))
    @created_tmp_files << log.log_file_full_path if log.log_file_full_path
    log
  end
end
