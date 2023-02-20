file = File.open(ARGV[0], 'r')
file_removed_out = File.open("removed_seqs_with_no_taxon_info.tsv", 'w')

no_taxon_info = false
file.each do |line|
	line.chomp!
	if line =~ /^>/
		file_removed_out.puts if no_taxon_info
                no_taxon_info = false
	end
	if line =~ /(^>.*?)\|\|/
		new_header = $1
		if new_header !~ /\|/
 			no_taxon_info = true
			file_removed_out.print "#{line}\t#{new_header}\t"
		else
			puts new_header
		end
	else
	
		if no_taxon_info
			file_removed_out.print line	
		else
			puts line
		end
	end
end
