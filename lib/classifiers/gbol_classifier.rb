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
    
        # if params[:filter][:dereplicate]
        #     specimens_of_sequence = Hash.new { |h,k| h[k] = [] }
        #     specimens_of_taxon.keys.each do |taxon_name|
        #         specimens_of_taxon[taxon_name][:data].each do |specimen|
        #             specimens_of_sequence[specimen[:sequence]].push(taxon_name)
        #         end
        #     end

        #     specimens_of_sequence.each do |seq, names_ary|
        #         if names_ary.uniq.size > 1
        #             puts seq
        #             puts names_ary.size
        #             p names_ary.uniq
        #             puts
        #             puts '*' * 100
        #         end
        #     end
        # end


        specimens_of_sequence = Hash.new# { |h,k| h[k] = Hash.new }
        
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

            ## dereplicate with taxon_name
            # specimens_of_taxon[taxon_name][:data].each do |specimen|
            #     seq = specimen[:sequence]
            #     if specimens_of_sequence.key?(seq)
            #         if specimens_of_sequence[seq].key?(taxon_name)
            #             specimens_of_sequence[seq][taxon_name].specimens.push(specimen)
            #         else
            #             seq_meta = OpenStruct.new(
            #                 taxonomic_infos: taxonomic_info,
            #                 first_specimen_infos: first_specimen_info,
            #                 specimens: []
            #             )
            #             specimens_of_sequence[seq][taxon_name] = seq_meta
    
            #             specimens_of_sequence[seq][taxon_name].specimens.push(specimen)
            #         end
            #     else
            #         info_per_taxon_name = Hash.new
            #         seq_meta = OpenStruct.new(
            #             taxonomic_infos: taxonomic_info,
            #             first_specimen_infos: first_specimen_info,
            #             specimens: []
            #         )
            #         info_per_taxon_name[taxon_name] = seq_meta

            #         info_per_taxon_name[taxon_name].specimens.push(specimen)
            #         specimens_of_sequence[seq] = info_per_taxon_name 
            #     end
            # end

            ## dereplicate with canonical_name as key for specimens_of_sequence
            ## since in the act of normalization there mght be some taxon_name that change to a higher rank
            ## from now on we ware only useing this canonical name therefore
            ## whe should also use it in this context...
            canonical_name = taxonomic_info.canonical_name
            specimens_of_taxon[taxon_name][:data].each do |specimen|
                seq = specimen[:sequence]
                if specimens_of_sequence.key?(seq)
                    if specimens_of_sequence[seq].key?(canonical_name)
                        specimens_of_sequence[seq][canonical_name].specimens.push(specimen)
                    else
                        seq_meta = OpenStruct.new(
                            taxonomic_infos: taxonomic_info,
                            first_specimen_infos: first_specimen_info,
                            specimens: []
                        )
                        specimens_of_sequence[seq][canonical_name] = seq_meta
    
                        specimens_of_sequence[seq][canonical_name].specimens.push(specimen)
                    end
                else
                    info_per_canonical_name = Hash.new
                    seq_meta = OpenStruct.new(
                        taxonomic_infos: taxonomic_info,
                        first_specimen_infos: first_specimen_info,
                        specimens: []
                    )
                    info_per_canonical_name[canonical_name] = seq_meta

                    info_per_canonical_name[canonical_name].specimens.push(specimen)
                    specimens_of_sequence[seq] = info_per_canonical_name 
                end
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

            MiscHelper.write_to_files(file_of: file_of, taxonomic_info: taxonomic_info, nomial: nomial, params: params, data: specimens_of_taxon[taxon_name][:data])

        end

        if params[:filter][:dereplicate]
            specimens_of_sequence.keys.each do |seq|
                if specimens_of_sequence[seq].keys.size > 1
                    p specimens_of_sequence[seq].keys
                    puts specimens_of_sequence[seq].size

                    old_seq_metas = []
                    same_lineages = []
                    metas = specimens_of_sequence[seq].each.values
                    num_of_specimens = metas.specimens.map!( |specimen_ary| specimen_ary.size )
                    if num_of_specimens.uniq.size == 1
                        ## all taxon names have the same value
                        ## therefore it will be only valid if
                        ## all share a lca
                        # if seq_meta.taxonomic_infos.public_send(old_latinized_rank) == old_taxon_name || old_seq_meta.taxonomic_infos.public_send(current_latinized_rank) == taxon_name

                    end
                    specimens_of_sequence[seq].each do |taxon_name, seq_meta|
                        if old_seq_metas.any?
                            old_seq_metas.each do |old_seq_meta_ary|
                                old_taxon_name          = old_seq_meta_ary.first
                                old_seq_meta            = old_seq_meta_ary.last
                                old_latinized_rank      = TaxonomyHelper.latinize_rank(old_seq_meta.taxonomic_infos.taxon_rank)
                                current_latinized_rank  = TaxonomyHelper.latinize_rank(seq_meta.taxonomic_infos.taxon_rank)
                                
                                if seq_meta.taxonomic_infos.public_send(old_latinized_rank) == old_taxon_name || old_seq_meta.taxonomic_infos.public_send(current_latinized_rank) == taxon_name
                                    
                                    old_taxon_rank_index        = GbifTaxonomy.possible_ranks.index(old_seq_meta.taxonomic_infos.taxon_rank)
                                    current_taxon_rank_index    = GbifTaxonomy.possible_ranks.index(seq_meta.taxonomic_infos.taxon_rank)
                                    
                                    if old_taxon_rank_index < current_taxon_rank_index
                                        lower_taxon_name = old_taxon_name
                                        higher_taxon_name = taxon_name
                                        lower_taxon_seq_meta = old_seq_meta
                                        higher_taxon_seq_meta = seq_meta
                                    elsif old_taxon_rank_index == current_taxon_rank_index
                                        if old_taxon_name.split(' ').size > taxon_name.split(' ').size
                                            lower_taxon_name  = old_taxon_name
                                            higher_taxon_name = taxon_name
                                            lower_taxon_seq_meta  = old_seq_meta
                                            higher_taxon_seq_meta = seq_meta
                                        else
                                            lower_taxon_name  = taxon_name
                                            higher_taxon_name = old_taxon_name
                                            lower_taxon_seq_meta  = seq_meta
                                            higher_taxon_seq_meta = old_seq_meta
                                        end
                                    else
                                        lower_taxon_name  = taxon_name
                                        higher_taxon_name = old_taxon_name
                                        lower_taxon_seq_meta  = seq_meta
                                        higher_taxon_seq_meta = old_seq_meta
                                    end

                                    same_lineages.push(
                                        OpenStruct.new(
                                            lower_taxon_name:       lower_taxon_name,
                                            higher_taxon_name:      higher_taxon_name,
                                            lower_taxon_seq_meta:   lower_taxon_seq_meta,
                                            higher_taxon_seq_meta:  higher_taxon_seq_meta
                                        )
                                    )
                                else # do not have same lineage parts
                                    puts 'Do not have same lineage parts'
                                    puts '*' * 20
                                    puts taxon_name
                                    puts seq_meta.specimens.size
                                    puts old_taxon_name
                                    puts old_seq_meta.specimens.size

                                    if seq_meta.specimens.size == old_seq_meta.specimens.size
                                        ## here we do have the same number of specimens for different taxa
                                        ## therefore it will choose the LCA of these two taxa
                                        lca = TaxonHelper.lowest_matching_taxon(obj1: seq_meta, obj2: old_seq_meta, params: params, importer: self.class)
                                        puts "LCA:"
                                        p lca
                                    else
                                        ## one taxon has mor specimens than the other
                                        ## for now i select the one with higher number of specimens
                                        ## threshold could be implement at what point it should choose
                                        ## one taxon over the other or if it should search for a LCA
                                        taxon_with_more_specimens = seq_meta.specimens.size > old_seq_meta.specimens.size ? seq_meta : old_seq_meta
                                        puts 'THE CHOSE ONE'
                                        puts taxon_with_more_specimens.taxonomic_infos
                                        puts '*' * 20
                                    end
                                end
                            end
                        end

                        old_seq_metas.push([taxon_name, seq_meta])

                    end

                    ## derep with same lineage parts
                    puts '-'
                    same_lineages.each do |same_lineage|
                        puts "lower_taxon_name:  #{same_lineage.lower_taxon_name}"
                        puts "low_specimen_num:  #{same_lineage.lower_taxon_seq_meta.specimens.size}"
                        puts "higher_taxon_name: #{same_lineage.higher_taxon_name}"
                        puts "high_specimen_num: #{same_lineage.higher_taxon_seq_meta.specimens.size}"
                        puts 
                        puts 'THE CHOSE ONE'
                        puts same_lineage.lower_taxon_name
                    end
                    puts



                end
            end
        end

        OutputFormat::Tsv.rewind
        file_of.each { |fc, fh| fh.close }

        return nil
    end



    #<OpenStruct taxonomic_infos=#<OpenStruct taxon_id=7042, regnum="Metazoa", phylum="Arthropoda", classis="Insecta", ordo="Coleoptera", familia="Curculionidae", genus="", canonical_name="Curculionidae", scientific_name="Curculionidae", taxonomic_status="accepted", taxon_rank="family", combined=["Metazoa", "Arthropoda", "Insecta", "Coleoptera", "Curculionidae"], comment="">, first_specimen_infos=#<CSV::Row "HigherTaxa":"Animalia, Arthropoda, Hexapoda, Insecta, Coleoptera, Curculionidae" "Species":"Acalles navieresi" "BarcodeSequence":"TACTTTATATTTTATCTTTGGTTCATGATCAGGAATAGTAGGAACATCATTAAGAATATTAATTCGAACTGAATTAGGAAACCCTGGAACCTTAATTGGTAATGATCAAATCTACAATTCAATTGTAACTGCCCATGCCTTTATTATAATTTTTTTCATAGTTATACCTATCATAATTGGGGGATTCGGCAATTGACTGATTCCTTTGATATTAGGAGCGCCCGATATAGCTTTCCCTCGATTAAATAATATAAGATTTTGGCTTTTACCTCCCTCATTAATTCTTCTTCTAATAAGAAGAATCATTGATAAAGGAGCTGGAACTGGCTGAACTGTTTATCCTCCTTTATCAGCTAATATTGCTCATGAAGGAATTTCTATTGATTTAGCTATTTTTAGATTACATATGGCAGGAGTTTCCTCAATTCTTGGAGCAATCAACTTTATCTCTACTGTAATTAACATACGTCCAATAGGGATAAATATTGACCGAATACCATTATTTATTTGAGCAGTAAAAATTACAGCGATTCTTCTACTTTTATCCCTACCTGTATTAGCTGGAGCTATTACTATACTATTAACAGACCGAAATATTAATACTTCATTTTTTGACCCTGCAGGAGGGGGAGACCCAATTTTATATCAACACTTATTT" "Institute":"ZFMK" "CatalogueNumber":"ZFMK-TIS-2563764" "UUID":"https://bolgermany.de/specimen/45f004119ab3ca09ec78a9f3c57a5748" "Location":"Rheinland-Pfalz, Germany, Elmstein" "Latitude":"49.42" "Longitude":"7.92">, specimens=[{:identifier=>"ZFMK-TIS-2563764", :sequence=>"TACTTTATATTTTATCTTTGGTTCATGATCAGGAATAGTAGGAACATCATTAAGAATATTAATTCGAACTGAATTAGGAAACCCTGGAACCTTAATTGGTAATGATCAAATCTACAATTCAATTGTAACTGCCCATGCCTTTATTATAATTTTTTTCATAGTTATACCTATCATAATTGGGGGATTCGGCAATTGACTGATTCCTTTGATATTAGGAGCGCCCGATATAGCTTTCCCTCGATTAAATAATATAAGATTTTGGCTTTTACCTCCCTCATTAATTCTTCTTCTAATAAGAAGAATCATTGATAAAGGAGCTGGAACTGGCTGAACTGTTTATCCTCCTTTATCAGCTAATATTGCTCATGAAGGAATTTCTATTGATTTAGCTATTTTTAGATTACATATGGCAGGAGTTTCCTCAATTCTTGGAGCAATCAACTTTATCTCTACTGTAATTAACATACGTCCAATAGGGATAAATATTGACCGAATACCATTATTTATTTGAGCAGTAAAAATTACAGCGATTCTTCTACTTTTATCCCTACCTGTATTAGCTGGAGCTATTACTATACTATTAACAGACCGAAATATTAATACTTCATTTTTTGACCCTGCAGGAGGGGGAGACCCAATTTTATATCAACACTTATTT", :location=>"Rheinland-Pfalz, Germany, Elmstein", :latitude=>"49.42", :longitude=>"7.92"}]>

  
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
