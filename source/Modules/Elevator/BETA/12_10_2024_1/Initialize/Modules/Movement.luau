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
	
	function data.safety_brake()
		for i, v in data.movement_threads do
			pcall(task.cancel, v)
		end
		table.clear(data.movement_threads)
		table.insert(data.movement_threads, task.spawn(function()
			local movementCfg = controller.config.movement[controller.stat_values.move_direction == 1 and 'up' or 'down']
			while (controller.stat_values.speed > 0) do
				local dtTime = controller.step:Wait()
				controller.stat_values.speed = math.max(0, controller.stat_values.speed-.75)
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
			controller.stat_values.speed = 0
			controller.stat_values.velocity = 0
			controller.stat_values.move_direction = 0
			controller.stat_values.queue_direction = 0
			data.stopping = false
			controller.update_stat_values()
		end))
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

		controller.api:Fire('on_elevator_arrive', { floor = floor, direction = controller.stat_values.queue_direction })

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
		-- No result? Check in opposite direction
		if not nextCarCall then
			nextCarCall = controller.queue.get_nearest_car_call(floor, -controller.stat_values.queue_direction)
		end
		-- Still no result? Check with no direction
		if not nextCarCall then
			nextCarCall = controller.queue.get_nearest_car_call(floor, 0)
		end

		controller.stat_values.queue_direction = if controller.queue_direction_lock == true then controller.stat_values.queue_direction elseif thisHallCall then thisHallCall.directions[tostring(controller.stat_values.queue_direction)] or thisHallCall.directions[tostring(-controller.stat_values.queue_direction)] elseif nextHallCall then nextHallCall.call > floor and 1 or nextHallCall.call < floor and -1 or 0 elseif nextCarCall then nextCarCall.call > floor and 1 or nextCarCall.call < floor and -1 or 0 else 0
		controller.api:Fire('on_arrive', { floor = floor, direction = controller.stat_values.queue_direction, park = controller.stat_values.park })
		if controller.config.lantern_controls.activate_on_arrival.exterior.enable and thisHallCall then
			task.delay(controller.config.lantern_controls.activate_on_arrival.exterior.delay, function()
				floor_instance.floor_model.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.exterior })
			end)
		end
		if controller.config.lantern_controls.activate_on_arrival.interior.enable and thisHallCall then
			task.delay(controller.config.lantern_controls.activate_on_arrival.interior.delay, function()
				controller.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.interior })
			end)
		end

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

			if (typeof(movementCfg.door_open_config) == 'table' and movementCfg.door_open_config.enable == true and currentDistance <= movementCfg.door_open_config.threshold and controller.stat_values.door_safety_lock) then
				controller.stat_values.door_safety_lock = false
				controller.api:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.config.doors.door_timers.open_on_stop, hall_call = if thisHallCall and thisHallCall.directions[tostring(controller.stat_values.queue_direction)] ~= nil then true else false})
				if controller.config.lantern_controls.activate_on_stop.exterior.enable and thisHallCall then
					task.delay(controller.config.lantern_controls.activate_on_stop.exterior.delay, function()
						floor_instance.floor_model.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.exterior })
					end)
				end
				if controller.config.lantern_controls.activate_on_stop.interior.enable and thisHallCall then
					task.delay(controller.config.lantern_controls.activate_on_stop.interior.delay, function()
						controller.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.interior })
					end)
				end
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
		if controller.config.lantern_controls.activate_on_stop.exterior.enable and controller.stat_values.queue_direction ~= 0 then
			task.delay(controller.config.lantern_controls.activate_on_stop.exterior.delay, function()
				floor_instance.floor_model.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.exterior })
			end)
		end
		if controller.config.lantern_controls.activate_on_stop.interior.enable and controller.stat_values.queue_direction ~= 0 then
			task.delay(controller.config.lantern_controls.activate_on_stop.interior.delay, function()
				controller.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.interior })
			end)
		end
		controller.stat_values.leveling = false
		controller.stat_values.speed = 0
		controller.stat_values.velocity = 0
		controller.stat_values.move_direction = 0
		controller.stat_values.door_safety_lock = false
		--local sides = thisQueue and #thisQueue.sides > 0 and thisQueue.sides or 'all'
		controller.api:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.config.doors.door_timers.open_on_stop, hall_call = if thisHallCall and thisHallCall.directions[tostring(controller.stat_values.queue_direction)] ~= nil then true else false})
		controller.queue.remove_car_call(controller.stat_values.destination)
		controller.queue.remove_hall_call(controller.stat_values.destination, controller.stat_values.queue_direction)
		controller.update_stat_values()
	end

	function data.go_to_floor(call: number, park: boolean?)

		if not controller.check_all_doors('closed_point') then warn(`Elevator has attempted to move with doors open!`) return 'Elevator has attempted to move with doors open' end
		if controller.stat_values.out_of_service then return 'Elevator is out of service' end
		if call == controller.stat_values.floor then return warn('Desired call cannot be equal (==) to current floor') end

		if controller.stat_values.move_direction ~= 0 or controller.stat_values.door_safety_lock then return end
		local floor_instance = controller.find_floor(call)
		local levelPosition = controller.current_position.Position.Y+(controller.level.Position.Y-controller.platform.Position.Y)
		local direction = floor_instance.level.Position.Y > levelPosition and 1 or floor_instance.level.Position.Y < levelPosition and -1 or 0
		if direction == 0 then return warn('Direction cannot be 0') end
		print(`Going to floor {floor_instance.floor_number} with direction {direction}`)
		local directionString = direction == 1 and 'up' or 'down'
		local movementCfg = controller.config.movement[directionString]
		controller.stat_values.destination = call
		
		controller.api:Fire('on_elevator_start', { direction = direction })

		table.insert(data.movement_threads, task.spawn(function()

				controller.stat_values.door_safety_lock = true
				controller.stat_values.move_direction = direction
				controller.stat_values.queue_direction = direction
				controller.update_stat_values()

				table.insert(data.movement_threads , task.delay(movementCfg.start_delay or 0, function()

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