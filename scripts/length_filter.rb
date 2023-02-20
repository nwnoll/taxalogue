# frozen_string_literal: true

if ARGV.size < 4
    abort("Need fasta file name, min length, max length, discarded file")
end

file        = File.open(ARGV[0], 'r')
min_length  = ARGV[1].to_i
max_length  = ARGV[2].to_i
discard_out = File.open(ARGV[3], 'w')
## seqs according to critera are put to stdout

seq_of  = Hash.new
header  = nil
file.each do |line|
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

discard_out.puts "header\tsequence\tlength"

seq_of.each do |key, value|
    seq_length = value.size

    if seq_length >= min_length && seq_length <= max_length
        puts key
        puts value
    else
        discard_out.puts "#{key}\t#{value}\t#{seq_length}"
    end
end