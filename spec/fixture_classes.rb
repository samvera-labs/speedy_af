class IndexedFile < ActiveFedora::File
  include SpeedyAF::IndexedContent
end

class Chapter < ActiveFedora::Base
  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end
  property :contributor, predicate: ::RDF::Vocab::DC.contributor, multiple: true do |index|
    index.as :stored_searchable
  end
end

class Book < ActiveFedora::Base
  include SpeedyAF::OrderedAggregationIndex

  belongs_to :library, predicate: ::RDF::Vocab::DC.isPartOf
  has_subresource 'indexed_file', class_name: 'IndexedFile'
  has_subresource 'unindexed_file', class_name: 'ActiveFedora::File'
  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end
  property :publisher, predicate: ::RDF::Vocab::DC.publisher, multiple: false do |index|
    index.as :stored_searchable
  end
  ordered_aggregation :chapters, through: :list_source
  indexed_ordered_aggregation :chapters

  def uppercase_title
    title.upcase
  end
end

class Library < ActiveFedora::Base
  has_many :books, predicate: ::RDF::Vocab::DC.isPartOf
end
