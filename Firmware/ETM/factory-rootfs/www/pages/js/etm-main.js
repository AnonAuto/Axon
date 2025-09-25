// localize string jquery addin
(function() {
  var $ = jQuery;

  $.localizeString = function(key)
  {
        var langOpts = getLangOptions();
        var result = ""
        langOpts.callback = function(data, defcallback)
        {
            // ignore the default callback, lookup data for the key and return;
            result = $.localizeValueForKey(key, data, langOpts);
        }

        $.localize("lang", langOpts);
        return result;
  }

  $.fn.localizeString = $.localizeString;

})(this);

  $(document).ready(function() {
    setInterval(setTime, 1000);
  });

  function setHeader(data) {
    $("#title-agency").html(getData(data, "etm.etm.agency"));
    $("#agency-name").html(getData(data, "etm.etm.name"));
    $("#agency-loc").html(getData(data, "etm.etm.location"));
    var home = getData(data, "etm.etm.device_home")
    if (home != 'null' && home != 'none')
      $("#device-home").html(home + ' &mdash; ');
  }

  function setAccess(xml, path) {
    var v = xml.find("access "+path).text();
    setLight("#net_"+path, v, !v.startsWith("OK"));
    return v.startsWith("OK");
  }

  // set value of the element and the associated light indicator
  // e = element selector (not ID)
  // v = value to set
  // err = optional force error condition if true
  function setLight(e, v, err) {
    var my$ = $(e);

    if (my$.length > 0)
    {
        if (isEmpty(v)) v = "NA";
        if (v == "NA") err = true;

        if (err)
        {
          my$.html(v).addClass("error").click(statusError)
            .parent().find("td.icon").addClass("icon-error");
        }
        else
        {
          my$.html(v).removeClass("error").click(null)
            .parent().find("td.icon").addClass("icon-ok");
        }
        var langOpts = getLangOptions();
        my$.filter("[data-localize-lookup]").localize("lang", {
            pathPrefix: langOpts.pathPrefix,
            debug: langOpts.debug,
            language: langOpts.language,
            keycallback: function(elem) {
                return elem.data("localize-lookup") + "." + v;
            }
         } );
    } // else nothing to do
  }

  function reload_page() {
    location.reload(true);
  }

  function statusError() {
    $(this).attr("id");
  }

  function error_help(err) {
    $(document).htmlAlert($.localizeString("ETM.strings.device_error","Device Error"),
                 "err_" + err,
                 null,
                 true);
  }

  function default_response(data, fn) {
    $(document).progress();
    if (data.err == "0") {
      $(document).alert($.localizeString("ETM.strings.finished","Finished"), $.localizeString("ETM.strings.operation_complete_success","The operation completed successfully."), fn);
    } else {
      var errMsg = "";
        switch (data.err) {
            case "1060":
                errMsg += data.msg;
                errMsg += $.localizeString("ETM.strings.invalid_hostname", " is not a valid hostname");
                break;
            case "10010":
                errMsg += $.localizeString("ETM.strings.login_failed", "Login failed");
                break;
            case "-1":
                errMsg += $.localizeString("ETM.strings.no_server_response", "No Response from server");
                break;
            case "100301":
                errMsg += $.localizeString("ETM.strings.error_download", "Error downloading https");
                break;
            case "10020":
                errMsg += $.localizeString("ETM.strings.failed_auth", "Too many failed authentication attempts. Account temporarily suspended.");
                break;
            default:
                errMsg += $.localizeString("ETM.strings.unspecified_error", "An unspecified error has occurred: ");
                errMsg += catchUnlocalized(data.msg);
                break;
      }
      $(document).alert($.localizeString("ETM.strings.an_error_occurred","An error occurred"), $.localizeString("ETM.strings.error","Error") + " "+data.err+": <br/>"+errMsg);
    }
  }

  var HIDDEN = "****";
  function make_row(cls, items) {
    var h = '<tr class="'+cls+'">';
    for (i=0;i<items.length;i++)
    {
      //check if cell data is supposed to be secured. if so, add link to secure
      //script which will require authentication
      if(items[i] == HIDDEN)
      {
        //use single quotes to allow a double quote inside the string value
        h += '<td nowrap><a class="btnShowHidden">' +
            $.localizeString("ETM.index.sections.devices.hidden_info","Click to see data")+ '</td>';
      }
      else
      {
        h += "<td nowrap>"+items[i]+"</td>";
      }
    }
    h += "</tr>";
    return h;
  }

function make_row_taser(cls, items, model) {
  var is_charger = model === "taser_cew_7_dock_charger";
  var is_battery = (model === "taser_cew_7_battery" || model === "taser_cew_7_battery_correctional" ||
                    model === "taser_cew_battery_haptic");
  var is_ble = model === "taser_cew_7_ble";
  var h;
  if (is_charger) {
    h = '<tr class="'+cls+'">';
  }
  else {
    h = '<tr class="'+cls+' no-border-bottom">';
  }
  for (i=0;i<items.length;i++)
  {
    // no owner for charger and ble, no serial number for ble
    if ((i == 0 && is_ble) || (i == 3 && (is_charger || is_ble))) {
        items[i] = "";
    }
    //check if cell data is supposed to be secured. if so, add link to secure
    //script which will require authentication
    if(items[i] == HIDDEN)
    {
      //use single quotes to allow a double quote inside the string value
      h += '<td nowrap><a class="btnShowHidden">' +
        $.localizeString("ETM.index.sections.devices.hidden_info","Click to see data")+ '</td>';
    }
    else if (is_charger) {
      h += "<td nowrap class='t7-charger'>"+items[i]+"</td>";
    }
    else if (is_battery) {
      h += "<td nowrap>"+items[i]+"</td>";
    }
    else {
      h += "<td nowrap class='no-padding-top'>"+items[i]+"</td>";
    }
  }
  h += "</tr>";
  return h;
}

  var g_last_status;
  var OFFLINE_USER = "[OFFLINE]";

  function setStatus(data) {
    var xmlDoc = $.parseXML( data.xml ), $xml = $( xmlDoc );
    g_last_status = $xml;
  }

function textFromStatus(statusCode, dev_code)
{
    var status = "";
    var scls = "ok"

    switch (statusCode)
    {
    case "new":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.new", "New Device");
        break;

    case "unsupported":
        scls = "error";
        status = $.localizeString("ETM.device_status_codes.unsupported", "Unsupported");
        break;

    case "plugin":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.plugin", "Connecting");
        break;

    case "init":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.init", "Initializing");
        break;

    case "devid":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.devid", "Identifying");
        break;

    case "register":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.register", "Registering");
        break;

    case "summary":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.summary", "Get Summary")
        break;

    case "cfg":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.cfg", "Configuring");
        break;

    case "logsend":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.logsend", "Uploading Log");
        break;

    case "inventory":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.inventory", "Inventory");
        break;

    case "wait":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.wait", "Waiting");
        break;

    case "proc":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.proc", "Transferring File");
        break;

    case "fwupdate":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.fwupdate", "Updating Firmware");
        break;

    case "sys_maint":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.sys_maint", "System Maintenance");
        break;

    case "device_maint":
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.device_maint", "Device Maintenance");
        break;


    case "chg":
        scls = "ok"
        status = $.localizeString("ETM.device_status_codes.chg", "Charging");
        break;

    case "rdy":
        scls = "ok"
        status = $.localizeString("ETM.device_status_codes.rdy", "Ready");
        break;

    case "fwdone" :
        scls = "notice";
        status = $.localizeString("ETM.device_status_codes.fwdone", "Firmware Updated");
        break;

        // No device Submenu
    case "del":
        scls = "ok"
        status = $.localizeString("ETM.device_status_codes.del", "Removing");
        break;

    // Errors stati
    case "lost":
        scls = "error";
        status = $.localizeString("ETM.device_status_codes.lost", "Lost Communication");
        break;
    case "unk":
        scls = "error";
        status = $.localizeString("ETM.device_status_codes.unk", "Unknown");
        break;
    case "err":
        scls = "error";
        status = $.localizeString("ETM.device_status_codes.err", "Error (Retry pending)");
        break;
    case "fail":
        scls = "error";
        status = $.localizeString("ETM.device_status_codes.fail", "Error");
        break;
    case "net_retry":
        scls = "error";
        status = $.localizeString("ETM.device_status_codes.net_retry", "Retry Network Connection");
        break;
    case "nonet":
        scls = "error";
        status = $.localizeString("ETM.device_status_codes.nonet", "Network Down");
        break;
    case "inact":
        scls = "error";
        status = $.localizeString("ETM.device_status_codes.inact", "Inactive");
        break;
    }

    var so = { scls: scls, status: status };
    return so;
}

  var id_counter = 0;
  function setStatusEx(data) {
    var xmlDoc = $.parseXML( data.xml ), $xml = $( xmlDoc );
    g_last_status = $xml;

    setLight("#net_mode", $xml.find("net").attr("mode"));
    setLight("#net_ip", $xml.find("net ip").text());
    setLight("#net_gateway", $xml.find("net gateway").text());
    var dns = "";
    $xml.find("net dns").each(function() {
      dns += ((dns == "") ? "" : ", ") + $(this).text();
    });
    setLight("#net_dns", dns);

    $("#etm_mac").html($xml.find("net mac").text());
    $("#etm_serial").html($xml.find("serial_num:first").text());

    setAccess($xml, "https");
    if (setAccess($xml, "ntp"))
        $("#net_ntp").html($xml.find("access ntp").text().substr(3));
    setAccess($xml, "ftp")
    setAccess($xml, "gw");

    if (setAccess($xml, "ecom", true))
      $("#net_ecom").html($.localizeString("ETM.index.sections.networking.active", "Active")+" ("+$xml.find("agency name").text()+")");
    else
      $("#net_ecom").html($.localizeString("ETM.index.sections.networking.not_registered", "Not registered"));
    $("tr.dev").remove();

    $xml.find("devices device").each(function () {
      var d = $(this), s = d.attr("status"), status = "", info = "";
      var extra = "";

      if (s == "wait") {
        var count = d.find("events").attr("count");
        if (count != 0)
          info = " (" + count + ")";
      }
      if (s == "proc")
      {
        var t = d.find("transfer");
        if (t)
        {

            // if a valid file number and count is given then display that information also.
            var file_num = t.attr("file_num");
            var file_count = t.attr("file_count");
            if (file_num != undefined && file_count != undefined) {

                var rate = (Number(t.attr("bytes_per_sec")) * 8 / 1024).toFixed(2);

                if (rate <= 0 || rate > (256 * 1024) || rate == "NaN")
                    rate = $.localizeString("ETM.strings.calculating_rate","Calculating...");
                else
                    rate = ""+rate+" " + $.localizeString("ETM.strings.kbps","kbps");

                info = " " + file_num + "/" + file_count + " ["+rate+"]";
            }
        }
      }

      var dev_code = d.attr("code");
      var ser = d.find("serial_num").text();
      var fw = d.find("firmware version sw").text();
      var owner = d.find("owner").text();
      if (d.find("owner").attr("hidden") == "true")
         owner = HIDDEN;
      else if (owner.trim() == "") // if empty string then camera is not assigned
        owner = $.localizeString("ETM.strings.unassigned","Unassigned");

      // if the device is not an old Flex era camera, no submenu...
      var model = d.find("model").text();
      var is_taser = model.startsWith("taser_cew");
      var so = textFromStatus(s, dev_code)
      scls = so.scls;
      status = so.status;

      // Display charging state with remaining battery percent for cam device with "battery" field.
      if (s == "chg" || ((model == "taser_cew_7_battery" || model == "taser_cew_7_battery_correctional" || model === "taser_cew_battery_haptic") && s == "rdy"))
      {
        var batt = d.find("battery").text();
        if (batt !== null) {
          // T7 Charger uses negative battery value to present Capacity Check progress
          if (batt < 0) {
            batt = -batt
            status = $.localizeString("ETM.device_status_codes.capchk", "Capacity Check")
          }
          status += "<bdo>" + " (" + batt + "\%)" + "</bdo>";
        }
      }

      if ((model == "taser_cew_7_handle" || model == "taser_cew_7_handle_single_laser_short_range" || model == "taser_cew_8_handle") && s == "logsend") {
        batt = d.find("battery").text();
        if (batt)
          status += "<bdo>" + " (" + batt + "\%)" + "</bdo>";
      }

      if ((model == "taser_cew_7_battery" || model == "taser_cew_7_battery_correctional" || model == "taser_cew_battery_haptic") && s == "inventory") {
        status = $.localizeString("ETM.device_status_codes.logerase", "Erasing Log")
        batt = d.find("battery").text();
        if (batt)
          status += "<bdo>" + " (" + batt + "\%)" + "</bdo>";
      }

      if (scls == "error")
      {
        var last_err = d.find("last_error").text();
        if (!isEmpty(last_err))
            info = ' &nbsp;<span class="cursor-pointer">[' + $.localizeString("ETM.strings.click_for_details","Click for details") + ']</span>';
      }

      var h;
      var ser_mask = ser + '-' + id_counter++;
      if (is_taser) {
        h = make_row_taser("dev", [ser, d.find("name").text(), fw, owner,
          '<span id="'+ser_mask+'" class="'+scls+'">'+status+info+'</span>'+extra],
          model);
      } else {
        h = make_row ("dev", [ser, d.find("name").text(), fw, owner,
              '<span id="'+ser_mask+'" class="'+scls+'">'+status+info+'</span>'+extra]);
      }
      $("#index-status-device").append(h);

      if (scls == "error") {
        $(document).on("click", '#'+ser_mask, function() {
          error_help(last_err);
        });
      }
    });

    $(".btnShowHidden").click(function() {
      getStatus(true);
    });

  }

  function goNet() { if ($(this).data("OK") == true) go("/secure/network.html"); }
  function goOps() { if ($(this).data("OK") == true) go("/secure/ops.html"); }

  function cfgWizard(data) {
    var xmlDoc = $.parseXML( data.xml ), $xml = $( xmlDoc );
    var mode = $xml.find("net").attr("mode");
    if (isEmpty(mode))
      $(document).htmlAlert($.localizeString("ETM.configassist.title","Configuration Assistant") , "NO_STATUS");
    else if ($("#net_ip").hasClass("error"))
      if (mode == "dynamic") $(document).htmlAlert($.localizeString("ETM.configassist.title","Configuration Assistant") , "NO_IP_DYNAMIC", goNet);
      else $(document).htmlAlert($.localizeString("ETM.configassist.title","Configuration Assistant") , "NO_IP_STATIC", goNet);
    else if ($("#net_gateway").hasClass("error"))
       $(document).htmlAlert($.localizeString("ETM.configassist.title","Configuration Assistant") , "NO_GATEWAY", goNet);
    else if ($("#net_dns").hasClass("error"))
       $(document).htmlAlert($.localizeString("ETM.configassist.title","Configuration Assistant") , "NO_DNS", goNet);
    else if ($("#net_ntp").hasClass("error"))
       $(document).htmlAlert($.localizeString("ETM.configassist.title","Configuration Assistant") , "NO_NTP");
    else if ($("#net_https").hasClass("error"))
       $(document).htmlAlert($.localizeString("ETM.configassist.title","Configuration Assistant") , "NO_HTTPS");
    else if ($("#net_ecom").hasClass("error"))
       $(document).htmlAlert($.localizeString("ETM.configassist.title","Configuration Assistant") , "NO_ECOM", goOps);
  }

    function ReplaceURLParam($url, param, newval)
    {
        if ($url.attr('fragment'))
        {
            console.log("ASSERT: ReplaceURLParam not tested with fragment");
        }

        var newurl = "";
        if ($url.param(param))
        {
            var url = $url;
            newurl = url.attr('protocol') + "://" +
                     url.attr('host') +
                     ((url.attr('port') != "") ? ":"+ url.attr('port') : "") +
                     url.attr('path') +
                     '?';

            // now replace the parameters except the one we are looking for
            var params = url.param();
            var i = 0;
            for(var p in params)
            {
                if (i++)
                {
                    newurl += '&';
                }

                newurl += p + '='
                if (p == param)
                {
                    newurl += newval;
                }
                else
                {
                    newurl += params[p];
                }
            }

            newurl += ((url.attr('fragment') != "") ? "#"+ url.attr('fragment') : "");
        }
        else
        {
            var params = $url.param();
            // count existing parameters
            var count = 0;
            for (var p in params)
            {
                if (p != "" && params.hasOwnProperty(p))
                {
                    count++;
                    break;
                }
            }

            newurl = "" + $url.attr('source') +
                     ((count > 0) ? "&" : "?") +
                     param + "=" + newval;
        }
        return newurl;
    }

    function updateLanguage(thelist)
    {
        window.location.href = ReplaceURLParam($.url(), 'lang', thelist.value);
    }

    // navigate to a URL after associating language and debugging options with the
    // given jQuery URL object
    function go($url)
    {
        if (typeof $url === "string")
        {
            $url = $.url($url);
        }

        var langOpts = getLangOptions();
        var newurl =  ReplaceURLParam($url, 'lang', langOpts.language);
        if (langOpts.debug == 1)
        {
            newurl = ReplaceURLParam($.url(newurl), "langdebug", langOpts.debug);
        }
        document.location.href = newurl;
    }


    function getLangOptions()
    {
        var langdebug = $.url().param('langdebug');
        langdebug = langdebug || 0;

        var langOverride = $.url().param('lang');
        langOverride = langOverride || $.defaultLanguage;
        langOverride = langOverride.toLowerCase();

        var langOptions = {
            pathPrefix : "/lang",
            debug: langdebug,
            language: langOverride
        }
        return langOptions;
    }

    function localizePage()
    {
        var langOpts = getLangOptions();
        $("#langchoice").val(langOpts.language);
        $("[data-localize]").localize("lang", langOpts );

        $(".languageLink").click(
            function(e)
            {
                go($(this).url());
                // no default
                event.preventDefault();
                return false;
            }
            );
    }

    function updateTitle(localizedPageName)
    {
        var titleInitialLength = document.title.length;

        if (typeof localizedPageName == "string" && localizedPageName !== null)
        {
            document.title += (" - " + localizedPageName);
        }

        new APIRequest("get-status", null, function(data)
        {
            var xmlDoc = $.parseXML(data.xml), $xml = $(xmlDoc);
            var etmSerial = $xml.find("serial_num:first").text();
            if (etmSerial !== null)
            {
                document.title = document.title.substr(0, titleInitialLength) + (" [" + etmSerial + "]") + document.title.substr(titleInitialLength);
            }
        }).exec();
    }

// Extra localization strings
// These were in the translation list but are used within jQuery -
// Still need to figure out how to get the localized values into the code, but
// a translation was returned so we need a corresponding placeholder for it.
// $.localizeString("ETM.strings.please_complete_manditory","Please complete this mandatory field.");
// $.localizeString("ETM.strings.ok","OK");
// $.localizeString("ETM.strings.cancel","Cancel");
// $.localizeString("ETM.strings.axon_flex","Axon Flex");
//

$(document).ready(function(){
    $("#langchoice").change(
        function(){
        updateLanguage(this);
    });
});
