# frozen_string_literal: true

class GbolClassifier
    include StringFormatting
    include GeoUtils
    attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :fast_run, :query_taxon_name, :file_manager, :filter_params, :taxonomy_params, :region_params, :params

    INCLUDED_TAXA = {
        'Hemiptera' => ['Auchenorrhyncha', 'Heteroptera', 'Sternorrhyncha']
    }

    RANKS = {
        1 => ['regnum'],
        2 => ['regnum', 'phylum'],
        3 => ['regnum', 'phylum', 'familia'],
        4 => ['regnum', 'phylum', 'classis', 'familia',],
        5 => ['regnum', 'phylum', 'classis', 'ordo', 'familia'],
        6 => ['regnum', 'subphylum', 'phylum', 'classis', 'ordo', 'familia'],
        7 => ['regnum', 'subphylum', 'phylum', 'classis', 'ordo', 'familia', 'subfamilia'],
    }

    def self.get_source_lineage(row)
        OpenStruct.new(
            name:     row["Species"],
            combined: row['HigherTaxa'].split(', ').push(row["Species"])
        )
    end

    def self.get_taxon_object_for_unmapped(first_specimen)
        canonical_name          = first_specimen["Species"]
        lineage                 = first_specimen['HigherTaxa']
        splitted_lineage        = lineage.split(', ')
        splitted_canonical_name = canonical_name.split(' ')

        return nil if splitted_lineage.size > 7
        return nil if splitted_lineage.size < 1

        ranks_for_specimen = RANKS[splitted_lineage.size]

        index = ranks_for_specimen.index('regnum')
        regnum = index.nil? ? '' : splitted_lineage[index]

        index = ranks_for_specimen.index('phylum')
        phylum = index.nil? ? '' : splitted_lineage[index]

        index = ranks_for_specimen.index('classis')
        classis = index.nil? ? '' : splitted_lineage[index]

        index = ranks_for_specimen.index('ordo')
        ordo = index.nil? ? '' : splitted_lineage[index]

        index = ranks_for_specimen.index('familia')
        familia = index.nil? ? '' : splitted_lineage[index]

        if splitted_canonical_name.size > 1
            genus = splitted_canonical_name.first
        else
            genus = ''
        end

        index = splitted_lineage.index(canonical_name)
        taxon_rank = index.nil? ? 'species' : TaxonomyHelper.anglicise_rank(ranks_for_specimen[index])

        combined = first_specimen['HigherTaxa'].split(', ').push(first_specimen["Species"])

        obj = OpenStruct.new(
            taxon_id:               'no_info',
            regnum:                 regnum,
            phylum:                 phylum,
            classis:                classis,
            ordo:                   ordo,
            familia:                familia,
            genus:                  genus,
            canonical_name:         canonical_name,
            scientific_name:        'no_info',
            taxonomic_status:       'no_info',
            taxon_rank:             taxon_rank,
            combined:               combined,
            comment:                ''
        )

        return obj
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
        MiscHelper.OUT_header('Starting to classify GBOL downloads')
        puts
        specimens_of_taxon      = Hash.new { |hash, key| hash[key] = {} }
        specimens_of_sequence   = Hash.new
        file_of = MiscHelper.create_output_files(file_manager: file_manager, query_taxon_name: query_taxon_name, file_name: file_name, params: params, source_db: 'gbol') unless params[:derep].any? { |opt| opt.last == true }

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

        puts "file '#{csv_file_name}'' was read"
        puts 

        # Parallel.map(specimens_of_taxon.keys, in_threads: 10) do |taxon_name|
        #     ActiveRecord::Base.connection_pool.with_connection do
        #         nomial  = specimens_of_taxon[taxon_name][:nomial]
        #         unless nomial.nil?
        #             first_specimen_info = specimens_of_taxon[taxon_name][:first_specimen_info]
        #             taxonomic_info      = nomial.taxonomy(first_specimen_info: first_specimen_info, importer: self.class)
        #             p taxonomic_info
        #         end
        #     end
        # end

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
            puts "Starting dereplication for file #{csv_file_name}"
            
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
