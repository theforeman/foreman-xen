module FogExtensions
  module Xenserver
    module Host
      extend ActiveSupport::Concern

      included do
        attribute :display_name
        prepend FogExtensions::Xenserver::Host
      end

      def initialize(new_attributes = {})
        super(new_attributes)
        attributes[:display_name] = "#{name} - #{mem_free_gb} GB free memory"
      end

      def mem_free_gb
        return metrics.memory_free.to_i / 1024 / 1024 / 1024 if metrics

        0
      end
    end
  end
end
