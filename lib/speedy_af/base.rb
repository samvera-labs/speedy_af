# frozen_string_literal: true
require 'ostruct'

module SpeedyAF
  class Base
    class NotAvailable < RuntimeError; end

    SOLR_ALL = 10_000_000

    class_attribute :model_reflections, :reflection_predicates
    SpeedyAF::Base.model_reflections = { belongs_to: {}, has_many: {}, subresource: {} }
    SpeedyAF::Base.reflection_predicates = {}

    attr_reader :attrs, :model

    class << self
      def defaults
        @defaults ||= {}
      end

      def defaults=(value)
        raise ArgumentError unless value.respond_to?(:merge)
        @defaults = value
      end

      def proxy_class_for(model)
        klass = "::SpeedyAF::Proxy::#{model.name}".safe_constantize
        if klass.nil?
          namespace = model.name.deconstantize
          name = model.name.demodulize
          klass_module = namespace.split(/::/).inject(::SpeedyAF::Proxy) do |mod, ns|
            mod.const_defined?(ns, false) ? mod.const_get(ns, false) : mod.const_set(ns, Module.new)
          end
          klass = klass_module.const_set(name, Class.new(self))
        end
        klass
      end

      def config(model, &block)
        proxy_class = proxy_class_for(model) { Class.new(self) }
        proxy_class.class_eval(&block) if block_given?
      end

      def find(id, opts = {})
        where(%(id:"#{id}"), opts.merge(rows: 1)).first
      end

      def where(query, opts = {})
        docs = ActiveFedora::SolrService.query(query, rows: opts[:rows] || SOLR_ALL)
        from(docs, opts)
      end

      def for(doc, opts = {})
        proxy = proxy_class_for(model_for(doc))
        proxy.new(doc, opts[:defaults])
      end

      def from(docs, opts = {})
        hash = docs.each_with_object({}) do |doc, h|
          h[doc['id']] = self.for(doc, opts)
        end

        if opts[:load_reflections]
          reflections_hash = gather_reflections(hash, opts)
          reflections_hash.each { |parent_id, reflections| hash[parent_id].attrs.merge!(reflections) }
        end

        return hash.values if opts[:order].nil?
        opts[:order].call.collect { |id| hash[id] }.to_a
      end

      def model_for(solr_document)
        solr_document[:has_model_ssim].first.safe_constantize
      end

      protected

      def predicate_for_reflection(reflection)
        SpeedyAF::Base.reflection_predicates[reflection.name] ||= reflection.predicate_for_solr
      end

      def gather_reflections(proxy_hash, opts)
        query = [query_for_belongs_to(proxy_hash, opts), query_for_has_many(proxy_hash, opts), query_for_subresources(proxy_hash, opts)].reject(&:blank?).join(" OR ")
        docs = ActiveFedora::SolrService.query query, rows: SOLR_ALL

        reflections = {}
        reflections.deep_merge!(gather_belongs_to(docs, proxy_hash, opts))
        reflections.deep_merge!(gather_has_many(docs, proxy_hash, opts))
        reflections.deep_merge!(gather_subresources(docs, proxy_hash, opts))
        reflections
      end

      def query_for_belongs_to(proxy_hash, _opts)
        proxy_hash.collect do |_id, proxy|
          proxy.belongs_to_reflections.collect do |_name, reflection|
            id = proxy.attrs[predicate_for_reflection(reflection).to_sym]
            id.blank? ? nil : "id:#{id}"
          end.compact
        end.flatten.join(" OR ")
      end

      def gather_belongs_to(docs, proxy_hash, _opts)
        hash = {}
        proxy_hash.each do |proxy_id, proxy|
          proxy.belongs_to_reflections.each do |name, reflection|
            doc = docs.find { |d| d.id == proxy.attrs[predicate_for_reflection(reflection).to_sym] }
            next unless doc
            hash[proxy_id] ||= {}
            hash[proxy_id][name] = doc
            hash[proxy_id]["#{name}_id".to_sym] = doc.id
          end
        end
        hash
      end

      def query_for_has_many(proxy_hash, _opts)
        proxy_hash.collect do |id, proxy|
          proxy.has_many_reflections.collect { |_name, reflection| "#{predicate_for_reflection(reflection)}_ssim:#{id}" }
        end.flatten.join(" OR ")
      end

      def gather_has_many(docs, proxy_hash, _opts)
        hash = {}
        has_many_reflections = SpeedyAF::Base.model_reflections[:has_many].values.reduce(:merge)
        docs.each do |doc|
          has_many_reflections.each do |name, reflection|
            Array(doc["#{predicate_for_reflection(reflection)}_ssim"]).each do |proxy_id|
              next unless proxy_hash.key?(proxy_id)
              hash[proxy_id] ||= {}
              hash[proxy_id][name] ||= []
              hash[proxy_id][name] << doc
              hash[proxy_id]["#{name.to_s.singularize}_ids".to_sym] ||= []
              hash[proxy_id]["#{name.to_s.singularize}_ids".to_sym] << doc.id
            end
          end
        end
        hash
      end

      def query_for_subresources(proxy_hash, _opts)
        proxy_hash.collect do |id, proxy|
          proxy.subresource_reflections.collect { |name, _reflection| "id:#{id}/#{name}" }
        end.flatten.join(" OR ")
      end

      def gather_subresources(docs, proxy_hash, _opts)
        docs.each_with_object({}) do |doc, hash|
          doc_id = doc.id
          parent_id = proxy_hash.keys.find { |id| doc_id.start_with? id }
          next unless parent_id
          subresource_id = proxy_hash[parent_id].subresource_reflections.keys.find { |name| doc_id == "#{parent_id}/#{name}" }
          next unless subresource_id
          hash[parent_id] ||= {}
          hash[parent_id][subresource_id.to_sym] = doc
          hash[parent_id]["#{subresource_id}_id".to_sym] = doc_id
        end
      end
    end

    def initialize(solr_document, instance_defaults = {})
      instance_defaults ||= {}
      @model = Base.model_for(solr_document)
      @attrs = self.class.defaults.merge(instance_defaults)
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

    def reload
      dup = Base.find(id)
      @attrs = dup.attrs
      @model = dup.model
      @real_object = nil
      self
    end

    def to_query(key)
      "#{key}=#{id}"
    end

    def respond_to_missing?(sym, _include_private = false)
      @attrs.key?(sym) ||
        model.respond_to?(:reflections) && model.reflections[sym].present? ||
        model.instance_methods.include?(sym)
    end

    def method_missing(sym, *args)
      return real_object.send(sym, *args) if real?

      if @attrs.key?(sym)
        # Lazy convert the solr document into a speedy_af proxy object
        @attrs[sym] = SpeedyAF::Base.for(@attrs[sym]) if @attrs[sym].is_a?(ActiveFedora::SolrHit)
        @attrs[sym] = @attrs[sym].map { |doc| SpeedyAF::Base.for(doc) } if @attrs[sym].is_a?(Array) && @attrs[sym].all? { |d| d.is_a?(ActiveFedora::SolrHit) }
        return @attrs[sym]
      end

      reflection = reflection_for(sym)
      unless reflection.nil?
        begin
          return load_from_reflection(reflection, sym.to_s =~ /_ids?$/)
        rescue NotAvailable => e
          ActiveFedora::Base.logger.warn(e.message)
        end
      end

      if model.instance_methods.include?(sym)
        ActiveFedora::Base.logger.warn("Reifying #{model} because #{sym} called from #{caller.first}")
        return real_object.send(sym, *args)
      end
      super
    end

    def subresource_reflections
      SpeedyAF::Base.model_reflections[:subresource][model] ||= model.reflections.select { |_name, reflection| reflection.is_a? ActiveFedora::Reflection::HasSubresourceReflection }
    end

    # rubocop:disable Naming/PredicateName
    def has_many_reflections
      SpeedyAF::Base.model_reflections[:has_many][model] ||= model.reflections.select { |_name, reflection| reflection.has_many? && reflection.respond_to?(:predicate_for_solr) }
    end
    # rubocop:enable Naming/PredicateName

    def belongs_to_reflections
      SpeedyAF::Base.model_reflections[:belongs_to][model] ||= model.reflections.select { |_name, reflection| reflection.belongs_to? && reflection.respond_to?(:predicate_for_solr) }
    end

    protected

    def reflection_for(sym)
      return nil unless model.respond_to?(:reflections)
      reflection_name = sym.to_s.sub(/_id(s?)$/, '\1').to_sym
      model.reflections[reflection_name] || model.reflections[:"#{reflection_name.to_s.singularize}_proxies"]
    end

    def parse_solr_field(k, v)
      # :nocov:
      transforms = {
        'dt' => ->(m) { Time.parse(m) },
        'b' => ->(m) { m },
        'db' => ->(m) { m.to_f },
        'f' => ->(m) { m.to_f },
        'i' => ->(m) { m.to_i },
        'l' => ->(m) { m.to_i },
        nil => ->(m) { m }
      }
      # :nocov:
      attr_name, type, _stored, _indexed, _multi = k.scan(/^(.+)_(.+)(s)(i?)(m?)$/).first
      return [k, v] if attr_name.nil?
      value = Array(v).map { |m| transforms.fetch(type, transforms[nil]).call(m) }
      value = value.first unless @model.respond_to?(:properties) && multiple?(@model.properties[attr_name])
      [attr_name, value]
    end

    def multiple?(prop)
      prop.present? && prop.respond_to?(:multiple?) && prop.multiple?
    end

    def load_from_reflection(reflection, ids_only = false)
      return load_through_reflection(reflection, ids_only) if reflection.options.key?(:through)
      return load_belongs_to_reflection(reflection.predicate_for_solr, ids_only) if reflection.belongs_to? && reflection.respond_to?(:predicate_for_solr)
      return load_has_many_reflection(reflection.predicate_for_solr, ids_only) if reflection.has_many? && reflection.respond_to?(:predicate_for_solr)
      return load_subresource_content(reflection) if reflection.is_a?(ActiveFedora::Reflection::HasSubresourceReflection)
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
      Base.where(query, order: -> { ids })
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
      Base.find(id)
    end

    def load_has_many_reflection(predicate, ids_only = false)
      query = %(#{predicate}_ssim:#{id})
      return Base.where(query) unless ids_only
      docs = ActiveFedora::SolrService.query query, rows: SOLR_ALL
      docs.collect { |doc| doc['id'] }
    end

    def load_subresource_content(reflection)
      subresource = reflection.name
      docs = ActiveFedora::SolrService.query(%(id:"#{id}/#{subresource}"), rows: 1)
      raise NotAvailable, "`#{subresource}' is not indexed" if docs.empty? || !docs.first.key?('has_model_ssim')
      @attrs[subresource] = Base.from(docs).first
    end
  end
end
