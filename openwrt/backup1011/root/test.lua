require("uci")
local x = uci.cursor()

function ontsetting()
        local isont = x:get("yokena",'sets','isont')
        if isont == '1' then
            local ontusername = x:get("yokena",'sets','ontusername')
            local ontpassword = x:get("yokena",'sets','ontpassword')
            x:set('network','wan','ifname','eth0.10')
            x:set('network','wan6','ifname','@wan')
            x:set('network','wan','proto','pppoe')
            x:set('network','wan','username',ontusername)
            x:set('network','wan','password',ontpassword)
            x:set('network','wan','peerdns','1')
        end
x:commit('network')

end


ontsetting()
