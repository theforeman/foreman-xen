module XenComputeHelper

  CACHE_PATH = File.exists?(SETTINGS[:puppetvardir]) ? Settings[:puppetvardir] : "/tmp"

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
    if new_host?(new)
      compute_attributes = compute_resource.compute_profile_attributes_for(params['host']['compute_profile_id'])
      attribute_map = filter_compute_attributes(attribute_map, compute_attributes)
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
      attribute_map = filter_compute_attributes(attribute_map, compute_attributes)
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

  def filter_compute_attributes(attribute_map, compute_attributes)
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
    attribute_map
  end

  def builtin_template_map(compute_resource)
    if(not persisted_map_exists?('builtin_templates'))
      persist_map('builtin_templates', compute_resource.builtin_templates.map { |t| [t.name, t.name] })
    end
    load_map('builtin_templates')
  end

  def custom_template_map(compute_resource)
    if(not persisted_map_exists?('custom_templates'))
      persist_map('custom_templates', compute_resource.custom_templates.map { |t| [t.name, t.name] })
    end
    load_map('custom_templates')
  end

  def storage_pool_map(compute_resource)
    if(not persisted_map_exists?('storage_pools'))
      persist_map('storage_pools', compute_resource.storage_pools.map { |item| [item[:display_name], item[:uuid]] })
    end
    load_map('storage_pools')
  end

  def hypervisor_map(compute_resource)
    if(not persisted_map_exists?('hypervisor'))
      persist_map('hypervisor', compute_resource.available_hypervisors.map { |t| [t.name + " - " + (t.metrics.memory_free.to_f / t.metrics.memory_total.to_f * 100).round(2).to_s + "% free mem", t.name] })
    end
    load_map('hypervisor')
  end

  private

  def persist_map(name, map, file="xen_#{name}_map.cache")
    File.open(File.join(CACHE_PATH, file),'w') do |m|
      m.write map.to_yaml
    end
  end

  def load_map(name, file="xen_#{name}_map.cache")
    YAML.load_file(File.join(CACHE_PATH, file))
  end

  def persisted_map_exists?(name, file="xen_#{name}_map.cache")
    File.exists?(File.join(CACHE_PATH, file))
  end

end
