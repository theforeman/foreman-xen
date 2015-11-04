module ForemanXen
  module HostHelperExtensions
    extend ActiveSupport::Concern

    included do
      alias_method_chain :host_title_actions, :xen_snap_button
    end

    def host_title_actions_with_xen_snap_button(*args)
      unless @host.compute_resource.nil?
        if @host.compute_resource.type == 'ForemanXen::Xenserver'
          title_actions(
            button_group(
              link_to(
                _('Xen Snapshots'),
                "../foreman_xen/snapshots/#{@host.id}/",
                :title => _('Manage machine snapshots'),
                :id => :xen_snap_button
              )
            )
          )
        end
      end
      host_title_actions_without_xen_snap_button(*args)
    end
  end
end
