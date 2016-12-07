require("os")
require("uci")
require("oauth")
require("updateconfig")


function upload()
local x = uci.cursor()
local file="heartbeat"
local filelog="heartbeatlog"
local enfile="enheartbeat"
local max_line = 60
local filestr = ""
local uptime=assert (io.popen("cat /proc/uptime | awk '{print $1}'"))
for line in uptime:lines() do
	filestr = filestr .. line .. ","
end
uptime:close()

local loads=assert (io.popen("cat /proc/loadavg | awk '{print $1}'"))
for line in loads:lines() do
	filestr = filestr .. line .. ","
end
loads:close()

local totalram=assert (io.popen("awk '/MemTotal/{print $2}' /proc/meminfo"))
for line in totalram:lines() do
	filestr = filestr .. line .. ","
end
totalram:close()

local freeram=assert (io.popen("awk '/MemFree/{print $2}' /proc/meminfo"))
for line in freeram:lines() do
	filestr = filestr .. line .. ","
end
freeram:close()

local wan_iface = x:get("network","wan","ifname")
local recive_byte=assert (io.popen("ifconfig " .. wan_iface .. [[ | awk '/RX bytes/{print substr($2, index($2, ":")+1)}']]))
for line in recive_byte:lines() do
	filestr = filestr .. line .. ","
end
recive_byte:close()

local transmit_byte=assert (io.popen("ifconfig " .. wan_iface .. [[ | awk '/TX bytes/{print substr($6, index($6, ":")+1)}']]))
for line in transmit_byte:lines() do
	filestr = filestr .. line .. ","
end
transmit_byte:close()

filestr = filestr .. os.time()

os.execute("echo " .. filestr .. [[ >> ]] .. file)
--os.execute("echo " .. filestr .. [[ >> ]] .. filelog)

local linecount = 0
local file_line_count=assert (io.popen("sed -n '$=' " .. file))
for line in file_line_count:lines() do
	linecount = line
end
file_line_count:close()

if tonumber(linecount) == 30 then
	updatebysync()
end

if tonumber(linecount) >= max_line then
	local cryptkey = x:get("yokena","sets","crypt_key")
	if cryptkey ~= nil then
		os.execute([[openssl enc -aes-128-cbc -in ]] .. file .. [[ -out ]] .. enfile .. [[ -a -pass pass:]] .. cryptkey)
		local enfiledata = ""
		local f = assert(io.open(enfile,'r'))	
		local enfiledata = f:read("*all")
		f:close()	
		local postdata = {
      		data = enfiledata
  		}
		local code ,t = apiop("POST","Heartbeats",postdata,nil)
		if code ==201 then 
			os.execute("echo " .. "code:" .. code .. "  time: " .. os.date() ..  [[ >> ]] .. "logpost")
		else
      		os.execute("echo " .. "code:" .. code .. "  time: " .. os.date() .. [[ >> ]] .. "logpost")
			refreshtoken()
		end 
	end

	updatebysync()
	os.remove(file)
end





end





