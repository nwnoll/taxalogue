# frozen_string_literal: true

require_relative '../test_helper'

class TestHttpDownloader < Test::Unit::TestCase


      def setup
            @tempfile = Tempfile.new('test_http_downloader')
            @config = OpenStruct.new(
                  address: 'https://raw.githubusercontent.com/nwnoll/RubyTree/master/setup.rb',
                  file_manager: OpenStruct.new(file_path: @tempfile)
            )
      end

      def test_run
            assert_path_exist @tempfile
            assert_true       File.zero? @tempfile

            downloader = HttpDownloader.new(config: @config)
            downloader.run

            assert_false File.zero? @tempfile

            md5sum = Digest::MD5.hexdigest(File.read(@tempfile))
            assert_equal '6bde9e51fc241e4fb3eced22b35c169a', md5sum
      end
end