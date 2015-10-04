module XenComputeHelper
  def compute_attribute_map(params, compute_resource, new)
    if @controller_name == 'hosts'
      attribute_map = hosts_controller_compute_attribute_map(params, compute_resource, new)
    elsif @controller_name = 'compute_attributes'
      attribute_map = compute_resource_controller_attribute_map(params, compute_resource)
    end
    attribute_map
  end

  def init_vmdata()
    vmdata = { :ifs         =>
                   { '0' => {
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
    if new_host?
      compute_attributes = compute_resource.compute_profile_attributes_for(params['host']['compute_profile_id'])
      if compute_attributes['VBDs']
        attribute_map[:volume_size] = compute_attributes['VBDs']['physical_size'] ? compute_attributes['VBDs']['physical_size'] : nil
        attribute_map[:volume_selected] = compute_attributes['VBDs']['sr_uuid'] ? compute_attributes['VBDs']['sr_uuid'] : nil
      end
      if compute_attributes['VIFS']
        attribute_map[:network_selected] = compute_attributes['VIFs']['print'] ? compute_attributes['VIFs']['print'] : nil
      end
      attribute_map[:template_selected_custom] = compute_attributes['custom_template_name'] ? compute_attributes['custom_template_name'] : nil
      attribute_map[:template_selected_builtin] = compute_attributes['builtin_template_name'] ? compute_attributes['custom_template_name'] : nil
    elsif params && params['host'] && params['host']['compute_attributes']
      if params['host']['compute_attributes']['VBDs']
        attribute_map[:volume_size] = (params['host']['compute_attributes']['VBDs']['physical_size']) ? params['host']['compute_attributes']['VBDs']['physical_size'] : nil
        attribute_map[:volume_selected] = (params['host']['compute_attributes']['VBDs']['sr_uuid']) ? params['host']['compute_attributes']['VBDs']['sr_uuid'] : nil
      end
      if params['host']['compute_attributes']['VIFs']
        attribute_map[:network_selected] = params['host']['compute_attributes']['VIFs']['print'] ? params['host']['compute_attributes']['VIFs']['print'] : nil
      end
      attribute_map[:template_selected_custom] = params['host']['compute_attributes']['custom_template_name'] ? params['host']['compute_attributes']['custom_template_name'] : nil
      attribute_map[:template_selected_builtin] = params['host']['compute_attributes']['builtin_template_name'] ? params['host']['compute_attributes']['builtin_template_name'] : nil
    elsif new
      if new.__vbds
        attribute_map[:volume_selected] = new.__vbds['sr_uuid'] ? new.__vbds['sr_uuid'] : nil
        attribute_map[:volume_size] = new.__vbds['physical_size'] ? new.__vbds['physical_size'] : nil
      end
      if new.__vifs
        attribute_map[:network_selected] = new.__vifs['print'] ? new.__vifs['print'] : nil
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
        attribute_map[:volume_size] = compute_attributes['VBDs']['physical_size'] ? compute_attributes['VBDs']['physical_size'] : nil
        attribute_map[:volume_selected] = compute_attributes['VBDs']['sr_uuid'] ? compute_attributes['VBDs']['sr_uuid'] : nil
      end
      if compute_attributes['VIFs']
        attribute_map[:network_selected] = compute_attributes['VIFs']['print'] ? compute_attributes['VIFs']['print'] : nil
      end
      attribute_map[:template_selected_custom] = compute_attributes['custom_template_name'] ? compute_attributes['custom_template_name'] : nil
      attribute_map[:template_selected_builtin] = compute_attributes['builtin_template_name'] ? compute_attributes['builtin_template_name'] : nil
      attribute_map[:cpu_count] = compute_attributes['vcpus_max'] ? compute_attributes['vcpus_max'] : nil
      attribute_map[:memory_min] = compute_attributes['memory_min'] ? compute_attributes['memory_min'] : nil
      attribute_map[:memory_max] = compute_attributes['memory_max'] ? compute_attributes['memory_max'] : nil
      attribute_map[:power_on] = compute_attributes['start'] ? compute_attributes['start'] : nil
    end
    attribute_map
  end

  def empty_attribute_map
    {:volume_size => nil,
     :volume_selected => nil,
     :network_selected => nil,
     :template_selected_custom => nil,
     :template_selected_builtin => nil,
     :cpu_count => nil,
     :memory_min => nil,
     :memory_max => nil,
     :power_on => nil}
  end