# frozen_string_literal: true

class GbolClassifier
    include StringFormatting
    include GeoUtils
    attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :fast_run, :query_taxon_name, :file_manager, :filter_params, :taxonomy_params, :region_params

    def self.get_source_lineage(row)
        OpenStruct.new(
            name:     row["Species"],
            combined: row['HigherTaxa'].split(', ').push(row["Species"])
        )
    end

    def initialize(file_name:, query_taxon_object:, fast_run: false, file_manager:, filter_params: nil, taxonomy_params:, region_params: nil)
        @file_name                = file_name
        @query_taxon_object       = query_taxon_object
        @query_taxon_name         = query_taxon_object.canonical_name
        @query_taxon_rank         = query_taxon_object.taxon_rank
        @fast_run                 = fast_run
        @file_manager             = file_manager
        @filter_params            = filter_params
        @taxonomy_params          = taxonomy_params
        @region_params            = region_params
    end

    def run
        specimens_of_taxon  = Hash.new { |hash, key| hash[key] = {} }

        begin
            MiscHelper.extract_zip(name: file_name, destination: file_name.dirname, files_to_extract: [file_name.basename.sub_ext('.csv').to_s, 'metadata.xml'])
        rescue Zip::Error => e
            pp e
            return file_name
        end 
    
        csv_file_name = file_name.sub_ext('.csv')
        csv_file = File.open(csv_file_name, 'r')
        csv_object = CSV.new(csv_file, headers: true, col_sep: "\t", liberal_parsing: true)


        csv_object.each do |row|
            _matches_query_taxon(row) ? nil : next if fast_run

            specimen = _get_specimen(row: row)
            next if specimen.nil? || specimen.sequence.nil? || specimen.sequence.empty?
            
            next unless specimen_is_from_area(specimen: specimen, region_params: region_params) if region_params.any?

            SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
        end

        tsv             = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_gbol_fast_#{fast_run}_output.tsv", OutputFormat::Tsv)
        fasta           = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_gbol_fast_#{fast_run}_output.fas", OutputFormat::Fasta)
        comparison_file = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_gbol_fast_#{fast_run}_comparison.tsv",   OutputFormat::Comparison)
    
        specimens_of_taxon.keys.each do |taxon_name|
            nomial              = specimens_of_taxon[taxon_name][:nomial]
            next unless nomial

            first_specimen_info = specimens_of_taxon[taxon_name][:first_specimen_info]
            taxonomic_info      = nomial.taxonomy(first_specimen_info: first_specimen_info, importer: self.class)
            
            next unless taxonomic_info
            next unless taxonomic_info.public_send(TaxonomyHelper.latinize_rank(query_taxon_rank)) == query_taxon_name

            syn = Synonym.new(accepted_taxon: taxonomic_info, sources: [TaxonomyHelper.get_source_db(taxonomy_params)])
            OutputFormat::Comparison.write_to_file(file: comparison_file, nomial: nomial, accepted_taxon: taxonomic_info, synonyms_of_taxonomy: syn.synonyms_of_taxonomy, used_taxonomy: TaxonomyHelper.get_source_db(taxonomy_params))

        # OutputFormat::Synonyms.write_to_file(file: synonyms_file, accepted_taxon: syn.accepted_taxon, synonyms_of_taxonomy: syn.synonyms_of_taxonomy)

            specimens_of_taxon[taxon_name][:data].each do |data|
                OutputFormat::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
                OutputFormat::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
            end

        end
        OutputFormat::Tsv.rewind

        tsv.close
        fasta.close
        comparison_file.close

        return nil
    end
  
    private
    def _get_specimen(row:)
        identifier                    = row["CatalogueNumber"]
        source_taxon_name             = row["Species"]
        sequence                      = row['BarcodeSequence']
        location                      = row["Location"]
        lat                           = row["Latitude"]
        long                          = row["Longitude"]
        sequence                      = FilterHelper.filter_seq(sequence, filter_params)

        return nil if sequence.nil?

        nomial                        = Nomial.generate(name: source_taxon_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank, taxonomy_params: taxonomy_params)

        specimen                      = Specimen.new
        specimen.identifier           = identifier
        specimen.sequence             = sequence
        specimen.source_taxon_name    = source_taxon_name
        specimen.taxon_name           = nomial.name
        specimen.nomial               = nomial
        specimen.location             = location
        specimen.lat                  = lat
        specimen.long                 = long
        specimen.first_specimen_info  = row
        
        return specimen
    end

    def _matches_query_taxon(row)
        /#{query_taxon_name}/.match?(row["HigherTaxa"]) || /#{query_taxon_name}/.match?(row["Species"])
    end
end
