# frozen_string_literal: true

require_relative '../test_helper'

class TestNomial < Test::Unit::TestCase

      def setup
            @query_taxon      = 'Arthropoda'
            @query_taxon_rank = 'phylum'
      end

      def test_class_generate

            nomial1     = 'Hymenoptera2'
            nomial2     = '12123'
            nomial3     = 'Hym3n0ptera'
            nomial4     = 'Hym3n0pter@'
            nomial5     = ''
            nomial6     = nil

            monomial1   = 'Hymenoptera'
            monomial2   = 'Hymenoptera nr. 99'
            monomial3   = 'Hymenoptera zz'
            monomial4   = 'Apis aff. mellifera'
            monomial5   = 'Hymenoptera sp.'
            monomial6   = 'Apis sp'
            monomial7   = 'Bombus cf. terrestris aff. terrestris'

            poylnomial1 = 'Bombus terrestris'
            poylnomial2 = 'Bombus terrestris terrestris'
            poylnomial3 = 'Bombus terrestris cf. terrestris'
            poylnomial4 = 'Bombus terrestris aff. terrestris'
            poylnomial5 = 'Bombus terrestris aff.    terrestris'
            poylnomial6 = 'Bombus terrestris aff. cf. terrestris'

            assert_kind_of Nomial, Nomial.generate(name: nomial1, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Nomial, Nomial.generate(name: nomial2, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Nomial, Nomial.generate(name: nomial3, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Nomial, Nomial.generate(name: nomial4, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Nomial, Nomial.generate(name: nomial5, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Nomial, Nomial.generate(name: nomial6, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)

            assert_kind_of Monomial, Nomial.generate(name: monomial1, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Monomial, Nomial.generate(name: monomial2, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Monomial, Nomial.generate(name: monomial3, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Monomial, Nomial.generate(name: monomial4, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Monomial, Nomial.generate(name: monomial5, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Monomial, Nomial.generate(name: monomial6, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Monomial, Nomial.generate(name: monomial7, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)

            assert_kind_of Polynomial, Nomial.generate(name: poylnomial1, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Polynomial, Nomial.generate(name: poylnomial2, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Polynomial, Nomial.generate(name: poylnomial3, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Polynomial, Nomial.generate(name: poylnomial4, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Polynomial, Nomial.generate(name: poylnomial5, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
            assert_kind_of Polynomial, Nomial.generate(name: poylnomial6, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank)
      end
end