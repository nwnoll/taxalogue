# frozen_string_literal: true

class BoldImporter
  include StringFormatting
  attr_reader :file_name, :query_taxon_object, :query_taxon_rank, :fast_run, :query_taxon_name, :file_manager, :filter_params, :markers, :regexes_for_markers

  @@index_by_column_name = nil
  def initialize(file_name:, query_taxon_object:, fast_run: true, file_manager:, filter_params: nil, markers:)
    @file_name            = file_name
    @query_taxon_object   = query_taxon_object
    @query_taxon_name     = query_taxon_object.canonical_name
    @query_taxon_rank     = query_taxon_object.taxon_rank
    @fast_run             = fast_run
    @markers              = markers
    @regexes_for_markers  = Marker.regexes(db: self, markers: markers)
    @file_manager         = file_manager
    @filter_params        = filter_params
  end

  def run
    specimens_of_taxon    = Hash.new { |hash, key| hash[key] = {} }
    
    file                  = File.file?(file_name) ? File.open(file_name, 'r') : nil
    abort "#{file_name} is not a valid file" if file.nil?
    
    @@index_by_column_name = Helper.generate_index_by_column_name(file: file, separator: "\t")

    file.each do |row|
      _matches_query_taxon(row.scrub!) ? nil : next if fast_run

      scrubbed_row = row.scrub!.chomp.split("\t")

      specimen = _get_specimen(row: scrubbed_row)
      next if specimen.nil? || specimen.sequence.nil? || specimen.sequence.empty?

      SpecimensOfTaxon.fill_hash(specimens_of_taxon: specimens_of_taxon, specimen_object: specimen)
    end

    tsv             = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_bold_fast_#{fast_run}_output.tsv", OutputFormat::Tsv)
    fasta           = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_bold_fast_#{fast_run}_output.fas", OutputFormat::Fasta)
    comparison_file = file_manager.create_file("#{query_taxon_name}_#{file_name.basename('.*')}_bold_fast_#{fast_run}_comparison.tsv",   OutputFormat::Comparison)

    specimens_of_taxon.keys.each do |taxon_name|
      nomial              = specimens_of_taxon[taxon_name][:nomial]
      first_specimen_info = specimens_of_taxon[taxon_name][:first_specimen_info]
      taxonomic_info      = nomial.taxonomy(first_specimen_info: first_specimen_info, importer: self.class)

      next unless taxonomic_info
      next unless taxonomic_info.public_send(Helper.latinize_rank(query_taxon_rank)) == query_taxon_name

      # Synonym List
      syn = Synonym.new(accepted_taxon: taxonomic_info, sources: [GbifTaxonomy])

      OutputFormat::Comparison.write_to_file(file: comparison_file, nomial: nomial, accepted_taxon: taxonomic_info, synonyms: syn.synonyms)
      # OutputFormat::Synonyms.write_to_file(file: synonyms_file, accepted_taxon: syn.accepted_taxon, synonyms: syn.synonyms)
      

      specimens_of_taxon[taxon_name][:data].each do |data|
        OutputFormat::Tsv.write_to_file(tsv: tsv, data: data, taxonomic_info: taxonomic_info)
        OutputFormat::Fasta.write_to_file(fasta: fasta, data: data, taxonomic_info: taxonomic_info)
      end
    end

    tsv.close
    fasta.close
    comparison_file.close
  end

  private
  def _get_specimen(row:)
    identifier                    = row[@@index_by_column_name["processid"]]
    source_taxon_name             = SpecimensOfTaxon.find_lowest_ranking_taxon(row, @@index_by_column_name)
    sequence                      = row[@@index_by_column_name['nucleotides']]
    sequence                      = Helper.filter_seq(sequence, filter_params)
    marker                        = row[@@index_by_column_name["markercode"]]
    
    return nil unless _belongs_to_correct_marker?(marker)
    return nil if sequence.nil?

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

  def _belongs_to_correct_marker?(marker)
    regexes_for_markers === marker
  end

  def self.get_source_lineage(row)
    lineage_ary = SpecimensOfTaxon.create_lineage_ary(row, @@index_by_column_name)
    
    OpenStruct.new(
      name: SpecimensOfTaxon.find_lowest_ranking_taxon(row, @@index_by_column_name),
      combined: lineage_ary
    )
  end

  def _matches_query_taxon(row)
    /#{query_taxon_name}/.match?(row)
  end
end