local setupClass = {}
setupClass.className = 'setupClass'

local data_list = {}

function setupClass.new(source, config, meta)

	local dataExists = data_list[source:GetAttribute('setup_id')]
	if dataExists then
		warn(`MODULUX Setup : Data already exists for ID {source:GetAttribute('setup_id')}`)
		return dataExists
	end
	
	local id = math.random(0, 10000000)
	source:SetAttribute('setup_id', id)
	
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

	local data = setmetatable(setupClass, {})

	data.buttons = {}
	data.id = id

	-- Modules --
	data.allocator_module = require(script.Parent.Allocator)
	data.audio_module = require(script.Parent.Audio)
	----

	-- Call buttons --

	local callButtons = source:WaitForChild('Call_Buttons', math.huge)
	local elevators = source:WaitForChild('Elevators', math.huge)

	for i, floor in callButtons:GetChildren() do
		for i, b in floor:GetChildren() do
			if b.Name ~= 'Up' and b.Name ~= 'Down' then continue end
			local button = b:FindFirstChild('Button')
			if not button then continue end

			local floorNumber = tonumber(string.split(floor.Name, '_')[2])
			local directionValue = b.Name == 'Up' and 1 or b.Name == 'Down' and -1 or nil

			local dragDetector = Instance.new('DragDetector')
			dragDetector.MaxActivationDistance = 10
			dragDetector.DragStyle = Enum.DragDetectorDragStyle.Scriptable
			dragDetector.Parent = button

			setButton(b, false, b, config.color_config[string.lower(b.Name)].inactive)

			local lanternThread = nil
			local carLanternsThread = nil
			local buttonHoldConnection = nil

			local cfg = config.sounds.button_click
			local buttonClickSound: Sound = data.audio_module.addSoundFromConfig(button, 'Button_Click', {
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
			
			local elevator, elevController
			local arriveConnection: RBXScriptConnection = nil

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
					setButton(floor, true, b, config.color_config[string.lower(b.Name)].active)
					elevator = data.allocator_module.allocateElevator(floorNumber, directionValue, elevators:GetChildren())
					if not elevator then return end
					elevController = require(script:FindFirstAncestor('Group_Call').Parent.Parent).ActiveControllers[tostring(elevator:GetAttribute('elevatorID'))].get_controller(elevator:GetAttribute('elevatorID'))
					local floor_instance = elevController.find_floor(floorNumber)
					if not floor_instance then return end
					
					if (not arriveConnection) or (not arriveConnection.Connected) then
						arriveConnection = elevator.API.Event:Connect(function(protocol, params)
							if protocol == 'on_hall_call_removed' then
								if (not elevController) or params.call ~= floorNumber or (not params.directions[tostring(directionValue)]) or directionValue ~= elevController.stat_values.queue_direction then return end
								arriveConnection:Disconnect()
								arriveConnection = nil
								setButton(floor, true, b, config.color_config[string.lower(b.Name)].inactive)
							end
						end)
					end
					
					if floorNumber == elevController.stat_values.floor and elevController.stat_values.move_direction == 0 and (elevController.stat_values.queue_direction == 0 or elevController.stat_values.queue_direction == directionValue) then
						if elevController.stat_values.queue_direction == 0 then
							elevController.stat_values.queue_direction = directionValue
							elevController.update_stat_values()
						end
						task.spawn(function()
							if elevController.door_data.Front.state ~= 'Closed' then
								task.spawn(function()
									if carLanternsThread or (not elevController.config.lantern_controls.activate_when_same_button_pressed.interior.enable) or elevController.door_data.Front.state == 'Closed' then return end
									carLanternsThread = task.delay((elevController.door_data.Front.state ~= 'Open' and elevController.config.doors.open_speed or 0)+elevController.config.lantern_controls.activate_when_same_button_pressed.interior.delay, function()
										elevController.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = elevController.stat_values.queue_direction, config = elevController.config.color_config.lanterns.interior })
										carLanternsThread = nil
									end)
								end)
								if not elevController.config.lantern_controls.activate_on_exterior_wake_call.exterior.enable then return end
								task.spawn(function()
									if lanternThread then return end
									lanternThread = task.delay((elevController.door_data.Front.state ~= 'Open' and elevController.config.doors.open_speed or 0)+1, function()
										floor_instance.floor_model.Lantern_API:Fire('set_lantern', { state = 'active', direction = elevController.stat_values.queue_direction, config = elevController.config.color_config.lanterns.exterior })
										lanternThread = nil
									end)
								end)
							else
								if elevController.config.lantern_controls.activate_on_exterior_wake_call.exterior.enable then
									floor_instance.floor_model.Lantern_API:Fire('set_lantern', { state = 'active', direction = elevController.stat_values.queue_direction, config = elevController.config.color_config.lanterns.exterior })
								end
								if not elevController.config.lantern_controls.activate_after_door_open.interior.enable then return end
								task.delay(elevController.config.doors.open_speed+elevController.config.doors.open_delay+elevController.config.lantern_controls.activate_after_door_open.interior.delay, function()
									elevController.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = elevController.stat_values.queue_direction, config = elevController.config.color_config.lanterns.interior })
								end)
							end
						end)
						task.spawn(function()
							if buttonHoldConnection and buttonHoldConnection.Connected then return end
							buttonHoldConnection = elevController.step:Connect(function()
								for i, v in elevController.door_data do
									if v.state ~= 'Open' then continue end
									v.timer_start = os.clock()
								end
							end)
						end)
						elevController.api:Fire('door_signal', {request = 'open', sides = 'all', open_time = elevController.config.doors.door_timers.open_by_call})
						return
					end
					elevController.queue.add_hall_call(floorNumber, directionValue)
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

				if not (floorNumber == elevController.stat_values.floor and elevController.stat_values.move_direction == 0 and (elevController.stat_values.queue_direction == 0 or elevController.stat_values.queue_direction == directionValue)) then return end
				task.spawn(function()
					if (not buttonHoldConnection) or (not buttonHoldConnection.Connected) then return end
					buttonHoldConnection:Disconnect()
					buttonHoldConnection = nil
				end)
				setButton(floor, true, b, config.color_config[string.lower(b.Name)].inactive)
			end)

		end
	end

	local dataID = math.random(0,10000000)
	source:SetAttribute('setup_id', dataID)
	data_list[tostring(dataID)] = data
	data.data_id = dataID

	return data

end

return setupClass