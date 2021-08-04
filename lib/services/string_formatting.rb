# frozen_string_literal: true

module StringFormatting
    def _to_taxon_info_fasta(obj, divider: '|', last_divider: nil)
        return "#{obj.regnum}#{divider}#{obj.phylum}#{divider}#{obj.classis}#{divider}#{obj.ordo}#{divider}#{obj.familia}#{divider}#{obj.canonical_name}#{last_divider}"   if obj.taxon_rank == 'species' || obj.taxon_rank == 'genus' || obj.taxon_rank == 'unranked' || obj.taxon_rank == 'subspecies'
        return "#{obj.regnum}#{divider}#{obj.phylum}#{divider}#{obj.classis}#{divider}#{obj.ordo}#{divider}#{obj.canonical_name}#{last_divider}"                           if obj.taxon_rank == 'family'
        return "#{obj.regnum}#{divider}#{obj.phylum}#{divider}#{obj.classis}#{divider}#{obj.canonical_name}#{last_divider}"                                                if obj.taxon_rank == 'order'
        return "#{obj.regnum}#{divider}#{obj.phylum}#{divider}#{obj.canonical_name}#{last_divider}"                                                                        if obj.taxon_rank == 'class'
        return "#{obj.regnum}#{divider}#{obj.canonical_name}#{last_divider}"                                                                                               if obj.taxon_rank == 'phylum'
    end

    def _to_taxon_info_fasta_all_standard_ranks(obj, divider: '|', last_divider: nil)
        return "#{obj.regnum}#{divider}#{obj.phylum}#{divider}#{obj.classis}#{divider}#{obj.ordo}#{divider}#{obj.familia}#{divider}#{obj.genus}#{divider}#{obj.canonical_name}#{last_divider}" if obj.taxon_rank == 'species' || obj.taxon_rank == 'unranked' || obj.taxon_rank == 'subspecies'
        return "#{obj.regnum}#{divider}#{obj.phylum}#{divider}#{obj.classis}#{divider}#{obj.ordo}#{divider}#{obj.familia}#{divider}#{divider}#{obj.canonical_name}#{last_divider}"             if obj.taxon_rank == 'genus'
        return "#{obj.regnum}#{divider}#{obj.phylum}#{divider}#{obj.classis}#{divider}#{obj.ordo}#{divider}#{obj.canonical_name}#{last_divider}"                                               if obj.taxon_rank == 'family'
        return "#{obj.regnum}#{divider}#{obj.phylum}#{divider}#{obj.classis}#{divider}#{obj.canonical_name}#{last_divider}"                                                                    if obj.taxon_rank == 'order'
        return "#{obj.regnum}#{divider}#{obj.phylum}#{divider}#{obj.canonical_name}#{last_divider}"                                                                                            if obj.taxon_rank == 'class'
        return "#{obj.regnum}#{divider}#{obj.canonical_name}#{last_divider}"                                                                                                                   if obj.taxon_rank == 'phylum'
    end

    def _to_taxon_info_tsv(obj)
        return "#{obj.regnum}\t#{obj.phylum}\t#{obj.classis}\t#{obj.ordo}\t#{obj.familia}\t#{obj.canonical_name}" if obj.taxon_rank == 'species' || obj.taxon_rank == 'genus' || obj.taxon_rank == 'unranked' || obj.taxon_rank == 'subspecies'
        return "#{obj.regnum}\t#{obj.phylum}\t#{obj.classis}\t#{obj.ordo}\t\t#{obj.canonical_name}"               if obj.taxon_rank == 'family'
        return "#{obj.regnum}\t#{obj.phylum}\t#{obj.classis}\t\t\t#{obj.canonical_name}"                          if obj.taxon_rank == 'order'
        return "#{obj.regnum}\t#{obj.phylum}\t\t\t\t#{obj.canonical_name}"                                        if obj.taxon_rank == 'class'
        return "#{obj.regnum}\t\t\t\t\t#{obj.canonical_name}"                                                     if obj.taxon_rank == 'phylum'
    end

    def _to_taxon_info_tsv_all_standard_ranks(obj)
        return "#{obj.regnum}\t#{obj.phylum}\t#{obj.classis}\t#{obj.ordo}\t#{obj.familia}\t#{obj.genus}\t#{obj.canonical_name}" if obj.taxon_rank == 'species' || obj.taxon_rank == 'unranked' || obj.taxon_rank == 'subspecies'
        return "#{obj.regnum}\t#{obj.phylum}\t#{obj.classis}\t#{obj.ordo}\t#{obj.familia}\t#{obj.canonical_name}\t"             if obj.taxon_rank == 'genus'
        return "#{obj.regnum}\t#{obj.phylum}\t#{obj.classis}\t#{obj.ordo}\t#{obj.canonical_name}\t\t"                           if obj.taxon_rank == 'family'
        return "#{obj.regnum}\t#{obj.phylum}\t#{obj.classis}\t#{obj.canonical_name}\t\t\t"                                      if obj.taxon_rank == 'order'
        return "#{obj.regnum}\t#{obj.phylum}\t#{obj.canonical_name}\t\t\t\t"                                                    if obj.taxon_rank == 'class'
        return "#{obj.regnum}\t#{obj.canonical_name}\t\t\t\t\t"                                                                 if obj.taxon_rank == 'phylum'
    end

    def _to_taxon_info_qiime2_taxonomy(obj)
        species_name = obj.canonical_name.split(' ')[1]

        return "k__#{obj.regnum}; p__#{obj.phylum}; c__#{obj.classis}; o__#{obj.ordo}; f__#{obj.familia}; g__#{obj.genus}; s__#{species_name}"  if obj.taxon_rank == 'species' || obj.taxon_rank == 'unranked' || obj.taxon_rank == 'subspecies'
        return "k__#{obj.regnum}; p__#{obj.phylum}; c__#{obj.classis}; o__#{obj.ordo}; f__#{obj.familia}; g__#{obj.canonical_name}; s__"        if obj.taxon_rank == 'genus'
        return "k__#{obj.regnum}; p__#{obj.phylum}; c__#{obj.classis}; o__#{obj.ordo}; f__#{obj.canonical_name}; g__; s__"                      if obj.taxon_rank == 'family'
        return "k__#{obj.regnum}; p__#{obj.phylum}; c__#{obj.classis}; o__#{obj.canonical_name}; f__; g__; s__"                                 if obj.taxon_rank == 'order'
        return "k__#{obj.regnum}; p__#{obj.phylum}; c__#{obj.canonical_name}; o__; f__; g__; s__"                                               if obj.taxon_rank == 'class'
        return "k__#{obj.regnum}; p__#{obj.canonical_name}; c__; o__; f__; g__; s__"                                                            if obj.taxon_rank == 'phylum'
        return "k__#{obj.canonical_name}; p__; c__; o__; f__; g__; s__"                                                                         if obj.taxon_rank == 'kingdom'
    end

    def _tsv_header_all_standard_ranks
        "identifier\tkingdom\tphylum\tclass\torder\tfamily\tgenus\tspecies\tlocation\tlatitude\tlongitude\tsequence"
    end

    def _tsv_header
        # "identifier\tkingdom\tphylum\tclass\torder\tfamily\tgenus\tcanonical_name\tsequence"
        "identifier\tkingdom\tphylum\tclass\torder\tfamily\tcanonical_name\tlocation\tlatitude\tlongitude\tsequence"
    end

    def _tsv_row(lineage_data:, identifier:, sequence:, loc:, lat:, long:)
        # "#{identifier}\t#{lineage_data.regnum}\t#{lineage_data.phylum}\t#{lineage_data.classis}\t#{lineage_data.ordo}\t#{lineage_data.familia}\t#{lineage_data.genus}\t#{lineage_data.canonical_name}\t#{sequence}"
        # "#{identifier}\t#{_to_taxon_info_tsv(lineage_data)}\t#{loc}\t#{lat}\t#{long}\t#{sequence}"
        
        "#{identifier}\t#{_to_taxon_info_tsv(lineage_data)}\t#{loc}\t#{lat}\t#{long}\t#{sequence}"
    end

    def _tsv_row_all_standard_ranks(lineage_data:, identifier:, sequence:, loc:, lat:, long:)
        # "#{identifier}\t#{lineage_data.regnum}\t#{lineage_data.phylum}\t#{lineage_data.classis}\t#{lineage_data.ordo}\t#{lineage_data.familia}\t#{lineage_data.genus}\t#{lineage_data.canonical_name}\t#{sequence}"
        # "#{identifier}\t#{_to_taxon_info_tsv(lineage_data)}\t#{loc}\t#{lat}\t#{long}\t#{sequence}"
        
        "#{identifier}\t#{_to_taxon_info_tsv_all_standard_ranks(lineage_data)}\t#{loc}\t#{lat}\t#{long}\t#{sequence}"
    end

    def _fasta_header(data:, taxonomic_info:)
        ">#{data[:identifier]}|#{_to_taxon_info_fasta(taxonomic_info)}"
    end

    def _fasta_header_all_standard_ranks(data:, taxonomic_info:)
        ">#{data[:identifier]}|#{_to_taxon_info_fasta_all_standard_ranks(taxonomic_info)}"
    end

    def _fasta_header_qiime2_taxonomy(data:, taxonomic_info:)
        ">#{data[:identifier]}|#{_to_taxon_info_fasta(taxonomic_info, divider: ';', last_divider: ';')}"
    end

    ## Kraken2 headers are dependent on space therefore i have to change every space to
    ## _*_
    def _fasta_header_kraken2(data:, taxonomic_info:)
        changed_header = data[:identifier].gsub(' ', '_*_')
        ">#{changed_header}|kraken:taxid|#{taxonomic_info.taxon_id} #{_to_taxon_info_fasta(taxonomic_info)}"
    end

    # >Level1;Level2;Level3;Level4;Level5;Level6;
    ## TODO:
    # maybe implemnet identifier later, problem is all the ";" in GBOL 
    def _fasta_header_dada2_taxonomy(taxonomic_info:)
        ">#{_to_taxon_info_fasta_all_standard_ranks(taxonomic_info, divider: ';')}"
    end

    # >ID Genus species
    ## Dada Species headers are dependent on space therefore i have to change every space to
    ## _*_
    def _fasta_header_dada2_species(data:, taxonomic_info:)
        
        if taxonomic_info.taxon_rank == 'species' || taxonomic_info.taxon_rank == 'unranked' || taxonomic_info.taxon_rank == 'subspecies'
            changed_header = data[:identifier].gsub(' ', '_*_')
            
            return ">#{changed_header} #{taxonomic_info.canonical_name}"
        else
            return nil
        end

    end

    def _fasta_seq(data:)
        data[:sequence]
    end

    def _qiime2_taxonomy_row(taxonomic_info:, identifier:)
        "#{identifier}\t#{_to_taxon_info_qiime2_taxonomy(taxonomic_info)}"
    end
end
