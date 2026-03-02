local ContentProvider = game:GetService('ContentProvider')

local AudioClass = {}
AudioClass.className = 'AudioClass'

AudioClass.__index = function(self, key)
	if --[[key == 'car' or key == 'source' or key == 'platform' or key == 'level' or key == 'audio_module' or key == 'api']] rawequal(typeof(key), 'string') and (string.sub(key, 1, 1) == string.sub(string.lower(key), 1, 1) or key == 'current_position') then
		local function convertString(snakeStr)
			local pascalStr = snakeStr:gsub("_(%a)", function(letter)
				return letter:upper()
			end)
			return pascalStr:sub(1, 1):upper() .. pascalStr:sub(2)
		end
		local newKey = convertString(key)
		if newKey == 'Api' then
			newKey = 'API' -- Additional correction
		end
		warn(`MXV2 Deprecation Warning: Internal value \'{key}\' was indexed. Please use \'{newKey}\' for new work.`)
		return self[newKey]
	end
end

function AudioClass.new(controller)

	local self = setmetatable({}, AudioClass)
	self.Sounds = {}

	function self.AddSound(parent: Instance, name: string, id: number, volume: number, pitch: number, looped: boolean, minDistance: number, maxDistance: number, rollOffMode: Enum.RollOffMode?, on_add: (sound: Sound) -> any, overrides: {any}, internal_on_add: (sound: Sound) -> any)
		local newSound = Instance.new('Sound')
		newSound.Name = name
		newSound.SoundId = if typeof(id) == 'number' and id ~= 0 and string.len(id) >= 4 then `rbxassetid://{id}` else '' -- 11/01: Fix 'Failed to load sound rbxassetid://0: Request asset was not found' errors
		task.spawn(function()
			ContentProvider:PreloadAsync({newSound}, function(assetId: string, status: Enum.AssetFetchStatus)
				if status ~= Enum.AssetFetchStatus.Success then
					newSound.SoundId = ''
					return
				end

				newSound.SoundId = assetId
			end)
		end)
		newSound.Volume = if typeof(volume) == 'number' then volume else 1
		newSound.PlaybackSpeed = if typeof(pitch) == 'number' then pitch else 1
		newSound.RollOffMinDistance = if typeof(minDistance) == 'number' then minDistance else 2
		newSound.RollOffMaxDistance = if typeof(maxDistance) == 'number' then maxDistance else 25
		newSound.RollOffMode = if typeof(rollOffMode) == 'EnumItem' and rollOffMode.EnumType == Enum.RollOffMode then rollOffMode else Enum.RollOffMode.Linear
		newSound.Looped = if typeof(overrides) == 'table' and typeof(overrides.looped) == 'boolean' then overrides.looped elseif typeof(looped) == 'boolean' then looped else false
		newSound.Parent = parent
		if typeof(on_add) == 'function' then
			on_add(newSound)
		end
		
		self.Sounds[name] = newSound

		return newSound
	end
	function self.AddSoundFromConfig(parent: Instance, name: string, config: { id: number, volume: number, pitch: number, looped: boolean, minDistance: number, maxDistance: number, rollOffMode: Enum.RollOffMode?, on_add: (sound: Sound) -> any }, overrides: {any}, on_add: (sound: Sound) -> any)
		return self.AddSound(parent, name, config.id, config.volume, config.pitch, config.looped, config.minDistance, config.maxDistance, config.rollOffMode, config.on_add, overrides, on_add)
	end

	return self

end

return AudioClass
