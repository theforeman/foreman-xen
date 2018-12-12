module ForemanXen
  class CacheController < ::ApplicationController
    before_action :load_compute_resource

    # POST = foreman_xen/cache/refresh
    def refresh
      type = params[:type]

      process_error(:error_msg => "Error refreshing cache. #{type} is not a white listed attribute") unless cache_attribute_whitelist.include?(type)

      unless @compute_resource.respond_to?("#{type}!")
        process_error(:error_msg => "Error refreshing cache. Method '#{type}!' not found for compute resource" +
            @compute_resource.name)
      end

      respond_to do |format|
        format.json do
          filtered_data = @compute_resource.public_send("#{type}!").map do |e|
            e.attributes.slice(:id, :uuid, :name, :display_name)
          end
          render json: filtered_data
        end
      end
    end

    private

    # List of methods to permit
    def cache_attribute_whitelist
      %w[isos networks available_hypervisors hypervisors templates builtin_templates storage_pools]
    end

    def load_compute_resource
      @compute_resource = ComputeResource.find_by(id: params['compute_resource_id'])
    end
  end
end
