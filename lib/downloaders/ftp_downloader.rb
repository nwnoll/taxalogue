# frozen_string_literal: true

class FtpDownloader
    private
    attr_reader :config

    public
    def initialize(config:)
      @config = config
    end

    def run(files_to_download: [])
        ## catch if offline
        ftp = Net::FTP.new(config.address)
        ftp.login
        files = ftp.chdir(config.target_directory) if config.target_directory
        files = ftp.nlst("#{config.target_file_base}*")
        app_out_file = File.open('run.txt', 'w')
        redo_count = 0
        files.each_with_index do |file, i|
            # break if i == 1
            next if files_to_download.any? && !files_to_download.include?(file.to_s)
            #   next unless file.to_s == "gbinv35.seq.gz"
            local_path = File.join(config.file_manager.dir_path, file)
            puts "local_path: #{local_path}"
            puts "... downloading #{file}"
            begin
                _get_with_progress(ftp, file, local_path)
            rescue => e
                redo_count += 1
                if redo_count == 6
                    puts "error while downloading #{file}"
                    puts "retry: #{redo_count}"
                    puts "last try"
                    puts "waiting 180 seconds"
                    sleep 180
                    redo                  
                elsif redo_count > 6
                    redo_count = 0
                    next
                end
                app_out_file.puts "local_path: #{local_path}"
                app_out_file.puts "file: #{file}"
                app_out_file.puts 'error:'
                app_out_file.puts e.inspect
                app_out_file.puts
                puts "error while downloading #{file}"
                puts "retry: #{redo_count}"
                puts "waiting 120 seconds"
                sleep 120
                redo
            end
            puts "... finished, file is stored at #{local_path}"
            puts
            sleep 5
        end
        ftp.close
    end

    private
    def _get_with_progress(ftp,file,local_path)
        transferred = 0
        filesize = ftp.size(file)
        ftp.get(file, local_path, 1024) do |data|
          transferred  += data.size
          percent       = ((transferred.to_f/filesize.to_f)*100).to_i
          finished      = ((transferred.to_f/filesize.to_f)*30).to_i
          not_finished  = 30 - finished
          print "\r"
          print "#{"%3i" % percent}%"
          print "["
          finished.downto(1) { |n| print "=" }
          print ">"
          not_finished.downto(1) { |n| print " " }
          print "]"
        end
        print "\n"
      end
end