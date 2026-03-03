--!strict

--In LuaU, an error() statment will kill this script and the entire user script. So instead of error() we will use Test Service
local softError = function(...)
	game:GetService("TestService"):Error(...)
end

local Types = require(script.Parent.Types)

type InternalLogger = {
	name: string,
	threshold: number,
} & Types.Logger

local LEVEL_WEIGHTS = {
	["TRACE"] = 10,
	["DEBUG"] = 20,
	["INFO"]  = 30,
	["WARN"]  = 40,
	["ERROR"] = 50,
	["OFF"]   = 100,
}

local ConsoleProvider = {}

ConsoleProvider.__index = ConsoleProvider

function ConsoleProvider.new(name: string, threshold: Types.Logs): Types.Logger
	local self: InternalLogger = setmetatable({
		name = name,
		threshold = LEVEL_WEIGHTS[threshold] or 0,
	}, ConsoleProvider) :: any

	return (self :: any) :: Types.Logger
end

local function formatMessage(message: string, ...: any): string
	local args = {...}
	local i = 0
	local formatted = message:gsub("{}", function()
		i += 1
		return tostring(args[i] or "nil")
	end)
	return formatted
end

function ConsoleProvider:log(level: Types.Logs, message: string, ...: any)
	if LEVEL_WEIGHTS[level] < self.threshold then return end

	local timestamp = tostring(os.date("%I:%M:%S %p")) :: string
	local formatted = string.format("[%s] [%s] %s - %s", timestamp, level, self.name, formatMessage(message, ...))

	if level == "ERROR" then
		softError(formatted, 2)
	elseif level == "WARN" then
		warn(formatted)
	else
		print(formatted)
	end
end

function ConsoleProvider:debug(msg, ...) self:log("DEBUG", msg, ...) end
function ConsoleProvider:info(msg, ...)  self:log("INFO", msg, ...)  end
function ConsoleProvider:warn(msg, ...)  self:log("WARN", msg, ...)  end
function ConsoleProvider:error(msg, ...) self:log("ERROR", msg, ...) end

local Provider = {}
function Provider.new(name: string)
	return ConsoleProvider.new(name, "DEBUG")
end

return Provider
