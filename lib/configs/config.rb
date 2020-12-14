# frozen_string_literal: true

class Config
    attr_reader :params, :name, :address, :file_type, :downloader, :importers, :file_manager, :target_directory, :target_file_base, :multiple_files_per_dir

    def initialize(params)
        @params                 = params
        @name                   = _name
        @address                = _address
        @file_type              = _file_type
        @downloader             = _downloader
        @importers              = _importers
        @file_manager           = _file_manager
        @target_directory       = _target_directory
        @target_file_base       = _target_file_base
        @multiple_files_per_dir = _multiple_files_per_dir
    end

    private
    def _name
        params["name"]
    end

    def _downloader
        Helper.constantize(params["downloader"])
    end

    def _address
        params["address"]
    end

    def _file_type
        params["file_type"]
    end

    def _importers
        params["importers"]
    end

    def _target_directory
        params["target_directory"]
    end

    def _target_file_base
        params["target_file_base"]
    end

    def _file_manager
        FileManager.new(name: name, versioning: params["versioning"], base_dir: params["base_dir"], config: self)
    end

    def _multiple_files_per_dir
        params["multiple_files_per_dir"]
    end
end