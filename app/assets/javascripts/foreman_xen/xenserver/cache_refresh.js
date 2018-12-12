function refreshCache(item) {
  tfm.tools.showSpinner();
  attribute_name = $(item).data('attribute');
  sel = $(item).closest('.input-group').children('select')
  data = {
    type: attribute_name,
    compute_resource_id: $(item).data('compute-resource-id')
  };
  $.ajax({
    type:'post',
    url: $(item).data('url'),
    data: data,
    complete: function(){
      tfm.tools.hideSpinner();
    },
    error: function(){
      notify(__("Error refreshing cache for " + attribute_name), 'error', true);
    },
    success: function(results, textStatus, jqXHR){
      var elements = sel.children()
      if (elements.first().val() == "") { //include_empty
        elements = elements.slice(1);
      }
      elements.remove();
      for (var i = 0; i < results.length; i++) {
        var result = results[i];
        var id = ('uuid' in result) ? result['uuid'] : result['id'];
        var name = ('display_name' in result) ? result['display_name'] : result['name'];
        sel.append('<option value=' + id + '>' + name + '</option>');
      }
    }
  });
}
