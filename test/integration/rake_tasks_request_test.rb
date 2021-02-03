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
end
