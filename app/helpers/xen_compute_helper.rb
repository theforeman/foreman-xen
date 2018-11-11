module XenComputeHelper
  def compute_attribute_map(params, compute_resource, new)
    if controller_name == 'hosts'
      attribute_map = hosts_controller_compute_attribute_map(params, compute_resource, new)
    elsif controller_name == 'compute_attributes'
      attribute_map = compute_resource_controller_attribute_map(params, compute_resource)
    end
    attribute_map
  end

  def init_vmdata
    vmdata = {
      :ifs         => {
        '0' => {
          :ip      => '',
          :gateway => '',
          :netmask => ''
        }
      },
      :nameserver1 => '',
      :nameserver2 => '',
      :environment => ''
    }
  end

  private

  def hosts_controller_compute_attribute_map(params, compute_resource, new)
    attribute_map = empty_attribute_map
    if new.try(:new_record?)
      compute_attributes = compute_resource.compute_profile_attributes_for(params['host']['compute_profile_id'])
      attribute_map = filter_compute_attributes(attribute_map, compute_attributes)
    elsif new
      attribute_map[:cpu_count]  = new.vcpus_max || nil
      attribute_map[:memory_min] = new.memory_static_min || nil
      attribute_map[:memory_max] = new.memory_static_max || nil
      if new.vbds
        vdi = new.vbds.first.vdi
        if vdi
          attribute_map[:volume_selected] = vdi.sr.uuid || nil
          attribute_map[:volume_size]     = vdi.virtual_size ? (vdi.virtual_size.to_i / 1_073_741_824).to_s : nil
        end
      end
      attribute_map[:network_selected] = new.vifs.first.network.name || nil if new.vifs
    end
    attribute_map
  end

  def compute_resource_controller_attribute_map(params, compute_resource)
    attribute_map = empty_attribute_map
    if params && params['compute_profile_id']
      compute_attributes = compute_resource.compute_profile_attributes_for(params['compute_profile_id'])
    elsif params && params['host'] && params['host']['compute_profile_id']
      compute_attributes = compute_resource.compute_profile_attributes_for(params['host']['compute_profile_id'])
    end
    attribute_map = filter_compute_attributes(attribute_map, compute_attributes) if compute_attributes
    attribute_map
  end

  def empty_attribute_map
    { :volume_size               => nil,
      :volume_selected           => nil,
      :network_selected          => nil,
      :template_selected_custom  => nil,
      :template_selected_builtin => nil,
      :cpu_count                 => nil,
      :memory_min                => nil,
      :memory_max                => nil,
      :power_on                  => nil }
  end

  def filter_compute_attributes(attribute_map, compute_attributes)
    if compute_attributes['VBDs']
      attribute_map[:volume_size]     = compute_attributes['VBDs']['physical_size']
      attribute_map[:volume_selected] = compute_attributes['VBDs']['sr_uuid']
    end
    attribute_map[:network_selected] = compute_attributes['VIFs']['print'] if compute_attributes['VIFs']
    attribute_map[:template_selected_custom]  = compute_attributes['custom_template_name']
    attribute_map[:template_selected_builtin] = compute_attributes['builtin_template_name']
    attribute_map[:cpu_count]                 = compute_attributes['vcpus_max']
    attribute_map[:memory_min]                = compute_attributes['memory_min']
    attribute_map[:memory_max]                = compute_attributes['memory_max']
    attribute_map[:power_on]                  = compute_attributes['start']
    attribute_map
  end

  def xen_builtin_template_map(compute_resource)
    compute_resource.builtin_templates.map { |t| [t.name, t.name] }
  end

  def xen_custom_template_map(compute_resource)
    compute_resource.custom_templates.map { |t| [t.name, t.name] }
  end

  def xen_storage_pool_map(compute_resource)
    compute_resource.storage_pools.map { |item| [item[:display_name], item[:uuid]] }
  end

  def xen_hypervisor_map(compute_resource)
    compute_resource.available_hypervisors!.map do |t|
      [t.name + ' - ' + (
        t.metrics.memory_free.to_f / t.metrics.memory_total.to_f * 100
      ).round(2).to_s + '% free mem', t.name]
    end
  end

  def selectable_f_with_cache_invalidation(f, attr, array,
                                           select_options = {}, html_options = {}, input_group_options = {})
    unless html_options.key?('input_group_btn')
      html_options[:input_group_btn] = link_to_function(
        icon_text('refresh'),
        "refreshCache(this, #{input_group_options[:callback]})",
        :class => 'btn btn-primary',
        :title => _(input_group_options[:title]),
        :data  => {
          :url                 => input_group_options[:url],
          :compute_resource_id => input_group_options[:computer_resource_id],
          :attribute           => input_group_options[:attribute]
        }
      )
    end
    selectable_f(f, attr, array, select_options, html_options)
  end
end
