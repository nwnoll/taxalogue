# frozen_string_literal: true

class GbolClassifier
    include StringFormatting
    include GeoUtils
    attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :fast_run, :query_taxon_name, :file_manager, :filter_params, :taxonomy_params, :region_params, :params

    INCLUDED_TAXA = {
        'Hemiptera' => ['Auchenorrhyncha', 'Heteroptera', 'Sternorrhyncha']
    }

    def self.get_source_lineage(row)
        OpenStruct.new(
            name:     row["Species"],
            combined: row['HigherTaxa'].split(', ').push(row["Species"])
        )
    end

    def initialize(params:, file_name:, file_manager:)
        @file_name          = file_name
        @params             = params
        @query_taxon_object = params[:taxon_object]
        @query_taxon_name   = query_taxon_object.canonical_name
        @query_taxon_rank   = query_taxon_object.taxon_rank
        @fast_run           = params[:fast_run]
        @file_manager       = file_manager
        @filter_params      = params[:filter]
        @taxonomy_params    = params[:taxonomy]
        @region_params      = params[:region]
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

        file_of = MiscHelper.create_output_files(file_manager: file_manager, query_taxon_name: query_taxon_name, file_name: file_name, params: params, source_db: 'gbol')
    
        if params[:filter][:dereplicate]
            specimens_of_sequence = Hash.new { |h,k| h[k] = [] }
            specimens_of_taxon.keys.each do |taxon_name|
                specimens_of_taxon[taxon_name][:data].each do |specimen|
                    specimens_of_sequence[specimen[:sequence]].push(taxon_name)
                end
            end

            specimens_of_sequence.each do |seq, names_ary|
                if names_ary.uniq.size > 1
                    puts seq
                    puts names_ary.size
                    p names_ary.uniq
                    puts
                    puts '*' * 100
                end
            end
        end

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


            # if taxonomic_info.taxon_rank =~ /species/ || (!taxonomic_info.genus.blank? && !taxonomic_info.canonical_name.blank?)
            #     canonical_ary = taxonomic_info.canonical_name.split(' ')
            #     if canonical_ary.size >= 2
            #         if canonical_ary.first != taxonomic_info.genus
            #             p canonical_ary.first
            #             p taxonomic_info.genus
            #             p first_specimen_info
            #             p taxonomic_info
            #             p _to_taxon_info_fasta(taxonomic_info)
            #             p _to_taxon_info_tsv(taxonomic_info)
            #             p taxonomic_info.taxon_rank
            #             p taxonomic_info.public_send(TaxonomyHelper.latinize_rank(taxonomic_info.taxon_rank))
            #             puts '*'  * 100
            #         end
            #     end
            # end

            # puts _to_taxon_info_tsv_all_standard_ranks(taxonomic_info)

            MiscHelper.write_to_files(file_of: file_of, taxonomic_info: taxonomic_info, nomial: nomial, params: params, specimens_of_taxon: specimens_of_taxon, taxon_name: taxon_name)

        end

        OutputFormat::Tsv.rewind
        file_of.each { |fc, fh| fh.close }

        return nil
    end
  
    private
    def _get_specimen(row:)
        identifier                    = row["CatalogueNumber"]
        source_taxon_name             = row["Species"]
        sequence                      = row['BarcodeSequence']
        return nil if sequence.nil? || sequence.blank?

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
        if INCLUDED_TAXA.key?(query_taxon_name)
            INCLUDED_TAXA[query_taxon_name].each do |included_name|
                matched = /#{included_name}/.match?(row["HigherTaxa"]) || /#{included_name}/.match?(row["Species"])
                
                return true if matched
            end

            return false
        else
            /#{query_taxon_name}/.match?(row["HigherTaxa"]) || /#{query_taxon_name}/.match?(row["Species"])
        end
    end
end
