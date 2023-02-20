# frozen_string_literal: true

if ARGV.size < 1
    abort("Need fasta file name, discarded out name, and maximal number of allowed Ns")
end

require 'pathname'

dir         = Pathname.new(ARGV[0])
files       = dir.glob('*')
out_file    = File.open("#{dir}_concat.fas", 'w')
seq_of      = Hash.new

files.each do |file_name|
    file = File.open(file_name, 'r')

    header  = nil
    file.each do |line|
        line.chomp!
        if line =~ /^>(.*)/
            header = ">#{file_name.basename}|#{$1}"
        else
            if seq_of.key?(header)
                seq_of[header] += line
            else
                seq_of[header] = line
            end
        end
    end
end

seq_of.each do |key, value|
    out_file.puts key
    out_file.puts value
end
