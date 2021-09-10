# frozen_string_literal: true

class MultipleJobs
    attr_reader :jobs, :download_only, :params, :result_file_manager

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

        $seq_ids = Set.new# if params[:derep].any?
        
        jobs.each do |job|
            if job.class == BoldJob
                bold_dir = BoldDownloadCheckHelper.ask_user_about_download_dirs(params, only_successful = false)
            elsif job.class == GbolJob
                gbol_dir = GbolDownloadCheckHelper.ask_user_about_gbol_download_dirs(params)
            elsif job.class == NcbiGenbankJob
                ncbi_dir = NcbiDownloadCheckHelper.ask_user_about_download_dirs(params, only_successful = true)
            end
        end
    
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

        if params[:derep].any? { |opt| opt.last == true }
            seqs            = Sequence.where(id: $seq_ids)
            file_manager    = jobs.last.result_file_manager
            source_db_string = used_source_db_ary.size == 3 ? 'all' : used_source_db_ary.join('_')

            file_of = MiscHelper.create_output_files(
                file_manager: file_manager,
                query_taxon_name: params[:taxon_object].canonical_name,
                file_name: Pathname.new("derep"),
                params: params,
                source_db: source_db_string
            )

            seqs.each do |seq|
                if seq.taxon_object_proxies.size < 2
                    specimen_data = _create_specimen_data(seq, seq.sequence_taxon_object_proxies.first)
                    MiscHelper.write_to_files(
                        file_of: file_of,
                        taxonomic_info: seq.taxon_object_proxies.first,
                        nomial: seq.taxon_object_proxies.first.source_taxon_name,
                        params: params,
                        data: [specimen_data]
                    )

                    next
                end
                comparison_results_for = Hash.new

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

                same_comparison_results = []
                comparison_results_for.each do |taxon_object_proxy, comparison_result|
                    next if sorted.first == taxon_object_proxy

                    if comparison_results_for[sorted.first] == comparison_result
                        same_comparison_results.any? ? same_comparison_results.push(taxon_object_proxy) : same_comparison_results.push(sorted.first, taxon_object_proxy)
                    end
                end

                if same_comparison_results.any?
                    if params[:derep][:last_common_ancestor]
                        comparison_result   = comparison_results_for[sorted.first]
                        lca_rank_index      = comparison_result[1]
                        lca_rank            = GbifTaxonomy.rank_mappings.values[lca_rank_index]
                        taxon_name          = sorted.first.public_send(lca_rank)

                        
                        taxon_record        = TaxonHelper.get_taxon_record(params, taxon_name, automatic: true)
                        next if taxon_record.nil?
                        # pp sorted.first.sequence_taxon_object_proxies.find_by(sequence_id: seq.id)
                        # p taxon_record
                        # p seq.nucleotides
                        # puts

                        specimen_data = _create_specimen_data(seq, sorted.first.sequence_taxon_object_proxies.find_by(sequence_id: seq.id))
                        
                        MiscHelper.write_to_files(
                            file_of: file_of,
                            taxonomic_info: taxon_record,
                            nomial: sorted.first.source_taxon_name,
                            params: params,
                            data: [specimen_data]
                        )

                        next
                    elsif params[:derep][:random]
                        # pp sorted.first.sequence_taxon_object_proxies.find_by(sequence_id: seq.id)
                        # p sorted.first
                        # p seq.nucleotides
                        # puts

                        specimen_data = _create_specimen_data(seq, sorted.first.sequence_taxon_object_proxies.find_by(sequence_id: seq.id))
                        MiscHelper.write_to_files(
                            file_of: file_of,
                            taxonomic_info: sorted.first,
                            nomial: sorted.first.source_taxon_name,
                            params: params,
                            data: [specimen_data]
                        )

                        next
                    elsif params[:derep][:discard]
                        # maybe write it to extra file

                        next
                    end
                else
                    ## sorted.first is the best hit
                    specimen_data = _create_specimen_data(seq, sorted.first.sequence_taxon_object_proxies.find_by(sequence_id: seq.id))
                    MiscHelper.write_to_files(
                        file_of: file_of,
                        taxonomic_info: sorted.first,
                        nomial: sorted.first.source_taxon_name,
                        params: params,
                        data: [specimen_data]
                    )

                    next
                end
            end
        end

        puts
        MiscHelper.OUT_header "Output locations:"
        puts
        result_file_manager = nil
        count_cant_classify = 0
        results_of.each do |key, value|
            result_file_manager     = value.first
            download_file_managers  = value.last
            
            if value.last == :cant_classify
                count_cant_classify += 1
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

    def _create_specimen_data(seq, seq_top)
        specimen_data = Hash.new
        specimen_data[:identifier]  =  seq_top.first_specimen_identifier
        specimen_data[:sequence]    =  seq.nucleotides
        specimen_data[:location]    =  seq_top.first_specimen_location
        specimen_data[:latitude]    =  seq_top.first_specimen_latitude
        specimen_data[:longitude]   =  seq_top.first_specimen_longitude

        return specimen_data
    end
end