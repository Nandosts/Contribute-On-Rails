module Api
  class SyncsController < ActionController::API
    before_action :authenticate_request

    def create
      fetch_all = params[:fetch_all] == "true"

      Thread.new do
        Rails.application.executor.wrap do
          Projects::SyncJob.perform_now
          Issues::SyncJob.perform_now(fetch_all: fetch_all)
        end
      end

      render json: { status: "accepted" }, status: :accepted
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
