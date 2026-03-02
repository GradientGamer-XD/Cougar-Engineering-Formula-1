local module = {}

local modules = script:WaitForChild('Modules')
local setup = require(modules.Setup)

function module.start(source, config, version_meta)
	
	warn('Initializing group calling...', version_meta)
	
	local data = setup.new(source, config, version_meta)
	
	return data
	
end

return module