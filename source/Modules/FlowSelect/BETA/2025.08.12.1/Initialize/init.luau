local HttpService = game:GetService('HttpService')

local module = {}

module.className = 'FSV4'

local Icons = require(script.WeatherServer.Icons)

module.Controllers = {}

function module.start(source, config, meta)
	
	local self = setmetatable({}, module)
	
	local API = source.Parent:FindFirstChild('FS_API')
	if not API then
		API = Instance.new('BindableEvent')
		API.Name = 'FS_API'
		API.Parent = source.Parent
		
		API.Event:Connect(function(protocol, params)
			
		end)
	end
	
	if not module.WeatherServer then
		module.WeatherServer = {
			IsReady = false,
		}

		task.spawn(function()
			while true do
				local cfg = require(config)
				local Success, Result = pcall(HttpService.GetAsync, HttpService, string.format(cfg.WeatherServer.API_Link, cfg.WeatherServer.City, cfg.WeatherServer.Key))
				if Success then
					module.WeatherServer.IsReady = true

					Result = HttpService:JSONDecode(Result)

					script:SetAttribute('Timezone', Result.timezone)
					script:SetAttribute('Temp', Result.main.temp)
					script:SetAttribute('City', `{Result.name}, {Result.sys.country}`)
					script:SetAttribute('Icon', Icons[Result.weather[1].icon])

					script:SetAttribute('WindDeg', Result.wind.deg)
					script:SetAttribute('WindGust', Result.wind.gust)
					script:SetAttribute('WindSpeed', Result.wind.speed)

					script:SetAttribute('Clouds', Result.clouds.all)

					script:SetAttribute('SunriseTime', Result.sys.sunrise+Result.timezone)
					script:SetAttribute('SunsetTime', Result.sys.sunset+Result.timezone)
				end

				task.wait(10/1)
			end
		end)
	end
	
	for i, v in source.Parent.Panels:GetChildren() do
		for i, p in v:GetChildren() do
			local contr = require(script.Controller)
			local ran, res = pcall(contr.new, source.Parent, config, meta, p)
			if not ran then warn(`Controller for panel \'{p:GetFullName()}\' has encountered an error: {res}`) continue end
			
			module.Controllers[tostring(res.Id)] = res
		end
	end
	
	return self
	
	
end

return module