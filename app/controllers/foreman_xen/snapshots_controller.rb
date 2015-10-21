module ForemanXen
  class SnapshotsController < ::ApplicationController
    helper :all
    skip_before_filter :verify_authenticity_token

    # GET - foreman_xen/snapshots/:host_id
    def show
      id    = params[:id]
      @host = get_host_by_id(id) if !id.nil? && id != ''
      if !@host.nil? && @host.compute_resource_id
        @compute_resource = get_compute_resource_for_host(@host)
        unless @compute_resource.nil?
          vm = @compute_resource.find_vm_by_uuid(@host.uuid)
          if !vm.nil?
            @snapshots = @compute_resource.get_snapshots_for_vm(vm)
          else
            process_error(:error_msg => "Error retrieving compute resource #{@host.compute_resource_id} from provider.")
            return
          end
        end
      elsif @host.nil?
        process_error(:error_msg => "No host found with ID: #{id}.")
        return
      else
        process_error(:error_msg => "No compute resource found for host with ID: #{id}.")
        return
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
            :success_msg => "Succesfully reverted and powered on #{@host.name}",
            :success_redirect => "/foreman_xen/snapshots/#{id}"
          )
          return
        else
          process_error(:error_msg => "Error retrieving host information for #{@host.name}")
          return
        end
      else
        process_error(:error_msg => "Error retrieving compute resource information for #{@host.name}")
        return
      end
      process_success(
        :success_msg => ("Succesfully reverted #{@host.name}"),
        :success_redirect => "/foreman_xen/snapshots/#{id}"
      )
      nil
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
          snapshots = @compute_resource.get_snapshots
          snapshots.each do |snapshot|
            if snapshot.reference == ref
              name = snapshot.name
              snapshot.destroy
              notice ("Succesfully deleted snapshot #{snapshot.name}")
              break
            end
          end
        else
          process_error(:error_msg => ("Error retrieving host information for host id: #{id}"))
          return
        end
      else
        process_error(:error_msg => ("Error retrieving compute resource information for host id: #{id}"))
        return
      end
      process_success(
        :success_msg => ("Succesfully deleted snapshot: #{name}"),
        :success_redirect => "/foreman_xen/snapshots/#{id}"
      )
      nil
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
          return
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
        return
      end
      @host = get_host_by_id(id)
      if !@host.nil?
        @compute_resource = get_compute_resource_by_host_id(id)
      else
        process_error(:error_msg => "Error retrieving host information for host id #{id}")
        return
      end
      if !@compute_resource.nil?
        vm = @compute_resource.find_vm_by_uuid(@host.uuid)
        if !vm.nil?
          vm.snapshot(name)
          process_success(
            :success_msg => "Succesfully created snapshot #{name} for #{@host.name}",
            :success_redirect => "/foreman_xen/snapshots/#{id}"
          )
          return
        else
          process_error(:error_msg => "Error retrieving compute resource information for #{@host.name}")
          return
        end
      else
        process_error(:error_msg => "Error retrieving compute provider information for #{@host.name}")
        return
      end
    end

    def snapshots_url
      case params[:action]
      when 'show'
        return '/'
      when 'new'
        id = params[:id]
        if id.nil?
          return '/'
        else
          return "/foreman_xen/snapshots/#{id}"
        end
      when 'create'
        id = params[:id]
        if id.nil?
          return '/'
        else
          return "/foreman_xen/snapshots/#{id}/new"
        end
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
