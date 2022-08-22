# frozen_string_literal: true

require_relative '../test_helper'

class TestNomial < Test::Unit::TestCase

    def setup
        params = Hash.new { |h,k| h[k]= Hash.new }
        params[:taxonomy][:ncbi] =  true

        
        #<NcbiName id: 19762, tax_id: 6656, name: "Arthropoda", unique_name: "", name_class: "scientific name", created_at: "2022-02-15 18:32:14", updated_at: "2022-02-15 18:32:14">
        NcbiName.create!(
            tax_id: 6656,
            name: 'Arthropoda',
            unique_name: '', 
            name_class: 'scientific name'
        )


        #<NcbiRankedLineage id: 867858, tax_id: 6656, name: "Arthropoda", species: "", genus: "", familia: "", ordo: "", classis: "", phylum: "", regnum: "Metazoa", super_regnum: "Eukaryota", created_at: "2022-02-15 18:54:32", updated_at: "2022-02-15 18:54:32">
        NcbiRankedLineage.create!(
            tax_id: 6656,
            name: "Arthropoda",
            species: "",
            genus: "",
            familia: "",
            ordo: "",
            classis: "",
            phylum: "",
            regnum: "Metazoa",
            super_regnum: "Eukaryota"
        )


        #<NcbiNode id: 5355, tax_id: 6656, parent_tax_id: 88770, rank: "phylum", division_id: 1, genetic_code_id: 1, mito_genetic_code_id: 5, has_specified_species: false, plastid_genetic_code_id: 0, created_at: "2022-02-15 19:02:08", updated_at: "2022-02-15 19:02:08">
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


                # #<NcbiName id: 105810, tax_id: 62781, name: "Lentulidae", unique_name: "", name_class: "scientific name", created_at: "2022-02-15 18:32:25", updated_at: "2022-02-15 18:32:25">
        NcbiName.create!(
            tax_id: 62781,
            name: 'Lentulidae',
            unique_name: '', 
            name_class: 'scientific name'
        )


        # #<NcbiRankedLineage id: 1742226, tax_id: 62781, name: "Lentulidae", species: "", genus: "", familia: "", ordo: "Orthoptera", classis: "Insecta", phylum: "Arthropoda", regnum: "Metazoa", super_regnum: "Eukaryota", created_at: "2022-02-15 18:58:15", updated_at: "2022-02-15 18:58:15">
        NcbiRankedLineage.create!(
            tax_id: 62781,
            name: "Lentulidae",
            species: "",
            genus: "",
            familia: "",
            ordo: "Orthoptera",
            classis: "Insecta",
            phylum: "Arthropoda",
            regnum: "Metazoa",
            super_regnum: "Eukaryota"
        )


        # #<NcbiNode id: 40907, tax_id: 62781, parent_tax_id: 92621, rank: "family", division_id: 1, genetic_code_id: 1, mito_genetic_code_id: 5, has_specified_species: false, plastid_genetic_code_id: 0, created_at: "2022-02-15 19:02:08", updated_at: "2022-02-15 19:02:08">
        NcbiNode.create!(
            tax_id: 62781,
            parent_tax_id: 92621,
            rank: "family",
            division_id: 1,
            genetic_code_id: 1,
            mito_genetic_code_id: 5,
            has_specified_species: false,
            plastid_genetic_code_id: 0
        )


        @query_taxon            = 'Arthropoda'
        @query_taxon_rank       = 'phylum'
        @query_taxon_object     = TaxonHelper.choose_ncbi_record(taxon_name: @query_taxon, params: params, automatic: true)
        @taxonomy_params        = { ncbi: true }

        
        headers     = ["HigherTaxa", "Species", "BarcodeSequence", "Institute", "CatalogueNumber", "UUID", "Location", "Latitude", "Longitude"]
        fields      = ["Animalia, Arthropoda, Arachnida, Araneae, Linyphiidae", "Abacoproeces saltuum", "TACTTTGTATTTTGTTTTTGGGGCTTGGGCTGCTATAGTAGGGACAGCAATAAGAGTTTTAATTCGGGTTGAGTTAGGTCAGACTGGTAGATTGTTGGGAGATGACCAACTATATAATGTAATTGTTACTGCTCACGCATTTGTTATAATTTTTTTTATGGTTATACCTATTTTAATTGGGGGGTTTGGAAATTGATTGGTCCCTTTGATATTAGGAGCGCCTGATATGGCTTTTCCACGTATGAATAATTTAAGCTTTTGACTATTGCCCCCATCTTTATTGTTATTATCTATTTCTAGTGTGGATGAGATAGGGGTTGGTGCGGGGTGGACTATTTATCCCCCCCTTGCTTCTTTAGAGGGTCATTCTGGGAGATCAGTAGATTTTGCTATTTTTTCTTTGCATCTAGCTGGGGCATCTTCTATTATAGGGGCAATTAATTTTATTTCTACTATTTTTAATATGCGGGGGTGTGGAATAACCTTGGAAAAAACTCCACTATTTGTTTGGTCTGTCTTAATTACTGCTATTTTATTATTGTTATCTCTTCCCGTGTTAGCAGGAGCTATTACAATGCTGTTAACAGATCGAAATTTTAATACGTCATTTTTTGATCCTAGTGGGGGGGGGGATCCTGTTTTGTTTCAGCACCTATTT", "ZFMK", "ZFMK-TIS-2538109", "https://bolgermany.de/specimen/31fdbc1094de5e20f132a7fd7779855c", "Sachsen-Anhalt, Germany, Bitterfeld", "51.66", "12.41"]
        fields2     = ["Animalia, Arthropoda, Insecta, Orthoptera, Lentulidae", "Lentulidae", "TACTTTGTATTTTGTTTTTGGGGCTTGGGCTGCTATAGTAGGGACAGCAATAAGAGTTTTAATTCGGGTTGAGTTAGGTCAGACTGGTAGATTGTTGGGAGATGACCAACTATATAATGTAATTGTTACTGCTCACGCATTTGTTATAATTTTTTTTATGGTTATACCTATTTTAATTGGGGGGTTTGGAAATTGATTGGTCCCTTTGATATTAGGAGCGCCTGATATGGCTTTTCCACGTATGAATAATTTAAGCTTTTGACTATTGCCCCCATCTTTATTGTTATTATCTATTTCTAGTGTGGATGAGATAGGGGTTGGTGCGGGGTGGACTATTTATCCCCCCCTTGCTTCTTTAGAGGGTCATTCTGGGAGATCAGTAGATTTTGCTATTTTTTCTTTGCATCTAGCTGGGGCATCTTCTATTATAGGGGCAATTAATTTTATTTCTACTATTTTTAATATGCGGGGGTGTGGAATAACCTTGGAAAAAACTCCACTATTTGTTTGGTCTGTCTTAATTACTGCTATTTTATTATTGTTATCTCTTCCCGTGTTAGCAGGAGCTATTACAATGCTGTTAACAGATCGAAATTTTAATACGTCATTTTTTGATCCTAGTGGGGGGGGGGATCCTGTTTTGTTTCAGCACCTATTT", "ZFMK", "ZFMK-TIS-2538109", "https://bolgermany.de/specimen/31fdbc1094de5e20f132a7fd7779855c", "Sachsen-Anhalt, Germany, Bitterfeld", "51.66", "12.41"]
        fields3     = ["Animalia, Arthropoda, Insecta, Orthoptera", "Lentulidae", "TACTTTGTATTTTGTTTTTGGGGCTTGGGCTGCTATAGTAGGGACAGCAATAAGAGTTTTAATTCGGGTTGAGTTAGGTCAGACTGGTAGATTGTTGGGAGATGACCAACTATATAATGTAATTGTTACTGCTCACGCATTTGTTATAATTTTTTTTATGGTTATACCTATTTTAATTGGGGGGTTTGGAAATTGATTGGTCCCTTTGATATTAGGAGCGCCTGATATGGCTTTTCCACGTATGAATAATTTAAGCTTTTGACTATTGCCCCCATCTTTATTGTTATTATCTATTTCTAGTGTGGATGAGATAGGGGTTGGTGCGGGGTGGACTATTTATCCCCCCCTTGCTTCTTTAGAGGGTCATTCTGGGAGATCAGTAGATTTTGCTATTTTTTCTTTGCATCTAGCTGGGGCATCTTCTATTATAGGGGCAATTAATTTTATTTCTACTATTTTTAATATGCGGGGGTGTGGAATAACCTTGGAAAAAACTCCACTATTTGTTTGGTCTGTCTTAATTACTGCTATTTTATTATTGTTATCTCTTCCCGTGTTAGCAGGAGCTATTACAATGCTGTTAACAGATCGAAATTTTAATACGTCATTTTTTGATCCTAGTGGGGGGGGGGATCCTGTTTTGTTTCAGCACCTATTT", "ZFMK", "ZFMK-TIS-2538109", "https://bolgermany.de/specimen/31fdbc1094de5e20f132a7fd7779855c", "Sachsen-Anhalt, Germany, Bitterfeld", "51.66", "12.41"]
        @first_specimen_info = CSV::Row.new(headers, fields, header_row = false)
        @first_specimen_info2 = CSV::Row.new(headers, fields2, header_row = false)
        @first_specimen_info3 = CSV::Row.new(headers, fields3, header_row = false)
        # @first_specimen_info    = "Animalia, Arthropoda, Arachnida, Araneae, Linyphiidae\tAbacoproeces saltuum\tTACTTTGTATTTTGTTTTTGGGGCTTGGGCTGCTATAGTAGGGACAGCAATAAGAGTTTTAATTCGGGTTGAGTTAGGTCAGACTGGTAGATTGTTGGGAGATGACCAACTATATAATGTAATTGTTACTGCTCACGCATTTGTTATAATTTTTTTTATGGTTATACCTATTTTAATTGGGGGGTTTGGAAATTGATTGGTCCCTTTGATATTAGGAGCGCCTGATATGGCTTTTCCACGTATGAATAATTTAAGCTTTTGACTATTGCCCCCATCTTTATTGTTATTATCTATTTCTAGTGTGGATGAGATAGGGGTTGGTGCGGGGTGGACTATTTATCCCCCCCTTGCTTCTTTAGAGGGTCATTCTGGGAGATCAGTAGATTTTGCTATTTTTTCTTTGCATCTAGCTGGGGCATCTTCTATTATAGGGGCAATTAATTTTATTTCTACTATTTTTAATATGCGGGGGTGTGGAATAACCTTGGAAAAAACTCCACTATTTGTTTGGTCTGTCTTAATTACTGCTATTTTATTATTGTTATCTCTTCCCGTGTTAGCAGGAGCTATTACAATGCTGTTAACAGATCGAAATTTTAATACGTCATTTTTTGATCCTAGTGGGGGGGGGGATCCTGTTTTGTTTCAGCACCTATTT\tZFMK\tZFMK-TIS-2538109\thttps://bolgermany.de/specimen/31fdbc1094de5e20f132a7fd7779855c\tSachsen-Anhalt, Germany, Bitterfeld\t51.66\t12.41"
        # @first_specimen_info2    = "Animalia, Arthropoda, Insecta, Ortoptera, Lentulidae\tLentulidae\tTACTTTGTATTTTGTTTTTGGGGCTTGGGCTGCTATAGTAGGGACAGCAATAAGAGTTTTAATTCGGGTTGAGTTAGGTCAGACTGGTAGATTGTTGGGAGATGACCAACTATATAATGTAATTGTTACTGCTCACGCATTTGTTATAATTTTTTTTATGGTTATACCTATTTTAATTGGGGGGTTTGGAAATTGATTGGTCCCTTTGATATTAGGAGCGCCTGATATGGCTTTTCCACGTATGAATAATTTAAGCTTTTGACTATTGCCCCCATCTTTATTGTTATTATCTATTTCTAGTGTGGATGAGATAGGGGTTGGTGCGGGGTGGACTATTTATCCCCCCCTTGCTTCTTTAGAGGGTCATTCTGGGAGATCAGTAGATTTTGCTATTTTTTCTTTGCATCTAGCTGGGGCATCTTCTATTATAGGGGCAATTAATTTTATTTCTACTATTTTTAATATGCGGGGGTGTGGAATAACCTTGGAAAAAACTCCACTATTTGTTTGGTCTGTCTTAATTACTGCTATTTTATTATTGTTATCTCTTCCCGTGTTAGCAGGAGCTATTACAATGCTGTTAACAGATCGAAATTTTAATACGTCATTTTTTGATCCTAGTGGGGGGGGGGATCCTGTTTTGTTTCAGCACCTATTT\tZFMK\tZFMK-TIS-2538109\thttps://bolgermany.de/specimen/31fdbc1094de5e20f132a7fd7779855c\tSachsen-Anhalt, Germany, Bitterfeld\t51.66\t12.41"
        @importer = GbolClassifier
        @ncbi_lentulidae_obj = OpenStruct.new(
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
            combined: ["Metazoa", "Arthropoda", "Insecta", "Orthoptera", "Lentulidae"],
            comment: ''
        )
    end


    def teardown
        NcbiName.delete_all
        NcbiNode.delete_all
        NcbiRankedLineage.delete_all
        GbifTaxonomy.delete_all
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

        assert_kind_of Nomial, Nomial.generate(name: nomial1, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Nomial, Nomial.generate(name: nomial2, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Nomial, Nomial.generate(name: nomial3, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Nomial, Nomial.generate(name: nomial4, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Nomial, Nomial.generate(name: nomial5, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Nomial, Nomial.generate(name: nomial6, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)

        assert_kind_of Monomial, Nomial.generate(name: monomial1, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Monomial, Nomial.generate(name: monomial2, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Monomial, Nomial.generate(name: monomial3, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Monomial, Nomial.generate(name: monomial4, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Monomial, Nomial.generate(name: monomial5, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Monomial, Nomial.generate(name: monomial6, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Monomial, Nomial.generate(name: monomial7, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)

        assert_kind_of Polynomial, Nomial.generate(name: poylnomial1, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Polynomial, Nomial.generate(name: poylnomial2, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Polynomial, Nomial.generate(name: poylnomial3, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Polynomial, Nomial.generate(name: poylnomial4, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Polynomial, Nomial.generate(name: poylnomial5, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
        assert_kind_of Polynomial, Nomial.generate(name: poylnomial6, query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params)
    end

    def test_taxonomy
        assert_nil Nomial.generate(name: '123', query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).taxonomy(first_specimen_info: @first_specimen_info, importer: @importer)
        assert_equal @ncbi_lentulidae_obj, Nomial.generate(name: 'Lentulidae', query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).taxonomy(first_specimen_info: @first_specimen_info2, importer: @importer)
        assert_equal @ncbi_lentulidae_obj, Nomial.generate(name: 'xcccxxx', query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).taxonomy(first_specimen_info: @first_specimen_info2, importer: @importer)
        assert_equal @ncbi_lentulidae_obj, Nomial.generate(name: 'xcccxxx', query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).taxonomy(first_specimen_info: @first_specimen_info3, importer: @importer)
    end

    def test_name_cleaning
        assert_equal 'Bombus terrestris',               Nomial.generate(name: 'Bombus terrestris aff. terrestris', query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).name
        assert_equal 'Bombus',                          Nomial.generate(name: 'Bombus terrestris2 aff. terrestris', query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).name
        assert_equal 'Bombus',                          Nomial.generate(name: 'Bombus terrestris@ aff. terrestris', query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).name
        assert_equal 'Bombus terrestris',               Nomial.generate(name: 'Bombus terrestris aff. cf. terrestris', query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).name
        assert_equal 'Bombus terrestris terrestris',    Nomial.generate(name: 'Bombus terrestris terrestris', query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).name
        assert_equal 'Bombus',                          Nomial.generate(name: 'Bombus sp', query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).name
        # assert_equal 'Bombus',                          Nomial.generate(name: 'Bombus| sp', query_taxon_rank: @query_taxon_rank, query_taxon_object: @query_taxon_object, taxonomy_params: @taxonomy_params).name
    end
end