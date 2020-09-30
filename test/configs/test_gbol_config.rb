# frozen_string_literal: true

require_relative '../test_helper'

class TestGbolConfig < Test::Unit::TestCase

      def setup
            @name             = 'GBOL_Dataset_Release-20200426'
            @source_name      = 'gbol'
            @gbol_config      = GbolConfig.new
            @file_structure   = @gbol_config.file_structure
      end

      def test_name
            assert_equal @name, @gbol_config.name
      end

      def test_downloader
            assert_equal HttpDownloader, @gbol_config.downloader
      end

      def test_address
            assert_equal 'https://bolgermany.de/release/GBOL_Dataset_Release-20200426.zip', @gbol_config.address
      end

      def test_file_type
            assert_equal 'zip', @gbol_config.file_type
      end

      def test_file_structure
            assert_kind_of FileStructure, @file_structure
            assert_equal "data/#{@source_name}/#{@name}/", @file_structure.directory_path
      end
end