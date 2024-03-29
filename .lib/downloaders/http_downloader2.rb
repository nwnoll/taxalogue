# frozen_string_literal: true

class HttpDownloader2
        private
        attr_reader :address, :destination
    
        public
        def initialize(address:, destination:)
        @address      = address
        @destination  = destination
        end
  
        def run
            uri = URI(address)
            address.start_with?('https') ? use_ssl = true : use_ssl = false

            # add redirect
            Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl) do |http|
                # http.read_timeout = 0.5
                http.max_retries  = 0
                request = Net::HTTP::Get.new uri
                http.request request do |response|
                    open destination, 'w' do |io|
                        response.read_body do |chunk|
                            io.write chunk
                        end
                    end
                end
            end
        end
  end
  