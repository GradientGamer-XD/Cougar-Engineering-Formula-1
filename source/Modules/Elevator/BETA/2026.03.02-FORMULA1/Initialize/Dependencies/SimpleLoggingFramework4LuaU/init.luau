--!strict
-- Logging api for Roblox scripting intended to mimic SLF4J

local Types = require(script.Types)
local LoggerFactory = require(script.LoggerFactory)

local printer = require(script.ConsoleProvider)

local SimpleLoggingFramework4LuaU = {}

export type Logger = Types.Logger
export type LogLevel = Types.Logs
export type LogProvider = Types.LogProvider

LoggerFactory.bindProvider(printer)

function SimpleLoggingFramework4LuaU.getLogger(name: string) : Logger
	return LoggerFactory.getLogger(name)
end

function SimpleLoggingFramework4LuaU.bindProvider(provider: LogProvider)
	LoggerFactory.bindProvider(provider)
end

return SimpleLoggingFramework4LuaU
