# frozen_string_literal: true

require_relative '../test_helper'

class TestMonomial < Test::Unit::TestCase
    def setup
        @lentulidae_obj    = OpenStruct.new(
            taxon_id: 62781,
            regnum: 'Metazoa',
            phylum: 'Arthropoda',
            classis: 'Insecta',
            ordo: 'Orthoptera',
            familia: 'Lentulidae',
            genus: '',
            canonical_name: 'Lentulidae',
            scientific_name: 'Lentulidae',
            taxonomic_status: 'accepted',
            taxon_rank: 'family',
            comment: ''
        )
    
    
        # #<ActiveRecord::Relation [#<NcbiName id: 19762, tax_id: 6656, name: "Arthropoda", unique_name: "", name_class: "scientific name", created_at: "2022-02-15 18:32:14", updated_at: "2022-02-15 18:32:14">]>
        NcbiName.create!(
            tax_id: 6656,
            name: 'Arthropoda',
            unique_name: '', 
            name_class: 'scientific name'
        )
    
    
        # #<NcbiRankedLineage id: 867858, tax_id: 6656, name: "Arthropoda", species: "", genus: "", familia: "", ordo: "", classis: "", phylum: "", regnum: "Metazoa", super_regnum: "Eukaryota", created_at: "2022-02-15 18:54:32", updated_at: "2022-02-15 18:54:32">
        NcbiRankedLineage.create!(
            tax_id: 6656,
            name: "Arthropoda",
            species: "",
            genus: "",
            familia: "",
            ordo: "",
            classis: "",
            phylum: "Arthropoda",
            regnum: "Metazoa",
            super_regnum: "Eukaryota"
        )
    
    
        # #<NcbiNode id: 5355, tax_id: 6656, parent_tax_id: 88770, rank: "phylum", division_id: 1, genetic_code_id: 1, mito_genetic_code_id: 5, has_specified_species: false, plastid_genetic_code_id: 0, created_at: "2022-02-15 19:02:08", updated_at: "2022-02-15 19:02:08">
        NcbiNode.create!(
            tax_id: 6656,
            parent_tax_id: 88770,
            rank: "phylum",
            division_id: 1,
            genetic_code_id: 1,
            mito_genetic_code_id: 5,
            has_specified_species: false,
            plastid_genetic_code_id: 0
        )
    
    
        # #<GbifTaxonomy id: 162, taxon_id: 54, dataset_id: "daacce49-b206-469b-8dc2-2257719f3afa", parent_name_usage_id: "1", accepted_name_usage_id: nil, original_name_usage_id: nil, scientific_name: "Arthropoda", scientific_name_authorship: nil, canonical_name: "Arthropoda", generic_name: "Arthropoda", specific_epithet: nil, infraspecific_epithet: nil, taxon_rank: "phylum", name_according_to: nil, name_published_in: "von Siebold, C.T. & Stannius, H. Lehrbuch der verg...", taxonomic_status: "accepted", nomenclatural_status: nil, taxon_remarks: nil, regnum: "Animalia", phylum: "Arthropoda", classis: nil, ordo: nil, familia: nil, genus: nil, created_at: "2022-02-15 15:38:09", updated_at: "2022-02-15 15:38:09">
        GbifTaxonomy.create!(
            taxon_id: 54,
            dataset_id: "daacce49-b206-469b-8dc2-2257719f3afa",
            parent_name_usage_id: "1",
            accepted_name_usage_id: nil,
            original_name_usage_id: nil,
            scientific_name: "Arthropoda",
            scientific_name_authorship: nil,
            canonical_name: "Arthropoda",
            generic_name: "Arthropoda",
            specific_epithet: nil,
            infraspecific_epithet: nil,
            taxon_rank: "phylum",
            name_according_to: nil,
            name_published_in: "von Siebold, C.T. & Stannius, H. Lehrbuch der verg...",
            taxonomic_status: "accepted",
            nomenclatural_status: nil,
            taxon_remarks: nil,
            regnum: "Animalia",
            phylum: "Arthropoda",
            classis: nil,
            ordo: nil,
            familia: nil,
            genus: nil
        )


        params = Hash.new { |h,k| h[k]= Hash.new }
        params[:taxonomy][:ncbi] =  true


        @query_taxon            = 'Arthropoda'
        @query_taxon_rank       = 'phylum'
        @query_taxon_object     = TaxonHelper.choose_ncbi_record(taxon_name: @query_taxon, params: params)
        @taxonomy_params        = {ncbi: true}
        # @first_specimen_info    = "Animalia, Arthropoda, Arachnida, Araneae, Linyphiidae\tAbacoproeces saltuum\tTACTTTGTATTTTGTTTTTGGGGCTTGGGCTGCTATAGTAGGGACAGCAATAAGAGTTTTAATTCGGGTTGAGTTAGGTCAGACTGGTAGATTGTTGGGAGATGACCAACTATATAATGTAATTGTTACTGCTCACGCATTTGTTATAATTTTTTTTATGGTTATACCTATTTTAATTGGGGGGTTTGGAAATTGATTGGTCCCTTTGATATTAGGAGCGCCTGATATGGCTTTTCCACGTATGAATAATTTAAGCTTTTGACTATTGCCCCCATCTTTATTGTTATTATCTATTTCTAGTGTGGATGAGATAGGGGTTGGTGCGGGGTGGACTATTTATCCCCCCCTTGCTTCTTTAGAGGGTCATTCTGGGAGATCAGTAGATTTTGCTATTTTTTCTTTGCATCTAGCTGGGGCATCTTCTATTATAGGGGCAATTAATTTTATTTCTACTATTTTTAATATGCGGGGGTGTGGAATAACCTTGGAAAAAACTCCACTATTTGTTTGGTCTGTCTTAATTACTGCTATTTTATTATTGTTATCTCTTCCCGTGTTAGCAGGAGCTATTACAATGCTGTTAACAGATCGAAATTTTAATACGTCATTTTTTGATCCTAGTGGGGGGGGGGATCCTGTTTTGTTTCAGCACCTATTT\tZFMK\tZFMK-TIS-2538109\thttps://bolgermany.de/specimen/31fdbc1094de5e20f132a7fd7779855c\tSachsen-Anhalt, Germany, Bitterfeld\t51.66\t12.41"
        @first_specimen_info  = {
            'HigherTaxa' => "Animalia, Arthropoda, Arachnida, Araneae, Linyphiidae", 
            'Species' => "Abacoproeces saltuum", 
            'BarcodeSequence' => "TACTTTGTATTTTGTTTTTGGGGCTTGGGCTGCTATAGTAGGGACAGCAATAAGAGTTTTAATTCGGGTTGAGTTAGGTCAGACTGGTAGATTGTTGGGAGATGACCAACTATATAATGTAATTGTTACTGCTCACGCATTTGTTATAATTTTTTTTATGGTTATACCTATTTTAATTGGGGGGTTTGGAAATTGATTGGTCCCTTTGATATTAGGAGCGCCTGATATGGCTTTTCCACGTATGAATAATTTAAGCTTTTGACTATTGCCCCCATCTTTATTGTTATTATCTATTTCTAGTGTGGATGAGATAGGGGTTGGTGCGGGGTGGACTATTTATCCCCCCCTTGCTTCTTTAGAGGGTCATTCTGGGAGATCAGTAGATTTTGCTATTTTTTCTTTGCATCTAGCTGGGGCATCTTCTATTATAGGGGCAATTAATTTTATTTCTACTATTTTTAATATGCGGGGGTGTGGAATAACCTTGGAAAAAACTCCACTATTTGTTTGGTCTGTCTTAATTACTGCTATTTTATTATTGTTATCTCTTCCCGTGTTAGCAGGAGCTATTACAATGCTGTTAACAGATCGAAATTTTAATACGTCATTTTTTGATCCTAGTGGGGGGGGGGATCCTGTTTTGTTTCAGCACCTATTT", 
            'Institute' => "ZFMK",
            'CatalogueNumber' => "ZFMK-TIS-2538109",
            'UUID' => "https://bolgermany.de/specimen/31fdbc1094de5e20f132a7fd7779855c",
            'Location' => "Sachsen-Anhalt, Germany, Bitterfeld",
            'Latitude' => "51.66",
            'Longitude' => "12.41"
        }
        @importer               = GbolClassifier
    end


    def teardown
        NcbiName.delete_all
        NcbiNode.delete_all
        NcbiRankedLineage.delete_all
        GbifTaxonomy.delete_all
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