local buttonHandlerClass = {}
buttonHandlerClass.className = 'buttonHandlerClass'

function buttonHandlerClass.new(source, config, controller)

	local data = setmetatable({}, buttonHandlerClass)

	data.controller = controller

	function data.setup()

		local function setButton(start: Instance, includeAllAlikes: boolean, button: Instance, config: any)
			if includeAllAlikes == true then
				for i, v in (start or button.Parent.Parent):GetDescendants() do
					if v.Name ~= button.Name then continue end
					for i, l in v:GetDescendants() do
						if l.Name ~= 'Light' or (not l:IsA('BasePart')) then continue end
						l.Color, l.Material = config.color, config.material
					end
				end
			else
				for i, l in button:GetDescendants() do
					if l.Name ~= 'Light' or (not l:IsA('BasePart')) then continue end
					l.Color, l.Material = config.color, config.material
				end
			end
		end

		local floorButtons = {}

		controller.api.Event:Connect(function(protocol, params)
			if protocol == 'on_car_call_removed' then
				local call = params.call
				for i, v in floorButtons do
					if v.Name ~= `Floor_{call}` then continue end
					setButton(controller.car, false, v, config.color_config.buttons.car_buttons.floor_buttons.inactive)
				end
			elseif protocol == 'on_hall_call_removed' then
				local call = params.call
				for i, v in controller.floors do
					if v.floor_number ~= call then continue end
					for i, c in v.floor_model:GetChildren() do
						if c.Name ~= 'Call_Buttons' then continue end
						for i, b in c:GetChildren() do
							if b.Name ~= 'Up' and b.Name ~= 'Down' then continue end
							local directionValue = b.Name == 'Up' and 1 or b.Name == 'Down' and -1
							if (not params.directions[tostring(directionValue)]) or directionValue ~= controller.stat_values.queue_direction then continue end
							setButton(b, false, b, config.color_config.buttons.call_buttons[string.lower(b.Name)].inactive)
						end
					end
				end
			end
		end)

		-- Car buttons --
		for i, v in controller.car:GetChildren() do
			if v.Name ~= 'Buttons' then continue end
			for i, b in v:GetChildren() do
				local button = b:FindFirstChild('Button')
				if not button then continue end

				local floorNumber = tonumber(string.split(b.Name, 'Floor')[2]) or tonumber(string.split(b.Name, '_')[2])
				local side = string.split(b.Name, '_')[3]
				floorButtons[b] = b

				local dragDetector = Instance.new('DragDetector')
				dragDetector.MaxActivationDistance = 10
				dragDetector.DragStyle = Enum.DragDetectorDragStyle.Scriptable
				dragDetector.Parent = button

				if floorNumber then
					setButton(b, false, b, config.color_config.buttons.car_buttons.floor_buttons.inactive)
				elseif string.match(b.Name, 'DoorOpen') or string.match(b.Name, 'Door_Open') then
					setButton(b, false, b, config.color_config.buttons.car_buttons.door_buttons.open.inactive)
				elseif string.match(b.Name, 'DoorClose') or string.match(b.Name, 'Door_Close') then
					setButton(b, false, b, config.color_config.buttons.car_buttons.door_buttons.close.inactive)
				elseif b.Name == 'Alarm' then
					setButton(b, false, b, config.color_config.buttons.car_buttons.alarm_button.inactive)
				end

				local lanternThread = nil
				local buttonHoldConnections = {}
				local controller = controller

				local cfg = controller.config.sounds.button_sounds.car_button_click
				local buttonClickSound: Sound = controller.audio_module.addSoundFromConfig(button, 'Button_Click', {
					id = cfg.id,
					volume = cfg.volume,
					pitch = cfg.pitch,
					looped = config.looped,
					minDistance = cfg.roll_off.min,
					maxDistance = cfg.roll_off.max,
					rollOffMode = cfg.roll_off.mode,
				})
				if cfg.time_positioning.enable then
					buttonClickSound.PlaybackRegionsEnabled = true
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

					controller.api:Fire('on_button_pressed', { button = b })
					-- Playback Regions --
					if buttonClickSound.PlaybackRegionsEnabled then
						buttonClickSound.PlaybackRegion = NumberRange.new(cfg.time_positioning.press.min, cfg.time_positioning.press.max)
						buttonClickSound.TimePosition = buttonClickSound.PlaybackRegion.Min
					else
						buttonClickSound.TimePosition = 0
					end
					buttonClickSound.Playing = true
					----

					dragDetector:SetAttribute('isDown', true)
					local conditionResult = if controller.button_input_conditional and typeof(controller.button_input_conditional.handleButtonClicked) == 'function' then controller.button_input_conditional.handleButtonClicked(playerWhoDragged, true, b, controller) else nil
					local conditionMet = conditionResult == nil or conditionResult == true

					if floorNumber then
						setButton(controller.car, true, b, config.color_config.buttons.car_buttons.floor_buttons.active)

						if not conditionMet then return end
						
						local side = string.split(v.Name, `Floor_{floorNumber}_`)[1] and string.split(v.Name, `Floor_{floorNumber}_`)[2]
						print(side)

						if controller.stat_values.out_of_service == true or (controller.stat_values.fire_service == true and controller.stat_values.phase_2 == false) then return end
						if floorNumber == controller.stat_values.floor and controller.stat_values.move_direction == 0 then
							if config.lantern_controls.activate_when_same_button_pressed.interior.enable and controller.door_data.Front.state ~= 'Closed' then
								task.spawn(function()
									if lanternThread then return end
									lanternThread = task.delay((controller.door_data.Front.state ~= 'Open' and config.doors.open_speed or 0)+config.lantern_controls.activate_when_same_button_pressed.interior.delay, function()
										controller.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = config.color_config.lanterns.interior })
										lanternThread = nil
									end)
								end)
							end
							if (not buttonHoldConnections[b]) or (not buttonHoldConnections[b].Connected) then
								buttonHoldConnections[b] = controller.step:Connect(function()
									for i, v in controller.door_data do
										if v.state ~= 'Open' then continue end
										v.timer_start = os.clock()
									end
								end)
							end
							return controller.api:Fire('door_signal', {request = 'open', sides = 'all', open_time = config.doors.door_timers.open_on_stop})
						end
						local queue_dir = controller.stat_values.queue_direction
						controller.queue.add_car_call(floorNumber, { side = side })
						if queue_dir ~= 0 or controller.stat_values.queue_direction == 0 or controller.check_all_doors('closed_point') then return end

						local floor_instance = controller.find_floor(controller.stat_values.floor)
						if controller.config.lantern_controls.activate_on_call_entry then
							controller.check_lantern_and_fire(controller.config.lantern_controls.activate_on_call_entry.exterior, controller.config.color_config.lanterns.exterior, function()
								return true
							end, floor_instance.floor_model.Lantern_API)
						end
						if controller.config.lantern_controls.activate_on_call_entry then
							controller.check_lantern_and_fire(controller.config.lantern_controls.activate_on_call_entry.interior, controller.config.color_config.lanterns.interior, function()
								return true
							end, controller.car.Lantern_API)
						end
					elseif string.match(b.Name, 'DoorOpen') or string.match(b.Name, 'Door_Open') then
						local side = string.split(b.Name, 'DoorOpen')[1] or string.split(b.Name, 'Door_Open')[1]
						if (string.match(side, '_')) then
							side = string.split(side, '_')[1]
						end
						if config.color_config.buttons.car_buttons.door_buttons.open.enable then
							setButton(controller.car, true, b, config.color_config.buttons.car_buttons.door_buttons.open.active)
						end
						if not conditionMet then return end
						controller.door_data[side].open(controller.config.doors.door_timers.open_no_call)
					elseif string.match(b.Name, 'DoorClose') or string.match(b.Name, 'Door_Close') then
						local side = string.split(b.Name, 'DoorClose')[1] or string.split(b.Name, 'Door_Close')[1]
						if (string.match(side, '_')) then
							side = string.split(side, '_')[1]
						end
						if config.color_config.buttons.car_buttons.door_buttons.close.enable then
							setButton(controller.car, true, b, config.color_config.buttons.car_buttons.door_buttons.close.active)
						end
						if (controller.stat_values.fire_service == true and controller.stat_values.phase_2 == false) then return end
						if not conditionMet then return end
						controller.door_data[side].close(false, controller.stat_values.phase_2)
					elseif b.Name == 'Alarm' then
						setButton(controller.car, true, b, config.color_config.buttons.car_buttons.alarm_button.active)
						if not conditionMet then return end
						controller.audio_module.sounds.Alarm.Playing = true
					end
				end)
				dragDetector.DragEnd:Connect(function(playerWhoDragged: Player)

					controller.api:Fire('on_button_released', { button = b })
					-- Playback Regions --
					if buttonClickSound.PlaybackRegionsEnabled then
						buttonClickSound.PlaybackRegion = NumberRange.new(cfg.time_positioning.release.min, cfg.time_positioning.release.max)
						buttonClickSound.TimePosition = buttonClickSound.PlaybackRegion.Min
					else
						buttonClickSound.TimePosition = 0
					end
					buttonClickSound.Playing = true
					----

					dragDetector:SetAttribute('isDown', false)

					local conditionResult = if controller.button_input_conditional and typeof(controller.button_input_conditional.handleButtonClicked) == 'function' then controller.button_input_conditional.handleButtonClicked(playerWhoDragged, false, b, controller) else nil
					local conditionMet = conditionResult == nil or conditionResult == true

					if buttonHoldConnections[b] then
						buttonHoldConnections[b]:Disconnect()
						buttonHoldConnections[b] = nil
					end
					if floorNumber then
						if (floorNumber == controller.stat_values.floor and (controller.stat_values.move_direction == 0 or controller.stat_values.leveling)) or (controller.stat_values.fire_service == true and controller.stat_values.phase_2 == false) or ((not controller.queue.find_car_call(floorNumber)) and (not conditionMet)) then
							if controller.stat_values.out_of_service == true and (not controller.queue.find_car_call(floorNumber)) then return end
							setButton(controller.car, true, b, config.color_config.buttons.car_buttons.floor_buttons.inactive)
						end
					elseif string.match(b.Name, 'DoorOpen') or string.match(b.Name, 'Door_Open') then
						local side = string.split(b.Name, 'DoorOpen')[1] or string.split(b.Name, 'Door_Open')[1]
						if (string.match(side, '_')) then
							side = string.split(side, '_')[1]
						end
						if config.color_config.buttons.car_buttons.door_buttons.open.enable then
							setButton(controller.car, true, b, config.color_config.buttons.car_buttons.door_buttons.open.inactive)
						end
						if not conditionMet then return end
						local doorData = controller.door_data[side]
						if not doorData then return end
						if controller.stat_values.phase_2 and doorData.state == 'Opening' then
							doorData.close(false, true)
						end
					elseif string.match(b.Name, 'DoorClose') or string.match(b.Name, 'Door_Close') then
						local side = string.split(b.Name, 'DoorClose')[1] or string.split(b.Name, 'Door_Close')[1]
						if (string.match(side, '_')) then
							side = string.split(side, '_')[1]
						end
						if config.color_config.buttons.car_buttons.door_buttons.close.enable then
							setButton(controller.car, true, b, config.color_config.buttons.car_buttons.door_buttons.close.inactive)
						end
						if not conditionMet then return end
						local doorData = controller.door_data[side]
						if not doorData then return end
						if controller.stat_values.phase_2 and doorData.state == 'Closing' then
							doorData.open()
						end
					elseif b.Name == 'Alarm' then
						setButton(controller.car, true, b, config.color_config.buttons.car_buttons.alarm_button.inactive)
						if not conditionMet then return end
						controller.audio_module.sounds.Alarm.Playing = false
						if controller.config.sounds.alarm.release_sound.enable then
							controller.audio_module.sounds.Alarm_Release.Playing = true
						end
					end
				end)

			end
		end
		--

		-- Call buttons --
		for i, floor in controller.floors do
			for i, v1 in floor.floor_model:GetChildren() do
				if v1.Name ~= 'Call_Buttons' then continue end
				for i, b in v1:GetChildren() do
					if b.Name ~= 'Up' and b.Name ~= 'Down' then continue end
					local button = b:FindFirstChild('Button')
					if not button then continue end

					local floorNumber = floor.floor_number
					local directionValue = b.Name == 'Up' and 1 or b.Name == 'Down' and -1 or nil

					local floor_instance = controller.find_floor(floorNumber)

					local dragDetector = Instance.new('DragDetector')
					dragDetector.MaxActivationDistance = 10
					dragDetector.DragStyle = Enum.DragDetectorDragStyle.Scriptable
					dragDetector.Parent = button

					setButton(b, false, b, config.color_config.buttons.call_buttons[string.lower(b.Name)].inactive)

					local doorDelayThread

					local buttonHoldConnection = nil

					local cfg = controller.config.sounds.button_sounds.call_button_click
					local buttonClickSound: Sound = controller.audio_module.addSoundFromConfig(button, 'Button_Click', {
						id = typeof(cfg) == 'table' and cfg.id or 0,
						volume = typeof(cfg) == 'table' and cfg.volume or 0,
						pitch = typeof(cfg) == 'table' and cfg.pitch or 0,
						looped = typeof(cfg) == 'table' and cfg.looped or false,
						minDistance = typeof(cfg) == 'table' and cfg.roll_off.min or 0,
						maxDistance = typeof(cfg) == 'table' and cfg.roll_off.max or 0,
						rollOffMode = typeof(cfg) == 'table' and cfg.roll_off.mode or Enum.RollOffMode.Linear,
					})
					if typeof(cfg.time_positioning) == 'table' and cfg.time_positioning.enable then
						buttonClickSound.PlaybackRegionsEnabled = true
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

						-- Playback Regions --
						if buttonClickSound.PlaybackRegionsEnabled then
							buttonClickSound.PlaybackRegion = NumberRange.new(cfg.time_positioning.press.min, cfg.time_positioning.press.max)
							buttonClickSound.TimePosition = buttonClickSound.PlaybackRegion.Min
						else
							buttonClickSound.TimePosition = 0
						end
						buttonClickSound.Playing = true
						----

						if floorNumber and directionValue then
							for i, v in floor.floor_model:GetChildren() do
								if v.Name ~= 'Call_Buttons' then continue end

								setButton(v, true, b, config.color_config.buttons.call_buttons[string.lower(b.Name)].active)
							end
							if controller.stat_values.out_of_service or controller.stat_values.fire_service then return end

							if ((floorNumber == controller.stat_values.floor and controller.stat_values.move_direction == 0 and (controller.stat_values.queue_direction == 0 or controller.stat_values.queue_direction == directionValue))) then
								if controller.stat_values.queue_direction == 0 then
									controller.stat_values.queue_direction = directionValue
									controller.update_stat_values()
								end

								-- Fire lantern signal
								controller.check_lantern_and_fire(controller.config.lantern_controls.activate_on_exterior_wake_call.interior, controller.config.color_config.lanterns.interior, function()
									return true
								end, controller.car.Lantern_API)

								controller.check_lantern_and_fire(controller.config.lantern_controls.activate_on_exterior_wake_call.exterior, controller.config.color_config.lanterns.exterior, function()
									return true
								end, floor_instance.floor_model.Lantern_API)
								--

								if not buttonHoldConnection or not buttonHoldConnection.Connected then
									buttonHoldConnection = controller.step:Connect(function()
										for i, v in controller.door_data do
											if v.state ~= 'Open' then continue end

											v.timer_start = os.clock()
										end
									end)
								end

								controller.api:Fire('door_signal', {request = 'open', sides = 'all', open_time = controller.config.doors.door_timers.open_by_call, hall_call = true})
								return
							end
							controller.queue.add_hall_call(floorNumber, directionValue)
						end
					end)
					dragDetector.DragEnd:Connect(function(playerWhoDragged: Player)

						-- Playback Regions --
						if buttonClickSound.PlaybackRegionsEnabled then
							buttonClickSound.PlaybackRegion = NumberRange.new(cfg.time_positioning.release.min, cfg.time_positioning.release.max)
							buttonClickSound.TimePosition = buttonClickSound.PlaybackRegion.Min
							buttonClickSound.Playing = true
						else
							buttonClickSound.TimePosition = 0
						end
						----

						if not ((floorNumber == controller.stat_values.floor and controller.stat_values.move_direction == 0 and (controller.stat_values.queue_direction == 0 or controller.stat_values.queue_direction == directionValue)) or controller.stat_values.out_of_service == true) then return end

						if buttonHoldConnection and buttonHoldConnection.Connected then
							buttonHoldConnection:Disconnect()
						end
						buttonHoldConnection = nil
						for i, v in floor.floor_model:GetChildren() do
							if v.Name ~= 'Call_Buttons' then continue end
							setButton(v, true, b, config.color_config.buttons.call_buttons[string.lower(b.Name)].inactive)
						end
					end)

				end
			end
		end

	end

	return data

end

return buttonHandlerClass