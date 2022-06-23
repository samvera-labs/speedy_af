# frozen_string_literal: true
module SpeedyAF
  module IndexedContent
    extend ActiveSupport::Concern
    MAX_CONTENT_SIZE = 8192

    included do
      after_save :update_external_index
    end

    def to_solr(solr_doc = {}, opts = {})
      return solr_doc unless opts[:external_index]
      solr_doc.tap do |doc|
        doc[:id] = id
        doc[:has_model_ssim] = self.class.name
        doc[:uri_ss] = uri.to_s
        doc[:mime_type_ss] = mime_type
        doc[:original_name_ss] = original_name
        doc[:size_is] = content.present? ? content.size : 0
        doc[:'empty?_bs'] = content.blank?
        doc[:content_ss] = content if index_content?
      end
    end

    def update_external_index
      ActiveFedora::SolrService.add(to_solr({}, external_index: true), softCommit: true)
    end

    protected

    def index_content?
      has_content? && mime_type =~ /(^text\/)|([\/\+]xml$)/ && size < MAX_CONTENT_SIZE && content !~ /\x00/
    end
  end
end
