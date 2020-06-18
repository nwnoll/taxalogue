# frozen_string_literal: true

class NcbiNodeImporter
	attr_reader :archive_name, :file_name

	def initialize(archive_name:, file_name:)
		@archive_name	= archive_name
		@file_name		= file_name
	end

	def run
		Zip::File.open(archive_name) do |zip_file|
			entry = zip_file.find_entry(file_name)
			node_records = []
			columns =[	:tax_id, :parent_tax_id, :rank, :division_id, :genetic_code_id,
			:mito_genetic_code_id, :has_specified_species, :plastid_genetic_code_id]

			entry.get_input_stream do |input|
				input.each_line do |line|
					node = line.scan(/\t?(.*?)\t\|/).flatten
					node[13] == '1' ? node[13] = true : node[13] = false
					node = [node[0], node[1], node[2], node[4],
							node[6], node[8], node[13], node[15]]
					node_records.push(node)
					if input.lineno % 100_000 == 0
						_batch_import(columns, node_records)
						node_records = []
					end
				end
				_batch_import(columns, node_records)
			end
		end
	end

	private
	def _batch_import(columns, records)
		# NcbiNode.import columns, records, validate: false
	end
end
