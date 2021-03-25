# frozen_string_literal: true

class FileManager
      attr_reader :directory, :versioning, :name, :base_dir, :dir_path, :force, :config, :multiple_files_per_dir, :created_files
      attr_accessor :status
      DATE_TIME_FORMAT = "%Y%m%dT%H%M"

      def initialize(name:, versioning: true, base_dir: '.', force: true, config: nil, multiple_files_per_dir: false)
            @base_dir               = Pathname.new(base_dir)
            @name                   = name
            @force                  = force

            current_datetime        = DateTime.now
            current_datetime        = current_datetime.strftime(DATE_TIME_FORMAT)

            @versioning             = versioning
            versioning              ? @directory = FileManager.get_versioned_file_name(name) : @directory = Pathname.new(name)

            @dir_path               = @base_dir + @directory

            @config                 = config
            @multiple_files_per_dir = multiple_files_per_dir

            @created_files          = [] 
      end

      def self.get_versioned_file_name(name)
            current_datetime        = DateTime.now
            current_datetime        = current_datetime.strftime(DATE_TIME_FORMAT)
            versioned_file_name     = Pathname.new("#{name}-#{current_datetime}")
      end

      def self.directories_of(dir:)
            dir.glob('*').select { |entry| entry.directory? }
      end
      
      def self.directories_with_name_of(dir:, dir_name:)
            dir.glob('*').select { |entry| entry.directory? && entry.basename.to_s =~ /#{dir_name}/ }
      end

      def self.most_recent_version(dirs:)
            return nil if dirs.empty?
            dirs_and_datetimes = []
            dirs.each do |dir|
                  datetime = FileManager.datetime_of(dir: dir)
                  next unless datetime
                  next if datetime == 'not_versioned'

                  dirs_and_datetimes.push([dir, datetime])
            end

            dirs_and_datetimes.sort_by! { |entry| entry.last }
            dirs_and_datetimes.last.first
      end

      def directories_of(dir:)
            dir.glob('*').select { |entry| entry.directory? }
      end

      def directories_r_of(dir:)
            dir.glob('**/*').select { |entry| entry.directory? }
      end

      def files_of(dir:)
            dir.glob('*').select { |entry| entry.file? }
      end

      def files_with_name_of(dir:)
            dir.glob('*').select { |entry| entry.file? && entry.basename.to_s =~ /#{name}/ }
            # TODO: BAD!! need another solution, could also match merged ord download_info file
      end

      def files_r_of(dir:)
            dir.glob('**/*').select { |entry| entry.file? }
      end

      def all_directories
            base_dir.glob('*').select { |entry| entry.directory? }
      end

      def all_directories_r
            base_dir.glob('**/*').select { |entry| entry.directory? }
      end

      def all_files
            base_dir.glob('*').select { |entry| entry.file? }
      end

      def all_files_r
            base_dir.glob('**/*').select { |entry| entry.file? }
      end

      def create_dir
            if dir_path.exist? && !force
                  puts "#{directory} already exists, do you want to overwrite it? [Y/n]"
                  user_input  = gets.chomp
                  replace_dir = (user_input =~ /y|yes/i) ? true : false
                  replace_dir ? FileUtils.mkdir_p(dir_path) : nil
            else
                  FileUtils.mkdir_p(dir_path)
            end
      end

      def create_file(file_name, file_type)
            path = Pathname.new(file_name)
            full_path = dir_path + path
            file = File.open(full_path, 'w')
            created_files.push(_file(full_path, file_type))
            return file
      end



      def versions
            dirs = base_dir.glob("**/#{name}*").select { |entry| entry.directory? }
      end
          
      def most_recent_version(dirs:)
            return nil unless versioning
            return nil if dirs.empty?
            dirs_and_datetimes = []
            dirs.each do |dir|
                  datetime = FileManager.datetime_of(dir: dir)
                  next if datetime == 'not_versioned'

                  dirs_and_datetimes.push([dir, datetime])
            end

            dirs_and_datetimes.sort_by! { |entry| entry.last }
            dirs_and_datetimes.last.first
      end

      def choose_version(dirs:, chosen_version:)
            dirs.each do |dir|
                  dir.split.each do |path|
                        path_matches = (path.to_s =~ /#{chosen_version}/) ? true : false
                        return dir if path_matches
                  end
            end
      end

      def self.is_older_than(datetime:, days: 90)
            return nil unless datetime
            long_time_ago = DateTime.now - days
            datetime < long_time_ago
      end

      def self.datetime_of(dir:)
            return nil unless dir
            dir               = dir
            base_name         = dir.basename.to_s
            is_versioned      = (base_name =~ /\w+-\d{8}T\d{4}/) ? true : false
            return 'not_versioned' unless is_versioned

            parts             = base_name.split('-')
            datetime          = parts.last
            datetime          = DateTime.strptime(datetime, DATE_TIME_FORMAT)
            return datetime
      end

      def file_size_of(dir:)
            files_of(dir: dir).sum { |file| File.stat(file).size }
      end

      def file_size_r_of(dir:)
            files_r_of(dir: dir).sum { |file| File.stat(file).size }
      end

      def file_path
            return nil if multiple_files_per_dir
            dir_path + _file_name
      end

      private
      def _file_name
            return nil if multiple_files_per_dir || config.nil?
            config.name + '.' + config.file_type
      end

      def _file(file_path, file_type)
            OpenStruct.new(
                  path: file_path,
                  type: file_type
            )
      end
end
