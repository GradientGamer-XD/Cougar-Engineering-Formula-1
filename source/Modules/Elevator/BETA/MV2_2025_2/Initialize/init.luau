local module = {}

local modules = script:WaitForChild('Modules')
local setup = require(modules.Setup)

module.controllers = {}

function module.start(source, config, version_meta)
	
	warn(`Elevator {source.Name}: Initializing elevator... \n	Version: {version_meta.branch}\n	{version_meta.version}`)
	
	local data = setup.new(source, config, version_meta)
	if not module.controllers[tostring(data.id)] then
		module.controllers[tostring(data.id)] = data
	end
	return data
	
end

function module.get_controller(id: number)
	return module.controllers[tostring(id)]
end

return module