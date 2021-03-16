# frozen_string_literal: true

require_relative '../test_helper'

class TestNcbiTaxonomyConfig < Test::Unit::TestCase

      def setup
            @name                   = 'NCBI_TAXONOMY'
            @ncbi_taxonomy_config   = NcbiTaxonomyConfig.new
            @file_manager           = @ncbi_taxonomy_config.file_manager
      end

      def test_name
            assert_equal @name, @ncbi_taxonomy_config.name
      end

      def test_downloader
            assert_equal HttpDownloader, @ncbi_taxonomy_config.downloader
      end

      def test_importers
            assert_kind_of    Hash, @ncbi_taxonomy_config.importers
            assert_equal      3, @ncbi_taxonomy_config.importers.size
            assert_true       @ncbi_taxonomy_config.importers.key?(:NcbiRankedLineageImporter)
            assert_true       @ncbi_taxonomy_config.importers.key?(:NcbiNodeImporter)
            assert_true       @ncbi_taxonomy_config.importers.key?(:NcbiNameImporter)
            assert_equal      'rankedlineage.dmp', @ncbi_taxonomy_config.importers[:NcbiRankedLineageImporter]
            assert_equal      'nodes.dmp', @ncbi_taxonomy_config.importers[:NcbiNodeImporter]
            assert_equal      'names.dmp', @ncbi_taxonomy_config.importers[:NcbiNameImporter]
      end

      def test_address
            assert_equal 'https://ftp.ncbi.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.zip', @ncbi_taxonomy_config.address
      end

      def test_file_type
            assert_equal 'zip', @ncbi_taxonomy_config.file_type
      end

      def test_file_structure
            assert_kind_of FileManager, @file_manager
      end
end