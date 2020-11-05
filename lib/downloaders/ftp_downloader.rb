# frozen_string_literal: true

class FtpDownloader
    private
    attr_reader :config

    public
    def initialize(config:)
      @config = config
    end

    def run
        p 'in'
        ftp = Net::FTP.new(config.address)
        ftp.login
        files = ftp.chdir(config.target_directory) if config.target_directory
        files = ftp.nlst("#{config.target_file_base}*")
        files.each_with_index do |file, i|
          p file
          break if i == 1
          next
          # next if file.to_s == "gbinv35.seq.gz"
          local_path = File.join(config.file_manager.dir_path, file)
          puts "local_path: #{local_path}"
          puts "... downloading #{file}"
          _get_with_progress(ftp, file, local_path)
          puts "... finished, file is stored at #{local_path}"
          puts
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