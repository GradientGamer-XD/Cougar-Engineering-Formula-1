local function convertString(snakeStr)
	local pascalStr = snakeStr:gsub("_(%a)", function(letter)
		return letter:upper()
	end)
	return pascalStr:sub(1, 1):upper() .. pascalStr:sub(2)
end

local ControllerClass = {}
ControllerClass.className = 'ControllerClass'

ControllerClass.IndexVariableCorrection = function(self, key)
	if --[[key == 'car' or key == 'source' or key == 'platform' or key == 'level' or key == 'audio_module' or key == 'api']] rawequal(typeof(key), 'string') and (string.sub(key, 1, 1) == string.sub(string.lower(key), 1, 1) or key == 'current_position') then
		local newKey = convertString(key)
		if newKey == 'Api' then newKey = 'API' end -- Additional correction
		if newKey == 'CheckLanternAndFire' then newKey = 'InvokeLanternAPIWithCheckAsync' end
		--warn(`MXV2 Deprecation Warning: Internal value \'{key}\' was indexed. Please use \'{newKey}\' for new work.`)
		return self[newKey]
	end
end

ControllerClass.__index = ControllerClass.IndexVariableCorrection

local controllers = {}

local replicatedStorage = game:GetService('ReplicatedStorage')
local replicatedFirst = game:GetService('ReplicatedFirst')
local serverScriptService = game:GetService('ServerScriptService')
local runService = game:GetService('RunService')
local players = game:GetService('Players')
local collectionService = game:GetService('CollectionService')

function ControllerClass.new(source, config)

	local elevatorID = source:GetAttribute('elevatorID')

	if controllers[elevatorID] then print(`A controller has already been set up for this elevator!`) return controllers[elevatorID] end

	if not elevatorID then
		elevatorID = tostring(math.random(0,99999999))
		source:SetAttribute('elevatorID', elevatorID)
	end

	local initStart = os.clock()
	print('Setting up...')

	collectionService:AddTag(source, 'MX_Elevator')

	local self = setmetatable({}, ControllerClass)

	self.Step = runService.PreSimulation

	self.Source = source
	self.Config = config
	self.Path = source:GetFullName()

	self.Car = source:FindFirstChild('Car')
	self.Platform = self.Car:FindFirstChild('Platform')
	self.Level = self.Car:FindFirstChild('Level') or self.Platform
	self._InitialPosition = self.Platform.CFrame
	self.CurrentPosition = self.Platform.CFrame

	self.API = Instance.new('BindableEvent')
	self.API.Name = 'API'
	self.API.Parent = source

	self.Remote = Instance.new('RemoteEvent')
	self.Remote.Name = 'Remote'
	self.Remote.Parent = source

	local dataApi = Instance.new('BindableFunction')
	dataApi.Name = 'Data_API'
	dataApi.Parent = source

	local t_value = Instance.new('CFrameValue')
	t_value.Name = 'target_position'
	t_value.Value = self.CurrentPosition
	t_value.Parent = self.Platform

	self.Id = elevatorID

	self.Floors = {}

	for i, v in source.Floors:GetChildren() do
		local floorNumber, level = tonumber(string.split(v.Name, 'Floor_')[2]), v:FindFirstChild('Level')
		if (not floorNumber) or (not level) then continue end

		local data =  setmetatable({}, {
			__index = ControllerClass.IndexVariableCorrection
		})

		data.FloorModel = v
		data.FloorNumber = floorNumber
		data.Level = level

		self.Floors[tostring(floorNumber)] = data
	end

	function self.FindFloor(floor: number | string)
		return self.Floors[tostring(floor)]
	end

	-- Get bottom & top floor --
	local dist_top = -math.huge
	local dist_bottom = math.huge
	for i, v in self.Floors do
		local Level_pos = v.Level.Position.Y
		if Level_pos >= dist_top then
			dist_top = Level_pos
			self.TopFloor = v
		end
		if Level_pos <= dist_bottom then
			dist_bottom = Level_pos
			self.BottomFloor = v
		end
	end
	----

	function self.GetNearestFloor()
		local dist = math.huge
		local result
		for i, v in self.Floors do
			if math.abs(v.Level.Position.Y-self.CurrentPosition.Position.Y) <= dist then
				dist = math.abs(v.Level.Position.Y-self.CurrentPosition.Position.Y)
				result = v
			end
		end
		return result
	end

	function self.GetTableLength(t: any)
		if typeof(t) ~= 'table' then return end
		local length = 0
		for i, v in t do
			length += 1
		end
		return length
	end

	function self.CheckAllDoors(target_position: string)
		for i, v in self.door_data do
			for i, weld in v.engine_welds do
				if (weld:GetAttribute(target_position).Position-weld.C0.Position).Magnitude > (weld:IsDescendantOf(car) and .175 or .035) or v.state ~= 'Closed' then return false end
			end
		end
		return true
	end

	self.StatValueInstances = {}

	self.StatValues = setmetatable({}, {
		__index = ControllerClass.IndexVariableCorrection
	})

	self.StatValues.Floor = self.GetNearestFloor().FloorNumber
	self.StatValues.MoveDirection = 0
	self.StatValues.QueueDirection = 0
	self.StatValues.Destination = 0
	self.StatValues.Leveling = false
	self.StatValues.Speed = 0
	self.StatValues.Velocity = 0
	self.StatValues.DoorSafetyLock = false
	self.StatValues.OutOfService = false
	self.StatValues.Park = false
	self.StatValues.Stop = false

	self.StatValues.FireService = {
		Recall = false,
		Phase2 = false
	}
	self._QueueDirectionLock = false -- Prevents the queue direction from being set if true

	function self.UpdateStatValues()
		for i, v in self.StatValueInstances do
			v.update()
		end
	end

	local function AddStatValue(index: string, value: any)
		local t = typeof(value) == 'boolean' and 'Bool' or typeof(value) == 'number' and 'Number' or typeof(value) == 'string' and 'String' or nil
		if not t then return end

		local function ConvertString(str: string)
			return str:gsub("(%u)(%l*)", function(upper, lower)
				return "_" .. upper .. lower
			end):gsub("(%d+)", "_" .. "%1") -- Add underscores before numbers
				:gsub("^_", "")  -- Remove leading underscore
		end

		local inst = Instance.new(`{t}Value`)
		inst.Name = ConvertString(index)
		inst.Value = value
		inst.Parent = self.ValuesFolder
		local random_value = math.random(0, 9999999)
		local lastValue = inst.Value
		inst:GetPropertyChangedSignal('Value'):Connect(function()
			if inst:GetAttribute(`value_hotfix_{random_value}`) then return end

			inst.Value = lastValue
			lastValue = inst.Value
		end)
		self.StatValueInstances[inst] = {
			instance = inst,
			update = function()
				inst:SetAttribute(`value_hotfix_{random_value}`, true)
				if inst.Name == 'Recall' or inst.Name == 'Phase_2' then
					inst.Value = self.StatValues.FireService[index]
				else
					inst.Value = self.StatValues[index]
				end
				lastValue = inst.Value
				inst:SetAttribute(`value_hotfix_{random_value}`, nil)
			end,
		}
	end

	if not source:FindFirstChild('Values') then
		self.ValuesFolder = Instance.new('Folder')
		self.ValuesFolder.Name = 'Values'
		self.ValuesFolder.Parent = source
		for i, v in self.StatValues do
			AddStatValue(i, v)
		end
		for i, v in self.StatValues.FireService do
			AddStatValue(i, v)
		end
	end

	self._Dependencies = script.Parent.Parent:WaitForChild('Dependencies')

	self.ElevatorFolder = replicatedStorage.MX_Elevator_Storage:FindFirstChild(`Elev_{elevatorID}`) or Instance.new('Folder')
	self.ElevatorFolder.Name = `Elev_{elevatorID}`
	self.ElevatorFolder.Parent = replicatedStorage.MX_Elevator_Storage
	local platformValue = Instance.new('ObjectValue')
	platformValue.Name = 'Target_Object'
	platformValue.Value = self.Platform
	platformValue.Parent = self.ElevatorFolder
	local val = Instance.new('ObjectValue')
	val.Name = 'Values'
	val.Value = self.ValuesFolder
	val.Parent = platformValue.Value
	local playerWeldsFolder = Instance.new('Folder')
	playerWeldsFolder.Name = 'Player_Welds'
	playerWeldsFolder.Parent = self.ElevatorFolder
	

	-- Modules --
	self.AudioModule = require(script.Parent.Audio).new(self)
	self.WeldingModule = require(script.Parent.Welding)
	self.Signal = require(script.Parent.Signal) -- MUST be local
	self.DoorSetupModule = require(script.Parent.Door_Setup)
	local buttons_handler_module = require(script.Parent.Buttons_Handler)
	self.QueueModule = require(script.Parent.Queue)
	self.MovementModule = require(script.Parent.Movement)
	self.MovementInstance = self.MovementModule.new(self)

	local button_handler_instance = buttons_handler_module.new(source, config, self)

	self.Queue = self.QueueModule.new(self)

	-- 09/06/2025: Counterweight implementation
	self.Counterweight = if self.Source:FindFirstChild('Counterweight', true) and self.Source:FindFirstChild('Counterweight', true):FindFirstChild('Main') then self.Source:FindFirstChild('Counterweight', true) else nil
	self.CWStart = if self.Counterweight then self.Counterweight.Main.CFrame else nil
	self.CWBottom = if self.Counterweight then CFrame.new(self.CWStart.Position-Vector3.new(0, (self.TopFloor.Level.Position.Y-self.BottomFloor.Level.Position.Y), 0))*CFrame.fromOrientation(self.CWStart:ToOrientation()) else nil
	if self.Counterweight then
		local val = Instance.new('CFrameValue')
		val.Name = 'target_position'
		val.Value = self.CWStart
		val:SetAttribute('is_active', false)
		val.Parent = self.Counterweight.Main
		self.WeldingModule.WeldPartsInModel(self.Counterweight, self.Counterweight.Main, {}, self.Counterweight.Main)
		self.Counterweight.Main.Anchored = true
	end
	local targetCWVal = Instance.new('ObjectValue')
	targetCWVal.Name = 'Target_Counterweight'
	targetCWVal:SetAttribute('IsAvailable', if self.Counterweight then true else false)
	targetCWVal.Value = if self.Counterweight then self.Counterweight.Main else nil
	targetCWVal.Parent = self.ElevatorFolder
	local val = Instance.new('ObjectValue')
	val.Name = 'Values'
	val.Value = self.ValuesFolder
	val.Parent = targetCWVal.Value
	
	function self.IndexInTable(t: any, index: number)
		if typeof(t) ~= 'table' then return error('Table (argument #1) must be a table') end
		if typeof(index) ~= 'number' then return error('Index (argument #2) must be a number') end
		local currentIndex = 0
		for i, v in t do
			currentIndex += 1
			if currentIndex == index then
				return v
			end
		end
		return nil
	end

	--

	-- Handle lanterns --
	local function SetupLanterns(group: Instance, audio_config: any)
		local lanternApi = Instance.new('BindableEvent')
		lanternApi.Name = 'Lantern_API'
		lanternApi.Parent = group
		for i, v in group:GetDescendants() do
			if v.Name ~= 'Lanterns' or not v:IsA('Model') then continue end

			local chimeBoxPart = Instance.new('Part')
			chimeBoxPart.Name = 'Chime_Box'
			chimeBoxPart.CFrame, chimeBoxPart.Size = v:GetBoundingBox()
			chimeBoxPart.Transparency = 1
			chimeBoxPart.CanCollide = false
			chimeBoxPart.CanQuery = false

			if chimeBoxPart:IsDescendantOf(self.Car) then
				self.WeldingModule.WeldParts(chimeBoxPart, self.Platform, true, false)
			elseif group:FindFirstChild('Level') then
				self.WeldingModule.WeldParts(chimeBoxPart, group.Level, true, false)
			else
				chimeBoxPart.Anchored = true
			end

			chimeBoxPart.Parent = v
			local chime_up = self.AudioModule.AddSoundFromConfig(chimeBoxPart, 'Chime_Up', {
				id = audio_config.up_chime.id,
				volume = audio_config.up_chime.volume,
				pitch = audio_config.up_chime.pitch+math.random(-100,100)/16000,
				looped = false,
				minDistance = audio_config.up_chime.roll_off.min,
				maxDistance = audio_config.up_chime.roll_off.max,
				rollOffMode = audio_config.up_chime.roll_off.mode,
				on_add = audio_config.up_chime.on_add
			})
			local chime_down = self.AudioModule.AddSoundFromConfig(chimeBoxPart, 'Chime_Down', {
				id = audio_config.down_chime.id,
				volume = audio_config.down_chime.volume,
				pitch = audio_config.down_chime.pitch+math.random(-100,100)/16000,
				looped = false,
				minDistance = audio_config.down_chime.roll_off.min,
				maxDistance = audio_config.down_chime.roll_off.max,
				rollOffMode = audio_config.down_chime.roll_off.mode,
				on_add = audio_config.down_chime.on_add
			})
			chime_up:SetAttribute('volume', chime_up.Volume)
			chime_down:SetAttribute('volume', chime_down.Volume)
		end
		task.defer(function()
			lanternApi:Fire('set_lantern', { state = 'inactive', direction = 1, config = self.Config.color_config.lanterns[group:IsDescendantOf(self.Car) and 'interior' or 'exterior'], ring_chime = false })
			lanternApi:Fire('set_lantern', { state = 'inactive', direction = -1, config = self.Config.color_config.lanterns[group:IsDescendantOf(self.Car) and 'interior' or 'exterior'], ring_chime = false })
		end)
	end

	SetupLanterns(self.Car, config.sounds.chimes.interior)
	for i, floor in self.Floors do
		SetupLanterns(floor.FloorModel, config.sounds.chimes.exterior)
	end
	----

	-- Add audios --
	self.CabRegion = self.Car:FindFirstChild('Cab_Region')
	if not self.CabRegion then
		self.CabRegion = Instance.new('Part')
		self.CabRegion.Name = 'Cab_Region'
		self.CabRegion.CFrame, self.CabRegion.Size = self.Platform.CFrame*CFrame.new(0, (self.Platform.Size.Y+10)/2, 0), Vector3.new(self.Platform.Size.X-1, self.Platform.Size.Y+10, self.Platform.Size.Z-1)
		self.CabRegion.Transparency = 1
		self.CabRegion.CanCollide = false
		self.CabRegion.CanQuery = false
		self.CabRegion.Parent = self.Car
	end

	self.AudioModule.AddSoundFromConfig(self.CabRegion, 'Floor_Pass_Chime', config.sounds.chimes.floor_passing_chime)
	self.AudioModule.AddSoundFromConfig(self.CabRegion, 'Alarm', config.sounds.alarm, {looped = true})
	if config.sounds.nudge_signal_loop then
		self.AudioModule.AddSoundFromConfig(self.CabRegion, 'Nudge_Signal_Loop', config.sounds.nudge_signal_loop, {looped = true})
	end
	self.AudioModule.AddSoundFromConfig(self.CabRegion, 'Alarm_Release', config.sounds.alarm.release_sound)
	local travelingSound = self.AudioModule.AddSoundFromConfig(self.CabRegion, 'Traveling_Sound', config.sounds.traveling_sound, { looped = true })
	travelingSound:SetAttribute('minVolume', config.sounds.traveling_sound.speed_ramping.volume.min)
	travelingSound:SetAttribute('maxVolume', config.sounds.traveling_sound.speed_ramping.volume.max)
	travelingSound:SetAttribute('minPitch', config.sounds.traveling_sound.speed_ramping.pitch.min)
	travelingSound:SetAttribute('maxPitch', config.sounds.traveling_sound.speed_ramping.pitch.max)

	if config.sounds.motor_sounds then
		for dir, data in config.sounds.motor_sounds do
			for motor_name, v in data do
				local soundName = `Motor_{string.upper(string.sub(motor_name, 1, 1))}{string.sub(motor_name, 2)}_{string.upper(string.sub(dir, 1, 1))}{string.sub(dir, 2)}`
				local sound = self.AudioModule.AddSoundFromConfig(self.CabRegion, soundName, v, v.on_add)
				sound.Looped = motor_name == 'run'
			end
		end
	end

	travelingSound.Volume = 0
	travelingSound.PlaybackSpeed = 0
	travelingSound.Playing = true

	----

	-- Lanterns internal API check --
	function self.InvokeLanternAPIWithCheckAsync(lantern_config: any, lantern_color_config: any, call_check_function: any, api_to_fire: BindableEvent)
		if lantern_config.enable and ((lantern_config.limit_to_hall_call and (typeof(call_check_function) == 'function' and call_check_function())) or (not lantern_config.limit_to_hall_call)) then
			task.delay(lantern_config.delay, function()
				api_to_fire:Fire('set_lantern', { state = 'active', direction = self.StatValues.QueueDirection, config = lantern_color_config, ring_chime = lantern_config.ring_chime })
			end)
		end
	end
	----

	self.door_data = {}

	function self.CheckAllDoorStates(state: string)
		for i, v in self.door_data do
			if v.state ~= state then return false end
		end
		return true
	end

	-- Weld the car --
	local weldsFolder = self.Car:FindFirstChild('Car_Welds') or Instance.new('Folder')
	weldsFolder.Name = 'Car_Welds'
	weldsFolder.Parent = self.Car

	local doorPartsToIgnore = {}
	for i, v in self.Car:GetChildren() do
		local doorSide = string.split(v.Name, 'Doors')[2] and string.split(v.Name, 'Doors')[1]
		if (not doorSide) then continue end
		if string.match(doorSide, '_') then
			doorSide = string.split(doorSide, '_')[2] and string.split(doorSide, '_')[1]
		end
		self.door_data[doorSide] = self.DoorSetupModule.new(source, v, self)

		for i, p in v:GetDescendants() do
			if ((not p:IsA('BasePart')) or p.Name == 'Open') then continue end
			table.insert(doorPartsToIgnore, p)
		end
	end

	for i, floor in self.Floors do
		for i, door in floor.FloorModel:GetDescendants() do
			local doorSide = string.split(door.Name, 'Doors')[2] and string.split(door.Name, 'Doors')[1]
			if (not doorSide) then continue end
			if string.match(doorSide, '_') then
				doorSide = string.split(doorSide, '_')[2] and string.split(doorSide, '_')[1]
			end

			local lastSafetyCheck = true
			for i, v in door:GetChildren() do
				local scaler, open = v:FindFirstChild('Scaler'), v:FindFirstChild('Scaler') and v.Scaler:FindFirstChild('Open')
				if (not scaler) or (not open) then continue end
				local doorData = self.door_data[doorSide]
				if not doorData then continue end

				if not doorData.floor_door_welds then
					doorData.floor_door_welds = {}
				end

				self.WeldingModule.WeldPartsInModel(v, scaler, {open})
				self.WeldingModule.WeldParts(open, floor.Level, true, false)
				open.Anchored = false
				local engineWeld = self.WeldingModule.WeldParts(scaler, open, true, false)
				engineWeld.Name = 'Door_Engine_Weld'
				engineWeld:SetAttribute('open_point', engineWeld.C1)
				engineWeld:SetAttribute('closed_point', engineWeld.C0)
				engineWeld:SetAttribute('Side', doorSide)
				doorData.floor_door_welds[#doorData.floor_door_welds+1] = engineWeld

				-- Handle door safety --
				engineWeld:GetPropertyChangedSignal('C0'):Connect(function()
					task.wait()
					local safetyMet = true
					for i, v in doorData.engine_welds do
						if (v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude >= .06 and doorData.state == 'Closed' then safetyMet = false break end
					end
					for i, v in doorData.floor_door_welds do
						if (v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude >= .035 and doorData.state == 'Closed' then safetyMet = false break end
					end
					if lastSafetyCheck == safetyMet then return end
					lastSafetyCheck = safetyMet
					self.StatValues.OutOfService = not safetyMet
					task.spawn(self.UpdateStatValues)
					if not safetyMet then
						print('Safety braking', doorData.side)
						self.MovementInstance.safety_brake()
					else
						self.StatValues.DoorSafetyLock = false
						self.MovementInstance.resumeFloorCall()
					end
				end)
				----

				local val = Instance.new('ObjectValue')
				val.Name = 'Engine_Weld'
				val.Value = engineWeld
				val.Parent = doorData.engine_welds_folder

				local value = Instance.new('CFrameValue')
				value.Name = 'target_position'
				value.Value = engineWeld.C0
				value.Parent = engineWeld

			end
		end
	end

	self.WeldingModule.WeldPartsInModel(self.Car, self.Platform, doorPartsToIgnore, weldsFolder)
	self.Platform.Anchored = true

	button_handler_instance.Setup(self)

	-- Limit switch check --
	function self.check_limit_switch(top_or_bottom: string)
		if (top_or_bottom == 'bottom' and (self[`{top_or_bottom}_floor`].Level.Position.Y-self.CurrentPosition.Position.Y) >= .35)
			or (top_or_bottom == 'top' and (self[`{top_or_bottom}_floor`].Level.Position.Y-self.CurrentPosition.Position.Y) <= -.35) then return true end
		return false
	end

	local access_move_threads = {}
	local access_move_connections = {}
	local fire_recall_threads = {}

	self.API.Event:Connect(function(protocol, params)
		task.spawn(self.Remote.FireAllClients, self.Remote, protocol, params)
		if protocol == 'door_signal' then
			local sides = typeof(params.sides) == 'table' and params.sides or params.sides == 'all' and 'all' or 'all'
			local hallCall = if typeof(params.hall_call) == 'boolean' then params.hall_call else false
			if params.request == 'open' or params.request == 'close' then
				if sides == 'all' then
					for i, data in self.door_data do
						if params.request == 'open' then
							data[params.request](typeof(params.open_time) == 'number' and params.open_time or self.Config.doors.door_timers.open_no_call, hallCall)
						else
							data[params.request](params.nudge)
						end
					end
				else
					for i, v in sides do
						local data = self.door_data[v]
						if not data then continue end
						if params.request == 'open' then
							data[params.request](typeof(params.open_time) == 'number' and params.open_time or self.Config.doors.door_timers.open_no_call, hallCall)
						else
							data[params.request](params.nudge)
						end
					end
				end
			end
		elseif protocol == 'AddCarCall' then
			self.Queue.AddCarCall(params.call, params.is_locked, params.sides) -- NOTE 09/27: 'is_locked' & 'sides' TO BE IMPLEMENTED
		elseif protocol == 'AddHallCall' then
			self.Queue.AddHallCall(params.call, params.direction, params.is_locked, params.sides) -- NOTE 09/27: 'is_locked' & 'sides' TO BE IMPLEMENTED
		elseif protocol == 'access_mode' then
			if params == true then
				self.StatValues.OutOfService = true
				task.spawn(self.UpdateStatValues)
				if self.StatValues.MoveDirection ~= 0 then
					self.MovementInstance.safety_brake()
				end
			else
				self.StatValues.OutOfService = false
				task.spawn(self.UpdateStatValues)
			end
		elseif protocol == 'move_access' then
			if not self.StatValues.OutOfService then return end
			if (params.direction == 1 and not self.check_limit_switch('top')) or (params.direction == -1 and not self.check_limit_switch('bottom')) then
				for i, v in access_move_threads do
					pcall(task.cancel, v)
				end
				for i, v in access_move_connections do
					if not v.Connected then continue end
					v:Disconnect()
				end
				table.clear(access_move_threads)
				table.clear(access_move_connections)

				local movementCfg = self.Config.movement[params.direction == 1 and 'up' or 'down']
				table.insert(access_move_threads, task.delay(params.start_delay, function()
					self.StatValues.MoveDirection = params.direction
					task.spawn(self.UpdateStatValues)
					table.insert(access_move_connections, self.Step:Connect(function(dtTime)
						if (params.direction == 1 and self.check_limit_switch('top')) or (params.direction == -1 and self.check_limit_switch('bottom')) then
							return self.API:Fire('move_access', { direction = 0 })
						end

						self.StatValues.speed = math.min(self.StatValues.speed+movementCfg.acceleration.acceleration_rate*math.deg(dtTime), params.speed)

						self.CurrentPosition = CFrame.new(self._InitialPosition.Position.X, self.CurrentPosition.Position.Y+self.StatValues.MoveDirection*self.StatValues.speed*dtTime, self._InitialPosition.Position.Z)*CFrame.fromOrientation(self._InitialPosition:ToOrientation())
						self.Platform.target_position.Value = self.CurrentPosition

						self.AudioModule.Sounds.Traveling_Sound.Volume = self.AudioModule.Sounds.Traveling_Sound:GetAttribute('minVolume')+(self.AudioModule.Sounds.Traveling_Sound:GetAttribute('maxVolume')-self.AudioModule.Sounds.Traveling_Sound:GetAttribute('minVolume'))*(self.StatValues.speed/movementCfg.traveling_speed)
						self.AudioModule.Sounds.Traveling_Sound.PlaybackSpeed = self.AudioModule.Sounds.Traveling_Sound:GetAttribute('minPitch')+(self.AudioModule.Sounds.Traveling_Sound:GetAttribute('maxPitch')-self.AudioModule.Sounds.Traveling_Sound:GetAttribute('minPitch'))*(self.StatValues.speed/movementCfg.traveling_speed)

						local nearFloor = self.GetNearestFloor().FloorNumber
						if (nearFloor ~= self.StatValues.Floor) then
							self.StatValues.Floor = nearFloor
							if self.Config.sounds.chimes.floor_passing_chime.enable then
								self.AudioModule.Sounds.Floor_Pass_Chime:Play()
							end
						end
						self.StatValues.velocity = (self.StatValues.speed^2)^.5
						task.spawn(self.UpdateStatValues)
					end))
				end))
			elseif params.direction == 0 then
				for i, v in access_move_threads do
					pcall(task.cancel, v)
				end
				for i, v in access_move_connections do
					if not v.Connected then continue end
					v:Disconnect()
				end
				table.clear(access_move_threads)
				table.clear(access_move_connections)

				local movementCfg = self.Config.movement[self.StatValues.MoveDirection == 1 and 'up' or 'down']
				table.insert(access_move_threads, task.spawn(function()
					table.insert(access_move_connections, self.Step:Connect(function(dtTime)
						self.StatValues.speed = math.max(0, self.StatValues.speed-.35)

						self.CurrentPosition = CFrame.new(self._InitialPosition.Position.X, self.CurrentPosition.Position.Y+self.StatValues.MoveDirection*self.StatValues.speed*dtTime, self._InitialPosition.Position.Z)*CFrame.fromOrientation(self._InitialPosition:ToOrientation())
						self.Platform.target_position.Value = self.CurrentPosition

						self.AudioModule.Sounds.Traveling_Sound.Volume = self.AudioModule.Sounds.Traveling_Sound:GetAttribute('minVolume')+(self.AudioModule.Sounds.Traveling_Sound:GetAttribute('maxVolume')-self.AudioModule.Sounds.Traveling_Sound:GetAttribute('minVolume'))*(self.StatValues.speed/movementCfg.traveling_speed)
						self.AudioModule.Sounds.Traveling_Sound.PlaybackSpeed = self.AudioModule.Sounds.Traveling_Sound:GetAttribute('minPitch')+(self.AudioModule.Sounds.Traveling_Sound:GetAttribute('maxPitch')-self.AudioModule.Sounds.Traveling_Sound:GetAttribute('minPitch'))*(self.StatValues.speed/movementCfg.traveling_speed)

						local nearFloor = self.GetNearestFloor().FloorNumber
						if (nearFloor ~= self.StatValues.Floor) then
							self.StatValues.Floor = nearFloor
							if self.Config.sounds.chimes.floor_passing_chime.enable then
								self.AudioModule.Sounds.Floor_Pass_Chime:Play()
							end
						end
						self.StatValues.velocity = (self.StatValues.speed^2)^.5
						task.spawn(self.UpdateStatValues)
						if self.StatValues.speed == 0 then
							for i, v in access_move_threads do
								pcall(task.cancel, v)
							end
							for i, v in access_move_connections do
								if not v.Connected then continue end
								v:Disconnect()
							end
							table.clear(access_move_threads)
							table.clear(access_move_connections)
							return
						end
					end))
				end))
			end
		elseif protocol == 'fire_recall' then
			if params.recall == self.StatValues.FireService.Recall then return end
			if params.recall == true then
				local floor_instance = self.FindFloor(params.floor)
				if not floor_instance then return end

				self.StatValues.FireService.Recall = true
				self.fire_recall_floor = params.floor
				task.spawn(self.UpdateStatValues)

				for i, v in self.Queue.Car_Calls do
					self.Queue.RemoveCarCall(v.Call)
				end
				for i, v in self.Queue.HallCalls do
					for i, d in v.Directions do
						self.Queue.RemoveHallCall(v.Call, v.Directions)
					end
				end

				if (self.StatValues.MoveDirection == 1 and self.StatValues.Floor > params.floor) or (self.StatValues.MoveDirection == -1 and self.StatValues.Floor < params.floor) or (self.StatValues.Floor == params.floor and self.StatValues.MoveDirection ~= 0 and not self.StatValues.Leveling) then
					print('Fire Service: Elevator needs to stop at a nearby floor')
					local movementCfg = self.Config.movement[self.StatValues.MoveDirection == 1 and 'up' or 'down']
					local stopping_distance = movementCfg.stopping.distance_to_stop*(self.StatValues.speed/movementCfg.traveling_speed)+self.StatValues.speed

					local nearest_floor, dist = nil, math.huge
					for i, v in self.Floors do
						if (self.StatValues.MoveDirection == 1 and v.FloorNumber <= self.StatValues.Floor) or (self.StatValues.MoveDirection == -1 and v.FloorNumber >= self.StatValues.Floor) then continue end
						local near_dist = math.abs(v.Level.Position.Y-(self.CurrentPosition.Position.Y+stopping_distance))
						if near_dist <= dist then
							dist = near_dist
							nearest_floor = v
						end
					end
					if not nearest_floor then return end
					self.StatValues.Destination = nearest_floor.FloorNumber
					task.spawn(self.UpdateStatValues)
				else
					-- Open all elevator doors --
					if self.fire_recall_floor ~= self.StatValues.Floor then
						self.Queue.AddCarCall(self.fire_recall_floor, true)
					else
						self.API:Fire('door_signal', { sides = 'all', request = 'open' })
					end
				end

			else
				local last_recall_floor = self.fire_recall_floor
				self.Queue.RemoveCarCall(self.fire_recall_floor)
				self.StatValues.FireService.Recall = false
				self.fire_recall_floor = nil
				task.spawn(self.UpdateStatValues)
				if self.MovementInstance.MovementThreads.fire_recall then
					pcall(task.cancel, self.MovementInstance.MovementThreads.fire_recall)
					self.MovementInstance.MovementThreads.fire_recall = nil
				end
				if last_recall_floor ~= self.StatValues.Floor then return end
				self.API:Fire('door_signal', { sides = 'all', request = 'close' })
			end
		elseif protocol == 'phase_2' then
			self.StatValues.phase_2 = params.value
			task.spawn(self.UpdateStatValues)
		elseif protocol == 'stop' then
			self.StatValues.Stop = params
			task.spawn(self.UpdateStatValues)
			if params == true then
				if self.StatValues.MoveDirection ~= 0 then
					self.MovementInstance.SafetyBrake()
				end
			else
				self.StatValues.DoorSafetyLock = false
				self.MovementInstance.ResumeFloorCall()
			end
		end
	end)

	dataApi.OnInvoke = function(protocol, params)
		if protocol == 'GetController' then
			return self
		end
	end

	for i, v in source.Controller:FindFirstChild('Plugins') and source.Controller.Plugins:GetChildren() or {} do
		if not v:IsA('ModuleScript') then continue end
		local ran, res = pcall(require, v)
		if (not ran) or (typeof(res) ~= 'table') then continue end
		if res.button_input_handler then
			self.ButtonInputConditionFunc = res
		end
		if not res.init then continue end
		task.spawn(res.init, self)
	end

	print(`Setup complete! ({math.round((os.clock()-initStart)*1000)/1000}s)`)

	controllers[elevatorID] = self

	return self
end

return ControllerClass