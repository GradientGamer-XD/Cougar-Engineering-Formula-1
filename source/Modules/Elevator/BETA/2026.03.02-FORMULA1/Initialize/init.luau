local module = {}

local modules = script:WaitForChild('Modules')
local setup = require(modules.Setup)

module.Controllers = {}

local logger = require(script:WaitForChild("Dependencies"):WaitForChild("SimpleLoggingFramework4LuaU")).getLogger("Formula 1")

function module.start(source, config, version_meta, loader_meta)
	
	logger:warn(`Elevator {source.Name}: Initializing elevator... \n	Version: {version_meta.branch}\n	{version_meta.version}`)
	
	local data = setup.new(source, config, version_meta, loader_meta)
	print(data)
	if not module.Controllers[tostring(data.Id)] then
		module.Controllers[tostring(data.Id)] = data
	end
	return data
	
end

function module.GetController(id: number)
	return module.Controllers[tostring(id)]
end

return module