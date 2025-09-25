  require "os"
  
  local env = ...
  
  send(env.SERVER_PROTOCOL)
  send(" 200 OK\r\n")
  print("in test.lua...\r\n");  
  send("Content-type: text/plain\r\n\r\n")
  send("Request: " .. clean(env.REQUEST_URI) .."\r\n")
  send(" Script: " .. clean(env.SCRIPT_NAME) .."\r\n")
  send("  Query: " .. clean(env.QUERY_STRING) .. "\r\n")
  send("    ENV: " .. json.encode(env) .."\r\n")
  send("DataLen: " .. clean(env.CONTENT_LENGTH) .. "\r\n")

  local len = env.CONTENT_LENGTH or 0

  if (len > 0) then
    send("   Data: " .. recv() .."\r\n")
  end
  
  --os.execute("/lua/lib/restart &")  
