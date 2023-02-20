# frozen_string_literal: true

if ARGV.size < 3
    abort("Need fasta file name, discarded out name, and maximal number of allowed Ns")
end

file                = File.open(ARGV[0], 'r')
discarded_out       = File.open(ARGV[1], 'w')
max_N               = ARGV[2].to_i

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

seq_of.each do |key, value|
    
    if value.count('N') > max_N
        discarded_out.puts key
        discarded_out.puts value
        
        next
    end

    puts key
    puts value
end
