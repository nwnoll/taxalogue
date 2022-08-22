# frozen_string_literal: true

require_relative '../test_helper'

class TestTaxonomyHelper < Test::Unit::TestCase
    def test_latinize_rank
        assert_equal 'regnum',  TaxonomyHelper.latinize_rank('kingdom')
        assert_equal 'phylum',  TaxonomyHelper.latinize_rank('phylum')
        assert_equal 'ordo',    TaxonomyHelper.latinize_rank('order')
        assert_equal 'familia', TaxonomyHelper.latinize_rank('family')
        assert_equal 'genus',   TaxonomyHelper.latinize_rank('genus')
        assert_equal 'canonical_name', TaxonomyHelper.latinize_rank('species')
        assert_equal nil, TaxonomyHelper.latinize_rank(nil)
        assert_equal nil, TaxonomyHelper.latinize_rank([])
        assert_equal nil, TaxonomyHelper.latinize_rank(['test1', 'test2'])
        assert_equal nil, TaxonomyHelper.latinize_rank({})
    end
end