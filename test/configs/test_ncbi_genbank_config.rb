# frozen_string_literal: true

require_relative '../test_helper'

class TestNcbiGenbankConfig < Test::Unit::TestCase

      def setup
            @name                   = 'Lentulidae'
            @source_name            = 'ncbigenbank'
            @ncbi_genbank_config    = NcbiGenbankConfig.new(name: @name)
            @file_structure         = @ncbi_genbank_config.file_structure

            # @parent_dir_name        = 'Orthoptera'
            # @ncbi_genbank_config_pd = NcbiGenbankConfig.new(name: @name, parent_dir: @parent_dir_name)
            # @file_structure_pd      = @bold_conncbi_genbank_config_pdfig_pd.file_structure
      end

      def test_name
            assert_equal @name, @ncbi_genbank_config.name
            # assert_equal @name, @ncbi_genbank_config_pd.name
      end

      def test_downloader
            assert_equal FtpDownloader, @ncbi_genbank_config.downloader
            # assert_equal FtpDownloader, @ncbi_genbank_config_pd.downloader
      end

      def test_address
            assert_equal 'ftp.ncbi.nlm.nih.gov', @ncbi_genbank_config.address
            # assert_equal 'ftp.ncbi.nlm.nih.gov', @ncbi_genbank_config_pd.address
      end

      def test_file_type
            assert_equal 'seq.gz', @ncbi_genbank_config.file_type
            # assert_equal 'seq.gz', @ncbi_genbank_config_pd.file_type
      end

      def test_file_structure
            assert_kind_of FileStructure, @file_structure
            assert_equal "data/#{@source_name}/#{@name}/", @file_structure.directory_path
            # assert_equal "data/#{@source_name}/#{@parent_dir_name}/#{@name}/", @file_structure_pd.directory_path
      end
end