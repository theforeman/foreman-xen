module ForemanXen
  class CacheController < ::ApplicationController

    # POST = foreman_xen/cache/refresh
    def refresh
      type                = params[:type]
      compute_resource_id = params[:compute_resource_id]
      @compute_resource   = get_compute_resource_by_id(compute_resource_id)
      retval = nil
      if @compute_resource
        if @compute_resource.respond_to?("#{type}!")
          retval = @compute_resource.public_send("#{type}!")
        else
          process_error(:error_msg => "Error refreshing cache. Method '#{type}!' not found for compute resource" +
              @compute_resource.name)
        end
      else
        process_error(:error_msg => 'Error retrieving compute resource information')
      end

      respond_to do |format|
        format.json { render :json => retval }
      end
    end

    private

    def get_compute_resource_by_id(compute_resource_id)
      ComputeResource.where(:id => compute_resource_id).to_a[0] if compute_resource_id
    end
  end
end
