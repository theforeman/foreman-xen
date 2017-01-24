function refreshCache(attribute_name, compute_resource_id, on_success) {
    tfm.tools.showSpinner();
    url = "/foreman_xen/cache/refresh";
    data = {
        type: attribute_name,
        compute_resource_id: compute_resource_id
    }
    $.ajax({
            type:'post',
            url: url,
            data: data,
            complete: function(){
                tfm.tools.hideSpinner();
            },
            error: function(jqXHR, status, error){
                $('#scheduler_hint_wrapper').html(Jed.sprintf(__("Error loading scheduler hint filters information: %s"), error));
                $('#compute_resource_tab a').addClass('tab-error');
            },
            success: on_success
        })
}
