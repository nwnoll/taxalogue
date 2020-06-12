# frozen_string_literal: true

class NcbiDivision
    def self.info
        divisions = Hash.new
        path = 'data/NCBI/new_taxdump/division.dmp'
        if File.file?(path)
            file = File.open(path, 'r')
            file.each do |line|
                line.chomp!
                entries = line.scan(/\t?(.*?)\t\|/).flatten
                id = entries[0].to_i
                code = entries[1].downcase
                divisions[id] = code
            end
        end
        return divisions
    end

    def self.get_id(taxon_name:)
        ncbi_name_record = NcbiName.find_by_name(taxon_name)
		unless ncbi_name_record.nil? 
			ncbi_node_object = NcbiNode.find_by_tax_id(ncbi_name_record.tax_id)
			unless ncbi_node_object.nil?
				[ncbi_node_object.division_id]
			end
		end
    end
end