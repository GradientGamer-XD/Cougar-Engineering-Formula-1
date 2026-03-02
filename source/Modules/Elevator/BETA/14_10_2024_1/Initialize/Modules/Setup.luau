local controllerClass = {}
controllerClass.className = 'controllerClass'

local controllers = {}

local replicatedStorage = game:GetService('ReplicatedStorage')
local replicatedFirst = game:GetService('ReplicatedFirst')
local serverScriptService = game:GetService('ServerScriptService')
local runService = game:GetService('RunService')
local players = game:GetService('Players')

function controllerClass.new(source, config)

	local elevatorID = source:GetAttribute('elevatorID')

	if controllers[elevatorID] then warn(`A controller has already been set up for this elevator!`) return controllers[elevatorID] end

	if not elevatorID then
		elevatorID = tostring(math.random(0,99999999))
		source:SetAttribute('elevatorID', elevatorID)
	end

	local initStart = os.clock()
	print('Setting up...')

	local controller = setmetatable({}, controllerClass)

	controller.step = runService.PreSimulation

	controller.source = source
	controller.config = config
	controller.path = source:GetFullName()

	controller.car = source:FindFirstChild('Car')
	controller.platform = controller.car:FindFirstChild('Platform')
	controller.level = controller.car:FindFirstChild('Level') or controller.platform
	controller.initial_position = controller.platform.CFrame
	controller.current_position = controller.platform.CFrame

	controller.api = Instance.new('BindableEvent')
	controller.api.Name = 'API'
	controller.api.Parent = source

	local dataApi = Instance.new('BindableFunction')
	dataApi.Name = 'Data_API'
	dataApi.Parent = source

	local t_value = Instance.new('CFrameValue')
	t_value.Name = 'target_position'
	t_value.Value = controller.current_position
	t_value.Parent = controller.platform

	controller.id = elevatorID

	controller.floors = {}

	for i, v in source.Floors:GetChildren() do
		local floorNumber, level = tonumber(string.split(v.Name, 'Floor_')[2]), v:FindFirstChild('Level')
		if (not floorNumber) or (not level) then continue end
		controller.floors[tostring(floorNumber)] = {
			floor_model = v,
			floor_number = floorNumber,
			level = level
		}
	end

	function controller.find_floor(floor: number | string)
		return controller.floors[tostring(floor)]
	end
	
	-- Get bottom & top floor --
	local dist_top = -math.huge
	local dist_bottom = math.huge
	for i, v in controller.floors do
		local level_pos = v.level.Position.Y
		if level_pos >= dist_top then
			dist_top = level_pos
			controller.top_floor = v
		end
		if level_pos <= dist_bottom then
			dist_bottom = level_pos
			controller.bottom_floor = v
		end
	end
	----

	function controller.get_nearest_floor()
		local dist = math.huge
		local result
		for i, v in controller.floors do
			if math.abs(v.level.Position.Y-controller.current_position.Position.Y) <= dist then
				dist = math.abs(v.level.Position.Y-controller.current_position.Position.Y)
				result = v
			end
		end
		return result
	end

	function controller.get_table_length(t: any)
		if typeof(t) ~= 'table' then return end
		local length = 0
		for i, v in t do
			length += 1
		end
		return length
	end

	function controller.check_all_doors(target_position: string)
		for i, v in controller.door_data do
			for i, weld in v.engine_welds do
				if (weld:GetAttribute(target_position).Position-weld.C0.Position).Magnitude > (weld:IsDescendantOf(car) and .175 or .035) or v.state ~= 'Closed' then return false end
			end
		end
		return true
	end

	controller.stat_value_instances = {}
	controller.stat_values = {
		['floor'] = controller.get_nearest_floor().floor_number,
		['move_direction'] = 0,
		['queue_direction'] = 0,
		['destination'] = 0,
		['leveling'] = false,
		['speed'] = 0,
		['velocity'] = 0,
		['door_safety_lock'] = false,
		['out_of_service'] = false,
		['park'] = false,
	}
	controller.queue_direction_lock = false -- Prevents the queue direction from being set if true

	function controller.update_stat_values()
		for i, v in controller.stat_value_instances do
			v.update()
		end
	end

	if not source:FindFirstChild('Values') then
		controller.values_folder = Instance.new('Folder')
		controller.values_folder.Name = 'Values'
		controller.values_folder.Parent = source
		for i, v in controller.stat_values do
			local t = typeof(v) == 'boolean' and 'Bool' or typeof(v) == 'number' and 'Number' or typeof(v) == 'string' and 'String' or nil
			if not t then continue end
			local str = string.gsub(i, '(%a)(%w*)', function(first, rest)
				return `{string.upper(first)}{rest}`
			end)
			local value = Instance.new(`{t}Value`)
			value.Name = str
			value.Value = v
			value.Parent = controller.values_folder
			local random_value = math.random(0, 9999999)
			local lastValue = value.Value
			value:GetPropertyChangedSignal('Value'):Connect(function()
				if value:GetAttribute(`value_hotfix_{random_value}`) then return end
				value.Value = lastValue
				lastValue = value.Value
			end)
			controller.stat_value_instances[value] = {
				instance = value,
				update = function()
					value:SetAttribute(`value_hotfix_{random_value}`, true)
					value.Value = controller.stat_values[i]
					lastValue = value.Value
					value:SetAttribute(`value_hotfix_{random_value}`, nil)
				end,
			}
		end
	end

	controller.dependencies = script.Parent.Parent:WaitForChild('Dependencies')

	controller.elevator_folder = replicatedStorage.MX_Elevator_Storage:FindFirstChild(`Elev_{elevatorID}`) or Instance.new('Folder')
	controller.elevator_folder.Name = `Elev_{elevatorID}`
	controller.elevator_folder.Parent = replicatedStorage.MX_Elevator_Storage
	local platformValue = Instance.new('ObjectValue')
	platformValue.Name = 'Target_Object'
	platformValue.Value = controller.platform
	platformValue.Parent = controller.elevator_folder
	local playerWeldsFolder = Instance.new('Folder')
	playerWeldsFolder.Name = 'Player_Welds'
	playerWeldsFolder.Parent = controller.elevator_folder

	-- Modules --
	controller.audio_module = require(script.Parent.Audio).new(controller)
	controller.welding_module = require(script.Parent.Welding)
	local signal = require(script.Parent.Signal) -- MUST be local
	controller.door_setup_module = require(script.Parent.Door_Setup)
	local buttons_handler_module = require(script.Parent.Buttons_Handler)
	controller.queue_module = require(script.Parent.Queue)
	controller.movement_module = require(script.Parent.Movement)
	controller.movement_instance = controller.movement_module.new(controller)

	local button_handler_instance = buttons_handler_module.new(source, config, controller)

	controller.queue = controller.queue_module.new(controller)

	function controller.index(t: any, index: number)
		if typeof(t) ~= 'table' then return error('Table (argument #1) must be a table') end
		if typeof(index) ~= 'number' then return error('Index (argument #2) must be a number') end
		local currentIndex = 0
		for i, v in t do
			currentIndex += 1
			if currentIndex == index then
				return v
			end
		end
		return nil
	end

	--

	-- Handle lanterns --
	local function setupLanterns(group: Instance, audio_config: any)
		local lanternApi = Instance.new('BindableEvent')
		lanternApi.Name = 'Lantern_API'
		lanternApi.Parent = group
		for i, v in group:GetDescendants() do
			if v.Name ~= 'Lanterns' then continue end
			local chimeBoxPart = Instance.new('Part')
			chimeBoxPart.Name = 'Chime_Box'
			chimeBoxPart.CFrame, chimeBoxPart.Size = v:GetBoundingBox()
			chimeBoxPart.Transparency = 1
			chimeBoxPart.CanCollide = false
			chimeBoxPart.CanQuery = false
			if chimeBoxPart:IsDescendantOf(controller.car) then
				controller.welding_module.weldParts(chimeBoxPart, controller.platform, true, false)
			elseif group:FindFirstChild('Level') then
				controller.welding_module.weldParts(chimeBoxPart, group.Level, true, false)
			else
				chimeBoxPart.Anchored = true
			end
			chimeBoxPart.Parent = v
			local chime_up = controller.audio_module.addSoundFromConfig(chimeBoxPart, 'Chime_Up', {
				id = audio_config.up_chime.id,
				volume = audio_config.up_chime.volume,
				pitch = audio_config.up_chime.pitch+math.random(-100,100)/16000,
				looped = false,
				minDistance = audio_config.up_chime.roll_off.min,
				maxDistance = audio_config.up_chime.roll_off.max,
				rollOffMode = audio_config.up_chime.roll_off.mode,
			})
			local chime_down = controller.audio_module.addSoundFromConfig(chimeBoxPart, 'Chime_Down', {
				id = audio_config.down_chime.id,
				volume = audio_config.down_chime.volume,
				pitch = audio_config.down_chime.pitch+math.random(-100,100)/16000,
				looped = false,
				minDistance = audio_config.down_chime.roll_off.min,
				maxDistance = audio_config.down_chime.roll_off.max,
				rollOffMode = audio_config.down_chime.roll_off.mode,
			})
			chime_up:SetAttribute('volume', chime_up.Volume)
			chime_down:SetAttribute('volume', chime_down.Volume)
		end
		lanternApi:Fire('set_lantern', { state = 'inactive', direction = 1, config = controller.config.color_config.lanterns[group:IsDescendantOf(controller.car) and 'interior' or 'exterior'], ring_chime = false })
		lanternApi:Fire('set_lantern', { state = 'inactive', direction = -1, config = controller.config.color_config.lanterns[group:IsDescendantOf(controller.car) and 'interior' or 'exterior'], ring_chime = false })
	end

	setupLanterns(controller.car, config.sounds.chimes.interior)
	for i, floor in controller.floors do
		setupLanterns(floor.floor_model, config.sounds.chimes.exterior)
	end
	----

	-- Add audios --
	controller.cab_region = controller.car:FindFirstChild('Cab_Region')
	if not controller.cab_region then
		controller.cab_region = Instance.new('Part')
		controller.cab_region.Name = 'Cab_Region'
		controller.cab_region.CFrame, controller.cab_region.Size = controller.platform.CFrame, Vector3.new(controller.platform.Size.X-1, controller.platform.Size.Y+10, controller.platform.Size.Z-1)
		controller.cab_region.Transparency = 1
		controller.cab_region.CanCollide = false
		controller.cab_region.CanQuery = false
		controller.cab_region.Parent = controller.car
	end
	local function addSound(parent: Instance, name: string, cfg: any, overrides: {any})
		local result = controller.audio_module.addSoundFromConfig(controller.cab_region, name, {
			id = cfg.id,
			volume = cfg.volume,
			pitch = cfg.pitch,
			looped = typeof(overrides) == 'table' and typeof(overrides.looped) == 'boolean' and overrides.looped or config.looped,
			minDistance = cfg.roll_off.min,
			maxDistance = cfg.roll_off.max,
			rollOffMode = cfg.roll_off.mode,
		})
		controller.audio_module.sounds[name] = result
		return result
	end

	addSound(controller.cab_region, 'Floor_Pass_Chime', config.sounds.chimes.floor_passing_chime)
	addSound(controller.cab_region, 'Alarm', config.sounds.alarm, {looped = true})
	addSound(controller.cab_region, 'Alarm_Release', config.sounds.alarm.release_sound)
	local travelingSound = addSound(controller.cab_region, 'Traveling_Sound', config.sounds.traveling_sound, { looped = true })
	travelingSound:SetAttribute('minVolume', config.sounds.traveling_sound.speed_ramping.volume.min)
	travelingSound:SetAttribute('maxVolume', config.sounds.traveling_sound.speed_ramping.volume.max)
	travelingSound:SetAttribute('minPitch', config.sounds.traveling_sound.speed_ramping.pitch.min)
	travelingSound:SetAttribute('maxPitch', config.sounds.traveling_sound.speed_ramping.pitch.max)

	if config.sounds.motor_sounds then
		for dir, data in config.sounds.motor_sounds do
			for motor_name, v in data do
				local soundName = `Motor_{string.upper(string.sub(motor_name, 1, 1))}{string.sub(motor_name, 2)}_{string.upper(string.sub(dir, 1, 1))}{string.sub(dir, 2)}`
				local sound = addSound(controller.cab_region, soundName, v)
				sound.Looped = motor_name == 'run'
			end
		end
	end

	travelingSound.Volume = 0
	travelingSound.PlaybackSpeed = 0
	travelingSound.Playing = true

	----

	-- Lanterns internal API check --
	function controller.check_lantern_and_fire(lantern_config: any, lantern_color_config: any, call_check_function: any, api_to_fire: BindableEvent)
		if lantern_config.enable and ((lantern_config.limit_to_hall_call and (typeof(call_check_function) == 'function' and call_check_function())) or (not lantern_config.limit_to_hall_call)) then
			task.delay(lantern_config.delay, function()
				api_to_fire:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = lantern_color_config, ring_chime = lantern_config.ring_chime })
			end)
		end
	end
	----

	controller.door_data = {}

	function controller.check_all_door_states(state: string)
		for i, v in controller.door_data do
			if v.state ~= state then return false end
		end
		return true
	end

	-- Weld the car --
	local weldsFolder = controller.car:FindFirstChild('Car_Welds') or Instance.new('Folder')
	weldsFolder.Name = 'Car_Welds'
	weldsFolder.Parent = controller.car

	local doorPartsToIgnore = {}
	for i, v in controller.car:GetChildren() do
		local doorSide = string.split(v.Name, 'Doors')[2] and string.split(v.Name, 'Doors')[1]
		if (not doorSide) then continue end
		if string.match(doorSide, '_') then
			doorSide = string.split(doorSide, '_')[2] and string.split(doorSide, '_')[1]
		end
		controller.door_data[doorSide] = controller.door_setup_module.new(source, v, controller)

		for i, p in v:GetDescendants() do
			if ((not p:IsA('BasePart')) or p.Name == 'Open') then continue end
			table.insert(doorPartsToIgnore, p)
		end
	end

	controller.floor_door_welds = {}
	for i, floor in controller.floors do
		for i, door in floor.floor_model:GetDescendants() do
			local doorSide = string.split(door.Name, 'Doors')[2] and string.split(door.Name, 'Doors')[1]
			if (not doorSide) then continue end
			if string.match(doorSide, '_') then
				doorSide = string.split(doorSide, '_')[2] and string.split(doorSide, '_')[1]
			end
			for i, v in door:GetChildren() do
				local scaler, open = v:FindFirstChild('Scaler'), v:FindFirstChild('Scaler') and v.Scaler:FindFirstChild('Open')
				if (not scaler) or (not open) then continue end
				local doorData = controller.door_data[doorSide]
				if not doorData then continue end

				controller.welding_module.weldPartsInModel(v, scaler, {open})
				controller.welding_module.weldParts(open, floor.level, true, false)
				open.Anchored = false
				local engineWeld = controller.welding_module.weldParts(scaler, open, true, false)
				engineWeld.Name = 'Door_Engine_Weld'
				engineWeld:SetAttribute('open_point', engineWeld.C1)
				engineWeld:SetAttribute('closed_point', engineWeld.C0)
				controller.floor_door_welds[#controller.floor_door_welds+1] = engineWeld

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
							table.insert(doorData.opening_threads, task.delay(controller.config.lantern_controls.activate_on_exterior_wake_call.interior.delay, function()
								controller.car.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.interior })
							end))
						end
						if controller.config.lantern_controls.activate_on_exterior_wake_call.exterior.enable then
							table.insert(doorData.opening_threads, task.delay(controller.config.lantern_controls.activate_on_exterior_wake_call.exterior.delay, function()
								floor_instance.floor_model.Lantern_API:Fire('set_lantern', { state = 'active', direction = controller.stat_values.queue_direction, config = controller.config.color_config.lanterns.exterior })
							end))
						end
						----
						return doorData.open(controller.config.doors.door_timers.open_by_call, true)
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
				local lastSafetyCheck = true
				engineWeld:GetPropertyChangedSignal('C0'):Connect(function()
					task.wait()
					local safetyMet = true
					for i, data in controller.door_data do
						for i, v in data.engine_welds do
							if (v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude >= .175 and data.state == 'Closed' then safetyMet = false break end
						end
					end
					for i, v in welds do
						if (v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude >= .035 and doorData.state == 'Closed' then safetyMet = false break end
					end
					if lastSafetyCheck == safetyMet then return end
					lastSafetyCheck = safetyMet
					controller.stat_values.out_of_service = not safetyMet
					controller.update_stat_values()
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
				val.Parent = doorData.engine_welds_folder

				local value = Instance.new('CFrameValue')
				value.Name = 'target_position'
				value.Value = engineWeld.C0
				value.Parent = engineWeld

			end
		end
	end

	controller.welding_module.weldPartsInModel(controller.car, controller.platform, doorPartsToIgnore, weldsFolder)
	controller.platform.Anchored = true

	button_handler_instance.setup(controller)

	controller.api.Event:Connect(function(protocol, params)
		if protocol == 'door_signal' then
			local sides = typeof(params.sides) == 'table' and params.sides or params.sides == 'all' and 'all' or 'all'
			local hallCall = if typeof(params.hall_call) == 'boolean' then params.hall_call else false
			if params.request == 'open' or params.request == 'close' then
				if sides == 'all' then
					for i, data in controller.door_data do
						data[params.request](typeof(params.open_time) == 'number' and params.open_time or controller.config.doors.door_timers.open_no_call, hallCall)
					end
				else
					for i, v in sides do
						local doorData = controller.door_data[v]
						if not doorData then continue end
						data[params.request](params.nudge)
					end
				end
			end
		elseif protocol == 'add_hall_call' then
			controller.queue.add_hall_call(params.call, params.direction, params.is_locked, params.sides) -- NOTE 09/27: "is_locked" & "sides" TO BE IMPLEMENTED
		end
	end)

	dataApi.OnInvoke = function(protocol, params)
		if protocol == 'get_controller' then
			local ctrl = controller
			return ctrl
		end
	end

	for i, v in source.Controller:FindFirstChild('Plugins') and source.Controller.Plugins:GetChildren() or {} do
		if not v:IsA('ModuleScript') then continue end
		local ran, res = pcall(require, v)
		if (not ran) or (typeof(res) ~= 'table') or (not res.init) then continue end
		task.spawn(res.init, controller)
	end

	print(`Setup complete! ({math.round((os.clock()-initStart)*1000)/1000}s)`)

	controllers[elevatorID] = controller

	return controller

end

return controllerClass