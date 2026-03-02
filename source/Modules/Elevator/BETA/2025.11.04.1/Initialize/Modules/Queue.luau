local QueueClass = {}
QueueClass.className = 'QueueClass'

QueueClass.__index = function(self, key)
	if --[[key == 'car' or key == 'source' or key == 'platform' or key == 'level' or key == 'audio_module' or key == 'api']] rawequal(typeof(key), 'string') and (string.sub(key, 1, 1) == string.sub(string.lower(key), 1, 1) or key == 'current_position') then
		local function convertString(snakeStr)
			local pascalStr = snakeStr:gsub("_(%a)", function(letter)
				return letter:upper()
			end)
			return pascalStr:sub(1, 1):upper() .. pascalStr:sub(2)
		end
		local newKey = convertString(key)
		if newKey == 'Api' then
			newKey = 'API' -- Additional correction
		end
		warn(`MXV2 Deprecation Warning: Internal value \'{key}\' was indexed. Please use \'{newKey}\' for new work.`)
		return self[newKey]
	end
end

function QueueClass.new(controller)

	local data = setmetatable({}, QueueClass)
	data.CarCalls = {}
	data.HallCalls = {}

	-- Car call handling --
	function data.FindCarCall(call: number)
		for i, v in data.CarCalls do
			if v.Call == call then return v end
		end
		return nil
	end

	function data.AddCarCall(call: number, params: { BypassFireRecall: boolean?, IsLocked: boolean?, Sides: {any}, ActivateButton: boolean? })
		local result = data.FindCarCall(call)
		if controller.StatValues.FireService.Recall and params.BypassFireRecall == false then return false, 'Elevator is in fire service' end
		if result then return 'Call already exists!' end
		local entry = {
			Call = call,
			Locked = '', -- TO BE ADDED
			Side = '' -- TO BE ADDED
		}
		data.CarCalls[tostring(call)] = entry
		controller.API:Fire('on_car_call_added', entry)
		local floor = controller.FindFloor(call)
		if not floor then return end
		
		local direction = floor.Level.Position.Y > controller.CurrentPosition.Position.Y and 1 or floor.Level.Position.Y < controller.CurrentPosition.Position.Y and -1 or 0 -- Check physical position & convert to numerical direction logic
		if direction == 0 then return 'Direction cannot be 0' end
		
		if typeof(params) == 'table' and params.ActivateButton == true then
			local Button = controller.Car.Buttons:FindFirstChild(`Floor_{call}`)
			controller.ButtonHandlerInstance.SetButton(controller.Car, true, Button, controller.Config.color_config.buttons.car_buttons.floor_buttons, 'active', true)
		end
		
		if ((controller.StatValues.QueueDirection == 0 or controller.StatValues.QueueDirection == direction) and ((call > controller.StatValues.Floor and call < controller.StatValues.Destination) or (call < controller.StatValues.Floor and call > controller.StatValues.Destination) or (controller.StatValues.QueueDirection == 0 and controller.GetTableLength(data.CarCalls)+controller.GetTableLength(data.HallCalls) == 1))) then
			controller.StatValues.Destination = call
			controller.UpdateStatValues()
		end
		if controller.StatValues.QueueDirection == 0 and controller._QueueDirectionLock == false then
			controller.StatValues.QueueDirection = direction
			controller.UpdateStatValues()
		end

		if controller.StatValues.MoveDirection == 0 then
			if call == controller.StatValues.Floor then
				local direction = controller.StatValues.QueueDirection
				controller.API:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.Config.doors.door_timers.open_on_stop, hall_call = true})
				controller.Queue.RemoveCarCall(call)
				controller.Queue.RemoveHallCall(call, direction)
				--controller.StatValues.QueueDirection = direction
				task.spawn(controller.UpdateStatValues)
			end

			task.spawn(controller.MovementInstance.GoToFloor, call, false, true)
		end

		return true
	end

	function data.GetNearestCarCall(floor: number, direction: number)
		if typeof(direction) ~= 'number' or (direction ~= -1 and direction ~= 1) then
			direction = 'unset' -- Failsafe for possible invalid value being passed as the direction
		end

		local dist = math.huge
		local result = nil

		for i, v in data.CarCalls do
			local diff = math.abs(v.Call-floor)
			if ((direction == 1 and v.Call > floor) or (direction == -1 and v.Call < floor) or (direction == 'unset' and v.Call ~= floor)) and diff <= dist then
				dist = diff
				result = v
			end
		end
		return result
	end

	function data.RemoveCarCall(call: number)
		local removed = false
		for i, v in data.CarCalls do
			if v.Call == call then
				data.CarCalls[tostring(call)] = nil
				controller.API:Fire('on_car_call_removed', v)
				removed = true
			end
		end
		if removed and (controller.GetTableLength(data.CarCalls) == 0 and controller.GetTableLength(data.HallCalls) == 0) then
			--controller.StatValues.QueueDirection = 0
			task.spawn(controller.UpdateStatValues)
		end
		return removed
	end

	--

	-- Hall call handling --

	function data.FindHallCall(call: number, direction: number?)
		if typeof(call) ~= 'number' then return error('Call must be a number') end
		if typeof(direction) ~= 'number' or (direction ~= -1 and direction ~= 1) then
			direction = 'unset' -- Failsafe for possible invalid value being passed as the direction
		end
		for i, v in data.HallCalls do
			if v.Call == call and (v.Directions[tostring(direction)] or direction == 'unset') then
				return v
			end
		end
		return nil
	end
	function data.GetNearestHallCall(floor: number, direction: number?)
		if ((not tonumber(direction)) and typeof(direction) ~= 'number') or (direction ~= -1 and direction ~= 1) then
			direction = 'unset' -- Failsafe for possible invalid value being passed as the direction
		end

		local dist = math.huge
		local result = nil

		for i, v in data.HallCalls do
			local diff = math.abs(v.Call-floor)
			if ((direction == 1 and v.Call > floor) or (direction == -1 and v.Call < floor) or (direction == 'unset' and v.Call ~= floor)) and (direction == 'unset' or v.Directions[tostring(direction)]) and diff <= dist then
				dist = diff
				result = v
			end
		end
		return result
	end

	function data.AddHallCall(call: number, direction: number)
		if typeof(call) ~= 'number' then return error('Call must be a number') end
		
		if controller.StatValues.FireService.Recall then return false, 'Elevator is in fire service' end
		
		if ((not tonumber(direction)) and typeof(direction) ~= 'number') or (direction ~= -1 and direction ~= 1) then
			direction = 'unset' -- Failsafe for possible invalid value being passed as the direction
		end

		local result = data.FindHallCall(call)
		if result then
			if direction ~= 'unset' and (not result.Directions[tostring(direction)]) then
				result.Directions[tostring(direction)] = direction
			end
			
		elseif (direction == 1 or direction == -1) and ((direction ~= controller.StatValues.QueueDirection or controller.StatValues.QueueDirection == 0) or (not (controller.StatValues.Floor == call and (controller.StatValues.MoveDirection == 0 or controller.StatValues.Leveling))) --[[or (call ~= controller.StatValues.Floor or controller.StatValues.Leveling)]]) then
			local entry = {
				Call = call,
				Directions = {},
				IsLocked = '', -- TO BE ADDED
				Sides = {} -- TO BE ADDED
			}
			if direction ~= 'unset' and (not entry.Directions[tostring(direction)]) then
				entry.Directions[tostring(direction)] = direction
			end

			data.HallCalls[tostring(call)] = entry
			controller.API:Fire('on_hall_call_added', entry)
		end

		local floor = controller.FindFloor(call)
		if not floor then return print(`No floor instance found for floor {call}`) end
		
		local callDirection = controller.StatValues.Floor ~= call and
			(floor.Level.Position.Y > controller.CurrentPosition.Position.Y and 1 or floor.Level.Position.Y < controller.CurrentPosition.Position.Y and -1 or 0)
			or direction -- Check physical position & convert to numerical direction logic
		if callDirection ~= controller.StatValues.QueueDirection and controller.StatValues.QueueDirection ~= 0 and call == controller.StatValues.Floor then return end
		
		if callDirection == 0 then return print('Direction cannot be 0') end
		
		if
			(((controller.StatValues.QueueDirection == 0 or controller.StatValues.QueueDirection == callDirection) and
				(direction == callDirection or direction == 'unset') and
				(callDirection == 1 and (call > controller.StatValues.Floor and call <= controller.StatValues.Destination)) or (callDirection == -1 and (call < controller.StatValues.Floor and call >= controller.StatValues.Destination))) or
				(controller.StatValues.QueueDirection == 0 and controller.GetTableLength(data.CarCalls)+controller.GetTableLength(data.HallCalls) <= 1)) then

			controller.StatValues.Destination = call
			controller.UpdateStatValues()
		end
		if controller.StatValues.QueueDirection == 0 and controller._QueueDirectionLock == false then
			controller.StatValues.QueueDirection = callDirection
			controller.UpdateStatValues()
		end

		if controller.StatValues.MoveDirection == 0 then
			if call == controller.StatValues.Floor then
				local direction = controller.StatValues.QueueDirection
				controller.API:Fire('door_signal', {sides = 'all', request = 'open', open_time = controller.Config.doors.door_timers.open_by_call, hall_call = true})
				controller.Queue.RemoveCarCall(call)
				controller.Queue.RemoveHallCall(call, direction)
				--controller.StatValues.QueueDirection = direction
				task.spawn(controller.UpdateStatValues)
			end

			task.spawn(controller.MovementInstance.GoToFloor, call, false, true)
		end

		return true

	end

	function data.RemoveHallCall(call: number, direction: number?)
		if typeof(call) ~= 'number' then return error('Call must be a number') end
		if ((not tonumber(direction)) and typeof(direction) ~= 'number') or (direction ~= -1 and direction ~= 1) then
			direction = 'unset' -- Failsafe for possible invalid value being passed as the direction
		end

		local removed = false
		for i, v in data.HallCalls do
			if v.Call == call then
				controller.API:Fire('on_hall_call_removed', v)
				if v.Directions[tostring(direction)] then
					v.Directions[tostring(direction)] = nil
				end
				if controller.GetTableLength(v.Directions) == 0 then
					data.HallCalls[tostring(v.Call)] = nil
				end
				removed = true
			end
		end
		return removed
	end

	--

	return data

end

return QueueClass