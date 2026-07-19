module Api
  class SyncsController < ActionController::API
    before_action :authenticate_request

    def create
      Projects::SyncJob.perform_later
      Issues::SyncJob.perform_later

      render json: { status: "enqueued" }, status: :accepted
    end

    private

    def authenticate_request
      token = request.headers["Authorization"]&.split(" ")&.last || params[:token]
      expected_token = ENV["SYNC_TOKEN"]

      if expected_token.blank?
        render json: { error: "Sync token is not configured on the server" }, status: :internal_server_error
      elsif token != expected_token
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
