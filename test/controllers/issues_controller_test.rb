require "test_helper"

class IssuesControllerTest < ActionDispatch::IntegrationTest
  test "renders the issue index" do
    get issues_url

    assert_response :success
  end
end
