
var nextPage = null;

var cnt = 1;
var running = false;

function addResult(txt) {
    $("#result").val($("#result").val()+txt);
}

function testGetKeys() {
    addResult("Test #"+(cnt++)+": ");
    new APIRequest("secure/get-keys", formToJSON("#testForm"), function(data) {
    addResult(data.err + " " + data.msg+"\n");
    if (running) setTimeout(testGetKeys, 1000);
    }, function(error) {
    var errMsg = data.msg;
    if (errMsg == "Invalid username or password") {
        errMsg = $.localizeString("ETM.cgi.invalid_auth", errMsg);
    } else if (errMsg == "Unknown error") {
        errMsg = $.localizeString("ETM.cgi.unknown_err", errMsg);
    }
    addResult("ERROR: "+error.err+" / "+errMsg);
    if (running) setTimeout(testGetKeys, 1000);
    }).exec();
}

$(document).ready(function() {
    new APIRequest("get-header", null, function(data) {
    setHeader(data);
    }).exec();

    $("#btnExec").click(function() {
    if (running) running = false;
    else {
        running = true;
        testGetKeys();
    }
    return false;
    });

});
