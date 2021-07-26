# frozen_string_literal: true

require_relative '../test_helper'

class TestMiscHelper < Test::Unit::TestCase
    def test_constantize
        assert_same BoldConfig,                   MiscHelper.constantize('BoldConfig')
        assert_same GbifTaxonomyConfig,           MiscHelper.constantize('GbifTaxonomyConfig')
        assert_same GbolConfig,                   MiscHelper.constantize('GbolConfig')
        assert_same NcbiGenbankConfig,            MiscHelper.constantize('NcbiGenbankConfig')
        assert_same NcbiTaxonomyConfig,           MiscHelper.constantize('NcbiTaxonomyConfig')
        assert_same Printing,                     MiscHelper.constantize('Printing')
        assert_same FtpDownloader,                MiscHelper.constantize('FtpDownloader')
        assert_same HttpDownloader,               MiscHelper.constantize('HttpDownloader')
        assert_same MiscHelper,                       MiscHelper.constantize('MiscHelper')
        assert_same BoldClassifier,                 MiscHelper.constantize('BoldClassifier')
        assert_same GbifTaxonomyImporter,         MiscHelper.constantize('GbifTaxonomyImporter')
        assert_same GbolClassifier,                 MiscHelper.constantize('GbolClassifier')
        assert_same NcbiGenbankClassifier,          MiscHelper.constantize('NcbiGenbankClassifier')
        assert_same NcbiNameImporter,             MiscHelper.constantize('NcbiNameImporter')
        assert_same NcbiNodeImporter,             MiscHelper.constantize('NcbiNodeImporter')
        assert_same NcbiRankedLineageImporter,    MiscHelper.constantize('NcbiRankedLineageImporter')
        assert_same BoldJob,                      MiscHelper.constantize('BoldJob')
        assert_same GbifTaxonomyJob,              MiscHelper.constantize('GbifTaxonomyJob')
        assert_same NcbiGenbankJob,               MiscHelper.constantize('NcbiGenbankJob')
        assert_same NcbiTaxonomyJob,              MiscHelper.constantize('NcbiTaxonomyJob')
        assert_same GbifTaxonomy,                 MiscHelper.constantize('GbifTaxonomy')
        assert_same NcbiName,                     MiscHelper.constantize('NcbiName')
        assert_same NcbiNode,                     MiscHelper.constantize('NcbiNode')
        assert_same NcbiRankedLineage,            MiscHelper.constantize('NcbiRankedLineage')
        assert_same OutputFormat::Fasta,          MiscHelper.constantize('OutputFormat::Fasta')
        assert_same OutputFormat,                 MiscHelper.constantize('OutputFormat')
        assert_same OutputFormat::Tsv,            MiscHelper.constantize('OutputFormat::Tsv')
        assert_same FileStructure,                MiscHelper.constantize('FileStructure')
        assert_same GbifApi,                      MiscHelper.constantize('GbifApi')
        assert_same Marker,                       MiscHelper.constantize('Marker')
        assert_same NcbiApi,                      MiscHelper.constantize('NcbiApi')
        assert_same NcbiDivision,                 MiscHelper.constantize('NcbiDivision')
        assert_same Nomial,                       MiscHelper.constantize('Nomial')
        assert_same Specimen,                     MiscHelper.constantize('Specimen')
        assert_same SpecimensOfTaxon,             MiscHelper.constantize('SpecimensOfTaxon')
        assert_same StringFormatting,             MiscHelper.constantize('StringFormatting')
        assert_same TaxonSearch,                  MiscHelper.constantize('TaxonSearch')
    end

    def test_generate_index_by_column_name
        tempfile = Tempfile.create('test_generate_index_by_column_name')
        tempfile.write("processid\ttsampleid\ttrecordID\ttcatalognum\ttfieldnum\ttinstitution_storing\tcollection_code\tbin_uri\tphylum_taxID\tphylum_name\tclass_taxID\tclass_name\torder_taxID\torder_name\tfamily_taxID\tfamily_name\tsubfamily_taxID\tsubfamily_name\tgenus_taxID\tgenus_name\tspecies_taxID\tspecies_name\tsubspecies_taxID\tsubspecies_name\tidentification_provided_by\tidentification_method\tidentification_reference\ttax_note\tvoucher_status\ttissue_type\tcollection_event_id\tcollectors\tcollectiondate_start\tcollectiondate_end\tcollectiontime\tcollection_note\tsite_code\tsampling_protocol\tlifestage\tsex\treproduction\thabitat\tassociated_specimens\tassociated_taxa\textrainfo\tnotes\tlat\tlon\tcoord_source\tcoord_accuracy\telev\tdepth\telev_accuracy\tdepth_accuracy\tcountry\tprovince_state\tregion\tsector\texactsite\timage_ids\timage_urls\tmedia_descriptors\tcaptions\tcopyright_holders\tcopyright_years\tcopyright_licenses\tcopyright_institutions\tphotographers\tsequenceID\tmarkercode\tgenbank_accession\tnucleotides\ttrace_ids\ttrace_names\ttrace_links\trun_dates\tsequencing_centers\tdirections\tseq_primers\tmarker_codes")
        tempfile.write("\nAGMPK217-18\tBIOUG37024-D07\t8562520\tBIOUG37024-D07\tL#17AGAS4-02N\tCentre for Biodiversity Genomics\t\tBOLD:ACM9724\t20\tArthropoda\t82\tInsecta\t125\tHymenoptera\t106636\tPlatygastridae\t\t\t\t\t\t\t\t\tKate Perez\tBIN Taxonomy Match (Mar 2018)\t\t\tVouchered:Registered Collection\tinv whole voucher\t\tCBG Collections\t\t\t\t4-headed SLAM trap (N)\t\tMalaise Trap\tA\t\t\tAgricultural\t\t\tAS4\t\t43.5264\t-80.1796\tGPS\t\t329\t\t\t\tCanada\tOntario\tWellington Co.\tGuelph, Arkell Research Station\tSoy field, trap 4\t\t\t\t\t\t\t\t\t\t9858437\tCOI-5P\t\tAACTCTTTATTTCTTATTTGGAATTTGATCTGGTATAATTGGAAGAAGACTCAGTATAATTATTCGTATAGAAGTAGGAATAAGAGGAACTTTAATTGGTAATGATCAAATTTATAATTCTATTGTTACAGCTCATGCATTTATTATAATTTTTTTTATAATTATACCCCTAATATTAGGAGGATTTGGAAATTGACTAATTCCTTTAATATTATCTGCTCCAGATATAGCATTCCCCCGTATAAATAATATAAGATTTTGGCTATTACCCCCATCCCTAATACTATTAATTTATAGAAATATTTTTGGTATAGGGACTGGTACTGGATGAACATTATATCCTCCTTTATCTTTATTAACTAATCCCTCTATTGACATAAGAATCTTTTCTCTCCATTTAGCTGGTATTTCATCAATTTTAGGATCAATTAATTTTATCTGTACTATTATCAATATAACTCCCATAAATATAAAAATAGAAAAAATATCTTTATTTTCATGATCAATTTTTATTACAACAATTCTTCTTCTACTTTCCTTACCTGTATTAGCAGGGGCTATTACTATACTATTAACAGACCGAAACTTAAATACTTCTTTTTTTGATCCTTCAGGAGGAGGAGACCCTGTTCTTTATCAACACTTATTC\t\t\t\t\t\t\t\t")
        tempfile.rewind

        index_by_column_name = MiscHelper.generate_index_by_column_name(file: tempfile, separator: "\t")
        
        specimen_data = []
        tempfile.each do |row|
              specimen_data = row.scrub!.chomp.split("\t")
        end

        nucs  = 'AACTCTTTATTTCTTATTTGGAATTTGATCTGGTATAATTGGAAGAAGACTCAGTATAATTATTCGTATAGAAGTAGGAATAAGAGGAACTTTAATTGGTAATGATCAAATTTATAATTCTATTGTTACAGCTCATGCATTTATTATAATTTTTTTTATAATTATACCCCTAATATTAGGAGGATTTGGAAATTGACTAATTCCTTTAATATTATCTGCTCCAGATATAGCATTCCCCCGTATAAATAATATAAGATTTTGGCTATTACCCCCATCCCTAATACTATTAATTTATAGAAATATTTTTGGTATAGGGACTGGTACTGGATGAACATTATATCCTCCTTTATCTTTATTAACTAATCCCTCTATTGACATAAGAATCTTTTCTCTCCATTTAGCTGGTATTTCATCAATTTTAGGATCAATTAATTTTATCTGTACTATTATCAATATAACTCCCATAAATATAAAAATAGAAAAAATATCTTTATTTTCATGATCAATTTTTATTACAACAATTCTTCTTCTACTTTCCTTACCTGTATTAGCAGGGGCTATTACTATACTATTAACAGACCGAAACTTAAATACTTCTTTTTTTGATCCTTCAGGAGGAGGAGACCCTGTTCTTTATCAACACTTATTC'
        id    = 'AGMPK217-18'
        lat   = '43.5264'
        lon  = '-80.1796'

        assert_equal id, specimen_data[index_by_column_name['processid']]
        assert_equal nucs, specimen_data[index_by_column_name['nucleotides']]
        assert_equal lat, specimen_data[index_by_column_name['lat']]
        assert_equal lon, specimen_data[index_by_column_name['lon']]
  end

    def test_extract_zip
        tmp_dir     = Dir.mktmpdir
        destination = File.join(tmp_dir, 'out')
        test_name   = 'test_extract_zip'

        data = [0, 1, 2, 3, 4]
    
        zip_path = File.join(tmp_dir, "#{test_name}.zip")
    
        Zip::OutputStream.open(zip_path) do |io|
            data.each do |d|
                    io.put_next_entry("#{test_name}#{d}.txt")
                    io.write "#{test_name}#{d}"
            end
        end

        MiscHelper.extract_zip(name: zip_path, destination: destination, files_to_extract: ['test_extract_zip0.txt', 'test_extract_zip1.txt'])

        assert_path_exist destination

        destination = Pathname.new(destination)
        files = destination.glob('*').select { |entry| entry.file? }
        
        assert_equal 2, files.size

        files.sort.each_with_index do |file, index|
            assert_path_exist file
            assert_equal "#{test_name}#{index}", File.open(file).read
        end
    end

    def test_normalize
        assert_equal 'A', MiscHelper.normalize('Â')
        assert_equal 'A', MiscHelper.normalize('A')
    end

    def test_create_marker_objects
        assert_kind_of Array, MiscHelper.create_marker_objects(query_marker_names: 'co1')
        assert_kind_of Array, MiscHelper.create_marker_objects(query_marker_names: nil)
        assert_kind_of Array, MiscHelper.create_marker_objects(query_marker_names: 'co1,cox1')
        assert_raise (SystemExit) { MiscHelper.create_marker_objects(query_marker_names: 'co1, cox1') }
        assert_raise (SystemExit) { MiscHelper.create_marker_objects(query_marker_names: 'whatever') }
    end
end