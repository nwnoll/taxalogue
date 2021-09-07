# frozen_string_literal: true

require_relative '../test_helper'

class TestDerepHelper < Test::Unit::TestCase

    def setup
        reset

        @specimens = 
        [
            {:identifier=>"ZFMK-TIS-1803395", :sequence=>"AACTTTATATTTTTTATTTGGAGCATGAGCTGGAATAGTAGGTACATCAATAAGAATAATTATTCGTGCAGAACTTGGACAACCAGGATCCATAATTGGAGATGATCAAATCTATAATGTTATTATTACAGCACATGCATTTGTAATAATTTTCTTCATAGTAATACCTATTATAATTGGGGGATTCGGTAATTGACTGGTTCCACTAATAATCGGAGCACCAGATATAGCTTTTCCACGAATAAATAACATAAGTTTTTGACTTTTACCACCATCATTAACTCTTTTAATTGCATCATCAATAATAGATAATGGTGCAGGAACAGGATGAACAGTTTATCCCCCTCTCGCAGGAGCAATTGCACATGGAGGAGGATCAGTAGACCTGGCGATTTTTTCATTACATTTAGCAGGTGTTTCATCAATTTTAGGAGCAGTTAATTTCATTACAACTGNAATCAATATACGGTCGGAAAGAATAACACTAGATCAAACACCACTATTTGTCTGATCAGTAGCAATTACAGCACTCCTATTACTATTATCATTACCGGTACTAGCAGGAGCAATTACTATATTATTAACTGATCGAAATTTAAATACTTCGTTCTTTGACCCTGCAG", :location=>"Germany, Kreis Ahrweiler, Rheinland-Pfalz", :latitude=>"50.5", :longitude=>"7.21"},
            {:identifier=>"GBOL08155", :sequence=>"TATTTTATATTTGGAGCATGAGCCGGAATAGTAGGAACATCAATAAGAATAATTATTCGTGCAGAACTTGGACAACCAGGATCTATAATTGGAGATGATCAAATTTATAATGTTATTATTACAGCACATGCATTTGTAATAATTTTCCTCATAGTAATACCTATTATAATTGGAGGATTTGGTAATTGACTAGTTCCATTAATAATTGGGGCACCAGATATAGCCTTTCCACGAATAAATAACATAAGTTTTTGGTTTTTACCACCATCATTAACTCTTTTAATTGCATCATCAATAGTAGATAGTGGTGCAGGAACAGGATGAACAGTTTACCCTCCTCTTGCAGGAGCAATCGCTCATGGAGGAGGGTCAGTAGACCTAGCTATTTTTTCATTACATTTAGCCGGTATTTCATCAATTTTAGGAGCAGTAAATTTCATTACAACTGCAATCAACATTCGATCGGAAAGAATAACACTGGTCAAACACCACTATTTGTTTGATCAGTA", :location=>"Bayern, Germany", :latitude=>"48.26", :longitude=>"10.96"},
            {:identifier=>"DUMMY123", :sequence=>"TATTTTATATTTGGAGCATGAGCCGGAATAGTAGGAACATCAATAAGAATAATTATTCGTGCAGAACTTGGACAACCAGGATCTATAATTGGAGATGATCAAATTTATAATGTTATTATTACAGCACATGCATTTGTAATAATTTTCCTCATAGTAATACCTATTATAATTGGAGGATTTGGTAATTGACTAGTTCCATTAATAATTGGGGCACCAGATATAGCCTTTCCACGAATAAATAACATAAGTTTTTGGTTTTTACCACCATCATTAACTCTTTTAATTGCATCATCAATAGTAGATAGTGGTGCAGGAACAGGATGAACAGTTTACCCTCCTCTTGCAGGAGCAATCGCTCATGGAGGAGGGTCAGTAGACCTAGCTATTTTTTCATTACATTTAGCCGGTATTTCATCAATTTTAGGAGCAGTAAATTTCATTACAACTGCAATCAACATTCGATCGGAAAGAATAACACTGGTCAAACACCACTATTTGTTTGATCAGTA", :location=>"Bayern, Germany", :latitude=>"48.26", :longitude=>"10.96"}
        ]

        @gbif_taxonomic_info = GbifTaxonomy.create(taxon_id: 9394, dataset_id: "7ddf754f-d193-4cc9-b351-99906754a03b", parent_name_usage_id: "1458", accepted_name_usage_id: nil, original_name_usage_id: nil, scientific_name: "Acrididae", scientific_name_authorship: nil, canonical_name: "Acrididae", generic_name: "Acrididae", specific_epithet: nil, infraspecific_epithet: nil, taxon_rank: "family", name_according_to: nil, name_published_in: "MacLeay. 1821. Horae Entomologicae or Essays on th...", taxonomic_status: "accepted", nomenclatural_status: nil, taxon_remarks: nil, regnum: "Animalia", phylum: "Arthropoda", classis: "Insecta", ordo: "Orthoptera", familia: "Acrididae", genus: nil)
        @ncbi_taxonomic_info = OpenStruct.new(
            taxon_id: 7002,
            regnum: "Metazoa",
            phylum: "Arthropoda",
            classis: "Insecta",
            ordo: "Orthoptera",
            familia: "Acrididae",
            genus: "",
            canonical_name: "Acrididae",
            scientific_name: "Acrididae",
            taxonomic_status: "accepted",
            taxon_rank: "family",
            combined: ["Metazoa", "Arthropoda", "Insecta", "Orthoptera", "Acrididae"],
            comment: ""
        )
        
        @taxon_name = 'Acrididae'
        @first_specimen_info = CSV::Row.new(
            ["HigherTaxa", "Species", "BarcodeSequence", "Institute", "CatalogueNumber", "UUID", "Location", "Latitude", "Longitude"],
            ["Animalia, Arthropoda, Hexapoda, Insecta, Orthoptera, Acrididae", "Acrididae", "AACTTTATATTTTTTATTTGGAGCATGAGCTGGAATAGTAGGTACATCAATAAGAATAATTATTCGTGCAGAACTTGGACAACCAGGATCCATAATTGGAGATGATCAAATCTATAATGTTATTATTACAGCACATGCATTTGTAATAATTTTCTTCATAGTAATACCTATTATAATTGGGGGATTCGGTAATTGACTGGTTCCACTAATAATCGGAGCACCAGATATAGCTTTTCCACGAATAAATAACATAAGTTTTTGACTTTTACCACCATCATTAACTCTTTTAATTGCATCATCAATAATAGATAATGGTGCAGGAACAGGATGAACAGTTTATCCCCCTCTCGCAGGAGCAATTGCACATGGAGGAGGATCAGTAGACCTGGCGATTTTTTCATTACATTTAGCAGGTGTTTCATCAATTTTAGGAGCAGTTAATTTCATTACAACTGNAATCAATATACGGTCGGAAAGAATAACACTAGATCAAACACCACTATTTGTCTGATCAGTAGCAATTACAGCACTCCTATTACTATTATCATTACCGGTACTAGCAGGAGCAATTACTATATTATTAACTGATCGAAATTTAAATACTTCGTTCTTTGACCCTGCAG", "ZFMK", "ZFMK-TIS-1803395", "https://bolgermany.de/specimen/9e3a828923eb619eabce0016cd7dd17e", "Germany, Kreis Ahrweiler, Rheinland-Pfalz", "50.5", "7.21"] 
        )

        dummy_specimen = @specimens.detect { |specimen| specimen[:identifier] == 'DUMMY123' }

    end

    def teardown
        reset
    end

    def test_fill_specimens_of_sequence
        specimens_of_sequence = Hash.new
        assert_true specimens_of_sequence.size == 0
        

        dummy_specimen = @specimens.detect { |specimen| specimen[:identifier] == 'DUMMY123' }
        DerepHelper.fill_specimens_of_sequence(specimens: @specimens, specimens_of_sequence: specimens_of_sequence, taxonomic_info: @gbif_taxonomic_info, taxon_name: @taxon_name, first_specimen_info: @first_specimen_info)
        
        assert_true specimens_of_sequence.size == 2
        assert_instance_of(Hash, specimens_of_sequence[dummy_specimen[:sequence]])
        assert_instance_of(OpenStruct, specimens_of_sequence[dummy_specimen[:sequence]][@taxon_name])
    end

    def test_dereplicate
        specimens_of_sequence = Hash.new
        taxonomy_params_gbif_backbone = Hash.new(ncbi: false, gbif: false, gbif_backbone: true)
        taxonomy_params_gbif = Hash.new(ncbi: false, gbif: true, gbif_backbone: false)
        taxonomy_params_ncbi = Hash.new(ncbi: true, gbif: false, gbif_backbone: false)
        
        DerepHelper.fill_specimens_of_sequence(specimens: @specimens, specimens_of_sequence: specimens_of_sequence, taxonomic_info: @gbif_taxonomic_info, taxon_name: @taxon_name, first_specimen_info: @first_specimen_info)
        DerepHelper.dereplicate(specimens_of_sequence, taxonomy_params_gbif_backbone, @taxon_name)
        assert_true SequenceTaxonObjectProxy.all.size == 2
        assert_true Sequence.all.size == 2
        assert_true TaxonObjectProxy.all.size == 1
        assert_true $seq_ids.size == 2
        reset

        DerepHelper.fill_specimens_of_sequence(specimens: @specimens, specimens_of_sequence: specimens_of_sequence, taxonomic_info: @gbif_taxonomic_info, taxon_name: @taxon_name, first_specimen_info: @first_specimen_info)
        DerepHelper.dereplicate(specimens_of_sequence, taxonomy_params_gbif, @taxon_name)
        assert_true SequenceTaxonObjectProxy.all.size == 2
        assert_true Sequence.all.size == 2
        assert_true TaxonObjectProxy.all.size == 1
        assert_true $seq_ids.size == 2
        reset

        DerepHelper.fill_specimens_of_sequence(specimens: @specimens, specimens_of_sequence: specimens_of_sequence, taxonomic_info: @gbif_taxonomic_info, taxon_name: @taxon_name, first_specimen_info: @first_specimen_info)
        DerepHelper.dereplicate(specimens_of_sequence, taxonomy_params_ncbi, @taxon_name)
        assert_true SequenceTaxonObjectProxy.all.size == 2
        assert_true Sequence.all.size == 2
        assert_true TaxonObjectProxy.all.size == 1
        assert_true $seq_ids.size == 2
    end

    def reset
        SequenceTaxonObjectProxy.delete_all
        TaxonObjectProxy.delete_all
        Sequence.delete_all
        $seq_ids = []
    end
end