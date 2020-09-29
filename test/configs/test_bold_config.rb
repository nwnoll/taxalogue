# frozen_string_literal: true

require_relative '../test_helper'

class TestBoldConfig < Test::Unit::TestCase

      def setup
            @name                   = 'Lentulidae'
            @source_name            = 'bold'
            @bold_config            = BoldConfig.new(name: @name)
            @file_structure         = @bold_config.file_structure

            @parent_dir_name        = 'Orthoptera'
            @bold_config_pd         = BoldConfig.new(name: @name, parent_dir: @parent_dir_name)
            @file_structure_pd      = @bold_config_pd.file_structure
      end

      def test_name
            assert_equal @name, @bold_config.name
            assert_equal @name, @bold_config_pd.name
      end

      def test_markers
            assert_kind_of Marker
            assert_kind_of Marker
            assert_equal 'COI-5P', @bold_config.markers
            assert_equal 'COI-5P', @bold_config_pd.markers

            marker1     = Marker.new(query_marker_name: 'coi')
            bc1         = BoldConfig.new(name: @name, markers: marker1)
            assert_equal 'COI-5P', bc1.markers
      end

      def test_parent_dir
            assert_equal nil, @bold_config.parent_dir
            assert_equal @parent_dir_name, @bold_config_pd.parent_dir
      end

      def test_downloader
            assert_equal HttpDownloader, @bold_config.downloader
            assert_equal HttpDownloader, @bold_config_pd.downloader
      end

      def test_address
            assert_equal "http://www.boldsystems.org/index.php/API_Public/combined?taxon=#{@name}&format=tsv", @bold_config.address
            assert_equal "http://www.boldsystems.org/index.php/API_Public/combined?taxon=#{@name}&format=tsv", @bold_config_pd.address
      end

      def test_file_type
            assert_equal 'tsv', @bold_config.file_type
            assert_equal 'tsv', @bold_config_pd.file_type
      end

      def test_file_structure
            assert_kind_of FileStructure, @file_structure
            assert_equal "data/#{@source_name}/#{@name}/", @file_structure.directory_path
            assert_equal "data/#{@source_name}/#{@parent_dir_name}/#{@name}/", @file_structure_pd.directory_path
      end

      # def test__join_markers
      #       @bold_config.send(:_join_markers, args)
      # end
end