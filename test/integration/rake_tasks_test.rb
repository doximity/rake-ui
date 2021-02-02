require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "index" do
    get '/rake-ui/rake_tasks'

    assert_equal 200, status
  end
end
