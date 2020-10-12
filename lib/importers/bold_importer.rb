# frozen_string_literal: true

class BoldImporter
  include StringFormatting
  attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :fast_run, :query_taxon_name

  @@index_by_column_name = nil
  def initialize(file_name:, query_taxon_object:, fast_run: true)
    @file_name                = file_name
    @query_taxon_object       = query_taxon_object
    @query_taxon_name         = query_taxon_object.canonical_name
    @query_taxon_rank         = query_taxon_object.taxon_rank
    @fast_run                 = fast_run
  end

  def run
    specimens_of_taxon    = Hash.new { |hash, key| hash[key] = {} }
    file                  = File.open(file_name, 'r')

    @@index_by_column_name = Helper.generate_index_by_column_name(file: file, separator: "\t")

    file.each do |row|
      _matches_query_taxon(row.scrub!) ? nil : next if fast_run

      scrubbed_row = row.scrub!.chomp.split("\t")

      specimen = _get_specimen(row: scrubbed_row)
      # specimen = Specimen.new
      # specimen.identifier   = specimen_data[index_by_column_name["processid"]]
      # nucs                  = specimen_data[index_by_column_name['nucleotides']]
      next if specimen.sequence.nil? || specimen.sequence.empty?

      # specimen.sequence     = nucs
      # specimen.taxon_name   = SpecimensOfTaxon.find_lowest_ranking_taxon(specimen_data, index_by_column_name)
      SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
    end

    tsv   = File.open("results2/#{query_taxon_name}_bold_fast_#{fast_run}_output_test.tsv", 'w')
    fasta = File.open("results2/#{query_taxon_name}_bold_fast_#{fast_run}_output_test.fas", 'w')


    specimens_of_taxon.keys.each do |taxon_name|
      nomial              = specimens_of_taxon[taxon_name][:nomial]
      first_specimen_info = specimens_of_taxon[taxon_name][:first_specimen_info]
      taxonomic_info      = nomial.taxonomy(first_specimen_info: first_specimen_info, importer: self.class)

      next unless taxonomic_info
      next unless taxonomic_info.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name

      specimens_of_taxon[taxon_name][:data].each do |data|
        OutputFormat::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
        OutputFormat::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
      end
    end
  end

  private

  def _get_specimen(row:)
    identifier  = row[@@index_by_column_name["processid"]]
    taxon_name  = SpecimensOfTaxon.find_lowest_ranking_taxon(row, @@index_by_column_name)
    sequence    = row[@@index_by_column_name['nucleotides']]

    nomial                        = Nomial.generate(name: taxon_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank)

    specimen                      = Specimen.new
    specimen.identifier           = identifier
    specimen.sequence             = sequence
    specimen.taxon_name           = nomial.name
    specimen.nomial               = nomial
    specimen.first_specimen_info  = row
    return specimen
  end

  def self.get_lineage(row)
    lineage_ary = SpecimensOfTaxon.create_lineage_ary(row, @@index_by_column_name)
    p lineage_ary
    lineage = Lineage.new(
      name: SpecimensOfTaxon.find_lowest_ranking_taxon(row, @@index_by_column_name),
      combined: lineage_ary
    )
  end

  def _matches_query_taxon(row)
    /#{query_taxon_name}/.match?(row)
  end
end