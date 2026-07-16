module Projects
  class SyncService
    def call
      entries = catalog_entries
      total = entries.size
      progress = 0
      synced_names = []

      Project.transaction do
        imported_ids = []
        entries.each do |entry|
          progress += 1
          print "\rSyncing Projects: #{progress}/#{total} (#{entry.repo})".ljust(80) if $stdout.tty?

          project = Project.find_or_initialize_by(github_owner: entry.owner, github_repo: entry.repo)
          project.update!(name: entry.name, source_category: entry.category, github_url: entry.url, active: true, fetch_all_issues: entry.fetch_all_issues)
          synced_names << entry.repo
          imported_ids << project.id
        end

        Project.where.not(id: imported_ids).update_all(active: false, updated_at: Time.current)
      end

      if $stdout.tty?
        puts "\nCompleted! Synced repos: #{synced_names.join(', ')}"
      end
    end

    private

    def catalog_entries
      CuratedCatalog.new.call.index_by { |entry| [ entry.owner.downcase, entry.repo.downcase ] }.values
    end
  end
end
