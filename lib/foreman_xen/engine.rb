require 'fast_gettext'
require 'gettext_i18n_rails'
require 'fog/xenserver'

module ForemanXen
  # Inherit from the Rails module of the parent app (Foreman), not the plugin.
  # Thus, inherits from ::Rails::Engine and not from Rails::Engine
  class Engine < ::Rails::Engine
    engine_name 'foreman_xen'

    initializer 'foreman_xen.register_gettext', :after => :load_config_initializers do |app|
      locale_dir    = File.join(File.expand_path('../..', __dir__), 'locale')
      locale_domain = 'foreman-xen'

      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end

    initializer 'foreman_xen.register_plugin', :before => :finisher_hook do |app|
      Foreman::Plugin.register :foreman_xen do
        requires_foreman '>= 1.20'
        # Register xen compute resource in foreman
        compute_resource ForemanXen::Xenserver
        parameter_filter(ComputeResource, :uuid, :iso_library_mountpoint)
      end
    end

    assets_to_precompile =
      Dir.chdir(root) do
        Dir['app/assets/javascripts/**/*', 'app/assets/stylesheets/**/*'].map do |f|
          f.split(File::SEPARATOR, 4).last
        end
      end

    initializer 'foreman_xen.assets.precompile' do |app|
      app.config.assets.precompile += assets_to_precompile
    end

    initializer 'foreman_xen.configure_assets', group: :assets do
      SETTINGS[:foreman_xen] = { assets: { precompile: assets_to_precompile } }
    end

    config.to_prepare do
      begin
        # extend fog xen server and image models.
        require 'fog/xenserver/compute/models/server'
        require 'fog/xenserver/compute/models/host'
        require 'fog/xenserver/compute/models/vdi'
        require 'fog/xenserver/compute/models/storage_repository'
        require File.expand_path('../../app/models/concerns/fog_extensions/xenserver/server', __dir__)
        require File.expand_path('../../app/models/concerns/fog_extensions/xenserver/host', __dir__)
        require File.expand_path('../../app/models/concerns/fog_extensions/xenserver/vdi', __dir__)
        require File.expand_path('../../app/models/concerns/fog_extensions/xenserver/storage_repository', __dir__)
        require File.expand_path('../../app/models/concerns/foreman_xen/host_helper_extensions', __dir__)
        require File.expand_path('../../app/models/concerns/foreman_xen/host_extensions', __dir__)

        Fog::XenServer::Compute::Models::Server.include ::FogExtensions::Xenserver::Server
        Fog::XenServer::Compute::Models::Host.include ::FogExtensions::Xenserver::Host
        Fog::XenServer::Compute::Models::Vdi.include ::FogExtensions::Xenserver::Vdi
        Fog::XenServer::Compute::Models::StorageRepository.include ::FogExtensions::Xenserver::StorageRepository
        ::HostsHelper.include ForemanXen::HostHelperExtensions
        ::Host::Managed.prepend ForemanXen::HostExtensions
      rescue => e
        Rails.logger.warn "Foreman-Xen: skipping engine hook (#{e})"
      end
    end
  end
end
