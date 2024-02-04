module ForemanXen
  module HostExtensions
    extend ActiveSupport::Concern

    def built(installed = true)
      if compute_resource && compute_resource.type == 'ForemanXen::Xenserver'
        compute_resource.detach_cdrom(uuid)
        compute_resource.cleanup_configdrive(uuid)
      end
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
