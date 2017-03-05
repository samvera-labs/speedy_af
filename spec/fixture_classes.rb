class IndexedFile < ActiveFedora::File
  include ActiveFedora::Performance::IndexedContent
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
  include ActiveFedora::Performance::OrderedAggregationIndex

  has_subresource 'notes', class_name: 'IndexedFile'
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
