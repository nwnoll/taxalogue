# frozen_string_literal: true

require_relative '../test_helper'

class TestNcbiGenbankConfig < Test::Unit::TestCase

      def setup
            @name                   = 'Lentulidae'
            @source_name            = 'ncbigenbank'
            @ncbi_genbank_config    = NcbiGenbankConfig.new(name: @name)
            @file_structure         = @ncbi_genbank_config.file_structure
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

      def test_file_structure
            assert_kind_of FileStructure, @file_structure
            assert_equal "data/#{@source_name}/#{@name}/", @file_structure.directory_path
      end
end