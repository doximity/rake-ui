# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "shellwords"

class RakeTaskLogTest < ActiveSupport::TestCase
  test "loads a log file correctly into an instance of RakeTaskLog" do
    id = "2021-02-07-09-34-04-0600____nested%3Athe_nested_task"
    log = RakeUi::RakeTaskLog.find_by_id(id)

    assert_equal log.id, id
    assert_equal log.name, "nested:the_nested_task"
    assert_equal log.args, "1"
    assert_equal log.environment, "FOO=bar BAZ=biz"
    assert_equal log.rake_command, "FOO=bar BAZ=biz rake nested:the_nested_task[1]"
    assert_equal log.rake_definition_file, "#<Proc:0x00005558b6239128 /test/dummy/lib/tasks/nested_tasks.rake:3>"
    assert_equal log.log_file_name, "2021-02-07-09-34-04-0600____nested%3Athe_nested_task.txt"
    assert_includes log.log_file_full_path, "/test/dummy/tmp/rake_ui/2021-02-07-09-34-04-0600____nested%3Athe_nested_task.txt"
  end

  test "is able to decode some date, id and name so that we don't have to read the full contents of file" do
    id = "2021-02-07-09-34-04-0600____nested%3Athe_nested_task"
    log = RakeUi::RakeTaskLog.find_by_id(id)

    log.stub(:parsed_file_contents, {}) do
      assert_equal log.id, id
      assert_equal log.name, "nested:the_nested_task"
      assert_equal log.date, "2021-02-07-09-34-04-0600"
    end
  end

  test "generates log IDs with sub-second precision" do
    log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "rake test_task",
      raker_id: "test_task"
    )

    assert_match(/\A\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}-\d+[-+]\d{4}____test_task\z/, log.id)
  ensure
    File.delete(log.log_file_full_path) if File.exist?(log.log_file_full_path)
  end

  test "generates unique log IDs for concurrent executions of the same task" do
    first_log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "rake test_task",
      raker_id: "test_task"
    )

    second_log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "rake test_task",
      raker_id: "test_task"
    )

    refute_equal first_log.id, second_log.id
    refute_equal first_log.log_file_full_path, second_log.log_file_full_path
  ensure
    [first_log, second_log].compact.each do |log|
      File.delete(log.log_file_full_path) if File.exist?(log.log_file_full_path)
    end
  end

  test "repository_dir defaults to the tmp/rake_ui directory" do
    assert_nil RakeUi.log_directory
    assert_equal RakeUi::RakeTaskLog::REPOSITORY_DIR, RakeUi::RakeTaskLog.repository_dir
    assert_equal Rails.root.join("tmp", "rake_ui").to_s, RakeUi::RakeTaskLog.repository_dir.to_s

    name = "2021-02-07-09-34-04-0600____missing.txt"
    log = RakeUi::RakeTaskLog.build_from_file(name)

    assert_equal Rails.root.join("tmp", "rake_ui", name).to_s, log.log_file_full_path
  end

  test "repository_dir uses the configured log_directory and leaves the default directory alone" do
    default_dir = RakeUi::RakeTaskLog::REPOSITORY_DIR
    default_entries_before = Dir.children(default_dir).sort

    tmpdir = Dir.mktmpdir("rake_ui_logs")
    RakeUi.log_directory = tmpdir

    log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "rake test_task",
      raker_id: "test"
    )

    assert_equal Pathname.new(tmpdir), RakeUi::RakeTaskLog.repository_dir
    assert File.exist?(log.log_file_full_path)
    assert_equal tmpdir, File.dirname(log.log_file_full_path)
    assert_equal default_entries_before, Dir.children(default_dir).sort
  ensure
    RakeUi.log_directory = nil
    FileUtils.remove_entry(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  test "all merges log_list ids without duplicating a locally known log" do
    local = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "rake test_task",
      raker_id: "test"
    )

    RakeUi.log_list = -> { [local.id, "remote-id"] }

    ids = RakeUi::RakeTaskLog.all.map(&:id)

    assert_equal 1, ids.count(local.id)
    assert_equal 1, ids.count("remote-id")
  ensure
    RakeUi.log_list = nil
    File.delete(local.log_file_full_path) if local && File.exist?(local.log_file_full_path)
  end

  test "build_from_id normalizes a .txt suffix" do
    log = RakeUi::RakeTaskLog.build_from_id("2021-02-07-09-34-04-0600____remote-task.txt")

    assert_equal "2021-02-07-09-34-04-0600____remote-task", log.id
    assert_equal "2021-02-07-09-34-04-0600____remote-task.txt", log.log_file_name
  end

  test "log_source reads content and finished state from log_reader" do
    log = RakeUi::RakeTaskLog.build_from_id("some-id")
    RakeUi.log_reader = ->(_log) { {content: "hello", finished: true} }

    assert_equal({content: "hello", finished: true}, log.log_source)
  ensure
    RakeUi.log_reader = nil
  end

  test "log_source raises MissingLogFile when log_reader returns nil" do
    log = RakeUi::RakeTaskLog.build_from_id("some-id")
    RakeUi.log_reader = ->(_log) {}

    assert_raises(RakeUi::RakeTaskLog::MissingLogFile) { log.log_source }
  ensure
    RakeUi.log_reader = nil
  end

  test "rake_command_with_logging merges stderr after redirecting to the escaped log path" do
    path = "/tmp/rake ui/some log.txt"
    log = RakeUi::RakeTaskLog.new(
      rake_command: "rake test_task",
      log_file_full_path: path
    )

    escaped = Shellwords.escape(path)
    command = log.rake_command_with_logging

    assert_equal "rake test_task >> #{escaped} 2>&1", command
    assert_operator command.index(escaped), :<, command.index("2>&1"),
      "the log path must be redirected before stderr is merged into it"
    refute_equal path, escaped, "the log path should be shell-escaped"
  end

  test "build_from_file tolerates a missing log file" do
    log = RakeUi::RakeTaskLog.build_from_file("2021-02-07-09-34-04-0600____missing.txt")

    assert_nil log.args
    assert_nil log.environment
  end

  test "does not truncate existing log file when creating a new one" do
    first_log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "rake test_task",
      raker_id: "test_task"
    )

    marker = "first run marker #{SecureRandom.hex(8)}"
    File.open(first_log.log_file_full_path, "a") do |f|
      f.puts marker
    end

    second_log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "rake test_task",
      raker_id: "test_task"
    )

    assert_includes File.read(first_log.log_file_full_path), marker
    refute_equal first_log.log_file_full_path, second_log.log_file_full_path
  ensure
    [first_log, second_log].compact.each do |log|
      File.delete(log.log_file_full_path) if File.exist?(log.log_file_full_path)
    end
  end
end
