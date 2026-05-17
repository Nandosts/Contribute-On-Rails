module Projects
  class CuratedCatalog
    Entry = Data.define(:owner, :repo, :name, :category, :url)

    def call
      YAML.load_file(Rails.root.join("config/curated_projects.yml")).map do |entry|
        Entry.new(
          owner: entry.fetch("owner"),
          repo: entry.fetch("repo"),
          name: entry.fetch("repo").tr("-", " ").titleize,
          category: entry.fetch("category"),
          url: "https://github.com/#{entry.fetch("owner")}/#{entry.fetch("repo")}"
        )
      end
    end
  end
end
