# frozen_string_literal: true

require_relative '../test_helper'

class TestGbolConfig < Test::Unit::TestCase

      def setup
            @name             = 'GBOL_Dataset_Release-20210128'
            @source_name      = 'GBOL'
            @gbol_config      = GbolConfig.new
            @file_manager      = @gbol_config.file_manager
      end

      def test_name
            assert_equal @name, @gbol_config.name
      end

      def test_downloader
            assert_equal HttpDownloader, @gbol_config.downloader
      end

      def test_address
            assert_equal 'https://www.bolgermany.de/gbol1/release/GBOL_Dataset_Release-20210128.zip', @gbol_config.address
      end

      def test_file_type
            assert_equal 'zip', @gbol_config.file_type
      end

      def test_file_manager
            assert_kind_of FileManager, @file_manager
            assert_equal Pathname.new("downloads/#{@source_name}/#{@name}"), @file_manager.dir_path
      end
end