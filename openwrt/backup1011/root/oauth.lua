--oauth operator (refreshtoken,post,get)
require("uci")
require("os")
local http=require("socket.http")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require ("dkjson")
local apiurl = "https://api.yokena.com/"
local x = uci.cursor()
--refreshtoken()
function refreshtoken()
  local client_id = x:get("yokena","sets","client_id")
  local client_secret = x:get("yokena","sets","client_secret")
  local params = {
      grant_type = "client_credentials",
      client_id = client_id,
      client_secret = client_secret
  }
  local request_body =  json.encode (params, { indent = true })
  local response_body = {}
  local res, code, response_headers = https.request{
      url = apiurl .. "oauth",
      method = "POST",
      headers =
        {
            ["Content-Type"] = "application/json";
            ["Content-Length"] = request_body:len();
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body),
  }
-- response_body format {"access_token":"a691e574ac82b1f33cbb33eb2c7000819c2e29af","expires_in":3600,"token_type":"Bearer","scope":null}
  if type(response_body) == "table" then
    local res = table.concat(response_body)
    local obj, pos, err = json.decode (res, 1, nil)
    if err then
      print ("Error:", err)
    else
      x:set("yokena", "oauth", "token", obj.token_type .. " " .. obj.access_token)
      x:set("yokena", "oauth", "expire_time", os.time() + obj.expires_in -100)
      x:commit("yokena")
    end
  else
      print("Not a table:", type(response_body))
  end
end


function checktoken()
  local expire_time_str = x:get("yokena","oauth","expire_time")
  local token_str = x:get("yokena","oauth","token")
  if expire_time_str == nil or token_str == nil then
	refreshtoken()
  elseif (os.time()>tonumber(expire_time_str)) then
      refreshtoken()   
  end
  
end

function apiop(method,interface,postdata,getparam)
  checktoken()
  if method == "GET" then
    local t = {}
    if getparam ~= nil then
      interface = interface .. "/" ..getparam
    end
    local res, code, headers = https.request{
      url = apiurl .. interface,
      method = "GET",
      headers =
        {  
          ["Accept"] = "*/*";
          ["Authorization"] = x:get("yokena", "oauth", "token");
        },
      sink = ltn12.sink.table(t)}
      return code, t
  end

  if method == "POST" then
    local t = {}
    local request_body =  json.encode (postdata, { indent = true })
    local res, code, headers = https.request{
      url = apiurl .. interface,
      method = "POST",
      headers =
        {  
          ["Accept"] = "*/*";
          ["Authorization"] = x:get("yokena", "oauth", "token");
          ["Content-Type"] = "application/json";
          ["Content-Length"] = request_body:len();
        },
      source = ltn12.source.string(request_body),
      sink = ltn12.sink.table(t)
    }
    return code, t
  end

end