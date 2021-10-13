# frozen_string_literal: true

## If the taxonomy option "unmapped" is used there are some occasions where
## ranks do differ between different source databases but in fact do mean the same thing
## e.g. rank: kingdom Animalia <=> Metazoa
## or are inclusive e.g Hemiptera <=> Auchenorryncha 
## this is not changed directly since the whole point of the unmapped option is to retain
## the info without any mapping
## GBMND80252-21	Metazoa	Arthropoda	Insecta	Hemiptera	Cercopidae	Paracercopis	Paracercopis chekiangensis				ACATTATTATTATCAAGAAGAATAATTGACAATGGGGTAGGAACTGGTTGAACAGTTTATCCTCCATTATCAAGTAATATTGCTCATATAGGAGCATGTGTGGATATAGCTATTTTTTCATTACATTTAGCTGGAATTTCCTCAATCCTTGGAGCAGTAAATTTTATTACTACAATTCTTAATATACGATCTGTAGGTATAAATTTAGATCGAACTCCATTATTTGTGTGAGCTGTATTAATCACAGCAATTTTACTATTATTATCATTACCTGTTTTAGCAGGAGCTATTACAATATTGTTGACAGATCGAAATATTAATACATCATTCTTTGATCCTTCAGGTGGGGGAGACCCAATTTTATATCAACATTTATTTTGATTTTTTGGACACCCAGAAGTTTATATTTTGATTTTACCTGGATTTGGTTTAATTTCACATATTATTAGACAAGAAAGAGGAAAAAATGAATCATTTGGATCATTAAGAATAATTTATGCAATAACTACTATTGGTTTATTAGGATTTTTAGTATGAGCTCATCATATATTTACTGTAGGGATAGATGTTGATACGCGAGCGTATTTTACTTCGGCAACAATAATTATTGCAGTACCAACTGGTATCAAAATTTTTAGATGATTAGCTACTTTATACGGTATACCTATTAATATATCTTCATCAATTATATGATCTATTGGATTTGTATTTTTATTTACTATTGGAGGGTTAACAGGAGTTATTTTAGCAAATTCATCAATTGATATTATTTTACATGACACTTATTATGTAGTAGCTCATTTTCATTATGTTCTTTCTATAGGTGCAGTATTTGCTATTTTAGGAAGATTTATTCAATGATACCCTTTATTTACAGGTTTAACTCTTAATACA
## ZFMK-TIS-7514	Animalia	Hexapoda	Insecta	Auchenorrhyncha	Cercopidae	Cercopis	Cercopis vulnerata	Bayern, Germany, Greding	48.95	11.33	TACATTATATATACTATTTGGAATTTGATCAGGAATAACCGGAATAATTTTAAGTTTATTAATCCGTATAGAATTAGGACAACCAGGATCATTTATTGGAAATGATCAAATTTTTAATGTAATTGTAACTGCCCACGCTTTCATTATAATTTTTTTTATAGTTATACCCATTATAATTGGAGGTTTTGGAAACTGACTTGTACCAATTATAATTGGAGCTCCTGATATAGCATTTCCTCGAATAAATAATATAAGATTCTGAATATTACCACCATCTCTTACTTTACTATTGTCAAGAAGCTTAATTGATAACGGAGTAGGTACTGGATGAACTGTATATCCACCTTTATCAAGTGGAATTGCCCATTCTGGAGCTTGTGTAGATATAGCAATTTTTTCACTTCATTTAGCAGGTATTTCATCAATTTTAGGTGCTGTAAATTTTATTACAACAATCTTTAATATACGTTCAACTGGTATAAATCTTGATCGAATACCTTTATTTGTTTGAGCAGTTTTAATTACTGCAGTTTTACTTTTATTATCTTTACCAGTCTTGGCAGGTGCTATTACTATATTACTTACAGATCGAAACATTAACACATCTTTTTTTGATCCAGCTGGGGGAGGAGATCCCATTCTATATCAACATTTATTC

require 'csv'
require 'optparse'

params = {}
OptionParser.new do |opts|
    opts.banner = "Usage: ruby replace_taxon_name_for_rank.rb [options]"
    opts.set_summary_width 50

    opts.on("-f FILE", String, "--file_name", "File name of TSV file, where taxon names should be changed ") { |opt| params[:file_name] = opt }
    opts.on("-r FILE", String, "--replacement_file", "The replacement file has three columns: 1. taxon_rank, 2. taxon_to_replace, 3. taxon_to_use. Each row has to have all values specified. to get an example file where you could plug your own changes in please use the option --replacement_example. This file should be CSV file, the allowed column separators are: ',;\\t'") { |opt| params[:file_name] = opt }
    opts.on("-e", "--replacement_example", "Creates a example CSV file for replacements") { |opt| params["replacement_example"] = opt }

    opts.on("-k KINGDOM_TO_REPLACE", String, "--kingdom_to_replace", "Specify the name of the kingdom rank taxon to be changed" ) do |opt|
        opt = opt.split(',')
        params[:kingdom_to_replace] = opt
    end
    opts.on("-K KINGDOM_TO_USE", String, "--kingdom_to_use", "Specify the name of the kingdom rank taxon to be used" ) do |opt|
        opt = opt.split(',')
        params[:kingdom_to_use] = opt
    end


    opts.on("-p PHYLUM_TO_REPLACE", String, "--phylum_to_replace", "Specify the name of the phylum rank taxon to be changed" ) do |opt|
        opt = opt.split(',')
        params[:pyhlum_to_replace] = opt
    end

    opts.on("-P PHYLUM_TO_USE", String, "--phylum_to_use", "Specify the name of the phylum rank taxon to be used" ) do |opt|
        opt = opt.split(',')
        params[:pyhlum_to_use] = opt
    end


    opts.on("-c CLASS_TO_REPLACE", String, "--class_to_replace", "Specify the name of the class rank taxon to be changed" ) do |opt|
        opt = opt.split(',')
        params[:class_to_replace] = opt
    end

    opts.on("-C CLASS_TO_USE", String, "--class_to_use", "Specify the name of the class rank taxon to be used" ) do |opt|
        opt = opt.split(',')
        params[:class_to_use] = opt
    end


    opts.on("-o ORDER_TO_REPLACE", String, "--order_to_replace", "Specify the name of the order rank taxon to be changed" ) do |opt|
        opt = opt.split(',')
        params[:order_to_replace] = opt
    end

    opts.on("-O ORDER_TO_USE", String, "--order_to_use", "Specify the name of the order rank taxon to be used" ) do |opt|
        opt = opt.split(',')
        params[:order_to_use] = opt
    end


    opts.on("-f FAMILY_TO_REPLACE", String, "--family_to_replace", "Specify the name of the family rank taxon to be changed" ) do |opt|
        opt = opt.split(',')
        params[:family_to_replace] = opt
    end

    opts.on("-F FAMILY_TO_USE", String, "--family_to_use", "Specify the name of the family rank taxon to be used" ) do |opt|
        opt = opt.split(',')
        params[:family_to_use] = opt
    end


    opts.on("-g GENUS_TO_REPLACE", String, "--genus_to_replace", "Specify the name of the genus rank taxon to be changed" ) do |opt|
        opt = opt.split(',')
        params[:genus_to_replace] = opt
    end

    opts.on("-G GENUS_TO_USE", String, "--genus_to_use", "Specify the name of the genus rank taxon to be used" ) do |opt|
        opt = opt.split(',')
        params[:genus_to_use] = opt
    end


    opts.on("-s SPECIES_TO_REPLACE", String, "--species_to_replace", "Specify the name of the species rank taxon to be changed" ) do |opt|
        opt = opt.split(',')
        params[:species_to_replace] = opt
    end

    opts.on("-S SPECIES_TO_USE", String, "--species_to_use", "Specify the name of the species rank taxon to be used" ) do |opt|
        opt = opt.split(',')
        params[:species_to_use] = opt
    end

end.parse!

if params[:replacement_example]
    ## needs implementation
    abort "the option --replacement_example is not implemented yet "
end

if params[:replacement_file]
    ## needs implementation
    abort "the option --replacement_file is not implemented yet "
end

to_replace  = []
to_use      = []
replacement_of = Hash.new { |h,k| h[k] = Hash.new }
params.keys.each do |key|
    to_replace.push([$1, params[key].size]) if key =~ /(^.*?)_to_replace$/
    to_use.push([$1, params[key].size]) if key =~/(^.*?)_to_use$/
end

abort "Each taxon that should be replaced needs a taxon it should be replaced with" unless to_replace == to_use
abort "Please specify a file name" unless params[:file_name]

to_replace.each do |taxon_rank, changes_num|
    params["#{taxon_rank}_to_replace".to_sym].each_with_index do |name_to_replace, i|
        replacement_of[taxon_rank][name_to_replace] = params["#{taxon_rank}_to_use".to_sym][i]
    end
end

file    = File.open(params[:file_name], 'r')
csv     = CSV.open(file, liberal_parsing: true, col_sep: "\t", headers: true)

new_rows = []
csv.each do |row|

    new_row = []
    row.each do |key, value|
        new_row.push(value)
    end
    new_row_joined = new_row.join("\t")

    replacement_of.keys.each do |taxon_rank|
        if replacement_of[taxon_rank][row[taxon_rank]]
            new_row_joined.gsub!(row[taxon_rank], replacement_of[taxon_rank][row[taxon_rank]])
        end
    end
    
    new_rows.push(new_row_joined)
end

puts csv.headers.join("\t")
new_rows.each { |row| puts row }