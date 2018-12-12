module ForemanXen
  module HostExtensions
    extend ActiveSupport::Concern

    def built(installed = true)
      compute_resource.cleanup_configdrive(uuid) if compute_resource && compute_resource.type == 'ForemanXen::Xenserver'
      super(installed)
    end

    def disassociate!
      # Disassociated host object cannot be saved unless provision_method
      # is supported by the default compute resource
      self.provision_method = 'build'
      super
    end
  end
end
