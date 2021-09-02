# frozen_string_literal: true

class TailLogic

    attr_accessor :filename, :fd
    attr_reader :mtime, :size
  
    def initialize(filename)
        @filename = filename
    end
  
    def get_fd
        @fd ||= File.open(filename, 'r')
        update_stats
    end
  
    def read(num = 10, bytes = false)
        get_fd
        pos = 0
        current_num = 0
    
        loop do
            pos -= 1
            fd.seek(pos, IO::SEEK_END)
            char = fd.read(1)
    
            if bytes || eol?(char)
                current_num += 1
            end
    
            break if current_num > num || fd.tell == 0
        end
    
        update_stats
        fd.read
    end
  
    def read_all
        update_stats
        fd.read
    end
  
    def file_changed?
        mtime != fd.stat.mtime || size != fd.size
    end
  
    private
    def eol?(char)
        char == "\n"
    end
  
    def update_stats
        @mtime = fd.stat.mtime
        @size = fd.size
    end
  
end
