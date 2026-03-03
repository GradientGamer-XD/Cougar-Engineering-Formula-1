--!strict
local Types = require(script.Parent.Types)

local NoOpLogger = {}
NoOpLogger.__index = NoOpLogger

function NoOpLogger.new(): Types.Logger
	return setmetatable({}, NoOpLogger) :: any
end

function NoOpLogger:debug(...) end
function NoOpLogger:info(...) end
function NoOpLogger:warn(...) end
function NoOpLogger:error(...) end
function NoOpLogger:log(...) end

return NoOpLogger