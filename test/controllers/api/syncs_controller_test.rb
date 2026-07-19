require "test_helper"

class Api::SyncsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @original_token = ENV["SYNC_TOKEN"]
    ENV["SYNC_TOKEN"] = "super-secret-token"
  end

  teardown do
    ENV["SYNC_TOKEN"] = @original_token
  end

  test "should trigger sync jobs with authorization header" do
    assert_enqueued_with(job: Projects::SyncJob) do
      assert_enqueued_with(job: Issues::SyncJob) do
        post api_syncs_url, headers: { "Authorization" => "Bearer super-secret-token" }
      end
    end

    assert_response :accepted
    assert_equal "enqueued", JSON.parse(response.body)["status"]
  end

  test "should trigger sync jobs with query param token" do
    assert_enqueued_with(job: Projects::SyncJob) do
      assert_enqueued_with(job: Issues::SyncJob) do
        post api_syncs_url(token: "super-secret-token")
      end
    end

    assert_response :accepted
    assert_equal "enqueued", JSON.parse(response.body)["status"]
  end

  test "should return unauthorized with incorrect token" do
    assert_no_enqueued_jobs do
      post api_syncs_url, headers: { "Authorization" => "Bearer wrong-token" }
    end

    assert_response :unauthorized
    assert_equal "Unauthorized", JSON.parse(response.body)["error"]
  end

  test "should return internal server error if SYNC_TOKEN is blank" do
    ENV["SYNC_TOKEN"] = nil

    assert_no_enqueued_jobs do
      post api_syncs_url(token: "any-token")
    end

    assert_response :internal_server_error
    assert_equal "Sync token is not configured on the server", JSON.parse(response.body)["error"]
  end
end
