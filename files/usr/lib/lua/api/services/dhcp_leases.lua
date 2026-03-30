local FunctionService = require("api/FunctionService")
local DHCPLeases = FunctionService:new()

local ubus = require("ubus")

local function get_devices(ipv4devices, ipv6devices)
    local devices = {}

    for name, device in pairs(ipv6devices.device) do
        if not devices[name] then
            devices[name] = {}
        end

        if not devices[name]["ipv6_leases"] then
            devices[name]["ipv6_leases"] = {}
        end

        for _, lease in ipairs(device.leases) do
            table.insert(devices[name]["ipv6_leases"], {
                hostname = lease.hostname,
                ['valid-lifetime'] = lease['ipv6-addr'][1]['valid-lifetime'],
                ['preferred-lifetime'] = lease['ipv6-addr'][1]['preferred-lifetime'],
                address = lease['ipv6-addr'][1].address,
            })
        end
    end

    for _, device in ipairs(ipv4devices.leases) do
        if not devices[device.device] then
            devices[device.device] = {}
        end

        if not devices[device.device]["ipv4_leases"] then
            devices[device.device]["ipv4_leases"] = {}
        end

        table.insert(devices[device.device]["ipv4_leases"], {
            ['valid-lifetime'] = device.valid,
            address = device.address,
            mac = device.mac,
            hostname = device.hostname,
        })
    end

    return devices
end

function DHCPLeases:GET_TYPE_get()
    local conn = ubus.connect()
	if not conn then
		self:add_critical_error(100, "Failed to connect to ubus")
		return self:ResponseError()
 	end

    local ipv4devices = conn:call("dnsmasq", "ipv4leases", {})
    local ipv6devices = conn:call("dhcp", "ipv6leases", {})
    if not ipv4devices and not ipv6devices then
        self:add_critical_error(100, "Failed to get dhcp leases")
		return self:ResponseError()
    end

    local devices = get_devices(ipv4devices, ipv6devices)
    conn:close()

    return self:ResponseOK({
		result = devices
	})
end

return DHCPLeases