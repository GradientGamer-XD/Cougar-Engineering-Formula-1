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
	
	warn(`MODULUX Group Call- Initiating group calling {meta.version} in {meta.branch} `)

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

			local interiorLanternThread = nil
			local exteriorLanternThread = nil

			local carLanternsThread = nil
			local callCarLanternsThread = nil

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
			local stopConnections = {}
			local maxRetries = 30
			local retries = 0
			local checking = false
			
			local function reset()
				elevator = nil
				elevController = nil
				checking = false
				for i, v in stopConnections do
					v:Disconnect()
				end
				stopConnections = {}
				setButton(floor, true, b, config.color_config[string.lower(b.Name)].inactive)
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
					setButton(floor, true, b, config.color_config[string.lower(b.Name)].active)
					elevator = data.allocator_module.allocateElevator(floorNumber, directionValue, elevators:GetChildren())
					elevController = elevator and require(script:FindFirstAncestor('Group_Call').Parent.Parent).ActiveControllers[tostring(elevator:GetAttribute('elevatorID'))].get_controller(elevator:GetAttribute('elevatorID'))
					if checking then return end
					
					-- Handle retry limit timeout
					if (not elevController) and (not checking) then
						retries = 0
						checking = true
						while not elevController do
							warn(`No elevator allocated, checking...`)
							retries += 1
							elevator = data.allocator_module.allocateElevator(floorNumber, directionValue, elevators:GetChildren())
							elevController = elevator and require(script:FindFirstAncestor('Group_Call').Parent.Parent).ActiveControllers[tostring(elevator:GetAttribute('elevatorID'))].get_controller(elevator:GetAttribute('elevatorID'))
							task.wait(1)
							if retries == (typeof(config.max_retries) == 'number' and config.max_retries or 60) then
								warn('Maximum call retry limit reached, canceling request.')
								return reset()
							end
						end
					end
					
					local floor_instance = elevController.find_floor(floorNumber)
					if not floor_instance then return end

					local isOnFloor = (elevController and (floorNumber == elevController.stat_values.floor and elevController.stat_values.move_direction == 0 and (elevController.stat_values.leveling == true or (elevController.stat_values.queue_direction == 0 or elevController.stat_values.queue_direction == directionValue))))

					if checking and ((not buttonHoldConnection) or (not buttonHoldConnection.Connected)) and isOnFloor then
						setButton(floor, true, b, config.color_config[string.lower(b.Name)].inactive)
					end
					checking = false

					if not isOnFloor then
						stopConnections[#stopConnections+1] = elevator.API.Event:Connect(function(protocol, params)
							if protocol == 'on_hall_call_removed' then
								if (not elevController) or params.call ~= floorNumber or (not params.directions[tostring(directionValue)]) or directionValue ~= elevController.stat_values.queue_direction then return end
								reset()
							end
						end)
						stopConnections[#stopConnections+1] = elevator.Values.Out_Of_Service:GetPropertyChangedSignal('Value'):Connect(function()
							if not elevator.Values.Out_Of_Service then return end
							reset()
						end)
					end

					if floorNumber == elevController.stat_values.floor and elevController.stat_values.move_direction == 0 and (elevController.stat_values.queue_direction == 0 or elevController.stat_values.queue_direction == directionValue) then
						if elevController.stat_values.queue_direction == 0 then
							elevController.stat_values.queue_direction = directionValue
							elevController.update_stat_values()
						end
						elevController.check_lantern_and_fire(elevController.config.lantern_controls.activate_on_exterior_wake_call.interior, elevController.config.color_config.lanterns.interior, function()
							return true
						end, elevator.Car.Lantern_API)
						elevController.check_lantern_and_fire(elevController.config.lantern_controls.activate_on_exterior_wake_call.exterior, elevController.config.color_config.lanterns.exterior, function()
							return true
						end, floor_instance.floor_model.Lantern_API)
						task.spawn(function()
							if buttonHoldConnection and buttonHoldConnection.Connected then return end
							buttonHoldConnection = elevController.step:Connect(function()
								if not elevController then return buttonHoldConnection:Disconnect() end
								for i, v in elevController.door_data do
									if v.state ~= 'Open' then continue end
									v.timer_start = os.clock()
								end
							end)
						end)
						elevController.api:Fire('door_signal', {request = 'open', sides = 'all', open_time = elevController.config.doors.door_timers.open_by_call, hall_call = true})
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
					buttonClickSound.Playing = true
				else
					buttonClickSound.TimePosition = 0
				end
				----

				if checking or (not (elevController and (floorNumber == elevController.stat_values.floor and elevController.stat_values.move_direction == 0 and (elevController.stat_values.queue_direction == 0 or elevController.stat_values.queue_direction == directionValue)))) then return end
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