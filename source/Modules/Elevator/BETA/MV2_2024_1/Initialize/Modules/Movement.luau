local movementClass = {}
movementClass.className = 'movementClass'

local humanoids = {}
local weldingOverlapParams = OverlapParams.new()
weldingOverlapParams.FilterType = Enum.RaycastFilterType.Include

local function processHumanoid(rig: Instance)
	local root, humanoid = rig:FindFirstChild('HumanoidRootPart'), rig:FindFirstChildWhichIsA('Humanoid')
	if (not humanoid) or (not root) then return end
	humanoids[#humanoids+1] = root
	weldingOverlapParams.FilterDescendantsInstances = humanoids
end

for i, rig in workspace:GetDescendants() do
	processHumanoid(rig)
end
workspace.DescendantAdded:Connect(processHumanoid)

function movementClass.new(controller)

	local data = setmetatable({}, movementClass)

	data.movement_threads = {}
	data.player_Welds = {}

	data.stopping = false
	controller.stat_values.door_safety_lock = false

	local signal = require(script.Parent.Signal)
	local stopping = signal.new()

	local function run_motor_sounds()
		for i, v in controller.audio_module.sounds do
			if not string.match(v.Name, 'Motor_') then continue end
			v.Playing = v.Name == `Motor_Start_{controller.stat_values.move_direction == 1 and 'Up' or 'Down'}`
			if v.Name ~= `Motor_Start_{controller.stat_values.move_direction == 1 and 'Up' or 'Down'}` then continue end
			table.insert(data.movement_threads, task.spawn(function()
				v.Ended:Wait()
				controller.audio_module.sounds[`Motor_Run_{controller.stat_values.move_direction == 1 and 'Up' or 'Down'}`].Playing = true
			end))
			stopping:Wait()
			for i, v in controller.audio_module.sounds do
				if not string.match(v.Name, 'Motor_') then continue end
				v.Playing = v.Name == `Motor_Stop_{controller.stat_values.move_direction == 1 and 'Up' or 'Down'}`
			end
		end
	end

	function data.safety_brake()
		for i, v in data.movement_threads do
			pcall(task.cancel, v)
		end
		table.clear(data.movement_threads)
		table.insert(data.movement_threads, task.spawn(function()
			for i, v in controller.audio_module.sounds do
				if not string.match(v.Name, 'Motor_') then continue end
				v.Playing = v.Name == `Motor_Stop_{controller.stat_values.move_direction == 1 and 'Up' or 'Down'}`
			end
			local movementCfg = controller.config.movement[controller.stat_values.move_direction == 1 and 'up' or 'down']
			while (controller.stat_values.speed > 0) do
				local dtTime = controller.step:Wait()
				controller.stat_values.speed = math.max(0, controller.stat_values.speed-.5)
				controller.current_position = CFrame.new(controller.initial_position.Position.X, controller.current_position.Position.Y+controller.stat_values.move_direction*controller.stat_values.speed*dtTime, controller.initial_position.Position.Z)*CFrame.fromOrientation(controller.initial_position:ToOrientation())
				controller.platform.target_position.Value = controller.current_position

				controller.audio_module.sounds.Traveling_Sound.Volume = controller.audio_module.sounds.Traveling_Sound:GetAttribute('minVolume')+(controller.audio_module.sounds.Traveling_Sound:GetAttribute('maxVolume')-controller.audio_module.sounds.Traveling_Sound:GetAttribute('minVolume'))*(controller.stat_values.speed/movementCfg.traveling_speed)
				controller.audio_module.sounds.Traveling_Sound.PlaybackSpeed = controller.audio_module.sounds.Traveling_Sound:GetAttribute('minPitch')+(controller.audio_module.sounds.Traveling_Sound:GetAttribute('maxPitch')-controller.audio_module.sounds.Traveling_Sound:GetAttribute('minPitch'))*(controller.stat_values.speed/movementCfg.traveling_speed)

				local nearFloor = controller.get_nearest_floor().floor_number
				if (nearFloor ~= controller.stat_values.floor) then
					controller.stat_values.floor = nearFloor
					if controller.config.sounds.chimes.floor_passing_chime.enable then
						controller.audio_module.sounds.Floor_Pass_Chime:Play()
					end
				end
				controller.stat_values.velocity = (controller.stat_values.speed^2)^.5
				controller.update_stat_values()
			end
			for i, v in controller.audio_module.sounds do
				if not string.match(v.Name, 'Motor_') then continue end
				v.Playing = false
			end
			controller.stat_values.speed = 0
			controller.stat_values.velocity = 0
			controller.stat_values.move_direction = 0
			controller.stat_values.queue_direction = 0
			data.stopping = false
			stopping:Destroy()
			controller.update_stat_values()
		end))
	end
	
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

	function data.stop_at_floor(floor: number)
		local levelPosition = controller.current_position.Position.Y+(controller.level.Position.Y-controller.platform.Position.Y)
		local floor_instance = controller.find_floor(floor)
		local movementCfg = controller.config.movement[controller.stat_values.move_direction == 1 and 'up' or 'down']
		local currentDistance = controller.stat_values.move_direction*((floor_instance.level.Position.Y+movementCfg.stopping.final_stop_offset)-levelPosition)
		local initialDistance = currentDistance
		local initialDistanceOffset = controller.stat_values.move_direction*((floor_instance.level.Position.Y+movementCfg.stopping.slowdown_final_offset)-levelPosition)
		local initialSpeed = controller.stat_values.speed

		controller.stat_values.leveling = true

		local startTime = os.clock()

		-- Hall call
		-- Check in current direction
		local thisHallCall = controller.queue.find_hall_call(floor, controller.stat_values.queue_direction)
		-- No result? Check in opposite direction
		if not thisHallCall then
			thisHallCall = controller.queue.find_hall_call(floor, -controller.stat_values.queue_direction)
		end
		-- Still no result? Check with no direction
		if not thisHallCall then
			thisHallCall = controller.queue.find_hall_call(floor, 0)
		end

		-- Check for nearby calls in current direction
		local nextHallCall = controller.queue.get_nearest_hall_call(floor, controller.stat_values.queue_direction)
		local nextHallCallCurDir = controller.queue.get_nearest_hall_call(floor, controller.stat_values.queue_direction)
		-- No result? Check in opposite direction
		if not nextHallCall then
			nextHallCall = controller.queue.get_nearest_hall_call(floor, -controller.stat_values.queue_direction)
		end
		-- Still no result? Check with no direction
		if not nextHallCall then
			nextHallCall = controller.queue.get_nearest_hall_call(floor, 0)
		end

		-- Car call
		-- Check in current direction
		local nextCarCall = controller.queue.get_nearest_car_call(floor, controller.stat_values.queue_direction)
		local nextCarCallCurDir = controller.queue.get_nearest_car_call(floor, controller.stat_values.queue_direction)
		-- No result? Check in opposite direction
		if not nextCarCall then
			nextCarCall = controller.queue.get_nearest_car_call(floor, -controller.stat_values.queue_direction)
		end
		-- Still no result? Check with no direction
		if not nextCarCall then
			nextCarCall = controller.queue.get_nearest_car_call(floor, 0)
		end

		controller.queue_direction_lock = false
		local current_direction = controller.stat_values.queue_direction
		local new_direction = if controller.queue_direction_lock == true then
			controller.stat_values.queue_direction
			elseif thisHallCall then
			if thisHallCall.directions[tostring(current_direction)] or nextCarCallCurDir or nextHallCallCurDir then current_direction
			elseif thisHallCall.directions[tostring(-current_direction)] or controller.queue.get_nearest_car_call(floor, -current_direction) or controller.queue.get_nearest_hall_call(floor, -current_direction) then -current_direction

			elseif nextHallCall then
			nextHallCall.call > floor and 1 or nextHallCall.call < floor and -1 or 0
			elseif nextCarCall then
			nextCarCall.call > floor and 1 or nextCarCall.call < floor and -1 or 0
			else 0
		else 0
			-- Correct queue direction if at bottom or top floor --
			new_direction = if controller.stat_values.queue_direction ~= 0 then if controller.top_floor.floor_number == floor then -1 elseif controller.bottom_floor.floor_number == floor then 1 else new_direction else 0
				controller.stat_values.queue_direction = new_direction
				----
				controller.update_stat_values()

				controller.api:Fire('on_arrive', { floor = floor, direction = controller.stat_values.queue_direction, park = controller.stat_values.park })
				controller.check_lantern_and_fire(controller.config.lantern_controls.activate_on_arrival.exterior, controller.config.color_config.lanterns.exterior, function()
					return thisHallCall
				end, floor_instance.floor_model.Lantern_API)
				controller.check_lantern_and_fire(controller.config.lantern_controls.activate_on_arrival.interior, controller.config.color_config.lanterns.interior, function()
					return thisHallCall
				end, controller.car.Lantern_API)
				stopping:Fire()

				while data.stopping do
					local dtTime = controller.step:Wait()

					levelPosition = controller.current_position.Position.Y+(controller.level.Position.Y-controller.platform.Position.Y)
					currentDistance = controller.stat_values.move_direction*((floor_instance.level.Position.Y+movementCfg.stopping.final_stop_offset)-levelPosition)
					local currentDistanceOffset = controller.stat_values.move_direction*((floor_instance.level.Position.Y+movementCfg.stopping.slowdown_final_offset)-levelPosition)

					controller.current_position = CFrame.new(controller.initial_position.Position.X, controller.current_position.Position.Y+controller.stat_values.move_direction*controller.stat_values.speed*dtTime, controller.initial_position.Position.Z)*CFrame.fromOrientation(controller.initial_position:ToOrientation())
					controller.platform.target_position.Value = controller.current_position

					controller.audio_module.sounds.Traveling_Sound.Volume = controller.audio_module.sounds.Traveling_Sound:GetAttribute('minVolume')+(controller.audio_module.sounds.Traveling_Sound:GetAttribute('maxVolume')-controller.audio_module.sounds.Traveling_Sound:GetAttribute('minVolume'))*(controller.stat_values.speed/movementCfg.traveling_speed)
					controller.audio_module.sounds.Traveling_Sound.PlaybackSpeed = controller.audio_module.sounds.Traveling_Sound:GetAttribute('minPitch')+(controller.audio_module.sounds.Traveling_Sound:GetAttribute('maxPitch')-controller.audio_module.sounds.Traveling_Sound:GetAttribute('minPitch'))*(controller.stat_values.speed/movementCfg.traveling_speed)

					local nearFloor = controller.get_nearest_floor().floor_number
					if (nearFloor ~= controller.stat_values.floor) then
						controller.stat_values.floor = nearFloor
						if controller.config.sounds.chimes.floor_passing_chime.enable then
							controller.audio_module.sounds.Floor_Pass_Chime:Play()
						end
					end
					controller.stat_values.velocity = (controller.stat_values.speed^2)^.5
					controller.update_stat_values()

					-- Main slowdown curve --
					if currentDistanceOffset >= 0 then
						if (movementCfg.stopping.slowdown_increment_type == nil or movementCfg.stopping.slowdown_increment_type == 'Constant') then
							local speed = controller.stat_values.speed
							local gradThresh = typeof(movementCfg.stopping.gradual_stop_threshold) == 'number' and movementCfg.stopping.gradual_stop_threshold or 0
							local gradualDecelRatio = math.clamp((currentDistanceOffset/(initialDistanceOffset*gradThresh))/(speed/initialSpeed), 0, 1)
							local rate = speed^2/(2*currentDistanceOffset*gradualDecelRatio)
							local newSpeed = math.max(movementCfg.stopping.slowdown_final_speed, speed-rate*dtTime)
							controller.stat_values.speed = newSpeed
						end
					end

					if (typeof(movementCfg.door_open_config) == 'table' and movementCfg.door_open_config.enable == true and currentDistance <= movementCfg.door_open_config.threshold and controller.stat_values.door_safety_lock and (not controller.stat_values.fire_service) and (not park)) then
						controller.stat_values.door_safety_lock = false
						controller.api:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.config.doors.door_timers.open_on_stop, hall_call = if (thisHallCall and thisHallCall.directions[tostring(controller.stat_values.queue_direction)] ~= nil) or nextCarCall ~= nil then true else false})

						controller.check_lantern_and_fire(controller.config.lantern_controls.activate_on_stop.exterior, controller.config.color_config.lanterns.exterior, function()
							return thisHallCall
						end, floor_instance.floor_model.Lantern_API)
						controller.check_lantern_and_fire(controller.config.lantern_controls.activate_on_stop.interior, controller.config.color_config.lanterns.interior, function()
							return thisHallCall
						end, controller.car.Lantern_API)

						controller.queue.remove_car_call(controller.stat_values.destination)
						controller.queue.remove_hall_call(controller.stat_values.destination, controller.stat_values.queue_direction)
						controller.update_stat_values()
					end

					if ((currentDistance/initialDistance) < 0) then break end
				end
				--doPlayerWeld(false)
				task.wait(controller.step:Wait()/0.1)
				controller.platform.CFrame = controller.platform.target_position.Value
				data.stopping = false
				for i, v in data.player_Welds do
					if v.weld.Part0 and v.weld.Part0.Parent:FindFirstChildWhichIsA('Humanoid') then
						v.weld.Part0.Parent.Humanoid.PlatformStand = false
					end
					v.weld:Destroy()
					v.value:Destroy()
				end
				table.clear(data.player_Welds)
				if controller.stat_values.door_safety_lock and (not controller.stat_values.fire_service) and (not park) then
					controller.check_lantern_and_fire(controller.config.lantern_controls.activate_on_stop.exterior, controller.config.color_config.lanterns.exterior, function()
						return thisHallCall
					end, floor_instance.floor_model.Lantern_API)
					controller.check_lantern_and_fire(controller.config.lantern_controls.activate_on_stop.interior, controller.config.color_config.lanterns.interior, function()
						return thisHallCall
					end, controller.car.Lantern_API)
				end
				controller.stat_values.leveling = false
				controller.stat_values.speed = 0
				controller.stat_values.velocity = 0
				controller.stat_values.move_direction = 0
				controller.stat_values.door_safety_lock = false
				controller.api:Fire('on_stop', { floor = floor, direction = controller.stat_values.queue_direction, park = controller.stat_values.park })
				--local sides = thisQueue and #thisQueue.sides > 0 and thisQueue.sides or 'all'
				if ((not controller.stat_values.fire_service) or controller.fire_recall_floor == floor) and (not park) then
					controller.api:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.config.doors.door_timers.open_on_stop, hall_call = if thisHallCall and thisHallCall.directions[tostring(controller.stat_values.queue_direction)] ~= nil then true else false})
				end
				controller.queue.remove_car_call(controller.stat_values.destination)
				controller.queue.remove_hall_call(controller.stat_values.destination, controller.stat_values.queue_direction)
				controller.update_stat_values()
				if controller.stat_values.fire_service and (not controller.stat_values.phase_2) and floor ~= controller.fire_recall_floor then
					print(`Elevator is returning to recalled floor ({controller.fire_recall_floor})`)
					data.movement_threads['fire_recall'] = task.delay(2, data.go_to_floor, controller.fire_recall_floor, false, true)
				elseif controller.stat_values.phase_2 then
					data.movement_threads['phase_2_move'] = task.delay(2, resumeFloorCall)
				end
			end

			function data.go_to_floor(call: number, park: boolean?, idle_delay: boolean?)

				if controller.stat_values.out_of_service then return 'Elevator is out of service' end
				if call == controller.stat_values.floor then
					controller.api:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.config.doors.door_timers.open_by_call, hall_call = true})
					--controller.queue.remove_car_call(call)
					--controller.queue.remove_hall_call(call, controller.stat_values.queue_direction)
					return warn('Desired call cannot be equal (==) to current floor')
				end
				if not controller.check_all_doors('closed_point') then warn(`Elevator has attempted to move with doors open!`) return 'Elevator has attempted to move with doors open' end

				if controller.stat_values.move_direction ~= 0 or controller.stat_values.door_safety_lock then return end
				local floor_instance = controller.find_floor(call)
				local levelPosition = controller.current_position.Position.Y+(controller.level.Position.Y-controller.platform.Position.Y)
				local direction = floor_instance.level.Position.Y > levelPosition and 1 or floor_instance.level.Position.Y < levelPosition and -1 or 0
				if direction == 0 then return warn('Direction cannot be 0') end
				local directionString = direction == 1 and 'up' or 'down'
				local movementCfg = controller.config.movement[directionString]
				controller.stat_values.destination = call

				controller.api:Fire('on_elevator_start', { direction = direction, idle_delay = idle_delay })
				if not stopping then
					stopping = signal.new()
				end

				controller.stat_values.door_safety_lock = true
				controller.update_stat_values()

				table.insert(data.movement_threads, task.delay(idle_delay == true and 1 or 0, function()

					controller.stat_values.move_direction = direction
					controller.stat_values.queue_direction = direction
					controller.queue_direction_lock = false
					controller.update_stat_values()

					table.insert(data.movement_threads , task.delay((idle_delay == true and 1 or 0)+(movementCfg.motor_start_delay or 0), run_motor_sounds))
					table.insert(data.movement_threads , task.delay((idle_delay == true and 1 or 0)+(movementCfg.start_delay or 0), function()

						local ran, res = pcall(function()
							local result = workspace:GetPartBoundsInBox(controller.current_position, Vector3.new(controller.platform.Size.X-1, controller.platform.Size.Y+15, controller.platform.Size.Z-1), weldingOverlapParams)
							for i, v in result do
								local humanoid = v.Parent:FindFirstChildWhichIsA('Humanoid')
								if (not humanoid) or humanoid.Health == 0 then continue end
								local obj = Instance.new('ObjectValue')
								obj.Name = v.Parent.Name
								obj.Value = v
								obj.Parent = controller.elevator_folder.Player_Welds
								local weld = controller.welding_module.weldParts(v, controller.platform, true, false)
								weld.Name = 'MX_Elevator_Player_Weld'
								weld.Parent = v
								local humanoid = v.Parent:FindFirstChildWhichIsA('Humanoid')
								data.player_Welds[weld] = {
									weld = weld,
									value = obj
								}
							end
							local startTime = os.clock()

							-- Determine the top speed ratio --
							local initialDistance = math.abs((floor_instance.level.Position-controller.level.Position).Y)
							local distanceToMaxSpeed = (movementCfg.traveling_speed^2)/(2*movementCfg.acceleration.acceleration_rate)
							local travelSpeed = initialDistance < distanceToMaxSpeed and math.min(math.sqrt(2*initialDistance), movementCfg.traveling_speed) or movementCfg.traveling_speed

							while true do
								local dtTime = controller.step:Wait()
								local accelerationRate = movementCfg.acceleration.acceleration_rate*math.min((os.clock()-startTime)/movementCfg.acceleration.gradual_acceleration_time, 1)
								controller.stat_values.speed = math.min(controller.stat_values.speed+accelerationRate*math.deg(dtTime), travelSpeed)
								controller.current_position = CFrame.new(controller.initial_position.Position.X, controller.current_position.Position.Y+controller.stat_values.move_direction*controller.stat_values.speed*dtTime, controller.initial_position.Position.Z)*CFrame.fromOrientation(controller.initial_position:ToOrientation())
								controller.platform.target_position.Value = controller.current_position

								controller.audio_module.sounds.Traveling_Sound.Volume = controller.audio_module.sounds.Traveling_Sound:GetAttribute('minVolume')+(controller.audio_module.sounds.Traveling_Sound:GetAttribute('maxVolume')-controller.audio_module.sounds.Traveling_Sound:GetAttribute('minVolume'))*(controller.stat_values.speed/movementCfg.traveling_speed)
								controller.audio_module.sounds.Traveling_Sound.PlaybackSpeed = controller.audio_module.sounds.Traveling_Sound:GetAttribute('minPitch')+(controller.audio_module.sounds.Traveling_Sound:GetAttribute('maxPitch')-controller.audio_module.sounds.Traveling_Sound:GetAttribute('minPitch'))*(controller.stat_values.speed/movementCfg.traveling_speed)

								floor_instance = controller.find_floor(controller.stat_values.destination)

								local nearFloor = controller.get_nearest_floor().floor_number
								if (nearFloor ~= controller.stat_values.floor) then
									controller.stat_values.floor = nearFloor
									if controller.config.sounds.chimes.floor_passing_chime.enable then
										controller.audio_module.sounds.Floor_Pass_Chime:Play()
									end
								end
								controller.stat_values.velocity = (controller.stat_values.speed^2)^.5
								controller.update_stat_values()

								levelPosition = controller.current_position.Position.Y+(controller.level.Position.Y-controller.platform.Position.Y)
								local currentDistance = controller.stat_values.move_direction*((floor_instance.level.Position.Y+movementCfg.stopping.slowdown_final_offset)-levelPosition)
								if (currentDistance <= movementCfg.stopping.distance_to_stop*(controller.stat_values.speed/movementCfg.traveling_speed)+controller.stat_values.speed and (not data.stopping)) then
									data.stopping = true
									for i, v in controller.platform:GetChildren() do
										if (not v:IsA('Sound')) or (not string.match(v.Name, 'Motor_')) then continue end
										v.Playing = v.Name == `Motor_Stop_{directionString}`
									end
									return data.stop_at_floor(controller.stat_values.destination)
								end
							end

						end)
						if not ran then
							warn(`Elevator controller experienced an error : {res}`)
							return data.stop_at_floor(controller.stat_values.floor)
						end
					end))
				end))

			end

			return data

		end

		return movementClass