# frozen_string_literal: true

class OutputFormat::Comparison
    extend StringFormatting

    @@count = 0

    def self.write_to_file(file:, nomial:, accepted_taxon:, synonyms: nil, used_taxonomy: GbifTaxonomy)
        
        @@count += 1
        if @@count == 1
            file.puts "source_taxon_name\taccepted_taxon_name\taccepted_full_taxon_name\taccepted_taxonomic_status\tused_taxonomy\tsynonyms_for_accepted_taxon"
            return
        end
        source_taxon_name           = nomial.name
        accepted_taxon_name         = accepted_taxon.canonical_name
        accepted_full_taxon_name    = accepted_taxon.scientific_name
        accepted_taxonomic_status   = accepted_taxon.taxonomic_status
        

        synonyms_str = ''
        if synonyms
            synonyms_ary = []
            synonyms.each { |synonym| synonym.scientific_name.blank? || synonym.scientific_name.nil? ? synonyms_ary.push(synonym.canonical_name) : synonyms_ary.push(synonym.scientific_name) }
            synonyms_str = synonyms_ary.join(', ')
        end

        file.puts source_taxon_name + "\t" + accepted_taxon_name + "\t" + accepted_full_taxon_name + "\t" + accepted_taxonomic_status + "\t" + used_taxonomy.to_s + "\t" + synonyms_str
    end
  end

class OutputFormat::MergedComparison; end
