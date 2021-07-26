# frozen_string_literal: true

class FtpDownloader
    attr_reader :config

    @@count_restarts = 0

    def initialize(config:)
      @config = config
    end

    def self.rewind
        @@count_restarts = 0
    end

    def run(files_to_download: [])
        puts 'ftp_downloader started'
        puts "count_restarts: #{@@count_restarts}"
        pp files_to_download
        ftp = Net::FTP.new(config.address)
        ftp.login
        files = ftp.chdir(config.target_directory) if config.target_directory
        files = ftp.nlst("#{config.target_file_base}*") if config.target_directory
        files = files_to_download if files_to_download.any?

        ##
        # files = files.select { |f| ["gbinv231.seq.gz", "gbinv190.seq.gz", "gbinv135.seq.gz"].include?(f) }

        needs_restart = false

        files.reverse.each_with_index do |file, i|
            # next if files_to_download.any? && !files_to_download.include?(file.to_s)
            local_path = File.join(config.file_manager.dir_path, file)
            ## exclude later
            # next if File.file?(local_path) && !File.zero?(local_path) && !files_to_download.include?(file.to_s)
            begin
                puts "downloading #{file}"
                ftp.get(file, local_path, 32768)
                sleep 2
                if i == 1
                    raise Net::ReadTimeout
                end
            rescue => e
                puts "error while downloading file: #{file}"
                puts e.inspect
                puts "restarting soon"
                @@count_restarts += 1
                puts "restart num: #{@@count_restarts}"
                # run_out_file.puts
                # run_out_file.puts 'already downloaded:'
                # already_downloaded = files - missing_files
                # already_downloaded.each { |f| run_out_file.puts f }
                # run_out_file.puts (files - missing_files)
                # run_out_file.puts
                # run_out_file.puts 'files to download:'
                # run_out_file.puts missing_files
                # run_out_file.puts
                # sleep 5
                if @@count_restarts > 20
                    FtpDownloader.rewind
                    return files
                end
                ftp.close
                print 'ftp.closed?'
                puts ftp.closed?
                puts 'waiting 60 seconds'

                needs_restart = true
                sleep 60
                break
            end
            files.delete(file)
        end

        if needs_restart
            puts 'restart!'

            ftp_downloader = FtpDownloader.new(config: config)
            ftp_downloader.run(files_to_download: files)
        end
    end

    private
    def _get_with_progress(ftp,file,local_path)
        transferred = 0
        filesize = ftp.size(file)
        ftp.get(file, local_path, 32768) do |data|
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
