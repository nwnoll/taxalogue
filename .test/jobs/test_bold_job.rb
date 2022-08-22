# frozen_string_literal: true

require_relative '../test_helper'

class TestBoldJob < Test::Unit::TestCase

    def setup
        params = Hash.new { |h,k| h[k]= Hash.new }
        params[:taxonomy][:ncbi] =  true

        @query_taxon            = 'Arthropoda'
        @query_taxon_rank       = 'phylum'
        @query_taxon_object     = TaxonHelper.choose_ncbi_record(taxon_name: @query_taxon, params: params)
        @taxonomy_params        = {ncbi: true}
        @first_specimen_info    = "Animalia, Arthropoda, Arachnida, Araneae, Linyphiidae\tAbacoproeces saltuum\tTACTTTGTATTTTGTTTTTGGGGCTTGGGCTGCTATAGTAGGGACAGCAATAAGAGTTTTAATTCGGGTTGAGTTAGGTCAGACTGGTAGATTGTTGGGAGATGACCAACTATATAATGTAATTGTTACTGCTCACGCATTTGTTATAATTTTTTTTATGGTTATACCTATTTTAATTGGGGGGTTTGGAAATTGATTGGTCCCTTTGATATTAGGAGCGCCTGATATGGCTTTTCCACGTATGAATAATTTAAGCTTTTGACTATTGCCCCCATCTTTATTGTTATTATCTATTTCTAGTGTGGATGAGATAGGGGTTGGTGCGGGGTGGACTATTTATCCCCCCCTTGCTTCTTTAGAGGGTCATTCTGGGAGATCAGTAGATTTTGCTATTTTTTCTTTGCATCTAGCTGGGGCATCTTCTATTATAGGGGCAATTAATTTTATTTCTACTATTTTTAATATGCGGGGGTGTGGAATAACCTTGGAAAAAACTCCACTATTTGTTTGGTCTGTCTTAATTACTGCTATTTTATTATTGTTATCTCTTCCCGTGTTAGCAGGAGCTATTACAATGCTGTTAACAGATCGAAATTTTAATACGTCATTTTTTGATCCTAGTGGGGGGGGGGATCCTGTTTTGTTTCAGCACCTATTT\tZFMK\tZFMK-TIS-2538109\thttps://bolgermany.de/specimen/31fdbc1094de5e20f132a7fd7779855c\tSachsen-Anhalt, Germany, Bitterfeld\t51.66\t12.41"
        @importer               = GbolClassifier
    end

    def test_taxonomy
    end
end