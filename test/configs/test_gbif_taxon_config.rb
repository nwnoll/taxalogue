# frozen_string_literal: true

require_relative '../test_helper'

class TestGbifTaxonConfig < Test::Unit::TestCase

      def setup
            @name             = 'backbone'
            @gbif_taxon_config      = GbifTaxonConfig.new
            @file_structure   = @gbif_taxon_config.file_structure
      end

      def test_name
            assert_equal @name, @gbif_taxon_config.name
      end

      def test_downloader
            assert_equal HttpDownloader, @gbif_taxon_config.downloader
      end

      def test_importers
            assert_kind_of    Hash, @gbif_taxon_config.importers
            assert_equal      1, @gbif_taxon_config.importers.size
            assert_true       @gbif_taxon_config.importers.key?(:GbifTaxonImporter)
            assert_equal      'taxon.tsv', @gbif_taxon_config.importers[:GbifTaxonImporter]
      end

      def test_address
            assert_equal 'https://hosted-datasets.gbif.org/datasets/backbone/backbone-current.zip', @gbif_taxon_config.address
      end

      def test_file_type
            assert_equal 'zip', @gbif_taxon_config.file_type
      end

      def test_file_structure
            assert_kind_of FileStructure, @file_structure
      end
end