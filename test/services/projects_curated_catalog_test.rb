require "test_helper"

class ProjectsCuratedCatalogTest < ActiveSupport::TestCase
  test "contains canonical ecosystem projects without duplicate repositories" do
    entries = Projects::CuratedCatalog.new.call
    slugs = entries.map { |entry| "#{entry.owner}/#{entry.repo}" }

    assert_includes slugs, "rails/rails"
    assert_includes slugs, "rubocop/rubocop"
    assert_includes slugs, "heartcombo/devise"
    assert_includes slugs, "hanami/hanami-router"
    assert_includes slugs, "dry-rb/dry-schema"
    assert_includes slugs, "bridgetownrb/bridgetown"
    assert_includes slugs, "Shopify/ruby-lsp"
    assert_equal 354, entries.size
    assert_equal slugs.uniq, slugs
  end
end
