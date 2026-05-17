require "net/http"
require "json"

module Github
  class ReadmeClient
    URL = URI("https://raw.githubusercontent.com/asyraffff/Open-Source-Ruby-and-Rails-Apps/main/README.md")

    def call
      response = Net::HTTP.get_response(URL)
      raise "GitHub README request failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  end
end
