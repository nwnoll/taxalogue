# frozen_string_literal: true

class NcbiDivision
    def self.code_for
        divisions = Hash.new
        Zip::File.open('fm_data/NCBI_TAXONOMY/NCBI_TAXONOMY.zip') do |zip_file|
			entry = zip_file.find_entry('division.dmp')

			entry.get_input_stream do |input|
				input.each_line do |line|
                    entries = line.scan(/\t?(.*?)\t\|/).flatten
                    id = entries[0].to_i
                    code = entries[1].downcase
                    divisions[id] = code
				end
			end
        end
        return divisions
    end

    def self.get_division_id_by_taxon_name(taxon_name)
        # pp NcbiName.where(name: taxon_name)
        ncbi_name_record = NcbiName.find_by_name(taxon_name)
		unless ncbi_name_record.nil? 
			ncbi_node_object = NcbiNode.find_by_tax_id(ncbi_name_record.tax_id)
            unless ncbi_node_object.nil?
				[ncbi_node_object.division_id]
			end
		end
    end

    def self.get_division_id_by_taxon_id(taxon_id)
        ncbi_node_object = NcbiNode.find_by_tax_id(taxon_id)
        unless ncbi_node_object.nil?
            [ncbi_node_object.division_id]
        end
    end
end