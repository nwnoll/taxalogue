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
      Zlib::GzipReader.open(file) do |gz_file|
    		gb_entry = ''.dup
      	gz_file.each_line do |line|
          next if gz_file.lineno <= UNUSED_FIRST_LINES_NUM
          if line =~ /#{gb_entry_end}/
    				gb = Bio::GenBank.new(gb_entry)
            gb.each_gene do |gene|
              gene.qualifiers.each do |qualifier|
                gene_name = qualifier.value
                if qualifier.qualifier == 'gene'
                  if gene_name =~ /coi/i || gene_name =~ /co1/i || gene_name =~ /cox1/i  || gene_name =~ /cytochrome oxidase 1/i
                    add_values(hash: entry_of, identifier: gb.accession, organism: gb.organism, sequence: gb.naseq.splicing(gene.position).to_s)
                  end
                end
              end
            end
            gb_entry = ''.dup
    			else
    				gb_entry.concat(line)
    		  end
        end
    	end
      _generate_outputs(entry_of, base_name)
    end
  end

  def gb_entry_end
    "^\/\/"
  end

  def add_values(hash:, identifier:, organism:, sequence:)
    if hash.has_key?(organism)
      hash[organism].push([identifier, sequence])
    else
      hash[organism] = [[identifier, sequence]]
    end
    return hash
  end

  def _lowest_rank(row, element_of)
    _possible_taxa.each do |t|
      return row[element_of[t]] unless row[element_of[t]].blank?
      return nil if row[element_of[t]] == _possible_taxa.last
    end
  end

  def _generate_outputs(specimen_data, base_name)
    tsv = File.open("results/ncbi_output_#{base_name}.tsv", 'w')
    tsv.puts _tsv_header

    fh_seqs_o = File.open("results/ncbi_seqs_#{base_name}.fas", 'w')
    specimen_data.keys.each do |species_name|
      nomial = Nomial.generate(name: species_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank)
      tax_info = nomial.taxonomy
      unless tax_info
        puts "no tax_info #{species_name}"
        p nomial
        puts '-' * 100
        next
      end
      if tax_info.public_send(GbifTaxon.rank_mappings["#{query_taxon_rank}"]) == query_taxon
        p tax_info
        p query_taxon
        p query_taxon_rank
        puts '-' * 100
      end

      count = 0
      specimen_data[species_name].each do |data|
        count += 1
        tsv.puts _tsv_row(identifier: data[0], lineage_data: tax_info, sequence: data[1])
        fh_seqs_o.puts ">#{data[0]}|#{_to_taxon_info(tax_info)}"
        fh_seqs_o.puts data[1]
      end
    end
  end
end
