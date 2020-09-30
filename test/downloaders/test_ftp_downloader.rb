# frozen_string_literal: true

require_relative '../test_helper'

class TestFtpDownloader < Test::Unit::TestCase


      def setup
            @temp_dir = Dir.mktmpdir('test_ftp_downloader')
            @temp_file = File.join(@temp_dir, '1KB.zip')
            @config = OpenStruct.new(
                  address: 'speedtest.tele2.net',
                  target_file_base: '1KB',
                  file_structure: OpenStruct.new(directory_path: @temp_dir)
            )
      end

      def test_run
            downloader = FtpDownloader.new(config: @config)
            downloader.run

            assert_false File.zero? @temp_file

            md5sum = Digest::MD5.hexdigest(File.read(@temp_file))
            assert_equal '0f343b0931126a20f133d67c2b018a3b', md5sum
      end
end