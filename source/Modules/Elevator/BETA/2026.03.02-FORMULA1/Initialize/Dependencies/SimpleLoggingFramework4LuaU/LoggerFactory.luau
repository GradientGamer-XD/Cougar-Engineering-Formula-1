--!strict
local Types = require(script.Parent.Types)

local LoggerFactory = {}

local loggers: {
	[string] : Types.Logger 
} = {}
local currentProvider: Types.LogProvider? = nil

local NoOpLogger: Types.Logger = {
	debug = function() end,
	info = function() end,
	warn = function() end,
	error = function() end,
	log = function() end,
}
function LoggerFactory.bindProvider(provider: Types.LogProvider)
	currentProvider = provider
	table.clear(loggers)
end

function LoggerFactory.getLogger(name: string) : Types.Logger
	if loggers[name] then
		return loggers[name]
	end
	
	local newLogger: Types.Logger
	if currentProvider then
		newLogger = currentProvider.new(name)
	else
		warn(string.format("No Provider set, falling back to No-op for %s", name))
		newLogger = NoOpLogger
	end
	
	loggers[name] = newLogger
	return newLogger
	
end

return LoggerFactory
