local audioClass = {}
audioClass.className = 'audioClass'

function audioClass.new(controller)
	
	local data = setmetatable({}, audioClass)
	data.sounds = {}

	function data.addSound(parent: Instance, name: string, id: number, volume: number, pitch: number, looped: boolean, minDistance: number, maxDistance: number, rollOffMode: Enum.RollOffMode?)
		local newSound = Instance.new('Sound')
		newSound.Name = name
		newSound.SoundId = if typeof(id) == 'number' then `rbxassetid://{id}` else ''
		newSound.Volume = if typeof(volume) == 'number' then volume else 1
		newSound.PlaybackSpeed = if typeof(pitch) == 'number' then pitch else 1
		newSound.RollOffMinDistance = if typeof(minDistance) == 'number' then minDistance else 2
		newSound.RollOffMaxDistance = if typeof(maxDistance) == 'number' then maxDistance else 25
		newSound.RollOffMode = if typeof(rollOffMode) == 'EnumItem' and rollOffMode.EnumType == Enum.RollOffMode then rollOffMode else Enum.RollOffMode.Linear
		newSound.Looped = if typeof(looped) == 'boolean' then looped else false
		newSound.Parent = parent
		return newSound
	end
	function data.addSoundFromConfig(parent: Instance, name: string, config: { id: number, volume: number, pitch: number, looped: boolean, minDistance: number, maxDistance: number, rollOffMode: Enum.RollOffMode? })
		return data.addSound(parent, name, config.id, config.volume, config.pitch, config.looped, config.minDistance, config.maxDistance, config.rollOffMode)
	end
	
	return data
	
end

return audioClass
