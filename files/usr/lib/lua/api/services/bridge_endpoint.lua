local FunctionService = require("api/FunctionService")
local BridgesEndpoint = FunctionService:new()

local ubus = require("ubus")

local function get_bridges(devices)
	local bridges = {}

	for name, device in pairs(devices) do
		if device.devtype == "bridge" then
			local members = {}


			for i, member in ipairs(device["bridge-members"]) do
				table.insert(members, {
					name = member,
					mac = devices[member].macaddr,
					mtu = devices[member].mtu,
				})
			end

			

			table.insert(bridges, {
				name = name,
				mac = device.macaddr,
				mtu = device.mtu,
				members = members,
				address = nil,
			})

		end
	end

	return bridges
end

local function insert_ip_mask(bridges, conn)
	local devices = conn:call("network.interface", "dump", {})
	if devices == nil then
		return
	end


	for _, bridge in ipairs(bridges) do

		for i, device in ipairs(devices.interface) do
			if device.device == bridge.name then
				bridge.address = device["ipv4-address"][1]
			end
		end
		
		bridge.name = string.gsub(bridge.name, "-", "_")
	end
end

function BridgesEndpoint:GET_TYPE_get()
	local conn = ubus.connect()
	if not conn then
		self:add_critical_error(100, "Failed to connect to ubus")
		return self:ResponseError()
 	end

	local devices = conn:call("network.device", "status", {})
	if devices == nil then
		self:add_critical_error(100, "Failed to get network devices")
		return self:ResponseError()
	end

	local bridges = get_bridges(devices)
	insert_ip_mask(bridges, conn)

	conn:close()
	return self:ResponseOK({
		result = bridges
	})
end

return BridgesEndpoint
