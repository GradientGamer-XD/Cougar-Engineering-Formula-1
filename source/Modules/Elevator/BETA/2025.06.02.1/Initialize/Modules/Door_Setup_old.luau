local doorClass = {}
doorClass.className = 'doorClass'

doorClass.__index = function(self, key)
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

function doorClass.new(source, door, controller)

	local doorSide = string.split(door.Name, 'Doors')[2] and string.split(door.Name, 'Doors')[1]
	if (not doorSide) then return end
	if string.match(doorSide, '_') then
		doorSide = string.split(doorSide, '_')[2] and string.split(doorSide, '_')[1]
	end

	local data = setmetatable({}, doorClass)
	data.state = 'Closed'
	data.engine_welds = {}
	data.floor_welds = {}
	data.side = doorSide

	door:SetAttribute('state', data.state)

	data.opening_threads = {}
	data.closing_threads = {}

	data.alpha = 0
	data.velocity = 0
	data.velocityDiff = 0
	data.lastVelocity = data.velocity

	data.timer_start = 0
	data.nudge_timer_start = 0
	data.is_obstructed = false
	data.nudging = false

	-- Door state values --
	local ds_name = `{string.lower(doorSide)}_door_state`
	controller.StatValues[ds_name] = data.state
	data.door_state_value = Instance.new('StringValue')
	data.door_state_value.Name = `{doorSide}_Door_State`
	data.door_state_value.Value = data.state
	data.door_state_value.Parent = controller.ValuesFolder
	controller.StatValueInstances[data.door_state_value] = {
		instance = data.door_state_value,
		update = function()
			data.door_state_value.Value = controller.StatValues[ds_name]
		end,
	}
	----

	-- Nudge value --
	local nudge_value = `{string.lower(doorSide)}_door_nudge`
	controller.StatValues[nudge_value] = data.nudging
	data.nudge_value = Instance.new('BoolValue')
	data.nudge_value.Name = `{doorSide}_Door_Nudge`
	data.nudge_value.Value = data.nudging
	data.nudge_value.Parent = controller.ValuesFolder
	controller.StatValueInstances[data.nudge_value] = {
		instance = data.nudge_value,
		update = function()
			data.nudge_value.Value = controller.StatValues[nudge_value]
		end,
	}
	----

	-- Speed value --
	local speed_value = `{string.lower(doorSide)}_door_speed`
	controller.StatValues[speed_value] = data.velocity
	data.speed_value = Instance.new('NumberValue')
	data.speed_value.Name = `{doorSide}_Door_Speed`
	data.speed_value.Value = data.velocity
	data.speed_value.Parent = controller.ValuesFolder
	controller.StatValueInstances[data.speed_value] = {
		instance = data.speed_value,
		update = function()
			data.speed_value.Value = controller.StatValues[speed_value]
		end,
	}
	----

	data.doors_folder = Instance.new('Folder')
	data.doors_folder.Name = `{doorSide}_Doors_Data`
	data.doors_folder.Parent = controller.ElevatorFolder
	data.engine_welds_folder = Instance.new('Folder')
	data.engine_welds_folder.Name = 'Engine_Welds'
	data.engine_welds_folder.Parent = data.doors_folder

	data.bounding_box = Instance.new('Part')
	data.bounding_box.Name = 'Door_Bounds'
	data.bounding_box.CFrame, data.bounding_box.Size = door:GetBoundingBox()
	data.bounding_box.CanCollide = false
	data.bounding_box.Transparency = 1
	data.bounding_box.CanQuery = false
	controller.WeldingModule.WeldParts(data.bounding_box, controller.Platform, true)
	data.bounding_box.Parent = door

	data.open_sound = controller.AudioModule.AddSoundFromConfig(data.bounding_box, 'Open_Sound', {
		id = controller.Config.sounds.door_sounds.open_sound.id,
		volume = controller.Config.sounds.door_sounds.open_sound.volume,
		pitch = controller.Config.sounds.door_sounds.open_sound.pitch,
		looped = false,
		minDistance = controller.Config.sounds.door_sounds.open_sound.roll_off.min,
		maxDistance = controller.Config.sounds.door_sounds.open_sound.roll_off.max,
		rollOffMode = controller.Config.sounds.door_sounds.open_sound.roll_off.mode
	})
	data.close_sound = controller.AudioModule.AddSoundFromConfig(data.bounding_box, 'Close_Sound', {
		id = controller.Config.sounds.door_sounds.close_sound.id,
		volume = controller.Config.sounds.door_sounds.close_sound.volume,
		pitch = controller.Config.sounds.door_sounds.close_sound.pitch,
		looped = false,
		minDistance = controller.Config.sounds.door_sounds.close_sound.roll_off.min,
		maxDistance = controller.Config.sounds.door_sounds.close_sound.roll_off.max,
		rollOffMode = controller.Config.sounds.door_sounds.close_sound.roll_off.mode
	})

	if typeof(controller.Config.sounds.door_sounds.Floors) == 'table' then
		for i, v in controller.Config.sounds.door_sounds.Floors do
			local str = `Floor_{i}_%s`
			local entry_value = `floor_{i}_%s_sound`
			local sound_name = `Floor_{i}_%s_Sound`
			data[string.format(entry_value, 'open')] = controller.AudioModule.AddSoundFromConfig(data.bounding_box, string.format(sound_name, 'Open'), {
				id = v.open_sound.id,
				volume = v.open_sound.volume,
				pitch = v.open_sound.pitch,
				looped = false,
				minDistance = v.open_sound.roll_off.min,
				maxDistance = v.open_sound.roll_off.max,
				rollOffMode = v.open_sound.roll_off.mode
			})
			data[string.format(entry_value, 'close')] = controller.AudioModule.AddSoundFromConfig(data.bounding_box, string.format(sound_name, 'Close'), {
				id = v.close_sound.id,
				volume = v.close_sound.volume,
				pitch = v.close_sound.pitch,
				looped = false,
				minDistance = v.close_sound.roll_off.min,
				maxDistance = v.close_sound.roll_off.max,
				rollOffMode = v.close_sound.roll_off.mode
			})
		end
	end

	local lastSafetyCheck = true
	for i, v in door:GetChildren() do
		local scaler, open = v:FindFirstChild('Scaler'), v:FindFirstChild('Scaler') and v.Scaler:FindFirstChild('Open')
		if (not scaler) or (not open) then continue end

		controller.WeldingModule.WeldPartsInModel(v, scaler, {open})
		local engineWeld = controller.WeldingModule.WeldParts(scaler, open, true, false)
		engineWeld.Name = 'Door_Engine_Weld'
		engineWeld:SetAttribute('open_point', engineWeld.C1)
		engineWeld:SetAttribute('closed_point', engineWeld.C0)

		-- Handle door safety --
		engineWeld:GetPropertyChangedSignal('C0'):Connect(function()
			task.wait()
			local safetyMet = true
			for i, v in data.engine_welds do
				if (v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude >= .06 and data.state == 'Closed' then safetyMet = false break end
			end
			for i, v in data.floor_door_welds do
				if (v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude >= .035 and data.state == 'Closed' then safetyMet = false break end
			end
			if lastSafetyCheck == safetyMet then return end
			lastSafetyCheck = safetyMet
			controller.StatValues.OutOfService = not safetyMet
			task.spawn(controller.UpdateStatValues)
			if not safetyMet then
				print('Safety braking', data.side)
				controller.MovementInstance.safety_brake()
			else
				controller.StatValues.DoorSafetyLock = false
				controller.MovementInstance.resumeFloorCall()
			end
		end)
		----

		local val = Instance.new('ObjectValue')
		val.Name = 'Engine_Weld'
		val.Value = engineWeld
		val.Parent = data.engine_welds_folder

		table.insert(data.engine_welds, engineWeld)

		local value = Instance.new('CFrameValue')
		value.Name = 'target_position'
		value.Value = engineWeld.C0
		value.Parent = engineWeld

	end

	local dist = -math.huge
	for i, v in data.engine_welds do
		local d = (v:GetAttribute('open_point').Position-v:GetAttribute('closed_point').Position).Magnitude
		if d >= dist then
			dist = d
			data.master_weld = v
		end
	end

	-- Cache all functions here --
	local abs, rad, deg, min, max, clamp, cf_new, cf_angles = math.abs, math.rad, math.deg, math.min, math.max, math.clamp, CFrame.new, CFrame.Angles
	local runService = game:GetService('RunService')

	local function lerp(a, b, t)
		return a+(b-a)*t
	end
	local function getAccelerationTime(initialSpeed: number, finalSpeed: number, rate: number)
		return math.abs(finalSpeed-initialSpeed)/math.deg(rate)
	end

	local doorConfig = controller.Config.doors

	local step = runService.PreSimulation

	function data.Open(open_time: number, lantern_signal: boolean?, bypass_nudge: boolean?)

		local previousState = data.state
		if (previousState ~= 'Closed' and previousState ~= 'Closing') or (data.nudging and bypass_nudge ~= true) or controller.StatValues.DoorSafetyLock or controller.StatValues.OutOfService then return end

		local floor_instance = controller.FindFloor(controller.StatValues.Floor)
		if not floor_instance then return end

		local doorsModel = floor_instance.FloorModel:FindFirstChild(`{data.side}_Doors`)
		if (not doorsModel) or door:GetAttribute('is_door_key') or doorsModel:GetAttribute('is_door_key') then return end

		for i, v in data.closing_threads do
			pcall(task.cancel, v)
		end
		data.closing_threads = {}
		table.insert(data.opening_threads, task.spawn(function()
			if previousState == 'Closed' then
				data.floor_welds = {}
			end
			data.state = 'Opening'
			door:SetAttribute('state', data.state)
			controller.StatValues[ds_name] = data.state
			controller.UpdateStatValues()

			if controller.MovementInstance.MovementThreads['park_timer'] then
				pcall(task.cancel, controller.MovementInstance.MovementThreads['park_timer'])
				controller.MovementInstance.MovementThreads['park_timer'] = nil
			end

			local doorConfigMain = controller.Config.doors.opening
			local doorDuration = doorConfig.open_speed
			local thisDistance = (data.master_weld:GetAttribute('open_point').Position-data.master_weld:GetAttribute('closed_point').Position).Magnitude
			local doorSpeed = thisDistance/doorDuration

			local slowdown = false
			local signaling = false

			if previousState == 'Closing' then
				data.velocity = -data.velocity
			end

			local stages = {}
			local lastStage
			for i, v in doorConfig.opening.acceleration_stages do

				local speed, accel, delay = min(v.speed, doorSpeed), v.rate, v.delay
				local duration = getAccelerationTime(lastStage and min(lastStage.speed, doorSpeed) or 0, speed, accel)

				local stageData = {}
				function stageData.accel(i, callback: any)
					local startTime = os.clock()
					local initialVelocity = data.velocity
					while ((os.clock()-startTime)/duration <= 1) do -- Accelerate the doors
						local lastTick = os.clock()
						controller.Step:Wait()
						local dtTime = os.clock()-lastTick
						data.lastVelocity = data.velocity
						if (typeof(callback) == 'function') then callback(dtTime) end
						data.velocity = lerp(initialVelocity, speed, min((os.clock()-startTime)/duration, 1))
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

			local initialVelocity, initialDistance

			local function checkWelds(target)
				if (data.master_weld.target_position.Value ~= data.master_weld:GetAttribute(target)) then return false end
				return true
			end

			local open_sound = data[`floor_{floor_instance.FloorNumber}_open_sound`] or data.open_sound
			local close_sound = data[`floor_{floor_instance.FloorNumber}_close_sound`] or data.close_sound
			table.insert(data.opening_threads, task.delay(previousState == 'Closed' and doorConfig.open_sound_delay or 0, function()
				close_sound:Stop()
				open_sound:Play()
			end))

			task.wait(previousState == 'Closed' and doorConfig.open_delay or 0)
			controller.API:Fire('on_door_open', { side = data.side })
			local startTime = os.clock()
			for i, weld in data.engine_welds do
				weld.target_position:SetAttribute('is_active', true)
			end
			for i, weld in doorsModel:GetDescendants() do
				if weld.Name ~= 'Door_Engine_Weld' then continue end
				weld.target_position:SetAttribute('is_active', true)
				table.insert(data.floor_welds, weld)
			end

			local function handleWelds(dtTime)

				local currentDistanceVector = (data.master_weld:GetAttribute('open_point').Position-data.master_weld.target_position.Value.Position)
				local currentDistanceWithOffset = ((data.master_weld:GetAttribute('open_point').Position-currentDistanceVector.Unit*doorConfigMain.slowdown.final_slowdown_point)-data.master_weld.target_position.Value.Position)

				local currentDistance = currentDistanceVector.Magnitude
				local currentDistanceFactor = currentDistance/thisDistance
				if (currentDistanceFactor <= doorConfigMain.slowdown.slowdown_distance*(data.velocity/doorSpeed) or slowdown) then
					if (not slowdown) then
						initialDistance = currentDistanceWithOffset
						initialVelocity = data.velocity
						slowdown = true
					end
					local currentSpeed = data.velocity
					local deceleration = currentSpeed^2/(2*max(.001, currentDistanceWithOffset.Magnitude))
					local SPEED = max(0, currentSpeed-deceleration*dtTime)
					data.velocity = max(doorConfigMain.slowdown.final_slowdown_speed, SPEED)
				end

				for i, weld in data.engine_welds do
					weld.target_position.Value = weld:GetAttribute('closed_point'):Lerp(weld:GetAttribute('open_point'), data.alpha)
				end
				for i, weld in data.floor_welds do
					local closed_point = weld:GetAttribute('closed_point')
					local open_point = weld:GetAttribute('open_point')
					local offsetVector = (closed_point.Position+(open_point.Position-closed_point.Position)*data.alpha)-(open_point.Position-closed_point.Position).Unit*doorConfigMain.door_clutch_offset
					weld.target_position.Value = weld.target_position.Value:Lerp(cf_new(
						clamp(offsetVector.X, closed_point.Position.X <= open_point.Position.X and closed_point.Position.X or open_point.Position.X, closed_point.Position.X >= open_point.Position.X and closed_point.Position.X or open_point.Position.X),
						clamp(offsetVector.Y, closed_point.Position.Y <= open_point.Position.Y and closed_point.Position.Y or open_point.Position.Y, closed_point.Position.Y >= open_point.Position.Y and closed_point.Position.Y or open_point.Position.Y),
						clamp(offsetVector.Z, closed_point.Position.Z <= open_point.Position.Z and closed_point.Position.Z or open_point.Position.Z, closed_point.Position.Z >= open_point.Position.Z and closed_point.Position.Z or open_point.Position.Z)
						)*CFrame.fromOrientation(weld:GetAttribute('closed_point'):ToOrientation()), clamp( min(dtTime/0.02, 1)+(doorConfigMain.outer_door_spring_effect.enable == true and doorConfigMain.outer_door_spring_effect.threshold or 0)*(math.cos((os.clock()-startTime)*1*math.pi^2)*data.velocityDiff*6), 0, 1 ))
				end
				data.alpha = clamp(data.alpha+((data.velocity/doorSpeed)/doorDuration)*dtTime, 0, 1)

				data.velocityDiff = lerp(data.velocityDiff, ((data.velocity-data.lastVelocity)/(dtTime/0.05)), min(dtTime/0.02, 1))
				controller.StatValues[speed_value] = data.velocity
				controller.UpdateStatValues()

				if (not checkWelds('open_point')) then return false end
				task.wait(dtTime/0.1)
				-- Lantern signal --
				if lantern_signal == true and signaling == false then
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
				data.velocity = 0
				door:SetAttribute('state', data.state)
				controller.StatValues[ds_name] = data.state
				controller.StatValues[speed_value] = data.velocity
				controller.UpdateStatValues()
				--controller.elevator.API:Fire('onDoorOpened', { side = data.side })
				--data.Opened:Fire()
				data.alpha = 1

				for i, weld in data.engine_welds do
					weld.C0 = weld.target_position.Value
					weld.target_position:SetAttribute('is_active', false)
				end
				for i, weld in data.floor_welds do
					weld.C0 = weld.target_position.Value
					weld.target_position:SetAttribute('is_active', false)
				end

				data.state = 'Open'
				controller.StatValues[ds_name] = data.state
				task.spawn(controller.UpdateStatValues)

				table.insert(data.opening_threads, task.spawn(function()
					data.timer_start = os.clock()
					if previousState == 'Closed' then
						data.nudge_timer_start = os.clock()
					end
					while true do
						controller.Step:Wait()
						if data.state ~= 'Open' then return end
						if controller.StatValues.FireService.Recall == true and controller.StatValues.phase_2 == false and controller.StatValues.Floor ~= controller.fire_recall_floor then return data.close(controller.StatValues.FireService.Recall) end
						if controller.StatValues.FireService.Recall then
							data.timer_start = os.clock()
							data.nudge_timer_start = os.clock()
							for i, v in data.opening_threads do
								pcall(task.cancel, v)
							end
							data.opening_threads = {}
							if controller.fire_recall_floor ~= controller.StatValues.Floor and not controller.StatValues.phase_2 then
								return data.close(controller.StatValues.FireService.Recall)
							end
							return
						end
						if (os.clock()-data.timer_start)/open_time >= 1 and (not controller.StatValues.FireService.Recall) and data.is_obstructed == false then return data.close(controller.StatValues.FireService.Recall) end
						if (os.clock()-data.nudge_timer_start)/(doorConfig.door_timers.nudge_timer or 30) >= 1 then return data.close(true) end
						local result = workspace:GetPartBoundsInBox(data.bounding_box.CFrame, data.bounding_box.Size, overlapParams)
						data.is_obstructed = #result > 0
						if data.is_obstructed then
							data.timer_start = os.clock()
						end
					end
				end))
				controller.API:Fire('on_door_opened', { side = data.side })

				return true
			end

			if (previousState == 'Closed') then
				for i, stage in stages do
					stage.accel(i, function(dtTime)
						handleWelds(dtTime)
					end)
				end
			else
				local initialVelocity, finalVelocity = data.velocity, 0
				local rate = .05
				local stage = stages[#stages]
				stage.accel(1, function(dtTime)
					handleWelds(dtTime)
				end)
			end

			while data.state == 'Opening' do
				local lastTick = os.clock()
				controller.Step:Wait()
				local dtTime = os.clock()-lastTick
				--task.wait(.75)
				data.lastVelocity = data.velocity
				if (handleWelds(dtTime)) then return end
			end
		end))

	end

	function data.close(nudge: boolean?, bypass_opening_state: boolean?)

		local previousState = data.state

		local floor_instance = controller.FindFloor(controller.StatValues.Floor)
		if not floor_instance then return end

		if (data.state ~= 'Open' and (data.state ~= 'Opening' or (not bypass_opening_state))) or (data.is_obstructed and (not (data.nudging or nudge)) and (not controller.StatValues.FireService.Recall)) then return end

		if previousState == 'Opening' then
			data.velocity = -data.velocity
		end

		data.state = 'Closing'
		data.nudging = nudge
		door:SetAttribute('state', data.state)

		for i, v in data.opening_threads do
			pcall(task.cancel, v)
		end
		data.opening_threads = {}

		table.insert(data.closing_threads, task.spawn(function()
			controller.StatValues[ds_name] = data.state
			controller.StatValues[nudge_value] = data.nudging
			controller.StatValues[speed_value] = data.velocity
			controller.UpdateStatValues()


			local doorConfigMain = controller.Config.doors.closing
			local doorDuration = if data.nudging then doorConfig.nudge_speed else doorConfig.close_speed
			local thisDistance = (data.master_weld:GetAttribute('open_point').Position-data.master_weld:GetAttribute('closed_point').Position).Magnitude
			local doorSpeed = thisDistance/doorDuration

			table.insert(data.closing_threads, task.spawn(function()
				local startTime = os.clock()
				while true do
					if data.state ~= 'Closing' then return end
					if (os.clock()-data.nudge_timer_start)/(doorConfig.door_timers.nudge_timer or 30) >= 1 and (not data.nudging) and (not controller.StatValues.FireService.Recall) then
						data.nudging = true
						controller.StatValues[nudge_value] = data.nudging
						return controller.UpdateStatValues()
					end
					local result = workspace:GetPartBoundsInBox(data.bounding_box.CFrame, data.bounding_box.Size, overlapParams)
					data.is_obstructed = #result > 0
					if data.is_obstructed then
						return data.Open(controller.Config.doors.door_timers.open_no_call)
					end
					if (os.clock()-startTime) > doorDuration*4 then
						return data.Open(controller.Config.doors.door_timers.open_no_call, false, true)
					end
					controller.Step:Wait()
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
					local initialVelocity = data.velocity
					while ((os.clock()-startTime)/duration <= 1) do -- Accelerate the doors
						local lastTick = os.clock()
						controller.Step:Wait()
						local dtTime = os.clock()-lastTick
						data.lastVelocity = data.velocity
						if (typeof(callback) == 'function') then callback(dtTime) end
						data.velocity = lerp(initialVelocity, speed, min((os.clock()-startTime)/duration, 1))
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
				local speed, accel, delay = min(finalSpeed, initialSpeed), rate, delay
				local duration = getAccelerationTime(math.min(.0001, initialSpeed), math.min(.0001, speed), accel)

				local startTime = os.clock()
				local initialVelocity = data.velocity

				while ((os.clock()-startTime)/duration <= 1) do -- Accelerate the doors
					local lastTick = os.clock()
					controller.Step:Wait()
					local dtTime = os.clock()-lastTick
					data.lastVelocity = data.velocity
					data.velocity = lerp(initialVelocity, speed, min((os.clock()-startTime)/duration, 1))
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
				if (data.master_weld.target_position.Value ~= data.master_weld:GetAttribute(target)) then return false end
				return true
			end

			local nearestHallCall = controller.Queue.GetNearestHallCall(controller.StatValues.Floor, controller.StatValues.QueueDirection)
			local nearestCarCall = controller.Queue.GetNearestCarCall(controller.StatValues.Floor, controller.StatValues.QueueDirection)
			local nearestCallResult = nearestCarCall or nearestHallCall

			local thisOppositeHallCall = controller.Queue.FindHallCall(controller.StatValues.Floor, -controller.StatValues.QueueDirection)

			table.insert(data.closing_threads, task.delay((previousState == 'Open' and doorConfig.close_delay or 0)+doorDuration+(doorConfig.direction_switch_delay or 0), function()
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
					controller.UpdateStatValues()
					data.nudge_timer_start = os.clock()
					-- Handle lanterns --
					if controller.Config.lantern_controls.activate_on_exterior_wake_call.interior.enable then
						table.insert(data.opening_threads, task.delay(controller.Config.lantern_controls.activate_on_exterior_wake_call.interior.delay, function()
							controller.Car.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.StatValues.QueueDirection, config = controller.Config.color_config.lanterns.interior })
						end))
					end
					if controller.Config.lantern_controls.activate_on_exterior_wake_call.exterior.enable then
						table.insert(data.opening_threads, task.delay(controller.Config.lantern_controls.activate_on_exterior_wake_call.exterior.delay, function()
							floor_instance.FloorModel.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.StatValues.QueueDirection, config = controller.Config.color_config.lanterns.exterior })
						end))
					end
					----
					return data.Open(controller.Config.doors.door_timers.open_by_call, true)
				end
			end))

			local open_sound = data[`floor_{floor_instance.FloorNumber}_open_sound`] or data.open_sound
			local close_sound = data[`floor_{floor_instance.FloorNumber}_close_sound`] or data.close_sound
			table.insert(data.closing_threads, task.delay(previousState == 'Open' and doorConfig.close_sound_delay or 0, function()
				open_sound:Stop()
				close_sound:Play()
			end))
			task.wait(previousState == 'Open' and doorConfig.close_delay or 0)
			controller.API:Fire('on_door_close', { side = data.side })
			local startTime = os.clock()
			for i, weld in data.engine_welds do
				weld.target_position:SetAttribute('is_active', true)
			end
			for i, weld in data.floor_welds do
				weld.target_position:SetAttribute('is_active', true)
			end

			local pausing = false
			local function handleWelds(dtTime)
				data.alpha = clamp(data.alpha-((data.velocity/doorSpeed)/doorDuration)*dtTime, 0, 1)

				local currentDistanceVector = (data.master_weld:GetAttribute('closed_point').Position-data.master_weld.target_position.Value.Position)
				local currentDistanceWithOffset = ((data.master_weld:GetAttribute('closed_point').Position-currentDistanceVector.Unit*doorConfigMain.slowdown.final_slowdown_point)-data.master_weld.target_position.Value.Position)

				local currentDistance = currentDistanceVector.Magnitude
				local currentDistanceFactor = currentDistance/thisDistance
				if (currentDistanceFactor <= doorConfigMain.slowdown.slowdown_distance*(data.velocity/doorSpeed) or slowdown) then
					if (not slowdown) then
						initialDistance = currentDistanceWithOffset
						initialVelocity = data.velocity
						slowdown = true
					end
					local currentSpeed = data.velocity
					local deceleration = currentSpeed^2/(2*max(.001, currentDistanceWithOffset.Magnitude))
					local SPEED = max(0, currentSpeed-deceleration*dtTime)
					data.velocity = max(doorConfigMain.slowdown.final_slowdown_speed, SPEED)
					if pausing == false and data.velocity <= doorConfigMain.slowdown.final_slowdown_speed and doorConfigMain.slowdown.stop_after_slowdown and doorConfigMain.slowdown.stop_after_slowdown.enable == true then
						pausing = true
						accelToSpeed(data.velocity, 0, deceleration, doorConfigMain.slowdown.stop_after_slowdown.pause_duration)
						accelToSpeed(data.velocity, doorConfigMain.slowdown.stop_after_slowdown.accelerate_to.speed, doorConfigMain.slowdown.stop_after_slowdown.accelerate_to.rate, 0)
					end
				end
				for i, weld in data.engine_welds do
					weld.target_position.Value = weld:GetAttribute('closed_point'):Lerp(weld:GetAttribute('open_point'), data.alpha)
				end
				for i, weld in data.floor_welds do
					local closed_point = weld:GetAttribute('closed_point')
					local open_point = weld:GetAttribute('open_point')
					local offsetVector = (closed_point.Position+(open_point.Position-closed_point.Position)*data.alpha)-(open_point.Position-closed_point.Position).Unit*doorConfigMain.door_clutch_offset
					weld.target_position.Value = weld.target_position.Value:Lerp(cf_new(
						clamp(offsetVector.X, closed_point.Position.X <= open_point.Position.X and closed_point.Position.X or open_point.Position.X, closed_point.Position.X >= open_point.Position.X and closed_point.Position.X or open_point.Position.X),
						clamp(offsetVector.Y, closed_point.Position.Y <= open_point.Position.Y and closed_point.Position.Y or open_point.Position.Y, closed_point.Position.Y >= open_point.Position.Y and closed_point.Position.Y or open_point.Position.Y),
						clamp(offsetVector.Z, closed_point.Position.Z <= open_point.Position.Z and closed_point.Position.Z or open_point.Position.Z, closed_point.Position.Z >= open_point.Position.Z and closed_point.Position.Z or open_point.Position.Z)
						)*CFrame.fromOrientation(weld:GetAttribute('closed_point'):ToOrientation()), clamp( min(dtTime/0.02, 1)+(doorConfigMain.outer_door_spring_effect.enable == true and doorConfigMain.outer_door_spring_effect.threshold or 0)*(math.cos((os.clock()-startTime)*1*math.pi^2)*data.velocityDiff*6), 0, 1 ))
				end

				data.velocityDiff = lerp(data.velocityDiff, ((data.velocity-data.lastVelocity)/(dtTime/0.05)), min(dtTime/0.02, 1))
				controller.StatValues[speed_value] = data.velocity
				controller.UpdateStatValues()

				if (not checkWelds('closed_point')) then return false end
				task.wait(dtTime/0.1)

				data.nudging = false
				door:SetAttribute('state', data.state)
				data.velocity = 0
				controller.StatValues[nudge_value] = data.nudging
				controller.StatValues[speed_value] = data.velocity
				controller.UpdateStatValues()
				--controller.elevator.API:Fire('onDoorOpened', { side = data.side })
				--data.Opened:Fire()
				data.alpha = 0
				controller.API:Fire('on_door_closed', { side = data.side })

				table.clear(data.closing_threads)
				for i, weld in data.engine_welds do
					weld.C0 = weld.target_position.Value
					weld.target_position:SetAttribute('is_active', false)
				end
				for i, weld in data.floor_welds do
					weld.C0 = weld.target_position.Value
					weld.target_position:SetAttribute('is_active', false)
				end

				data.state = 'Closed'
				controller.StatValues[ds_name] = data.state
				controller.UpdateStatValues()

				if not controller.CheckAllDoors('closed_point') then return end -- Elevator is not safe to move as one or more set of doors are not within their safety zone

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
							controller.MovementInstance.GoToFloor(nearestCallResult.Call, false, directionSwitch)
							return true
						end
					elseif not thisOppositeHallCall then
						controller.StatValues.QueueDirection = 0
						controller._QueueDirectionLock = false
						controller.UpdateStatValues()
					end
				elseif nearestCallResult then
					return controller.MovementInstance.GoToFloor(nearestCallResult.Call, false)
				end
				
				-- 13/01: Add & fix parking feature re-instatement
				local parkFloor = typeof(controller.Config.movement.parking_config) == 'table' and typeof(controller.Config.movement.parking_config.park_floor) == 'number' and controller.Config.movement.parking_config.park_floor or 1
				if parkFloor ~= controller.StatValues.Floor or (typeof(controller.Config.movement.parking_config) == 'table' and controller.Config.movement.parking_config.enable ~= true) then
					controller.MovementInstance.MovementThreads['park_timer'] = task.delay(typeof(controller.Config.movement.parking_config) == 'table' and typeof(controller.Config.movement.parking_config.park_timer) == 'number' and controller.Config.movement.parking_config.park_timer or 60, controller.MovementInstance.GoToFloor, parkFloor, true, true)
				end

				return true
			end

			if (previousState == 'Open') then
				for i, stage in stages do
					stage.accel(i, function(dtTime)
						handleWelds(dtTime)
					end)
				end
			else
				local initialVelocity, finalVelocity = data.velocity, 0
				local rate = .05
				local stage = stages[#stages]
				stage.accel(1, function(dtTime)
					handleWelds(dtTime)
				end)
			end

			while data.state == 'Closing' do
				local lastTick = os.clock()
				controller.Step:Wait()
				local dtTime = os.clock()-lastTick
				data.lastVelocity = data.velocity
				if (handleWelds(dtTime)) then return end
			end
		end))

	end

	return data

end

return doorClass