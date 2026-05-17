require "test_helper"

class GithubProjectCatalogImporterTest < ActiveSupport::TestCase
  test "extracts unique github repositories and preserves headings" do
    markdown = <<~MD
      ## Rails
      - [Discourse](https://github.com/discourse/discourse)
      - [Duplicate](https://github.com/discourse/discourse)
      ## Ruby
      - [Ruby](https://github.com/ruby/ruby)
      - [External](https://example.com/project)
    MD

    entries = Github::ProjectCatalogImporter.new(markdown).call

    assert_equal 2, entries.size
    assert_equal [ "discourse", "discourse", "Rails" ], [ entries.first.owner, entries.first.repo, entries.first.category ]
    assert_equal "Ruby", entries.second.category
  end
end
