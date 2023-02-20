File.open(ARGV[0], 'r').each { |line| puts line.chomp!.match?(/^>/) ? line.gsub(' ', '_') : line }
