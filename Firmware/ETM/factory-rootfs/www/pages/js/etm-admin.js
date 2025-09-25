
function snmpChange(){
    if($("#enable_snmp").is(":checked")){
        $("#frmSNMP").show("fast");

        // Set default auth and encrypt if not available yet.
        if($('input[name="etm.etm.snmp_auth"]:checked').val() == undefined){
        $('input[name="etm.etm.snmp_auth"]').val(["MD5"]);
        }
        if($('input[name="etm.etm.snmp_encrypt"]:checked').val() == undefined){
        $('input[name="etm.etm.snmp_encrypt"]').val(["NoPriv"]);
        }
    } else {
        $("#frmSNMP").hide("fast");
    }
}

function updateEcom(current_config) {
    new APIRequest("secure/update-ecom", null, function(data) {
    if (data.err != 0) return

    var new_config = flattenObj(data);
    var changes = [];
    for (var [key, value] of Object.entries(new_config)) {
        if (current_config[key] != value) {
        console.log('config is changed ' + key + ' from ' + current_config[key] + ' to ' + value);
        changes.push(key);
        }
    }
    if (changes.length == 0) return

    function doUpdate(){
        for (var k of changes) {
            var o = $(`[name="${k}"]`);  // find form input the have name as the changed value

            if (o.prop("tagName").toLowerCase() == 'select') {
                o.find('option').each(function (index, elem) {
                if (elem.innerText == new_config[k])  // it's tricky here, the text is display value not the submit value
                    elem.setAttribute("selected", "selected");
                else
                    elem.removeAttribute("selected");
                });
            }
            else o.val(new_config[k]);
        }
        $("#btnSave").click();
    }

    var msg = ""
    msg += `<p class="warn">${$.localizeString("ETM.admin.settings_changed.p1","Settings from your Agency has changed!")}</p>`;
    msg += `<p>${$.localizeString("ETM.admin.settings_changed.p2","Press [Update] button to apply the changes from your Agency to the Dock,")}</p>`;
    msg += `<p>${$.localizeString("ETM.admin.settings_changed.p3","Otherwise press [Cancel] then manually update your settings, the changes will be sync to your Agency.")}</p>`;
    msg += `<p class="warn">${$.localizeString("ETM.admin.settings_changed.p4","List of changes:")}</p>`;
    var changes_table = ""
    for (var k of changes) {
        var config_name = $(`[name="${k}"]`).parent().prev().text();
        changes_table += `<tr><td>${config_name}</td><td>${current_config[k]} &rarr; ${new_config[k]}</td></tr>`;
    }
    msg += '<table>' + changes_table + '</table>'
    msg += '<span class="ui-helper-hidden-accessible"><input type="text" />Hack to prevent button auto focus</span>'

    var $a = $('<div id="alertBox" class="dialog"></div>').appendTo('body');
    $a.html(msg);
    $a.dialog({
        title: $.localizeString("ETM.admin.settings_changed.title","Settings changed"), modal : true, minWidth: 450,
        close: function() {
        if ($(this).data("update")) doUpdate();
        },
        open: function() {
        $(this).data("update", false);
        },
        buttons : {
        'Update Dock': function() {
            $(this).data("update", true);
            $(this).dialog('close');
        },
        'Cancel': function() {
            $(this).dialog('close');
        },
        },
    });
    }).exec();
}

function getDeviceHomes(current_config){
    new APIRequest("secure/get-device-homes", null, function(data) {
    if (data.err != 0 || !data || !data.homes) return

    var o = $('#content form fieldset select[name="etm.etm.device_home"]');
    var t = "";
    data.homes.push({id:'none',name:'none'});
    var selected = o.val() || 'none';
    for (var i of data.homes) {
        t += `<option ${selected == i.name ? "selected":""} value="${i.id},${i.name}">${i.name}</option>`;
    }
    o.html(t);

    updateEcom(current_config);  // after get the device homes so the home-id is available for updating
    }
    ).exec();
}

// Default is hiding snmp password fields, aka display as ******
var showpass = false;

$(document).ready(function() {
    var config;
    var title = document.title;
    document.title += " - " + $.localizeString("ETM.admin.page_title", "Admin. Settings");

    localizePage();
    $("#frmSNMP").hide("fast");

    var request={ "token":$('meta[name="csrf-token"]').attr('content') }
    var last_snmp_user = "";

    new APIRequest("secure/get-config", null, function(data) {
    document.title = title + ` [${data.etm.etm.serial_num}] ` + " - " + $.localizeString("ETM.admin.page_title", "Admin. Settings");

    setHeader(data);
    config = flattenObj(data);
    flatToForm("#content", config);

    snmpChange();
    last_snmp_user = $("#snmp_username").val();
    last_web_admin_user = $("#web_admin_user").val();

    $("#content form fieldset select").each(function(index, elem) {
        if (config[elem.name]) {
        elem.innerHTML = `<option selected">${config[elem.name]}</option>`;
        }
    });

    getDeviceHomes(config);
    }).exec();

    $("#enable_snmp").on("click", snmpChange);
    $("#btnShowPass").click(function () {
        event.preventDefault();
        if (showpass = !showpass) {
            document.getElementById("snmp_password").type = "text";
            document.getElementById("snmp_encryption_password").type = "text";
        }
        else {
            document.getElementById("snmp_password").type = "password";
            document.getElementById("snmp_encryption_password").type = "password";
        }
    });

    $("#btnReboot").click(function() {
    new APIRequest("secure/etm-reboot", request, function(data) {
        setTimeout(function(){window.location.reload(true);}, 60000);
        alertOperationResult(data,
                            $.localizeString("ETM.admin.admin_title","Dock Administration"),
                            $.localizeString("ETM.admin.rebooting_msg","Rebooting, This will take approximately 60 seconds..."),
                            $.localizeString("ETM.strings.error","Error"),
                            data.msg)
    }, null).exec();

    return false;
    });

    $("#btnNewSSL").click(function() {
    new APIRequest("secure/ssl-regen", request, function(data) {
    setTimeout(function(){window.location.reload(true);}, 40000);
    alertOperationResult(data,
                        $.localizeString("ETM.admin.admin_title","Dock Administration"),
                        $.localizeString("ETM.admin.configuring_msg","Configuring, This will take approximately 40 seconds..."),
                        $.localizeString("ETM.strings.error","Error"),
                        data.msg)
    }, null).exec();
    return false;
    });

    $("#btnDiscard").click(function(){
        location.reload(true);
    });

    $("#btnSave").click(function() {
    var valid = formIsValid("#frmInfo") && formIsValid("#frmHeader") ;
    if($("#enable_snmp").is(":checked")) {
        valid = valid && formIsValid("#frmSNMP");
        if (valid && last_snmp_user != $("#snmp_username").val() && $("#snmp_password").val() == ""){
            valid = false;
            $(document).alert($.localizeString("ETM.admin.sections.snmp.error_title","Set SNMP Error"),
                            $.localizeString("ETM.admin.sections.snmp.error_no_password",
                                                "Changing the SNMP username requires a corresponding password."));
        }
    }

    if (valid) {
        $(document).progress($.localizeString("ETM.admin.admin_title","Dock Administration"), $.localizeString("ETM.admin.saving_settings","Saving settings..."), 100);
        var json=formToJSON("#content");
        json.token=$('meta[name="csrf-token"]').attr('content')
        new APIRequest("secure/set-config", json, function(data) {
        if (data.err == 0) {
            var admin_usr = $("#web_admin_user").val();
            var cur_pass = $("#web_admin_cur_pass").val();
            var new_pass = $("#web_admin_new_pass").val();

            if (last_web_admin_user != admin_usr) {
            if (isEmpty(cur_pass)) {
                $(document).alert($.localizeString("ETM.strings.error","Error"),
                                $.localizeString("ETM.admin.sections.password_change.error_no_password",
                                                    "Changing Administrator credentials requires current password."));
                return false;
            }
            else if (isEmpty(new_pass))
            {
                // allow changing administrator's username with providing current password only;
                // in this case we 'fake' new password and set it to current
                new_pass = cur_pass;
            }
            }

            if (!isEmpty(new_pass)) {
            if (isEmpty(cur_pass)) {
                $(document).alert($.localizeString("ETM.strings.error","Error"),
                                $.localizeString("ETM.admin.sections.password_change.error_no_password",
                                                    "Changing Administrator credentials requires current password."));
                return false;
            }
            else
            {
                new APIRequest("secure/set-passwd", { token: $('meta[name="csrf-token"]').attr('content'), web_admin_user: admin_usr, web_admin_cur_pass: cur_pass, web_admin_new_pass: new_pass}, function(data) {
                if (data.err == 0) {
                    setTimeout(function(){window.location.reload(true);}, 4000);
                }
                else {
                    var errMsg = $.localizeString(data.msgkey, data.msg);
                    $(document).alert($.localizeString("ETM.strings.error","Error"), errMsg);
                }
                }).exec();
            }
            }
            else
            {
            $(document).progress();
            window.location.reload(true);
            }
        }
        else
        {
            var errMsg = $.localizeString(data.msgkey, data.msg);
            $(document).progress();
            $(document).alert($.localizeString("ETM.admin.set_configuration_error_title","Set Configuration"),
                            $.localizeString("ETM.strings.error","Error") +
                            ": "+
                            errMsg);
        }
        }).exec();
    }
    return false;
    });
});
