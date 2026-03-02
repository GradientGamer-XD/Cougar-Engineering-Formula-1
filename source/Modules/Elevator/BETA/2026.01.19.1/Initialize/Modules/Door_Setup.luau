local RunService = game:GetService('RunService')

local abs, rad, deg, min, max, clamp, cf_new, cf_angles = math.abs, math.rad, math.deg, math.min, math.max, math.clamp, CFrame.new, CFrame.Angles

local function lerp(a, b, t)
	return a+(b-a)*t
end

local function getAccelerationTime(initialSpeed: number, finalSpeed: number, rate: number)
	return math.abs(finalSpeed-initialSpeed)/math.deg(rate)
end

local function convertString(snakeStr)
	local pascalStr = snakeStr:gsub("_(%a)", function(letter)
		return letter:upper()
	end)
	return pascalStr:sub(1, 1):upper() .. pascalStr:sub(2)
end

local doorClass = {}
doorClass.className = 'doorClass'
doorClass.__index = function(self, key)
	if typeof(key) == 'string' and (string.sub(key, 1, 1) == string.sub(string.lower(key), 1, 1) or key == 'current_position') then
		local newKey = convertString(key)
		if newKey == 'Api' then newKey = 'API' end -- Additional correction
		if newKey == 'CheckLanternAndFire' then newKey = 'InvokeLanternAPIWithCheckAsync' end
		return self[newKey]
	end
end

local humanoids = {}
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local function processHumanoid(rig: Instance)
	local root, humanoid = rig:FindFirstChild('HumanoidRootPart'), rig:FindFirstChildWhichIsA('Humanoid')
	if (not humanoid) or (not root) then return end
	humanoids[#humanoids+1] = root
	overlapParams.FilterDescendantsInstances = humanoids
end

for i, rig in workspace:GetDescendants() do
	processHumanoid(rig)
end
workspace.DescendantAdded:Connect(processHumanoid)

local Signal = require(script.Parent.Signal)

function doorClass.new(source, door, controller)
	local doorSide = string.split(door.Name, 'Doors')[2] and string.split(door.Name, 'Doors')[1]
	if (not doorSide) then return end

	if string.match(doorSide, '_') then
		doorSide = string.split(doorSide, '_')[2] and string.split(doorSide, '_')[1]
	end

	local self = setmetatable({}, doorClass)

	self.__index = doorClass.__index

	self.Source = source
	self.Door = door

	self.DoorConfig = controller.Config.doors
	self.State = 'Closed'
	self.EngineWelds = {}
	self.FloorWelds = {}
	self.MasterWeld = nil
	self.Side = doorSide

	self.Disabled = false -- 04/10/2025: Add "Disabled" to :Stop() function

	self.Door:SetAttribute('state', self.State)

	self.OpeningThreads = {}
	self.ClosingThreads = {}

	self.OpeningConnections = {}
	self.ClosingConnections = {}

	self.Alpha = 0
	self.Velocity = 0
	self.VelocityDiff = 0
	self.LastVelocity = self.Velocity

	self.TimerStart = 0
	self.NudgeTimerStart = 0
	self.IsObstructed = false
	self.Nudging = false

	self.stages = {} -- 10/10/2025: Move stages dictionary to door data: Improve door acceleration stages logic

	self.Opening = Signal.new()
	self.Opened = Signal.new()

	self.Closing = Signal.new()
	self.Closed = Signal.new()

	-- Door state values --
	self.DoorStateName = `{string.lower(doorSide)}_door_state`
	controller.StatValues[self.DoorStateName] = self.State
	self.DoorStateValue = Instance.new('StringValue')
	self.DoorStateValue.Name = `{doorSide}_Door_State`
	self.DoorStateValue.Value = self.State
	self.DoorStateValue.Parent = controller.ValuesFolder
	controller.StatValueInstances[self.DoorStateValue] = {
		instance = self.DoorStateValue,
		update = function()
			self.DoorStateValue.Value = controller.StatValues[self.DoorStateName]
		end,
	}
	----

	-- Nudge value --
	self.NudgeValueName = `{string.lower(doorSide)}_door_nudge`
	controller.StatValues[self.NudgeValueName] = self.Nudging
	self.NudgeValue = Instance.new('BoolValue')
	self.NudgeValue.Name = `{doorSide}_Door_Nudge`
	self.NudgeValue.Value = self.Nudging
	self.NudgeValue.Parent = controller.ValuesFolder
	controller.StatValueInstances[self.NudgeValue] = {
		instance = self.NudgeValue,
		update = function()
			self.NudgeValue.Value = controller.StatValues[self.NudgeValueName]
		end,
	}
	----

	-- Speed value --
	self.SpeedValueName = `{string.lower(doorSide)}_door_speed`
	controller.StatValues[self.SpeedValueName] = self.Velocity
	self.SpeedValue = Instance.new('NumberValue')
	self.SpeedValue.Name = `{doorSide}_Door_Speed`
	self.SpeedValue.Value = self.Velocity
	self.SpeedValue.Parent = controller.ValuesFolder
	controller.StatValueInstances[self.SpeedValue] = {
		instance = self.SpeedValue,
		update = function()
			self.SpeedValue.Value = controller.StatValues[self.SpeedValueName]
		end,
	}
	----

	self.DoorsFolder = Instance.new('Folder')
	self.DoorsFolder.Name = `{doorSide}_Doors_Data`
	self.DoorsFolder.Parent = controller.ElevatorFolder
	self.EngineWeldsFolder = Instance.new('Folder')
	self.EngineWeldsFolder.Name = 'Engine_Welds'
	self.EngineWeldsFolder.Parent = self.DoorsFolder

	self.BoundingBox = Instance.new('Part')
	self.BoundingBox.Name = 'Door_Bounds'
	self.BoundingBox.CFrame, self.BoundingBox.Size = self.Door:GetBoundingBox()
	self.BoundingBox.CanCollide = false
	self.BoundingBox.AudioCanCollide = false
	self.BoundingBox.Transparency = 1
	self.BoundingBox.CanQuery = false
	controller.WeldingModule.WeldParts(self.BoundingBox, controller.Platform, true)
	self.BoundingBox.Parent = self.Door

	-- 04/11/2025- Condense all sound instances into a table for neatness
	self.Sounds = {}

	self.Sounds.GlobalOpenSound = controller.AudioModule.AddSoundFromConfig(self.BoundingBox, 'Open_Sound', {
		id = controller.Config.sounds.door_sounds.open_sound.id,
		volume = controller.Config.sounds.door_sounds.open_sound.volume,
		pitch = controller.Config.sounds.door_sounds.open_sound.pitch,
		Looping = false,
		minDistance = controller.Config.sounds.door_sounds.open_sound.roll_off.min,
		maxDistance = controller.Config.sounds.door_sounds.open_sound.roll_off.max,
		rollOffMode = controller.Config.sounds.door_sounds.open_sound.roll_off.mode
	})
	self.GlobalCloseSound = controller.AudioModule.AddSoundFromConfig(self.BoundingBox, 'Close_Sound', {
		id = controller.Config.sounds.door_sounds.close_sound.id,
		volume = controller.Config.sounds.door_sounds.close_sound.volume,
		pitch = controller.Config.sounds.door_sounds.close_sound.pitch,
		Looping = false,
		minDistance = controller.Config.sounds.door_sounds.close_sound.roll_off.min,
		maxDistance = controller.Config.sounds.door_sounds.close_sound.roll_off.max,
		rollOffMode = controller.Config.sounds.door_sounds.close_sound.roll_off.mode
	})

	self.IsDeparting = false

	self.OpeningTimeout = {
		Start = 0,
		Duration = 0,
		Retries = 0,
		Max_Retries = 3
	}

	function self.SetupDoorSounds()
		if typeof(controller.Config.sounds.door_sounds.floors) == 'table' then
			for i, v in controller.Config.sounds.door_sounds.floors do
				local indexString = `Floor{i}%sSound`
				local soundName = `Floor_{i}_%s_Sound`
				self.Sounds[string.format(indexString, 'Open')] = controller.AudioModule.AddSoundFromConfig(self.BoundingBox, string.format(soundName, 'Open'), {
					id = v.open_sound.id,
					volume = v.open_sound.volume,
					pitch = v.open_sound.pitch,
					Looping = false,
					minDistance = v.open_sound.roll_off.min,
					maxDistance = v.open_sound.roll_off.max,
					rollOffMode = v.open_sound.roll_off.mode
				})
				self.Sounds[string.format(indexString, 'Close')] = controller.AudioModule.AddSoundFromConfig(self.BoundingBox, string.format(soundName, 'Close'), {
					id = v.close_sound.id,
					volume = v.close_sound.volume,
					pitch = v.close_sound.pitch,
					Looping = false,
					minDistance = v.close_sound.roll_off.min,
					maxDistance = v.close_sound.roll_off.max,
					rollOffMode = v.close_sound.roll_off.mode
				})
			end
		end
	end

	function self.SetupDoorWelds()
		for i, v in self.Door:GetChildren() do
			local scaler, open = v:FindFirstChild('Scaler'), v:FindFirstChild('Scaler') and v.Scaler:FindFirstChild('Open')
			if (not scaler) or (not open) then continue end

			controller.WeldingModule.WeldPartsInModel(v, scaler, {open})
			local engineWeld = controller.WeldingModule.WeldParts(scaler, open, true, false)
			engineWeld.Name = 'Door_Engine_Weld'
			engineWeld:SetAttribute('open_point', engineWeld.C1)
			engineWeld:SetAttribute('closed_point', engineWeld.C0)
			engineWeld:SetAttribute('Side', self.Side)

			local value = Instance.new('CFrameValue')
			value.Name = 'target_position'
			value.Value = engineWeld.C0
			value.Parent = engineWeld

			-- Handle door safety --
			local lastSafetyCheck = true
			engineWeld.target_position:GetPropertyChangedSignal('Value'):Connect(function()
				task.wait()
				local safetyMet = controller.CheckDoorTolerance('inner', {.175, .065}) and controller.CheckDoorTolerance('outer', {.175, .065})
				if lastSafetyCheck == safetyMet then return end

				lastSafetyCheck = safetyMet
				if not safetyMet then
					if controller.StatValues.DoorSafetyLock then
						controller.StatValues.OutOfService = not safetyMet
						task.spawn(controller.UpdateStatValues)

						warn(`{self.Side} (inner) doors breached safety zone(s)`)
						if controller.StatValues.MoveDirection ~= 0 then
							controller.MovementInstance.safety_brake()
						end
						return
					end
					return
				end
				if (not controller.StatValues.OutOfService and safetyMet and not self.Disabled) or (not controller.CheckDoorTolerance('outer', {.175, .065}) and controller.CheckDoorTolerance('inner', {.175, .065})) then return end

				controller.StatValues.OutOfService = not safetyMet
				task.spawn(controller.UpdateStatValues)
				controller.StatValues.DoorSafetyLock = false
				controller.MovementInstance.resumeFloorCall()
			end)
			----

			local val = Instance.new('ObjectValue')
			val.Name = 'Engine_Weld'
			val.Value = engineWeld
			val.Parent = self.EngineWeldsFolder

			table.insert(self.EngineWelds, engineWeld)
		end

		local dist = -math.huge
		for i, v in self.EngineWelds do
			local d = (v:GetAttribute('open_point').Position-v:GetAttribute('closed_point').Position).Magnitude
			if d >= dist then
				dist = d
				self.MasterWeld = v
			end
		end
	end

	function self.SetupDoorSafetyCheck()
		local safetyMet = true
		for i, v in self.EngineWelds do
			if (v:GetAttribute('closed_point').Position-v.target_position.Value.Position).Magnitude >= .135 then safetyMet = false break end
		end
		for i, v in self.floor_door_welds or {} do
			if (v:GetAttribute('closed_point').Position-v.target_position.Value.Position).Magnitude >= .035 then safetyMet = false break end
		end

		for i, engineWeld in self.EngineWelds do
			-- Handle door safety --
			local lastSafetyCheck = true
			engineWeld.target_position:GetPropertyChangedSignal('Value'):Connect(function()
				task.wait()
				local safetyMet = controller.CheckDoorTolerance('inner', {.175, .065}) and controller.CheckDoorTolerance('outer', {.175, .065})
				if lastSafetyCheck == safetyMet then return end

				lastSafetyCheck = safetyMet
				if not safetyMet then
					if controller.StatValues.DoorSafetyLock then
						controller.StatValues.OutOfService = not safetyMet
						task.spawn(controller.UpdateStatValues)

						warn(`{self.Side} (inner) doors breached safety zone(s)`)
						if controller.StatValues.MoveDirection ~= 0 then
							controller.MovementInstance.safety_brake()
						end
						return
					end
					return
				end
				if (not controller.StatValues.OutOfService and safetyMet and not self.Disabled) or (not controller.CheckDoorTolerance('outer', {.175, .065}) and controller.CheckDoorTolerance('inner', {.175, .065})) then return end

				controller.StatValues.OutOfService = not safetyMet
				task.spawn(controller.UpdateStatValues)
				controller.StatValues.DoorSafetyLock = false
				controller.MovementInstance.resumeFloorCall()
			end)
			----
			if not safetyMet then
				if (controller.StatValues.DoorSafetyLock and controller.StatValues.MoveDirection ~= 0) or (not controller.CheckDoorTolerance('inner', {.175, .065}) and controller.CheckDoorTolerance('outer', {.175, .065})) then
					controller.StatValues.OutOfService = not safetyMet
					task.spawn(controller.UpdateStatValues)

					warn(`{self.Side} (inner) doors breached safety zone(s)`)
					return controller.MovementInstance.safety_brake()
				end
			end
		end
	end

	function self.Open(data: { open_time: number, lantern_signal: boolean?, bypass_nudge: boolean?, disable_safety_lock: boolean?, bypass_door_zone: boolean?, open_floor_doors: boolean?, bypass_disabled_elevator: boolean? })

		local previousState = self.State == 'Stopped' and 'Closed' or self.State
		if (previousState ~= 'Closed' and previousState ~= 'Closing' and self.State ~= 'Stopped') or (data.bypass_disabled_elevator ~= true and self.Disabled) or (self.Nudging and data.bypass_nudge ~= true) or (data.bypass_disabled_elevator ~= true and controller.StatValues.OutOfService) then return end

		local floor_instance = controller.FindFloor(controller.StatValues.Floor)
		if not floor_instance then return end

		local doorsModel = floor_instance.FloorModel:FindFirstChild(`{self.Side}_Doors`)
		if (not doorsModel) or self.Door:GetAttribute('is_door_key') or doorsModel:GetAttribute('is_door_key') then return end

		local LevelPosition = controller.CurrentPosition.Position.Y+(controller.Level.Position.Y-controller.Platform.Position.Y)
		local distance = abs(floor_instance.Level.Position.Y-LevelPosition)
		if distance >= .5 and data.bypass_door_zone ~= true then return warn('Unable to open doors, the elevator is not within the door zone') end

		if not data.open_time then
			data.open_time = 1 -- 10/10/2025: Hotfix; set a fallback value to prevent errors
		end

		if data.disable_safety_lock then
			controller.StatValues.DoorSafetyLock = false
		end

		if controller.StatValues.DoorSafetyLock then return end

		for i, v in self.ClosingThreads do
			pcall(task.cancel, v)
		end
		self.ClosingThreads = {}
		table.insert(self.OpeningThreads, task.spawn(function()
			if previousState == 'Closed' then
				self.FloorWelds = {}
			end

			self.State = 'Opening'
			self.Door:SetAttribute('state', self.State)
			controller.StatValues[self.DoorStateName] = self.State
			controller.UpdateStatValues()

			self.IsDeparting = false

			self.Opening:Fire()
			for i, v in self.OpeningConnections do
				if not v.Connected then continue end

				v:Disconnect()
			end
			self.OpeningConnections = {}

			if controller.MovementInstance.MovementThreads['park_timer'] then
				pcall(task.cancel, controller.MovementInstance.MovementThreads['park_timer'])
				controller.MovementInstance.MovementThreads['park_timer'] = nil
			end

			local doorConfigMain = controller.Config.doors.opening
			local doorDuration = self.DoorConfig.open_speed
			local thisDistance = (self.MasterWeld:GetAttribute('open_point').Position-self.MasterWeld:GetAttribute('closed_point').Position).Magnitude
			local doorSpeed = thisDistance/doorDuration

			local slowdown = false
			local signaling = false

			if previousState == 'Closing' then
				self.Velocity = -self.Velocity
			end

			self.OpeningTimeout.Start = os.clock()
			self.OpeningTimeout.Duration = doorDuration+10
			self.OpeningTimeout.Retries = if previousState == 'Closed' then 0 else self.OpeningTimeout.Retries -- Reset timeout retries if the doors start from the Closed state

			--if #self.stages == 0 then
			local lastStage
			for i, v in self.DoorConfig.opening.acceleration_stages do

				local stageData = {}

				stageData.speed, stageData.rate, stageData.delay = min(v.speed, doorSpeed), v.rate, v.delay
				stageData.duration = max(.001, getAccelerationTime(lastStage and min(self.Velocity, doorSpeed) or 0, stageData.speed, stageData.rate))

				function stageData.accel(i, callback: any)
					local startTime = os.clock()
					local initialVelocity = self.Velocity
					while ((os.clock()-startTime)/stageData.duration <= 1) do -- Accelerate the doors
						local lastTick = os.clock()
						controller.Step:Wait()
						local dtTime = os.clock()-lastTick
						self.LastVelocity = self.Velocity
						if (typeof(callback) == 'function') then callback(dtTime) end
						self.Velocity = lerp(initialVelocity, stageData.speed, min((os.clock()-startTime)/stageData.duration, 1))
						if (slowdown) then return end
					end
					startTime = os.clock()
					while ((os.clock()-startTime)/stageData.delay <= 1) do -- Handle delay
						local lastTick = os.clock()
						controller.Step:Wait()
						local dtTime = os.clock()-lastTick
						if (typeof(callback) == 'function') then callback(dtTime) end
					end
				end
				self.stages[i] = stageData
				lastStage = v

			end
			--end

			local initialVelocity, initialDistance

			local function checkWelds(target)
				if (self.MasterWeld.target_position.Value ~= self.MasterWeld:GetAttribute(target)) then return false end
				return true
			end

			local openSound = self.Sounds[`Floor{floor_instance.FloorNumber}OpenSound`] or self.Sounds.GlobalOpenSound
			local closeSound = self.Sounds[`Floor{floor_instance.FloorNumber}CloseSound`] or self.GlobalCloseSound
			table.insert(self.OpeningThreads, task.delay(previousState == 'Closed' and self.DoorConfig.open_sound_delay or 0, function()
				closeSound:Stop()
				openSound.TimePosition = 0
				openSound:Play()
			end))

			task.wait(previousState == 'Closed' and self.DoorConfig.open_delay or 0)
			controller.API:Fire('on_door_open', { side = self.Side })
			local startTime = os.clock()
			for i, weld in self.EngineWelds do
				weld.target_position:SetAttribute('is_active', true)
			end
			for i, weld in doorsModel:QueryDescendants('[Name="Door_Engine_Weld"]') do
				if data.open_floor_doors ~= nil and data.open_floor_doors ~= true then continue end

				weld.target_position:SetAttribute('is_active', true)
				table.insert(self.FloorWelds, weld)
			end

			if previousState == 'Closed' then
				self.NudgeTimerStart = os.clock()
			end

			local function handleWelds(dtTime)
				self.Alpha = clamp(self.Alpha+((self.Velocity/doorSpeed)/doorDuration)*dtTime, 0, 1)

				local currentDistanceVector = (self.MasterWeld:GetAttribute('open_point').Position-self.MasterWeld.target_position.Value.Position)
				local currentDistanceWithOffset = ((self.MasterWeld:GetAttribute('open_point').Position-currentDistanceVector.Unit*doorConfigMain.slowdown.final_slowdown_point)-self.MasterWeld.target_position.Value.Position)

				local currentDistance = currentDistanceVector.Magnitude
				local currentDistanceFactor = currentDistance/thisDistance
				if (currentDistanceFactor <= doorConfigMain.slowdown.slowdown_distance*(self.Velocity/doorSpeed) or slowdown) then
					if (not slowdown) then
						initialDistance = currentDistanceWithOffset
						initialVelocity = self.Velocity
						slowdown = true
					end

					currentDistanceWithOffset = ((self.MasterWeld:GetAttribute('open_point').Position-currentDistanceVector.Unit*(doorConfigMain.slowdown.final_slowdown_point))-(self.MasterWeld.target_position.Value.Position-currentDistanceVector.Unit*max(doorConfigMain.slowdown.final_slowdown_speed*.2*(self.Velocity/initialVelocity), 0)))

					local currentSpeed = self.Velocity
					local deceleration = currentSpeed^2/(2*max(.001, currentDistanceWithOffset.Magnitude))
					local SPEED = max(0, currentSpeed-deceleration*dtTime)
					self.Velocity = max(doorConfigMain.slowdown.final_slowdown_speed, SPEED)
				end

				for i, weld in self.EngineWelds do
					weld.target_position.Value = weld:GetAttribute('closed_point'):Lerp(weld:GetAttribute('open_point'), self.Alpha)
				end
				for i, weld in self.FloorWelds do
					local closed_point = weld:GetAttribute('closed_point')
					local open_point = weld:GetAttribute('open_point')
					local offsetVector = (closed_point.Position+(open_point.Position-closed_point.Position)*self.Alpha)-(open_point.Position-closed_point.Position).Unit*doorConfigMain.door_clutch_offset
					weld.target_position.Value = weld.target_position.Value:Lerp(cf_new(
						clamp(offsetVector.X, closed_point.Position.X <= open_point.Position.X and closed_point.Position.X or open_point.Position.X, closed_point.Position.X >= open_point.Position.X and closed_point.Position.X or open_point.Position.X),
						clamp(offsetVector.Y, closed_point.Position.Y <= open_point.Position.Y and closed_point.Position.Y or open_point.Position.Y, closed_point.Position.Y >= open_point.Position.Y and closed_point.Position.Y or open_point.Position.Y),
						clamp(offsetVector.Z, closed_point.Position.Z <= open_point.Position.Z and closed_point.Position.Z or open_point.Position.Z, closed_point.Position.Z >= open_point.Position.Z and closed_point.Position.Z or open_point.Position.Z)
						)*CFrame.fromOrientation(weld:GetAttribute('closed_point'):ToOrientation()), clamp( min(dtTime/0.02, 1)--[[+(doorConfigMain.outer_door_spring_effect.enable == true and doorConfigMain.outer_door_spring_effect.threshold or 0)*(math.cos((os.clock()-startTime)*1*math.pi^2)*self.VelocityDiff*6)]], 0, 1 ))
				end

				self.VelocityDiff = lerp(self.VelocityDiff, ((self.Velocity-self.LastVelocity)/(dtTime/0.05)), min(dtTime/0.02, 1))
				controller.StatValues[self.SpeedValueName] = self.Velocity
				controller.UpdateStatValues()

				local TimePassed = os.clock()-self.OpeningTimeout.Start
				if TimePassed > self.OpeningTimeout.Duration and self.OpeningTimeout.Retries < self.OpeningTimeout.Max_Retries then
					self.OpeningTimeout.Retries += 1
					warn('Door opening timeout')
					if self.OpeningTimeout.Retries >= self.OpeningTimeout.Max_Retries then
						return self.Close(true, true)
					else
						self.ClosingThreads[#self.ClosingThreads+1] = task.delay(.5, self.Open, data)
						return self.Close(false, true)
					end
				end

				if (not checkWelds('open_point')) then return false end
				task.wait(dtTime/0.05)
				-- Lantern signal --
				if data.lantern_signal == true and signaling == false then
					signaling = true
					local nearestHallCall = controller.Queue.GetNearestHallCall(controller.StatValues.Floor, controller.StatValues.QueueDirection)
					local thisHallCall = controller.Queue.FindHallCall(controller.StatValues.Floor, controller.StatValues.QueueDirection)
					controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_after_door_open.exterior, controller.Config.color_config.lanterns.exterior, function()
						return nearestHallCall or thisHallCall
					end, floor_instance.FloorModel.Lantern_API)
					controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_after_door_open.interior, controller.Config.color_config.lanterns.interior, function()
						return nearestHallCall or thisHallCall
					end, controller.Car.Lantern_API)
				end
				----
				self.Velocity = 0
				self.Opened:Fire()
				self.Door:SetAttribute('state', self.State)
				controller.StatValues[self.DoorStateName] = self.State
				controller.StatValues[self.SpeedValueName] = self.Velocity
				controller.UpdateStatValues()
				--controller.elevator.API:Fire('onDoorOpened', { side = self.Side })
				--data.Opened:Fire()
				self.Alpha = 1

				for i, weld in self.EngineWelds do
					weld.C0 = weld.target_position.Value
					weld.target_position:SetAttribute('is_active', false)
				end
				for i, weld in self.FloorWelds do
					weld.C0 = weld.target_position.Value
					weld.target_position:SetAttribute('is_active', false)
				end

				self.State = 'Open'
				controller.StatValues[self.DoorStateName] = self.State
				task.spawn(controller.UpdateStatValues)

				table.insert(self.OpeningThreads, task.spawn(function()
					self.TimerStart = os.clock()
					while true do
						controller.Step:Wait()
						if self.State ~= 'Open' then return end

						if (os.clock()-self.NudgeTimerStart)/(self.DoorConfig.door_timers.nudge_timer or 30) >= 1 then
							self.Nudging = true
							controller.StatValues[self.NudgeValueName] = self.Nudging
							controller.UpdateStatValues()
							if controller.CabRegion:FindFirstChild('Nudge_Signal_Loop') then
								controller.CabRegion.Nudge_Signal_Loop:Play()
							end
						end

						if controller.StatValues.FireService.FireServiceRecall and not controller.StatValues.FireService.FireServicePhase2 and controller.StatValues.Floor ~= controller.FireRecallFloor then return self.Close(controller.StatValues.FireService.FireServiceRecall) end

						if controller.StatValues.FireService.FireServiceRecall or controller.StatValues.FireService.FireServicePhase2 then
							self.TimerStart = os.clock()
							self.NudgeTimerStart = os.clock()
							for i, v in self.OpeningThreads do
								pcall(task.cancel, v)
							end
							self.OpeningThreads = {}
							if controller.FireRecallFloor ~= controller.StatValues.Floor and not controller.StatValues.FireService.FireServicePhase2 then
								return self.Close(controller.StatValues.FireService.FireServiceRecall)
							end
							return
						end
						if (os.clock()-self.TimerStart)/data.open_time >= 1 and (not controller.StatValues.FireService.FireServiceRecall) and not self.IsObstructed then return self.Close(controller.StatValues.FireService.FireServiceRecall) end

						if (os.clock()-self.NudgeTimerStart)/(self.DoorConfig.door_timers.nudge_timer or 30) >= 1 then return self.Close(true) end

						if controller.StatValues.FireService.FireServiceRecall or controller.StatValues.FireService.FireServicePhase2 then continue end

						local result = workspace:GetPartBoundsInBox(self.BoundingBox.CFrame, self.BoundingBox.Size, overlapParams)
						self.IsObstructed = #result > 0
						if self.IsObstructed then
							self.TimerStart = os.clock()
						end
					end
				end))
				controller.API:Fire('on_door_opened', { side = self.Side })

				return true
			end

			if (previousState == 'Closed') then
				for i, stage in self.stages do
					stage.accel(i, function(dtTime)
						handleWelds(dtTime)
					end)
				end
			else
				local initialVelocity, finalVelocity = self.Velocity, 0
				local rate = .05
				local stage = self.stages[#self.stages]
				stage.accel(1, function(dtTime)
					handleWelds(dtTime)
				end)
			end

			while self.State == 'Opening' do
				local lastTick = os.clock()
				controller.Step:Wait()
				local dtTime = os.clock()-lastTick
				--task.wait(.75)
				self.LastVelocity = self.Velocity
				if (handleWelds(dtTime)) then return end
			end
		end))

	end

	function self.Close(nudge: boolean?, bypass_opening_state: boolean?, bypass_disabled_state: boolean?)
		local previousState = self.State == 'Stopped' and 'Open' or self.State
		local floor_instance = controller.FindFloor(controller.StatValues.Floor)
		if not floor_instance then return end

		if (self.Disabled and not bypass_disabled_state) or (self.State ~= 'Open' and self.State ~= 'Stopped' and (self.State ~= 'Opening' or (not bypass_opening_state))) or (self.IsObstructed and (not (self.Nudging or nudge)) and (not controller.StatValues.FireService.FireServiceRecall)) then return end

		if previousState == 'Opening' then
			self.Velocity = -self.Velocity
		end

		self.State = 'Closing'
		self.Nudging = if not self.Nudging then nudge else self.Nudging
		self.Door:SetAttribute('state', self.State)

		for i, v in self.ClosingConnections do
			if not v.Connected then continue end

			v:Disconnect()
		end
		self.ClosingConnections = {}

		if self.Nudging and controller.CabRegion:FindFirstChild('Nudge_Signal_Loop') then
			if controller.CabRegion.Nudge_Signal_Loop:IsA('AudioPlayer') then
				controller.CabRegion.Nudge_Signal_Loop.TimePosition = 0
				controller.CabRegion.Nudge_Signal_Loop.Looping = true
			else
				controller.CabRegion.Nudge_Signal_Loop.Looped = true
			end
			controller.CabRegion.Nudge_Signal_Loop:Play()
		end

		self.Closing:Fire()

		for i, v in self.OpeningThreads do
			pcall(task.cancel, v)
		end
		self.OpeningThreads = {}

		table.insert(self.ClosingThreads, task.spawn(function()
			controller.StatValues[self.DoorStateName] = self.State
			controller.StatValues[self.NudgeValueName] = self.Nudging
			controller.StatValues[self.SpeedValueName] = self.Velocity
			controller.UpdateStatValues()

			local doorConfigMain = controller.Config.doors.closing
			local doorDuration = if self.Nudging then self.DoorConfig.nudge_speed else self.DoorConfig.close_speed
			local thisDistance = (self.MasterWeld:GetAttribute('open_point').Position-self.MasterWeld:GetAttribute('closed_point').Position).Magnitude
			local doorSpeed = thisDistance/doorDuration

			table.insert(self.ClosingThreads, task.spawn(function()
				local startTime = os.clock()
				while true do
					controller.Step:Wait()
					if self.State ~= 'Closing' then return end

					if (os.clock()-self.NudgeTimerStart)/(self.DoorConfig.door_timers.nudge_timer or 30) >= 1 and (not self.Nudging) and (not controller.StatValues.FireService.FireServiceRecall and not controller.StatValues.FireService.FireServicePhase2) then
						self.Nudging = true
						controller.StatValues[self.NudgeValueName] = self.Nudging
						if self.Nudging and controller.CabRegion:FindFirstChild('Nudge_Signal_Loop') then
							if controller.CabRegion.Nudge_Signal_Loop:IsA('AudioPlayer') then
								controller.CabRegion.Nudge_Signal_Loop.TimePosition = 0
								controller.CabRegion.Nudge_Signal_Loop.Looping = true
							else
								controller.CabRegion.Nudge_Signal_Loop.Looped = true
							end
							controller.CabRegion.Nudge_Signal_Loop:Play()
						end
						return controller.UpdateStatValues()
					end

					if controller.StatValues.FireService.FireServiceRecall or controller.StatValues.FireService.FireServicePhase2 then continue end

					local result = workspace:GetPartBoundsInBox(self.BoundingBox.CFrame, self.BoundingBox.Size, overlapParams)
					self.IsObstructed = #result > 0
					if self.IsObstructed then
						return self.Open({ open_time = controller.Config.doors.door_timers.open_no_call })
					end
					if (os.clock()-startTime) > doorDuration*4 then
						return self.Open({ open_time = controller.Config.doors.door_timers.open_no_call, lantern_signal = false, bypass_nudge = true })
					end
				end
			end))
			local slowdown = false

			local stages = {}
			local lastStage
			for i, v in doorConfigMain.acceleration_stages do

				local speed, accel, delay = min(v.speed, doorSpeed), v.rate, v.delay
				local duration = getAccelerationTime(lastStage and min(lastStage.speed, doorSpeed) or 0, speed, accel)

				local stageData = {}
				function stageData.accel(i, callback: any)
					local startTime = os.clock()
					local initialVelocity = self.Velocity
					while ((os.clock()-startTime)/duration <= 1) do -- Accelerate the doors
						local lastTick = os.clock()
						controller.Step:Wait()
						local dtTime = os.clock()-lastTick
						self.LastVelocity = self.Velocity
						if (typeof(callback) == 'function') then callback(dtTime) end
						self.Velocity = lerp(initialVelocity, speed, min((os.clock()-startTime)/duration, 1))
						if (slowdown) then return end
					end
					startTime = os.clock()
					while ((os.clock()-startTime)/delay <= 1) do -- Handle delay
						local lastTick = os.clock()
						controller.Step:Wait()
						local dtTime = os.clock()-lastTick
						if (typeof(callback) == 'function') then callback(dtTime) end
					end
				end
				stages[i] = stageData
				lastStage = v

			end

			local function accelToSpeed(initialSpeed, finalSpeed, rate, delay, callback: (...any) -> any)
				local speed, accel, delay = finalSpeed, rate, delay
				local duration = getAccelerationTime(initialSpeed, speed, accel)

				local startTime = os.clock()
				local initialVelocity = self.Velocity

				while ((os.clock()-startTime)/duration <= 1) do -- Accelerate the doors
					local lastTick = os.clock()
					controller.Step:Wait()
					local dtTime = os.clock()-lastTick
					self.LastVelocity = self.Velocity
					self.Velocity = lerp(initialVelocity, speed, min((os.clock()-startTime)/duration, 1))
					if (typeof(callback) == 'function') then callback(dtTime) end
				end
				startTime = os.clock()
				while ((os.clock()-startTime)/delay <= 1) do -- Handle delay
					local lastTick = os.clock()
					controller.Step:Wait()
					local dtTime = os.clock()-lastTick
					if (typeof(callback) == 'function') then callback(dtTime) end
				end
			end

			local initialVelocity, initialDistance

			local function checkWelds(target)
				if (self.MasterWeld.target_position.Value ~= self.MasterWeld:GetAttribute(target)) then return false end
				return true
			end

			local nearestHallCall = controller.Queue.GetNearestHallCall(controller.StatValues.Floor, controller.StatValues.QueueDirection)
			local nearestCarCall = controller.Queue.GetNearestCarCall(controller.StatValues.Floor, controller.StatValues.QueueDirection)
			local nearestCallResult = nearestHallCall or nearestCarCall

			local thisOppositeHallCall = controller.Queue.FindHallCall(controller.StatValues.Floor, -controller.StatValues.QueueDirection)

			if not self.Disabled then
				table.insert(self.ClosingThreads, task.delay((previousState == 'Open' and self.DoorConfig.close_delay or 0)+doorDuration+(self.DoorConfig.direction_switch_delay or 0), function()
					if thisOppositeHallCall and (not nearestCallResult) then
						controller.StatValues.QueueDirection = 0
						controller._QueueDirectionLock = true
						controller.StatValues.DoorSafetyLock = true
						controller.UpdateStatValues()
						task.wait(1)
						local opposite_direction = controller.IndexInTable(thisOppositeHallCall.Directions, 1)
						controller._QueueDirectionLock = false
						controller.StatValues.DoorSafetyLock = false
						controller.Queue.RemoveHallCall(thisOppositeHallCall.Call, opposite_direction)
						controller.StatValues.QueueDirection = opposite_direction
						controller.API:Fire('on_call_respond', { floor = controller.StatValues.Floor, direction = controller.StatValues.QueueDirection, park = controller.StatValues.park })
						controller.UpdateStatValues()
						self.NudgeTimerStart = os.clock()
						-- Handle lanterns --
						if controller.Config.lantern_controls.activate_on_exterior_wake_call.interior.enable then
							table.insert(self.OpeningThreads, task.delay(controller.Config.lantern_controls.activate_on_exterior_wake_call.interior.delay, function()
								controller.Car.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.StatValues.QueueDirection, config = controller.Config.color_config.lanterns.interior })
							end))
						end
						if controller.Config.lantern_controls.activate_on_exterior_wake_call.exterior.enable then
							table.insert(self.OpeningThreads, task.delay(controller.Config.lantern_controls.activate_on_exterior_wake_call.exterior.delay, function()
								floor_instance.FloorModel.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.StatValues.QueueDirection, config = controller.Config.color_config.lanterns.exterior })
							end))
						end
						----
						return self.Open({ open_time = controller.Config.doors.door_timers.open_by_call, lantern_signal = true })
					end
				end))
			end

			local openSound = self.Sounds[`Floor{floor_instance.FloorNumber}OpenSound`] or self.Sounds.GlobalOpenSound
			local closeSound = self.Sounds[`Floor{floor_instance.FloorNumber}CloseSound`] or self.GlobalCloseSound
			table.insert(self.ClosingThreads, task.delay(previousState == 'Open' and self.DoorConfig.close_sound_delay or 0, function()
				openSound:Stop()
				closeSound.TimePosition = 0
				closeSound:Play()
			end))
			task.wait(previousState == 'Open' and self.DoorConfig.close_delay or 0)
			controller.API:Fire('on_door_close', { side = self.Side })
			local startTime = os.clock()
			for i, weld in self.EngineWelds do
				weld.target_position:SetAttribute('is_active', true)
			end
			for i, weld in self.FloorWelds do
				weld.target_position:SetAttribute('is_active', true)
			end

			local pausing = false
			local function handleWelds(dtTime)
				self.Alpha = clamp(self.Alpha-((self.Velocity/doorSpeed)/doorDuration)*dtTime, 0, 1)

				local currentDistanceVector = (self.MasterWeld:GetAttribute('closed_point').Position-self.MasterWeld.target_position.Value.Position)
				local currentDistanceWithOffset = ((self.MasterWeld:GetAttribute('closed_point').Position-currentDistanceVector.Unit*doorConfigMain.slowdown.final_slowdown_point)-self.MasterWeld.target_position.Value.Position)

				local currentDistance = currentDistanceVector.Magnitude
				local currentDistanceFactor = currentDistance/thisDistance
				if (currentDistanceFactor <= doorConfigMain.slowdown.slowdown_distance*(self.Velocity/doorSpeed) or slowdown) then
					if (not slowdown) then
						initialDistance = currentDistanceWithOffset
						initialVelocity = self.Velocity
						slowdown = true
					end

					currentDistanceWithOffset = ((self.MasterWeld:GetAttribute('closed_point').Position-currentDistanceVector.Unit*(doorConfigMain.slowdown.final_slowdown_point))-(self.MasterWeld.target_position.Value.Position-currentDistanceVector.Unit*max(doorConfigMain.slowdown.final_slowdown_speed*.2*(self.Velocity/initialVelocity), 0)))

					local currentSpeed = self.Velocity
					local deceleration = currentSpeed^2/(2*max(.001, currentDistanceWithOffset.Magnitude))
					if not pausing then
						local SPEED = max(0, currentSpeed-deceleration*dtTime)
						self.Velocity = max(doorConfigMain.slowdown.final_slowdown_speed, SPEED)
					end
					if pausing == false and self.Velocity <= doorConfigMain.slowdown.final_slowdown_speed and doorConfigMain.slowdown.stop_after_slowdown and doorConfigMain.slowdown.stop_after_slowdown.enable == true then
						pausing = true
						accelToSpeed(self.Velocity, 0, (doorConfigMain.slowdown.stop_after_slowdown.slowdown_rate or deceleration), doorConfigMain.slowdown.stop_after_slowdown.pause_duration, handleWelds)
						accelToSpeed(self.Velocity, doorConfigMain.slowdown.stop_after_slowdown.accelerate_to.speed, doorConfigMain.slowdown.stop_after_slowdown.accelerate_to.rate, 0, handleWelds)
					end
				end
				for i, weld in self.EngineWelds do
					weld.target_position.Value = weld:GetAttribute('closed_point'):Lerp(weld:GetAttribute('open_point'), self.Alpha)
				end
				for i, weld in self.FloorWelds do
					local closed_point = weld:GetAttribute('closed_point')
					local open_point = weld:GetAttribute('open_point')
					local offsetVector = (closed_point.Position+(open_point.Position-closed_point.Position)*self.Alpha)-(open_point.Position-closed_point.Position).Unit*doorConfigMain.door_clutch_offset
					weld.target_position.Value = weld.target_position.Value:Lerp(cf_new(
						clamp(offsetVector.X, closed_point.Position.X <= open_point.Position.X and closed_point.Position.X or open_point.Position.X, closed_point.Position.X >= open_point.Position.X and closed_point.Position.X or open_point.Position.X),
						clamp(offsetVector.Y, closed_point.Position.Y <= open_point.Position.Y and closed_point.Position.Y or open_point.Position.Y, closed_point.Position.Y >= open_point.Position.Y and closed_point.Position.Y or open_point.Position.Y),
						clamp(offsetVector.Z, closed_point.Position.Z <= open_point.Position.Z and closed_point.Position.Z or open_point.Position.Z, closed_point.Position.Z >= open_point.Position.Z and closed_point.Position.Z or open_point.Position.Z)
						)*CFrame.fromOrientation(weld:GetAttribute('closed_point'):ToOrientation()), clamp( min(dtTime/0.02, 1)--[[+(doorConfigMain.outer_door_spring_effect.enable == true and doorConfigMain.outer_door_spring_effect.threshold or 0)*(math.cos((os.clock()-startTime)*1*math.pi^2)*self.VelocityDiff*6)]], 0, 1 ))
				end

				self.VelocityDiff = lerp(self.VelocityDiff, ((self.Velocity-self.LastVelocity)/(dtTime/0.05)), min(dtTime/0.02, 1))
				controller.StatValues[self.SpeedValueName] = self.Velocity
				controller.UpdateStatValues()

				-- 11/04: Change original fully closed point code to check for safety tolerance; allows for pre-start
				local Tolerance = math.max(.05, typeof(controller.Config.doors.pre_start_tolerance) == 'number' and controller.Config.doors.pre_start_tolerance or 0)
				local IsSafeToMove: boolean = controller.CheckDoorTolerance('all', { Tolerance, Tolerance })

				if IsSafeToMove and not self.IsDeparting and not self.Disabled then
					self.ClosingThreads[#self.ClosingThreads+1] = task.spawn(function()
						self.IsDeparting = true
						local nearestHallCall = controller.Queue.GetNearestHallCall(controller.StatValues.Floor, controller.StatValues.QueueDirection)
						local nearestCarCall = controller.Queue.GetNearestCarCall(controller.StatValues.Floor, controller.StatValues.QueueDirection)
						local nearestCallResult = nearestCarCall or nearestHallCall

						local thisOppositeHallCall = controller.Queue.FindHallCall(controller.StatValues.Floor, -controller.StatValues.QueueDirection)

						if (not nearestCallResult) and (not thisOppositeHallCall) then
							-- Opposite direction check
							nearestHallCall = controller.Queue.GetNearestHallCall(controller.StatValues.Floor, -controller.StatValues.QueueDirection)
							nearestCarCall = controller.Queue.GetNearestCarCall(controller.StatValues.Floor, -controller.StatValues.QueueDirection)
							nearestCallResult = nearestCarCall or nearestHallCall

							-- Still no calls? Check with no direction
							if not nearestCallResult then
								nearestHallCall = controller.Queue.GetNearestHallCall(controller.StatValues.Floor, 0)
								nearestCarCall = controller.Queue.GetNearestCarCall(controller.StatValues.Floor, 0)
								nearestCallResult = nearestCarCall or nearestHallCall
							end

							if nearestCallResult then
								local callDirection = nearestCallResult.Call > controller.StatValues.Floor and 1 or nearestCallResult.Call < controller.StatValues.Floor and -1 or 0

								local directionSwitch = false
								if callDirection == -controller.StatValues.QueueDirection then
									controller.StatValues.QueueDirection = 0
									controller._QueueDirectionLock = true
									controller.StatValues.DoorSafetyLock = true
									controller.UpdateStatValues()
									task.wait(1)
									controller._QueueDirectionLock = false
									controller.StatValues.DoorSafetyLock = false
									directionSwitch = true
								end
								if nearestCallResult then
									controller.MovementInstance.GoToFloor(nearestCallResult.Call, false, directionSwitch, true)
									return true
								end
							elseif not thisOppositeHallCall then
								controller.StatValues.QueueDirection = 0
								controller._QueueDirectionLock = false
								controller.UpdateStatValues()
							end
						elseif nearestCallResult then
							return controller.MovementInstance.GoToFloor(nearestCallResult.Call, false, false, true)
						end

						-- 13/01: Add & fix parking feature re-instatement
						local parkFloor = typeof(controller.Config.movement.parking_config) == 'table' and typeof(controller.Config.movement.parking_config.park_floor) == 'number' and controller.Config.movement.parking_config.park_floor or 1
						if parkFloor ~= controller.StatValues.Floor or (typeof(controller.Config.movement.parking_config) == 'table' and controller.Config.movement.parking_config.enable ~= true) then
							controller.MovementInstance.MovementThreads['park_timer'] = task.delay(typeof(controller.Config.movement.parking_config) == 'table' and typeof(controller.Config.movement.parking_config.park_timer) == 'number' and controller.Config.movement.parking_config.park_timer or 60, controller.MovementInstance.GoToFloor, parkFloor, true, true)
						end
					end)
				end

				if not checkWelds('closed_point') then return end -- Elevator is not safe to move as one or more set of doors are not within their safety zone

				task.wait(dtTime/0.1)

				self.Nudging = false
				self.Door:SetAttribute('state', self.State)
				self.Velocity = 0
				controller.StatValues[self.NudgeValueName] = self.Nudging
				controller.StatValues[self.SpeedValueName] = self.Velocity
				controller.UpdateStatValues()
				--controller.elevator.API:Fire('onDoorOpened', { side = self.Side })
				--data.Opened:Fire()
				self.Alpha = 0
				controller.API:Fire('on_door_closed', { side = self.Side })

				self.Closed:Fire()

				table.clear(self.ClosingThreads)
				for i, weld in self.EngineWelds do
					weld.C0 = weld.target_position.Value
					weld.target_position:SetAttribute('is_active', false)
				end
				for i, weld in self.FloorWelds do
					weld.C0 = weld.target_position.Value
					weld.target_position:SetAttribute('is_active', false)
				end

				self.State = 'Closed'
				controller.StatValues[self.DoorStateName] = self.State
				controller.UpdateStatValues()

				-- Check all doors and only stop the nudge signal loop if no doors are nudging --
				for i, v in controller.door_data do
					if v.Nudging then continue end

					if controller.CabRegion:FindFirstChild('Nudge_Signal_Loop') then
						if controller.CabRegion.Nudge_Signal_Loop:IsA('AudioPlayer') then
							self.ClosingConnections[#self.ClosingConnections+1] = controller.CabRegion.Nudge_Signal_Loop.Looped:Once(function()
								--if self.State ~= 'Closed' then return end

								controller.CabRegion.Nudge_Signal_Loop:Stop()
								controller.CabRegion.Nudge_Signal_Loop.Looping = false
							end)
						else
							self.ClosingConnections[#self.ClosingConnections+1] = controller.CabRegion.Nudge_Signal_Loop.DidLoop:Once(function()
								--if self.State ~= 'Closed' then return end

								controller.CabRegion.Nudge_Signal_Loop:Stop()
								controller.CabRegion.Nudge_Signal_Loop.Looped = false
							end)
						end
					end
				end

				if not controller.CheckAllDoors('closed_point') then return end -- Elevator is not safe to move as one or more set of doors are not within their safety zone

				return true
			end

			if (previousState == 'Open') then
				for i, stage in stages do
					stage.accel(i, function(dtTime)
						handleWelds(dtTime)
					end)
				end
			else
				local initialVelocity, finalVelocity = self.Velocity, 0
				local rate = .05
				local stage = stages[#stages]
				stage.accel(1, function(dtTime)
					handleWelds(dtTime)
				end)
			end

			while self.State == 'Closing' do
				local lastTick = os.clock()
				controller.Step:Wait()
				local dtTime = os.clock()-lastTick
				self.LastVelocity = self.Velocity
				if (handleWelds(dtTime)) then return end
			end
		end))

	end

	function self.Stop(disable: boolean?) -- 04/10/2025- Add new door stop function

		-- Update door state
		self.State = 'Stopped'
		self.Nudging = false
		self.Velocity = 0

		self.Disabled = if typeof(disable) == 'boolean' then disable else self.Disabled

		controller.StatValues[self.DoorStateName] = self.State
		controller.StatValues[self.NudgeValueName] = self.Nudging
		controller.StatValues[self.SpeedValueName] = self.Velocity

		-- Cancel all threads
		for i, v in self.OpeningThreads do
			pcall(task.cancel, v)
		end
		for i, v in self.ClosingThreads do
			pcall(task.cancel, v)
		end

		-- Stop all sounds
		for i, v in self.Sounds do
			v:Stop()
		end

		self.OpeningThreads = {}
		self.ClosingThreads = {}

		task.spawn(controller.UpdateStatValues)

	end

	function self.Disable(value: boolean) -- 04/10/2025- Add Disable feature to the doors
		if typeof(value) ~= 'boolean' then return error(`DoorStop: Must supply a valid Boolean value, instead got type '{typeof(value)}' ({tostring(value)})`) end

		self.Disabled = value
	end

	self.SetupDoorSounds()
	self.SetupDoorWelds()

	return self
end

return doorClass