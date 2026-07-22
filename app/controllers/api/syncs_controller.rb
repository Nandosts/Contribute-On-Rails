module Api
  class SyncsController < ActionController::API
    before_action :authenticate_request

    def create
      result = Syncs::Runner.new(force_full: force_full?).call

      if result.status == :already_running
        render json: { status: "already_running" }, status: :conflict
      else
        run = result.sync_run
        render json: {
          status: run.status,
          sync_run_id: run.id,
          projects_succeeded: run.projects_succeeded,
          projects_failed: run.projects_failed,
          issues_upserted: run.issues_upserted,
          issues_deleted: run.issues_deleted
        }, status: run.status == "succeeded" ? :ok : :multi_status
      end
    rescue StandardError => error
      Rails.logger.error("Synchronization failed: #{error.message}")
      render json: { status: "failed", error: "Synchronization failed" }, status: :internal_server_error
    end

    private

    def force_full?
      params[:force_full] == "true" || params[:fetch_all] == "true"
    end

    def authenticate_request
      authorization = request.headers["Authorization"].to_s
      token = authorization.delete_prefix("Bearer ") if authorization.start_with?("Bearer ")
      expected_token = ENV["SYNC_TOKEN"].to_s

      if expected_token.blank?
        render json: { error: "Sync token is not configured on the server" }, status: :internal_server_error
      elsif token.blank? || !ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
