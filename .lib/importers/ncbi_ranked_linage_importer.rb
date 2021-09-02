# frozen_string_literal: true

class NcbiRankedLineageImporter
	attr_reader :file_name, :file_manager

	def initialize(file_name:, file_manager:)
		@file_name		= file_name
		@file_manager	= file_manager
	end

	def run
		Zip::File.open(file_manager.file_path) do |zip_file|
			entry = zip_file.find_entry(file_name)
			lineage_records = []
			columns =[:tax_id, :name, :species, :genus, :familia,
					  :ordo, :classis, :phylum, :regnum, :super_regnum]
			entry.get_input_stream do |input|
				input.each_line do |line|
					lineage = line.scan(/\t?(.*?)\t\|/).flatten
					lineage_records.push(lineage)
					if input.lineno % 100_000 == 0
						_batch_import(columns, lineage_records)
						lineage_records = []
					end
				end
				_batch_import(columns, lineage_records)
			end
		end
	end

	private
	def _batch_import(columns, records)
		NcbiRankedLineage.import columns, records, validate: false
	end
end
