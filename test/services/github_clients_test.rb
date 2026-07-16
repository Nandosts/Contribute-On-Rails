require "test_helper"
require "net/http"

class GithubClientsTest < ActiveSupport::TestCase

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
    results = client.open_issues(owner: "rails", repo: "rails", labels: [ "good first issue" ])[:issues]

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

  test "IssuesClient returns issues with fetch_all true" do
    mock_response = ::Net::HTTPSuccess.new("1.1", "200", "OK")
    payload = [ { "id" => 1, "number" => 1, "title" => "Test Issue", "html_url" => "https://example.com/1", "state" => "open" } ]
    mock_response.define_singleton_method(:body) { payload.to_json }

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
    results = client.open_issues(owner: "rails", repo: "rails", fetch_all: true)[:issues]

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

  test "IssuesClient paginates issues when there are 100 or more" do
    mock_response_page_1 = ::Net::HTTPSuccess.new("1.1", "200", "OK")
    payload_1 = Array.new(100) { |i| { "id" => i, "number" => i, "title" => "Issue #{i}", "html_url" => "https://example.com/#{i}", "state" => "open" } }
    mock_response_page_1.define_singleton_method(:body) { payload_1.to_json }

    mock_response_page_2 = ::Net::HTTPSuccess.new("1.1", "200", "OK")
    payload_2 = [ { "id" => 101, "number" => 101, "title" => "Issue 101", "html_url" => "https://example.com/101", "state" => "open" } ]
    mock_response_page_2.define_singleton_method(:body) { payload_2.to_json }

    responses = [ mock_response_page_1, mock_response_page_2 ]

    class << ::Net::HTTP
      alias_method :original_start, :start
      define_method(:start) do |hostname, port, options = {}, &block|
        connection = Object.new
        responses_captured = @mock_responses
        connection.define_singleton_method(:request) do |req|
          responses_captured.shift
        end
        block.call(connection)
      end
    end
    ::Net::HTTP.instance_variable_set(:@mock_responses, responses)

    client = Github::IssuesClient.new(token: "fake_token")
    results = client.open_issues(owner: "rails", repo: "rails", labels: [ "good first issue" ])[:issues]

    assert_equal 101, results.length
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

  test "IssuesClient returns notmodified when receiving 304" do
    mock_response = ::Net::HTTPNotModified.new("1.1", "304", "Not Modified")

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
    results = client.open_issues(owner: "rails", repo: "rails", labels: [ "good first issue" ], etags: { "good first issue" => "some_etag" })

    refute results[:any_modified]
    assert_equal [ "good first issue" ], results[:not_modified_labels]
    assert_empty results[:issues]
    assert_equal "some_etag", results[:etags]["good first issue"]
  ensure
    class << ::Net::HTTP
      if method_defined?(:original_start)
        alias_method :start, :original_start
        remove_method :original_start
      end
    end
  end
  test "IssuesClient retries on network error and eventually raises" do
    class << ::Net::HTTP
      alias_method :original_start, :start
      define_method(:start) do |hostname, port, options = {}, &block|
        raise Errno::ECONNRESET
      end
    end

    client = Github::IssuesClient.new(token: "fake_token")
    client.define_singleton_method(:sleep) { |time| }

    assert_raises(Errno::ECONNRESET) do
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
  test "IssuesClient returns not_modified for all when fetch_all is true and receiving 304" do
    mock_response = ::Net::HTTPNotModified.new("1.1", "304", "Not Modified")

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
    results = client.open_issues(owner: "rails", repo: "rails", fetch_all: true, etags: { "all" => "some_etag" })

    refute results[:any_modified]
    assert_equal [ "all" ], results[:not_modified_labels]
    assert_empty results[:issues]
    assert_equal "some_etag", results[:etags]["all"]
  ensure
    class << ::Net::HTTP
      if method_defined?(:original_start)
        alias_method :start, :original_start
        remove_method :original_start
      end
    end
  end
end
