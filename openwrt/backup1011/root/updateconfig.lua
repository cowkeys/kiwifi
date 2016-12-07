require("uci")
local x = uci.cursor()
require("os")
require("io")
require("oauth")
local json = require ("dkjson")
local haspppoe = false
function updatebysync()
  local cryptkey = x:get("yokena","sets","crypt_key")
  if cryptkey ~= nil then
      local code, t = apiop("GET","Gatefigs",nil,nil)
      if code ==200 then
          local res = table.concat(t)
          local obj, pos, err = json.decode (res, 1, nil)
          if err then
              print ("Error:", err)
          else
            for  k,v in pairs(obj._embedded.gatefig[1]) do
              if k == "sync" then
                if v =="N" then
                  print("update")
                  updatefile()
                  --checkconfig()
                  ontsetting()
                  loginsetting()
                  reloadfile()
                  os.execute("echo " .. "sync: N ,update gateways and reload success!  time: " .. os.date() .. [[ >> ]] .. "logpost")
                else
                  print("update Y")
                end
              end
            end
          end
      end
  else
      os.execute("echo " .. "config yokena load error!  time: " .. os.date() .. [[ >> ]] .. "logpost")
  end
  
end


function ontsetting()
        local isont = x:get("yokena",'sets','isont')
        if isont == '1' then
            local ontusername = x:get("yokena",'sets','ontusername')
            local ontpassword = x:get("yokena",'sets','ontpassword')
            x:set('network','wan','ifname','eth0.10')
            x:set('network','wan6','ifname','eth0')
            x:set('network','wan','proto','pppoe')
            x:set('network','wan','username',ontusername)
            x:set('network','wan','password',ontpassword)
            x:set('network','wan','peerdns','1')
        end
x:commit('network')

end

function reloadfile()
	os.execute("/etc/init.d/network reload")
	--os.execute("wifi")
	--os.execute("/etc/init.d/qos reload")
  os.execute("/etc/init.d/dnsmasq reload")
  os.execute("/etc/init.d/firewall reload") 

  if haspppoe then
      os.execute("/etc/init.d/pppoe-server reload")
      os.execute("/etc/init.d/pppoe-server enable")
  end
end

function checkconfig()
	--[[local novlan = true
	x:foreach("network", "switch_vlan", function(s)  
    	for ks, vs in pairs(s) do
     		if ks == ".name" then
     			local vlanval = x:get("network",vs,"vlan")
     			if vlanval == "1" then
     				novlan = false
     			end				            
     		end	
    	end
	end)
	if novlan then
		local name = x:add("network", "switch_vlan")
		x:set("network",name,"device","switch0")
		x:set("network",name,"vlan","1")
		x:set("network",name,"ports","0 1 2 3 6t")
		x:commit("network")
	end
]]
	local novantowan = true
	x:foreach("firewall", "forwarding", function(s)  
    	for ks, vs in pairs(s) do
     		if ks == ".name" then
     			local srcval = x:get("firewall",vs,"src")
     			if srcval == "lan" then
     				novantowan = false
     			end				            
     		end	
    	end
	end)
	if novantowan then
		local name = x:add("firewall", "forwarding")
		x:set("firewall",name,"src","lan")
		x:set("firewall",name,"dest","wan")
		x:commit("firewall")
	end
	-- body
end


function loginsetting()
  local ispppoe = false
    local isweb = false
  x:foreach("network", "interface", function(s) 
    
    if s['login_type'] == "pppoe" then
      ispppoe = true

    end
    if s['login_type'] == "web" then
      isweb = true
    end
    end)

  if ispppoe ==false then
      os.execute("/etc/init.d/pppoe-server stop")
      os.execute("/etc/init.d/pppoe-server disable")
    end
    if isweb == false then
      x:foreach("chilli", "chilli", function(ss) 
                      x:set("chilli", ss['.name'], "disabled", "1")                
                end)
      x:commit("chilli")
      os.execute("/etc/init.d/chilli stop")
      os.execute("/etc/init.d/chilli disable")
    end
x:foreach("firewall", "forwarding", function(sf) 
              for sfk, sfv in pairs(sf) do
                if sfk == ".name" then
                  x:delete("firewall",sfv) 
                end 
              end
            end)
os.execute("echo  > /etc/default/pppoe-server")
  local ippool = '0'
  ippool = x:get("yokena",'sets','ippool')
  x:foreach("network", "interface", function(s) 
                  print("logintype",s['login_type'])
                  if s['login_type'] == "pppoe" then
                      haspppoe = true
                      local brlanlist = mysplit(s['ifname'],"eth") 
                      if brlanlist[1] == "1" then
                         brlanlist[1] = ""
                      end

                      local listip = mysplit(s['ipaddr'] .. "", ".")
                      local ipstr = listip[1] .. "." ..listip[2] .. "." .. listip[3] ..  "."
                      local iptablecmd = "iptables -t nat -A POSTROUTING -s " .. ipstr .. "0/24 -j MASQUERADE"
                      os.execute("echo iptableoptslan" .. brlanlist[1] .."=" .. [[\"]] .. iptablecmd .. [[\"]] .. [[ >> ]] .. "/etc/default/pppoe-server")
                      

                      local pppoecmd = ""
                      if ippool == '1' then
                        pppoecmd = "pppoe-server -k -T 60 -I br-"  .. s['.name'] .. "  -C Myp -L " .. ipstr .. "1 -p /etc/default/pool "
                      else
                        pppoecmd = "pppoe-server -k -T 60 -I br-"  .. s['.name'] .. " -N 200 -C Myp -L " .. ipstr .. "1 -R " .. ipstr .. "2"
                      end
                      --local pppoecmd = "pppoe-server -k -T 60 -I br-"  .. s['.name'] .. "  -C Myp -L " .. ipstr .. "1 -p /etc/default/pool "
                      os.execute("echo pppoeoptslan" .. brlanlist[1] .."=" .. [[\"]] ..  pppoecmd .. [[\"]] .. [[ >> ]] .. "/etc/default/pppoe-server")
                  end
                  if s['login_type'] == "web" then
                    local brlanlist = mysplit(s['ifname'],"eth") 
                    if brlanlist[1] == "1" then
                              brlanlist[1] = ""
                    end
                      x:foreach("chilli", "chilli", function(ss) 
                      x:delete("chilli", ss['.name'], "disabled")
                      x:set("chilli", ss['.name'], "dhcpif", "br-" .. s['.name'])
                      end)
                      x:commit("chilli")
                      os.execute("/etc/init.d/chilli enable")
                      os.execute("/etc/init.d/chilli start")
                      os.execute("ifdown " .. s[".name"])
                      os.execute("ifup " .. s[".name"])
                  end
                  if s['login_type'] == "open" then
                    print("web")
                    print(s['ifname'])
                    local brlanlist = mysplit(s['ifname'],"eth") 
                    if brlanlist[1] == "1" then
                              brlanlist[1] = ""
                      end

                      

                      local name = x:add("firewall", "forwarding")
                      x:set("firewall",name,"src",s['.name']) --eg  x:set(network,lan3,ifname,eth0.3)
                      x:set("firewall",name,"dest","wan")
                      x:commit("firewall")
                      os.execute("/etc/init.d/firewall reload") 
                  end
                  
                end)

  
end

function updatefile()
	--
	--[[local f = assert(io.open("gateconfig.json",'r'))	
	local ta = f:read("*all")
	f:close()
	local obj, pos, err = json.decode (ta, 1, nil)]]
  local gid = x:get("yokena", "sets", "gateway_id")
  local code,t = apiop("GET","Gatefigs",nil,gid)
  if code == 200 then
    local res = table.concat(t)
    local obj, pos, err = json.decode (res, 1, nil)
	for k, v in pairs(obj) do
	    if k =="network" then
			    for kk, vv in pairs(v) do
				    if kk =="interface" then
                x:foreach(k, kk, function(s) 
                  for ks, vs in pairs(s) do
                    if ks == ".name"  and vs~="loopback" then
                      x:delete(k,vs) 
                    end 
                  end
                end)
				        for kkk,vvv in pairs(vv) do
					         
                        x:set(k,kkk,kk)
                        local ifn = ''
                        for kkkk,vvvv in pairs(vvv) do
                            --x:set(k,kkk,kkkk,vvvv) --eg  x:set(network,lan3,ifname,eth0.3)
                            if kkkk ~= 'ifname'  then
                                x:set(k,kkk,kkkk,vvvv)
                            elseif kkk == "wan" or kkk == "wan6" then
                                x:set(k,kkk,'ifname','eth0')
                            else 
                                ifn = vvvv 
                            end

                        end
						            --eg  x:get(network,lan3)  not found
                        for lk, lv in pairs(v) do
                          if lk =="switch_vlan" then
						                  for lkk,lvv in pairs(lv) do
                                  for lkkk,lvvv in pairs(lvv) do
                                  if lkkk == 'vlan' then 
                                    print(string.find(ifn, tostring(lvvv), 1, true))
                                    if string.find(ifn, tostring(lvvv), 1, true) ~=nil then
                                        local port = lvv['ports']
                                        local eth = "eth" .. getport(port,nil)
                                        print(k,kkk,'ifname',eth)
                                        x:set(k,kkk,'ifname',eth)
                                    end
                                  end
                                 end 
                              end

                          end
                        end
					          
				        end
				    end
				    
    			  if kk == "globals" then 
    				      for kkk,vvv in pairs(vv) do
    					        for kkkk,vvvv in pairs(vvv) do
							            x:set(k,kk,kkkk,vvvv)
						          end
    				      end
    			  end	
    		  end
    	    x:commit(k)
          
      end

   --[[	if k =="wireless" then
    		for kk, vv in pairs(v) do
    			if kk =="wifi-device" then
    				for kkk,vvv in pairs(vv) do
    					x:set(k,kkk,"disabled",0)
    					for kkkk,vvvv in pairs(vvv) do
    						x:set(k,kkk,kkkk,vvvv)
    					end
     				end
    			end
    			if kk == "wifi-iface" then
    				x:foreach(k, kk, function(s)  
    					for ks, vs in pairs(s) do
     						if ks == ".name" then
     						    x:delete(k, vs)
     						end	
    					end
					end)

					for kkk,vvv in pairs(vv) do
    					local name = x:add(k, kk)
    					for kkkk,vvvv in pairs(vvv) do
							x:set(k,name,kkkk,vvvv) --eg  x:set(wireless,name,device,radio0)
						end
    				end
    			end
    		end
    	  x:commit(k)	

   		end]] 
   		
   		if k == "dhcp" then
   			for kk, vv in pairs(v) do
   				if kk == "dnsmasq" then
   					for kkk, vvv in pairs(vv) do
   						local dnsmasqname = ""
   						x:foreach(k, kk, function(s)  
    						for ks, vs in pairs(s) do
     							if ks == ".name" then
     						    	dnsmasqname = vs
     						    	break
     							end	
    						end
						end)
						for kkkk, vvvv in pairs(vvv) do
							x:set(k,dnsmasqname,kkkk,vvvv)
						end
   					end
   				end
   				if kk == "dhcp" then
   					x:foreach(k, kk, function(s) 
   						for ks, vs in pairs(s) do
     						if ks == ".name" then
     							x:delete(k,vs) 
     						end	
    					end
   					end)
   					for kkk, vvv in pairs(vv) do
   						x:set(k,kkk,kk)
   						for kkkk,vvvv in pairs(vvv) do
   							x:set(k,kkk,kkkk,vvvv)
   						end
   					end
   				end
   				if kk == "odhcpd" then
   					for kkk, vvv in pairs(vv) do
   						x:set(k,kkk,kk)
   						for kkkk,vvvv in pairs(vvv) do
   							x:set(k,kkk,kkkk,vvvv)
   						end
   					end
   				end
   			end
   		  x:commit(k)	

   		end

   		if k == "firewall" then
   			for kk,vv in pairs(v) do
   				if kk =="defaults" then
   					for kkk, vvv in pairs(vv) do
   						local defaultsname = ""
   						x:foreach(k, kk, function(s)  
    						for ks, vs in pairs(s) do
     							if ks == ".name" then
     						    	defaultsname = vs
     						    	break
     							end	
    						end
						end)
						for kkkk, vvvv in pairs(vvv) do
							x:set(k,defaultsname,kkkk,vvvv)
						end
   					end
   				end
   				if kk == "zone" then
   					x:foreach(k, kk, function(s) 
   						for ks, vs in pairs(s) do
     						if ks == ".name" then
     							x:delete(k,vs) 
     						end	
    					end
   					end)
   					for kkk, vvv in pairs(vv) do
   						local name = x:add(k, kk)
    					for kkkk,vvvv in pairs(vvv) do
    						if kkkk == "network" then
    							local list = mysplit(vvvv, nil)
    							x:set(k,name,kkkk,list)
    						else
    							x:set(k,name,kkkk,vvvv) --eg  x:set(network,lan3,ifname,eth0.3)
    						end	
						end
   					end
   				end
   				if kk == "forwarding" then
   					x:foreach(k, kk, function(s) 
   						for ks, vs in pairs(s) do
     						if ks == ".name" then
     							x:delete(k,vs) 
     						end	
    					end
   					end)
   					--for kkk, vvv in pairs(vv) do
   					--	local name = x:add(k, kk)
    				--	for kkkk,vvvv in pairs(vvv) do
    				--		x:set(k,name,kkkk,vvvv) --eg  x:set(network,lan3,ifname,eth0.3)
						--  end
   					--end
   				end
   				if kk =="rule" then
   					x:foreach(k, kk, function(s) 
   						for ks, vs in pairs(s) do
     						if ks == ".name" then
     							x:delete(k,vs) 
     						end	
    					end
   					end)
   					for kkk, vvv in pairs(vv) do
   						local name = x:add(k, kk)
    					for kkkk,vvvv in pairs(vvv) do
    						x:set(k,name,kkkk,vvvv) --eg  x:set(network,lan3,ifname,eth0.3)
						  end
   					end
   				end
   				if kk =="include" then
   					x:foreach(k, kk, function(s) 
   						for ks, vs in pairs(s) do
     						if ks == ".name" then
     							x:delete(k,vs) 
     						end	
    					end
   					end)
   					for kkk, vvv in pairs(vv) do
   						local name = x:add(k, kk,kkk)
    					for kkkk,vvvv in pairs(vvv) do
    						x:set(k,name,kkkk,vvvv) --eg  x:set(network,lan3,ifname,eth0.3)
						end
   					end
   				end
   			end
   		  x:commit(k)

   		end

    	--[[if k =="qos" then
          for kk,vv in pairs(v) do
              if kk =="interface" then
                  for kkk,vvv in pairs(vv) do
                      local tmp = x:get(k,kkk) --eg  x:get(network,lan)
                      if tmp ~=nil then
                          for kkkk,vvvv in pairs(vvv) do
                            x:set(k,kkk,kkkk,vvvv) --eg  x:set(network,lan,ifname,eth0.1)
                          end
                      else
                          --eg  x:get(qos,lan)  not found
                          x:set(k,kkk,kk)
                          for kkkk,vvvv in pairs(vvv) do
                            x:set(k,kkk,kkkk,vvvv) --eg  x:set(network,lan3,ifname,eth0.3)
                          end
                      end
                  end
              end
              if (kk == "classify" or kk=="reclassify" or kk=="default") then
                  x:foreach(k, kk, function(s) 
                  for ks, vs in pairs(s) do
                      if ks == ".name" then
                      x:delete(k,vs) 
                      end 
                  end
                  end)
                  for kkk, vvv in pairs(vv) do
                      local name = x:add(k, kk)
                      for kkkk,vvvv in pairs(vvv) do
                      x:set(k,name,kkkk,vvvv) --eg  x:set(network,lan3,ifname,eth0.3)
                      end
                  end
              end
              if (kk == "classgroup" or kk =="class") then
                  for kkk,vvv in pairs(vv) do
                      local tmp = x:get(k,kkk) --eg  x:get(network,lan)
                      if tmp ~=nil then
                          for kkkk,vvvv in pairs(vvv) do
                            x:set(k,kkk,kkkk,vvvv) --eg  x:set(network,lan,ifname,eth0.1)
                          end
                      else
                          --eg  x:get(qos,lan)  not found
                          x:set(k,kkk,kk)
                          for kkkk,vvvv in pairs(vvv) do
                            x:set(k,kkk,kkkk,vvvv) --eg  x:set(network,lan3,ifname,eth0.3)
                          end
                      end
                  end
              end
          end
          x:commit(k)
      end]]
  	end
  end



end

function mysplit(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={} ; i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end

function getport(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={} ; i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return (tonumber(t[1])+1) .. ""
end


--update()

--updatebysync()

--loginsetting()