# frozen_string_literal: true
module SpeedyAF
  module OrderedAggregationIndex
    extend ActiveSupport::Concern

    module ClassMethods
      def indexed_ordered_aggregation(name)
        target_class = reflections[name].class_name
        contains_key = reflections[:"ordered_#{name.to_s.singularize}_proxies"].options[:through]
        mixin = generated_association_methods
        mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
          def indexed_#{name}
            ids = self.indexed_#{name.to_s.singularize}_ids
            ids.lazy.collect { |id| #{target_class}.find(id) }
          end

          def indexed_#{name.to_s.singularize}_ids
            return [] unless persisted?
            docs = ActiveFedora::SolrService.query "id: \#{self.id}/#{contains_key}", rows: 1
            return [] if docs.empty? or docs.first['ordered_targets_ssim'].nil?
            docs.first['ordered_targets_ssim']
          end
        CODE
      end
    end
  end
end
