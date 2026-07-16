module Projects
  class CuratedCatalog
    Entry = Data.define(:owner, :repo, :name, :category, :url, :fetch_all_issues)

    def call
      YAML.load_file(Rails.root.join("config/curated_projects.yml")).map do |entry|
        Entry.new(
          owner: entry.fetch("owner"),
          repo: entry.fetch("repo"),
          name: entry.fetch("repo").tr("-", " ").titleize,
          category: entry.fetch("category", "Ruby Ecosystem"),
          url: "https://github.com/#{entry.fetch("owner")}/#{entry.fetch("repo")}",
          fetch_all_issues: entry.fetch("fetch_all_issues", false)
        )
      end
    end
  end
end
