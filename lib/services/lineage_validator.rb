# frozen_string_literal: true

class LineageValidator
  attr_reader :backbone_lineage, :specimen_lineage

  def initialize(backbone_lineage:, specimen_lineage:)
    @backbone_lineage = backbone_lineage
    @specimen_lineage = specimen_lineage
  end

  def call
    (backbone_lineage & specimen_lineage).size >= 2 ? true : false
  end
end
