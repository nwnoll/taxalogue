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
                            source_taxon_name: taxon_name,
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
                        source_taxon_name: taxon_name,
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

            

            # MiscHelper.write_to_files(file_of: file_of, taxonomic_info: taxonomic_info, nomial: nomial, params: params, data: specimens_of_taxon[taxon_name][:data])

        end

        ## TODO:
        # Need to make it global
        # or passed from Job to Job...
        seq_top_ids                     = []
        seqs_with_taxonomic_conflicts   = Hash.new { |h, k| h[k] = Hash.new(0) }
        ##
        seq_arys_to_import              = []
        top_arys_to_import              = []
        related_seqs_and_taxon_infos    = Hash.new
        already_pushed_tops             = Set.new

        specimens_of_sequence.each do |seq, seq_meta_of|
            seq_sha256_bubblebabble = Digest::SHA256.bubblebabble(seq)

            ## Maybe easiest is to trop the has many through table? and create it again?
            seq_meta_of.each { |k, v| seqs_with_taxonomic_conflicts[seq_sha256_bubblebabble][k] += v.specimens.size} if seq_meta_of.size > 1
            
            if Sequence.exists?(sha256_bubblebabble: seq_sha256_bubblebabble)
                sequence_ary_or_id = Sequence.find_by(sha256_bubblebabble: seq_sha256_bubblebabble).id
            else
                sequence_ary_or_id = [seq_sha256_bubblebabble, seq]
                seq_arys_to_import.push(sequence_ary_or_id)
            end

            seq_sha_or_id =  sequence_ary_or_id.kind_of?(Array) ? seq_sha256_bubblebabble : sequence_ary_or_id
            
            related_seqs_and_taxon_infos[seq_sha_or_id] = OpenStruct.new(
                taxon_object_proxy_sha_or_ids: [],
                specimens_num: 0,
                first_specimen_identifier: nil
            )

            seq_meta_of.each do |canonical_name, seq_meta|
                if taxonomy_params[:ncbi]
                    used_taxonomy_string = 'ncbi'
                elsif taxonomy_params[:gbif_backbone]
                    used_taxonomy_string = 'gbif_backbone'
                elsif taxonomy_params[:gbif]
                    used_taxonomy_string = 'gbif'
                end
                
                taxon_object_proxy_string = "#{seq_meta.taxonomic_infos.regnum}|#{seq_meta.taxonomic_infos.phylum}|#{seq_meta.taxonomic_infos.classis}|#{seq_meta.taxonomic_infos.ordo}|#{seq_meta.taxonomic_infos.familia}|#{seq_meta.taxonomic_infos.genus}|#{seq_meta.taxonomic_infos.canonical_name}|#{seq_meta.taxonomic_infos.scientific_name}|#{used_taxonomy_string}"
                taxon_object_proxy_string_as_sha256_bubblebabble = Digest::SHA256.bubblebabble(taxon_object_proxy_string)
                
                if TaxonObjectProxy.exists?(sha256_bubblebabble: taxon_object_proxy_string_as_sha256_bubblebabble)
                    taxon_object_proxy_ary_or_id = TaxonObjectProxy.find_by(sha256_bubblebabble: taxon_object_proxy_string_as_sha256_bubblebabble).id
                elsif already_pushed_tops.include?(taxon_object_proxy_string_as_sha256_bubblebabble)
                    ## lateron I check if the variable is of kind array
                    # if thats the case i will use the sha
                    # i have to use the sha since I dont yet have the ID, because
                    # I import all at once later
                    taxon_object_proxy_ary_or_id = [] 
                else
                    seq_meta_hash = seq_meta.taxonomic_infos.to_h
                    seq_meta_hash[:combined] = seq_meta_hash[:combined].join(', ') if seq_meta_hash[:combined]

                    taxon_object_proxy_ary_or_id = seq_meta_hash.to_h.values
                    taxon_object_proxy_ary_or_id.push(query_taxon_name, used_taxonomy_string, taxonomy_params[:synonyms_allowed], seq_meta.source_taxon_name, taxon_object_proxy_string_as_sha256_bubblebabble)
                    top_arys_to_import.push(taxon_object_proxy_ary_or_id)
                    already_pushed_tops.add(taxon_object_proxy_string_as_sha256_bubblebabble)
                end

                top_sha_or_id =  taxon_object_proxy_ary_or_id.kind_of?(Array) ? taxon_object_proxy_string_as_sha256_bubblebabble : taxon_object_proxy_ary_or_id
                related_seqs_and_taxon_infos[seq_sha_or_id].taxon_object_proxy_sha_or_ids.push(top_sha_or_id)
                related_seqs_and_taxon_infos[seq_sha_or_id].specimens_num = seq_meta.specimens.size
                related_seqs_and_taxon_infos[seq_sha_or_id].first_specimen_identifier = seq_meta.specimens.first[:identifier]
            end

        end
        seq_columns = Sequence.column_names - ['id']
        top_columns = TaxonObjectProxy.column_names - ['id']
        seq_top_columns = SequenceTaxonObjectProxy.column_names - ['id']
        
        TaxonObjectProxy.import top_columns, top_arys_to_import, validate: false, batch_size: 100_000 if top_arys_to_import.any?
        Sequence.import seq_columns, seq_arys_to_import, validate: false, batch_size: 100_000 if seq_arys_to_import.any?
        sleep 1

        seq_top_arys_to_import = []
        related_seqs_and_taxon_infos.each do |key, value|
            seq_id = key.kind_of?(String) ? Sequence.find_by(sha256_bubblebabble: key).id : key
            value.taxon_object_proxy_sha_or_ids.each do |top_sha_or_id|
                top_id = top_sha_or_id.kind_of?(String) ? TaxonObjectProxy.find_by(sha256_bubblebabble: top_sha_or_id).id : top_sha_or_id
                
                unless SequenceTaxonObjectProxy.exists?(sequence_id: seq_id, taxon_object_proxy_id: top_id)
                    seq_top_arys_to_import.push([seq_id, top_id, value.specimens_num, value.first_specimen_identifier])
                end

                seq_top_ids.push([seq_id, top_id])
            end
        end

        SequenceTaxonObjectProxy.import seq_top_columns, seq_top_arys_to_import, validate: false, batch_size: 100_000 if seq_top_arys_to_import.any?
        sleep 1
        
        seq_top_ids.map.with_index(0) do |seq_top_ary, index|
            seq_top_join_id = SequenceTaxonObjectProxy.find_by(sequence_id: seq_top_ary[0], taxon_object_proxy_id: seq_top_ary[1]).id
            seq_top_ids[index].push(seq_top_join_id)
        end

        seq_records_with_taxonomic_conflicts = Sequence.where(sha256_bubblebabble: seqs_with_taxonomic_conflicts.keys)


        ## TODO: next specimens num is wrong in databse...
        # but correct in hash
        seqs_with_taxonomic_conflicts.each do |seq_sha, specimens_num_of_taxon|
            seq_record = Sequence.find_by(sha256_bubblebabble: seq_sha)
            puts '*' * 100
            pp seq_record
            puts '------------'
            pp seq_record.taxon_object_proxies
            puts '------------'
            pp seq_record.sequence_taxon_object_proxies

            puts '*' * 100
            pp seqs_with_taxonomic_conflicts[seq_sha]

        end

        if params[:filter][:dereplicate]
            specimens_of_sequence.keys.each do |seq|
                if specimens_of_sequence[seq].keys.size > 1
                    p specimens_of_sequence[seq].keys
                    puts specimens_of_sequence[seq].size

                    old_seq_metas = []
                    same_lineages = []
                    # metas = specimens_of_sequence[seq].each.values
                    # num_of_specimens = metas.specimens.map!{ |specimen_ary| specimen_ary.size }
                    # if num_of_specimens.uniq.size == 1
                        ## all taxon names have the same value
                        ## therefore it will be only valid if
                        ## all share a lca
                        # if seq_meta.taxonomic_infos.public_send(old_latinized_rank) == old_taxon_name || old_seq_meta.taxonomic_infos.public_send(current_latinized_rank) == taxon_name

                    # end
                    chosen_one = nil
                    specimens_of_sequence[seq].each do |taxon_name, seq_meta|
                        if chosen_one
                            old_taxon_name          = chosen_one.first
                            old_seq_meta            = chosen_one.last
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

























                        # if old_seq_metas.any?
                        #     old_seq_metas.each do |old_seq_meta_ary|
                        #         old_taxon_name          = old_seq_meta_ary.first
                        #         old_seq_meta            = old_seq_meta_ary.last
                        #         old_latinized_rank      = TaxonomyHelper.latinize_rank(old_seq_meta.taxonomic_infos.taxon_rank)
                        #         current_latinized_rank  = TaxonomyHelper.latinize_rank(seq_meta.taxonomic_infos.taxon_rank)
                                
                        #         if seq_meta.taxonomic_infos.public_send(old_latinized_rank) == old_taxon_name || old_seq_meta.taxonomic_infos.public_send(current_latinized_rank) == taxon_name
                                    
                        #             old_taxon_rank_index        = GbifTaxonomy.possible_ranks.index(old_seq_meta.taxonomic_infos.taxon_rank)
                        #             current_taxon_rank_index    = GbifTaxonomy.possible_ranks.index(seq_meta.taxonomic_infos.taxon_rank)
                                    
                        #             if old_taxon_rank_index < current_taxon_rank_index
                        #                 lower_taxon_name = old_taxon_name
                        #                 higher_taxon_name = taxon_name
                        #                 lower_taxon_seq_meta = old_seq_meta
                        #                 higher_taxon_seq_meta = seq_meta
                        #             elsif old_taxon_rank_index == current_taxon_rank_index
                        #                 if old_taxon_name.split(' ').size > taxon_name.split(' ').size
                        #                     lower_taxon_name  = old_taxon_name
                        #                     higher_taxon_name = taxon_name
                        #                     lower_taxon_seq_meta  = old_seq_meta
                        #                     higher_taxon_seq_meta = seq_meta
                        #                 else
                        #                     lower_taxon_name  = taxon_name
                        #                     higher_taxon_name = old_taxon_name
                        #                     lower_taxon_seq_meta  = seq_meta
                        #                     higher_taxon_seq_meta = old_seq_meta
                        #                 end
                        #             else
                        #                 lower_taxon_name  = taxon_name
                        #                 higher_taxon_name = old_taxon_name
                        #                 lower_taxon_seq_meta  = seq_meta
                        #                 higher_taxon_seq_meta = old_seq_meta
                        #             end

                        #             same_lineages.push(
                        #                 OpenStruct.new(
                        #                     lower_taxon_name:       lower_taxon_name,
                        #                     higher_taxon_name:      higher_taxon_name,
                        #                     lower_taxon_seq_meta:   lower_taxon_seq_meta,
                        #                     higher_taxon_seq_meta:  higher_taxon_seq_meta
                        #                 )
                        #             )
                        #         else # do not have same lineage parts
                        #             puts 'Do not have same lineage parts'
                        #             puts '*' * 20
                        #             puts taxon_name
                        #             puts seq_meta.specimens.size
                        #             puts old_taxon_name
                        #             puts old_seq_meta.specimens.size

                        #             if seq_meta.specimens.size == old_seq_meta.specimens.size
                        #                 ## here we do have the same number of specimens for different taxa
                        #                 ## therefore it will choose the LCA of these two taxa
                        #                 lca = TaxonHelper.lowest_matching_taxon(obj1: seq_meta, obj2: old_seq_meta, params: params, importer: self.class)
                        #                 puts "LCA:"
                        #                 p lca
                        #             else
                        #                 ## one taxon has mor specimens than the other
                        #                 ## for now i select the one with higher number of specimens
                        #                 ## threshold could be implement at what point it should choose
                        #                 ## one taxon over the other or if it should search for a LCA
                        #                 taxon_with_more_specimens = seq_meta.specimens.size > old_seq_meta.specimens.size ? seq_meta : old_seq_meta
                        #                 puts 'THE CHOSE ONE'
                        #                 puts taxon_with_more_specimens.taxonomic_infos
                        #                 puts '*' * 20
                        #             end
                        #         end
                        #     end
                        # end

                        chosen_one = [taxon_name, seq_meta]
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
