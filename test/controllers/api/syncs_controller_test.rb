require "test_helper"

class Api::SyncsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_token = ENV["SYNC_TOKEN"]
    ENV["SYNC_TOKEN"] = "super-secret-token"

    @original_projects_sync = Projects::SyncJob.method(:perform_now)
    @original_issues_sync = Issues::SyncJob.method(:perform_now)
    @original_thread_new = Thread.method(:new)

    @projects_called = false
    @issues_called = false

    test_instance = self
    Projects::SyncJob.define_singleton_method(:perform_now) { test_instance.instance_variable_set(:@projects_called, true) }
    Issues::SyncJob.define_singleton_method(:perform_now) { test_instance.instance_variable_set(:@issues_called, true) }
    Thread.define_singleton_method(:new) { |&block| block.call; Object.new }
  end

  teardown do
    ENV["SYNC_TOKEN"] = @original_token

    Projects::SyncJob.define_singleton_method(:perform_now, @original_projects_sync)
    Issues::SyncJob.define_singleton_method(:perform_now, @original_issues_sync)
    Thread.define_singleton_method(:new, @original_thread_new)
  end

  test "should trigger sync jobs with authorization header" do
    post api_syncs_url, headers: { "Authorization" => "Bearer super-secret-token" }

    assert_response :accepted
    assert_equal "accepted", JSON.parse(response.body)["status"]
    assert @projects_called
    assert @issues_called
  end

  test "should trigger sync jobs with query param token" do
    post api_syncs_url(token: "super-secret-token")

    assert_response :accepted
    assert_equal "accepted", JSON.parse(response.body)["status"]
    assert @projects_called
    assert @issues_called
  end

  test "should return unauthorized with incorrect token" do
    post api_syncs_url, headers: { "Authorization" => "Bearer wrong-token" }

    assert_response :unauthorized
    assert_equal "Unauthorized", JSON.parse(response.body)["error"]
  end

  test "should return internal server error if SYNC_TOKEN is blank" do
    ENV["SYNC_TOKEN"] = nil

    post api_syncs_url(token: "any-token")

    assert_response :internal_server_error
    assert_equal "Sync token is not configured on the server", JSON.parse(response.body)["error"]
  end
end
