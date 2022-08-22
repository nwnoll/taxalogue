# frozen_string_literal: true

class FtpDownloader
    attr_reader :config

    RESTART_WAIT = 30
    @@count_restarts        = 0
    @@all_files_of_division = []


    def initialize(config:)
        @config = config
    end


    def self.rewind
        @@count_restarts = 0
    end


    def self.get_files_per_division(configs)
        begin
            download_success_of_division_file = Hash.new

            
            configs.each do |config|
                ftp = Net::FTP.new(config.address)
                ftp.login


                if config.target_directory
                    ftp.chdir(config.target_directory)
                    files = ftp.nlst("#{config.target_file_base}*")
                end
                ftp.close


                files.each do |file|
                    download_success_of_division_file[file] = false
                end
            end


            return download_success_of_division_file
        rescue SocketError
            return nil
        end
    end


    ## TODO:
    # I need to know wat kind of files where already downloaded and successfull
    # If i just say that with every initialition all files are considered not not downloaded
    # we might have a problem if we wnat to check failed downloads... but maybe not since I will 
    # have an inject function that does change the class variable based on the text file in the folder?
    # maybe here I could also allow NOT taxalogue GENBANK folder by creating the download info files?
    def run(download_success_of_division_file:)
        puts 'ftp_downloader started'
        puts "count_restarts: #{@@count_restarts}"


        needs_restart       = false
        text                = nil
        has_ftp_connection  = false


        ## connects to FTP server and goes into directory
        begin
            ftp = Net::FTP.new(config.address, read_timeout: 3)
            ftp.login
            ftp.chdir(config.target_directory) if config.target_directory
        rescue StandardError
            @@count_restarts += 1
            puts "FTP connection failed\nrestart #{@@count_restarts} starts in #{RESTART_WAIT} seconds"


            needs_restart = true
            sleep RESTART_WAIT
        else
            has_ftp_connection = true
        end


        ## downloads all failed files
        if has_ftp_connection
            download_success_of_division_file.keys.each_with_index do |file, i|
                next if download_success_of_division_file[file]

                ## TODO:
                ## REMOVE!
                ## just for testing
                # download_success_of_division_file[file] = true
                # break if i == 1


                local_path = File.join(config.file_manager.dir_path, file)
                begin
                    puts "downloading #{file}"
                    ftp.get(file, local_path)
                    sleep 2
                rescue
                    @@count_restarts += 1
                    text = "error while downloading file: #{file}\nrestart #{@@count_restarts} starts in #{RESTART_WAIT} seconds" 
                    

                    needs_restart = true
                end


                ## download failure 
                if needs_restart
                    _prepare_restart(text: text, ftp: ftp)
                    break
                end
                
                
                ## download did succeed but downloaded file was malformed
                is_gz_valid = MiscHelper.is_gz_valid?(local_path)
                unless is_gz_valid
                    @@count_restarts += 1
                    
                    
                    text = "malformed file: #{file}\nrestart #{@@count_restarts} starts in #{RESTART_WAIT} seconds"
                    _prepare_restart(text: text, ftp: ftp)
                    needs_restart = true
                    break
                end


                ## too many failures, servers seem to be slow or unresponsive
                if @@count_restarts > 30
                    FtpDownloader.rewind
                    raise StandardError
                end


                download_success_of_division_file[file] = true
            end
        end

        
        if needs_restart
            ftp_downloader = FtpDownloader.new(config: config)
            ftp_downloader.run(download_success_of_division_file: download_success_of_division_file)
        end


        FtpDownloader.rewind
    end
        

    private
    def _prepare_restart(text:, ftp:)
        puts text
        
        ftp.close
        sleep RESTART_WAIT
    end


    ## UNUSED
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
