const API_ROOT = "/cgi-bin/d3dapi";

$(document).ready(function(){
	performRequest('test', '123', "GET", {});
	performRequest('test', '', "POST", {});
	performRequest('test', 'success', "GET", {});
	performRequest('test', 'fail', "GET", {});
	performRequest('test', 'error', "GET", {});
	performRequest('test', 'echo', "GET", {});
	performRequest('test', 'write', "POST", {});
	performRequest('test', 'read', "GET", {});
});

/*
 * TODO
 * - change function signature to: apiPath, data, expected
 * - create request divs before ajax request so it's visible what 'threads' have been put out
 * - function always tries both GET and POST and matches this with expected.methods
 * - expected.methods can be 'GET', 'POST' or 'BOTH'
 * - expected.status indicates what status was expected
 * - expected.data.{...} indicates what fields should look like (regex/literal/...?)
 * - anything not specified in expected.data is ignored
 */
function performRequest(mod, func, method, data) {
	$.ajax({
		type: method,
		context: $("#module_" + mod),
		url: API_ROOT + "/" + mod + "/" + func,
		dataType: 'json',
		data: data
	}).done(function(response){
		var status = response.status == 'success' ? '<span class="resp_status resp_success">+</span>'
				: response.status == 'fail' ? '<span class="resp_status resp_fail">-</span>'
						: response.status == 'error' ? '<span class="resp_status resp_error">!</span>'
								: '<span class="resp_status resp_unknown">?</span>';
		var modFunc = '<span class="resp_mod_func">' + mod + '/' + func + '</span><br/>';
		this.append('<div id="resp_' + mod + '_' + func + '">' + status + modFunc
				+ '<span class="resp_msg">' + response.msg + '</span></div>');
	});
}
