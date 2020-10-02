# frozen_string_literal: true

module StringFormatting
  def _header_gbif_taxon_object(taxon_name)
    _to_taxon_info(_gbif_taxon_object(taxon_name))
  end

  def _header_exact_gbif_api_result(taxon_name)
    _exact_gbif_api_accepted_taxon(taxon_name)
  end

  def _header_higher_ncbi_taxon_gbif_object(taxon_name)
    _to_taxon_info(_gbif_taxon_object(_ncbi_next_highest_taxa_name(taxon_name)))
  end

  def _to_taxon_info(obj)
    return "#{obj.regnum}|#{obj.phylum}|#{obj.classis}|#{obj.ordo}|#{obj.familia}|#{obj.canonical_name}" if obj.taxon_rank == 'species' || obj.taxon_rank == 'genus' || obj.taxon_rank == 'unranked' || obj.taxon_rank == 'subspecies'
    return "#{obj.regnum}|#{obj.phylum}|#{obj.classis}|#{obj.ordo}|#{obj.canonical_name}"                if obj.taxon_rank == 'family'
    return "#{obj.regnum}|#{obj.phylum}|#{obj.classis}|#{obj.canonical_name}"                            if obj.taxon_rank == 'order'
    return "#{obj.regnum}|#{obj.phylum}|#{obj.canonical_name}"                                           if obj.taxon_rank == 'class'
    return "#{obj.regnum}|#{obj.canonical_name}"                                                         if obj.taxon_rank == 'phylum'
  end

  def _tsv_header
    "identifier\tkingdom\tphylum\torder\tfamily\tgenus\tcanonical_name\tsequence"
  end

  def _tsv_row(lineage_data:, identifier:, sequence:)
    "#{identifier}\t#{lineage_data.regnum}\t#{lineage_data.phylum}\t#{lineage_data.classis}\t#{lineage_data.ordo}\t#{lineage_data.familia}\t#{lineage_data.genus}\t#{lineage_data.canonical_name}\t#{sequence}"
  end

  def _fasta_header(data:, taxonomic_info:)
    ">#{data[0]}|#{_to_taxon_info(taxonomic_info)}"
  end

  def _fasta_seq(data:)
    data[1]
  end
end
