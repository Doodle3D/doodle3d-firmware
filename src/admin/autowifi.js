/*
 * TODO
 * - finish network creation
 * - finish auto operation
 * - call auto op from init script
 * - in AP mode, route all addresses to the autowifi page
 * - escape text where necessary (e.g. in getKnown, '<unknown SSID>' is currently interpreted as html...)
 * - why is $.trim() required in string comparison? do we need to strip newlines in the parse functions?
 * - add hidden field to remember encryption (so we know whether or not a passphrase should be entered)
 * - instead of showing alerts on missing ssid/phrase in connect, disable the button until contraints have been satisfied
 *   (this is also cleaner in case no networks are present)
 * - use json for communication
 * - local all functions (see: http://stackoverflow.com/questions/4643814/why-would-this-lua-optimization-hack-help)
 */

animSpeed = 200;
cgiBase = "../cgi-bin/wfcf";

function setResultNeutral(text) {
	c = $("#op_result"); p = c.parent();
	c.removeClass("result_success").removeClass("result_error").html(text);
	if (text == "") p.hide(animSpeed);
	else p.show(animSpeed);
}

/*
 * Sets div#op_result content to text, assigns appropiate class based on isError and display: block or, with empty text, display:none.
 */
function setResult(text, isError) {
	container = $("#op_result");
	parent = container.parent();
	if (isError) container.removeClass("result_success").addClass("result_error");
	else container.removeClass("result_error").addClass("result_success");
	
	if (isError) title = "<i>Error</i><br />\n";
	else title = "<i>Success</i><br />\n";
	container.html(title + text);
	
	if (text == "") parent.hide(animSpeed);
	else parent.show(animSpeed);
}

//Returns an array with key 'status' (OK/WARN/ERR), 'msg' (can be empty) and 'status' (remainder of data)
function parseResponse(response) {
	var r = {};
	var lines = response.split("\n");
	var st = lines[0].trim().split(',');
	lines = lines.slice(1);
	
	r['status'] = st[0];
	r['msg'] = st.slice(1).join(",");
	r['payload'] = lines.join("\n");
	
	return r;
}

function parseNetLine(line) {
	var r = {};
	line = line.trim().split(",");
	r.ssid = line[0];
	r.bssid = line[1];
	r.channel = line[2];
	r.mode = line[3];
	return r;
}

function fetchNetworkState() {
	$.get(cgiBase + "?op=getstate", function(data) {
		data = parseResponse(data);
		if (data.status == "ERR") setResult(data.msg, true);
		var net = parseNetLine(data.payload);
		if (net.mode == "ap") {
			$("#wlan_state").text("Access point mode (SSID: " + net.ssid + "; BSSID: " + net.bssid + "; channel: " + net.channel + ")");
		} else {
			$("#wlan_state").text("Client mode (SSID: " + net.ssid + "; BSSID: " + net.bssid + "; channel: " + net.channel + ")");
		}
	});
}

function fetchAvailableNetworks() {
	$.get(cgiBase + "?op=getavl", function(data) {
		data = parseResponse(data);
		if (data.status == "ERR") setResult(data.msg, true);
//		else setResult(data.msg, false);
		
		data = data.payload.split("\n");
		var options = $("#wlan_networks");
		options.empty();
		$.each(data, function(index,value) {
			if (value != "") {
				var ssid = parseNetLine(value).ssid;
				options.append($("<option />").val(ssid).text(ssid));
			}
		});
		$("#wlan_btn_connect").prop('disabled', false);
	});
}

function fetchKnownNetworks() {
	$.get(cgiBase + "?op=getknown", function(data) {
		data = parseResponse(data);
		if (data.status == "ERR") setResult(data.msg, true);
		
		data = data.payload.split("\n");
		var container = $("#wlan_known_container");
		container.empty();
		container.append("<table class=\"known_nets\"><tr><th>SSID</th><th>BSSID</th><th>channel</th></tr>");
		$.each(data, function(index,value) {
			if (value != "") {
				net = parseNetLine(value);
				console.log(net);
				container.append("<tr><td>" + net.ssid + "</td><td>" + net.bssid + "</td><td>" + net.channel + "</td></tr>");
			}
		});
		container.append("</table>");
	});
}

function connectBtnHandler() {
	setResultNeutral("Associating with network...");
	ssid = $("#wlan_networks").find(":selected").text();
	phrase = $("#wlan_passphrase").val();
	
	if (ssid == "") {
		alert("Please select a network");
		return;
	}
	
	$.get(cgiBase + "?op=assoc&ssid=" + ssid + "&passphrase=" + phrase, function(data) {
		data = parseResponse(data);
		if (data.status == "ERR") {
			setResult(data.msg, true);
		} else {
			if (data.msg != "") setResult(data.msg, false);
			else setResult("Associated! (or are we?)", false);
		}
		
		fetchKnownNetworks();
	});
	
	return;
}

$(document).ready(function() {
	fetchNetworkState();
	fetchAvailableNetworks();
	fetchKnownNetworks();
	$("#wlan_btn_connect").click(connectBtnHandler);
});
