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
            error: function(){
                $.jnotify(__("Error refreshing cache for " + attribute_name), 'error', true);
            },
            success: on_success
        })
}
