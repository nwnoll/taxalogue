# frozen_string_literal: true

class NcbiNodeImporter

	def self.import(file_name)

		file = File.open(file_name, "r")

		node_records = []
		columns =[	:tax_id, :parent_tax_id, :rank, :division_id, :genetic_code_id,
					:mito_genetic_code_id, :has_specified_species, :plastid_genetic_code_id]

		file.each do |line|
			line.chomp!
			entries = line.scan(/\t?(.*?)\t\|/).flatten
			entries[13] == '1' ? entries[13] = true : entries[13] = false
			entries = [entries[0], entries[1], entries[2], entries[4],
					entries[6], entries[8], entries[13], entries[15]]

			node_records.push(entries)
			if file.lineno % 100_000 == 0
				puts '... importing 100k records'
				NcbiNode.import columns, node_records, validates: false
				node_records = []
			end
		end
		
		puts '... importing last few records'
		NcbiNode.import columns, node_records, validates: false
	end
end
