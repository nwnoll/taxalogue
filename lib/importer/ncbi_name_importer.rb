# frozen_string_literal: true

class NcbiNameImporter

	def self.import(file_name)

		file = File.open(file_name, "r")

		name_records = []
		columns =[:tax_id, :name, :unique_name, :name_class]

		file.each do |line|
			line.chomp!
			entries = line.scan(/\t?(.*?)\t\|/).flatten
			name_records.push(entries)
			if file.lineno % 100_000 == 0
				puts '... importing 100k records'
				NcbiName.import columns, name_records, validates: false
				name_records = []
			end
		end
		
		puts '... importing last few records'
		NcbiName.import columns, name_records, validates: false
	end
end
