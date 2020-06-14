# frozen_string_literal: true

class Importer
  attr_reader :model, :column_mapping, :rows
  def initialize(model:, column_mapping:, rows:)
    @model = model
    @column_mapping = column_mapping
    @rows = rows
  end

  def run
    model.import columns, rows, validate: false
  end

  def db_import_columns
    model.column_names - ['id']
  end
end
