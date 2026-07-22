require "test_helper"

class Api::SyncsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_token = ENV["SYNC_TOKEN"]
    ENV["SYNC_TOKEN"] = "super-secret-token"
    @original_runner_new = Syncs::Runner.method(:new)
    @force_full = nil
    @runner_status = :succeeded
    test_instance = self

    Syncs::Runner.define_singleton_method(:new) do |force_full:|
      test_instance.instance_variable_set(:@force_full, force_full)
      runner = Object.new
      runner.define_singleton_method(:call) do
        status = test_instance.instance_variable_get(:@runner_status)
        if status == :already_running
          Syncs::Runner::Result.new(status:, sync_run: nil)
        else
          run = SyncRun.create!(status: status.to_s, started_at: Time.current, finished_at: Time.current, projects_succeeded: 2, issues_upserted: 5)
          Syncs::Runner::Result.new(status:, sync_run: run)
        end
      end
      runner
    end
  end

  teardown do
    ENV["SYNC_TOKEN"] = @original_token
    Syncs::Runner.define_singleton_method(:new, @original_runner_new)
  end

  test "runs synchronously with a bearer token" do
    post api_syncs_url, headers: { "Authorization" => "Bearer super-secret-token" }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "succeeded", payload["status"]
    assert_equal 2, payload["projects_succeeded"]
    assert_equal 5, payload["issues_upserted"]
    assert_equal false, @force_full
  end

  test "does not accept a token in the query string" do
    post api_syncs_url(token: "super-secret-token")

    assert_response :unauthorized
  end

  test "passes the full reconciliation option to the runner" do
    post api_syncs_url(force_full: "true"), headers: { "Authorization" => "Bearer super-secret-token" }

    assert_response :success
    assert_equal true, @force_full
  end

  test "returns conflict when a synchronization is already running" do
    @runner_status = :already_running

    post api_syncs_url, headers: { "Authorization" => "Bearer super-secret-token" }

    assert_response :conflict
    assert_equal "already_running", JSON.parse(response.body)["status"]
  end

  test "returns unauthorized with an incorrect token" do
    post api_syncs_url, headers: { "Authorization" => "Bearer wrong-token" }

    assert_response :unauthorized
    assert_equal "Unauthorized", JSON.parse(response.body)["error"]
  end

  test "returns internal server error if SYNC_TOKEN is blank" do
    ENV["SYNC_TOKEN"] = nil

    post api_syncs_url, headers: { "Authorization" => "Bearer any-token" }

    assert_response :internal_server_error
    assert_equal "Sync token is not configured on the server", JSON.parse(response.body)["error"]
  end
end
