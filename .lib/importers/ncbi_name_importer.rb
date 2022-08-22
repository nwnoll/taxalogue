# frozen_string_literal: true

class NcbiNameImporter
	attr_reader :file_name, :file_manager
    
    NUM_RECORDS = 35_000

	def initialize(file_name:, file_manager:)
		@file_name		= file_name
		@file_manager	= file_manager
	end

	def run
		Zip::File.open(file_manager.file_path) do |zip_file|
			entry = zip_file.find_entry(file_name)
			name_records = []
			columns =[:tax_id, :name, :unique_name, :name_class]

			entry.get_input_stream do |input|
				input.each_line do |line|
					name = line.scan(/\t?(.*?)\t\|/).flatten
					name_records.push(name)
					if input.lineno % NUM_RECORDS == 0
						_batch_import(columns, name_records)
						name_records = []
					end
				end
				_batch_import(columns, name_records)
			end
		end
	end

	private
	def _batch_import(columns, records)
        puts "importing #{NUM_RECORDS} NCBI Name records"
		NcbiName.import columns, records, validate: false
	end
end
