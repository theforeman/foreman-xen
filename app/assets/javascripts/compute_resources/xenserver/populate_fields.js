function xenPopulateNetworks(network_list){
    console.log("HAHAHAHAHAHAAH");
    $('#host_compute_attributes_VIFs_print').children().remove();
    for (var i = 0; i < network_list.length; i++) {
        network = network_list[i];
        $('#host_compute_attributes_VIFs_print').append('<option id=' + network['name'] + '>' + network['name'] + '</option>');
    }
}

function xenPopulateStoragePools(results){
    $('#host_compute_attributes_VBDs_sr_uuid').children().remove();
    for (var i = 0; i < results.length; i++) {
        result = results[i];
        $('#host_compute_attributes_VBDs_sr_uuid').append('<option id=' + result['uuid'] + '>' + result['name'] + '</option>');
    }
}

function xenPopulateCustomTemplates(custom_templates){
    xenPopulateTemplates(custom_templates, '#host_compute_attributes_custom_template_name');
}

function xenPopulateBuiltinTemplates(builtin_templates){
    xenPopulateTemplates(builtin_templates, '#host_compute_attributes_builtin_template_name');
}

function xenPopulateTemplates(results, selector){
    $(selector).children().remove();
    $(selector).append('<option>No template</option>');
    for (var i = 0; i < results.length; i++) {
        result = results[i];
        $(selector).append('<option id=' + result['name'] + '>' + result['name'] + '</option>');
    }
}