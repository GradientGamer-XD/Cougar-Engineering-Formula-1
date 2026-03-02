local controllerClass = {}
controllerClass.className = 'controllerClass'

local controllers = {}

local replicatedStorage = game:GetService('ReplicatedStorage')
local replicatedFirst = game:GetService('ReplicatedFirst')
local serverScriptService = game:GetService('ServerScriptService')
local runService = game:GetService('RunService')
local players = game:GetService('Players')
local collectionService = game:GetService('CollectionService')

function controllerClass.new(source, config)

	local elevatorID = source:GetAttribute('elevatorID')

	if controllers[elevatorID] then print(`A controller has already been set up for this elevator!`) return controllers[elevatorID] end

	if not elevatorID then
		elevatorID = tostring(math.random(0,99999999))
		source:SetAttribute('elevatorID', elevatorID)
	end

	local initStart = os.clock()
	print('Setting up...')

	collectionService:AddTag(source, 'MX_Elevator')

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
	
	controller.remote = Instance.new('RemoteEvent')
	controller.remote.Name = 'Remote'
	controller.remote.Parent = source

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

		['fire_service'] = false,
		['phase_2'] = false
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
			if v.Name ~= 'Lanterns' or not v:IsA('Model') then continue end
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
				on_add = audio_config.up_chime.on_add
			})
			local chime_down = controller.audio_module.addSoundFromConfig(chimeBoxPart, 'Chime_Down', {
				id = audio_config.down_chime.id,
				volume = audio_config.down_chime.volume,
				pitch = audio_config.down_chime.pitch+math.random(-100,100)/16000,
				looped = false,
				minDistance = audio_config.down_chime.roll_off.min,
				maxDistance = audio_config.down_chime.roll_off.max,
				rollOffMode = audio_config.down_chime.roll_off.mode,
				on_add = audio_config.down_chime.on_add
			})
			chime_up:SetAttribute('volume', chime_up.Volume)
			chime_down:SetAttribute('volume', chime_down.Volume)
		end
		task.defer(function()
			lanternApi:Fire('set_lantern', { state = 'inactive', direction = 1, config = controller.config.color_config.lanterns[group:IsDescendantOf(controller.car) and 'interior' or 'exterior'], ring_chime = false })
			lanternApi:Fire('set_lantern', { state = 'inactive', direction = -1, config = controller.config.color_config.lanterns[group:IsDescendantOf(controller.car) and 'interior' or 'exterior'], ring_chime = false })
		end)
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
			on_add = cfg.on_add
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
				local sound = addSound(controller.cab_region, soundName, v, v.on_add)
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

	for i, floor in controller.floors do
		for i, door in floor.floor_model:GetDescendants() do
			local doorSide = string.split(door.Name, 'Doors')[2] and string.split(door.Name, 'Doors')[1]
			if (not doorSide) then continue end
			if string.match(doorSide, '_') then
				doorSide = string.split(doorSide, '_')[2] and string.split(doorSide, '_')[1]
			end

			local lastSafetyCheck = true
			for i, v in door:GetChildren() do
				local scaler, open = v:FindFirstChild('Scaler'), v:FindFirstChild('Scaler') and v.Scaler:FindFirstChild('Open')
				if (not scaler) or (not open) then continue end
				local doorData = controller.door_data[doorSide]
				if not doorData then continue end

				if not doorData.floor_door_welds then
					doorData.floor_door_welds = {}
				end
				
				controller.welding_module.weldPartsInModel(v, scaler, {open})
				controller.welding_module.weldParts(open, floor.level, true, false)
				open.Anchored = false
				local engineWeld = controller.welding_module.weldParts(scaler, open, true, false)
				engineWeld.Name = 'Door_Engine_Weld'
				engineWeld:SetAttribute('open_point', engineWeld.C1)
				engineWeld:SetAttribute('closed_point', engineWeld.C0)
				doorData.floor_door_welds[#doorData.floor_door_welds+1] = engineWeld

				-- Handle door safety --
				engineWeld:GetPropertyChangedSignal('C0'):Connect(function()
					task.wait()
					local safetyMet = true
					for i, v in doorData.engine_welds do
						if (v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude >= .06 and doorData.state == 'Closed' then safetyMet = false break end
					end
					for i, v in doorData.floor_door_welds do
						if (v:GetAttribute('closed_point').Position-v.C0.Position).Magnitude >= .035 and doorData.state == 'Closed' then safetyMet = false break end
					end
					if lastSafetyCheck == safetyMet then return end
					lastSafetyCheck = safetyMet
					controller.stat_values.out_of_service = not safetyMet
					task.spawn(controller.update_stat_values)
					if not safetyMet then
						print('Safety braking', doorData.side)
						controller.movement_instance.safety_brake()
					else
						controller.stat_values.door_safety_lock = false
						controller.movement_instance.resumeFloorCall()
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

	-- Limit switch check --
	function controller.check_limit_switch(top_or_bottom: string)
		if (top_or_bottom == 'bottom' and (controller[`{top_or_bottom}_floor`].level.Position.Y-controller.current_position.Position.Y) >= .35)
			or (top_or_bottom == 'top' and (controller[`{top_or_bottom}_floor`].level.Position.Y-controller.current_position.Position.Y) <= -.35) then return true end
		return false
	end

	local access_move_threads = {}
	local access_move_connections = {}
	local fire_recall_threads = {}

	controller.api.Event:Connect(function(protocol, params)
		controller.remote:FireAllClients(protocol, params)
		if protocol == 'door_signal' then
			local sides = typeof(params.sides) == 'table' and params.sides or params.sides == 'all' and 'all' or 'all'
			local hallCall = if typeof(params.hall_call) == 'boolean' then params.hall_call else false
			if params.request == 'open' or params.request == 'close' then
				if sides == 'all' then
					for i, data in controller.door_data do
						if params.request == 'open' then
							data[params.request](typeof(params.open_time) == 'number' and params.open_time or controller.config.doors.door_timers.open_no_call, hallCall)
						else
							data[params.request](params.nudge)
						end
					end
				else
					for i, v in sides do
						local data = controller.door_data[v]
						if not data then continue end
						if params.request == 'open' then
							data[params.request](typeof(params.open_time) == 'number' and params.open_time or controller.config.doors.door_timers.open_no_call, hallCall)
						else
							data[params.request](params.nudge)
						end
					end
				end
			end
		elseif protocol == 'add_car_call' then
			controller.queue.add_car_call(params.call, params.is_locked, params.sides) -- NOTE 09/27: "is_locked" & "sides" TO BE IMPLEMENTED
		elseif protocol == 'add_hall_call' then
			controller.queue.add_hall_call(params.call, params.direction, params.is_locked, params.sides) -- NOTE 09/27: "is_locked" & "sides" TO BE IMPLEMENTED
		elseif protocol == 'access_mode' then
			if params == true then
				controller.stat_values.out_of_service = true
				task.spawn(controller.update_stat_values)
				if controller.stat_values.move_direction ~= 0 then
					controller.movement_instance.safety_brake()
				end
			else
				controller.stat_values.out_of_service = false
				task.spawn(controller.update_stat_values)
			end
		elseif protocol == 'move_access' then
			if not controller.stat_values.out_of_service then return end
			if (params.direction == 1 and not controller.check_limit_switch('top')) or (params.direction == -1 and not controller.check_limit_switch('bottom')) then
				for i, v in access_move_threads do
					pcall(task.cancel, v)
				end
				for i, v in access_move_connections do
					if not v.Connected then continue end
					v:Disconnect()
				end
				table.clear(access_move_threads)
				table.clear(access_move_connections)

				local movementCfg = controller.config.movement[params.direction == 1 and 'up' or 'down']
				table.insert(access_move_threads, task.delay(params.start_delay, function()
					controller.stat_values.move_direction = params.direction
					task.spawn(controller.update_stat_values)
					table.insert(access_move_connections, controller.step:Connect(function(dtTime)
						if (params.direction == 1 and controller.check_limit_switch('top')) or (params.direction == -1 and controller.check_limit_switch('bottom')) then
							return controller.api:Fire('move_access', { direction = 0 })
						end

						controller.stat_values.speed = math.min(controller.stat_values.speed+movementCfg.acceleration.acceleration_rate*math.deg(dtTime), params.speed)

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
						task.spawn(controller.update_stat_values)
					end))
				end))
			elseif params.direction == 0 then
				for i, v in access_move_threads do
					pcall(task.cancel, v)
				end
				for i, v in access_move_connections do
					if not v.Connected then continue end
					v:Disconnect()
				end
				table.clear(access_move_threads)
				table.clear(access_move_connections)

				local movementCfg = controller.config.movement[controller.stat_values.move_direction == 1 and 'up' or 'down']
				table.insert(access_move_threads, task.spawn(function()
					table.insert(access_move_connections, controller.step:Connect(function(dtTime)
						controller.stat_values.speed = math.max(0, controller.stat_values.speed-.35)

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
						task.spawn(controller.update_stat_values)
						if controller.stat_values.speed == 0 then
							for i, v in access_move_threads do
								pcall(task.cancel, v)
							end
							for i, v in access_move_connections do
								if not v.Connected then continue end
								v:Disconnect()
							end
							table.clear(access_move_threads)
							table.clear(access_move_connections)
							return
						end
					end))
				end))
			end
		elseif protocol == 'fire_recall' then
			if params.recall == controller.stat_values.fire_service then return end
			if params.recall == true then
				local floor_instance = controller.find_floor(params.floor)
				if not floor_instance then return end

				controller.stat_values.fire_service = true
				controller.fire_recall_floor = params.floor
				task.spawn(controller.update_stat_values)

				for i, v in controller.queue.car_calls do
					controller.queue.remove_car_call(v.call)
				end
				for i, v in controller.queue.hall_calls do
					for i, d in v.directions do
						controller.queue.remove_hall_call(v.call, v.directions)
					end
				end

				if (controller.stat_values.move_direction == 1 and controller.stat_values.floor > params.floor) or (controller.stat_values.move_direction == -1 and controller.stat_values.floor < params.floor) or (controller.stat_values.floor == params.floor and controller.stat_values.move_direction ~= 0 and not controller.stat_values.leveling) then
					print('Fire Service: Elevator needs to stop at a nearby floor')
					local movementCfg = controller.config.movement[controller.stat_values.move_direction == 1 and 'up' or 'down']
					local stopping_distance = movementCfg.stopping.distance_to_stop*(controller.stat_values.speed/movementCfg.traveling_speed)+controller.stat_values.speed

					local nearest_floor, dist = nil, math.huge
					for i, v in controller.floors do
						if (controller.stat_values.move_direction == 1 and v.floor_number <= controller.stat_values.floor) or (controller.stat_values.move_direction == -1 and v.floor_number >= controller.stat_values.floor) then continue end
						local near_dist = math.abs(v.level.Position.Y-(controller.current_position.Position.Y+stopping_distance))
						if near_dist <= dist then
							dist = near_dist
							nearest_floor = v
						end
					end
					if not nearest_floor then return end
					controller.stat_values.destination = nearest_floor.floor_number
					task.spawn(controller.update_stat_values)
				else
					-- Open all elevator doors --
					if controller.fire_recall_floor ~= controller.stat_values.floor then
						controller.queue.add_car_call(controller.fire_recall_floor, true)
					else
						controller.api:Fire('door_signal', { sides = 'all', request = 'open' })
					end
				end

			else
				local last_recall_floor = controller.fire_recall_floor
				controller.queue.remove_car_call(controller.fire_recall_floor)
				controller.stat_values.fire_service = false
				controller.fire_recall_floor = nil
				task.spawn(controller.update_stat_values)
				if controller.movement_instance.movement_threads.fire_recall then
					pcall(task.cancel, controller.movement_instance.movement_threads.fire_recall)
					controller.movement_instance.movement_threads.fire_recall = nil
				end
				if last_recall_floor ~= controller.stat_values.floor then return end
				controller.api:Fire('door_signal', { sides = 'all', request = 'close' })
			end
		elseif protocol == 'phase_2' then
			controller.stat_values.phase_2 = params.value
			task.spawn(controller.update_stat_values)
		end
	end)

	dataApi.OnInvoke = function(protocol, params)
		if protocol == 'get_controller' then
			return controller
		end
	end

	for i, v in source.Controller:FindFirstChild('Plugins') and source.Controller.Plugins:GetChildren() or {} do
		if not v:IsA('ModuleScript') then continue end
		local ran, res = pcall(require, v)
		if (not ran) or (typeof(res) ~= 'table') then continue end
		if res.button_input_handler then
			controller.button_input_conditional = res
		end
		if not res.init then continue end
		task.spawn(res.init, controller)
	end

	print(`Setup complete! ({math.round((os.clock()-initStart)*1000)/1000}s)`)

	controllers[elevatorID] = controller

	return controller

end

return controllerClass