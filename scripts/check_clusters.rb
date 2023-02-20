# frozen_string_literal: true

require 'optparse'
require 'pathname'

# MAX_SEQ_COUNT = 100

params = {}
OptionParser.new do |opts|
	opts.set_summary_width 80

	opts.on('-i FASTA_INPUT', '--input')
	opts.on('-o FASTA_OUTPUT', '--output')
	opts.on('-p INFO_OUTPUT', '--processing_output')
    opts.on('-r RATIO', Float, '--choose_by_resolution_and_count', 'Pick a ratio, when a Taxon information is considered as valid. E.g.: 2 means that the most abundant taxon name in the cluster has to be found twice as much as the next highest taxon name')
    opts.on('-M', '--lca_if_lineage_match')
    opts.on('-c', '--choose_by_count')
    opts.on('-l', '--choose_by_lca')
    opts.on('-t', '--choose_by_lowest_taxon_with_congruent_lineage')
    opts.on('-d', '--discard')
end.parse!(into: params)

## example run
## ruby get_clusters.rb -i input.fas -o output.fas -p processing_info.tsv --choose_by_lowest_taxon_with_congruent_lineage

if params[:input].nil?
    abort("Need input file, please specify --input")
end

if params[:output]
    output = File.open(params[:output], 'w')
end

if params[:processing_output]
    processing_output = File.open(params[:processing_output], 'w')
    processing_output.puts "identifier\tcluster\ttaxon_original\ttaxon_curated\tcount_original\tprocessing_method\tsequence"
end

file_path   = Pathname.new(params[:input])
file        = File.open(file_path, 'r')

seq_of_cluster  = Hash.new { |h,k| h[k] = Hash.new}
header  = nil
cluster = nil
# clusters = []
file.each do |line|
    line.chomp!
    if line =~ /^>(.*?)\|(.*)/
        cluster = $1
        header  = $2
        
        ## for testing
        # break if clusters.size == MAX_SEQ_COUNT
        # clusters.push(cluster) unless clusters.include?(cluster)
    else
        if seq_of_cluster[cluster].key?(header)
            seq_of_cluster[cluster][header] += line
        else
            seq_of_cluster[cluster][header] = line
        end
    end
end

seq_of_cluster.each do |cluster, seq_of|
    
    count_of = Hash.new(0)
    seq_of.each do |header, sequence|
        taxa = header.split('|')
        taxa.shift ## remove identifier

        count_of[taxa] += 1
    end

    count_of = count_of.sort_by do |key, value|
        [key.size, value]
    end.reverse.to_h

    top_taxa        = nil
    first_taxon     = true
    discard         = false
    sum_of_merged_lineage = Hash.new(0)
    count_of.each do |taxa_ary, count|
        if first_taxon
            top_taxa = taxa_ary
            first_taxon = false
            sum_of_merged_lineage[top_taxa] = count_of[top_taxa]

            next
        end
        sum_of_merged_lineage[taxa_ary] = count

        taxa_union      = (top_taxa | taxa_ary)
        taxa_intersect  = (top_taxa & taxa_ary)
        
        if params[:choose_by_resolution_and_count]
            
            next if taxa_union == top_taxa
        end

        if params[:choose_by_lowest_taxon_with_congruent_lineage]
            
            if taxa_union == top_taxa
                next
            else
                top_taxa = taxa_intersect
            end
        end

        if params[:choose_by_lca]
            top_taxa = taxa_intersect

            next
        end

        if params[:choose_by_count]
            top_taxa = taxa_ary if count > count_of[top_taxa]

            next
        end

        if params[:discard]
            discard = true
            
            break
        end
    end
    if params[:choose_by_resolution_and_count] && sum_of_merged_lineage.size > 1
        sum_of_merged_lineage.each do |taxa_ary, sum|
            sum_of_merged_lineage.each do |taxa_ary2, sum2|
                next if taxa_ary == taxa_ary2

                if taxa_ary == (taxa_ary | taxa_ary2)
                    sum_of_merged_lineage[taxa_ary] += sum2
                end
            end
        end

        sum_of_merged_lineage = sum_of_merged_lineage.sort_by {|key, value| value }.reverse.to_h

        if (sum_of_merged_lineage.values[0].to_f / sum_of_merged_lineage.values[1]) >= params[:choose_by_resolution_and_count]
            # top_taxa = "#{sum_of_merged_lineage.first[0].join(', ')}: #{sum_of_merged_lineage.first[1]}"
            top_taxa = sum_of_merged_lineage.keys[0]
        end
    end
    
    if params[:choose_by_lowest_taxon_with_congruent_lineage]
        seq_of.each do |header, sequence|
            next if top_taxa.nil?

            header              =~ /^(.*?)\|(.*)/
            identifier          = $1
            taxon_original      = $2
            processed_header    = ">#{identifier}\|#{top_taxa.join('|')}"

            if params[:processing_output]
                processing_output.puts "#{identifier}\t#{cluster}\t#{taxon_original}\t#{top_taxa.join('|')}\t#{count_of[taxon_original.split('|')]}\tchoose_by_lowest_taxon_with_congruent_lineage\t#{sequence}"
            end
    
            if params[:output]
                output.puts processed_header
                output.puts sequence
            else
                puts processed_header
                puts sequence
            end
        end
    end

end
