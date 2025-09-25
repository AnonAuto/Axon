
function protoChange() {
    if($("#rProtocol input:checked").val() == "static") $("#frmStaticIP").show("fast");
    else $("#frmStaticIP").hide("fast");
}

$(document).ready(function() {
    var title = document.title;
    document.title += " - " + $.localizeString("ETM.networking.page_title", "Networking Settings");

    localizePage();

    $("#frmStaticIP").hide();
    $("#formWireless").hide();

    $("#rProtocol input").change(protoChange);

    $(".radio").buttonset();

    $("#btnDiscard").click(function(){
        location.reload(true);
    });

    $("#btnSave").click(function() {
    var valid = ($("#rProtocol input:checked").val() == "dhcp") || formIsValid("#frmStaticIP");
    valid = valid && formIsValid("#frmUpstream");
    if (valid) {
        var json=formToJSON("#content")
        json.token=$('meta[name="csrf-token"]').attr('content')
        var update = new APIRequest("secure/set-config", json, function(data) {
        alertOperationResult(data,
                                $.localizeString("ETM.networking.restart_title","Network Restart"),
                                $.localizeString("ETM.networking.saved_restarting","Settings are saved, network is restarting..."),
                                $.localizeString("ETM.strings.error","Error"),
                                data.msg)
        }, null);
        update.exec();
    }
    });

    new APIRequest("secure/get-config", null, function(data) {
        document.title = title + ` [${data.etm.etm.serial_num}] ` + " - " + $.localizeString("ETM.networking.page_title", "Networking Settings");

        setHeader(data);
        flatToForm("#content", flattenObj(data));
        if (typeof data.network.wan.dns !== 'undefined') {
        if (typeof data.network.wan.dns[0] !== 'undefined' && data.network.wan.dns[0] !== null) {
            $("#dns0").val(data.network.wan.dns[0]);
        }
        if (typeof data.network.wan.dns[1] !== 'undefined' && data.network.wan.dns[1] !== null) {
            $("#dns1").val(data.network.wan.dns[1]);
        }
        }
        $("#rProtocol").buttonset();
        protoChange();
    }).exec();
});
