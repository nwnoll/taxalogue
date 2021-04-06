# frozen_string_literal: true

require_relative '../test_helper'

class TestNcbiGenbankConfig < Test::Unit::TestCase

      def setup
            @name                   = 'Lentulidae'
            @source_name            = 'NCBIGENBANK'
            @parent_dir_name        = 'parent_dir'
            @ncbi_genbank_config    = NcbiGenbankConfig.new(name: @name, parent_dir: @parent_dir_name)
            @file_manager           = @ncbi_genbank_config.file_manager
      end

      def test_name
            assert_equal @name, @ncbi_genbank_config.name
      end

      def test_downloader
            assert_equal FtpDownloader, @ncbi_genbank_config.downloader
      end

      def test_address
            assert_equal 'ftp.ncbi.nlm.nih.gov', @ncbi_genbank_config.address
      end

      def test_file_type
            assert_equal 'seq.gz', @ncbi_genbank_config.file_type
      end

      def test_file_manager
            assert_kind_of FileManager, @file_manager
            assert_equal Pathname.new("fm_data/#{@source_name}/#{@name}"), @file_manager.dir_path
      end

      def test_parent_dir
            assert_equal 'parent_dir', @ncbi_genbank_config.parent_dir
            assert_equal Pathname.new(NcbiGenbankConfig::DOWNLOAD_DIR + @parent_dir_name), @file_manager.base_dir
      end
end