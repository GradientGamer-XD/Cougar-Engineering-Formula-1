--!strict
export type Logs = "TRACE" | "DEBUG" | "INFO" | "WARN" | "ERROR" | "OFF"

export type Logger = {
	debug: (self: Logger, Message: string, ...any) -> (),
	error: (self: Logger, Message: string, ...any) -> (),
	info: (self: Logger, Message: string, ...any) -> (),
	warn: (self: Logger, Message: string, ...any) -> (),
	log: (self: Logger, Level: Logs, Message: string, ...any) -> ()
}

export type LogProvider = {
	new: (name: string) -> Logger
}




return {}