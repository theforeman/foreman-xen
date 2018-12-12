module XenComputeHelper
  def compute_attributes_from_params(compute_resource)
    id = params.dig('host', 'compute_profile_id') || params.dig('compute_profile_id')
    return compute_resource.compute_profile_attributes_for id if id

    {}
  end

  private

  def selectable_f_with_cache_invalidation(f, attr, array,
                                           select_options = {}, html_options = {}, input_group_options = {})
    unless html_options.key?('input_group_btn')
      html_options[:input_group_btn] = link_to_function(
        icon_text('refresh'),
        'refreshCache(this)',
        :class => 'btn btn-primary',
        :title => _(input_group_options[:title]),
        :data  => {
          :url                 => input_group_options[:url],
          :compute_resource_id => input_group_options[:compute_resource_id],
          :attribute           => input_group_options[:attribute],
          :select_attr         => attr
        }
      )
    end
    selectable_f(f, attr, array, select_options, html_options)
  end
end
