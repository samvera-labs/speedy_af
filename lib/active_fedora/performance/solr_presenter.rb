module ActiveFedora
  module Performance
    class SolrPresenter
      class NotAvailable < Exception; end

      SOLR_ALL = 10_000_000

      attr_reader :model

      def self.find(id, opts = {})
        where(%(id:"#{id}"), opts).first
      end

      def self.where(query, opts = {})
        docs = ActiveFedora::SolrService.query(query, rows: SOLR_ALL)
        from(docs, opts)
      end

      def self.from(docs, opts = {})
        hash = docs.each_with_object({}) { |doc, h| h[doc['id']] = new(doc, opts[:defaults]) }
        return hash.values if opts[:order].nil?
        opts[:order].call.collect { |id| hash[id] }.to_a
      end

      def initialize(solr_document, defaults = {})
        defaults ||= {}
        @model = solr_document[:has_model_ssim].first.safe_constantize
        @attrs = defaults.dup
        solr_document.each_pair do |k, v|
          attr_name, value = parse_solr_field(k, v)
          @attrs[attr_name.to_sym] = value
        end
      end

      def real_object
        if @real_object.nil?
          @real_object = model.find(id)
          @attrs.clear
        end
        @real_object
      end

      def respond_to_missing?(sym, _include_private = false)
        @attrs.key?(sym) ||
          model.reflections[sym].present? ||
          model.instance_methods.include?(sym)
      end

      def method_missing(sym, *args)
        return @attrs[sym] if @attrs.key?(sym)
        reflection = model.reflections[sym] || model.reflections[:"#{sym.to_s.singularize}_proxies"]
        unless reflection.nil?
          begin
            result = load_from_reflection(reflection)
            return result unless result.nil?
          rescue NotAvailable => e
            ActiveFedora.logger.warn(e.message)
          end
        end
        if model.instance_methods.include?(sym)
          ActiveFedora.logger.warn("Reifying #{model} because #{sym} called from #{caller.first}")
          return real_object.send(sym, *args)
        end
        super
      end

      protected

        def parse_solr_field(k, v)
          transformations = {
            b:  ->(m) { m == 'true' },
            db: ->(m) { m.to_f },
            dt: ->(m) { Time.parse(m) },
            f:  ->(m) { m.to_f },
            i:  ->(m) { m.to_i },
            l:  ->(m) { m.to_i },
            s:  ->(m) { m },
            t:  ->(m) { m },
            te: ->(m) { m },
            ti: ->(m) { m }
          }
          attr_name, type, _stored, _indexed, _multi = k.scan(/^(.+)_(.+)(s)(i?)(m?)$/).first
          return [k, v] if attr_name.nil?
          value = Array(v).map { |m| transformations[type.to_sym].call(m) }
          value = value.first unless multiple?(@model.properties[attr_name])
          [attr_name, value]
        end

        def multiple?(prop)
          prop.present? && prop.respond_to?(:multiple?) && prop.multiple?
        end

        def load_from_reflection(reflection)
          if reflection.options.key?(:through)
            return load_indexed_reflection(reflection.options[:through])
          end
          if reflection.belongs_to? && reflection.respond_to?(:predicate_for_solr)
            return load_belongs_to_reflection(reflection.predicate_for_solr)
          end
          if reflection.has_many? && reflection.respond_to?(:predicate_for_solr)
            return load_has_many_reflection(reflection.predicate_for_solr)
          end
          if reflection.kind_of?(ActiveFedora::Reflection::HasSubresourceReflection)
            return load_subresource_content(reflection)
          end
          []
        end

        def load_indexed_reflection(subresource)
          docs = ActiveFedora::SolrService.query %(id:"#{id}/#{subresource}"), rows: 1
          return [] if docs.empty?
          ids = docs.first['ordered_targets_ssim']
          return [] if ids.nil? || ids.empty?
          query = ActiveFedora::SolrQueryBuilder.construct_query_for_ids(ids)
          SolrPresenter.where(query, order: ->{ids})
        end

        def load_belongs_to_reflection(predicate)
          id = @attrs[predicate.to_sym]
          SolrPresenter.find(id)
        end

        def load_has_many_reflection(predicate)
          query = %(#{predicate}_ssim:#{id})
          SolrPresenter.where(query)
        end

        def load_subresource_content(reflection)
          subresource = reflection.name
          docs = ActiveFedora::SolrService.query %(id:"#{id}/#{subresource}"), rows: 1
          raise NotAvailable, "`#{subresource}' is not indexed" if docs.empty?
          resource = reflection.class_name.safe_constantize.new
          resource.content = docs.first['content_ss']
          resource
        end
    end
  end
end
