# frozen_string_literal: true

class HttpDownloader
    private
    attr_reader :config, :address

    public
    def initialize(config: nil, address: nil)
        @config = config
        @address = address
    end

    def run
        return nil if config.nil? && address.nil?

        config.nil? ? uri = URI(address) : uri = URI(config.address)

        config.address.start_with?('https') ? use_ssl = true : use_ssl = false
        # add redirect
        Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl) do |http|
            http.read_timeout = 25
            # http.read_timeout = 1
            http.max_retries  = 0
            request = Net::HTTP::Get.new uri

            http.request request do |response|
                open config.file_manager.file_path, 'w' do |io|
                    response.read_body do |chunk|
                        io.write chunk
                    end
                end
            end
        end
    end
end
