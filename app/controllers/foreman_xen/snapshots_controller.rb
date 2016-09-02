module ForemanXen
  class SnapshotsController < ::ApplicationController
    helper :all
    skip_before_action :verify_authenticity_token

    # GET - foreman_xen/snapshots/:host_id
    def show
      id    = params[:id]
      @host = get_host_by_id(id) if !id.nil? && id != ''
      if !@host.nil? && @host.compute_resource_id
        @compute_resource = get_compute_resource_for_host(@host)
        unless @compute_resource.nil?
          vm = @compute_resource.find_vm_by_uuid(@host.uuid)
          if !vm.nil?
            @snapshots = @compute_resource.find_snapshots_for_vm(vm)
          else
            process_error(:error_msg => "Error retrieving compute resource #{@host.compute_resource_id} from provider.")
          end
        end
      elsif @host.nil?
        process_error(:error_msg => "No host found with ID: #{id}.")
      else
        process_error(:error_msg => "No compute resource found for host with ID: #{id}.")
      end
    end

    # GET = foreman_xen/snapshots/revert
    def revert
      id                = params[:id]
      ref               = params[:ref]
      @host             = get_host_by_id(id)
      @compute_resource = get_compute_resource_by_host_id(id)
      if @compute_resource
        if @host
          vm = @compute_resource.find_vm_by_uuid(@host.uuid)
          vm.revert(ref)
          vm.start
          process_success(
            :success_msg      => "Successfully reverted and powered on #{@host.name}",
            :success_redirect => "/foreman_xen/snapshots/#{id}"
          )
        else
          process_error(:error_msg => "Error retrieving host information for #{@host.name}")
        end
      else
        process_error(:error_msg => "Error retrieving compute resource information for #{@host.name}")
      end
    end

    # GET = foreman_xen/snapshots/delete
    def destroy
      ref               = params[:ref]
      id                = params[:id]
      @host             = get_host_by_id(id)
      @compute_resource = get_compute_resource_by_host_id(id)
      name              = nil
      if @compute_resource
        if @host
          snapshots = @compute_resource.find_snapshots
          snapshots.each do |snapshot|
            next unless snapshot.reference == ref
            name = snapshot.name
            snapshot.destroy
            notice "Successfully deleted snapshot #{snapshot.name}"
            break
          end
        else
          process_error(:error_msg => "Error retrieving host information for host id: #{id}")
        end
      else
        process_error(:error_msg => "Error retrieving compute resource information for host id: #{id}")
      end
      process_success(
        :success_msg      => "Successfully deleted snapshot: #{name}",
        :success_redirect => "/foreman_xen/snapshots/#{id}"
      )
    end

    # GET = foreman_xen/snapshots/:id/new
    def new
      id    = params[:id]
      @host = get_host_by_id(id)
      if !@host.nil?
        @compute_resource = get_compute_resource_by_host_id(id)
        if @compute_resource.nil?
          process_error(
            :error_msg => "Error retrieving compute information for compute resource id: #{@host.compute_resource_id}"
          )
        end
      else
        process_error(:error_msg => "Error retrieving host information for host id: #{id}")
      end
    end

    # POST = foreman_xen/snapshots/:id/create
    def create
      id   = params[:id]
      name = params[:name]
      if name.nil? || name == ''
        process_error(:error_msg => 'You must supply a name.')
      end
      @host = get_host_by_id(id)
      if !@host.nil?
        @compute_resource = get_compute_resource_by_host_id(id)
      else
        process_error(:error_msg => "Error retrieving host information for host id #{id}")
      end
      if !@compute_resource.nil?
        vm = @compute_resource.find_vm_by_uuid(@host.uuid)
        if !vm.nil?
          vm.snapshot(name)
          process_success(
            :success_msg      => "Successfully created snapshot #{name} for #{@host.name}",
            :success_redirect => "/foreman_xen/snapshots/#{id}"
          )
        else
          process_error(:error_msg => "Error retrieving compute resource information for #{@host.name}")
        end
      else
        process_error(:error_msg => "Error retrieving compute provider information for #{@host.name}")
      end
    end

    def snapshots_url
      case params[:action]
      when 'show'
        '/'
      when 'new'
        id = params[:id]
        id.nil? ? '/' : "/foreman_xen/snapshots/#{id}"
      when 'create'
        id = params[:id]
        id.nil? ? '/' : "/foreman_xen/snapshots/#{id}/new"
      end
    end

    private

    def get_host_by_id(host_id)
      Host::Managed.where(:id => host_id).to_a[0]
    end

    def get_compute_resource_by_host_id(host_id)
      host = get_host_by_id(host_id)
      ComputeResource.where(:id => host.compute_resource_id).to_a[0] if host
    end

    def get_compute_resource_for_host(host)
      ComputeResource.where(:id => host.compute_resource_id).to_a[0] if host
    end
  end
end
