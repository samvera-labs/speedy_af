require 'active_fedora'
module ActiveFedora
  module Performance
    def self.active_job?
      Object.const_defined?(:ActiveJob)
    end
    autoload :SolrPresenter, 'active_fedora/performance/solr_presenter'
    autoload :OrderedAggregationIndex, 'active_fedora/performance/ordered_aggregation_index'
    if active_job?
      autoload :ReindexOrderedAggregationJob, 'active_fedora/performance/reindex_ordered_aggregation_job'
    end
  end
end
