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

    ## UNUSED
	def self.primer_to_regex(primer_seq)
		nucs_of = Hash.new

		nucs_of['A'] = 'A'
		nucs_of['C'] = 'C'
		nucs_of['G'] = 'G'
		nucs_of['T'] = 'T'
		nucs_of['R'] = '[AG]'
		nucs_of['Y'] = '[TC]'
		nucs_of['K'] = '[GT]'
		nucs_of['M'] = '[AC]'
		nucs_of['S'] = '[GC]'
		nucs_of['W'] = '[AT]'
		nucs_of['B'] = '[CGT]'
		nucs_of['D'] = '[AGT]'
		nucs_of['H'] = '[ACT]'
		nucs_of['V'] = '[ACG]'
		nucs_of['N'] = '[ACGT]'
		nucs_of['I'] = '[ACGT]'

		primer_regex_string_ary = []
		primer_seq.split('').each do |char|
			primer_regex_string_ary.push(nucs_of[char])
		end
		primer_regex_string = primer_regex_string_ary.join('')
		primer_regex = Regexp.new(primer_regex_string)

		return primer_regex
	end

    ## UNUSED
    def self.matches_seq?(primer_regex, seq)
        # seq.match?(/^#{primer_regex}|#{primer_regex}$/)
        seq.match?(/#{primer_regex}/)
    end

    ## UNUSED
    def self.one_mismatch(primer_seq)

        primer_ary = primer_seq.split('')
        mismatch_ary = []
        primer_ary.each_with_index do |char, i|
            ary_dup = primer_ary.dup
            ary_dup[i] = 'N'
            str = ary_dup.join('')
            mismatch_ary.push(str)
        end

        return mismatch_ary
    end

    ## UNUSED
    def self.two_mismatches(primer_seq)
        primer_ary = primer_seq.split('')
        mismatch_ary = []

        combinations = (0 .. (primer_seq.size - 1)).to_a.combination(2).to_a
        combinations.each do |positions|
            ary_dup = primer_ary.dup
            positions.each { |pos| ary_dup[pos] = 'N' }
            str = ary_dup.join('')
            mismatch_ary.push(str)
        end

        return mismatch_ary
    end

    ## UNUSED
    def self.get_primer_seqs_with_mismatches(primer_seq, mismatch_num)
        return nil unless primer_seq

        primer_ary = primer_seq.split('')
        primer_seqs_with_mismatches = []

        combinations = (0 .. (primer_seq.size - 1)).to_a.combination(mismatch_num).to_a
        combinations.each do |positions|
            primer_ary_dup = primer_ary.dup
            positions.each { |pos| primer_ary_dup[pos] = 'N' }
            primer_str = primer_ary_dup.join('')
            primer_seqs_with_mismatches.push(primer_str)
        end

        return primer_seqs_with_mismatches
    end

    ## UNUSED
    def self.get_regexes_for_primers(primers)
        primer_regexes = []
        primers.each do |primer|
            primer_regex = Helper.primer_to_regex(primer)
            primer_regexes.push(primer_regex)
        end

        return primer_regexes
    end
end