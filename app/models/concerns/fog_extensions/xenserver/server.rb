module FogExtensions
  module Xenserver
    module Server

      attr_accessor :memory_min, :memory_max, :custom_template_name, :builtin_template_name

      def to_s
        name
      end

      def nics_attributes=(attrs); end

      def volumes_attributes=(attrs); end

      def memory
        memory_static_max.to_i
      end

      def reset
        reboot
      end

      def ready?
        running?
      end

      def mac
        vifs.first.mac
      end

      def state
        power_state
      end

    end
  end
end
