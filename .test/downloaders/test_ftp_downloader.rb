# frozen_string_literal: true

require_relative '../test_helper'

class TestFtpDownloader < Test::Unit::TestCase

    def setup
        # @temp_dir = Dir.mktmpdir('test_ftp_downloader')
        # @temp_file = File.join(@temp_dir, '1KB.zip')
        # @config = OpenStruct.new(
        #     address: 'speedtest.tele2.net',
        #     target_file_base: '1KB',
        #     file_manager: OpenStruct.new(dir_path: @temp_dir)
        # )
        
        @original_stdout = $stdout
        # $stdout = File.open(File::NULL, 'w')

        # Dir.mktmpdir('test_ftp_downloader')
        temp_dir = Dir.mktmpdir('test_ftp_downloader/inv')
        name                = 'inv'
        parent_dir          = 'test_ftp_downloader'
        address             = 'ftp.ncbi.nlm.nih.gov'
        target_directory    = 'genbank'
        target_file_base    = "gb#{name}1.seq.gz"
        file_type           = 'seq.gz'
        @config = OpenStruct.new(
            name: name,
            markers: nil,
            parent_dir: parent_dir,
            file_manager: nil,
            use_http: false,
            address: address,
            target_directory: target_directory,
            target_file_base: target_file_base,
            file_type: file_type 
        )

        file_manager = OpenStruct.new(
            dir_path: temp_dir
        )
        @config.file_manager = file_manager
        # file_manager.config = @config
    end

    def teardown
        $stdout = @original_stdout
    end

    def test_run
        # pp @config
        # p @config.file_manager.dir_path
        # downloader = FtpDownloader.new(config: @config)
        # downloader.run

        ## speedtest currently down
        # downloader = FtpDownloader.new(config: @config)
        # downloader.run

        # assert_false File.zero? @temp_file

        # md5sum = Digest::MD5.hexdigest(File.read(@temp_file))
        # assert_equal '0f343b0931126a20f133d67c2b018a3b', md5sum
    end
end