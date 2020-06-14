# frozen_string_literal: true

require 'open-uri'
class HttpDownloader
  private
  attr_reader :config

  public
  def initialize(config:)
    @config = config
  end

  def run
    uri = URI(config.address)

    config.address.start_with?('https') ? use_ssl = true : use_ssl = false
    
    Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl) do |http|
      request = Net::HTTP::Get.new uri

      http.request request do |response|
        p response
        p config.file_structure.file_path
        open config.file_structure.file_path, 'w' do |io|
          response.read_body do |chunk|
            p chunk
            io.write chunk
          end
        end
      end
    end
    return true
  end
end
