function proxyChange() {
    if ($("#enable_proxy").is(":checked")) {
        $("#frmHttpProxy").show("fast");
    } else {
        $("#frmHttpProxy").hide("fast");
    }
}

$(document).ready(function () {
    var title = document.title;
    document.title += " - " + $.localizeString("ETM.proxy.page_title", "Proxy Settings");

    localizePage();

    $("#btnDiscard").click(function () {
        location.reload(true);
    });

    $("#btnSave").click(function (event) {
        event.preventDefault();
        if (formIsValid("#frmHttpProxy")) {
            var json = formToJSON("#content");
            json.token = $('meta[name="csrf-token"]').attr('content');
            var update = new APIRequest("secure/set-config", json, function (data) {
                alertOperationResult(data,
                                     $.localizeString("ETM.proxy.configuration_saved_title", "Proxy Configuration Saved"),
                                     $.localizeString("ETM.proxy.configuration_saved_msg", "Proxy configuration is saved and will take effect shortly"),
                                     $.localizeString("ETM.strings.error", "Error"),
                                     data.msg);
            }, null);
            update.exec();
        }
    });

    $("#btnTestProxy").click(function (event) {
        event.preventDefault();
        if (formIsValid("#frmHttpProxy")) {
            var json = formToJSON("#content");
            json.token = $('meta[name="csrf-token"]').attr('content');
            $(document).progress($.localizeString("ETM.proxy.proxy_test_title", "Proxy Test"),
                                 $.localizeString("ETM.proxy.proxy_test_in_progress", "Proxy test is in progress..."),
                                 100);
            var update = new APIRequest("secure/test-proxy", json, function (data) {
                $(document).progress();
                alertOperationResult(data,
                                     $.localizeString("ETM.proxy.proxy_test_title", "Proxy Test"),
                                     $.localizeString("ETM.proxy.proxy_test_success_msg", "Proxy test succeeded"),
                                     $.localizeString("ETM.strings.error", "Error"),
                                     $.localizeString("ETM.proxy.proxy_test_fail_msg", "Proxy test failed") + ` (${data.err}/${data.msg})`);
            }, null);
            update.exec();
        }
    });

    $("#frmHttpProxy").hide("fast");
    $("#enable_proxy").on("click", proxyChange);

    new APIRequest("secure/get-config", null, function (data) {
        document.title = title + ` [${data.etm.etm.serial_num}] ` + " - " + $.localizeString("ETM.proxy.page_title", "Proxy Settings");
        setHeader(data);
        flatToForm("#content", flattenObj(data));
        proxyChange();
    }).exec();
});
