require "test_helper"
require "net/http"

class GithubClientsTest < ActiveSupport::TestCase
  # ReadmeClient Tests
  test "ReadmeClient returns body on success" do
    mock_response = ::Net::HTTPSuccess.new("1.1", "200", "OK")
    mock_response.define_singleton_method(:body) { "markdown content" }

    class << ::Net::HTTP
      alias_method :original_get_response, :get_response
      define_method(:get_response) { |url| @mock_response }
    end
    ::Net::HTTP.instance_variable_set(:@mock_response, mock_response)

    assert_equal "markdown content", Github::ReadmeClient.new.call
  ensure
    class << ::Net::HTTP
      if method_defined?(:original_get_response)
        alias_method :get_response, :original_get_response
        remove_method :original_get_response
      end
    end
  end

  test "ReadmeClient raises error on failure" do
    mock_response = ::Net::HTTPBadRequest.new("1.1", "400", "Bad Request")

    class << ::Net::HTTP
      alias_method :original_get_response, :get_response
      define_method(:get_response) { |url| @mock_response }
    end
    ::Net::HTTP.instance_variable_set(:@mock_response, mock_response)

    assert_raises(RuntimeError) do
      Github::ReadmeClient.new.call
    end
  ensure
    class << ::Net::HTTP
      if method_defined?(:original_get_response)
        alias_method :get_response, :original_get_response
        remove_method :original_get_response
      end
    end
  end

  # IssuesClient Tests
  test "IssuesClient raises error if token is missing" do
    client = Github::IssuesClient.new(token: "")
    assert_raises(RuntimeError, "GITHUB_TOKEN is missing") do
      client.open_issues(owner: "rails", repo: "rails")
    end
  end

  test "IssuesClient returns issues on success" do
    mock_response = ::Net::HTTPSuccess.new("1.1", "200", "OK")
    payload = [ { "id" => 1, "number" => 1, "title" => "Test Issue", "html_url" => "https://example.com/1", "state" => "open" } ]
    mock_response.define_singleton_method(:body) { payload.to_json }

    class << ::Net::HTTP
      alias_method :original_start, :start
      define_method(:start) do |hostname, port, options = {}, &block|
        connection = Object.new
        mock_response_captured = @mock_response
        connection.define_singleton_method(:request) do |req|
          mock_response_captured
        end
        block.call(connection)
      end
    end
    ::Net::HTTP.instance_variable_set(:@mock_response, mock_response)

    client = Github::IssuesClient.new(token: "fake_token")
    results = client.open_issues(owner: "rails", repo: "rails", labels: [ "good first issue" ])

    assert_equal 1, results.length
    assert_equal "Test Issue", results.first["title"]
  ensure
    class << ::Net::HTTP
      if method_defined?(:original_start)
        alias_method :start, :original_start
        remove_method :original_start
      end
    end
  end

  test "IssuesClient raises error on HTTP failure" do
    mock_response = ::Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
    mock_response.define_singleton_method(:body) { "[]" }

    class << ::Net::HTTP
      alias_method :original_start, :start
      define_method(:start) do |hostname, port, options = {}, &block|
        connection = Object.new
        mock_response_captured = @mock_response
        connection.define_singleton_method(:request) { |req| mock_response_captured }
        block.call(connection)
      end
    end
    ::Net::HTTP.instance_variable_set(:@mock_response, mock_response)

    client = Github::IssuesClient.new(token: "fake_token")
    assert_raises(RuntimeError) do
      client.open_issues(owner: "rails", repo: "rails", labels: [ "good first issue" ])
    end
  ensure
    class << ::Net::HTTP
      if method_defined?(:original_start)
        alias_method :start, :original_start
        remove_method :original_start
      end
    end
  end

  test "IssuesClient handles redirection and limits redirects" do
    redirect_response = ::Net::HTTPRedirection.new("1.1", "302", "Found")
    redirect_response.define_singleton_method(:[]) { |key| "https://api.github.com/redirected" if key == "location" }
    redirect_response.define_singleton_method(:fetch) { |key, *default| key == "location" ? "https://api.github.com/redirected" : (default.first || raise(KeyError)) }

    class << ::Net::HTTP
      alias_method :original_start, :start
      define_method(:start) do |hostname, port, options = {}, &block|
        connection = Object.new
        mock_response_captured = @mock_response
        connection.define_singleton_method(:request) { |req| mock_response_captured }
        block.call(connection)
      end
    end
    ::Net::HTTP.instance_variable_set(:@mock_response, redirect_response)

    client = Github::IssuesClient.new(token: "fake_token")

    assert_raises(RuntimeError, "Too many GitHub redirects") do
      client.open_issues(owner: "rails", repo: "rails", labels: [ "good first issue" ])
    end
  ensure
    class << ::Net::HTTP
      if method_defined?(:original_start)
        alias_method :start, :original_start
        remove_method :original_start
      end
    end
  end
end
