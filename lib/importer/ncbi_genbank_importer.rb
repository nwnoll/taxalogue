# frozen_string_literal: true

class NcbiGenbankImporter
  include OutputFormatting

  attr_reader :file_name, :query_taxon, :query_taxon_rank

  def _possible_taxa
    ['subspecies_name', 'species_name', 'genus_name', 'family_name', 'order_name', 'phylum_name']
  end

  def initialize(file_name:, query_taxon:, query_taxon_rank:)
    @file_name        = file_name
    @query_taxon      = query_taxon
    @query_taxon_rank = query_taxon_rank
  end

  def self.call(file_name:, query_taxon:, query_taxon_rank:)
    new(file_name: file_name, query_taxon: query_taxon, query_taxon_rank: query_taxon_rank).call
  end


  def call
    seqs = Dir[ 'data/GenBank/sequences/*' ].select{ |f| File.file? f }
    seqs.each do |s|
      m = s.match(/gbinv\d+/)
      source_file_name = m[0]
      next unless source_file_name == 'gbinv83'
      entry_of = Hash.new
    	Zlib::GzipReader.open(s) do |gz|
    		gb_entry = ''.dup
      	gz.each_line do |line|
    			next if gz.lineno <= 10
    			if line =~ /^\/\//
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
      _generate_outputs(entry_of, source_file_name)
    end
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

  def _generate_outputs(specimen_data, source_file_name)
    tsv = File.open("results/ncbi_output_#{source_file_name}.tsv", 'w')
    tsv.puts _tsv_header

    fh_seqs_o = File.open("results/ncbi_seqs_#{source_file_name}.fas", 'w')
    specimen_data.keys.each do |species_name|
      # byebug if species_name == 'Abax parallelus'
      # puts "species_name: #{species_name}"
      # next unless species_name == 'Tripteroides (Tripteroides) complex sp. 2 MTM-2019'
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
