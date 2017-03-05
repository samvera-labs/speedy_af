require 'active_fedora'
module ActiveFedora
  module Performance
    autoload :IndexedContent, 'active_fedora/performance/indexed_content'
    autoload :SolrPresenter, 'active_fedora/performance/solr_presenter'
    autoload :OrderedAggregationIndex, 'active_fedora/performance/ordered_aggregation_index'
  end
end
