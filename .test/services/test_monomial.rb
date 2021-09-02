# frozen_string_literal: true

require_relative '../test_helper'

class TestMonomial < Test::Unit::TestCase

    def setup
        @query_taxon            = 'Arthropoda'
        @query_taxon_rank       = 'phylum'
        @query_taxon_object     = TaxonHelper.choose_ncbi_record(taxon_name: @query_taxon)
        @taxonomy_params        = {ncbi: true}
        @first_specimen_info    = "Animalia, Arthropoda, Arachnida, Araneae, Linyphiidae\tAbacoproeces saltuum\tTACTTTGTATTTTGTTTTTGGGGCTTGGGCTGCTATAGTAGGGACAGCAATAAGAGTTTTAATTCGGGTTGAGTTAGGTCAGACTGGTAGATTGTTGGGAGATGACCAACTATATAATGTAATTGTTACTGCTCACGCATTTGTTATAATTTTTTTTATGGTTATACCTATTTTAATTGGGGGGTTTGGAAATTGATTGGTCCCTTTGATATTAGGAGCGCCTGATATGGCTTTTCCACGTATGAATAATTTAAGCTTTTGACTATTGCCCCCATCTTTATTGTTATTATCTATTTCTAGTGTGGATGAGATAGGGGTTGGTGCGGGGTGGACTATTTATCCCCCCCTTGCTTCTTTAGAGGGTCATTCTGGGAGATCAGTAGATTTTGCTATTTTTTCTTTGCATCTAGCTGGGGCATCTTCTATTATAGGGGCAATTAATTTTATTTCTACTATTTTTAATATGCGGGGGTGTGGAATAACCTTGGAAAAAACTCCACTATTTGTTTGGTCTGTCTTAATTACTGCTATTTTATTATTGTTATCTCTTCCCGTGTTAGCAGGAGCTATTACAATGCTGTTAACAGATCGAAATTTTAATACGTCATTTTTTGATCCTAGTGGGGGGGGGGATCCTGTTTTGTTTCAGCACCTATTT\tZFMK\tZFMK-TIS-2538109\thttps://bolgermany.de/specimen/31fdbc1094de5e20f132a7fd7779855c\tSachsen-Anhalt, Germany, Bitterfeld\t51.66\t12.41"
        @importer               = GbolClassifier
    end

    def test_taxonomy
        assert_kind_of OpenStruct, Nomial.generate(name: "Absidia prolixa", query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).taxonomy(first_specimen_info: @first_specimen_info, importer: @importer)
        # name1 = 'Hymenoptera'
        # name2 = 'Bombus terrestris2'
        # name3 = 'Bombus terrestris2 cf. terrestris'

        # assert_not_nil Nomial.generate(name: name1, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
        # assert_not_nil Nomial.generate(name: name2, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
        # assert_not_nil Nomial.generate(name: name3, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy

        # assert_kind_of GbifTaxonomy, Nomial.generate(name: name1, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
        # assert_kind_of GbifTaxonomy, Nomial.generate(name: name2, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
        # assert_kind_of GbifTaxonomy, Nomial.generate(name: name3, query_taxon: @query_taxon, query_taxon_rank: @query_taxon_rank).taxonomy
    end
end