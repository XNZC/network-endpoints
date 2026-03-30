local FunctionService = require("api/FunctionService")
local RoutesEndpoint = FunctionService:new()
local json = require("luci.jsonc")

local function group_routes(jsonroutes)
	local routes = {}

	for _, route in pairs(jsonroutes) do

		if not routes[route.dev] then
			routes[route.dev] = {}
		end

		table.insert(routes[route.dev], {
			protocol = route.protocol,
			prefsrc = route.prefsrc,
			dst = route.dst,
			flags = route.flags,
			metric = route.metric,
			gateway = route.gateway,
			scope = route.scope
		})

	end

	return routes
end

function RoutesEndpoint:GET_TYPE_get()
    local handle = io.popen("ip -json route show table all")
	if not handle then
		self:add_critical_error(500, "Failed to get ip routes")
		return self:ResponseError()
	end

    local result = handle:read("*a")
	handle:close()

    local jsonroutes = json.parse(result)
	local routes = group_routes(jsonroutes)

    return self:ResponseOK({
		routes = routes
	})
end

return RoutesEndpoint