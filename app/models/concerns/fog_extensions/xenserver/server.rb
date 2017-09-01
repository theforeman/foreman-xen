module FogExtensions
  module Xenserver
    module Server
      extend ActiveSupport::Concern

      include ActionView::Helpers::NumberHelper

      attr_accessor :start
      attr_accessor :image_id
      attr_accessor :memory_min, :memory_max, :custom_template_name, :builtin_template_name, :hypervisor_host

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

      def stop
        shutdown
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

      def vm_description
        format(_('%{cpus} CPUs and %{ram} memory'), :cpus => vcpus_max, :ram => number_to_human_size(memory_max.to_i))
      end

      def interfaces
        vifs
      end

      def select_nic(fog_nics, nic)
        fog_nics[0]
      end
    end
  end
end
