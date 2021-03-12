# frozen_string_literal: true

module StringFormatting
  def _to_taxon_info(obj)
    return "#{obj.regnum}|#{obj.phylum}|#{obj.classis}|#{obj.ordo}|#{obj.familia}|#{obj.canonical_name}" if obj.taxon_rank == 'species' || obj.taxon_rank == 'genus' || obj.taxon_rank == 'unranked' || obj.taxon_rank == 'subspecies'
    return "#{obj.regnum}|#{obj.phylum}|#{obj.classis}|#{obj.ordo}|#{obj.canonical_name}"                if obj.taxon_rank == 'family'
    return "#{obj.regnum}|#{obj.phylum}|#{obj.classis}|#{obj.canonical_name}"                            if obj.taxon_rank == 'order'
    return "#{obj.regnum}|#{obj.phylum}|#{obj.canonical_name}"                                           if obj.taxon_rank == 'class'
    return "#{obj.regnum}|#{obj.canonical_name}"                                                         if obj.taxon_rank == 'phylum'
  end

  def _tsv_header
    # "identifier\tkingdom\tphylum\tclass\torder\tfamily\tgenus\tcanonical_name\tsequence"
    "identifier\tkingdom\tphylum\tclass\torder\tfamily\tcanonical_name\tlocation\tlatitude\tlongitude\tsequence"
  end

  def _tsv_row(lineage_data:, identifier:, sequence:, loc:, lat:, long:)
    # "#{identifier}\t#{lineage_data.regnum}\t#{lineage_data.phylum}\t#{lineage_data.classis}\t#{lineage_data.ordo}\t#{lineage_data.familia}\t#{lineage_data.genus}\t#{lineage_data.canonical_name}\t#{sequence}"
    "#{identifier}\t#{lineage_data.regnum}\t#{lineage_data.phylum}\t#{lineage_data.classis}\t#{lineage_data.ordo}\t#{lineage_data.familia}\t#{lineage_data.canonical_name}\t#{loc}\t#{lat}\t#{long}\t#{sequence}"
  end

  def _fasta_header(data:, taxonomic_info:)
    ">#{data[:identifier]}|#{_to_taxon_info(taxonomic_info)}"
  end

  def _fasta_seq(data:)
    data[:sequence]
  end
end
