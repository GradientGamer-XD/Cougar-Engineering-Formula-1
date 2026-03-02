local RunService = game:GetService('RunService')
local MovementClass = {}
MovementClass.className = 'movementClass'

local function convertString(snakeStr)
	local pascalStr = snakeStr:gsub("_(%a)", function(letter)
		return letter:upper()
	end)
	return pascalStr:sub(1, 1):upper() .. pascalStr:sub(2)
end

MovementClass.__index = function(self, key)
	if --[[key == 'car' or key == 'source' or key == 'platform' or key == 'level' or key == 'audio_module' or key == 'api']] rawequal(typeof(key), 'string') and (string.sub(key, 1, 1) == string.sub(string.lower(key), 1, 1) or key == 'current_position') then
		local newKey = convertString(key)
		if newKey == 'Api' then newKey = 'API' end -- Additional correction
		if newKey == 'CheckLanternAndFire' then newKey = 'InvokeLanternAPIWithCheckAsync' end
		--warn(`MXV2 Deprecation Warning: Internal value \'{key}\' was indexed. Please use \'{newKey}\' for new work.`)
		return self[newKey]
	end
end

local humanoids = {}
local weldingOverlapParams = OverlapParams.new()
weldingOverlapParams.FilterType = Enum.RaycastFilterType.Include

local function ProcessHumanoid(rig: Instance)
	local root, humanoid = rig:FindFirstChild('HumanoidRootPart'), rig:FindFirstChildWhichIsA('Humanoid')
	if (not humanoid) or (not root) then return end
	humanoids[#humanoids+1] = root
	weldingOverlapParams.FilterDescendantsInstances = humanoids
end

for i, rig in workspace:GetDescendants() do
	ProcessHumanoid(rig)
end
workspace.DescendantAdded:Connect(ProcessHumanoid)

function MovementClass.new(controller)

	local data = setmetatable({}, MovementClass)

	data.MovementThreads = {}
	data.MovementConnections = {}
	data._PlayerWelds = {}

	data._Stopping = false
	controller.StatValues.DoorSafetyLock = false

	local signal = require(script.Parent.Signal)
	local stopping = signal.new()

	function data.PlayMotorSoundsAsync()
		for i, v in controller.AudioModule.Sounds do
			if not string.match(v.Name, 'Motor_') then continue end
			pcall(v.Name == `Motor_Start_{controller.StatValues.MoveDirection == 1 and 'Up' or 'Down'}` and v.Play or v.Stop, v)
			if v.Name ~= `Motor_Start_{controller.StatValues.MoveDirection == 1 and 'Up' or 'Down'}` then continue end
			table.insert(data.MovementThreads, task.spawn(function()
				v.Ended:Wait()
				controller.AudioModule.Sounds[`Motor_Run_{controller.StatValues.MoveDirection == 1 and 'Up' or 'Down'}`]:Play()
			end))
		end
		stopping:Wait()
		for i, v in controller.AudioModule.Sounds do
			if not string.match(v.Name, 'Motor_') then continue end
			pcall(v.Name == `Motor_Stop_{controller.StatValues.MoveDirection == 1 and 'Up' or 'Down'}` and v.Play or v.Stop, v)
		end
	end
	local function RemovePlayerWelds()
		for i, v in data._PlayerWelds do
			if v.weld.Part0 and v.weld.Part0.Parent and v.weld.Part0.Parent:FindFirstChildWhichIsA('Humanoid') then
				v.weld.Part0.Parent.Humanoid.PlatformStand = false
			end
			v.weld:Destroy()
			v.value:Destroy()
		end
		table.clear(data._PlayerWelds)
	end

	function data.SafetyBrake()
		for i, v in data.MovementThreads do
			pcall(task.cancel, v)
		end
		table.clear(data.MovementThreads)
		for i, v in data.MovementConnections do
			if not v.Connected then continue end
			
			v:Disconnect()
		end
		data.MovementConnections = {}
		controller.API:Fire('on_safety_brake')
		table.insert(data.MovementThreads, task.spawn(function()
			for i, v in controller.AudioModule.Sounds do
				if not string.match(v.Name, 'Motor_') then continue end
				
				pcall(v[v.Name == `Motor_Stop_{controller.StatValues.MoveDirection == 1 and 'Up' or 'Down'}` and 'Play' or 'Stop'], v)
			end
			if controller.SafetyBrakeSound then
				controller.SafetyBrakeSound:Play()
			end
			local movementCfg = controller.Config.movement[controller.StatValues.MoveDirection == 1 and 'up' or 'down']
			while (controller.StatValues.Speed > 0) do
				local dtTime = controller.Step:Wait()
				controller.StatValues.Speed = math.max(0, controller.StatValues.Speed-.185)
				controller.CurrentPosition = CFrame.new(controller._InitialPosition.Position.X, controller.CurrentPosition.Position.Y+controller.StatValues.MoveDirection*controller.StatValues.Speed*dtTime, controller._InitialPosition.Position.Z)*CFrame.fromOrientation(controller._InitialPosition:ToOrientation())
				controller.Platform.target_position.Value = controller.CurrentPosition

				controller.AudioModule.Sounds.Traveling_Sound.Volume = controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minVolume')+(controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('maxVolume')-controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minVolume'))*(controller.StatValues.Speed^2/movementCfg.traveling_speed^2)
				controller.AudioModule.Sounds.Traveling_Sound.PlaybackSpeed = controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minPitch')+(controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('maxPitch')-controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minPitch'))*(controller.StatValues.Speed/movementCfg.traveling_speed)

				local nearFloor = controller.GetNearestFloor().FloorNumber
				if (nearFloor ~= controller.StatValues.Floor) then
					controller.StatValues.Floor = nearFloor
					if controller.Config.sounds.chimes.floor_passing_chime.enable then
						controller.AudioModule.Sounds.Floor_Pass_Chime:Play()
					end
				end
				controller.StatValues.velocity = (controller.StatValues.Speed^2)^.5
				controller.UpdateStatValues()
			end
			for i, v in controller.AudioModule.Sounds do
				if not string.match(v.Name, 'Motor_') then continue end
				v:Stop()
			end
			task.wait(controller.Step:Wait()/0.1)
			controller.Platform.CFrame = controller.Platform.target_position.Value
			controller.StatValues.Speed = 0
			controller.StatValues.Velocity = 0
			controller.StatValues.MoveDirection = 0
			controller.StatValues.QueueDirection = 0
			controller.StatValues.Leveling = false
			controller.StatValues.park = false
			data._Stopping = false
			stopping:Destroy()
			RemovePlayerWelds()
			controller.UpdateStatValues()
			controller.API:Fire('on_stop', { floor = controller.StatValues.Floor, direction = controller.StatValues.QueueDirection, park = controller.StatValues.park })

			for i, v in data.MovementThreads do
				pcall(task.cancel, v)
			end
			table.clear(data.MovementThreads)
		end))
	end

	function data.ResumeFloorCall()
		if not controller.CheckAllDoors('closed_point') then return end
		
		table.insert(data.MovementThreads, task.spawn(function()
			local floor_instance = controller.FindFloor(controller.StatValues.Floor)
			local nearestHallCall = controller.Queue.GetNearestHallCall(controller.StatValues.Floor, controller.StatValues.QueueDirection)
			local nearestCarCall = controller.Queue.GetNearestCarCall(controller.StatValues.Floor, controller.StatValues.QueueDirection)
			local nearestCallResult = nearestCarCall or nearestHallCall

			local thisOppositeHallCall = controller.Queue.FindHallCall(controller.StatValues.Floor, -controller.StatValues.QueueDirection)
			if thisOppositeHallCall and (not nearestCallResult) then
				controller.StatValues.QueueDirection = 0
				controller._QueueDirectionLock = true
				controller.StatValues.DoorSafetyLock = true
				controller.UpdateStatValues()
				task.wait(1)
				controller.StatValues.QueueDirection = controller.IndexInTable(thisOppositeHallCall.Directions, 1)
				controller._QueueDirectionLock = false
				controller.StatValues.DoorSafetyLock = false
				controller.Queue.RemoveHallCall(thisOppositeHallCall.Call, controller.StatValues.QueueDirection)
				controller.API:Fire('on_call_respond', { floor = controller.StatValues.Floor, direction = controller.StatValues.QueueDirection, park = controller.StatValues.park })
				controller.UpdateStatValues()
				-- Handle lanterns --
				if controller.Config.lantern_controls.activate_on_exterior_wake_call.interior.enable then
					table.insert(data.MovementThreads, task.delay(controller.Config.lantern_controls.activate_on_exterior_wake_call.interior.delay, function()
						controller.Car.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.StatValues.QueueDirection, config = controller.Config.color_config.lanterns.interior })
					end))
				end
				if controller.Config.lantern_controls.activate_on_exterior_wake_call.exterior.enable then
					table.insert(data.MovementThreads, task.delay(controller.Config.lantern_controls.activate_on_exterior_wake_call.exterior.delay, function()
						floor_instance.FloorModel.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.StatValues.QueueDirection, config = controller.Config.color_config.lanterns.exterior })
					end))
				end
				----
				return controller.API:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.Config.doors.door_timers.open_by_call, hall_call = if (thisHallCall and thisHallCall.Directions[tostring(controller.StatValues.QueueDirection)] ~= nil) or nextCarCall ~= nil then true else false})
			end
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

					if callDirection == -controller.StatValues.QueueDirection then
						controller.StatValues.QueueDirection = 0
						controller._QueueDirectionLock = true
						controller.StatValues.DoorSafetyLock = true
						controller.UpdateStatValues()
						task.wait(1)
						controller._QueueDirectionLock = false
						controller.StatValues.DoorSafetyLock = false
					end
					if nearestCallResult then
						controller.MovementInstance.GoToFloor(nearestCallResult.Call, false, true)
						return true
					end
				elseif not thisOppositeHallCall then
					controller.StatValues.QueueDirection = 0
					controller._QueueDirectionLock = false
					controller.UpdateStatValues()
				end
			elseif nearestCallResult then
				warn(`Going to floor {nearestCallResult.Call}`)
				return controller.MovementInstance.GoToFloor(nearestCallResult.Call, false, true)
			end
		end))
	end

	function data.StopAtFloor(floor: number, park: boolean?)
		local LevelPosition = controller.CurrentPosition.Position.Y+(controller.Level.Position.Y-controller.Platform.Position.Y)
		local floor_instance = controller.FindFloor(floor)
		local movementCfg = controller.Config.movement[controller.StatValues.MoveDirection == 1 and 'up' or 'down']
		local currentDistance = controller.StatValues.MoveDirection*((floor_instance.Level.Position.Y+movementCfg.stopping.final_stop_offset)-LevelPosition)
		local initialDistance = currentDistance
		local initialDistanceOffset = controller.StatValues.MoveDirection*((floor_instance.Level.Position.Y+movementCfg.stopping.slowdown_final_offset)-LevelPosition)
		local initialSpeed = controller.StatValues.Speed
		local AdvancedOpening = false

		controller.StatValues.Leveling = true

		local startTime = os.clock()
		
		-- Car call
		-- Check in current direction
		local thisCarCall = controller.Queue.FindCarCall(floor, controller.StatValues.QueueDirection)
		-- No result? Check in opposite direction
		if not thisCarCall then
			thisCarCall = controller.Queue.FindCarCall(floor, -controller.StatValues.QueueDirection)
		end
		-- Still no result? Check with no direction
		if not thisCarCall then
			thisCarCall = controller.Queue.FindCarCall(floor, 0)
		end

		-- Hall call
		-- Check in current direction
		local thisHallCall = controller.Queue.FindHallCall(floor, controller.StatValues.QueueDirection)
		-- No result? Check in opposite direction
		if not thisHallCall then
			thisHallCall = controller.Queue.FindHallCall(floor, -controller.StatValues.QueueDirection)
		end
		-- Still no result? Check with no direction
		if not thisHallCall then
			thisHallCall = controller.Queue.FindHallCall(floor, 0)
		end

		-- Check for nearby calls in current direction
		local nextHallCall = controller.Queue.GetNearestHallCall(floor, controller.StatValues.QueueDirection)
		local nextHallCallCurDir = controller.Queue.GetNearestHallCall(floor, controller.StatValues.QueueDirection)
		-- No result? Check in opposite direction
		if not nextHallCall then
			nextHallCall = controller.Queue.GetNearestHallCall(floor, -controller.StatValues.QueueDirection)
		end
		-- Still no result? Check with no direction
		if not nextHallCall then
			nextHallCall = controller.Queue.GetNearestHallCall(floor, 0)
		end

		-- Car call
		-- Check in current direction
		local nextCarCall = controller.Queue.GetNearestCarCall(floor, controller.StatValues.QueueDirection)
		local nextCarCallCurDir = controller.Queue.GetNearestCarCall(floor, controller.StatValues.QueueDirection)
		-- No result? Check in opposite direction
		if not nextCarCall then
			nextCarCall = controller.Queue.GetNearestCarCall(floor, -controller.StatValues.QueueDirection)
		end
		-- Still no result? Check with no direction
		if not nextCarCall then
			nextCarCall = controller.Queue.GetNearestCarCall(floor, 0)
		end

		controller._QueueDirectionLock = false
		local current_direction = controller.StatValues.QueueDirection
		local new_direction = if controller._QueueDirectionLock == true then
			controller.StatValues.QueueDirection

			-- Check current hall call
			elseif thisHallCall then
			if thisHallCall.Directions[tostring(current_direction)] or nextCarCallCurDir or nextHallCallCurDir then
			current_direction
			elseif thisHallCall.Directions[tostring(-current_direction)] or controller.Queue.GetNearestCarCall(floor, -current_direction) or controller.Queue.GetNearestHallCall(floor, -current_direction) then
			-current_direction

			else current_direction
			-- Car & hall calls on other floors
		elseif nextCarCall then
			nextCarCall.Call > floor and 1 or nextCarCall.Call < floor and -1 or 0
		elseif nextHallCall then
			nextHallCall.Call > floor and 1 or nextHallCall.Call < floor and -1 or 0
		else 0

			-- Correct queue direction if at bottom or top floor --
			new_direction = if new_direction ~= 0 then if controller.TopFloor.FloorNumber == floor then -1 elseif controller.BottomFloor.FloorNumber == floor then 1 else new_direction else 0

				controller.StatValues.QueueDirection = new_direction
				----
				controller.UpdateStatValues()

				controller.API:Fire('on_call_respond', { floor = floor, direction = controller.StatValues.QueueDirection, park = controller.StatValues.park })
				controller.API:Fire('on_arrive', { floor = floor, direction = controller.StatValues.QueueDirection, park = controller.StatValues.park })
				
				if typeof(controller.Config.color_config.buttons.car_buttons.floor_buttons.behavior) ~= 'table' or typeof(controller.Config.color_config.buttons.call_buttons.behavior.reset_behavior) ~= 'string' or controller.Config.color_config.buttons.car_buttons.floor_buttons.behavior.reset_behavior == 'on_arrive' then
					controller.API:Fire('reset_car_button', { Call = floor })
				end
				if typeof(controller.Config.color_config.buttons.call_buttons.behavior) ~= 'table' or typeof(controller.Config.color_config.buttons.call_buttons.behavior.reset_behavior) ~= 'string' or controller.Config.color_config.buttons.call_buttons.behavior.reset_behavior == 'on_arrive' then
					controller.API:Fire('reset_floor_button', { Call = floor, Directions = thisHallCall and thisHallCall.Directions or {} })
				end
				
				controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_on_arrival.exterior, controller.Config.color_config.lanterns.exterior, function()
					return thisHallCall
				end, floor_instance.FloorModel.Lantern_API)
				controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_on_arrival.interior, controller.Config.color_config.lanterns.interior, function()
					return thisHallCall
				end, controller.Car.Lantern_API)
				stopping:Fire()

				local reached_min_speed = false
				local reached_dual_stage = false

				local Connection: RBXScriptConnection
				Connection = controller.Step:Connect(function(dtTime: number)
					if dtTime ~= dtTime then
						dtTime = 0 -- Prevents NaN
					end
					dtTime = math.min(dtTime, 5)

					LevelPosition = controller.CurrentPosition.Position.Y+(controller.Level.Position.Y-controller.Platform.Position.Y)
					currentDistance = controller.StatValues.MoveDirection*((floor_instance.Level.Position.Y+movementCfg.stopping.final_stop_offset)-LevelPosition)
					local currentDistanceOffset
					if movementCfg.stopping.use_improved_formula == true or movementCfg.stopping.use_improved_formula == nil then
						currentDistanceOffset = controller.StatValues.MoveDirection*((floor_instance.Level.Position.Y+movementCfg.stopping.slowdown_final_offset)-(LevelPosition+controller.StatValues.MoveDirection*math.max(movementCfg.stopping.slowdown_final_speed*2*(controller.StatValues.Speed/initialSpeed)*2, 0)))
					else
						currentDistanceOffset = controller.StatValues.MoveDirection*((floor_instance.Level.Position.Y+movementCfg.stopping.slowdown_final_offset)-LevelPosition)
					end

					controller.CurrentPosition = CFrame.new(controller._InitialPosition.Position.X, controller.CurrentPosition.Position.Y+controller.StatValues.MoveDirection*controller.StatValues.Speed*dtTime, controller._InitialPosition.Position.Z)*CFrame.fromOrientation(controller._InitialPosition:ToOrientation())
					controller.Platform.target_position.Value = controller.CurrentPosition

					if controller.Counterweight then
						local alpha = (LevelPosition-controller.BottomFloor.Level.Position.Y)/(controller.TopFloor.Level.Position.Y-controller.BottomFloor.Level.Position.Y)
						controller.Counterweight.Main.target_position.Value = CFrame.new(controller.CWStart.Position-(controller.CurrentPosition.Position-controller._InitialPosition.Position))*CFrame.fromOrientation(controller.CWStart:ToOrientation())
					end

					controller.AudioModule.Sounds.Traveling_Sound.Volume = controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minVolume')+(controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('maxVolume')-controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minVolume'))*(controller.StatValues.Speed/movementCfg.traveling_speed)
					controller.AudioModule.Sounds.Traveling_Sound.PlaybackSpeed = controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minPitch')+(controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('maxPitch')-controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minPitch'))*(controller.StatValues.Speed/movementCfg.traveling_speed)

					local nearFloor = controller.GetNearestFloor().FloorNumber
					if (nearFloor ~= controller.StatValues.Floor) then
						controller.StatValues.Floor = nearFloor
						if controller.Config.sounds.chimes.floor_passing_chime.enable then
							controller.AudioModule.Sounds.Floor_Pass_Chime:Play()
						end
					end
					controller.StatValues.velocity = (controller.StatValues.Speed^2)^.5
					controller.UpdateStatValues()

					if controller.Queue.FindHallCall(floor, controller.StatValues.QueueDirection) or controller.Queue.FindCarCall(floor) then
						park = false
					end

					-- Main slowdown curve --
					if currentDistanceOffset >= 0 then
						if (movementCfg.stopping.slowdown_increment_type == nil or movementCfg.stopping.slowdown_increment_type == 'Constant') then
							local reached_dual_speed = typeof(movementCfg.stopping.dual_stage_config) == 'table' and movementCfg.stopping.dual_stage_config.enable and math.abs(currentDistanceOffset) > math.abs(movementCfg.stopping.dual_stage_config.distance)
							local finalSpeed = reached_dual_speed and movementCfg.stopping.dual_stage_config.speed or movementCfg.stopping.slowdown_final_speed
							if reached_dual_speed then
								currentDistanceOffset = controller.StatValues.MoveDirection*((floor_instance.Level.Position.Y+movementCfg.stopping.slowdown_final_offset-movementCfg.stopping.dual_stage_config.distance)-(LevelPosition+(controller.StatValues.MoveDirection*finalSpeed*2*(controller.StatValues.Speed/initialSpeed))))
							end

							local speed = controller.StatValues.Speed
							local gradThresh = typeof(movementCfg.stopping.gradual_stop_threshold) == 'number' and movementCfg.stopping.gradual_stop_threshold or 0
							local gradualDecelRatio = math.clamp((currentDistanceOffset/(initialDistanceOffset*gradThresh))/(speed/initialSpeed), 0, 1)
							local rate = speed^2/(2*currentDistanceOffset*(reached_dual_speed == false and gradualDecelRatio or 1))
							local newSpeed = math.max(finalSpeed, speed-rate*dtTime)
							controller.StatValues.Speed = math.min(newSpeed, speed)
						end
						if controller.StatValues.Speed <= movementCfg.stopping.slowdown_final_speed and reached_min_speed == false then
							reached_min_speed = true
							--RemovePlayerWelds()
						end
					end

					-- Advanced door opening / Pre-door --
					if (not AdvancedOpening and typeof(movementCfg.door_open_config) == 'table' and movementCfg.door_open_config.enable == true and (not park) and currentDistance <= movementCfg.door_open_config.threshold and controller.StatValues.DoorSafetyLock) then
						AdvancedOpening = true
						if (not controller.StatValues.FireService.FireServiceRecall) and (not controller.StatValues.FireService.FireServicePhase2) then
							controller.API:Fire('door_signal', {sides = 'all', request = 'open', disable_safety_lock = true, open_time = controller.Config.doors.door_timers.open_on_stop, hall_call = if (thisHallCall and thisHallCall.Directions[tostring(controller.StatValues.QueueDirection)] ~= nil) or nextCarCall ~= nil then true else false})
							controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_on_stop.exterior, controller.Config.color_config.lanterns.exterior, function()
								return thisHallCall
							end, floor_instance.FloorModel.Lantern_API)
							controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_on_stop.interior, controller.Config.color_config.lanterns.interior, function()
								return thisHallCall
							end, controller.Car.Lantern_API)
						end

						if typeof(controller.Config.color_config.buttons.car_buttons.floor_buttons.behavior) ~= 'table' or controller.Config.color_config.buttons.car_buttons.floor_buttons.behavior.reset_behavior == 'on_open' then
							controller.API:Fire('reset_car_button', { Call = floor })
						end
						if typeof(controller.Config.color_config.buttons.call_buttons.behavior) ~= 'table' or controller.Config.color_config.buttons.call_buttons.behavior.reset_behavior == 'on_open' then
							controller.API:Fire('reset_floor_button', { Call = floor, Directions = thisHallCall and thisHallCall.Directions or {} })
						end
					end
					--

					if ((currentDistance/initialDistance) < 0) then
						Connection:Disconnect()
						
						--doPlayerWeld(false)
						task.wait(controller.Step:Wait()/0.1)
						controller.Platform.CFrame = controller.Platform.target_position.Value
						data._Stopping = false
						if controller.StatValues.DoorSafetyLock and (not controller.StatValues.FireService.FireServiceRecall) and (not controller.StatValues.FireService.FireServicePhase2) and (not park) then
							controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_on_stop.exterior, controller.Config.color_config.lanterns.exterior, function()
								return thisHallCall
							end, floor_instance.FloorModel.Lantern_API)
							controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_on_stop.interior, controller.Config.color_config.lanterns.interior, function()
								return thisHallCall
							end, controller.Car.Lantern_API)
						end
						RemovePlayerWelds()
						controller.StatValues.Leveling = false
						controller.StatValues.Speed = 0
						controller.StatValues.velocity = 0
						controller.StatValues.MoveDirection = 0
						controller.StatValues.DoorSafetyLock = false
						controller.API:Fire('on_stop', { floor = floor, direction = controller.StatValues.QueueDirection, park = controller.StatValues.park })

						if typeof(controller.Config.color_config.buttons.car_buttons.floor_buttons.behavior) == 'table' and controller.Config.color_config.buttons.car_buttons.floor_buttons.behavior.reset_behavior == 'on_stop' then
							controller.API:Fire('reset_car_button', { Call = floor })
						end
						if typeof(controller.Config.color_config.buttons.call_buttons.behavior) == 'table' and controller.Config.color_config.buttons.call_buttons.behavior.reset_behavior == 'on_stop' then
							controller.API:Fire('reset_floor_button', { Call = floor, Directions = thisHallCall and thisHallCall.Directions or {} })
						end

						--local sides = thisQueue and #thisQueue.sides > 0 and thisQueue.sides or 'all'
						if ((not controller.StatValues.FireService.FireServiceRecall and not controller.StatValues.FireService.FireServicePhase2) or controller.FireRecallFloor == floor) and (not park) then
							task.delay(typeof(movementCfg.door_open_config) == 'table' and typeof(movementCfg.door_open_config.open_delay) == 'number' and movementCfg.door_open_config.open_delay or 0, function()
								controller.API:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.Config.doors.door_timers.open_on_stop, hall_call = if thisHallCall and thisHallCall.Directions[tostring(controller.StatValues.QueueDirection)] ~= nil then true else false})
							end)
						end
						controller.Queue.RemoveCarCall(controller.StatValues.Destination)
						controller.Queue.RemoveHallCall(controller.StatValues.Destination, controller.StatValues.QueueDirection)
						controller.UpdateStatValues()
						if controller.Counterweight then
							controller.Counterweight.Main.target_position:SetAttribute('is_active', false)
						end
						if controller.StatValues.FireService.FireServiceRecall and (not controller.StatValues.FireService.FireServicePhase2) and floor ~= controller.FireRecallFloor then
							print(`Elevator is returning to recalled floor ({controller.FireRecallFloor})`)
							data.MovementThreads['fire_recall'] = task.delay(2, data.GoToFloor, controller.FireRecallFloor, false, true)
						elseif controller.StatValues.FireService.FireServicePhase2 then
							data.MovementThreads['phase_2_move'] = task.delay(2, data.ResumeFloorCall)
						end
						if controller.CheckAllDoors('closed_point') then
							data.MovementThreads['idle_attempt'] = task.delay(2, data.ResumeFloorCall)
						end

						local parkFloor = typeof(controller.Config.movement.parking_config) == 'table' and typeof(controller.Config.movement.parking_config.park_floor) == 'number' and controller.Config.movement.parking_config.park_floor or 1
						if parkFloor == controller.StatValues.Floor or (typeof(controller.Config.movement.parking_config) == 'table' and controller.Config.movement.parking_config.enable ~= true) then return end

						data.MovementThreads['park_timer'] = task.delay(typeof(controller.Config.movement.parking_config) == 'table' and typeof(controller.Config.movement.parking_config.park_timer) == 'number' and controller.Config.movement.parking_config.park_timer or 60, data.GoToFloor, parkFloor, true, true)
					end
				end)
				data.MovementConnections[#data.MovementConnections+1] = Connection
			end

			function data.GoToFloor(call: number, park: boolean?, idle_delay: boolean?)

				local ran, res, msg = pcall(function()
					local floor_instance = controller.FindFloor(call)
					if not floor_instance then
						controller.Queue.RemoveCarCall(call)
						controller.Queue.RemoveHallCall(call)
						return true, `Floor instance ({call}) not found`
					end

					if controller.StatValues.OutOfService then return true, 'Elevator is out of service' end

					if call == controller.StatValues.Floor then
						local direction = controller.StatValues.QueueDirection
						controller.API:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.Config.doors.door_timers.open_by_call, hall_call = true})
						controller.Queue.RemoveCarCall(call)
						controller.Queue.RemoveHallCall(call, direction)
						controller.StatValues.QueueDirection = direction
						task.spawn(controller.UpdateStatValues)
						return true, 'Same floor call, opening doors & removing call entry'
					end
					if not controller.CheckDoorTolerance('all', {.175, .065}) then return 'Elevator has attempted to move with doors open' end

					if controller.StatValues.MoveDirection ~= 0 or controller.StatValues.DoorSafetyLock then return true, if controller.StatValues.MoveDirection ~= 0 then 'Elevator is already moving' elseif controller.StatValues.DoorSafetyLock then 'Door safety lock is active' else 'Unable to run' end
					local LevelPosition = controller.CurrentPosition.Position.Y+(controller.Level.Position.Y-controller.Platform.Position.Y)
					local direction = floor_instance.Level.Position.Y > LevelPosition and 1 or floor_instance.Level.Position.Y < LevelPosition and -1 or 0
					if direction == 0 then return print('Direction cannot be 0') end
					local directionString = direction == 1 and 'up' or 'down'
					local movementCfg = controller.Config.movement[directionString]
					controller.StatValues.Destination = call

					controller.API:Fire('on_elevator_start', { direction = direction, idle_delay = idle_delay })
					if not stopping then
						stopping = signal.new()
					end

					controller.StatValues.MoveDirection = direction
					controller.StatValues.QueueDirection = direction
					controller._QueueDirectionLock = false
					controller.StatValues.DoorSafetyLock = true
					controller.UpdateStatValues()
					if controller.Counterweight then
						controller.Counterweight.Main.target_position:SetAttribute('is_active', true)
					end

					controller.Platform.CFrame = controller.CurrentPosition

					if data.MovementThreads['park_timer'] then
						pcall(task.cancel, data.MovementThreads['park_timer'])
						data.MovementThreads['park_timer'] = nil
					end

					table.insert(data.MovementThreads, task.delay(idle_delay == true and 1 or 0, function()

						table.insert(data.MovementThreads , task.delay((idle_delay == true and 1 or 0)+(movementCfg.motor_start_delay or 0), function()
							controller.API:Fire('on_motor_start', { direction = direction })
							data.PlayMotorSoundsAsync()
						end))
						table.insert(data.MovementThreads , task.delay((idle_delay == true and 1 or 0)+(movementCfg.start_delay or 0)+task.wait()/0.1, function()

							local ran, res = pcall(function()
								local welded = {}
								local result = workspace:GetPartBoundsInBox(controller.CurrentPosition, Vector3.new(controller.Platform.Size.X-.5, controller.Platform.Size.Y+15, controller.Platform.Size.Z-.5), weldingOverlapParams)
								for i, v in result do
									local humanoid = v.Parent:FindFirstChildWhichIsA('Humanoid')
									if (not humanoid) or humanoid.Health == 0 then continue end
									local obj = Instance.new('ObjectValue')
									obj.Name = v.Parent.Name
									obj.Value = v
									obj.Parent = controller.ElevatorFolder.Player_Welds

									local weld = Instance.new('Weld')
									weld.Name = 'MX_Elevator_Player_Weld'
									weld.Part0, weld.Part1 = v, controller.Platform
									weld.C0, weld.C1 = CFrame.new(), weld.Part1.CFrame:ToObjectSpace(weld.Part0.CFrame)
									weld.Parent = v

									local humanoid = v.Parent:FindFirstChildWhichIsA('Humanoid')

									local connection: RBXScriptConnection
									connection = v.Parent.Changed:Connect(function()
										if v.Parent then return end

										connection:Disconnect()
										connection = nil
										if not data._PlayerWelds[weld] then return end

										data._PlayerWelds[weld].weld:Destroy()
										data._PlayerWelds[weld].value:Destroy()
										data._PlayerWelds[weld] = nil
									end)

									data._PlayerWelds[weld] = {
										weld = weld,
										value = obj
									}
									welded[#welded+1] = humanoid.Parent
								end

								controller.API:Fire('on_elevator_move_begin', { direction = direction, welded = welded })
								local startTime = os.clock()

								-- Determine the top speed ratio --
								local initialDistance = math.abs((floor_instance.Level.Position-controller.Level.Position).Y)
								local distanceToMaxSpeed = (movementCfg.traveling_speed^2)/(2*movementCfg.acceleration.acceleration_rate)
								local travelSpeed = initialDistance < distanceToMaxSpeed and math.min(math.sqrt(2*initialDistance), movementCfg.traveling_speed) or movementCfg.traveling_speed

								local Connection: RBXScriptConnection
								Connection = controller.Step:Connect(function(dtTime: number)
									local accelerationRate = movementCfg.acceleration.acceleration_rate*math.min((os.clock()-startTime)/movementCfg.acceleration.gradual_acceleration_time, 1)
									controller.StatValues.Speed = math.min(controller.StatValues.Speed+accelerationRate*dtTime/0.025, travelSpeed)
									controller.CurrentPosition = CFrame.new(controller._InitialPosition.Position.X, controller.CurrentPosition.Position.Y+controller.StatValues.MoveDirection*controller.StatValues.Speed*dtTime, controller._InitialPosition.Position.Z)*CFrame.fromOrientation(controller._InitialPosition:ToOrientation())
									controller.Platform.target_position.Value = controller.CurrentPosition

									controller.StatValues.DoorSafetyLock = true

									LevelPosition = controller.CurrentPosition.Position.Y+(controller.Level.Position.Y-controller.Platform.Position.Y)

									if controller.Counterweight then
										local alpha = (LevelPosition-controller.BottomFloor.Level.Position.Y)/(controller.TopFloor.Level.Position.Y-controller.BottomFloor.Level.Position.Y)
										controller.Counterweight.Main.target_position.Value = CFrame.new(controller.CWStart.Position-(controller.CurrentPosition.Position-controller._InitialPosition.Position))*CFrame.fromOrientation(controller.CWStart:ToOrientation())
									end

									controller.AudioModule.Sounds.Traveling_Sound.Volume = controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minVolume')+(controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('maxVolume')-controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minVolume'))*(controller.StatValues.Speed/movementCfg.traveling_speed)
									controller.AudioModule.Sounds.Traveling_Sound.PlaybackSpeed = controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minPitch')+(controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('maxPitch')-controller.AudioModule.Sounds.Traveling_Sound:GetAttribute('minPitch'))*(controller.StatValues.Speed/movementCfg.traveling_speed)

									floor_instance = controller.FindFloor(controller.StatValues.Destination)

									local nearFloor = controller.GetNearestFloor().FloorNumber
									if (nearFloor ~= controller.StatValues.Floor) then
										controller.StatValues.Floor = nearFloor
										if controller.Config.sounds.chimes.floor_passing_chime.enable then
											controller.AudioModule.Sounds.Floor_Pass_Chime:Play()
										end
									end
									controller.StatValues.velocity = (controller.StatValues.Speed^2)^.5
									controller.UpdateStatValues()

									local currentDistance = controller.StatValues.MoveDirection*((floor_instance.Level.Position.Y+movementCfg.stopping.slowdown_final_offset)-LevelPosition)
									if (currentDistance <= movementCfg.stopping.distance_to_stop*(controller.StatValues.Speed/movementCfg.traveling_speed)+controller.StatValues.Speed and (not data._Stopping)) then
										data._Stopping = true
										for i, v in controller.Platform:GetChildren() do
											if (not v:IsA('Sound')) or (not string.match(v.Name, 'Motor_')) then continue end

											pcall(v[v.Name == `Motor_Stop_{directionString}` and 'Play' or 'Stop'], v)
										end
										Connection:Disconnect()
										return data.StopAtFloor(controller.StatValues.Destination, park)
									end
								end)
								data.MovementConnections[#data.MovementConnections+1] = Connection

							end)
							if not ran then
								warn(`Elevator controller experienced an error : {res}`)
								return data.StopAtFloor(controller.StatValues.Floor, park)
							end
						end))
					end))
				end)
				if not ran or res == false then
					warn(`Elevator has experienced an error: {res or msg}`)
					return data.StopAtFloor(controller.StatValues.Floor, park)
				end

			end

			return data

		end

		return MovementClass