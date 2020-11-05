# frozen_string_literal: true

class GbolImporter
  include StringFormatting
  attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :fast_run, :query_taxon_name

  def self.get_source_lineage(row)
    OpenStruct.new(
      name:     row["Species"],
      combined: row['HigherTaxa'].split(', ')
    )
  end

  def initialize(file_name:, query_taxon_object:, fast_run: false)
    @file_name                = file_name
    @query_taxon_object       = query_taxon_object
    @query_taxon_name         = query_taxon_object.canonical_name
    @query_taxon_rank         = query_taxon_object.taxon_rank
    @fast_run                 = fast_run
  end

  ## change to Zip processing
  ## or unzip file to use csv
  def run
    specimens_of_taxon  = Hash.new { |hash, key| hash[key] = {} }
    file                = File.open(file_name, 'r')
    
    _csv_object.each do |row|
      _matches_query_taxon(row) ? nil : next if fast_run

      specimen = _get_specimen(row: row)
      next if specimen.sequence.nil? || specimen.sequence.empty?

      SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
    end

    tsv             = File.open("results3/#{query_taxon_name}_gbol_fast_#{fast_run}_output.tsv", 'w')
    fasta           = File.open("results3/#{query_taxon_name}_gbol_fast_#{fast_run}_output.fas", 'w')
    comparison_file = File.open("results3/#{query_taxon_name}_gbol_fast_#{fast_run}_comparison.tsv", 'w')
    
    specimens_of_taxon.keys.each do |taxon_name|
      nomial              = specimens_of_taxon[taxon_name][:nomial]
      first_specimen_info = specimens_of_taxon[taxon_name][:first_specimen_info]
      taxonomic_info      = nomial.taxonomy(first_specimen_info: first_specimen_info, importer: self.class)

      next unless taxonomic_info
      next unless taxonomic_info.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name

      # Synonym List
      syn = Synonym.new(accepted_taxon: taxonomic_info, sources: [GbifTaxon])
      OutputFormat::Comparison.write_to_file(file: comparison_file, nomial: nomial, accepted_taxon: taxonomic_info, synonyms: syn.synonyms)

      # OutputFormat::Synonyms.write_to_file(file: synonyms_file, accepted_taxon: syn.accepted_taxon, synonyms: syn.synonyms)

      specimens_of_taxon[taxon_name][:data].each do |data|
        OutputFormat::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
        OutputFormat::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
      end

    end
    OutputFormat::Tsv.rewind

    tsv.close
    fasta.close
    comparison_file.close
  end
  
  private
  def _get_specimen(row:)
    identifier                    = row["CatalogueNumber"]
    source_taxon_name             = row["Species"]
    sequence                      = row['BarcodeSequence']

    nomial                        = Nomial.generate(name: source_taxon_name, query_taxon_object: query_taxon_object, query_taxon_rank: query_taxon_rank)

    specimen                      = Specimen.new
    specimen.identifier           = identifier
    specimen.sequence             = sequence
    specimen.source_taxon_name    = source_taxon_name
    specimen.taxon_name           = nomial.name
    specimen.nomial               = nomial
    specimen.first_specimen_info  = row
    
    return specimen
  end

  def _csv_object
    CSV.new(_opened_file_in_read_mode, headers: true, col_sep: "\t", liberal_parsing: true)
  end

  def _opened_file_in_read_mode
    file = File.open(file_name, 'r')
  end

  def _matches_query_taxon(row)
    /#{query_taxon_name}/.match?(row["HigherTaxa"]) || /#{query_taxon_name}/.match?(row["Species"])
  end
end
