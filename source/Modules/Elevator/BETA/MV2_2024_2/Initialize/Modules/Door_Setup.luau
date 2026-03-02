local doorClass = {}
doorClass.className = 'doorClass'

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
	controller.stat_values[ds_name] = data.state
	data.door_state_value = Instance.new('StringValue')
	data.door_state_value.Name = `{doorSide}_Door_State`
	data.door_state_value.Value = data.state
	data.door_state_value.Parent = controller.values_folder
	controller.stat_value_instances[data.door_state_value] = {
		instance = data.door_state_value,
		update = function()
			data.door_state_value.Value = controller.stat_values[ds_name]
		end,
	}
	----

	-- Nudge value --
	local nudge_value = `{string.lower(doorSide)}_door_nudge`
	controller.stat_values[nudge_value] = data.nudging
	data.nudge_value = Instance.new('BoolValue')
	data.nudge_value.Name = `{doorSide}_Door_Nudge`
	data.nudge_value.Value = data.nudging
	data.nudge_value.Parent = controller.values_folder
	controller.stat_value_instances[data.nudge_value] = {
		instance = data.nudge_value,
		update = function()
			data.nudge_value.Value = controller.stat_values[nudge_value]
		end,
	}
	----

	-- Speed value --
	local speed_value = `{string.lower(doorSide)}_door_speed`
	controller.stat_values[speed_value] = data.velocity
	data.speed_value = Instance.new('NumberValue')
	data.speed_value.Name = `{doorSide}_Door_Speed`
	data.speed_value.Value = data.velocity
	data.speed_value.Parent = controller.values_folder
	controller.stat_value_instances[data.speed_value] = {
		instance = data.speed_value,
		update = function()
			data.speed_value.Value = controller.stat_values[speed_value]
		end,
	}
	----

	data.doors_folder = Instance.new('Folder')
	data.doors_folder.Name = `{doorSide}_Doors_Data`
	data.doors_folder.Parent = controller.elevator_folder
	data.engine_welds_folder = Instance.new('Folder')
	data.engine_welds_folder.Name = 'Engine_Welds'
	data.engine_welds_folder.Parent = data.doors_folder

	data.bounding_box = Instance.new('Part')
	data.bounding_box.Name = 'Door_Bounds'
	data.bounding_box.CFrame, data.bounding_box.Size = door:GetBoundingBox()
	data.bounding_box.CanCollide = false
	data.bounding_box.Transparency = 1
	data.bounding_box.CanQuery = false
	controller.welding_module.weldParts(data.bounding_box, controller.platform, true)
	data.bounding_box.Parent = door

	data.open_sound = controller.audio_module.addSoundFromConfig(data.bounding_box, 'Open_Sound', {
		id = controller.config.sounds.door_sounds.open_sound.id,
		volume = controller.config.sounds.door_sounds.open_sound.volume,
		pitch = controller.config.sounds.door_sounds.open_sound.pitch,
		looped = false,
		minDistance = controller.config.sounds.door_sounds.open_sound.roll_off.min,
		maxDistance = controller.config.sounds.door_sounds.open_sound.roll_off.max,
		rollOffMode = controller.config.sounds.door_sounds.open_sound.roll_off.mode
	})
	data.close_sound = controller.audio_module.addSoundFromConfig(data.bounding_box, 'Close_Sound', {
		id = controller.config.sounds.door_sounds.close_sound.id,
		volume = controller.config.sounds.door_sounds.close_sound.volume,
		pitch = controller.config.sounds.door_sounds.close_sound.pitch,
		looped = false,
		minDistance = controller.config.sounds.door_sounds.close_sound.roll_off.min,
		maxDistance = controller.config.sounds.door_sounds.close_sound.roll_off.max,
		rollOffMode = controller.config.sounds.door_sounds.close_sound.roll_off.mode
	})

	if typeof(controller.config.sounds.door_sounds.floors) == 'table' then
		for i, v in controller.config.sounds.door_sounds.floors do
			local str = `Floor_{i}_%s`
			local entry_value = `floor_{i}_%s_sound`
			local sound_name = `Floor_{i}_%s_Sound`
			data[string.format(entry_value, 'open')] = controller.audio_module.addSoundFromConfig(data.bounding_box, string.format(sound_name, 'Open'), {
				id = v.open_sound.id,
				volume = v.open_sound.volume,
				pitch = v.open_sound.pitch,
				looped = false,
				minDistance = v.open_sound.roll_off.min,
				maxDistance = v.open_sound.roll_off.max,
				rollOffMode = v.open_sound.roll_off.mode
			})
			data[string.format(entry_value, 'close')] = controller.audio_module.addSoundFromConfig(data.bounding_box, string.format(sound_name, 'Close'), {
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

		controller.welding_module.weldPartsInModel(v, scaler, {open})
		local engineWeld = controller.welding_module.weldParts(scaler, open, true, false)
		engineWeld.Name = 'Door_Engine_Weld'
		engineWeld:SetAttribute('open_point', engineWeld.C1)
		engineWeld:SetAttribute('closed_point', engineWeld.C0)

		-- Handle door safety --
		local function resumeFloorCall()
			local floor_instance = controller.find_floor(controller.stat_values.floor)
			local nearestHallCall = controller.queue.get_nearest_hall_call(controller.stat_values.floor, controller.stat_values.queue_direction)
			local nearestCarCall = controller.queue.get_nearest_car_call(controller.stat_values.floor, controller.stat_values.queue_direction)
			local nearestCallResult = nearestCarCall or nearestHallCall

			local thisOppositeHallCall = controller.queue.find_hall_call(controller.stat_values.floor, -controller.stat_values.queue_direction)
			if thisOppositeHallCall and (not nearestCallResult) then
				controller.stat_values.queue_direction = 0
				controller.queue_direction_lock = true
				controller.stat_values.door_safety_lock = true
				controller.update_stat_values()
				task.wait(1)
				controller.stat_values.queue_direction = controller.index(thisOppositeHallCall.directions, 1)
				controller.queue_direction_lock = false
				controller.stat_values.door_safety_lock = false
				controller.queue.remove_hall_call(thisOppositeHallCall.call, controller.stat_values.queue_direction)
				controller.update_stat_values()
				-- Handle lanterns --
				if controller.config.lantern_controls.activate_on_exterior_wake_call.interior.enable then
					table.insert(data.opening_threads, task.delay(controller.config.lantern_controls.activate_on_exterior_wake_call.interior.delay, function()
						controller.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.interior })
					end))
				end
				if controller.config.lantern_controls.activate_on_exterior_wake_call.exterior.enable then
					table.insert(data.opening_threads, task.delay(controller.config.lantern_controls.activate_on_exterior_wake_call.exterior.delay, function()
						floor_instance.floor_model.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.exterior })
					end))
				end
				----
				return data.open(controller.config.doors.door_timers.open_by_call, true)
			end
			if (not nearestCallResult) and (not thisOppositeHallCall) then
				-- Opposite direction check
				nearestHallCall = controller.queue.get_nearest_hall_call(controller.stat_values.floor, -controller.stat_values.queue_direction)
				nearestCarCall = controller.queue.get_nearest_car_call(controller.stat_values.floor, -controller.stat_values.queue_direction)
				nearestCallResult = nearestCarCall or nearestHallCall

				-- Still no calls? Check with no direction
				if not nearestCallResult then
					nearestHallCall = controller.queue.get_nearest_hall_call(controller.stat_values.floor, 0)
					nearestCarCall = controller.queue.get_nearest_car_call(controller.stat_values.floor, 0)
					nearestCallResult = nearestCarCall or nearestHallCall
				end

				if nearestCallResult then
					local callDirection = nearestCallResult.call > controller.stat_values.floor and 1 or nearestCallResult.call < controller.stat_values.floor and -1 or 0

					if callDirection == -controller.stat_values.queue_direction then
						controller.stat_values.queue_direction = 0
						controller.queue_direction_lock = true
						controller.stat_values.door_safety_lock = true
						controller.update_stat_values()
						task.wait(1)
						controller.queue_direction_lock = false
						controller.stat_values.door_safety_lock = false
					end
					if nearestCallResult then
						controller.movement_instance.go_to_floor(nearestCallResult.call, false)
						return true
					end
				elseif not thisOppositeHallCall then
					controller.stat_values.queue_direction = 0
					controller.queue_direction_lock = false
					controller.update_stat_values()
					return
				end
			elseif nearestCallResult then
				controller.movement_instance.go_to_floor(nearestCallResult.call, false)
			end
		end

		local welds = {}
		for i, v in door:GetDescendants() do
			if v.Name ~= 'Door_Engine_Weld' then continue end
			table.insert(welds, v)
		end

		engineWeld:GetPropertyChangedSignal('C0'):Connect(function()
			task.wait()
			local safetyMet = true
			for i, v in data.engine_welds do
				if (v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude >= .175 and data.state == 'Closed' then safetyMet = false warn(`Door {v:GetFullName()} not within its safety zone, {(v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude}`) break end
			end
			for i, v in welds do
				if (v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude >= .035 and data.state == 'Closed' then safetyMet = false warn(`Door {door:GetFullName()} not within its safety zone, {(v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude}`) break end
			end
			if lastSafetyCheck == safetyMet then return end
			lastSafetyCheck = safetyMet
			controller.stat_values.out_of_service = not safetyMet
			task.spawn(controller.update_stat_values)
			if not safetyMet then
				warn('Safety brake')
				controller.movement_instance.safety_brake()
			else
				print('Safety is good')
				controller.stat_values.door_safety_lock = false
				resumeFloorCall()
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

	local doorConfig = controller.config.doors

	local step = runService.PreSimulation

	function data.open(open_time: number, lantern_signal: boolean?)

		local previousState = data.state
		if (previousState ~= 'Closed' and previousState ~= 'Closing') or data.nudging or controller.stat_values.door_safety_lock or controller.stat_values.out_of_service then return end

		local floor_instance = controller.find_floor(controller.stat_values.floor)
		if not floor_instance then return end

		local doorsModel = floor_instance.floor_model:FindFirstChild(`{data.side}_Doors`)
		if (not doorsModel) or door:GetAttribute('is_door_key') or doorsModel:GetAttribute('is_door_key') then return end

		for i, v in data.closing_threads do
			pcall(task.cancel, v)
		end
		table.clear(data.closing_threads)
		table.insert(data.opening_threads, task.spawn(function()
			if previousState == 'Closed' then
				data.floor_welds = {}
			end
			data.state = 'Opening'
			door:SetAttribute('state', data.state)
			controller.stat_values[ds_name] = data.state
			controller.update_stat_values()

			local doorConfigMain = controller.config.doors.opening
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
						controller.step:Wait()
						local dtTime = os.clock()-lastTick
						data.lastVelocity = data.velocity
						if (typeof(callback) == 'function') then callback(dtTime) end
						data.velocity = lerp(initialVelocity, speed, min((os.clock()-startTime)/duration, 1))
						if (slowdown) then return end
					end
					startTime = os.clock()
					while ((os.clock()-startTime)/delay <= 1) do -- Handle delay
						local lastTick = os.clock()
						controller.step:Wait()
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

			local open_sound = data[`floor_{floor_instance.floor_number}_open_sound`] or data.open_sound
			local close_sound = data[`floor_{floor_instance.floor_number}_close_sound`] or data.close_sound
			table.insert(data.opening_threads, task.delay(previousState == 'Closed' and doorConfig.open_sound_delay or 0, function()
				close_sound:Stop()
				open_sound:Play()
			end))

			task.wait(previousState == 'Closed' and doorConfig.open_delay or 0)
			controller.api:Fire('on_door_open', { side = data.side })
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
				controller.stat_values[speed_value] = data.velocity
				controller.update_stat_values()

				if (not checkWelds('open_point')) then return false end
				task.wait(dtTime/0.1)
				-- Lantern signal --
				if lantern_signal == true and signaling == false then
					signaling = true
					local nearestHallCall = controller.queue.get_nearest_hall_call(controller.stat_values.floor, controller.stat_values.queue_direction)
					local thisHallCall = controller.queue.find_hall_call(controller.stat_values.floor, controller.stat_values.queue_direction)
					controller.check_lantern_and_fire(controller.config.lantern_controls.activate_after_door_open.exterior, controller.config.color_config.lanterns.exterior, function()
						return nearestHallCall or thisHallCall
					end, floor_instance.floor_model.Lantern_API)
					controller.check_lantern_and_fire(controller.config.lantern_controls.activate_after_door_open.interior, controller.config.color_config.lanterns.interior, function()
						return nearestHallCall or thisHallCall
					end, controller.car.Lantern_API)
				end
				----
				data.velocity = 0
				door:SetAttribute('state', data.state)
				controller.stat_values[ds_name] = data.state
				controller.stat_values[speed_value] = data.velocity
				controller.update_stat_values()
				--controller.elevator.API:Fire('onDoorOpened', { side = data.side })
				--data.Opened:Fire()
				data.alpha = 1

				table.clear(data.opening_threads)

				for i, weld in data.engine_welds do
					weld.C0 = weld.target_position.Value
					weld.target_position:SetAttribute('is_active', false)
				end
				for i, weld in data.floor_welds do
					weld.C0 = weld.target_position.Value
					weld.target_position:SetAttribute('is_active', false)
				end

				data.state = 'Open'
				controller.stat_values[ds_name] = data.state
				controller.update_stat_values()

				table.insert(data.opening_threads, task.spawn(function()
					data.timer_start = os.clock()
					if previousState == 'Closed' then
						data.nudge_timer_start = os.clock()
					end
					while true do
						if data.state ~= 'Open' then return end
						if controller.stat_values.fire_service then
							data.timer_start = os.clock()
							data.nudge_timer_start = os.clock()
							print('Resetting all timers')
							for i, v in data.opening_threads do
								pcall(task.cancel, v)
							end
							table.clear(data.opening_threads)
							if controller.fire_recall_floor ~= controller.stat_values.floor and not controller.stat_values.phase_2 then
								return data.close(controller.stat_values.fire_service)
							end
							return
						end
						if (os.clock()-data.timer_start)/open_time >= 1 and (not controller.stat_values.fire_service) then return data.close(controller.stat_values.fire_service) end
						if (os.clock()-data.nudge_timer_start)/(doorConfig.door_timers.nudge_timer or 30) >= 1 then warn('Elevator is nudging') return data.close(true) end
						local result = workspace:GetPartBoundsInBox(data.bounding_box.CFrame, data.bounding_box.Size, overlapParams)
						data.is_obstructed = #result > 0
						if data.is_obstructed then
							data.timer_start = os.clock()
						end
						controller.step:Wait()
					end
				end))
				controller.api:Fire('on_door_opened', { side = data.side })

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
				controller.step:Wait()
				local dtTime = os.clock()-lastTick
				--task.wait(.75)
				data.lastVelocity = data.velocity
				if (handleWelds(dtTime)) then return end
			end
		end))

	end

	function data.close(nudge: boolean?, bypass_opening_state: boolean?)

		local previousState = data.state

		local floor_instance = controller.find_floor(controller.stat_values.floor)
		if not floor_instance then return end

		if (data.state ~= 'Open' and (data.state ~= 'Opening' or not bypass_opening_state)) or (data.is_obstructed and ((not data.nudging) and (not nudge))) then return end

		data.state = 'Closing'
		data.nudging = nudge
		door:SetAttribute('state', data.state)

		if previousState == 'Opening' then
			data.velocity = -data.velocity
		end

		for i, v in data.opening_threads do
			pcall(task.cancel, v)
		end
		table.clear(data.opening_threads)
		table.insert(data.closing_threads, task.spawn(function()
			controller.stat_values[ds_name] = data.state
			controller.stat_values[nudge_value] = data.nudging
			controller.stat_values[speed_value] = data.velocity
			controller.update_stat_values()

			table.insert(data.closing_threads, task.spawn(function()
				while true do
					if data.state ~= 'Closing' then return end
					if (os.clock()-data.nudge_timer_start)/(doorConfig.door_timers.nudge_timer or 30) >= 1 and (not data.nudging) and (not controller.stat_values.fire_service) then
						data.nudging = true
						controller.stat_values[nudge_value] = data.nudging
						return controller.update_stat_values()
					end
					local result = workspace:GetPartBoundsInBox(data.bounding_box.CFrame, data.bounding_box.Size, overlapParams)
					data.is_obstructed = #result > 0
					if data.is_obstructed then
						return data.open(controller.config.doors.door_timers.open_no_call)
					end
					controller.step:Wait()
				end
			end))

			local doorConfigMain = controller.config.doors.closing
			local doorDuration = if data.nudging then doorConfig.nudge_speed else doorConfig.close_speed
			local thisDistance = (data.master_weld:GetAttribute('open_point').Position-data.master_weld:GetAttribute('closed_point').Position).Magnitude
			local doorSpeed = thisDistance/doorDuration

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
						controller.step:Wait()
						local dtTime = os.clock()-lastTick
						data.lastVelocity = data.velocity
						if (typeof(callback) == 'function') then callback(dtTime) end
						data.velocity = lerp(initialVelocity, speed, min((os.clock()-startTime)/duration, 1))
						if (slowdown) then return end
					end
					startTime = os.clock()
					while ((os.clock()-startTime)/delay <= 1) do -- Handle delay
						local lastTick = os.clock()
						controller.step:Wait()
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
					controller.step:Wait()
					local dtTime = os.clock()-lastTick
					data.lastVelocity = data.velocity
					data.velocity = lerp(initialVelocity, speed, min((os.clock()-startTime)/duration, 1))
					if (typeof(callback) == 'function') then callback(dtTime) end
				end
				startTime = os.clock()
				while ((os.clock()-startTime)/delay <= 1) do -- Handle delay
					local lastTick = os.clock()
					controller.step:Wait()
					local dtTime = os.clock()-lastTick
					if (typeof(callback) == 'function') then callback(dtTime) end
				end
			end

			local initialVelocity, initialDistance

			local function checkWelds(target)
				if (data.master_weld.target_position.Value ~= data.master_weld:GetAttribute(target)) then return false end
				return true
			end

			local nearestHallCall = controller.queue.get_nearest_hall_call(controller.stat_values.floor, controller.stat_values.queue_direction)
			local nearestCarCall = controller.queue.get_nearest_car_call(controller.stat_values.floor, controller.stat_values.queue_direction)
			local nearestCallResult = nearestCarCall or nearestHallCall

			local thisOppositeHallCall = controller.queue.find_hall_call(controller.stat_values.floor, -controller.stat_values.queue_direction)

			table.insert(data.closing_threads, task.delay((previousState == 'Open' and doorConfig.close_delay or 0)+doorDuration+(doorConfig.direction_switch_delay or 0), function()
				if thisOppositeHallCall and (not nearestCallResult) then
					controller.stat_values.queue_direction = 0
					controller.queue_direction_lock = true
					controller.stat_values.door_safety_lock = true
					controller.update_stat_values()
					task.wait(1)
					local opposite_direction = controller.index(thisOppositeHallCall.directions, 1)
					controller.queue_direction_lock = false
					controller.stat_values.door_safety_lock = false
					controller.queue.remove_hall_call(thisOppositeHallCall.call, opposite_direction)
					controller.stat_values.queue_direction = opposite_direction
					controller.update_stat_values()
					data.nudge_timer_start = os.clock()
					-- Handle lanterns --
					if controller.config.lantern_controls.activate_on_exterior_wake_call.interior.enable then
						table.insert(data.opening_threads, task.delay(controller.config.lantern_controls.activate_on_exterior_wake_call.interior.delay, function()
							controller.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.interior })
						end))
					end
					if controller.config.lantern_controls.activate_on_exterior_wake_call.exterior.enable then
						table.insert(data.opening_threads, task.delay(controller.config.lantern_controls.activate_on_exterior_wake_call.exterior.delay, function()
							floor_instance.floor_model.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.exterior })
						end))
					end
					----
					return data.open(controller.config.doors.door_timers.open_by_call, true)
				end
			end))

			local open_sound = data[`floor_{floor_instance.floor_number}_open_sound`] or data.open_sound
			local close_sound = data[`floor_{floor_instance.floor_number}_close_sound`] or data.close_sound
			table.insert(data.closing_threads, task.delay(previousState == 'Open' and doorConfig.close_sound_delay or 0, function()
				open_sound:Stop()
				close_sound:Play()
			end))
			task.wait(previousState == 'Open' and doorConfig.close_delay or 0)
			controller.api:Fire('on_door_close', { side = data.side })
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
				controller.stat_values[speed_value] = data.velocity
				controller.update_stat_values()

				if (not checkWelds('closed_point')) then return false end
				task.wait(dtTime/0.1)
				data.nudging = false
				door:SetAttribute('state', data.state)
				data.velocity = 0
				controller.stat_values[nudge_value] = data.nudging
				controller.stat_values[speed_value] = data.velocity
				controller.update_stat_values()
				--controller.elevator.API:Fire('onDoorOpened', { side = data.side })
				--data.Opened:Fire()
				data.alpha = 0
				controller.api:Fire('on_door_closed', { side = data.side })

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
				controller.stat_values[ds_name] = data.state
				controller.update_stat_values()

				if not controller.check_all_doors('closed_point') then return end -- Elevator is not safe to move as one or more set of doors are not within their safety zone

				local nearestHallCall = controller.queue.get_nearest_hall_call(controller.stat_values.floor, controller.stat_values.queue_direction)
				local nearestCarCall = controller.queue.get_nearest_car_call(controller.stat_values.floor, controller.stat_values.queue_direction)
				local nearestCallResult = nearestCarCall or nearestHallCall

				local thisOppositeHallCall = controller.queue.find_hall_call(controller.stat_values.floor, -controller.stat_values.queue_direction)

				if (not nearestCallResult) and (not thisOppositeHallCall) then
					-- Opposite direction check
					nearestHallCall = controller.queue.get_nearest_hall_call(controller.stat_values.floor, -controller.stat_values.queue_direction)
					nearestCarCall = controller.queue.get_nearest_car_call(controller.stat_values.floor, -controller.stat_values.queue_direction)
					nearestCallResult = nearestCarCall or nearestHallCall

					-- Still no calls? Check with no direction
					if not nearestCallResult then
						nearestHallCall = controller.queue.get_nearest_hall_call(controller.stat_values.floor, 0)
						nearestCarCall = controller.queue.get_nearest_car_call(controller.stat_values.floor, 0)
						nearestCallResult = nearestCarCall or nearestHallCall
					end

					if nearestCallResult then
						local callDirection = nearestCallResult.call > controller.stat_values.floor and 1 or nearestCallResult.call < controller.stat_values.floor and -1 or 0

						local directionSwitch = false
						if callDirection == -controller.stat_values.queue_direction then
							controller.stat_values.queue_direction = 0
							controller.queue_direction_lock = true
							controller.stat_values.door_safety_lock = true
							controller.update_stat_values()
							task.wait(1)
							controller.queue_direction_lock = false
							controller.stat_values.door_safety_lock = false
							directionSwitch = true
						end
						if nearestCallResult then
							controller.movement_instance.go_to_floor(nearestCallResult.call, false, directionSwitch)
							return true
						end
					elseif not thisOppositeHallCall then
						controller.stat_values.queue_direction = 0
						controller.queue_direction_lock = false
						controller.update_stat_values()
						return true
					end
				elseif nearestCallResult then
					controller.movement_instance.go_to_floor(nearestCallResult.call, false)
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
				controller.step:Wait()
				local dtTime = os.clock()-lastTick
				data.lastVelocity = data.velocity
				if (handleWelds(dtTime)) then return end
			end
		end))

	end

	return data

end

return doorClass