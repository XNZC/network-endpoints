local FunctionService = require("api/FunctionService")
local BridgeConfig = FunctionService:new()

local uci = require("uci")
local ubus = require("ubus")

local function refresh_network(self)
    local conn = ubus.connect()
	if not conn then
		self:add_critical_error(100, "Failed to connect to ubus")
		return self:ResponseError()
 	end

    conn:call("network", "reload", {});
	conn:close()

    return self:ResponseOK({
        msg = "UCI updated successfully"
    })
end

function BridgeConfig:set()
    local cursor = uci.cursor()
    if not cursor then
        self:add_critical_error(100, "Failed to initialise uci cursor")
		return self:ResponseError()
    end

	local data = self.arguments.data

    if not cursor:get("network", data.name) then
		self:add_critical_error(100, "Could not find bridge '" .. data.name .. "'")
		return self:ResponseError()
	end

    if data.mtu then
		cursor:set("network", data.name, "mtu", tostring(data.mtu))
	end

	if data.macaddr then
		cursor:set("network", data.name, "macaddr", data.macaddr)
	end

    if data.new_name then
        local name = cursor:get("network", data.name, "name")
        cursor:set("network", data.name, "name", data.new_name)

        cursor:foreach("network", "interface", function(s)
            if s.name == name then
                cursor:set("network", s, "device", data.new_name)
            end
        end)
    end

    cursor:commit("network")

	return refresh_network(self)
end

local action = BridgeConfig:action("set", BridgeConfig.set)

local name = action:option("name")
	name.require = true
	name.maxlength = 32

local mtu = action:option("mtu")
	function mtu:validate(value)
		local num = tonumber(value)
		if not num or num < 576 or num > 9000 then
			return false, "Invalid MTU value"
		end
		return true
	end

local macaddr = action:option("macaddr")
	function macaddr:validate(value)
		if not string.match(value, "^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$") then
			return false, "Invalid MAC address format"
		end

		return true
	end

local new_name = action:option("new_name")
	new_name.maxlength = 32



return BridgeConfig