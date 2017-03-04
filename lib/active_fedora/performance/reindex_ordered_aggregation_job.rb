module ActiveFedora
  module Performance
    class ReindexOrderedAggregationJob < ActiveJob::Base
      queue_as :reindex
      def perform(id, name)
        ActiveFedora::Base.find(id, cast: true).send(:"reindex_ordered_#{name}!")
      end
    end
  end
end
