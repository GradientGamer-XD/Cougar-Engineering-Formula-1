local buttonHandlerClass = {}
buttonHandlerClass.className = 'buttonHandlerClass'

function buttonHandlerClass.new(source, config, controller)
	
	local data = setmetatable({}, buttonHandlerClass)
	
	data.controller = controller
	
	warn(`Setting up button for controller {controller.id}`)
	
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
				local elevCtrl = controller

				local cfg = controller.config.sounds.button_sounds.car_button_click
				local buttonClickSound: Sound = elevCtrl.audio_module.addSoundFromConfig(button, 'Button_Click', {
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
					if floorNumber then
						setButton(elevCtrl.car, true, b, config.color_config.buttons.car_buttons.floor_buttons.active)
						if controller.stat_values.out_of_service == true then return end
						if floorNumber == elevCtrl.stat_values.floor and elevCtrl.stat_values.move_direction == 0 then
							if config.lantern_controls.activate_when_same_button_pressed.interior.enable and elevCtrl.door_data.Front.state ~= 'Closed' then
								task.spawn(function()
									if lanternThread then return end
									lanternThread = task.delay((elevCtrl.door_data.Front.state ~= 'Open' and config.doors.open_speed or 0)+config.lantern_controls.activate_when_same_button_pressed.interior.delay, function()
										elevCtrl.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = elevCtrl.stat_values.queue_direction, config = config.color_config.lanterns.interior })
										lanternThread = nil
									end)
								end)
							end
							if (not buttonHoldConnections[b]) or (not buttonHoldConnections[b].Connected) then
								buttonHoldConnections[b] = elevCtrl.step:Connect(function()
									for i, v in elevCtrl.door_data do
										if v.state ~= 'Open' then continue end
										v.timer_start = os.clock()
									end
								end)
							end
							return elevCtrl.api:Fire('door_signal', {request = 'open', sides = 'all', open_time = config.doors.door_timers.open_on_stop})
						end
						elevCtrl.queue.add_car_call(floorNumber)
					elseif string.match(b.Name, 'DoorOpen') or string.match(b.Name, 'Door_Open') then
						local side = string.split(b.Name, 'DoorOpen')[1] or string.split(b.Name, 'Door_Open')[1]
						if (string.match(side, '_')) then
							side = string.split(side, '_')[1]
						end
						if config.color_config.buttons.car_buttons.door_buttons.open.enable then
							setButton(elevCtrl.car, true, b, config.color_config.buttons.car_buttons.door_buttons.open.active)
						end
						elevCtrl.door_data[side].open(elevCtrl.config.doors.door_timers.open_no_call)
					elseif string.match(b.Name, 'DoorClose') or string.match(b.Name, 'Door_Close') then
						local side = string.split(b.Name, 'DoorClose')[1] or string.split(b.Name, 'Door_Close')[1]
						if (string.match(side, '_')) then
							side = string.split(side, '_')[1]
						end
						if config.color_config.buttons.car_buttons.door_buttons.close.enable then
							setButton(elevCtrl.car, true, b, config.color_config.buttons.car_buttons.door_buttons.close.active)
						end
						elevCtrl.door_data[side].close()
					elseif b.Name == 'Alarm' then
						setButton(elevCtrl.car, true, b, config.color_config.buttons.car_buttons.alarm_button.active)
						elevCtrl.audio_module.sounds.Alarm.Playing = true
					end
				end)
				dragDetector.DragEnd:Connect(function(playerWhoDragged: Player)

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
					if buttonHoldConnections[b] then
						buttonHoldConnections[b]:Disconnect()
						buttonHoldConnections[b] = nil
					end
					if floorNumber then
						if floorNumber == elevCtrl.stat_values.floor and (elevCtrl.stat_values.move_direction == 0 or elevCtrl.stat_values.leveling) then
							if controller.stat_values.out_of_service == true and (not controller.queue.find_car_call(floorNumber)) then return end
							setButton(elevCtrl.car, true, b, config.color_config.buttons.car_buttons.floor_buttons.inactive)
						end
					elseif string.match(b.Name, 'DoorOpen') or string.match(b.Name, 'Door_Open') then
						if config.color_config.buttons.car_buttons.door_buttons.open.enable then
							setButton(elevCtrl.car, true, b, config.color_config.buttons.car_buttons.door_buttons.open.inactive)
						end
					elseif string.match(b.Name, 'DoorClose') or string.match(b.Name, 'Door_Close') then
						if config.color_config.buttons.car_buttons.door_buttons.close.enable then
							setButton(elevCtrl.car, true, b, config.color_config.buttons.car_buttons.door_buttons.close.inactive)
						end
					elseif b.Name == 'Alarm' then
						setButton(elevCtrl.car, true, b, config.color_config.buttons.car_buttons.alarm_button.inactive)
						elevCtrl.audio_module.sounds.Alarm.Playing = false
						if elevCtrl.config.sounds.alarm.release_sound.enable then
							elevCtrl.audio_module.sounds.Alarm_Release.Playing = true
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

					local dragDetector = Instance.new('DragDetector')
					dragDetector.MaxActivationDistance = 10
					dragDetector.DragStyle = Enum.DragDetectorDragStyle.Scriptable
					dragDetector.Parent = button

					setButton(b, false, b, config.color_config.buttons.call_buttons[string.lower(b.Name)].inactive)

					local lanternThread = nil
					local carLanternsThread = nil
					local buttonHoldConnection = nil
					local elevCtrl = controller

					local cfg = elevCtrl.config.sounds.button_sounds.call_button_click
					local buttonClickSound: Sound = elevCtrl.audio_module.addSoundFromConfig(button, 'Button_Click', {
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
							if floorNumber == elevCtrl.stat_values.floor and elevCtrl.stat_values.move_direction == 0 and (elevCtrl.stat_values.queue_direction == 0 or elevCtrl.stat_values.queue_direction == directionValue) then
								if elevCtrl.stat_values.queue_direction == 0 then
									elevCtrl.stat_values.queue_direction = directionValue
									elevCtrl.update_stat_values()
								end
								task.spawn(function()
									if elevCtrl.door_data.Front.state ~= 'Closed' then
										task.spawn(function()
											if carLanternsThread or (not config.lantern_controls.activate_when_same_button_pressed.interior.enable) or elevCtrl.door_data.Front.state == 'Closed' then return end
											carLanternsThread = task.delay((elevCtrl.door_data.Front.state ~= 'Open' and config.doors.open_speed or 0)+config.lantern_controls.activate_when_same_button_pressed.interior.delay, function()
												elevCtrl.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = elevCtrl.stat_values.queue_direction, config = config.color_config.lanterns.interior })
												carLanternsThread = nil
											end)
										end)
										if not config.lantern_controls.activate_on_exterior_wake_call.exterior.enable then return end
										task.spawn(function()
											if lanternThread then return end
											lanternThread = task.delay((elevCtrl.door_data.Front.state ~= 'Open' and config.doors.open_speed or 0)+1, function()
												floor.floor_model.Lantern_API:Fire('set_lantern', { state = 'active', direction = elevCtrl.stat_values.queue_direction, config = config.color_config.lanterns.exterior })
												lanternThread = nil
											end)
										end)
									else
										if config.lantern_controls.activate_on_exterior_wake_call.exterior.enable then
											floor.floor_model.Lantern_API:Fire('set_lantern', { state = 'active', direction = elevCtrl.stat_values.queue_direction, config = config.color_config.lanterns.exterior })
										end
										if not config.lantern_controls.activate_after_door_open.interior.enable then return end
										task.delay(config.doors.open_speed+config.doors.open_delay+config.lantern_controls.activate_after_door_open.interior.delay, function()
											elevCtrl.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = elevCtrl.stat_values.queue_direction, config = config.color_config.lanterns.interior })
										end)
									end
								end)
								task.spawn(function()
									if buttonHoldConnection and buttonHoldConnection.Connected then return end
									buttonHoldConnection = elevCtrl.step:Connect(function()
										for i, v in elevCtrl.door_data do
											if v.state ~= 'Open' then continue end
											v.timer_start = os.clock()
										end
									end)
								end)
								elevCtrl.api:Fire('door_signal', {request = 'open', sides = 'all', open_time = elevCtrl.config.doors.door_timers.open_by_call})
								return
							end
							elevCtrl.queue.add_hall_call(floorNumber, directionValue)
						end
					end)
					dragDetector.DragEnd:Connect(function(playerWhoDragged: Player)

						-- Playback Regions --
						if buttonClickSound.PlaybackRegionsEnabled then
							buttonClickSound.PlaybackRegion = NumberRange.new(cfg.time_positioning.release.min, cfg.time_positioning.release.max)
							buttonClickSound.TimePosition = buttonClickSound.PlaybackRegion.Min
						else
							buttonClickSound.TimePosition = 0
						end
						buttonClickSound.Playing = true
						----

						if not (floorNumber == elevCtrl.stat_values.floor and elevCtrl.stat_values.move_direction == 0 and (elevCtrl.stat_values.queue_direction == 0 or elevCtrl.stat_values.queue_direction == directionValue)) then return end
						task.spawn(function()
							if (not buttonHoldConnection) or (not buttonHoldConnection.Connected) then return end
							buttonHoldConnection:Disconnect()
							buttonHoldConnection = nil
						end)
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