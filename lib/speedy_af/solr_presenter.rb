module SpeedyAF
  class SolrPresenter
    class NotAvailable < RuntimeError; end

    SOLR_ALL = 10_000_000

    attr_reader :attrs, :model

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

    def real?
      !@real_object.nil?
    end

    def respond_to_missing?(sym, _include_private = false)
      @attrs.key?(sym) ||
        model.reflections[sym].present? ||
        model.instance_methods.include?(sym)
    end

    def reload
      dup = self.class.find(id)
      @attrs = dup.attrs
      @model = dup.model
      @real_object = nil
      self
    end

    def method_missing(sym, *args)
      return real_object.send(sym, *args) if real?

      return @attrs[sym] if @attrs.key?(sym)
      reflection_name = reflection_name_for(sym)
      reflection = model.reflections[reflection_name] || model.reflections[:"#{reflection_name.to_s.singularize}_proxies"]
      unless reflection.nil?
        begin
          return load_from_reflection(reflection, sym.to_s =~ /_ids?$/)
        rescue NotAvailable => e
          model.logger.warn(e.message)
        end
      end
      if model.instance_methods.include?(sym)
        model.logger.warn("Reifying #{model} because #{sym} called from #{caller.first}")
        return real_object.send(sym, *args)
      end
      super
    end

    protected

      def reflection_name_for(sym)
        sym.to_s.sub(/_id(s?)$/, '\1').to_sym
      end

      def parse_solr_field(k, v)
        # :nocov:
        transforms = {
          'dt' => ->(m) { Time.parse(m) },
          'b'  => ->(m) { m == 'true' },
          'db' => ->(m) { m.to_f },
          'f'  => ->(m) { m.to_f },
          'i'  => ->(m) { m.to_i },
          'l'  => ->(m) { m.to_i },
          nil  => ->(m) { m }
        }
        # :nocov:
        attr_name, type, _stored, _indexed, _multi = k.scan(/^(.+)_(.+)(s)(i?)(m?)$/).first
        return [k, v] if attr_name.nil?
        value = Array(v).map { |m| transforms.fetch(type, transforms[nil]).call(m) }
        value = value.first unless multiple?(@model.properties[attr_name])
        [attr_name, value]
      end

      def multiple?(prop)
        prop.present? && prop.respond_to?(:multiple?) && prop.multiple?
      end

      def load_from_reflection(reflection, ids_only = false)
        if reflection.options.key?(:through)
          return load_through_reflection(reflection, ids_only)
        end
        if reflection.belongs_to? && reflection.respond_to?(:predicate_for_solr)
          return load_belongs_to_reflection(reflection.predicate_for_solr, ids_only)
        end
        if reflection.has_many? && reflection.respond_to?(:predicate_for_solr)
          return load_has_many_reflection(reflection.predicate_for_solr, ids_only)
        end
        if reflection.is_a?(ActiveFedora::Reflection::HasSubresourceReflection)
          return load_subresource_content(reflection)
        end
        # :nocov:
        raise NotAvailable, "`#{reflection.name}' cannot be quick-loaded. Falling back to model."
        # :nocov:
      end

      def load_through_reflection(reflection, ids_only = false)
        ids = case reflection.options[:through]
              when 'ActiveFedora::Aggregation::Proxy' then proxy_ids(reflection)
              else subresource_ids(reflection)
              end
        return ids if ids_only
        query = ActiveFedora::SolrQueryBuilder.construct_query_for_ids(ids)
        SolrPresenter.where(query, order: -> { ids })
      end

      def proxy_ids(reflection)
        docs = ActiveFedora::SolrService.query %(id:#{id}/#{reflection.name}/*), rows: SOLR_ALL
        docs.collect { |doc| doc['proxyFor_ssim'] }.flatten
      end

      def subresource_ids(reflection)
        subresource = reflection.options[:through]
        docs = ActiveFedora::SolrService.query %(id:"#{id}/#{subresource}"), rows: 1
        return [] if docs.empty?
        ids = docs.first['ordered_targets_ssim']
        return [] if ids.nil?
        ids
      end

      def load_belongs_to_reflection(predicate, ids_only = false)
        id = @attrs[predicate.to_sym]
        return id if ids_only
        SolrPresenter.find(id)
      end

      def load_has_many_reflection(predicate, ids_only = false)
        query = %(#{predicate}_ssim:#{id})
        return SolrPresenter.where(query) unless ids_only
        docs = ActiveFedora::SolrService.query query, rows: SOLR_ALL
        docs.collect { |doc| doc['id'] }
      end

      def load_subresource_content(reflection)
        subresource = reflection.name
        docs = ActiveFedora::SolrService.query %(id:"#{id}/#{subresource}"), rows: 1
        raise NotAvailable, "`#{subresource}' is not indexed" if docs.empty?
        resource = reflection.class_name.safe_constantize.new
        resource.uri = docs.first['uri_ss']
        resource.content = docs.first['content_ss']
        resource
      end
  end
end
