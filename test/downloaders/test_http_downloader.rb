# frozen_string_literal: true

require_relative '../test_helper'

class TestHttpDownloader < Test::Unit::TestCase

      def setup
            @bold_config = BoldConfig.new(name: 'Lentulidae')
            @bold_job = BoldJob.new(taxon: @taxon, taxonomy: GbifTaxon)
      end

      def test_taxon
            assert_equal @taxon.regnum, 'Animalia'
            assert_equal @taxon.phylum, 'Arthropoda'
            assert_equal @taxon.canonical_name, 'Arthropoda'
            assert_equal @taxon.classis, nil
            assert_equal @taxon.ordo, nil
            assert_equal @taxon.familia, nil
            assert_equal @taxon.genus, nil
            assert_equal @taxon.taxon_rank, 'phylum'
      end
end