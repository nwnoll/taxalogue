# frozen_string_literal: true

class NcbiNameImporter
	attr_reader :archive_name, :file_name

	def initialize(archive_name:, file_name:)
		@archive_name	= archive_name
		@file_name		= file_name
	end

	def run
		Zip::File.open(archive_name) do |zip_file|
			entry = zip_file.find_entry(file_name)
			name_records = []
			columns =[:tax_id, :name, :unique_name, :name_class]

			entry.get_input_stream do |input|
				input.each_line do |line|
					name = line.scan(/\t?(.*?)\t\|/).flatten
					name_records.push(name)
					if input.lineno % 100_000 == 0
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
		# NcbiName.import columns, records, validate: false
	end
end
