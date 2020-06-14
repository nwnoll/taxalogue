# frozen_string_literal: true

class NcbiRankedLineageImporter

	def self.import(file_name)

		file = File.open(file_name, "r")

    	lineage_records = []
		columns =[:tax_id, :name, :species, :genus, :familia,
							:ordo, :classis, :phylum, :regnum, :super_regnum]

    	file.each do |line|
      		line.chomp!
			entries = line.scan(/\t?(.*?)\t\|/).flatten
			lineage_records.push(entries)
			if file.lineno % 100_000 == 0
				puts '... importing 100k records'
				NcbiRankedLineage.import columns, lineage_records, validates: false
				lineage_records = []
			end
    end
		puts '... importing last few records'
		NcbiRankedLineage.import columns, lineage_records, validates: false
	end
end
