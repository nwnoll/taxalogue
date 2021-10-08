# frozen_string_literal: true

class BoldClassifier
    include StringFormatting
    attr_reader :file_name, :params, :query_taxon_object, :query_taxon_rank, :fast_run, :query_taxon_name, :file_manager, :filter_params, :markers, :regexes_for_markers, :taxonomy_params, :region_params

    @@index_by_column_name = nil
    def initialize(file_name:, params:, file_manager:)
        @file_name            = file_name
        @params               = params
        @query_taxon_object   = params[:taxon_object]
        @query_taxon_name     = query_taxon_object.canonical_name
        @query_taxon_rank     = query_taxon_object.taxon_rank
        @fast_run             = params[:fast_run]
        @markers              = params[:marker_objects]
        @regexes_for_markers  = Marker.regexes(db: self.class, markers: markers)
        @file_manager         = file_manager
        @filter_params        = params[:filter]
        @taxonomy_params      = params[:taxonomy]
        @region_params        = params[:region]
    end

    def run
        MiscHelper.OUT_header('Starting to classify BOLD downloads')
        puts
        
        specimens_of_taxon = Hash.new { |hash, key| hash[key] = {} }
        specimens_of_sequence = Hash.new
        file_of = MiscHelper.create_output_files(file_manager: file_manager, query_taxon_name: query_taxon_name, file_name: file_name, params: params, source_db: 'gbol') unless params[:derep].any? { |opt| opt.last == true }

        file = File.file?(file_name) ? File.open(file_name, 'r') : nil
        return nil if file.nil?
        
        @@index_by_column_name = MiscHelper.generate_index_by_column_name(file: file, separator: "\t")

        file.each do |row|
            _matches_query_taxon(row.scrub!) ? nil : next if fast_run

            scrubbed_row = row.scrub!.chomp.split("\t")

            specimen = _get_specimen(row: scrubbed_row)
            next if specimen.nil? || specimen.sequence.nil? || specimen.sequence.empty?
            next unless specimen_is_from_area(specimen: specimen, region_params: region_params) if region_params.any?
            
            SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
        end
        
        puts "file '#{file_name}'' was read"
        puts 

        puts 'Starting taxa search'

        specimens_of_taxon.keys.each do |taxon_name|
            nomial              = specimens_of_taxon[taxon_name][:nomial]
            next unless nomial

            first_specimen_info = specimens_of_taxon[taxon_name][:first_specimen_info]
            taxonomic_info      = nomial.taxonomy(first_specimen_info: first_specimen_info, importer: self.class)
            
            next unless taxonomic_info
            next unless taxonomic_info.public_send(TaxonomyHelper.latinize_rank(query_taxon_rank)) == query_taxon_name

            if filter_params[:taxon_rank]
                has_user_taxon_rank = FilterHelper.has_taxon_tank(rank: filter_params[:taxon_rank], taxonomic_info: taxonomic_info)
                next unless has_user_taxon_rank
            end

            if params[:derep].any? { |opt| opt.last == true }
                DerepHelper.fill_specimens_of_sequence(specimens: specimens_of_taxon[taxon_name][:data], specimens_of_sequence: specimens_of_sequence, taxonomic_info: taxonomic_info, taxon_name: taxon_name, first_specimen_info: first_specimen_info)
            else
                MiscHelper.write_to_files(file_of: file_of, taxonomic_info: taxonomic_info, nomial: nomial, params: params, data: specimens_of_taxon[taxon_name][:data])
            end
        end

        puts 'taxon search completed'
        puts

        if params[:derep].any? { |opt| opt.last == true }
            puts "Starting dereplication for file #{file_name}"

            DerepHelper.dereplicate(specimens_of_sequence, taxonomy_params, query_taxon_name)
            puts 'dereplication finished'
            puts
        else
            ## TODO: Check if it should also be done for Comparison
            OutputFormat::Tsv.rewind
            file_of.each { |fc, fh| fh.close }
        end

        return nil
    end

    private
    def _get_specimen(row:)
        identifier                    = row[@@index_by_column_name["processid"]]
        source_taxon_name             = SpecimensOfTaxon.find_lowest_ranking_taxon(row, @@index_by_column_name)
        sequence                      = row[@@index_by_column_name['nucleotides']]
        return nil if sequence.nil? || sequence.blank?
        
        sequence                      = FilterHelper.filter_seq(sequence, filter_params)
        marker                        = row[@@index_by_column_name["markercode"]]
        location                      = row[@@index_by_column_name["country"]]
        lat                           = row[@@index_by_column_name["lat"]]
        long                          = row[@@index_by_column_name["lon"]]
        
        return nil unless _belongs_to_correct_marker?(marker)
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

    def _belongs_to_correct_marker?(marker)
        regexes_for_markers === marker
    end

    def self.get_source_lineage(row)
        lineage_ary = SpecimensOfTaxon.create_lineage_ary(row, @@index_by_column_name)
    
        OpenStruct.new(
            name: SpecimensOfTaxon.find_lowest_ranking_taxon(row, @@index_by_column_name),
            combined: lineage_ary
        )
    end

    def _matches_query_taxon(row)
        /#{query_taxon_name}/.match?(row)
    end
end