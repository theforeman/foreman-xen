module FogExtensions
  module Xenserver
    module StorageRepository
      extend ActiveSupport::Concern

      included do
        attribute :display_name
        prepend FogExtensions::Xenserver::StorageRepository
      end

      def initialize(new_attributes = {})
        super(new_attributes)
        attributes[:display_name] = init_display_name
      end

      def free_space
        physical_size.to_i - physical_utilisation.to_i
      end

      def free_space_gb
        free_space.to_i / 1024 / 1024 / 1024
      end

      def physical_size_gb
        physical_size.to_i / 1024 / 1024 / 1024
      end

      def physical_utilisation_gb
        physical_utilisation.to_i / 1024 / 1024 / 1024
      end

      def init_display_name
        srname = name
        unless shared
          pbd = pbds.first
          srname = "#{name} - #{pbd.host.name}" unless pbd.nil?
        end
        format('%{n} (%{f}: %{f_gb} GB - %{u}: %{u_gb} GB - %{t}: %{t_gb} GB)',
               n: srname, f: _('free'), f_gb: free_space_gb,
               u: _('used'), u_gb: physical_utilisation_gb,
               t: _('total'), t_gb: physical_size_gb)
      end
    end
  end
end
