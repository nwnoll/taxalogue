# frozen_string_literal: true

class FilterHelper
    def self.filter_seq(seq, criteria)
    
        seq = seq.dup
        seq.upcase!
    
        return nil if seq =~ /[^ACGTN-]/
    
        start_pos = _get_char_pos(seq)
        end_pos   = (seq.size - _get_char_pos(seq.reverse) - 1)
        seq       = seq[start_pos..end_pos]
    
        return seq unless criteria
    
        if criteria[:max_N]
            return nil if seq.count('N') > criteria[:max_N]
        end
    
        if criteria[:max_G]
            return nil if seq.count('-') > criteria[:max_G]
        end
    
        seq_length = seq.size
        if criteria[:min_length]
            return nil if seq_length < criteria[:min_length]
        end
    
        if criteria[:max_length]
            return nil if seq_length > criteria[:max_length]
        end
    
        return seq
    end

    def self._get_char_pos(seq)
        char_pos = 0
        # char_pos_to_start = 0
    
        seq.each_char do |char|
            if char =~ /[ACGT]/
                return char_pos
            end
    
            char_pos += 1
        end
    
        return 0
    end
    ## TODO: Subgenus?
    def self.has_taxon_tank(rank:, taxonomic_info:)
        if rank == 'species'
            return true if taxonomic_info.taxon_rank == 'species' || taxonomic_info.taxon_rank == 'unranked' || taxonomic_info.taxon_rank == 'subspecies'
        elsif rank == 'genus'
            return true if taxonomic_info.taxon_rank == 'species' || taxonomic_info.taxon_rank == 'unranked' || taxonomic_info.taxon_rank == 'subspecies'
            return true if taxonomic_info.taxon_rank == 'genus'
        elsif rank == 'family'
            return true if taxonomic_info.taxon_rank == 'species' || taxonomic_info.taxon_rank == 'unranked' || taxonomic_info.taxon_rank == 'subspecies'
            return true if taxonomic_info.taxon_rank == 'genus'
            return true if taxonomic_info.taxon_rank == 'family'
        elsif rank == 'order'
            return true if taxonomic_info.taxon_rank == 'species' || taxonomic_info.taxon_rank == 'unranked' || taxonomic_info.taxon_rank == 'subspecies'
            return true if taxonomic_info.taxon_rank == 'genus'
            return true if taxonomic_info.taxon_rank == 'family'
            return true if taxonomic_info.taxon_rank == 'order'
        elsif rank == 'class'
            return true if taxonomic_info.taxon_rank == 'species' || taxonomic_info.taxon_rank == 'unranked' || taxonomic_info.taxon_rank == 'subspecies'
            return true if taxonomic_info.taxon_rank == 'genus'
            return true if taxonomic_info.taxon_rank == 'family'
            return true if taxonomic_info.taxon_rank == 'order'
            return true if taxonomic_info.taxon_rank == 'class'
        elsif rank == 'phylum'
            return true if taxonomic_info.taxon_rank == 'species' || taxonomic_info.taxon_rank == 'unranked' || taxonomic_info.taxon_rank == 'subspecies'
            return true if taxonomic_info.taxon_rank == 'genus'
            return true if taxonomic_info.taxon_rank == 'family'
            return true if taxonomic_info.taxon_rank == 'order'
            return true if taxonomic_info.taxon_rank == 'class'
            return true if taxonomic_info.taxon_rank == 'phylum'
        elsif rank == 'kingdom'
            return true if taxonomic_info.taxon_rank == 'species' || taxonomic_info.taxon_rank == 'unranked' || taxonomic_info.taxon_rank == 'subspecies'
            return true if taxonomic_info.taxon_rank == 'genus'
            return true if taxonomic_info.taxon_rank == 'family'
            return true if taxonomic_info.taxon_rank == 'order'
            return true if taxonomic_info.taxon_rank == 'class'
            return true if taxonomic_info.taxon_rank == 'phylum'
            return true if taxonomic_info.taxon_rank == 'kingdom'
        end

        return false
    end
end