$(document).ready(function() {
    var title = document.title;
    document.title += " - " + $.localizeString("ETM.firmware.page_title", "Firmware Update");

    var request={ "token":$('meta[name="csrf-token"]').attr('content')}
    var fShowDetails = $.url().param('fwDetails');
    fShowDetails = fShowDetails || 0;
    localizePage();

    $("#btnVersionDetails").click(function(event) {
        event.preventDefault();
        $("#etmFwVersionDetailsRow").toggle();
    });

    $("#btnEtmUpdate").click(
        function(event)
        {
            // prevent default required since this button is in a form (below) for formatting purposes.
            event.preventDefault();

            new APIRequest("secure/etm-update", request, function(data)
            {
                alertOperationResult(data,
                                    $.localizeString("ETM.firmware.update_title","Firmware Update"),
                                    $.localizeString("ETM.firmware.etm_update_starting","Firmware Update has commenced. Check back in a few minutes to see if the version has updated..."),
                                    $.localizeString("ETM.strings.error","Error"),
                                    $.localizeString("ETM.firmware.update_failed", "Unable to start Firmware Update"))

                return false;
            }).exec();
            return false;
        }
    );

    $("#btnDvrUpdate").click(
        function(event)
        {
            // prevent default required since this button is in a form (below) for formatting purposes.
            event.preventDefault();
            new APIRequest("secure/dvr-update", request, function(data)
            {
                alertOperationResult(data,
                                        $.localizeString("ETM.firmware.update_title","Firmware Update"),
                                        $.localizeString("ETM.firmware.dvr_update_starting","Contacting Axon server to look for updates...Firmware update will be commenced after the DVR is done uploading files"),
                                        $.localizeString("ETM.strings.error","Error"),
                                        $.localizeString("ETM.firmware.update_failed", "Unable to start Firmware Update"))
                return false;
            }).exec();
            return false;
        }
    );
    new APIRequest("secure/get-config", null, function(data) {
        document.title = title + ` [${data.etm.etm.serial_num}] ` + " - " + $.localizeString("ETM.firmware.page_title", "Firmware Update");

        setHeader(data);
        var etmFwVersion = getData(data, "etm.etm.version");
        $("#etmFwVersion").html(etmFwVersion);

        var fwDetails = getData(data, "etm.etm.buildinfo")
        $("#etmFwVersionDetails").html(fwDetails);
        if (fShowDetails)
        {
            $("#etmFwVersionDetailsRow").show();
        }
        else
        {
            $("#etmFwVersionDetailsRow").hide();
        }

        function setFwVersion(deviceId, uciEntry)
        {
            var fwVersion = getData(data, uciEntry);
            if (!fwVersion || fwVersion == "null")
            {
                fwVersion = "0.0.0.0";
            } else if (fwVersion == "UNKNOWN")
            {
                fwVersion = $.localizeString("ETM.device_status_codes.unk", "Unknown");
            } else if (fwVersion == "Not released")
            {
                fwVersion = $.localizeString("ETM.firmware.not_released", "Not released");
            }
            $("#" + deviceId).html(fwVersion);
        }
        setFwVersion("flexFwVersion", "etm.firmware.taser_axon__taser_axon_lxcie");
        setFwVersion("bodyFwVersion", "etm.firmware.taser_axon__taser_body_cam");
        setFwVersion("body2FwVersion", "etm.firmware.taser_axon__taser_body_cam_2");
        setFwVersion("fleetFwVersion", "etm.firmware.taser_axon__taser_fleet_cam_1");
        setFwVersion("flex2FwVersion", "etm.firmware.taser_axon__taser_axon_flex_2");
        setFwVersion("flex2ctrlFwVersion", "etm.firmware.taser_axon__taser_axon_flex_2_ctrl");
        setFwVersion("taser7handleFwVersion", "etm.firmware.taser_ecd__taser_cew_7_handle");
        setFwVersion("taser10handleFwVersion", "etm.firmware.taser_ecd__taser_cew_10_handle");
        setFwVersion("taser7chargerFwVersion", "etm.firmware.taser_etm__taser_cew_7_dock_charger");

        setFwVersion("flexFwVersion_c", "etm.early_access_firmware.taser_axon__taser_axon_lxcie");
        setFwVersion("bodyFwVersion_c", "etm.early_access_firmware.taser_axon__taser_body_cam");
        setFwVersion("body2FwVersion_c", "etm.early_access_firmware.taser_axon__taser_body_cam_2");
        setFwVersion("fleetFwVersion_c", "etm.early_access_firmware.taser_axon__taser_fleet_cam_1");
        setFwVersion("flex2FwVersion_c", "etm.early_access_firmware.taser_axon__taser_axon_flex_2");
        setFwVersion("flex2ctrlFwVersion_c", "etm.early_access_firmware.taser_axon__taser_axon_flex_2_ctrl");
        setFwVersion("taser7handleFwVersion_c", "etm.early_access_firmware.taser_ecd__taser_cew_7_handle");
        setFwVersion("taser10handleFwVersion_c", "etm.early_access_firmware.taser_ecd__taser_cew_10_handle");
        setFwVersion("taser7chargerFwVersion_c", "etm.early_access_firmware.taser_etm__taser_cew_7_dock_charger");
    }).exec();
});
