module SpeedyAF
  module IndexedContent
    extend ActiveSupport::Concern

    included do
      after_save :update_external_index
    end

    def to_solr(solr_doc = {}, opts = {})
      return solr_doc unless opts[:external_index]
      solr_doc.tap do |doc|
        doc[:id] = id
        doc[:empty_bs] = empty?
        doc[:content_ss] = content
      end
    end

    def update_external_index
      ActiveFedora::SolrService.add(to_solr({}, external_index: true), softCommit: true)
    end
  end
end
