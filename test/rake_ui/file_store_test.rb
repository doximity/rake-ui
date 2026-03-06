# frozen_string_literal: true

require "test_helper"

class FileStoreTest < ActiveSupport::TestCase
  setup do
    @original_backend = RakeUi.storage_backend
    RakeUi.storage_backend = :file
    RakeUi.instance_variable_set(:@store, nil)
    RakeUi.instance_variable_set(:@last_storage_backend, nil)
  end

  teardown do
    RakeUi.storage_backend = @original_backend
    RakeUi.instance_variable_set(:@store, nil)
    RakeUi.instance_variable_set(:@last_storage_backend, nil)
  end

  test "store returns FileStore when configured" do
    assert_instance_of RakeUi::Storage::FileStore, RakeUi.store
  end

  test "default storage_backend is :file" do
    assert_equal :file, RakeUi.storage_backend
  end

  test "file store loads existing log files" do
    logs = RakeUi::RakeTaskLog.all
    assert_instance_of Array, logs
    assert logs.any?, "Expected at least one log from the test fixture file"
  end

  test "file store find_by_id works with existing fixture" do
    id = "2021-02-07-09-34-04-0600____nested%3Athe_nested_task"
    log = RakeUi::RakeTaskLog.find_by_id(id)

    assert_not_nil log
    assert_equal id, log.id
  end

  test "file store file_contents reads from disk" do
    id = "2021-02-07-09-34-04-0600____nested%3Athe_nested_task"
    log = RakeUi::RakeTaskLog.find_by_id(id)
    content = log.file_contents

    assert_includes content, "INVOKED RAKE TASK OUTPUT BELOW"
    assert_includes content, "the_nested_task start"
  end

  test "file store finished? checks for finished string in file" do
    id = "2021-02-07-09-34-04-0600____nested%3Athe_nested_task"
    log = RakeUi::RakeTaskLog.find_by_id(id)

    assert log.finished?
  end
end

