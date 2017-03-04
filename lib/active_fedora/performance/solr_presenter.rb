module ActiveFedora
  module Performance
    class SolrPresenter
      SOLR_ALL = 10_000_000

      def self.find(id, opts = {})
        where(%(id:"#{id}")).first
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
        @attrs = defaults.dup
        solr_document.each_pair do |k, v|
          attr_name, value = parse_solr_field(k, v)
          @attrs[attr_name.to_sym] = value          
        end

        @attrs.each_pair do |k, v|
          reflection = model.reflections[k.to_sym]
          next unless reflection.is_a?(ActiveFedora::Reflection::HasSubresourceReflection)
          resource = reflection.class_name.safe_constantize.new
          resource.content = v unless v.strip.empty?
          @attrs[k] = resource
        end
      end

      def model
        @attrs[:has_model].first.safe_constantize
      end

      def real_object
        @real_object ||= ActiveFedora::Base.find(id)
      end

      def respond_to_missing?(sym, _include_private = false)
        @attrs.key?(sym) ||
          model.reflections[sym].present? ||
          model.instance_methods.include?(sym)
      end

      def method_missing(sym, *args)
        return @attrs[sym] if @attrs.key?(sym)
        if model.reflections[sym]
          children = load_children(sym)
          return children unless children.nil?
        end
        if model.instance_methods.include?(sym)
          Rails.logger.warn("Reifying #{model} because #{sym} called from #{caller.first}")
          @attrs.clear!
          return real_object.send(sym, *args)
        end
        super
      end

      protected
        def parse_solr_field(k, v)
          transformations = { 
            b:  ->(m) { !!(m == 'true') },
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
          attr_name, type, _stored, _indexed, multi = k.scan(/^(.+)_(.+)(s)(i?)(m?)$/).first
          return [k, v] if attr_name.nil?
          value = Array(v).map { |m| transformations[type.to_sym].call(m) }
          value = value.first unless multi == 'm'
          [attr_name, value]
        end
        
        def load_children(property)
          parent_id_property = "#{has_model.underscore}_id".to_sym
          reflection = model.reflections[property.to_sym]
          return nil if reflection.nil?
          index_config = reflection.class_name.safe_constantize.index_config[parent_id_property]
          return nil if index_config.nil?
          self.class.from_parent(self, relation: index_config.key.to_sym)
        rescue
          nil
        end
    end
  end
end
