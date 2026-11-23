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

  test "repository_dir treats blank values as unset and accepts a Pathname" do
    default_dir = RakeUi::RakeTaskLog::REPOSITORY_DIR

    [nil, "", "   ", false].each do |blank|
      RakeUi.log_directory = blank
      assert_equal default_dir, RakeUi::RakeTaskLog.repository_dir
    end

    RakeUi.log_directory = Pathname.new("/tmp/rake_ui_configured")
    assert_equal Pathname.new("/tmp/rake_ui_configured"), RakeUi::RakeTaskLog.repository_dir
  ensure
    RakeUi.log_directory = nil
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

  test "log_source raises MissingLogFile when log_reader fails" do
    log = RakeUi::RakeTaskLog.build_from_id("some-id")
    RakeUi.log_reader = ->(_log) { raise "reader down" }

    assert_raises(RakeUi::RakeTaskLog::MissingLogFile) { log.log_source }
  ensure
    RakeUi.log_reader = nil
  end

  test "find_by_id tolerates a malformed id when a reader is configured" do
    RakeUi.log_reader = ->(_log) { {content: "remote", finished: true} }

    log = RakeUi::RakeTaskLog.find_by_id("bad\u0000id")

    assert_equal "bad\u0000id", log.id
    assert_nil log.log_file_full_path
  ensure
    RakeUi.log_reader = nil
  end

  test "log_source reads a local file instead of the reader when the log is on this pod" do
    log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "rake test_task",
      raker_id: "test"
    )
    reader_called = false
    RakeUi.log_reader = ->(_log) {
      reader_called = true
      {content: "remote", finished: true}
    }

    source = log.log_source

    refute reader_called, "a locally present log must not consult the reader"
    assert_includes source[:content], "INVOKED RAKE TASK OUTPUT BELOW"
    assert_equal false, source[:finished]
  ensure
    RakeUi.log_reader = nil
    File.delete(log.log_file_full_path) if log && File.exist?(log.log_file_full_path)
  end

  test "find_by_id does not consult log_list when log_reader is configured" do
    list_called = false
    RakeUi.log_list = -> {
      list_called = true
      ["remote-id"]
    }
    RakeUi.log_reader = ->(_log) { {content: "remote", finished: true} }

    log = RakeUi::RakeTaskLog.find_by_id("remote-id")

    refute list_called, "a configured reader fetches by id, so listing is unnecessary"
    assert_equal "remote-id", log.id
    assert_nil log.log_file_full_path
  ensure
    RakeUi.log_list = nil
    RakeUi.log_reader = nil
  end

  test "find_by_id returns a local log even when log_reader is configured" do
    local = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "rake test_task",
      raker_id: "test"
    )
    RakeUi.log_reader = ->(_log) { {content: "remote", finished: true} }

    found = RakeUi::RakeTaskLog.find_by_id(local.id)

    assert_equal local.log_file_full_path, found.log_file_full_path
  ensure
    RakeUi.log_reader = nil
    File.delete(local.log_file_full_path) if local && File.exist?(local.log_file_full_path)
  end

  test "find_by_id does not read outside the log directory for a traversal id" do
    RakeUi.log_reader = ->(_log) { {content: "remote", finished: true} }

    log = RakeUi::RakeTaskLog.find_by_id("../../etc/passwd")

    assert_equal "../../etc/passwd", log.id
    assert_nil log.log_file_full_path
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

  test "run_with_log_writer streams output to the file and the writer" do
    tmpdir = Dir.mktmpdir("rake_ui_logs")
    RakeUi.log_directory = tmpdir

    log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "echo hello-from-writer",
      raker_id: "test"
    )

    events = []
    writer = ->(_log, event, payload = nil) { events << [event, payload] }

    log.run_with_log_writer(writer)

    contents = File.read(log.log_file_full_path)
    assert_includes contents, "hello-from-writer"
    assert_includes contents, RakeUi::RakeTaskLog::FINISHED_STRING
    assert_equal :start, events.first.first
    assert_equal :finished, events.last.first
    assert_equal 1, events.count { |event, _payload| [:finished, :error].include?(event) }
    assert(events.any? { |event, payload| event == :progress && payload.include?("hello-from-writer") })
  ensure
    RakeUi.log_directory = nil
    FileUtils.remove_entry(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  test "run_with_log_writer does not raise or stop the file write when the writer fails" do
    tmpdir = Dir.mktmpdir("rake_ui_logs")
    RakeUi.log_directory = tmpdir

    log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "echo still-writes-the-file",
      raker_id: "test"
    )

    writer = ->(_log, _event, _payload = nil) { raise "writer exploded" }

    assert_nothing_raised { log.run_with_log_writer(writer) }
    assert_includes File.read(log.log_file_full_path), "still-writes-the-file"
  ensure
    RakeUi.log_directory = nil
    FileUtils.remove_entry(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  test "run_with_log_writer reports :error for a failed command" do
    tmpdir = Dir.mktmpdir("rake_ui_logs")
    RakeUi.log_directory = tmpdir

    log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "exit 3",
      raker_id: "test"
    )

    events = []
    writer = ->(_log, event, payload = nil) { events << [event, payload] }

    log.run_with_log_writer(writer)

    assert_equal :error, events.last.first
    assert_includes events.last.last, "exit 3"
    assert_includes File.read(log.log_file_full_path), RakeUi::RakeTaskLog::FINISHED_STRING
    assert log.finished?
  ensure
    RakeUi.log_directory = nil
    FileUtils.remove_entry(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  test "run_with_log_writer puts the finish marker on its own line" do
    tmpdir = Dir.mktmpdir("rake_ui_logs")
    RakeUi.log_directory = tmpdir

    log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "printf no-newline",
      raker_id: "test"
    )

    log.run_with_log_writer(->(_log, _event, _payload = nil) {})

    contents = File.read(log.log_file_full_path)
    assert_includes contents, "no-newline\n#{RakeUi::RakeTaskLog::FINISHED_STRING}"
    refute_includes contents, "no-newline#{RakeUi::RakeTaskLog::FINISHED_STRING}"
  ensure
    RakeUi.log_directory = nil
    FileUtils.remove_entry(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  test "run_with_log_writer handles empty output" do
    tmpdir = Dir.mktmpdir("rake_ui_logs")
    RakeUi.log_directory = tmpdir

    log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "true",
      raker_id: "test"
    )

    events = []
    log.run_with_log_writer(->(_log, event, _payload = nil) { events << event })

    assert_equal [:start, :finished], events
    assert log.finished?
  ensure
    RakeUi.log_directory = nil
    FileUtils.remove_entry(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  test "finished? tolerates invalid UTF-8 output" do
    tmpdir = Dir.mktmpdir("rake_ui_logs")
    RakeUi.log_directory = tmpdir

    log = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "printf '\\377\\376'",
      raker_id: "test"
    )

    log.run_with_log_writer(->(_log, _event, _payload = nil) {})

    assert_nothing_raised { assert log.finished? }
  ensure
    RakeUi.log_directory = nil
    FileUtils.remove_entry(tmpdir) if tmpdir && File.exist?(tmpdir)
  end

  test "log_source raises MissingLogFile when log_reader returns a non-hash" do
    log = RakeUi::RakeTaskLog.build_from_id("some-id")
    RakeUi.log_reader = ->(_log) { "not a hash" }

    assert_raises(RakeUi::RakeTaskLog::MissingLogFile) { log.log_source }
  ensure
    RakeUi.log_reader = nil
  end

  test "all ignores a failing log_list" do
    local = RakeUi::RakeTaskLog.build_new_for_command(
      name: "test_task",
      rake_definition_file: "test.rake",
      rake_command: "rake test_task",
      raker_id: "test"
    )
    RakeUi.log_reader = ->(_log) { {content: "remote", finished: true} }
    RakeUi.log_list = -> { raise "list down" }

    assert_includes RakeUi::RakeTaskLog.all.map(&:id), local.id
  ensure
    RakeUi.log_list = nil
    RakeUi.log_reader = nil
    File.delete(local.log_file_full_path) if local && File.exist?(local.log_file_full_path)
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
