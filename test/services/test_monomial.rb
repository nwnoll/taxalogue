# frozen_string_literal: true

require_relative '../test_helper'

class TestMonomial < Test::Unit::TestCase

      def setup
            @query_taxon      = 'Arthropoda'
            @query_taxon_rank = 'phylum'
      end

      def test_taxonomy
            assert_kind_of GbifTaxon, Nomial.generate(name: "Absidia prolixa", query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
            # name1 = 'Hymenoptera'
            # name2 = 'Bombus terrestris2'
            # name3 = 'Bombus terrestris2 cf. terrestris'

            # assert_not_nil Nomial.generate(name: name1, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
            # assert_not_nil Nomial.generate(name: name2, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
            # assert_not_nil Nomial.generate(name: name3, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
      
            # assert_kind_of GbifTaxon, Nomial.generate(name: name1, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
            # assert_kind_of GbifTaxon, Nomial.generate(name: name2, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
            # assert_kind_of GbifTaxon, Nomial.generate(name: name3, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
      end
end