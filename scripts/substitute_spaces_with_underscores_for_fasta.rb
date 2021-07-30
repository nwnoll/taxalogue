# frozen_string_literal: true

file_name   = ARGV[0]
file        = File.open(file_name, 'r')

header = nil
seq_of = Hash.new
file.each do |line|
    line.chomp!
    if line =~ /^>/
        header = line.gsub(' ', '_')
    else
        seq_of.key?(header) ? seq_of[header] += line : seq_of[header] = line
    end
end

seq_of.each { |k, v| puts "#{k}\n#{v}"}
