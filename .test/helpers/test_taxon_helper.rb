# frozen_string_literal: true

require_relative '../test_helper'

class TestTaxonHelper < Test::Unit::TestCase
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


        # #<GbifTaxonomy id: 336438, taxon_id: 7254, dataset_id: "7ddf754f-d193-4cc9-b351-99906754a03b", parent_name_usage_id: "1458", accepted_name_usage_id: nil, original_name_usage_id: nil, scientific_name: "Lentulidae", scientific_name_authorship: nil, canonical_name: "Lentulidae", generic_name: "Lentulidae", specific_epithet: nil, infraspecific_epithet: nil, taxon_rank: "family", name_according_to: nil, name_published_in: "Dirsh, V.M. (1956) The phallic complex in Acridoid...", taxonomic_status: "accepted", nomenclatural_status: nil, taxon_remarks: nil, regnum: "Animalia", phylum: "Arthropoda", classis: "Insecta", ordo: "Orthoptera", familia: "Lentulidae", genus: nil, created_at: "2022-02-15 15:39:21", updated_at: "2022-02-15 15:39:21">]
        GbifTaxonomy.create!(
            taxon_id: 7254,
            dataset_id: "7ddf754f-d193-4cc9-b351-99906754a03b",
            parent_name_usage_id: "1458",
            accepted_name_usage_id: nil,
            original_name_usage_id: nil,
            scientific_name: "Lentulidae",
            scientific_name_authorship: nil,
            canonical_name: "Lentulidae",
            generic_name: "Lentulidae",
            specific_epithet: nil,
            infraspecific_epithet: nil,
            taxon_rank: "family",
            name_according_to: nil,
            name_published_in: "Dirsh, V.M. (1956) The phallic complex in Acridoid...",
            taxonomic_status: "accepted",
            nomenclatural_status: nil,
            taxon_remarks: nil,
            regnum: "Animalia",
            phylum: "Arthropoda",
            classis: "Insecta",
            ordo: "Orthoptera",
            familia: "Lentulidae",
            genus: nil
        )
    end


    def teardown
        NcbiName.delete_all
        NcbiNode.delete_all
        NcbiRankedLineage.delete_all
        GbifTaxonomy.delete_all
    end


    def test_is_extinct?
        assert_same false, TaxonHelper.is_extinct?('Diplopoda')
        assert_same false, TaxonHelper.is_extinct?('Arachnida')
        assert_same false, TaxonHelper.is_extinct?('Ostracoda')
        assert_same false, TaxonHelper.is_extinct?('Entognatha')
        assert_same false, TaxonHelper.is_extinct?('Hexanauplia')
        assert_same false, TaxonHelper.is_extinct?('Insecta')
        assert_same false, TaxonHelper.is_extinct?('Maxillopoda')
        assert_same false, TaxonHelper.is_extinct?('Chilopoda')
        assert_same false, TaxonHelper.is_extinct?('Symphyla')
        assert_same false, TaxonHelper.is_extinct?('Remipedia')
        assert_same false, TaxonHelper.is_extinct?('Pycnogonida')
        assert_same false, TaxonHelper.is_extinct?('Cephalocarida')
        assert_same false, TaxonHelper.is_extinct?('Branchiopoda')
        assert_same false, TaxonHelper.is_extinct?('Merostomata')
        assert_same false, TaxonHelper.is_extinct?('Pauropoda')
        assert_same true,  TaxonHelper.is_extinct?('Trilobita')
        assert_same true,  TaxonHelper.is_extinct?('Pliytosauria')
        assert_same true,  TaxonHelper.is_extinct?('Condylarthra')
        assert_same true,  TaxonHelper.is_extinct?('Edopsoidea')
        assert_same true,  TaxonHelper.is_extinct?('Hapalopteroidea')
        assert_same true,  TaxonHelper.is_extinct?('Hadentomoidea')
        assert_same true,  TaxonHelper.is_extinct?('Archaehymenoptera')
        assert_same true,  TaxonHelper.is_extinct?('Hemiodonata')
        assert_same true,  TaxonHelper.is_extinct?('Protoblattoidea')
        assert_same true,  TaxonHelper.is_extinct?('Protohemiptera')
    end

    def test_get_ncbi_records
        params = Hash.new { |h,k| h[k]= Hash.new }
        params[:taxonomy][:synonyms_allowed] =  true
        

        assert_nil TaxonHelper.get_ncbi_records('xxxxccccccxxxxxx', params)
        assert_equal Array, TaxonHelper.get_ncbi_records('Lentulidae', params).class
        assert_equal [@lentulidae_obj], TaxonHelper.get_ncbi_records('Lentulidae', params)


        params[:taxonomy][:synonyms_allowed] = false
        assert_nil TaxonHelper.get_ncbi_records('xxxxccccccxxxxxx', params)
        assert_equal Array, TaxonHelper.get_ncbi_records('Lentulidae', params).class
        assert_equal [@lentulidae_obj], TaxonHelper.get_ncbi_records('Lentulidae', params)
    end

    def test_choose_ncbi_record
        params = Hash.new { |h,k| h[k]= Hash.new }
        params[:taxonomy][:ncbi] =  true

        assert_nil TaxonHelper.choose_ncbi_record(taxon_name: 'xxxxccccccxxxxxx', params: params, automatic: true)
        assert_equal OpenStruct, TaxonHelper.choose_ncbi_record(taxon_name: 'Lentulidae', params: params, automatic: true).class
        assert_equal @lentulidae_obj, TaxonHelper.choose_ncbi_record(taxon_name: 'Lentulidae', params: params, automatic: true)
    end


    def test_get_taxon_record
        params = Hash.new { |h, k| h[k] = Hash.new }
        params[:taxon] = 'Lentulidae'
        params[:taxonomy][:ncbi] = true
        params[:taxonomy][:gbif] = false


        assert_equal OpenStruct, TaxonHelper.get_taxon_record(params, automatic: true).class      
        assert_equal @lentulidae_obj, TaxonHelper.get_taxon_record(params, automatic: true)          
     
        
        params[:taxon] = 'xxxxccccccxxxxxx'
        assert_equal nil, TaxonHelper.get_taxon_record(params, automatic: true)          
        
        params[:taxonomy][:ncbi] = false
        params[:taxonomy][:gbif] = true
        assert_equal nil, TaxonHelper.get_taxon_record(params, automatic: true)          

        params[:taxon] = 'Lentulidae'
        assert_equal GbifTaxonomy, TaxonHelper.get_taxon_record(params, automatic: true).class
        
        obj = GbifTaxonomy.find_by(canonical_name: 'Lentulidae')
        assert_equal obj, TaxonHelper.get_taxon_record(params, automatic: true)
        
        params[:taxonomy][:ncbi] = false
        params[:taxonomy][:gbif] = true
        params[:taxon] = 'xxxxccccccxxxxxx'
        assert_equal nil, TaxonHelper.get_taxon_record(params, automatic: true)          
        
        params[:taxon] = 'Lentulidae'
        assert_equal GbifTaxonomy, TaxonHelper.get_taxon_record(params, automatic: true).class
        assert_equal obj, TaxonHelper.get_taxon_record(params, automatic: true)
    end


    def test_assign_taxon_info_to_params
        params = Hash.new { |h, k| h[k] = Hash.new }
        params[:taxon] = 'Lentulidae'
        params[:taxonomy][:ncbi] = true
        params[:taxonomy][:gbif] = false
        obj = GbifTaxonomy.find_by(canonical_name: 'Lentulidae')

        params[:taxon_object] = nil
        params[:taxon_rank] = nil
        assert_not_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')
        
        params[:taxon_object] = @lentulidae_obj
        params[:taxon_rank] = 'family'
        assert_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')


        params[:taxonomy][:ncbi] = false
        params[:taxonomy][:gbif] = true
        params[:taxon_object] = nil
        params[:taxon_rank] = nil
        assert_not_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')
        
        
        params[:taxon_object] = obj
        params[:taxon_rank] = 'family'
        assert_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')
        
        params[:taxonomy][:ncbi] = false
        params[:taxonomy][:gbif] = true
        params[:taxon_object] = nil
        params[:taxon_rank] = nil
        assert_not_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')

        params[:taxon_object] = obj
        params[:taxon_rank] = 'family'
        assert_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')


        params[:taxonomy][:ncbi] = false
        params[:taxonomy][:gbif] = false
        params[:taxon_object] = nil
        params[:taxon_rank] = nil
        assert_not_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')

        params[:taxon_object] = @lentulidae_obj ## defaults to ncbi
        params[:taxon_rank] = 'family'
        assert_equal params, TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae')


        params[:taxonomy][:ncbi] = true
        params[:taxonomy][:gbif] = false
        params[:taxon_object] = nil
        params[:taxon_rank] = nil
        assert_raise (SystemExit) { TaxonHelper.assign_taxon_info_to_params(params.dup, 'xxxxccccxxxxx') }
        assert_nothing_raised (SystemExit) { TaxonHelper.assign_taxon_info_to_params(params.dup, 'Lentulidae') }
    end
end
