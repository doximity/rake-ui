require "test_helper"

class RakeTasksRequestTest < ActionDispatch::IntegrationTest
  test "index html responds successfully" do
    get '/rake-ui/rake_tasks'

    assert_equal 200, status
  end

  test "index json responds with rake tasks" do
    get '/rake-ui/rake_tasks.json'

    assert_equal 200, status
    assert_instance_of Array, json_response[:rake_tasks]
  end

  test "show html responds successfully" do
    task = RakeUi::RakeTask.internal.first

    get "/rake-ui/rake_tasks/#{task.id}.json"

    assert_equal 200, status
  end

  test "json finds the task by id" do
    task = RakeUi::RakeTask.internal.first

    get "/rake-ui/rake_tasks/#{task.id}.json"

    assert_equal 200, status

    assert_equal task.id, json_response[:rake_task][:id]
    assert_equal task.name_with_args, json_response[:rake_task][:name_with_args]
  end

  test "post executes the task" do
    mock_task = Minitest::Mock.new
    def mock_task.id; "some_identifier"; end
    mock_task.expect :call, true, [{ args: "1,2,3", environment: "FOO=bar" }]

    mock_find_by_id = lambda do |args|
      assert args, "some_identifier"

      mock_task
    end

    RakeUi::RakeTask.stub :find_by_id, mock_find_by_id do
      post "/rake-ui/rake_tasks/#{mock_task.id}/execute", params: { environment: "FOO=bar",
                                                                    args: "1,2,3" }
    end
  end
end
