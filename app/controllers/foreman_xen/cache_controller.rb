module ForemanXen
  class CacheController < ::ApplicationController

    before_action :get_compute_resource

    # POST = foreman_xen/cache/refresh
    def refresh
      type                = params[:type]
      unless @compute_resource.respond_to?("#{type}!")
        process_error(:error_msg => "Error refreshing cache. Method '#{type}!' not found for compute resource" +
            @compute_resource.name)
      end

      respond_to do |format|
        format.json { render :json => @compute_resource.public_send("#{type}!") }
      end
    end

    private

    def get_compute_resource
      @compute_resource = ComputeResource.find_by_id(params['compute_resource_id'])
    end
  end
end
