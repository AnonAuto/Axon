/************************************************
 * Prototypes
 ************************************************/
Number.prototype.toRad = function() {
    return this * Math.PI / 180;
  }

String.prototype.trim = function() {
  return this.replace(/^\s+|\s+$/g,"");
}

String.prototype.merge = function(arr) {
  var s = this, i, pattern, re, n = arr.length;
  for (i = 0; i < n; i++) {
    pattern = "\\{" + i + "\\}";
    re = new RegExp(pattern, "g");
    s = s.replace(re, arr[i]);
  }
  return s;
}

String.prototype.startsWith = function(s) {
  if (isEmpty(s) || isEmpty(this)) return false;
  return this.substr(0, s.length) == s;
}

String.prototype.endsWith = function(suffix) {
    return this.indexOf(suffix, this.length - suffix.length) !== -1;
};

Array.prototype.contains = function(s) {
  for (var i=0,n=this.length;i<n;i++)
    if (this[i] == s) return true;
  return false;
}

Date.prototype.toJSON = function (key) {
  return this.getTime();
};

Math.rnd = function(n, l) {
  return Math.round(n*Math.pow(10, l)) / Math.pow(10,l);
}

// Loc_todo: Unknown
String.prototype.map = function(map) {
  map = (typeof map == 'string') ? {"null" : map} : (map) || {"null" : "Unknown"};
  var v= map[getData(this)];
  return (v != undefined) ? v : this.substr(0); // this is needed for jQuery, no idea why...
}

/************************************************
 * Logging
 ************************************************/

function Log(m) {if (window.console) window.console.log("INFO: "+m)}
function LogErr(m) {if (window.console) window.console.log(" ERR: "+m)}
function LogObj(m, o) {if (window.console) window.console.log(" OBJ: "+(m ? m : "")+" %o", o)}

/************************************************
 * Helpers
 ************************************************/


function isEmpty(s) { return (!s) || (s == "") || (s == " "); }
function emptyIsBlank(s) { return isEmpty(s) ? "" : s;}

// Loc_todo: null
function getData(o, n) {
  if (n) {
    var idx = -1;
    Log(n);
    if (n.endsWith(']')) {
      var p = n.lastIndexOf('[');
      idx = Number(n.substr(p+1, n.length-p-2));
      n = n.substring(0, p);
    }
    var sa = n.split("."), c = o;
    for (var j=0,s=sa.length;j<s;j++)
      if (isEmpty(c[sa[j]])) return "null";
      else c = c[sa[j]];
    return (idx == -1) ? String(c) : String(c[idx]);
  }
  return isEmpty(o) ? "null" : String(o);
}

// caution with zero values - need to be given as string "0", else filtered
// as empty.
function setData(o, p, v) {
  function set(r2, n, v) {
    if (n.endsWith(']')) {
      var p = n.lastIndexOf('[');
      var i = Number(n.substr(p+1, n.length-p-2));
      n = n.substring(0, p);
      r2[n] = r2[n] || [];
      r2[n][i] = v;
    } else
      r2[n] = v;
  }

  if (isEmpty(v))
      Log("Set: "+p + " = Skipped");
  else {
    // Log("Set: "+p + " = " + v); //uncomment this to help with debugging
    var s = p.split(".");
    if (s.length == 1)
        set(o, s[0], v);
    else {
      var r2 = o;
      while (s.length > 0) {
        var n = s.shift();
        if (s.length != 0)
        {
            r2[n] = r2[n] || {};
            r2 = r2[n];
        }
        else
            set(r2, n, v);
      }
    }
  }
}

function isNull(f, m) {
  f = f.trim();
  if ((f == null) || (f == "")) {
    $(document).alert("OOPS!", m);
    return true;
  }
  return false;
}


function makeHTTPS(s) {
  if (!s) return "";
  if (document.location.protocol != "https:") return s;
  if (s.startsWith("http://")) return "https://"+s.substr(7);
  return s;
}

var urlParams = {};
(function () {
    var e,
        d = function (s) { return decodeURIComponent(s.replace(/\+/g, " ")); },
        q = window.location.search.substring(1),
        r = /([^&=]+)=?([^&]*)/g;

    while (e = r.exec(q))
       urlParams[d(e[1])] = d(e[2]);
})();


/************************************************
 * UI: Alert Box
 ************************************************/
function alertOperationResult(data, successTitle, successMsg, failTitle, failMsg) {
    if (data.err == 0)
    {
        $(document).alert(successTitle, successMsg)
    }
    else
    {
        $(document).alert(failTitle, failMsg);
    }
}

function catchUnlocalized(msg) {
  switch (msg) {
    case "No Response from server":
      msg = $.localizeString("ETM.strings.no_server_response", msg);
      break;
    case "Authentication failed":
      msg = $.localizeString("ETM.strings.authentication_failed", msg);
      break;
    case "Invalid username or password":
      msg = $.localizeString("ETM.cgi.invalid_auth", msg);
      break;
    case "No domain specified":
      msg = $.localizeString("ETM.cgi.invalid_domain", msg);
      break;
    case "Request is null or invalid":
      msg = $.localizeString("ETM.strings.invalid_request", msg);
      break;
    default:
      break;
  }
  return msg;
}

(function($) {
    $.fn.alert = function(title, msg, cb) {
      if (isEmpty(msg)) return;
      msg = catchUnlocalized(msg);

      var $a = $("#alertBox");
      if ($a.length == 0) $a = $('<div id="alertBox" class="dialog"></div>').appendTo('body');
      $a.html("<p>"+msg+"</p>");
      $a.dialog({
        width: 320, height: 250,
        autoOpen: true, modal : true, resizable: false, zIndex : 90000,
        title: title,
        buttons : {
          'OK': function() {
            $(this).dialog('close');
          }
        },
        close: cb
      });
    };



  $.fn.progress = function(title, msg, pct) {
      if (isEmpty(msg)) {
        $("#alertBox").dialog("close");
        $("#alertBox").remove();
        return;
      }

      var $a = $("#alertBox");
      if ($a.length == 0) $a = $('<div id="alertBox" class="dialog"></div>').appendTo('body');
      $a.html("<p>"+msg+'</p><div class="progress"></div>');
      $a.dialog({
        width: 320, height: 200,
        autoOpen: true, modal : true, resizable: false, zIndex : 90000, closeOnEscape: false,
        title: title,
        buttons : { },
        open: function() {
          $(this).parent().children().children('.ui-dialog-titlebar-close').hide();
          $("#alertBox .progress").progressbar({value: 100});
        }
      });
    };

  // Loc_done:OK & Cancel are data names
  $.fn.htmlAlert = function(title, e, cb, can_cancel) {
    var msg
    if (e.startsWith("err_msg=")) msg = e.substring(8)
    else msg = $("#"+e).html()
    if (isEmpty(msg)) return;

      var $a = $("#alertBox");
      if ($a.length == 0) $a = $('<div id="alertBox" class="dialog"></div>').appendTo('body');
      $a.html(msg);
      var btn_list = { 'OK': function() {
          $(this).data("OK", true);
          $(this).dialog('close');
        }
      };
      if (can_cancel) btn_list.Cancel = function() { $(this).data("Cancel", true); $(this).dialog('close'); };
      $a.dialog({
        width: 540, height: 370,
        autoOpen: true, modal : true, resizable: false, zIndex : 90000,
        title: title,
        buttons : btn_list,
        open: function() {
          $(this).data("OK", false);
          $(this).data("Cancel", false);
        },
        close: cb
      });
  }

  $.fn.prompt = function(title, msg, cb) {
    var $a = $("#alertBox");
    if ($a.length == 0) $a = $('<div id="alertBox" class="dialog"></div>').appendTo('body');
    $a.html(msg);
    $a.dialog({
      width: 300, height: 200,
      autoOpen: true, modal : true, resizable: false, zIndex : 90000,
      title: title,
      buttons : [
        {
            text: $.localizeString("ETM.common.yes", "Yes"),
            onclick: function() {
              $(this).data("OK", true);
              $(this).dialog('close');
            }
        },
        {
            text: $.localizeString("ETM.common.no", "No"),
            onclick: function() {
             $(this).dialog('close');
            }
        }
      ],
      open: function() {
        $(this).data("OK", false);
      },
      close: function() {
        if (cb) cb($(this).data("OK"));
      }
    });
  };

  $.fn.input = function(title, msg, cb) {
    var $a = $("#alertBox");
    if ($a.length == 0) $a = $('<div id="alertBox" class="dialog"></div>').appendTo('body');
    $a.html("<p>"+msg+"</p><input type='text' id='dlgAlertInput'/>");
    $a.dialog({
      width: 320, height: 250,
      autoOpen: true, modal : true, resizable: false, zIndex : 90000,
      title: title,
      buttons : {
        'OK': function() {
          $(this).data("OK", true);
          $(this).dialog('close');
        },
        'Cancel': function() {
          $(this).dialog('close');
        }
      },
      open: function() {
        $(this).data("OK", false);
      },
      close: function() {
        if (cb) cb($(this).data("OK") ? $("#dlgAlertInput").val() : null);
      }
    });
  };
})(jQuery);


jQuery.fn.choose = function(f) {
    $(this).bind('choose', f);
};


jQuery.fn.file = function() {
    return this.each(function() {
        var btn = $(this);
        var pos = btn.offset();

        function update() {
            pos = btn.offset();
            file.css({
                'top': pos.top,
                'left': pos.left,
                'width': btn.width(),
                'height': btn.height()
            });
        }

        btn.mouseover(update);

        var hidden = $('<div></div>').css({
            'display': 'none'
        }).appendTo('body');

        var file = $('<div><form></form></div>').appendTo('body').css({
            'position': 'absolute',
            'overflow': 'hidden',
            '-moz-opacity': '0',
            'filter':  'alpha(opacity: 0)',
            'opacity': '0',
            'z-index': '2'
        });

        var form = file.find('form');
        var input = form.find('input');

        function reset() {
            var input = $('<input type="file" multiple>').appendTo(form);
            input.change(function(e) {
                input.unbind();
                input.detach();
                btn.trigger('choose', [input]);
                reset();
            });
        };

        reset();

        function placer(e) {
            form.css('margin-left', e.pageX - pos.left - offset.width);
            form.css('margin-top', e.pageY - pos.top - offset.height + 3);
        }

        function redirect(name) {
            file[name](function(e) {
                btn.trigger(name);
            });
        }

        file.mousemove(placer);
        btn.mousemove(placer);

        redirect('mouseover');
        redirect('mouseout');
        redirect('mousedown');
        redirect('mouseup');

        var offset = {
            width: file.width() - 25,
            height: file.height() / 2
        };

        update();
    });
};

  function pad(x) {
    return (x < 10) ? "0"+x : x;
  }

  function setTime() {
    var d = new Date();
    $("#ddate").html((new Date()).toLocaleDateString());
    $("#dtime").html(pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":"+ pad(d.getSeconds()))
  }

/************************************************
 * Form Processing
 ************************************************/
function formToJSON(f, o) {
  if (typeof f === 'string')
      f = $(f);

  var a = f.find(":input:not([type=checkbox])").serializeArray();
  var b = f.find("select").serializeArray();
  $.extend(a,b);
  var r = o || {};

  //if the name starts with "_" it is ignored
  while (a.length > 0) {
    var o = a.shift();
    if (o.name.charAt(0) != "_")
        setData(r, o.name, o.value);
  }

  // jQuery uses the W3C concept of "successful_controls" for serializeArray,
  // which includes only checked checkboxes.  However, we want to treat them
  // as always-present booleans, so need to query for them separately.
  var checkboxes = f.find("input:checkbox");
  for(var i=0; i < checkboxes.length; i++)
  {
    var o = checkboxes.get(i);
    if (o.name.charAt(0) != "_")
        setData(r, o.name, o.checked ? "1":"0");
  }

  return r;
}

function flattenObj(json, prefix, arr) {
  prefix = prefix || '';
  arr = arr || [];

  for (n in json) {
    var o = json[n];

    if (o instanceof Array) arr[prefix+n+"[]"] = o;
    else if (typeof o === 'object') flattenObj(o, prefix+n+".", arr);
    else arr[prefix+n] = o;
  }
  return arr;
}

function flatToForm(f, arr) {
  if (f != null) {
    if (typeof f === 'string') f = $(f);

    f.find(":input").each(function() {
      var $this = $(this), n = $this.attr('name');
      if (!isEmpty(n)) {
        if (n.charAt(0) != "_") {
          v = getData(arr[n]).map("");
          Log(n+" = "+v);
          //fix for bug in jQuery, doesn't handle radio/checkboxes correctly
          if($this[0].type == "radio")
          {
              if (isEmpty(v))
                  v = "";
              $this.val([v]);
          }
          else if ($this[0].type == "checkbox")
          {
              // simplistic - support only 0/1.  Anything except 1 is unchecked.
              // string is ok
              $this.prop('checked', (v == 1));
          }
          else
          {
              $this.val(v);
          }
        }
      }
    });
  }
}

function jsonToForm(f, json, prefix, arr) {
  arr = flattenObj(json, prefix, arr);
  flatToForm(f, arr);
}


/******************************************************************************
 * JSON
 ******************************************************************************/

function reviver(key, value) {
  return value;
}


if (!this.JSON) {
    this.JSON = {};
}

(function () {

    function f(n) {
        // Format integers to have at least two digits.
        return n < 10 ? '0' + n : n;
    }

    if (typeof Date.prototype.toJSON !== 'function') {

        Date.prototype.toJSON = function (key) {

            return isFinite(this.valueOf()) ?
                   this.getUTCFullYear()   + '-' +
                 f(this.getUTCMonth() + 1) + '-' +
                 f(this.getUTCDate())      + 'T' +
                 f(this.getUTCHours())     + ':' +
                 f(this.getUTCMinutes())   + ':' +
                 f(this.getUTCSeconds())   + 'Z' : null;
        };

        String.prototype.toJSON =
        Number.prototype.toJSON =
        Boolean.prototype.toJSON = function (key) {
            return this.valueOf();
        };
    }

    var cx = /[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,
        escapable = /[\\\"\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,
        gap,
        indent,
        meta = {    // table of character substitutions
            '\b': '\\b',
            '\t': '\\t',
            '\n': '\\n',
            '\f': '\\f',
            '\r': '\\r',
            '"' : '\\"',
            '\\': '\\\\'
        },
        rep;


    function quote(string) {

        escapable.lastIndex = 0;
        return escapable.test(string) ?
            '"' + string.replace(escapable, function (a) {
                var c = meta[a];
                return typeof c === 'string' ? c :
                    '\\u' + ('0000' + a.charCodeAt(0).toString(16)).slice(-4);
            }) + '"' :
            '"' + string + '"';
    }


    function str(key, holder) {
        var i,          // The loop counter.
            k,          // The member key.
            v,          // The member value.
            length,
            mind = gap,
            partial,
            value = holder[key];
        if (value && typeof value === 'object' &&
                typeof value.toJSON === 'function') {
            value = value.toJSON(key);
        }
        if (typeof rep === 'function') {
            value = rep.call(holder, key, value);
        }
        switch (typeof value) {
        case 'string':
            return quote(value);

        case 'number':
            return isFinite(value) ? String(value) : 'null';
        case 'boolean':
        case 'null':
            return String(value);
        case 'object':
            if (!value) {
                return 'null';
            }
            gap += indent;
            partial = [];
            if (Object.prototype.toString.apply(value) === '[object Array]') {
                length = value.length;
                for (i = 0; i < length; i += 1) {
                    partial[i] = str(i, value) || 'null';
                }
                v = partial.length === 0 ? '[]' :
                    gap ? '[\n' + gap +
                            partial.join(',\n' + gap) + '\n' +
                                mind + ']' :
                          '[' + partial.join(',') + ']';
                gap = mind;
                return v;
            }
            if (rep && typeof rep === 'object') {
                length = rep.length;
                for (i = 0; i < length; i += 1) {
                    k = rep[i];
                    if (typeof k === 'string') {
                        v = str(k, value);
                        if (v) {
                            partial.push(quote(k) + (gap ? ': ' : ':') + v);
                        }
                    }
                }
            } else {
                for (k in value) {
                    if (Object.hasOwnProperty.call(value, k)) {
                        v = str(k, value);
                        if (v) {
                            partial.push(quote(k) + (gap ? ': ' : ':') + v);
                        }
                    }
                }
            }
            v = partial.length === 0 ? '{}' :
                gap ? '{\n' + gap + partial.join(',\n' + gap) + '\n' +
                        mind + '}' : '{' + partial.join(',') + '}';
            gap = mind;
            return v;
        }
    }
    if (typeof JSON.stringify !== 'function') {
        JSON.stringify = function (value, replacer, space) {
            var i;
            gap = '';
            indent = '';
            if (typeof space === 'number') {
                for (i = 0; i < space; i += 1) {
                    indent += ' ';
                }
            } else if (typeof space === 'string') {
                indent = space;
            }
            rep = replacer;
            if (replacer && typeof replacer !== 'function' &&
                    (typeof replacer !== 'object' ||
                     typeof replacer.length !== 'number')) {
                throw new Error('JSON.stringify');
            }
            return str('', {'': value});
        };
    }

    if (typeof JSON.parse !== 'function') {
        JSON.parse = function (text, reviver) {
          var j;

          function walk(holder, key) {
                var k, v, value = holder[key];
                if (value && typeof value === 'object') {
                    for (k in value) {
                        if (Object.hasOwnProperty.call(value, k)) {
                            v = walk(value, k);
                            if (v !== undefined) {
                                value[k] = v;
                            } else {
                                delete value[k];
                            }
                        }
                    }
                }
                return reviver.call(holder, key, value);
            }
            cx.lastIndex = 0;
            if (cx.test(text)) {
                text = text.replace(cx, function (a) {
                    return '\\u' +
                        ('0000' + a.charCodeAt(0).toString(16)).slice(-4);
                });
            }

            if (/^[\],:{}\s]*$/.
test(text.replace(/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g, '@').
replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g, ']').
replace(/(?:^|:|,)(?:\s*\[)+/g, ''))) {
                j = eval('(' + text + ')');
                return typeof reviver === 'function' ?
                    walk({'': j}, '') : j;
            }
            throw new SyntaxError('JSON.parse');
        };
    }
}());

// Loc_todo: Error headers

function APIRequest(cmd, data, onS, onE) {
  var _onS = onS || nullHandler;
  var _onE = onE || onS;
  var _async = true;

  var proto = location.protocol;
  var svr = location.hostname;
  var req = (typeof data === 'string') ? data : JSON.stringify(data);
  var response;

  function nullHandler(json) {

  }

  function _err(xhr, text, e) {
    if (text) LogErr(text);
    else text = "Unknown Error";

    if (!e)
      response = {err: -1, msg: text};
    else if ((xhr) && (xhr.status > 200) && !isEmpty(xhr.responseText)) {
      if (xhr.status >= 500) {
        response = {err: -1, msg: "Internal Server Error: "+xhr.status+"\n"+xhr.responseText, status: xhr.status };
      } else if (xhr.status >= 400) {
        response = {err: -1, msg: "Client Error: "+xhr.status+"\n"+xhr.responseText, status: xhr.status };
      } else {
        response = {err: -1, msg: "Unknown Error: "+xhr.status+"\n"+xhr.responseText, status: xhr.status };
      }
    } else if (typeof e == "object")
      response = e;
    else {
      response = {err: -1, msg: e}
    }
    LogErr(response.msg);
    if (_onE) _onE(response);
  }

  function _done(resp, status, xhr) {
    try {
      Log("API-A: " +resp);
      if (isEmpty(resp)) {
        _err(xhr, "No Response from server", null);
        return;
      }
      response = JSON.parse(resp, reviver);
      Log("JSON OK")

      if (_async) {
        if (response.err) _err(xhr, response.err, response);
        else if (_onS) _onS(response);
      }
    } catch (e) {
      _err(xhr, "Parse Error! ["+String(e)+"] "+resp, null);
    }

  }


  this.exec = function() {

           var url = proto+"//"+svr+"/lua/"+cmd+".lua";

    Log("API-Q: " + url +(_async ? " (async)" : " (sync)"));
    //Log("API-Q: " + req); // Uncomment this to help with debugging


    var call = {cache : false, contentType: "text/plain", dataType: "text", type: "POST",
      async: _async, data: req, url: url,
      error: _err, success: _done};


    $.ajax(call);
    if (!_async) return response;
    return null;
  }
}

/************************************************
 * Form Validation
 ************************************************/

// loc_todo: various error messages
var OPT_VALIDATOR = {
            position: 'top right',
            offset: [-4, -40],
            message: '<div style="position: relative"><em/></div>' // em element is the arrow
          };

function formIsValid(s) {
  var inputs = $(s+" :input").validator(OPT_VALIDATOR);
  if (inputs.length == 0) return true;
  return inputs.data("validator").checkValidity();
}

// validate a field to make sure it does not contain characters that are not allowed. The validation is a copy of the
// server side implementation. Note that if invalid characters did get passed through, server should decline the update.
// This also means, if something is to be allowed/declined here then that update MUST be made in the server side
// sanitzation function(s)
$.tools.validator.fn("[validatename]", function(input, value) {
    var username_type = input.attr("validatename");

    if(value.length == 0){
        return $.localizeString("ETM.common.mandatory_field", "This field must be provided.");
    }

    if (username_type == "admin_uname"){
        // webUI admin name allowed characters are: alphanumeric, space, #, !, @, (, ), [, ], -, ., _
        if (value.match(/[^A-Za-z0-9 #!@()\[\]\-\._]/)){
            return $.localizeString("ETM.common.admin_name_allowed_characters", "Invalid username. Allowed characters: alphanumeric space # ! @ ( ) [ ] - . _");
        }
    }
    else if (username_type == "snmp_uname"){
        // SNMP username allowed characters are: alphanumeric, #, !, @, (, ), [, ], -, ., _
        if (value.match(/[^A-Za-z0-9#!@()\[\]\-\._]/)){
            return $.localizeString("ETM.common.snmp_name_allowed_characters", "Invalid username. Allowed characters: alphanumeric # ! @ ( ) [ ] - . _");
        }
    }
    else{
        return false; // this means a username field type sanitizer was not implemented. or possible typo by caller.
    }

    return true;
});


$.tools.validator.fn("[data-equals]", function(input) {
	var name = input.attr("data-equals"),
        field = this.getInputs().filter("[name='" + name + "']");
        s = input.attr("data-name");
        if (!isEmpty(s)) name = s;
	return input.val() == field.val() ? true : $.localizeString("ETM.common.value_not_equal", "Value not equal with the New Password field");
});

$.tools.validator.fn("[data-coexist]", "Must exist together with $1 field", function(input) {
	var name = input.attr("data-coexist"),
      field = this.getInputs().filter("[name='" + name + "']");
  s = input.attr("data-name");
  if (!isEmpty(s)) name = s;
	return isEmpty(input.val()) == isEmpty(field.val()) ? true : [name];
});

$.tools.validator.fn("[optminlength]", function(input, value) {
	var min = input.attr("optminlength");

	if (value.length >= min || value.length == 0) {
        return true;
    }
    else {
        var locString = $.localizeString("ETM.common.please_provide", "Please provide at least ");
        locString += min;
        if (min > 1) {
            locString += $.localizeString("ETM.common.characters", " characters");
        }
        else {
            locString += $.localizeString("ETM.common.character", " character");
        }
        return locString;
	}
});

$.tools.validator.fn("[minlength]", function(input, value) {
	var min = input.attr("minlength");

	if (value.length >= min) {
        return true;
    }
    else {
        var locString = $.localizeString("ETM.common.please_provide", "Please provide at least ");
        locString += min;
        if (min > 1) {
            locString += $.localizeString("ETM.common.characters", " characters");
        }
        else {
            locString += $.localizeString("ETM.common.character", " character");
        }
        return locString;
    }
});

$.tools.validator.fn("[requiredText]", function(input, value) {
  var x = input.attr("requiredText");
  if (value.indexOf(x) == -1) return $.localizeString("ETM.common.select_valid_entry", "Please select a valid entry from the list");
  return true;
});

$.tools.validator.fn("[type=ip]", function(input, ipaddr) {
   if (isEmpty(ipaddr)) return true;

   var re = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
   if (re.test(ipaddr)) {
      var parts = ipaddr.split(".");
      if (parseInt(parseFloat(parts[0])) == 0) { return $.localizeString("ETM.common.input_valid_IP", "Please input a valid IP address"); }
      for (var i=0; i<parts.length; i++) {
         if (parseInt(parseFloat(parts[i])) > 255) { return $.localizeString("ETM.common.input_valid_IP", "Please input a valid IP address"); }
      }
      return true;
   }
   return $.localizeString("ETM.common.input_valid_IP", "Please input a valid IP address");
});

$.tools.validator.fn("[passwd]", function(input, value) {
  if (isEmpty(value)) return true;
  var name = input.attr("passwd"),
  un = (!isEmpty(name)) ? this.getInputs().filter("[name=" + name + "]").val() : name,
  bw = ["password", "god", "sex"];
  if (!isEmpty(un)) bw.push(un);

  var r = validatePassword(value, {letter: 1, number: 1, length: [6,25], badWords: bw, badSequence: 4});
  if (r != null) return "Your password "+r;
  return true;
});

function validatePassword (pw, options) {
	// default options (allows any password)
	var o = {
		lowercase:    0,
		uppercase:    0,
		letter:    0, /* lower + upper */
		number:  0,
		special:  0,
		length:   [0, Infinity],
		custom:   [ /* regexes and/or functions */ ],
		badWords: [],
		badSequence: 0,
		noQwertySequences: false,
		noSequential:      false
	}, errors = [];

	for (var property in options)
		o[property] = options[property];

	var	re = {
			lowercase:   /[a-z]/g,
			uppercase:   /[A-Z]/g,
			letter:   /[A-Z]/gi,
			number: /[0-9]/g,
			special: /[\W_]/g
		},
		rule, i;

	// enforce min/max length
	if (pw.length < o.length[0])
		errors.push($.localizeString("ETM.common.at_least", "must be at least ")+o.length[0]+$.localizeString("ETM.common.characters", " characters"));

  if (pw.length > o.length[1])
    errors.push($.localizeString("ETM.common.less_than", "must be less than ")+o.length[1]+$.localizeString("ETM.common.characters", " characters"));

	// enforce lower/upper/alpha/numeric/special rules
	for (rule in re) {
		if ((pw.match(re[rule]) || []).length < o[rule])
			if (rule == "letter" || rule == "number") errors.push($.localizeString("ETM.common.must_contain", "must contain ")+o[rule]+" "+rule+"s");
      else errors.push($.localizeString("ETM.common.must_contain", "must contain ")+o[rule]+" "+rule+$.localizeString("ETM.common.characters", " characters"));
	}

	// enforce word ban (case insensitive)
	for (i = 0; i < o.badWords.length; i++) {
		if (pw.toLowerCase().indexOf(o.badWords[i].toLowerCase()) > -1)
			errors.push($.localizeString("ETM.common.cannot_contain_username", "cannot contain your username or other common words"));
	}

	// enforce the no sequential, identical characters rule
	if (o.noSequential && /([\S\s])\1/.test(pw))
		errors.push($.localizeString("ETM.common.cannot_contain_duplicate", "cannot contain duplicate characters"));

	// enforce alphanumeric/qwerty sequence ban rules
	if (o.badSequence) {
		var	lower   = "abcdefghijklmnopqrstuvwxyz",
			upper   = lower.toUpperCase(),
			numbers = "0123456789",
			qwerty  = "qwertyuiopasdfghjklzxcvbnm",
			start   = o.badSequence - 1,
			seq     = "_" + pw.slice(0, start);
		for (i = start; i < pw.length; i++) {
			seq = seq.slice(1) + pw.charAt(i);
			if (
				lower.indexOf(seq)   > -1 ||
				upper.indexOf(seq)   > -1 ||
				numbers.indexOf(seq) > -1 ||
				(o.noQwertySequences && qwerty.indexOf(seq) > -1)
			) {
				errors.push($.localizeString("ETM.common.cannot_contain_more_than", "cannot contain more than ")
                            +o.badSequence+$.localizeString("ETM.common.characters_in_seq", " characters in sequence"));
        break;
			}
		}
	}

	// enforce custom regex/function rules
	for (i = 0; i < o.custom.length; i++) {
		rule = o.custom[i];
		if (rule instanceof RegExp) {
			if (!rule.test(pw)) {
        errors.push($.localizeString("ETM.common.not_secure", "is not secure enough "));
        break;
      }
		} else if (rule instanceof Function) {
			if (!rule(pw)) {
        errors.push($.localizeString("ETM.common.not_secure", "is not secure enough "));
        break;
      }
		}
	}

	// great success!
	return (errors.length == 0) ? null : errors.join(", ");
}
