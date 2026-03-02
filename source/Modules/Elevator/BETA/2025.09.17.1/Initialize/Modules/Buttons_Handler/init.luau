local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

local ButtonHandlerClass = {}
ButtonHandlerClass.className = 'ButtonHandlerClass'

local TransitionHandler = script.Transition_Handler
if RunService:IsRunMode() then
	TransitionHandler.Server.Enabled = true
else
	TransitionHandler.Client.Enabled = true
end
TransitionHandler.Parent = ReplicatedStorage

local ControllerModule = require(script.Parent.Setup)

function ButtonHandlerClass.new(source, config, controller)

	local data = setmetatable({}, ButtonHandlerClass)

	function data.Setup()

		local function SetButton(start: Instance, includeAllAlikes: boolean, button: Instance, config: any, state: string, enable: boolean)
			if includeAllAlikes == true then
				for i, v in (start or button.Parent.Parent):GetDescendants() do
					if v.Name ~= button.Name then continue end
					for i, l in v:GetDescendants() do
						if l.Name ~= 'Light' or (not l:IsA('BasePart')) then continue end

						local behavior = button:IsDescendantOf(controller.Car) and controller.Config.color_config.buttons.car_buttons.floor_buttons.behavior or controller.Config.color_config.buttons.call_buttons[string.lower(button.Name)] and controller.Config.color_config.buttons.call_buttons[string.lower(button.Name)].behavior

						local inactiveLED = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and behavior.illumination_transition.enable == true and l:FindFirstChild('Inactive')
						if inactiveLED then
							l.Color, l.Material = config.active.color, config.active.material
							inactiveLED.Color, inactiveLED.Material = config.inactive.color, config.inactive.material
							inactiveLED:SetAttribute('IsActive', state == 'inactive')
							if RunService:IsRunMode() then
								TransitionHandler.Event:Fire({
									Part = inactiveLED,
									Active = state == 'inactive',
									Duration = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.duration) == 'number' and behavior.illumination_transition.active.duration or 0,
									EasingStyle = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.easing_style) == 'EnumItem' and behavior.illumination_transition.active.easing_style or Enum.EasingStyle.Linear,
									EasingDirection = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.easing_direction) == 'EnumItem' and behavior.illumination_transition.active.easing_direction or Enum.EasingDirection.InOut
								})
							else
								TransitionHandler.Remote:FireAllClients({
									Part = inactiveLED,
									Active = state == 'inactive',
									Duration = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.duration) == 'number' and behavior.illumination_transition.active.duration or 0,
									EasingStyle = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.easing_style) == 'EnumItem' and behavior.illumination_transition.active.easing_style or Enum.EasingStyle.Linear,
									EasingDirection = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.easing_direction) == 'EnumItem' and behavior.illumination_transition.active.easing_direction or Enum.EasingDirection.InOut
								})
							end
						else
							l.Color, l.Material = config[state].color, config[state].material
						end

						for i, v in l:GetDescendants() do
							if not v:IsA('Light') then continue end

							v.Enabled = enable == true
						end
					end
				end
			else
				for i, l in button:GetDescendants() do
					if l.Name ~= 'Light' or (not l:IsA('BasePart')) then continue end

					local behavior = button:IsDescendantOf(controller.Car) and controller.Config.color_config.buttons.car_buttons.floor_buttons.behavior or controller.Config.color_config.buttons.call_buttons[string.lower(button.Name)] and controller.Config.color_config.buttons.call_buttons[string.lower(button.Name)].behavior

					local inactiveLED = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and behavior.illumination_transition.enable == true and l:FindFirstChild('Inactive')
					if inactiveLED then
						l.Color, l.Material = config.active.color, config.active.material
						inactiveLED.Color, inactiveLED.Material = config.inactive.color, config.inactive.material
						inactiveLED:SetAttribute('IsActive', state == 'active')
						if RunService:IsRunMode() then
							TransitionHandler.Event:Fire({
								Part = inactiveLED,
								Active = state == 'inactive',
								Duration = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.duration) == 'number' and behavior.illumination_transition.active.duration or 0,
								EasingStyle = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.easing_style) == 'EnumItem' and behavior.illumination_transition.active.easing_style or Enum.EasingStyle.Linear,
								EasingDirection = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.easing_direction) == 'EnumItem' and behavior.illumination_transition.active.easing_direction or Enum.EasingDirection.InOut
							})
						else
							TransitionHandler.Remote:FireAllClients({
								Part = inactiveLED,
								Active = state == 'inactive',
								Duration = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.duration) == 'number' and behavior.illumination_transition.active.duration or 0,
								EasingStyle = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.easing_style) == 'EnumItem' and behavior.illumination_transition.active.easing_style or Enum.EasingStyle.Linear,
								EasingDirection = typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and typeof(behavior.illumination_transition.active) == 'table' and typeof(behavior.illumination_transition.active.easing_direction) == 'EnumItem' and behavior.illumination_transition.active.easing_direction or Enum.EasingDirection.InOut
							})
						end
					else
						l.Color, l.Material = config[state].color, config[state].material
					end

					for i, v in l:GetDescendants() do
						if not v:IsA('Light') then continue end

						v.Enabled = enable == true
					end
				end
			end
		end

		local floorButtons = {}

		controller.API.Event:Connect(function(protocol, params)
			if protocol == 'reset_car_button' then
				local call = params.Call
				for i, v in floorButtons do
					if v.Name ~= `Floor_{call}` then continue end
					
					task.delay(typeof(controller.Config.color_config.buttons.car_buttons.floor_buttons.behavior) == 'table' and controller.Config.color_config.buttons.car_buttons.floor_buttons.behavior.reset_delay or 0, SetButton, controller.Car, false, v, config.color_config.buttons.car_buttons.floor_buttons, 'inactive', false)
				end
			elseif protocol == 'reset_floor_button' then
				local call = params.Call
				for i, v in controller.Floors do
					if v.FloorNumber ~= call then continue end
					for i, c in v.FloorModel:GetChildren() do
						if c.Name ~= 'Call_Buttons' then continue end
						for i, b in c:GetChildren() do
							if b.Name ~= 'Up' and b.Name ~= 'Down' then continue end
							local directionValue = b.Name == 'Up' and 1 or b.Name == 'Down' and -1
							if (not params.Directions[tostring(directionValue)]) or directionValue ~= controller.StatValues.QueueDirection then continue end
							task.delay(typeof(controller.Config.color_config.buttons.call_buttons.behavior) == 'table' and controller.Config.color_config.buttons.call_buttons.behavior.reset_delay or 0, SetButton, b, false, b, config.color_config.buttons.call_buttons[string.lower(b.Name)], 'inactive', false)
						end
					end
				end
			end
		end)

		-- Car buttons --
		for i, v in controller.Car:GetChildren() do
			if v.Name ~= 'Buttons' then continue end
			for i, b in v:GetChildren() do
				local button = b:FindFirstChild('Button')
				if not button then continue end
				
				local behavior = controller.Config.color_config.buttons.car_buttons.floor_buttons.behavior

				if typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and behavior.illumination_transition.enable == true then
					for i, l in b:GetDescendants() do
						if not l:IsA('BasePart') or l.Name ~= 'Light' or l:FindFirstChild('Inactive') then continue end

						local inactiveLED = l:Clone()
						inactiveLED.Name = 'Inactive'
						--inactiveLED.Size += Vector3.new(1, 1, 1)*.0015
						inactiveLED.Reflectance -= 0.05
						inactiveLED.Transparency = 0
						controller.WeldingModule.WeldParts(inactiveLED, l, false, false)
						inactiveLED.Anchored = false
						inactiveLED.Parent = l
					end
				end

				local floorNumber = tonumber(string.split(b.Name, 'Floor')[2]) or tonumber(string.split(b.Name, '_')[2])
				local side = string.split(b.Name, '_')[3]
				floorButtons[b] = b

				local dragDetector = button:FindFirstChild('DragDetector') or Instance.new('DragDetector')
				dragDetector.MaxActivationDistance = 10
				dragDetector.DragStyle = Enum.DragDetectorDragStyle.Scriptable
				dragDetector.Parent = button

				--if not ControllerModule.controllers[controller.Id] then
				if floorNumber then
					SetButton(b, false, b, config.color_config.buttons.car_buttons.floor_buttons, 'inactive', false)
				elseif string.match(b.Name, 'DoorOpen') or string.match(b.Name, 'Door_Open') then
					SetButton(b, false, b, config.color_config.buttons.car_buttons.door_buttons.open, 'inactive', false)
				elseif string.match(b.Name, 'DoorClose') or string.match(b.Name, 'Door_Close') then
					SetButton(b, false, b, config.color_config.buttons.car_buttons.door_buttons.close, 'inactive', false)
				elseif b.Name == 'Alarm' then
					SetButton(b, false, b, config.color_config.buttons.car_buttons.alarm_button, 'inactive', false)
				end
				--end

				local lanternThread = nil
				local buttonHoldConnections = {}

				local cfg = controller.Config.sounds.button_sounds.car_button_click
				local buttonClickSound: Sound = button:FindFirstChild('Button_Click') or controller.AudioModule.AddSoundFromConfig(button, 'Button_Click', {
					id = cfg.id,
					volume = cfg.volume,
					pitch = cfg.pitch,
					looped = config.looped,
					minDistance = cfg.roll_off.min,
					maxDistance = cfg.roll_off.max,
					rollOffMode = cfg.roll_off.mode,
				})
				if cfg.time_positioning.enable then
					if buttonClickSound:IsA('Sound') then
						buttonClickSound.PlaybackRegionsEnabled = true
					end
					buttonClickSound.TimePosition = 0
				end

				dragDetector.DragStart:Connect(function(playerWhoDragged: Player)

					if playerWhoDragged and playerWhoDragged:GetAttribute('clickDebounce') then return end
					if playerWhoDragged then
						playerWhoDragged:SetAttribute('clickDebounce', true)
						task.delay(.05, function()
							playerWhoDragged:SetAttribute('clickDebounce', false)
						end)
					end

					controller.API:Fire('on_button_pressed', { button = b })
					-- Playback Regions --
					if typeof(cfg.time_positioning) == 'table' and ((buttonClickSound:IsA('Sound') and buttonClickSound.PlaybackRegionsEnabled) or buttonClickSound:IsA('AudioPlayer')) then
						buttonClickSound.PlaybackRegion = NumberRange.new(cfg.time_positioning.press.min, cfg.time_positioning.press.max)
						buttonClickSound.TimePosition = buttonClickSound.PlaybackRegion.Min
					else
						buttonClickSound.TimePosition = 0
					end
					buttonClickSound:Play()
					----

					dragDetector:SetAttribute('isDown', true)
					local conditionResult = if controller.ButtonInputConditionFunc and typeof(controller.ButtonInputConditionFunc.handleButtonClicked) == 'function' then controller.ButtonInputConditionFunc.handleButtonClicked(playerWhoDragged, true, b, controller) else nil
					local conditionMet = conditionResult == nil or conditionResult == true

					if floorNumber then
						SetButton(controller.Car, true, b, config.color_config.buttons.car_buttons.floor_buttons, 'active', true)

						-- 10/10/2025: Fix fire service recall disabling the buttons
						if not conditionMet or controller.StatValues.FireService.FireServiceRecall then return end

						local side = string.split(v.Name, `Floor_{floorNumber}_`)[1] and string.split(v.Name, `Floor_{floorNumber}_`)[2]

						if controller.StatValues.OutOfService or (controller.StatValues.FireService.FireServiceRecall or (controller.StatValues.FireService.FireServicePhase2 and controller.StatValues.Floor == floorNumber)) or ((not controller.Queue.FindCarCall(floorNumber)) and (not conditionMet)) then return end

						if floorNumber == controller.StatValues.Floor and controller.StatValues.MoveDirection == 0 then
							controller.InvokeLanternAPIWithCheckAsync(
								config.lantern_controls.activate_when_same_button_pressed.interior,
								config.color_config.lanterns.interior,
								function(): () -> boolean
									for i, v in controller.door_data do
										if v.State ~= 'Closed' then
											return true
										end
									end
									return false
								end,
								controller.Car.Lantern_API
							)
							if (not buttonHoldConnections[b]) or (not buttonHoldConnections[b].Connected) then
								buttonHoldConnections[b] = controller.Step:Connect(function()
									for i, v in controller.door_data do
										if v.state ~= 'Open' then continue end
										v.TimerStart = os.clock()
									end
								end)
							end
							return controller.API:Fire('door_signal', {request = 'open', sides = 'all', open_time = config.doors.door_timers.open_on_stop})
						end

						local queue_dir = controller.StatValues.QueueDirection
						controller.Queue.AddCarCall(floorNumber, { side = side })
						if queue_dir ~= 0 or controller.StatValues.QueueDirection == 0 or controller.CheckAllDoors('closed_point') then return end

						local floor_instance = controller.FindFloor(controller.StatValues.Floor)
						if controller.Config.lantern_controls.activate_on_call_entry then
							controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_on_call_entry.exterior, controller.Config.color_config.lanterns.exterior, function()
								return true
							end, floor_instance.FloorModel.Lantern_API)
						end
						if controller.Config.lantern_controls.activate_on_call_entry then
							controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_on_call_entry.interior, controller.Config.color_config.lanterns.interior, function()
								return true
							end, controller.Car.Lantern_API)
						end
					elseif string.match(b.Name, 'DoorOpen') or string.match(b.Name, 'Door_Open') then
						local side = string.split(b.Name, 'DoorOpen')[1] or string.split(b.Name, 'Door_Open')[1]
						if (string.match(side, '_')) then
							side = string.split(side, '_')[1]
						end
						if config.color_config.buttons.car_buttons.door_buttons.open.enable then
							SetButton(controller.Car, true, b, config.color_config.buttons.car_buttons.door_buttons.open, 'active', true)
						end
						-- 10/10/2025: Implemented button disable on fire service recall
						if (not conditionMet) or controller.StatValues.FireService.FireServiceRecall then return end
						
						controller.door_data[side].Open(controller.Config.doors.door_timers.open_no_call)
					elseif string.match(b.Name, 'DoorClose') or string.match(b.Name, 'Door_Close') then
						local side = string.split(b.Name, 'DoorClose')[1] or string.split(b.Name, 'Door_Close')[1]
						if (string.match(side, '_')) then
							side = string.split(side, '_')[1]
						end
						if config.color_config.buttons.car_buttons.door_buttons.close.enable then
							SetButton(controller.Car, true, b, config.color_config.buttons.car_buttons.door_buttons.close, 'active', true)
						end
						
						-- 10/10/2025: Implemented button disable on fire service recall
						if (not conditionMet) or controller.StatValues.FireService.FireServiceRecall then return end
						
						controller.door_data[side].close(false, controller.StatValues.FireService.FireServicePhase2)
					elseif b.Name == 'Alarm' then
						SetButton(controller.Car, true, b, config.color_config.buttons.car_buttons.alarm_button, 'active', true)
						if not conditionMet then return end
						controller.AudioModule.Sounds.Alarm.Playing = true
					end
				end)
				dragDetector.DragEnd:Connect(function(playerWhoDragged: Player)

					controller.API:Fire('on_button_released', { button = b })
					-- Playback Regions --
					if typeof(cfg.time_positioning) == 'table' and ((buttonClickSound:IsA('Sound') and buttonClickSound.PlaybackRegionsEnabled) or buttonClickSound:IsA('AudioPlayer')) then
						buttonClickSound.PlaybackRegion = NumberRange.new(cfg.time_positioning.release.min, cfg.time_positioning.release.max)
						buttonClickSound.TimePosition = buttonClickSound.PlaybackRegion.Min
					else
						buttonClickSound.TimePosition = 0
					end
					buttonClickSound:Play()
					----

					dragDetector:SetAttribute('isDown', false)

					local conditionResult = if controller.ButtonInputConditionFunc and typeof(controller.ButtonInputConditionFunc.handleButtonClicked) == 'function' then controller.ButtonInputConditionFunc.handleButtonClicked(playerWhoDragged, false, b, controller) else nil
					local conditionMet = conditionResult == nil or conditionResult == true

					if buttonHoldConnections[b] then
						buttonHoldConnections[b]:Disconnect()
						buttonHoldConnections[b] = nil
					end
					if floorNumber then
						if (floorNumber == controller.StatValues.Floor and (controller.StatValues.MoveDirection == 0 or controller.StatValues.Leveling)) or controller.StatValues.FireService.FireServiceRecall or ((not controller.Queue.FindCarCall(floorNumber)) and (not conditionMet)) then
							if controller.StatValues.OutOfService and (not controller.Queue.FindCarCall(floorNumber) and (not (floorNumber == controller.StatValues.Floor and (controller.StatValues.MoveDirection == 0 or controller.StatValues.Leveling)))) then return end
							
							SetButton(controller.Car, true, b, config.color_config.buttons.car_buttons.floor_buttons, 'inactive', false)
						elseif controller.StatValues.OutOfService and (not controller.Queue.FindCarCall(floorNumber)) then
							SetButton(controller.Car, true, b, config.color_config.buttons.car_buttons.floor_buttons, 'inactive', false)
						end
					elseif string.match(b.Name, 'DoorOpen') or string.match(b.Name, 'Door_Open') then
						local side = string.split(b.Name, 'DoorOpen')[1] or string.split(b.Name, 'Door_Open')[1]
						if (string.match(side, '_')) then
							side = string.split(side, '_')[1]
						end
						if config.color_config.buttons.car_buttons.door_buttons.open.enable then
							SetButton(controller.Car, true, b, config.color_config.buttons.car_buttons.door_buttons.open, 'inactive', false)
						end
						if not conditionMet then return end
						
						local doorData = controller.door_data[side]
						if not doorData then return end
						
						if controller.StatValues.FireService.FireServicePhase2 and doorData.state == 'Opening' then
							doorData.close(false, true)
						end
					elseif string.match(b.Name, 'DoorClose') or string.match(b.Name, 'Door_Close') then
						local side = string.split(b.Name, 'DoorClose')[1] or string.split(b.Name, 'Door_Close')[1]
						if (string.match(side, '_')) then
							side = string.split(side, '_')[1]
						end
						if config.color_config.buttons.car_buttons.door_buttons.close.enable then
							SetButton(controller.Car, true, b, config.color_config.buttons.car_buttons.door_buttons.close, 'inactive', false)
						end
						if not conditionMet then return end
						
						local doorData = controller.door_data[side]
						if not doorData then return end
						
						if controller.StatValues.FireService.FireServicePhase2 and doorData.state == 'Closing' then
							doorData.Open()
						end
					elseif b.Name == 'Alarm' then
						SetButton(controller.Car, true, b, config.color_config.buttons.car_buttons.alarm_button, 'inactive', false)
						if not conditionMet then return end
						
						controller.AudioModule.Sounds.Alarm.Playing = false
						if controller.Config.sounds.alarm.release_sound.enable then
							controller.AudioModule.Sounds.Alarm_Release.Playing = true
						end
					end
				end)

			end
		end
		--

		-- Call buttons --
		for i, floor in controller.Floors do
			for i, v1 in floor.FloorModel:GetChildren() do
				if v1.Name ~= 'Call_Buttons' then continue end
				for i, b in v1:GetChildren() do
					if b.Name ~= 'Up' and b.Name ~= 'Down' then continue end
					local button = b:FindFirstChild('Button')
					if not button then continue end
					
					local behavior = controller.Config.color_config.buttons.call_buttons[string.lower(b.Name)] and controller.Config.color_config.buttons.call_buttons[string.lower(b.Name)].behavior

					if typeof(behavior) == 'table' and typeof(behavior.illumination_transition) == 'table' and behavior.illumination_transition.enable == true then
						for i, l in b:GetDescendants() do
							if not l:IsA('BasePart') or l.Name ~= 'Light' or l:FindFirstChild('Inactive') then continue end

							local activeLED = l:Clone()
							activeLED.Name = 'Inactive'
							inactiveLED.Reflectance -= 0.05
							activeLED.Transparency = 0
							controller.WeldingModule.WeldParts(activeLED, l, false, false)
							activeLED.Anchored = false
							activeLED.Parent = l
						end
					end

					local floorNumber = floor.FloorNumber
					local directionValue = b.Name == 'Up' and 1 or b.Name == 'Down' and -1 or nil

					local floor_instance = controller.FindFloor(floorNumber)

					local dragDetector = button:FindFirstChild('DragDetector') or Instance.new('DragDetector')
					dragDetector.MaxActivationDistance = 10
					dragDetector.DragStyle = Enum.DragDetectorDragStyle.Scriptable
					dragDetector.Parent = button

					--if not ControllerModule.controllers[controller.Id] then
					SetButton(b, false, b, config.color_config.buttons.call_buttons[string.lower(b.Name)], 'inactive', false)
					--end

					local doorDelayThread

					local buttonHoldConnection = nil

					local cfg = controller.Config.sounds.button_sounds.call_button_click
					local buttonClickSound: Sound = button:FindFirstChild('Button_Click') or controller.AudioModule.AddSoundFromConfig(button, 'Button_Click', {
						id = typeof(cfg) == 'table' and cfg.id or 0,
						volume = typeof(cfg) == 'table' and cfg.volume or 0,
						pitch = typeof(cfg) == 'table' and cfg.pitch or 0,
						looped = typeof(cfg) == 'table' and cfg.looped or false,
						minDistance = typeof(cfg) == 'table' and cfg.roll_off.min or 0,
						maxDistance = typeof(cfg) == 'table' and cfg.roll_off.max or 0,
						rollOffMode = typeof(cfg) == 'table' and cfg.roll_off.mode or Enum.RollOffMode.Linear,
					})
					if typeof(cfg.time_positioning) == 'table' and cfg.time_positioning.enable then
						if buttonClickSound:IsA('Sound') then
							buttonClickSound.PlaybackRegionsEnabled = true
						end
						buttonClickSound.TimePosition = 0
					end

					dragDetector.DragStart:Connect(function(playerWhoDragged: Player)

						if playerWhoDragged and playerWhoDragged:GetAttribute('clickDebounce') then return end
						
						if playerWhoDragged then
							playerWhoDragged:SetAttribute('clickDebounce', true)
							task.delay(.05, function()
								playerWhoDragged:SetAttribute('clickDebounce', false)
							end)
						end

						controller.API:Fire('on_button_pressed', { button = b })

						-- Playback Regions --
						if typeof(cfg.time_positioning) == 'table' and ((buttonClickSound:IsA('Sound') and buttonClickSound.PlaybackRegionsEnabled) or buttonClickSound:IsA('AudioPlayer')) then
							buttonClickSound.PlaybackRegion = NumberRange.new(cfg.time_positioning.press.min, cfg.time_positioning.press.max)
							buttonClickSound.TimePosition = buttonClickSound.PlaybackRegion.Min
						else
							buttonClickSound.TimePosition = 0
						end
						buttonClickSound:Play()
						----

						if floorNumber and directionValue then
							for i, v in floor.FloorModel:GetChildren() do
								if v.Name ~= 'Call_Buttons' then continue end

								SetButton(v, true, b, config.color_config.buttons.call_buttons[string.lower(b.Name)], 'active', true)
							end
							if controller.StatValues.OutOfService or controller.StatValues.FireService.FireServiceRecall then return end

							if ((floorNumber == controller.StatValues.Floor and controller.StatValues.MoveDirection == 0 and (controller.StatValues.QueueDirection == 0 or controller.StatValues.QueueDirection == directionValue))) then
								if controller.StatValues.QueueDirection == 0 then
									controller.StatValues.QueueDirection = directionValue
									controller.UpdateStatValues()
								end

								-- Fire lantern signal
								controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_on_exterior_wake_call.interior, controller.Config.color_config.lanterns.interior, function()
									return true
								end, controller.Car.Lantern_API)

								controller.InvokeLanternAPIWithCheckAsync(controller.Config.lantern_controls.activate_on_exterior_wake_call.exterior, controller.Config.color_config.lanterns.exterior, function()
									return true
								end, floor_instance.FloorModel.Lantern_API)
								--

								if not buttonHoldConnection or not buttonHoldConnection.Connected then
									buttonHoldConnection = controller.Step:Connect(function()
										for i, v in controller.door_data do
											if v.state ~= 'Open' then continue end

											v.TimerStart = os.clock()
										end
									end)
								end

								controller.API:Fire('door_signal', {request = 'open', sides = 'all', open_time = controller.Config.doors.door_timers.open_by_call, hall_call = true})
								return
							end
							controller.Queue.AddHallCall(floorNumber, directionValue)
						end
					end)
					dragDetector.DragEnd:Connect(function(playerWhoDragged: Player)

						controller.API:Fire('on_button_released', { button = b })
						-- Playback Regions --
						if typeof(cfg.time_positioning) == 'table' and ((buttonClickSound:IsA('Sound') and buttonClickSound.PlaybackRegionsEnabled) or buttonClickSound:IsA('AudioPlayer')) then
							buttonClickSound.PlaybackRegion = NumberRange.new(cfg.time_positioning.release.min, cfg.time_positioning.release.max)
							buttonClickSound.TimePosition = buttonClickSound.PlaybackRegion.Min
							buttonClickSound:Play()
						else
							buttonClickSound.TimePosition = 0
						end
						----

						if not ((floorNumber == controller.StatValues.Floor and controller.StatValues.MoveDirection == 0 and (controller.StatValues.QueueDirection == 0 or controller.StatValues.QueueDirection == directionValue)) or controller.StatValues.OutOfService or controller.StatValues.FireService.FireServiceRecall or controller.StatValues.FireService.FireServicePhase2) then return end

						if buttonHoldConnection and buttonHoldConnection.Connected then
							buttonHoldConnection:Disconnect()
						end
						buttonHoldConnection = nil
						for i, v in floor.FloorModel:GetChildren() do
							if v.Name ~= 'Call_Buttons' then continue end
							
							SetButton(v, true, b, config.color_config.buttons.call_buttons[string.lower(b.Name)], 'inactive', false)
						end
					end)

				end
			end
		end

	end

	return data

end

return ButtonHandlerClass