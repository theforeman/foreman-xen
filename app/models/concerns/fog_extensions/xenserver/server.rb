module FogExtensions
  module Xenserver
    module Server
      extend ActiveSupport::Concern

      include ActionView::Helpers::NumberHelper

      attr_accessor :start, :image_id, :hypervisor_host, :iso, :target_sr
      attr_accessor :memory_min, :memory_max, :builtin_template
      attr_writer :volumes, :interfaces

      def id
        uuid
      end

      def to_s
        name
      end

      def nics_attributes=(attrs); end

      def volumes_attributes=(attrs); end

      def volumes
        @volumes ||= []
        disks = vbds.compact.select(&:disk?)
        disks.sort! { |x, y| x.userdevice <=> y.userdevice }
        (disks.map(&:vdi) + @volumes).uniq
      end

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
        @interfaces ||= []
        (vifs + @interfaces).uniq
      end

      def select_nic(fog_nics, nic)
        fog_nics[0]
      end

      def user_data
        return !other_config['default_template'] if is_a_template

        false
      end
    end
  end
end
