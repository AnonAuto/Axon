
var nextPage = null;
var ops_mode = null;
var secure_mode = false; //indicator whether user authenticaltion has been performed or not

function getStatus(secure) {
    var api_name = "get-status";

    if (secure == undefined) secure = false; //set default value for parameter

    //for sercure api call, add the secure folder name to script/api call
    if(secure || secure_mode)
    {
        api_name = "secure/get-status"
        // if we entered secure mode once, keep track of it until page is refreshed
        secure_mode = true;
    }
    new APIRequest(api_name, null, function(data) {
        setStatusEx(data);
        cfgWizard(data);
    }, function(err) {
        var errMsg = "";
        if ((err.status !== undefined) && (err.status == 403 /* Forbidden */)) {
            errMsg = $.localizeString("ETM.strings.cannot_get_data_too_many_failed_login_attempts", "Cannot get data due to too many failed login attempts");
        } else {
            errMsg += $.localizeString("ETM.strings.unspecified_error", "An unspecified error has occurred: ");
            errMsg += catchUnlocalized(err.msg);
        }
        $(document).alert($.localizeString("ETM.strings.error", "Error"), errMsg);
    }).exec();
}

$(document).ready(function() {
    // updateTitle($.localizeString("ETM.index.page_title", "Status"));
    var title = document.title
    document.title += " - " + $.localizeString("ETM.index.page_title", "Status")

    localizePage();

    new APIRequest("get-header", null, function(data) {
        document.title = title + ` [${data.etm.etm.serial_num}] ` + " - " + $.localizeString("ETM.index.page_title", "Status")

        setHeader(data);
        $("#fwVersion").html(getData(data, "etm.etm.version"));
        getStatus();
    }).exec();

    $("#btnRefresh").click(function() {
        $(document).progress($.localizeString("ETM.strings.reloading_status_title","Refreshing"),
                                $.localizeString("ETM.strings.reloading_status","Reloading status..."),
                                100);

        new APIRequest("status-refresh", null, function(data) {
                $(document).progress();
                getStatus();
        }).exec();

        new APIRequest("get-header", null, function(data) {
            $("#fwVersion").html(getData(data, "etm.etm.version"));
        }).exec();
    });

    $(".sitenavigation-fulllogo").click(function(evt) {
        if (evt.shiftKey) {
            location.href = "secure/diag.html";
            return false;
        }
    });

});

// localization lookup table:  These are not comments, but are extracted from the code.
// $.localizeString("ETM.lookups.netmode.dynamic","dynamic");
// $.localizeString("ETM.lookups.netmode.static","static");
