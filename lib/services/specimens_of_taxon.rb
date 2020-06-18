# frozen_string_literal: true

class SpecimensOfTaxon
    def self.generate(file_name:, query_taxon:, query_taxon_rank:)
        seqs_and_ids_by_taxon_name = Hash.new
        file                       = File.open(file_name, 'r')

        index_by_column_name       = generate_index_by_column_name(file: file)

        file.each do |row|
            specimen_data = row.scrub!.chomp.split("\t")
            fill_hash_with_seqs_and_ids(seqs_and_ids_by_taxon_name, specimen_data, index_by_column_name)
        end
        
        return seqs_and_ids_by_taxon_name
    end

    def self.generate_index_by_column_name(file:)
        column_names          =  file.first.chomp.split("\t")
        num_columns           = column_names.size
        index_by_column_name  = Hash.new
        (0...num_columns).each do |index|
            index_by_column_name[column_names[index]] = index
        end
    
        return index_by_column_name
    end

    def self.fill_hash_with_seqs_and_ids(seqs_and_ids_by_taxon_name, specimen_data, index_by_column_name)
        identifier    = specimen_data[index_by_column_name["processid"]]
        sequence      = specimen_data[index_by_column_name['nucleotides']]
        taxon_name    = find_lowest_ranking_taxon(specimen_data, index_by_column_name)
    
        if seqs_and_ids_by_taxon_name.has_key?(taxon_name)
            seqs_and_ids_by_taxon_name[taxon_name].push([identifier, sequence])
        else
            seqs_and_ids_by_taxon_name[taxon_name] = [[identifier, sequence]]
        end
    
        return seqs_and_ids_by_taxon_name
    end

    def self.find_lowest_ranking_taxon(specimen_data, index_by_column_name)
        _possible_taxa.each do |taxon|
          return specimen_data[index_by_column_name[taxon]] unless specimen_data[index_by_column_name[taxon]].blank?
          return nil if specimen_data[index_by_column_name[taxon]] == _possible_taxa.last
        end
    end

    def self._possible_taxa
        ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'phylum_name']
    end
end