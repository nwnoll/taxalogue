# frozen_string_literal: true

require 'optparse'
require 'pathname'
require 'ostruct'
require 'csv'

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  
  gem 'bio'
  #gem 'fuzzy-string-match', '~> 0.9.7'
  gem 'jaro_winkler'
  gem 'parallel'
end

require 'bio'
#require 'fuzzystringmatch'
require 'jaro_winkler'
require 'parallel'

## ARTRHOPODA_CONSENSUS_SEQ is a sequence from Aeshna specimen 
ARTHROPODA_CONSENSUS_SEQ    = "TLYFLFGAWSGMVGTALSVLIRIELGQPGSLIGDDQIYNVIVTAHAFVMIFFMVMPIMIGGFGNWLVPLMLGAPDMAFPRLNNMSFWLLPPSLTLLLAGSMVESGAGTGWTVYPPLAGAIAHAGASVDLTIFSLHLAGVSSILGAINFITTTINMKSPGMKMDQMPLFVWAVVITAVLLLLSLPVLAGAITMLLTDRNINTSFFDPAGGGDPILYQHLF"
ARTHROPODA_GENETIC_CODE     = 5
DISTANCE_TOLERANCE          = 0.05

params = {}
OptionParser.new do |opts|
    opts.set_summary_width 80

    opts.on('-i FASTA_INPUT', String, '--input')
    opts.on('-o FASTA_OUTPUT', String, '--output')
    opts.on('-c GENETIC_CODE', Integer, '--genetic_code')
    opts.on('-f FILTER_INFO', String,  '--filter_info')
    opts.on('-C CONSENSUS_PROTEIN_SEQ', String, '--consensus_seq')
    opts.on('-n NUM_CORES', Integer, '--num_cores')
end.parse!(into: params)

if params[:input].nil?
    abort("Need input file, please specify --input")
end

if params[:output].nil?
    abort("Need Output file, please specify --output")
end

params[:num_cores] = params[:num_cores] ? params[:num_cores] : 1
pp params

$consensus_seq  = params[:consensus_seq].nil? ? ARTHROPODA_CONSENSUS_SEQ : params[:consensus_seq]
$genetic_code   = params[:genetic_code].nil? ? ARTHROPODA_GENETIC_CODE : params[:genetic_code]

def get_reverse(str)
    return nil if str.nil?

    str.reverse
end

def get_complement(str)
    return nil if str.nil?

    str.tr('ACGTacgt', 'TGCATGCA')
end

def get_reverse_complement(str)
    return nil if str.nil?
    
    get_complement(get_reverse(str))
end

input 	= File.open(params[:input])

seq_of = Hash.new
header = nil
input.each do |line|
	line.chomp!
	if line =~ /^>/
		header = line
	else
		if seq_of.key?(header)
			seq_of[header] += line
		else
			seq_of[header] = line
		end
	end
end

def stop_codon_positions(aa)
    sc_indices = aa.enum_for(:scan, /(?=\*)/).map do
        Regexp.last_match.offset(0).first
    end

    return sc_indices
end

def nuc_to_aa(seq)
    nuc_seq = Bio::Sequence::NA.new(seq)
    return nil if nuc_seq.nil?

	prot_info = []
        (1..3).each do |frame|
	    begin
	      prot_seq = nuc_seq.translate(frame, $genetic_code)
	    rescue StandardError => e
	      break
	    end

            sc_indices = stop_codon_positions(prot_seq)
            sc_indices.delete(0)                            # stop codon at the beginning
            sc_indices.delete( (prot_seq.size - 1) )        # stop codon at the end

            distance_to_consensus = JaroWinkler.distance prot_seq, $consensus_seq
            prot_info = [prot_seq, distance_to_consensus, frame, sc_indices.size] if prot_info.length == 0 || distance_to_consensus > prot_info[1]
	end

    return prot_info
end

def get_prot_info(seq)
    fwd_prot_info = nuc_to_aa(seq)
    fwd_prot_info.push(nil)
    reverse = get_reverse_complement(seq)
    rev_prot_info = nuc_to_aa(reverse)
    rev_prot_info.push(reverse)

    return fwd_prot_info if fwd_prot_info[1] >= rev_prot_info[1]
    
    if rev_prot_info[1] > fwd_prot_info[1]
        return rev_prot_info if (rev_prot_info[1] - fwd_prot_info[1] ) > DISTANCE_TOLERANCE
        return rev_prot_info if (rev_prot_info[1] - fwd_prot_info[1] ) > (DISTANCE_TOLERANCE / 2) && rev_prot_info[3] < fwd_prot_info[3]
    end

    return fwd_prot_info
end

fasta_out   = File.open(params[:output], 'w') if params[:output]

output_files = []
filter_info_files = [] if params[:filter_info]

if params[:num_cores] == 1

    output_files.push(fasta_out)
else 
    params[:num_cores].times do |i|

        pno = Pathname.new(params[:output]).sub_ext("__o#{i}.tmp")
        fo = File.open(pno, 'w')
        output_files.push(fo)

        if params[:filter_info]
            pnf = Pathname.new(params[:filter_info]).sub_ext("__f#{i}.tmp")
            ff = File.open(pnf, 'w')
            filter_info_files.push(ff)
        end
    end
end


Parallel.map(seq_of.keys, in_processes: params[:num_cores] ) do |key|
    prot_info               = get_prot_info(seq_of[key])

    prot_seq                = prot_info.shift
    distance_to_consensus   = prot_info.shift
    frame                   = prot_info.shift
    sc_count                = prot_info.shift
    reverse_seq             = prot_info.shift
	
    discarded   = sc_count > 0      ? true : false
    reversed    = reverse_seq.nil?  ? false : true
    
    if params[:filter_info]
        
        filter_info_files[Parallel.worker_number].puts [key, discarded, reversed, seq_of[key], prot_seq, distance_to_consensus, sc_count, frame, reverse_seq, $consensus_seq].join("\t")
    end

    next if discarded

    if params[:output]
        output_files[Parallel.worker_number].puts key
        output_files[Parallel.worker_number].puts seq_of[key]
    end
end


if params[:filter_info]
    filter_info_out = File.open(params[:filter_info], 'w') 
    filter_info_out.puts "header\tdiscarded\treversed\tnuc_seq\tprot_seq\tdistance_to_consensus\tstop_codon_count\tframe\tnuc_reverse_complement_seq\tused_consensus_seq"
    filter_info_files.push(filter_info_out) if params[:num_cores] == 1
end

if params[:num_cores] != 1
    params[:num_cores].times do |i|

        if params[:filter_info]
            filter_info_files[i].close
            fn = filter_info_files[i].path
            content = File.open(fn, 'r').read
            filter_info_out.puts content
            FileUtils.rm(filter_info_files[i].path)
        end

        output_files[i].close
        fn = output_files[i].path
        content = File.open(fn, 'r').read
        fasta_out.puts content
        FileUtils.rm(output_files[i].path)
    end
end
        
    
    



