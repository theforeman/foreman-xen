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
      :ifs => {
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
    if new_host?(new)
      compute_attributes = compute_resource.compute_profile_attributes_for(params['host']['compute_profile_id'])
      if compute_attributes['VBDs']
        attribute_map[:volume_size]     = compute_attributes['VBDs']['physical_size']
        attribute_map[:volume_selected] = compute_attributes['VBDs']['sr_uuid']
      end
      if compute_attributes['VIFs']
        attribute_map[:network_selected] = compute_attributes['VIFs']['print']
      end
      attribute_map[:template_selected_custom]  = compute_attributes['custom_template_name']
      attribute_map[:template_selected_builtin] = compute_attributes['builtin_template_name']
      attribute_map[:cpu_count]                 = compute_attributes['vcpus_max']
      attribute_map[:memory_min]                = compute_attributes['memory_min']
      attribute_map[:memory_max]                = compute_attributes['memory_max']
      attribute_map[:power_on]                  = compute_attributes['start']
    elsif new
      attribute_map[:cpu_count]  = new.vcpus_max ? new.vcpus_max : nil
      attribute_map[:memory_min] = new.memory_static_min ? new.memory_static_min : nil
      attribute_map[:memory_max] = new.memory_static_max ? new.memory_static_max : nil
      if new.vbds
        vdi = new.vbds.first.vdi
        if vdi
          attribute_map[:volume_selected] = vdi.sr.uuid ? vdi.sr.uuid : nil
          attribute_map[:volume_size]     = vdi.virtual_size ? (vdi.virtual_size.to_i / 1_073_741_824).to_s : nil
        end
      end
      if new.vifs
        attribute_map[:network_selected] = new.vifs.first.network.name ? new.vifs.first.network.name : nil
      end
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
    if compute_attributes
      if compute_attributes['VBDs']
        attribute_map[:volume_size]     = compute_attributes['VBDs']['physical_size']
        attribute_map[:volume_selected] = compute_attributes['VBDs']['sr_uuid']
      end
      if compute_attributes['VIFs']
        attribute_map[:network_selected] = compute_attributes['VIFs']['print']
      end
      attribute_map[:template_selected_custom]  = compute_attributes['custom_template_name']
      attribute_map[:template_selected_builtin] = compute_attributes['builtin_template_name']
      attribute_map[:cpu_count]                 = compute_attributes['vcpus_max']
      attribute_map[:memory_min]                = compute_attributes['memory_min']
      attribute_map[:memory_max]                = compute_attributes['memory_max']
      attribute_map[:power_on]                  = compute_attributes['start']
    end
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
end
