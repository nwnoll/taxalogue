# frozen_string_literal: 

class FtpDownloadGenbank
  def self.download
    dir = 'data/GenBank/sequences/'
    Dir.mkdir(dir) unless File.exists?(dir)
    division = 'inv'
    ftp = Net::FTP.new('ftp.ncbi.nlm.nih.gov')
    ftp.login

    files = ftp.chdir('genbank')
    files = ftp.nlst("gb#{division}*")
    files.each do |file|
      local_path = "#{dir}#{file}"
      puts "... downloading #{file}"
      get_with_progress(ftp, file, local_path)
      puts "... finished, file is stored at #{local_path}"
      puts
    end
    ftp.close
  end

  def self.get_with_progress(ftp,file,local_path)
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
