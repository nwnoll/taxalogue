# frozen_string_literal: true

class NcbiGenbankImporter
  include StringFormatting
  attr_reader :file_name, :query_taxon, :query_taxon_rank

  UNUSED_FIRST_LINES_NUM = 10

  def _possible_taxa
    ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'phylum_name']
  end

  def initialize(file_name:, query_taxon:, query_taxon_rank:)
    @file_name        = file_name
    @query_taxon      = query_taxon
    @query_taxon_rank = query_taxon_rank
  end


  def run
    file_names = Dir[ 'data/NCBI/sequences/*' ].select{ |f| File.file? f }
    file_names.each do |file|
      m = file.match(/gbinv\d+/)
      base_name = m[0]
      entry_of = Hash.new
      seqs_and_ids_by_taxon_name = Hash.new
      Zlib::GzipReader.open(file) do |gz_file|
        gb_entry = ''.dup
        count = 0
      	gz_file.each_line do |line|
          next if gz_file.lineno <= UNUSED_FIRST_LINES_NUM
          if line =~ /#{is_gb_entry_end}/
    				gb = Bio::GenBank.new(gb_entry)
            gb.each_gene do |gene|
              gene.qualifiers.each do |qualifier|
                gene_name = qualifier.value
                if qualifier.qualifier == 'gene'
                  if gene_name =~ /coi/i || gene_name =~ /co1/i || gene_name =~ /cox1/i  || gene_name =~ /cytochrome oxidase 1/i
                    specimen = Specimen.new
                    specimen.identifier = gb.accession
                    specimen.sequence   = gb.naseq.splicing(gene.position).to_s
                    specimen.taxon_name = gb.organism
                    SpecimensOfTaxon.fill_hash_with_seqs_and_ids(seqs_and_ids_by_taxon_name: seqs_and_ids_by_taxon_name, specimen_object: specimen)
                    count += 1
                    p count
                  end
                end
              end
            end
            break if count == 1000
            gb_entry = ''.dup
    			else
    				gb_entry.concat(line)
    		  end
        end
      end

      tsv   = File.open("results/#{query_taxon}_ncbi_#{base_name}_output.tsv", 'w')
      fasta = File.open("results/#{query_taxon}_ncbi_#{base_name}_output.fas", 'w')
    
      seqs_and_ids_by_taxon_name.keys.each do |taxon_name|
        nomial          = Nomial.generate(name: taxon_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)
        taxonomic_info  = nomial.taxonomy

        unless taxonomic_info
          puts "no tax_info #{species_name}"
          p nomial
          puts '-' * 100
          next
        end
        if taxonomic_info.public_send(GbifTaxon.rank_mappings["#{query_taxon_rank}"]) == query_taxon
          p taxonomic_info
          p taxonomic_info.canonical_name
          p query_taxon
          p query_taxon_rank
          puts '-' * 100
        end

        next unless taxonomic_info

        seqs_and_ids_by_taxon_name[taxon_name].each do |data|
          OutputFormat::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
          OutputFormat::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
        end
      end
    end
  end

  def is_gb_entry_end
    "^\/\/"
  end

  ## UNUSED
  def _lowest_rank(row, element_of)
    _possible_taxa.each do |t|
      return row[element_of[t]] unless row[element_of[t]].blank?
      return nil if row[element_of[t]] == _possible_taxa.last
    end
  end
end
