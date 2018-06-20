module ForemanXen
  module HostHelperExtensions
    extend ActiveSupport::Concern

    module Overrides
      def host_title_actions(host)
        unless @host.compute_resource.nil?
          if @host.compute_resource.type == 'ForemanXen::Xenserver'
            title_actions(
              button_group(
                link_to(
                  _('Xen Snapshots'),
                  "../foreman_xen/snapshots/#{@host.id}/",
                  :title => _('Manage machine snapshots'),
                  :id    => :xen_snap_button,
                  :class => 'btn btn-default'
                )
              )
            )
          end
        end
        super(host)
      end
    end

    included do
      prepend Overrides
    end
  end
end
