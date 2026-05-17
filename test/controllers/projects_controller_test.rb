require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "renders the project index" do
    get projects_url

    assert_response :success
  end
end
