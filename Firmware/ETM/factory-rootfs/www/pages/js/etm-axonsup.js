
var nextPage = null;

function setBlobs(data) {
    $("#datablob1").html(getData(data,"blob1"));
    $("#datablob2").html(getData(data,"blob2"));
}

$(document).ready(function() {
    updateTitle($.localizeString("ETM.axonsup.page_title", "Axon Support"));

    localizePage();

    new APIRequest("get-header", null, function(data) {
    setHeader(data);
    }).exec();

    new APIRequest("get-blobs", null, function(data) {
    setBlobs(data);
    }).exec();
});
