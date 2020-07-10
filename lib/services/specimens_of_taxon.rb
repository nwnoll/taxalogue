# frozen_string_literal: true

class SpecimensOfTaxon
    def self.generate(file_name:, query_taxon:, query_taxon_rank:)
        seqs_and_ids_by_taxon_name = Hash.new
        file                       = File.open(file_name, 'r')

        index_by_column_name       = Helper.generate_index_by_column_name(file: file, separator: "\t")

        file.each do |row|
            specimen_data = row.scrub!.chomp.split("\t")
            fill_hash_with_seqs_and_ids(seqs_and_ids_by_taxon_name, specimen_data, index_by_column_name)
        end
        
        return seqs_and_ids_by_taxon_name
    end

    def self.fill_hash_with_seqs_and_ids(seqs_and_ids_by_taxon_name:, specimen_object:)
        if seqs_and_ids_by_taxon_name.has_key?(specimen_object.taxon_name)
            seqs_and_ids_by_taxon_name[specimen_object.taxon_name].push([specimen_object.identifier, specimen_object.sequence])
        else
            seqs_and_ids_by_taxon_name[specimen_object.taxon_name] = [[specimen_object.identifier, specimen_object.sequence]]
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