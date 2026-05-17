module Github
  class ProjectCatalogImporter
    Result = Data.define(:owner, :repo, :name, :category, :url, :fetch_all_issues)
    GITHUB_REPOSITORY_PATTERN = %r{https://github\.com/([\w.-]+)/([\w.-]+)}

    def initialize(markdown)
      @markdown = markdown
    end

    def call
      category = nil
      seen = Set.new

      markdown.each_line.filter_map do |line|
        category = heading_from(line) || category
        match = line.match(GITHUB_REPOSITORY_PATTERN)
        next unless match

        owner, repo = match.captures
        key = "#{owner.downcase}/#{repo.downcase}"
        next if seen.include?(key)

        seen << key
        Result.new(
          owner: owner,
          repo: repo,
          name: repo.tr("-", " ").titleize,
          category: category,
          url: "https://github.com/#{owner}/#{repo}",
          fetch_all_issues: false
        )
      end
    end

    private

    attr_reader :markdown

    def heading_from(line)
      match = line.match(/^#+\s+(.+?)\s*$/)
      match && match[1]
    end
  end
end
