module Syncs
  class Runner
    LOCK_KEY = 2_026_072_200_001
    Result = Data.define(:status, :sync_run)

    def initialize(force_full: false)
      @force_full = force_full
    end

    def call
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        return Result.new(status: :already_running, sync_run: nil) unless acquire_lock(connection)

        begin
          run = SyncRun.create!(status: "running", started_at: Time.current)
          Projects::SyncJob.perform_now
          Issues::SyncJob.perform_now(force_full: force_full, sync_run_id: run.id)
          run.reload
          run.update!(status: run.projects_failed.zero? ? "succeeded" : "failed", finished_at: Time.current)
          SyncRun.where("started_at < ?", 90.days.ago).delete_all
          Result.new(status: run.status.to_sym, sync_run: run)
        rescue StandardError => error
          if run
            run.update!(
              status: "failed",
              finished_at: Time.current,
              failure_details: run.failure_details.merge("system" => error.message)
            )
          end
          raise
        ensure
          release_lock(connection)
        end
      end
    end

    private

    attr_reader :force_full

    def acquire_lock(connection)
      connection.select_value("SELECT pg_try_advisory_lock(#{LOCK_KEY})")
    end

    def release_lock(connection)
      connection.execute("SELECT pg_advisory_unlock(#{LOCK_KEY})")
    end
  end
end
