module OrchestrationExtensions
  module Compute
    extend ActiveSupport::Concern

    included do
      def queue_compute_create

        queue.create(:name   => _("Render user data template for %s") % self, :priority => 1,
                     :action => [self, :setUserData]) if find_image.try(:user_data)
        queue.create(:name   => _("Set up compute instance %s") % self, :priority => 2,
                     :action => [self, :setCompute])
        queue.create(:name   => _("Acquire IP address for %s") % self, :priority => 3,
                     :action => [self, :setComputeIP]) if compute_provides?(:ip)
        queue.create(:name   => _("Query instance details for %s") % self, :priority => 4,
                     :action => [self, :setComputeDetails])
        template_type = compute_attributes['builtin_template_name'] == "" ? 'custom' : 'builtin'
        if template_type == 'builtin'
          templates = compute_resource.builtin_templates
          template = templates.find {|s| s.name == compute_attributes[:builtin_template_name]}
        else
          templates = compute_resource.custom_templates
          template = templates.find {|s| s.name == compute_attributes[:custom_template_name]}
        end
        queue.create(:name   => _("Setting kickstart details via PV_args for %s") % self, :priority => 5,
                       :action => [self, :setPVBootloader] ) if template.pv_bootloader != ""
        queue.create(:name   => _("Power up compute instance %s") % self, :priority => 1000,
                     :action => [self, :setComputePowerUp]) if compute_attributes[:start] == '1'
      end

      def setPVBootloader
        other_config = vm.other_config
        @host = self
        ks_url = foreman_url()
        vm.set_attribute 'PV_bootloader', 'eliloader'
        pv_args = vm.pv_args
        pv_args << " ks=#{ks_url}"
        vm.set_attribute 'PV_args', pv_args

        #Null the HVM just in case.
        vm.set_attribute 'HVM_boot_policy', ''
        other_config['install-repository'] = media_path.to_s
        other_config['install-methods'] = 'http'
        vm.set_attribute 'other_config', other_config
      end

      def delPVBootloader
        #Stub to avoid rollback errors
      end

    end
  end
end