
var nextPage = null;

$(document).ready(function() {
    var title = document.title;
    document.title += " - " + $.localizeString("ETM.diag.page_title", "Status");

    localizePage();

    new APIRequest("get-header", null, function(data) {
    document.title = title + ` [${data.etm.etm.serial_num}] ` + " - " + $.localizeString("ETM.diag.page_title", "Status");
    setHeader(data);
    }).exec();

    $("#btnExec").click(function () {

    $("#cmdResult").val($.localizeString("ETM.strings.waiting_for_response","Waiting for response..."));
    var json=formToJSON("#diagForm")
    json.token=$('meta[name="csrf-token"]').attr('content')
    new APIRequest("secure/diag-cmd",
                    json,
                    function(data) {
                        $("#cmdResult").val(data.msg);
                    },
                    function(error) {
                        var errMsg = $.localizeString(data.msgkey, data.msg);
                        $("#cmdResult").val($.localizeString("ETM.strings.error","Error") +
                                            error.err +
                                            ": " +
                                            errMsg );
                    }).exec();
    return false;
    });
});
