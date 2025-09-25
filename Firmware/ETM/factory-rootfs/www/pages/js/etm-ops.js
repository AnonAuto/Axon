var authenticated = false;
var local = false
var request={ "token":$('meta[name="csrf-token"]').attr('content') }

function reloadPage() {
    $(document).progress();
    window.location.reload(false);
}

function keyResponse(data) {
    if (data.err == "0") {
    $(document).progress($.localizeString("ETM.ops.register_with_ecom","Register with Evidence.com"), $.localizeString("ETM.ops.restarting_etm","Restarting Dock, this will take approximately 30 seconds..."), 100);
    setTimeout(reloadPage, 30000);
    new APIRequest("secure/etm-restart", request, null).exec();
    } else {
        var errMsg = parseError(data);
        $(document).progress();
        $(document).alert($.localizeString("ETM.ops.an_error_occurred"),
                            $.localizeString("ETM.strings.error","Error") +
                            " " +
                            data.err +
                            ": <br/>" +
                            errMsg);
    }
}

function localResponse(data) {
    if (data.err == 0) {
    $(document).progress("", $.localizeString("ETM.ops.restarting_etm","Restarting Dock, this will take approximately 30 seconds..."), 100);
    setTimeout(reloadPage, 30000);
    } else {
        var errMsg = parseError(data);
        $(document).alert($.localizeString("ETM.ops.an_error_occurred","An error occurred"),
                            $.localizeString("ETM.strings.error","Error") + " " + data.err + ": <br/>" + errMsg);
    }
}

function saveECOM()
{
    var valid = formIsValid("#frmECOM");
    if (valid)
    {
        $(document).progress($.localizeString("ETM.ops.register_with_ecom","Register with Evidence.com"), $.localizeString("ETM.ops.registering_etm","Registering the Dock..."), 100);
        var json=formToJSON("#content")
        json.token=$('meta[name="csrf-token"]').attr('content')
        new APIRequest(
            "secure/register-ecom",
            json,
            function(data)
            {
                if (data.err == "0" || data.err == "1080")
                {
                    $(document).progress($.localizeString("ETM.ops.register_with_ecom","Register with Evidence.com"),
                    $.localizeString("ETM.ops.generating_tokens","Generating Security Tokens..."), 100);
                    var json=formToJSON("#content")
                    json.token=$('meta[name="csrf-token"]').attr('content')
                    new APIRequest("secure/get-keys", json, keyResponse).exec();
                } else {
                    var errMsg = parseError(data);
                    $(document).progress();
                    $(document).alert($.localizeString("ETM.ops.an_error_occurred"),
                    $.localizeString("ETM.strings.error","Error") + " " + data.err + ": <br/>" + errMsg);
                }
            }
        ).exec();
    }
}

function renderUsernameAndPassword(isShown) {
    if (isShown) {
        var ecomReg = "To register this Dock to your Evidence.com Agency enter your Evidence.com agency name, username and password.\
                       Once the Dock is registered to Evidence.com, it will transfer all media files to your Evidence.com account.\
                       Your username and password are not stored on the Dock."
        $("#msgEcomReg").html($.localizeString("ETM.ops.sections.e_com_reg.msg", ecomReg));
        $("#ecom_username_row").show();
        $("#ecom_password_row").show();
        $("#ecom_username_row input[name='etm.admin.username']").prop("required", true);
        $("#ecom_password_row input[name='etm.admin.password']").prop("required", true);
    } 
    else 
    {
        var ecomReg = "To register this Dock to your Evidence.com Agency enter your Evidence.com agency name.\
                       Once the Dock is registered to Evidence.com, it will transfer all media files to your Evidence.com account."
        $("#msgEcomReg").html($.localizeString("ETM.ops.sections.e_com_reg.msg_shorten", ecomReg));
        $("#ecom_username_row").hide();
        $("#ecom_password_row").hide();
        $("#ecom_username_row input[name='etm.admin.username']").prop("required", false);
        $("#ecom_password_row input[name='etm.admin.password']").prop("required", false);
    }
}

function setButtonStatus(button, enabled) {
    if (enabled) {
        $(button).prop('disabled', false);
        $(button).removeClass('disabled');
    } else {
        $(button).prop('disabled', true);
        $(button).addClass('disabled');
    }
}

function pollAccessToken(baseIntervalSecond) {
    var interval = baseIntervalSecond;
    var exponential = 0;
    var secondsElapsed = 0;
    tokenPolling = setInterval(function() {
        secondsElapsed++;
        interval = baseIntervalSecond * (2 ** exponential);
        if ( (secondsElapsed % interval) === 0 ) {
            secondsElapsed = 0;
            var json=formToJSON("#content")
            json.token=$('meta[name="csrf-token"]').attr('content')
            new APIRequest(
                "secure/get-access-token",
                json,
                function(data) {
                    data.err = String(data.err);
                    if (data.err == "0" && data.msg == "RetrievedToken") {
                        clearInterval(tokenPolling);
                        $(document).progress($.localizeString("ETM.ops.register_with_ecom","Register with Evidence.com"), $.localizeString("ETM.ops.registering_etm","Registering the Dock..."), 100);
                        new APIRequest(
                            "secure/register-ecom-universal-login",
                            json,
                            function(regData)
                            {
                                if (regData.err == "0")
                                {
                                    $(document).progress($.localizeString("ETM.ops.register_with_ecom","Register with Evidence.com"), $.localizeString("ETM.ops.restarting_etm","Restarting Dock, this will take approximately 30 seconds..."), 100);
                                    setTimeout(reloadPage, 30000);
                                    new APIRequest("secure/etm-restart", request, null).exec();
                                } else {
                                    var errMsg = parseError(regData); 
                                    $(document).progress();
                                    $(document).alert($.localizeString("ETM.ops.an_error_occurred"),
                                    $.localizeString("ETM.strings.error","Error") + " " + regData.err + ": <br/>" + errMsg);
                                }
                            }
                        ).exec();
                    } else if (data.err == "0" && data.msg == "AuthorizationPending") {
                        exponential = 0;
                    } else if (data.err == "0" && data.msg == "ExponentialBackoff") {
                        exponential = Math.min(5, exponential + 1);
                    } else {
                            clearInterval(tokenPolling);
                            errMsg = parseError(data);
                            $(document).alert($.localizeString("ETM.ops.an_error_occurred"), $.localizeString("ETM.strings.error","Error") + " " + data.err + ": <br/>" + errMsg);
                            setButtonStatus("#btnContinue", true);
                    }
                }
            ).exec();
        }
    }, 1000);
}
function getLoginUriCode(response) {
    var errMsg = ""
    response.err = String(response.err);
    if (response.err == "0") {
        var uriEmbedded = `<a href="${response.verification_uri}" target="_blank" rel="noopener noreferrer">${response.verification_uri}</a>`;
        var userCodeEmbedded = `<b>${response.user_code}</b>`;
        var msg = $.localizeString("ETM.ops.sections.e_com_reg.msg_login_uri_code", "Please open the link and provide the code to complete registration:");
        $("#msgLoginInstruction").html(`${msg} ${uriEmbedded}, ${userCodeEmbedded}`);
        $("#msgLoginInstruction").show();
        $(document).progress();
        pollAccessToken(response.interval);
    } else {
        errMsg = parseError(response);
        $(document).alert($.localizeString("ETM.ops.an_error_occurred"),
        $.localizeString("ETM.strings.error","Error") + " " + response.err + ": <br/>" + errMsg);
        setButtonStatus("#btnContinue", true);
    }
}

function tryLogin() {
    var valid = formIsValid("#frmECOM");
    if(valid)
    {
        // Disable until succeeded or failed
        setButtonStatus("#btnContinue", false);
        $(document).progress($.localizeString("ETM.ops.register_with_ecom","Register with Evidence.com"), $.localizeString("ETM.ops.processing", "Processing..."), 100);

        var json=formToJSON("#content")
        json.token=$('meta[name="csrf-token"]').attr('content')
        new APIRequest(
            "secure/get-login-configuration-ecom",
            json,
            function(data) {
                data.err = data.err.toString();
                if (data.err == "0" && data.msg == "UniversalLogin") {
                    $(document).progress($.localizeString("ETM.ops.register_with_ecom","Register with Evidence.com"), $.localizeString("ETM.ops.poll_uri_code", "Retrieving activation link and code..."), 100);
                    new APIRequest("secure/get-login-uri-code", json, getLoginUriCode).exec()
                } else if (data.err == "0" && data.msg == "LegacyLogin") {
                    $(document).progress();
                    $("#btnContinue").hide();
                    $("#ecom_domain").attr("readonly", true);
                    $("#btnSave").show();
                    renderUsernameAndPassword(true);
                } else {
                    errMsg = parseError(data);
                    $(document).alert($.localizeString("ETM.ops.an_error_occurred"),
                    $.localizeString("ETM.strings.error","Error") + " " + data.err + ": <br/>" + errMsg);
                    setButtonStatus("#btnContinue", true)
                }
            }
        ).exec();
    }
}

$(document).ready(
    function()
    {
        var title = document.title;
        document.title += " - " + $.localizeString("ETM.ops.page_title", "General Operations");

        localizePage();
        $(".radio").buttonset();

        new APIRequest(
            "secure/get-config",
            null,
            function(data)
            {
                document.title = title + ` [${data.etm.etm.serial_num}] ` + " - " + $.localizeString("ETM.ops.page_title", "General Operations");

                setHeader(data);
                flatToForm("#content", flattenObj(data));

                $("#frmECOM").show();
                $("#rModeA").prop("checked",1)

                var agency = getData(data, "etm.operation.agency");
                if (agency != "null")
                    $("#ecom_agency").html(agency);

                if (data.etm.operation.authenticated == "1")
                {
                    $("#ecom_reg_done").show();
                    $("#ecom_domain").attr("readonly", true);
                    authenticated = true;
                    $("#btnContinue").hide();
                }
                else
                {
                    $("#btnContinue").show();
                }

                $("#msgLoginInstruction").hide();
                $("#msgLoading").hide();
                $("#btnResetReg").show();

                renderUsernameAndPassword(false)
            }
        ).exec();

        $("#btnSave").click(
            function(event)
            {
                event.preventDefault();
                saveECOM();
            }
        );

        $("#btnContinue").click(
            function(event)
            {
                event.preventDefault();
                if(authenticated) 
                {
                    $(document).prompt(
                        $.localizeString("ETM.ops.regenerate_keys_title","Regenerate Keys"),
                        $.localizeString("ETM.ops.regenerate_keys_query","You are already authenticated with Evidence.com, would you like to re-generate security keys?"),
                        function(isOk)
                        {
                            if (isOk)
                            {
                                $(document).progress($.localizeString("ETM.ops.register_with_ecom","Register with Evidence.com"),
                                                        $.localizeString("ETM.ops.generating_tokens","Generating Security Tokens..."), 100);
                                var json=formToJSON("#content")
                                json.token=$('meta[name="csrf-token"]').attr('content')
                                new APIRequest("secure/get-keys", json, keyResponse).exec();
                            }
                        }
                    );
                } 
                else 
                {
                    tryLogin()
                }
            }
        );

        $(".processKeyStrokes").keypress(
            function(event)
            {
                //check for enter key code
                if(event.keyCode == 13)
                {
                    // simply use btnSave:hidden as a flag to indicate which state since we are having only 2 states
                    if($("#btnSave").is(':hidden')){
                        $("#btnContinue").trigger("click"); 
                    }
                    else
                    {
                        $("#btnSave").trigger("click");
                    }
                }
            }
        );

        $("#btnResetReg").click(
            function(event)
            {
                // prevent default required since this button is in a form (below) for formatting purposes.
                event.preventDefault();

                new APIRequest("secure/reset-reg", request, function(data) {
                    setTimeout(reloadPage, 30000);
                    alertOperationResult(data,
                        $.localizeString("ETM.ops.reset_reg","Reset Registration"),
                        $.localizeString("ETM.ops.resetting_reg_dock", "Resetting registration of Dock to default. Reloading the page in 30 seconds."),
                        $.localizeString("ETM.strings.error","Error"),
                        $.localizeString("ETM.ops.reset_reg_failed", "Unable to Reset Registration"))
                }).exec();
            }
        );
    }
);

function parseError(data) {
    var errMsg = "";
    switch (data.err) {
        case "-1":
            errMsg += $.localizeString("ETM.strings.no_server_response", "No Response from server");
            break;
        case "100":
            errMsg += $.localizeString("ETM.strings.error_internal", "Internal Error");
            break;
        // Below errors come from https://git.taservs.net/dock/ecomapi/blob/eac01a9d6beef31247bf8e5b1266dc598c15784c/requests.h#L28
        case "1060":
            errMsg += data.msg;
            errMsg += $.localizeString("ETM.strings.invalid_hostname", " is not a valid hostname");
            break;
        case "10010":
            errMsg += $.localizeString("ETM.strings.login_failed", "Login failed");
            break;
        case "10020":
            errMsg += $.localizeString("ETM.strings.failed_auth", "Too many failed authentication attempts. Account temporarily suspended.");
            break;
        case "100301":
            errMsg += $.localizeString("ETM.strings.error_download", "Error downloading https");
            break;
        default:
            errMsg += $.localizeString("ETM.strings.unspecified_error", "An unspecified error has occurred: ");
        case "1": // REQUEST_ERROR https://git.taservs.net/dock/etm-1.0/blob/1fb047a66cfae207265546c57852629adb4b9748/common/ecom_admin.h#L39
        case "3": // AUTH_ERROR https://git.taservs.net/dock/etm-1.0/blob/1fb047a66cfae207265546c57852629adb4b9748/common/ecom_admin.h#L42
            errMsg += catchUnlocalized(data.msg);
            break;
    }
    return errMsg;
}
