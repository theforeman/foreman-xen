module ForemanXen
  class Xenserver < ComputeResource
    validates :url, :user, :password, :presence => true

    GB_BYTES = 1_073_741_824 # 1gb in bytes

    def provided_attributes
      super.merge(
        :uuid => :uuid,
        :mac  => :mac
      )
    end

    def capabilities
      %i[build image new_volume]
    end

    def host_compute_attrs(host)
      super(host).merge(
        name_description: host.comment,
        is_a_template:    false,
        is_a_shapshot:    false,
        xenstore:         host_xenstore_data(host),
        network_data:     host_network_data(host)
      )
    end

    def user_data_supported
      true
    end

    def iso_library_mountpoint
      attrs[:iso_library_mountpoint]
    end

    def iso_library_mountpoint=(path)
      mountpoint = path.to_s.end_with?('/') ? path.to_s : "#{path}/"
      mountpoint = nil if path.to_s.strip.empty?
      attrs[:iso_library_mountpoint] = mountpoint
    end

    def cleanup_configdrive(uuid)
      iso_file_name = "foreman-configdrive-#{uuid}.iso"
      begin
        path = File.join(iso_library_mountpoint, iso_file_name)
        exist = File.exist? path
        FileUtils.rm(path) if exist
      rescue
        return true unless exist

        return false
      end
    end

    # rubocop:disable Rails/DynamicFindBy
    # Fog::XenServer::Compute (client) isn't an ActiveRecord model which
    # supports find_by()
    def find_vm_by_uuid(uuid)
      return client.servers.find { |s| s.reference == uuid } if uuid.start_with? 'OpaqueRef:'

      client.servers.find_by_uuid(uuid)
    rescue Fog::XenServer::RequestFailed => e
      Foreman::Logging.exception("Failed retrieving xenserver vm by uuid #{uuid}", e)
      raise(ActiveRecord::RecordNotFound) if e.message.include?('HANDLE_INVALID')
      raise(ActiveRecord::RecordNotFound) if e.message.include?('VM.get_record: ["SESSION_INVALID"')

      raise e
    end
    # rubocop:enable Rails/DynamicFindBy

    # we default to destroy the VM's storage as well.
    def destroy_vm(ref, args = {})
      logger.info "destroy_vm: #{ref} #{args}"
      cleanup_configdrive(ref) if iso_library_mountpoint
      find_vm_by_uuid(ref).destroy
    rescue ActiveRecord::RecordNotFound
      true
    end

    def self.model_name
      ComputeResource.model_name
    end

    def max_cpu_count
      ## 16 is a max number of cpus per vm according to XenServer doc
      [hypervisor.host_cpus.size, 16].min
    end

    def max_memory
      xenserver_max_doc = 128 * 1024 * 1024 * 1024
      [hypervisor.metrics.memory_total.to_i, xenserver_max_doc].min
    rescue => e
      logger.error "unable to figure out free memory, guessing instead due to:#{e}"
      16 * 1024 * 1024 * 1024
    end

    def test_connection(options = {})
      super
      errors[:url].empty? && errors[:user].empty? && errors[:password].empty? && hypervisor
    rescue => e
      begin
        disconnect
      rescue
        nil
      end
      errors[:base] << e.message
    end

    def available_images
      custom_templates!
    end

    def available_storage_domains(*)
      storage_pools
    end

    def available_networks(*)
      networks
    end

    def available_hypervisors
      hypervisors.select(&:enabled)
    end

    def available_hypervisors!
      hypervisors!.select(&:enabled)
    end

    def hypervisors
      read_from_cache('hypervisors', 'hypervisors!')
    end

    def hypervisors!
      store_in_cache('hypervisors') do
        hosts = client.hosts
        hosts.sort_by(&:name)
      end
    end

    def new_nic(attr = {})
      client.vifs.new attr
    end

    def new_volume(attr = {})
      size = attr[:virtual_size_gb].to_i * GB_BYTES
      vdi = client.vdis.new virtual_size: size.to_s
      vdi.type = 'user'
      vdi.sr = storage_pools.find { |s| s.uuid == attr[:sr].to_s } if attr[:sr]
      vdi
    end

    def storage_pools
      read_from_cache('storage_pools', 'storage_pools!')
    end

    def storage_pools!
      store_in_cache('storage_pools') do
        pools = client.storage_repositories.select do |sr|
          sr.type != 'udev' && sr.type != 'iso'
        end
        pools.sort_by(&:display_name)
      end
    end

    def isos
      all_isos.reject do |iso|
        iso.name =~ /foreman-configdrive/
      end
    end

    def isos!
      all_isos!.reject do |iso|
        iso.name =~ /foreman-configdrive/
      end
    end

    def all_isos
      read_from_cache('isos', 'isos!')
    end

    def all_isos!
      store_in_cache('isos') do
        isos = iso_libraries.map(&:vdis).flatten
        isos.sort_by(&:name)
      end
    end

    def new_interface(attr = {})
      client.vifs.new attr
    end

    def interfaces
      client.vifs
    rescue
      []
    end

    def networks
      read_from_cache('networks', 'networks!')
    end

    def networks!
      store_in_cache('networks') do
        client.networks.sort_by(&:name)
      end
    end

    def templates
      read_from_cache('templates', 'templates!')
    end

    def templates!
      store_in_cache('templates') do
        client.templates.sort_by(&:name)
      end
    end

    def custom_templates
      read_from_cache('custom_templates', 'custom_templates!')
    end

    def custom_templates!
      store_in_cache('custom_templates') do
        get_templates(client.custom_templates)
      end
    end

    def builtin_templates
      read_from_cache('builtin_templates', 'builtin_templates!')
    end

    def builtin_templates!
      store_in_cache('builtin_templates') do
        get_templates(client.builtin_templates)
      end
    end

    def associated_host(vm)
      associate_by('mac', vm.interfaces.map(&:mac).map { |mac| Net::Validations.normalize_mac(mac) })
    end

    def find_snapshots_for_vm(vm)
      return [] if vm.snapshots.empty?

      tmps = begin
        client.templates.select(&:is_a_snapshot)
             rescue
               []
      end
      retval = []
      tmps.each do |snapshot|
        retval << snapshot if snapshot.snapshot_metadata.include?(vm.uuid)
      end
      retval
    end

    def find_snapshots
      tmps = begin
        client.templates.select(&:is_a_snapshot)
             rescue
               []
      end
      tmps.sort_by(&:name)
    end

    def new_vm(attr = {})
      attr = attr.to_hash.deep_symbolize_keys
      %i[networks interfaces].each do |collection|
        nested_attr = attr.delete("#{collection}_attributes".to_sym)
        attr[collection] = nested_attributes_for(collection, nested_attr) if nested_attr
      end
      if attr[:volumes_attributes]
        vol_attr = nested_attributes_for('volumes', attr[:volumes_attributes])
        attr[:volumes] = vol_attr.map { |v| new_volume(v) }
      end
      attr.reject! { |_, v| v.nil? }
      super(attr)
    end

    def vm_attr_from_args(args)
      {
        name:               args[:name],
        name_description:   args[:comment],
        VCPUs_max:          args[:vcpus_max],
        VCPUs_at_startup:   args[:vcpus_max],
        memory_static_max:  args[:memory_max],
        memory_dynamic_max: args[:memory_max],
        memory_dynamic_min: args[:memory_min],
        memory_static_min:  args[:memory_min]
      }
    end

    def create_vm(args = {})
      args = args.deep_symbolize_keys
      logger.debug('create_vm args:')
      logger.debug(args)
      begin
        # Create VM Object
        attr = vm_attr_from_args(args)
        if args[:provision_method] == 'image'
          image = available_images.find { |i| i.uuid == args[:image_id].to_s }
          sr = storage_pools.find { |s| s.uuid == args[:target_sr].to_s }
          vm = create_vm_from_image(image, attr, sr)
        else
          template = builtin_templates.find { |t| t.uuid == args[:builtin_template].to_s }
          raise 'Template not found' unless template

          vm = create_vm_from_template(attr, template)
        end

        raise 'Error creating VM' unless vm

        # Set correct affinity
        set_vm_affinity(vm, args[:hypervisor_host].to_s)

        # Add NICs
        vm.interfaces = args[:interfaces_attributes].map do |_, v|
          create_interface(vm, v[:network])
        end

        # Attach ConfigDrive
        create_and_attach_configdrive(vm, args) if args[:configdrive] == '1' && args[:provision_method] == 'image'

        # Attach ISO
        unless args[:iso].empty?
          iso_vdi = isos.find { |i| i.uuid == args[:iso] }
          attach_iso(vm, iso_vdi)
        end

        # Add new Volumes
        unless args[:volumes_attributes].nil?
          vm.volumes = args[:volumes_attributes].map do |_, v|
            create_volume(vm, v) unless v[:_delete] == '1'
          end
        end

        # Write XenStore data
        xenstore_data = xenstore_set_mac(vm, args[:xenstore])
        set_xenstore_data(vm, xenstore_data)

        # Fix Description
        vm.set_attribute('name-description', args[:name_description])

        return vm
      rescue => e
        cleanup_configdrive(vm.uuid) if vm&.uuid
        vm&.destroy
        vm.volumes.each(&:destroy) if vm&.volumes
        logger.info e
        logger.info e.backtrace.join("\n")
        raise e
      end
    end

    def create_vm_from_template(attr, template)
      vm_attr = template.attributes.dup.merge(attr)
      %i[uuid domid reference allowed_operations].each do |a|
        vm_attr.delete(a)
      end
      vm_attr[:is_a_template] = false
      vm_attr[:other_config].delete('default_template')
      vm_attr[:other_config]['mac_seed'] = SecureRandom.uuid
      vm = new_vm(vm_attr)
      # Set any host affinity (required for saving) - correct later
      vm.affinity = client.hosts.first
      vm.save
      vm
    end

    def create_vm_from_image(image, attr, sr)
      vm_ref = client.copy_server image.reference, attr[:name], sr.reference
      client.provision_server vm_ref
      vm = client.servers.find { |s| s.reference == vm_ref }
      set_vm_profile_attributes(vm, attr)
      rename_cloned_volumes(vm)
      vm
    end

    def set_vm_profile_attributes(vm, attr)
      # Memory limits must satisfy:
      # static_min <= dynamic_min <= dynamic_max <= static_max
      mem = %w[memory_static_max memory_dynamic_max
               memory_dynamic_min memory_static_min]
      mem.reverse! if vm.memory_static_max.to_i > attr[:memory_static_max].to_i
      # VCPU values must satisfy: 0 < VCPUs_at_startup <= VCPUs_max
      cpu = %w[VCPUs_max VCPUs_at_startup]
      cpu.reverse! if vm.vcpus_at_startup > attr[:VCPUs_at_startup]
      (mem + cpu).each { |e| vm.set_attribute e, attr[e.to_sym] }
    end

    def rename_cloned_volumes(vm)
      vm.volumes.each do |vol|
        udev = vol.vbds.find { |v| v.vm.uuid == vm.uuid }.userdevice
        name = "#{vm.name}-#{udev}"
        vol.set_attribute 'name-label', name
        vol.set_attribute 'name-description', name
      end
    end

    def console(uuid)
      vm = find_vm_by_uuid(uuid)
      raise 'VM is not running!' unless vm.ready?

      console = vm.service.consoles.find { |c| c.vm && c.vm.reference == vm.reference && c.protocol == 'rfb' }
      raise "No console for vm #{vm.name}" if console.nil?

      session_ref = (vm.service.instance_variable_get :@connection).instance_variable_get :@credentials
      full_url    = "#{console.location}&session_id=#{session_ref}"
      tunnel      = VNCTunnel.new full_url
      tunnel.start
      logger.info 'VNCTunnel started'
      WsProxy.start(
        :host      => tunnel.host,
        :host_port => tunnel.port,
        :password  => ''
      ).merge(
        :type => 'vnc',
        :name => vm.name
      )
    rescue Error => e
      logger.warn e
      raise e
    end

    def hypervisor
      client.hosts.first
    end

    protected

    def client
      @client ||= Fog::XenServer::Compute.new(
        xenserver_url:      url,
        xenserver_username: user,
        xenserver_password: password,
        xenserver_timeout:  1800
      )
    end

    def disconnect
      client.terminate if @client
      @client = nil
    end

    private

    def create_volume(vm, attr)
      vdi = new_volume attr
      udev = find_free_userdevice(vm)
      vdi.name = "#{vm.name}-#{udev}"
      vdi.description = "#{vm.name}-#{udev}"
      vdi.save
      # Attach VDI to VM
      client.vbds.create vm: vm, vdi: vdi, userdevice: udev.to_s, bootable: true
      vdi
    end

    def create_interface(vm, network_uuid)
      net = client.networks.find { |n| n.uuid == network_uuid }
      devices = vm.vifs.map(&:device)
      device = 0
      device += 1 while devices.include?(device.to_s)
      net_config = {
        'mac_autogenerated'    => 'True',
        'vm'                   => vm.reference,
        'network'              => net.reference,
        'mac'                  => '',
        'device'               => device.to_s,
        'mtu'                  => '0',
        'other_config'         => {},
        'qos_algorithm_type'   => 'ratelimit',
        'qos_algorithm_params' => {}
      }
      client.vifs.create net_config
    end

    def attach_iso(vm, iso_vdi)
      cd_drive = client.vbds.find { |v| v.vm == vm && v.type == 'CD' }
      if cd_drive&.empty
        client.insert_vbd cd_drive.reference, iso_vdi.reference
      else
        # Windows VMs expect the CDROM drive on userdevice 3
        vbds = client.vbds.select { |v| v.vm == vm }
        udev = vbds.map(&:userdevice).include?('3') ? find_free_userdevice(vm) : '3'
        vbd = {
          'vdi'                  => iso_vdi,
          'vm'                   => vm,
          'userdevice'           => udev.to_s,
          'mode'                 => 'RO',
          'type'                 => 'CD',
          'other_config'         => {},
          'qos_algorithm_type'   => '',
          'qos_algorithm_params' => {}
        }
        client.vbds.create vbd
      end
      true
    end

    def find_free_userdevice(vm)
      # Find next free userdevice id for vbd
      # vm.vbds is not current, vm.reload not working.
      vbds = client.vbds.select { |v| v.vm == vm }
      userdevices = vbds.map(&:userdevice)
      udev = 0
      udev += 1 while userdevices.include?(udev.to_s)
      udev
    end

    def xenstore_set_mac(vm, xenstore_data)
      xenstore_data[:'vm-data'][:ifs][:'0'][:mac] = vm.interfaces.first.mac
      xenstore_data
    end

    def set_xenstore_data(vm, xenstore_data)
      xenstore_data = xenstore_hash_flatten(xenstore_data)
      vm.set_attribute('xenstore_data', xenstore_data)
    end

    def host_xenstore_data(host)
      p_if = host.primary_interface
      subnet = p_if.subnet || p_if.subnet6
      { 'vm-data'     => { 'ifs' => { '0' =>
                                             { 'ip'      => p_if.ip.empty? ? p_if.ip6 : p_if.ip,
                                               'gateway' => subnet.nil? ? '' : subnet.gateway,
                                               'netmask' => subnet.nil? ? '' : subnet.mask } } },
        'nameserver1' => subnet.nil? ? '' : subnet.dns_primary,
        'nameserver2' => subnet.nil? ? '' : subnet.dns_secondary,
        'environment' => host.environment.to_s }
    end

    def xenstore_hash_flatten(nested_hash, _key = nil, keychain = nil, out_hash = {})
      nested_hash.each do |k, v|
        if v.is_a? Hash
          xenstore_hash_flatten(v, k, "#{keychain}#{k}/", out_hash)
        else
          out_hash["#{keychain}#{k}"] = v
        end
      end
      out_hash
    end

    # rubocop:disable Rails/DynamicFindBy
    # Fog::XenServer::Compute (client) isn't an ActiveRecord model which
    # supports find_by()
    def set_vm_affinity(vm, hypervisor)
      if hypervisor.empty?
        vm.set_attribute('affinity', '')
      else
        vm.set_attribute('affinity', client.hosts.find_by_uuid(hypervisor))
      end
    end
    # rubocop:enable Rails/DynamicFindBy

    def create_and_attach_configdrive(vm, attr)
      network_data = add_mac_to_network_data(attr[:network_data], vm)
      iso_name = generate_configdrive(vm.uuid,
                                      vm_meta_data(vm).to_json,
                                      network_data.deep_stringify_keys.to_json,
                                      attr[:user_data],
                                      iso_library_mountpoint)
      rescan_iso_libraries
      iso_vdi = all_isos!.find { |iso| iso.name == iso_name }
      raise 'Unable to locate metadata iso on iso libraries' unless iso_vdi

      attach_iso(vm, iso_vdi)
    end

    def vm_meta_data(vm)
      { 'uuid' => vm.uuid, 'hostname' => vm.name }
    end

    # openstack configdive network_data format spec:
    # https://github.com/openstack/nova-specs/blob/master/specs/liberty/implemented/metadata-service-network-info.rst
    def host_network_data(host)
      p_if = host.primary_interface
      network_data = { links: [], networks: [], services: [] }
      network = { id: 'network0', routes: [] }
      if p_if.subnet
        sn = p_if.subnet
        network[:ip_address] = p_if.ip unless p_if.ip.empty?
        network[:type] = sn.boot_mode == 'DHCP' ? 'ipv4_dhcp' : 'ipv4'
      end
      if p_if.subnet6
        sn = p_if.subnet6
        network[:ip_address] = p_if.ip6 unless p_if.ip6.empty?
        network[:type] = sn.boot_mode == 'DHCP' ? 'ipv6_dhcp' : 'ipv6'
      end
      link = { type: 'phy' }
      link[:id] = p_if.name.empty? ? 'eth0' : p_if.identifier
      link[:name] = link[:id]
      link[:mtu] = sn.mtu
      link[:ethernet_mac_address] = p_if.mac unless p_if.mac.empty?
      network_data[:links] << link
      network[:netmask] = sn.mask unless sn.mask.empty?
      network[:link] = link[:id]
      route = { network: '0.0.0.0', netmask: '0.0.0.0' }
      route[:gateway] = sn.gateway unless sn.gateway.empty?
      network[:routes] << route
      network_data[:networks] << network
      unless sn.dns_primary.empty?
        dns1 = { type: 'dns', address: sn.dns_primary }
        network_data[:services] << dns1
      end
      unless sn.dns_secondary.empty?
        dns2 = { type: 'dns', address: sn.dns_secondary }
        network_data[:services] << dns2
      end
      network_data
    end

    def add_mac_to_network_data(network_data, vm)
      network_data[:links][0][:ethernet_mac_address] = vm.interfaces.first.mac unless network_data[:links][0][:ethernet_mac_address]
      network_data
    end

    def generate_configdrive(vm_uuid, meta_data, network_data, user_data, dst_dir)
      Dir.mktmpdir('foreman-configdrive') do |wd|
        iso_file_name = "foreman-configdrive-#{vm_uuid}.iso"
        iso_file_path = File.join(wd, iso_file_name)
        config_dir = FileUtils.mkdir_p(File.join(wd, 'openstack/latest')).first
        meta_data_path = File.join(config_dir, 'meta_data.json')
        user_data_path = File.join(config_dir, 'user_data')
        network_data_path = File.join(config_dir, 'network_data.json')
        File.write(meta_data_path, meta_data)
        File.write(user_data_path, user_data)
        File.write(network_data_path, network_data)

        cmd = ['/usr/bin/genisoimage', '-output', iso_file_path,
               '-volid', 'config-2', '-joliet', '-rock', wd]

        raise ::Foreman::Exception, N_('ISO build failed, is the genisoimage package installed?') unless system(*cmd)

        FileUtils.cp(iso_file_path, dst_dir)

        return iso_file_name
      end
    end

    def rescan_iso_libraries
      iso_libraries.each do |sr|
        client.scan_sr sr.reference
      end
    end

    def iso_libraries
      client.storage_repositories.select do |sr|
        sr.type == 'iso'
      end
    end

    def get_templates(templates)
      tmps = templates.reject(&:is_a_snapshot)
      tmps.sort_by(&:name)
    end

    def get_hypervisor_host(args)
      return client.hosts.first unless args[:hypervisor_host] != ''

      client.hosts.find { |host| host.name == args[:hypervisor_host] }
    end

    def read_from_cache(key, fallback)
      value = Rails.cache.fetch(cache_key + key) { public_send(fallback) }
      value
    end

    def store_in_cache(key)
      value = yield
      Rails.cache.write(cache_key + key, value)
      value
    end

    def cache_key
      "computeresource_#{id}/"
    end
  end
end
