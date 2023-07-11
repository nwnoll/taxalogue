# frozen_string_literal: true

class MultipleJobs
    attr_reader :jobs, :download_only, :params, :result_file_manager
    
    BATCH_SIZE = 100_000
    
    def initialize(jobs:, params:)
        @jobs           = jobs
        @params         = params
        @download_only  = params[:download].any?
        @result_file_manager = nil
    end

    def run
        results_of = Hash.new

        # force_download = true if jobs.size > 1
        bold_dir = nil
        gbol_dir = nil
        ncbi_dir = nil

        $seq_ids = Set.new 
       
        ## set download dirs
        jobs.each do |job|
            if job.class == BoldJob
                if params[:download][:bold_dir]
                    bold_dir = Pathname.new(params[:download][:bold_dir])
                elsif params[:classify][:bold_release]
                    bold_dir = nil
                else
                    bold_dir = BoldDownloadCheckHelper.ask_user_about_download_dirs(params, only_successful = false)
                end
            elsif job.class == GbolJob
                ## TODO: implement user provided gbol_dir for failure check and download
                gbol_dir = GbolDownloadCheckHelper.ask_user_about_gbol_download_dirs(params)
            elsif job.class == NcbiGenbankJob
                if params[:download][:genbank_dir]
                    ncbi_dir = NcbiDownloadCheckHelper.create_release_info_struct(params[:download][:genbank_dir], params)
                else
                    ncbi_dir = NcbiDownloadCheckHelper.ask_user_about_download_dirs(params, only_successful = true)
                end
            end
        end


        ## run jobs
        used_source_db_ary = []
        jobs.each do |job|
            if job.class == BoldJob
                used_source_db_ary.push('bold')
                results_of[job.class] = job.run(bold_dir)
            elsif job.class == GbolJob
                used_source_db_ary.push('gbol')
                results_of[job.class] = job.run(gbol_dir)
            elsif job.class == NcbiGenbankJob
                used_source_db_ary.push('ncbi')
                results_of[job.class] = job.run(ncbi_dir)
            end
        end


        ## dereplicate
        if DerepHelper.do_derep
            
            file_manager    = jobs.last.result_file_manager
            source_db_string = used_source_db_ary.size == 3 ? 'all' : used_source_db_ary.join('_')

            file_of = MiscHelper.create_output_files(
                file_manager: file_manager,
                query_taxon_name: params[:taxon_object].canonical_name,
                file_name: Pathname.new("derep"),
                params: params,
                source_db: source_db_string
            )

            count                             = 0
            data_for_batch_writing            = []
            taxonomic_info_for_batch_writing  = []
            nomial_for_batch_writing          = []
            
            puts "Reconnecting to database" 
            $db_connection.connection.reconnect! 
            sleep 1
            
            puts "Processing records" 
            Sequence.where(id: $seq_ids).find_each do |seq|
                
                puts "Processed 10_000 records" if (count % 10_000) == 0
                ## write to file if BATCH_SIZE of seqs has been dereplicated 
                if count == BATCH_SIZE

                    puts "Writing #{BATCH_SIZE} dereplicated records."
                    MiscHelper.write_to_files(
                        file_of: file_of,
                        taxonomic_info: taxonomic_info_for_batch_writing,
                        nomial: nomial_for_batch_writing,
                        params: params,
                        data: data_for_batch_writing,
                        batch: true
                    )
            
                    taxonomic_info_for_batch_writing  = []
                    nomial_for_batch_writing          = []
                    data_for_batch_writing            = []
                    count                             = 0
                end  
                count += 1
                
                ## if there is only one taxon_object_proxy, we dont hav any name conflicts between records
                if seq.taxon_object_proxies.size < 2
                    data_for_batch_writing.push(_create_specimen_data(seq, seq.sequence_taxon_object_proxies.first))
                    taxonomic_info_for_batch_writing.push(seq.taxon_object_proxies.first)
                    nomial_for_batch_writing.push(seq.taxon_object_proxies.first.source_taxon_name)
            
                    next
                end

                ## compare and sort taxon names
                comparison_results_for = Hash.new
                sorted = _sort_taxon_names(seq: seq, comparison_results_for: comparison_results_for) 
              
                same_comparison_results = []
                comparison_results_for.each do |taxon_object_proxy, comparison_result|
                    next if sorted.first == taxon_object_proxy
            
                    if comparison_results_for[sorted.first] == comparison_result
                        same_comparison_results.any? ? same_comparison_results.push(taxon_object_proxy) : same_comparison_results.push(sorted.first, taxon_object_proxy)
                    end
                end
           
                ## if the taxon_name differs and both have the same sorting place, wee need to decide what to do
                ## last_common_ancestor chooses the lca between the taxon names
                ## random just picks one
                ## discard removes the seq, due to name conflicts
                ## last_common_ancestor is the default 
                if same_comparison_results.any?
            
                    if params[:derep][:last_common_ancestor]
            
                        comparison_result   = comparison_results_for[sorted.first]
                        lca_rank_index      = comparison_result[1]
                        lca_rank            = GbifTaxonomy.rank_mappings.values[lca_rank_index]
                        taxon_name          = sorted.first.public_send(lca_rank)
            
                        if params[:taxonomy][:unmapped]
                            taxon_record = sorted.first
                            taxon_record.canonical_name = taxon_name
                            taxon_record.taxon_rank = lca_rank == 'canonical_name' ? 'species' : lca_rank
                            
                            ## go through every rank that should have no information anymore
                            (1...lca_rank_index).each do |i|
                                taxon_record[GbifTaxonomy.rank_mappings.values[i]] = ""
                            end
                        else
                            taxon_record = TaxonHelper.get_taxon_record(params, taxon_name, automatic: true)
                        end
                        next if taxon_record.nil?
                        
            
                        data_for_batch_writing.push(_create_specimen_data(seq, sorted.first.sequence_taxon_object_proxies.find_by(sequence_id: seq.id)))
                        taxonomic_info_for_batch_writing.push(taxon_record)
                        nomial_for_batch_writing.push(sorted.first.source_taxon_name)
            
                        next
                    elsif params[:derep][:random]
                        
                        data_for_batch_writing.push(_create_specimen_data(seq, sorted.first.sequence_taxon_object_proxies.find_by(sequence_id: seq.id)))
                        taxonomic_info_for_batch_writing.push(sorted.first)
                        nomial_for_batch_writing.push(sorted.first.source_taxon_name)
            
                        next
                    elsif params[:derep][:discard]
            
                        # maybe write it to extra file
            
                        next
                    end
                else
                    ## sorted.first is the best hit
                    
                    data_for_batch_writing.push(_create_specimen_data(seq, sorted.first.sequence_taxon_object_proxies.find_by(sequence_id: seq.id)))
                    taxonomic_info_for_batch_writing.push(sorted.first)
                    nomial_for_batch_writing.push(sorted.first.source_taxon_name)
            
                    next
                end
            end
            
            ## write the results for the remaining records
            if data_for_batch_writing.any?

                puts "Writing #{count} dereplicated records."
                MiscHelper.write_to_files(
                    file_of: file_of,
                    taxonomic_info: taxonomic_info_for_batch_writing,
                    nomial: nomial_for_batch_writing,
                    params: params,
                    data: data_for_batch_writing,
                    batch: true
                )
            end
            
            file_of.each { |fc, fh| fh.close }
        end

        puts
        MiscHelper.OUT_header "Output locations:"
        result_file_manager = nil
        count_cant_classify = 0


        results_of.each do |key, value|
            result_file_manager     = value.first
            download_file_managers  = value.last
            
            ## TODO
            # What should I do with incomplete classifications?
            # I halso have to see what i do at caller
            if download_file_managers == :cant_classify
                MiscHelper.OUT_error "#{_from_class_to_source_db(key)} classification failed, please try again"


                count_cant_classify += 1
                next
            end


            if download_file_managers == :cant_download
                MiscHelper.OUT_error "#{_from_class_to_source_db(key)} download failed, please try again"
                next
            end


            if key == NcbiGenbankJob && download_file_managers == :not_current_release
                MiscHelper.OUT_error "You have an old #{_from_class_to_source_db(key)} release. Only the current release is downloadable"
                puts "Consider downloading the current release with: bundle exec ruby taxalogue.rb download --genbank"
                next
            end


            download_file_managers.each_with_index do |download_file_manager, i|
                if key == BoldJob
                    download_dir_path = download_file_manager.base_dir
                    puts download_dir_path if i == 0
                else
                    download_dir_path = download_file_manager.dir_path
                    puts download_dir_path
                end
            end
        end


        if count_cant_classify == results_of.keys.size
            MiscHelper.OUT_error 'No output' unless download_only
            FileUtils.rm_rf(result_file_manager.dir_path)

            
            return :failure
        else
            unless download_only
                MiscHelper.write_marshal_file(dir: result_file_manager.dir_path, data: result_file_manager, file_name: '.result_file_manager.dump')
                MiscHelper.OUT_success result_file_manager.dir_path
            end


            return :success
        end
    end

    def _sort_taxon_names(seq:, comparison_results_for:)
        sorted = seq.taxon_object_proxies.to_a.sort_by do |taxon_object_proxy|
            specimens_num = -(taxon_object_proxy.sequence_taxon_object_proxies.find_by(sequence_id: seq.id).specimens_num)
            rank = GbifTaxonomy.possible_ranks.index(taxon_object_proxy.taxon_rank)
    
            if rank.nil?
                deduced_rank = TaxonHelper.deduce_rank(taxon_object_proxy)
                rank = deduced_rank.nil? ? (GbifTaxonomy.possible_ranks.size -1) : GbifTaxonomy.possible_ranks.index(deduced_rank)
            end
    
            rank_hit_index = 9 ## this value is only for sorting purposes, a higher value means higherrank hit
            seq.taxon_object_proxies.map do |other_taxon_object_proxy|
                next if taxon_object_proxy.id == other_taxon_object_proxy.id
    
                lowest_rank_hit_index = (GbifTaxonomy.possible_ranks.size - 1)
                GbifTaxonomy.rank_mappings.values.each_with_index do |latinized_possible_rank, index|
                    if (!taxon_object_proxy.public_send(latinized_possible_rank).blank? && !other_taxon_object_proxy.public_send(latinized_possible_rank).blank?) && (taxon_object_proxy.public_send(latinized_possible_rank) == other_taxon_object_proxy.public_send(latinized_possible_rank))
                        lowest_rank_hit_index = index
    
                        break
                    end
                end
    
                rank_hit_index = lowest_rank_hit_index if lowest_rank_hit_index < rank_hit_index## this value is only for sorting purposes, a higher value means higher rank hit
            end
    
            comparison_results_for[taxon_object_proxy] = [rank, rank_hit_index, specimens_num]
            
            [rank, rank_hit_index, specimens_num]
        end
    
    
        return sorted
    end

    def _create_specimen_data(seq, seq_top)
        specimen_data = Hash.new
        specimen_data[:identifier]  =  seq_top.first_specimen_identifier
        specimen_data[:sequence]    =  seq.nucleotides
        specimen_data[:location]    =  seq_top.first_specimen_location
        specimen_data[:latitude]    =  seq_top.first_specimen_latitude
        specimen_data[:longitude]   =  seq_top.first_specimen_longitude


        return specimen_data
    end

    def _from_class_to_source_db(klass)
        if klass == BoldJob
            return "BOLD"
        elsif klass == NcbiGenbankJob
            return "GenBank"
        elsif klass == GbolJob
            return "GBOL"
        end
    end
end
