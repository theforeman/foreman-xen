module ForemanXen
  module HostHelperExtensions
    extend ActiveSupport::Concern

    def xen_host_title_actions(host)
      title_actions(
          button_group(
              link_to_if_authorized(_("Edit"), hash_for_edit_host_path(:id => host).merge(:auth_object => host),
                                    :title    => _("Edit your host")),
              if host.compute_resource_id
                link_to(_("Snapshots"), "../foreman_xen/snapshots/#{@host.id}/",
                        :title    => _("Manage machine snapshots"))
              end,
              if host.build
                link_to_if_authorized(_("Cancel build"), hash_for_cancelBuild_host_path(:id => host).merge(:auth_object => host, :permission => 'build_hosts'),
                                      :disabled => host.can_be_built?,
                                      :title    => _("Cancel build request for this host"))
              else
                link_to_if_authorized(_("Build"), hash_for_setBuild_host_path(:id => host).merge(:auth_object => host, :permission => 'build_hosts'),
                                      :disabled => !host.can_be_built?,
                                      :title    => _("Enable rebuild on next host boot"),
                                      :confirm  => _("Rebuild %s on next reboot?\nThis would also delete all of its current facts and reports") % host)
              end
          ),
          if host.compute_resource_id || host.bmc_available?
            button_group(
                link_to(_("Loading power state ..."), '#', :disabled => true, :id => :loading_power_state)
            )
          end,
          button_group(
              if host.try(:puppet_proxy)
                link_to_if_authorized(_("Run puppet"), hash_for_puppetrun_host_path(:id => host).merge(:auth_object => host, :permission => 'puppetrun_hosts'),
                                      :disabled => !Setting[:puppetrun],
                                      :title    => _("Trigger a puppetrun on a node; requires that puppet run is enabled"))
              end
          ),
          button_group(
              link_to_if_authorized(_("Delete"), hash_for_host_path(:id => host).merge(:auth_object => host, :permission => 'destroy_hosts'),
                                    :class => "btn btn-danger", :confirm => _('Are you sure?'), :method => :delete)
          )
      )
    end
    
  end
end
