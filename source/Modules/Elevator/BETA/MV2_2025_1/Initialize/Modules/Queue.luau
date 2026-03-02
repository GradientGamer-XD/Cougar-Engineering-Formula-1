local queueClass = {}
queueClass.className = 'queueClass'

function queueClass.new(controller)

	local data = setmetatable({}, queueClass)
	data.car_calls = {}
	data.hall_calls = {}

	-- Car call handling --
	function data.find_car_call(call: number)
		for i, v in data.car_calls do
			if v.call == call then return v end
		end
		return nil
	end

	function data.add_car_call(call: number, bypass_fire_recall: boolean?)
		local result = data.find_car_call(call)
		if controller.stat_values.fire_service and bypass_fire_recall == false then return false, 'Elevator is in fire service' end
		if result then return 'Call already exists!' end
		local entry = {
			call = call,
			locked = '', -- TO BE ADDED
			side = '' -- TO BE ADDED
		}
		data.car_calls[tostring(call)] = entry
		controller.api:Fire('on_car_call_added', entry)
		local floor = controller.find_floor(call)
		if not floor then return end
		local direction = floor.level.Position.Y > controller.current_position.Position.Y and 1 or floor.level.Position.Y < controller.current_position.Position.Y and -1 or 0 -- Check physical position & convert to numerical direction logic
		if direction == 0 then return 'Direction cannot be 0' end
		if ((controller.stat_values.queue_direction == 0 or controller.stat_values.queue_direction == direction) and ((call > controller.stat_values.floor and call < controller.stat_values.destination) or (call < controller.stat_values.floor and call > controller.stat_values.destination) or (controller.stat_values.queue_direction == 0 and controller.get_table_length(data.car_calls)+controller.get_table_length(data.hall_calls) == 1))) then
			controller.stat_values.destination = call
			controller.update_stat_values()
		end
		if controller.stat_values.queue_direction == 0 and controller.queue_direction_lock == false then
			controller.stat_values.queue_direction = direction
			controller.update_stat_values()
		end

		if controller.stat_values.move_direction == 0 then
			if call == controller.stat_values.floor then
				local direction = controller.stat_values.queue_direction
				controller.api:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.config.doors.door_timers.open_on_stop, hall_call = true})
				controller.queue.remove_car_call(call)
				controller.queue.remove_hall_call(call, direction)
				controller.stat_values.queue_direction = direction
				task.spawn(controller.update_stat_values)
			end

			task.spawn(controller.movement_instance.go_to_floor, call, false, true)
		end

		return true
	end

	function data.get_nearest_car_call(floor: number, direction: number)
		if typeof(direction) ~= 'number' or (direction ~= -1 and direction ~= 1) then
			direction = 'unset' -- Failsafe for possible invalid value being passed as the direction
		end

		local dist = math.huge
		local result = nil

		for i, v in data.car_calls do
			local diff = math.abs(v.call-floor)
			if ((direction == 1 and v.call > floor) or (direction == -1 and v.call < floor) or (direction == 'unset' and v.call ~= floor)) and diff <= dist then
				dist = diff
				result = v
			end
		end
		return result
	end

	function data.remove_car_call(call: number)
		local removed = false
		for i, v in data.car_calls do
			if v.call == call then
				data.car_calls[tostring(call)] = nil
				controller.api:Fire('on_car_call_removed', v)
				removed = true
			end
		end
		if removed and (controller.get_table_length(data.car_calls) == 0 and controller.get_table_length(data.hall_calls) == 0) then
			controller.stat_values.queue_direction = 0
			task.spawn(controller.update_stat_values)
		end
		return removed
	end

	--

	-- Hall call handling --

	function data.find_hall_call(call: number, direction: number?)
		if typeof(call) ~= 'number' then return error('Call must be a number') end
		if typeof(direction) ~= 'number' or (direction ~= -1 and direction ~= 1) then
			direction = 'unset' -- Failsafe for possible invalid value being passed as the direction
		end
		for i, v in data.hall_calls do
			if v.call == call and (v.directions[tostring(direction)] or direction == 'unset') then
				return v
			end
		end
		return nil
	end
	function data.get_nearest_hall_call(floor: number, direction: number?)
		if ((not tonumber(direction)) and typeof(direction) ~= 'number') or (direction ~= -1 and direction ~= 1) then
			direction = 'unset' -- Failsafe for possible invalid value being passed as the direction
		end

		local dist = math.huge
		local result = nil

		for i, v in data.hall_calls do
			local diff = math.abs(v.call-floor)
			if ((direction == 1 and v.call > floor) or (direction == -1 and v.call < floor) or (direction == 'unset' and v.call ~= floor)) and (direction == 'unset' or v.directions[tostring(direction)]) and diff <= dist then
				dist = diff
				result = v
			end
		end
		return result
	end

	function data.add_hall_call(call: number, direction: number)
		if typeof(call) ~= 'number' then return error('Call must be a number') end
		
		if controller.stat_values.fire_service then return false, 'Elevator is in fire service' end
		
		if ((not tonumber(direction)) and typeof(direction) ~= 'number') or (direction ~= -1 and direction ~= 1) then
			direction = 'unset' -- Failsafe for possible invalid value being passed as the direction
		end

		local result = data.find_hall_call(call)
		if result then
			if direction ~= 'unset' and (not result.directions[tostring(direction)]) then
				result.directions[tostring(direction)] = direction
			end
			
		elseif (direction == 1 or direction == -1) and ((direction ~= controller.stat_values.queue_direction and controller.stat_values.queue_direction ~= 0) or (call ~= controller.stat_values.floor or controller.stat_values.leveling)) then
			local entry = {
				call = call,
				directions = {},
				is_locked = '', -- TO BE ADDED
				sides = {} -- TO BE ADDED
			}
			if direction ~= 'unset' and (not entry.directions[tostring(direction)]) then
				entry.directions[tostring(direction)] = direction
			end

			data.hall_calls[tostring(call)] = entry
			controller.api:Fire('on_hall_call_added', entry)
		end

		local floor = controller.find_floor(call)
		if not floor then return print(`No floor instance found for floor {call}`) end
		
		local callDirection = controller.stat_values.floor ~= call and
			(floor.level.Position.Y > controller.current_position.Position.Y and 1 or floor.level.Position.Y < controller.current_position.Position.Y and -1 or 0)
			or direction -- Check physical position & convert to numerical direction logic
		if callDirection ~= controller.stat_values.queue_direction and controller.stat_values.queue_direction ~= 0 and call == controller.stat_values.floor then return end
		
		if callDirection == 0 then return print('Direction cannot be 0') end
		
		if
			(((controller.stat_values.queue_direction == 0 or controller.stat_values.queue_direction == callDirection) and
				(direction == callDirection or direction == 'unset') and
				(callDirection == 1 and (call > controller.stat_values.floor and call <= controller.stat_values.destination)) or (callDirection == -1 and (call < controller.stat_values.floor and call >= controller.stat_values.destination))) or
				(controller.stat_values.queue_direction == 0 and controller.get_table_length(data.car_calls)+controller.get_table_length(data.hall_calls) <= 1)) then

			controller.stat_values.destination = call
			controller.update_stat_values()
		end
		if controller.stat_values.queue_direction == 0 and controller.queue_direction_lock == false then
			controller.stat_values.queue_direction = callDirection
			controller.update_stat_values()
		end

		if controller.stat_values.move_direction == 0 then
			if call == controller.stat_values.floor then
				local direction = controller.stat_values.queue_direction
				controller.api:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.config.doors.door_timers.open_by_call, hall_call = true})
				controller.queue.remove_car_call(call)
				controller.queue.remove_hall_call(call, direction)
				controller.stat_values.queue_direction = direction
				task.spawn(controller.update_stat_values)
			end

			task.spawn(controller.movement_instance.go_to_floor, call, false, true)
		end

		return true

	end

	function data.remove_hall_call(call: number, direction: number?)
		if typeof(call) ~= 'number' then return error('Call must be a number') end
		if ((not tonumber(direction)) and typeof(direction) ~= 'number') or (direction ~= -1 and direction ~= 1) then
			direction = 'unset' -- Failsafe for possible invalid value being passed as the direction
		end

		local removed = false
		for i, v in data.hall_calls do
			if v.call == call then
				controller.api:Fire('on_hall_call_removed', v)
				if v.directions[tostring(direction)] then
					v.directions[tostring(direction)] = nil
					print(`Removed directional call from floor {v.call}`)
				end
				if controller.get_table_length(v.directions) == 0 then
					data.hall_calls[tostring(v.call)] = nil
					print(`Removed call entry {v.call}`)
				end
				removed = true
			end
		end
		return removed
	end

	--

	return data

end

return queueClass