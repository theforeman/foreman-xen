module ForemanXen
  class Xenserver < ComputeResource
    validates :url, :user, :password, :presence => true

    def provided_attributes
      super.merge(
        :uuid => :reference,
        :mac  => :mac
      )
    end

    def capabilities
      [:build, :image]
    end

    def find_vm_by_uuid(uuid)
      client.servers.get(uuid)
    rescue Fog::XenServer::RequestFailed => e
      Foreman::Logging.exception("Failed retrieving xenserver vm by uuid #{uuid}", e)
      raise(ActiveRecord::RecordNotFound) if e.message.include?('HANDLE_INVALID')
      raise(ActiveRecord::RecordNotFound) if e.message.include?('VM.get_record: ["SESSION_INVALID"')
      raise e
    end

    # we default to destroy the VM's storage as well.
    def destroy_vm(ref, args = {})
      logger.info "destroy_vm: #{ref} #{args}"
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

    def available_hypervisors
      read_from_cache('available_hypervisors', 'available_hypervisors!')
    end

    def available_hypervisors!
      store_in_cache('available_hypervisors') do
        hosts = client.hosts
        hosts.sort_by(&:name)
      end
    end

    def new_nic(attr = {})
      client.networks.new attr
    end

    def new_volume(attr = {})
      client.storage_repositories.new attr
    end

    def storage_pools
      #read_from_cache('storage_pools', 'storage_pools!')
      storage_pools!
    end

    def storage_pools!
      gb   = 1_073_741_824 # 1gb in bytes
      store_in_cache('storage_pools') do
        results = []
        storages = client.storage_repositories.select do |sr|
        espaco_livre = sr.physical_size.to_f - sr.physical_utilisation.to_f
          case client.host.to_s.downcase
          when "10.34.245.1", "s3001", "s3001.mpdft.gov.br", "s3001.mpdft.mp.br", "10.34.173.101", "s3002", "s3002.mpdft.gov.br", "s3002.mpdft.mp.br"
            sr.type != 'udev' && sr.type != 'iso' && espaco_livre > 625*gb #Somente SRs com espaco livre  maiores que 600GB + 25GB serao utilizados
          else
	    sr.type != 'udev' && (sr.name.upcase.include? '_SO') && sr.type != 'iso' && espaco_livre > 625*gb
          end

	end
        storages.each do |sr|
          subresults = {}
          found      = false
          espaco_livre = (sr.physical_size.to_f - sr.physical_utilisation.to_f)/gb

          available_hypervisors.each do |host|
            next unless sr.reference == host.suspend_image_sr
            found                     = true
            subresults[:name]         = sr.name
            subresults[:display_name] = sr.name + '(' + host.hostname + ')' + " (#{espaco_livre.round(2)} GB)"
            subresults[:uuid]         = sr.uuid
            subresults[:espaco_livre] = espaco_livre
            break
          end
          unless found
            subresults[:name]         = sr.name
            subresults[:display_name] = sr.name + " (#{espaco_livre.round(2)} GB)"
            subresults[:uuid]         = sr.uuid
            subresults[:espaco_livre] = espaco_livre
          end
          results.push(subresults)
        end
        results.sort_by! { |item| item[:espaco_livre] }.reverse!
      end
    end

    def interfaces
      client.interfaces
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
        client.servers.templates.sort_by(&:name)
      end
    end

    def custom_templates
      read_from_cache('custom_templates', 'custom_templates!')
    end

    def custom_templates!
      store_in_cache('custom_templates') do
        get_templates(client.servers.custom_templates)
      end
    end

    def builtin_templates
      read_from_cache('builtin_templates', 'builtin_templates!')
    end

    def builtin_templates!
      store_in_cache('builtin_templates') do
        get_templates(client.servers.builtin_templates)
      end
    end

    def associated_host(vm)
      associate_by('mac', vm.interfaces.map(&:mac).map { |mac| Net::Validations.normalize_mac(mac) })
    end

    def find_snapshots_for_vm(vm)
      return [] if vm.snapshots.empty?
      tmps = begin
        client.servers.templates.select(&:is_a_snapshot)
      rescue
        []
      end
      retval = []
      tmps.each do |snapshot|
        retval << snapshot if vm.snapshots.include?(snapshot.reference)
      end
      retval
    end

    def find_snapshots
      tmps = begin
        client.servers.templates.select(&:is_a_snapshot)
      rescue
        []
      end
      tmps.sort_by(&:name)
    end

    def new_vm(attr = {})
      test_connection
      return unless errors.empty?
      opts = vm_instance_defaults.merge(attr.to_hash).symbolize_keys

      %i[networks volumes].each do |collection|
        nested_attrs     = opts.delete("#{collection}_attributes".to_sym)
        opts[collection] = nested_attributes_for(collection, nested_attrs) if nested_attrs
      end
      opts.reject! { |_, v| v.nil? }
      client.servers.new opts
    end

    def create_vm(args = {})
      image_id  = args[:image_id].to_s
      builtin_template_name = args[:builtin_template_name].to_s

      if builtin_template_name != '' && image_id != ''
        logger.info "image_id: #{image_id}"
        logger.info "builtin_template_name: #{builtin_template_name}"
        raise 'you can select at most one template type'
      end
      begin
        logger.info "create_vm(): image_id: #{image_id}"
        logger.info "create_vm(): builtin_template_name: #{builtin_template_name}"
        vm = image_id != '' ? create_vm_from_custom(args) : create_vm_from_builtin(args)
        vm.set_attribute('name_description', 'Provisioned by Foreman')
        vm.set_attribute('VCPUs_max', args[:vcpus_max])
        vm.set_attribute('VCPUs_at_startup', args[:vcpus_max])
        vm.reload
        return vm
      rescue => e
        logger.info e
        logger.info e.backtrace.join("\n")
        return false
      end
    end

    def create_vm_from_custom(args)
      mem_max = args[:memory_max]
      mem_min = args[:memory_min]

      host = get_hypervisor_host(args)

      logger.info "url: #{url}"
      logger.info "user: #{user}"
      logger.info "password: #{password}"
      logger.info "create_vm_from_builtin: #{host}"

      raise 'Memory max cannot be lower than Memory min' if mem_min.to_i > mem_max.to_i
      
      template = client.custom_templates.select { |t| t.uuid == args[:image_id] }.first
      sr = client.storage_repositories.find { |sr| sr.uuid == (args[:VBDs][:sr_uuid]).to_s }
      vm_name = args[:name][s.length, args[:name].length - ".mpdft.gov.br".length]
      vm_reference = template.copy vm_name, sr.reference
#     vm.affinity = host
      client.provision_server (vm_reference)
      vm = client.servers.find { |server| server.reference == vm_reference }
      sr.scan

      begin
        vm.vifs.first.destroy
      rescue
        nil
      end

      create_network(vm, args)

#      args['xenstore']['vm-data']['ifs']['0']['mac'] = vm.vifs.first.mac
#      xenstore_data                                  = xenstore_hash_flatten(args['xenstore'])
#      vm.set_attribute('xenstore_data', xenstore_data)

      if vm.memory_static_max.to_i < mem_max.to_i
        vm.set_attribute('memory_static_max', mem_max)
        vm.set_attribute('memory_dynamic_max', mem_max)
        vm.set_attribute('memory_dynamic_min', mem_min)
        vm.set_attribute('memory_static_min', mem_min)
      else
        vm.set_attribute('memory_static_min', mem_min)
        vm.set_attribute('memory_dynamic_min', mem_min)
        vm.set_attribute('memory_dynamic_max', mem_max)
        vm.set_attribute('memory_static_max', mem_max)
      end

      disks = vm.vbds.select { |vbd| vbd.type == 'Disk' }
      disks.each do |vbd|
#        name_label = "#{vm_name}_#{vbd.device}_#{vbd.userdevice}"
        name_label = "#{vm_name}_xvda_#{vbd.userdevice}"
        vbd.vdi.set_name_label name_label
      end
      vm.reload
      vm
    end

    def create_vm_from_builtin(args)
      mem_max = args[:memory_max]
      mem_min = args[:memory_min]

#      host = get_hypervisor_host(args)
      host = client.hosts.sample
      logger.info "create_vm_from_builtin: #{host.inspect}"

      builtin_template_name = args[:builtin_template_name]
      builtin_template_name = builtin_template_name.to_s

      storage_repository = client.storage_repositories.find { |sr| sr.uuid == (args[:VBDs][:sr_uuid]).to_s }

      gb   = 1_073_741_824 # 1gb in bytes
      size = args[:VBDs][:physical_size].to_i * gb
      vdi  = client.vdis.create :name               => "#{args[:name]}-disk1",
                                :storage_repository => storage_repository,
                                :description        => "#{args[:name]}-disk_1",
                                :virtual_size       => size.to_s

      other_config = {}
      if builtin_template_name != ''
        template     = client.servers.builtin_templates.find { |tmp| tmp.name == args[:builtin_template_name] }
        other_config = template.other_config
        other_config.delete 'disks'
        other_config.delete 'default_template'
        other_config['mac_seed'] = SecureRandom.uuid
      end
      vm = client.servers.new :name               => args[:name],
                              :affinity           => host,
                              :pv_bootloader      => '',
                              :hvm_boot_params    => { :order => 'dnc' },
                              :other_config       => other_config,
                              :memory_static_max  => mem_max,
                              :memory_static_min  => mem_min,
                              :memory_dynamic_max => mem_max,
                              :memory_dynamic_min => mem_min

      vm.save :auto_start => false
      client.vbds.create :vm => vm, :vdi => vdi

      create_network(vm, args)

      if args[:xstools] == '1'
        # Add xs-tools ISO to newly created VMs
        dvd_vdi = client.vdis.find { |isovdi| isovdi.name == 'xs-tools.iso' }
        vbdconnectcd = {
          'vdi'                  => dvd_vdi,
          'vm'                   => vm.reference,
          'userdevice'           => '1',
          'mode'                 => 'RO',
          'type'                 => 'cd',
          'other_config'         => {},
          'qos_algorithm_type'   => '',
          'qos_algorithm_params' => {}
        }
        vm.vbds = client.vbds.create vbdconnectcd
        vm.reload
      end

      vm.provision
      vm.set_attribute('HVM_boot_policy', 'BIOS order')
      vm.reload
      vm
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
      @client ||= ::Fog::Compute.new(
        :provider                     => 'XenServer',
        :xenserver_url                => url,
        :xenserver_username           => user,
        :xenserver_password           => password,
        :xenserver_timeout            => 1800, #Timeout de 30 min devido ao tempo elevado necessario para clonar a template
        :xenserver_redirect_to_master => true
      )
    end

    def disconnect
      client.terminate if @client
      @client = nil
    end

    def vm_instance_defaults
      super.merge({})
    end

    private

    def create_network(vm, args)
      net        = client.networks.find { |n| n.name == args[:VIFs][:print] }
      net_config = {
        'mac_autogenerated'    => 'True',
        'vm'                   => vm.reference,
        'network'              => net.reference,
        'mac'                  => '',
        'device'               => '0',
        'mtu'                  => '0',
        'other_config'         => {},
        'qos_algorithm_type'   => 'ratelimit',
        'qos_algorithm_params' => {}
      }
      vm.vifs = client.vifs.create net_config
      vm.reload
    end

    def xenstore_hash_flatten(nested_hash, key = nil, keychain = nil, out_hash = {})
      nested_hash.each do |k, v|
        if v.is_a? Hash
          xenstore_hash_flatten(v, k, "#{keychain}#{k}/", out_hash)
        else
          out_hash["#{keychain}#{k}"] = v
        end
      end
      out_hash
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
