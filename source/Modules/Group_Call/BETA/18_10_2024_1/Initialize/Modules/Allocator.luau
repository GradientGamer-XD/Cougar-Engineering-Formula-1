local module = {}

local function checkElevatorStatValue(elevator, name)
	if (not elevator) then return nil end
	if not elevator:FindFirstChild('Values') then return nil end
	if (not elevator.Values:FindFirstChild(name)) then return nil end
	return elevator.Values[name]
end

function module.allocateElevator(callFloor: number, callDirection: number, elevators: any)

	local availableElevators = {}
	for i,v in elevators do
		if not v:FindFirstChild('Values') then continue end
		local floor, destination, moveDirection, queueDirection = checkElevatorStatValue(v,'Floor'),checkElevatorStatValue(v,'Destination'),checkElevatorStatValue(v,'Move_Direction'),checkElevatorStatValue(v,'Queue_Direction')
		if ((not floor) or (not destination) or (not moveDirection) or (not queueDirection)) then continue end
		table.insert(availableElevators, v)
	end
	table.sort(availableElevators, function(a,b)
		return a.Name < b.Name
	end)
	local sortedElevators = {}
	local nearestElevator
	local minDistance = math.huge
	for _,elevator in availableElevators do
		local statValues = elevator.Values
		local floor, direction, queueDirection = statValues.Floor.Value, statValues.Move_Direction.Value, statValues.Queue_Direction.Value
		local distance = math.abs(floor-callFloor)
		if (distance < minDistance) then
			-- // If elevator is idle on call floor
			if ((floor == callFloor and direction == 0) and (queueDirection == callDirection or queueDirection == 0)) then
				nearestElevator = elevator
				minDistance = distance
				--// Check for elevators in direction & check for their queue direction
			elseif ((callDirection == 1 and floor <= callFloor and (direction == -1 or direction == 0) and (queueDirection == 1 or queueDirection == 0)) or (callDirection == -1 and floor >= callFloor and (direction == 1 or direction == 0) and ((queueDirection == -1 or queueDirection == 0)))) then
				nearestElevator = elevator
				minDistance = distance
				-- // Check for any elevator that is idle on any floor
			elseif (direction == 0 and (queueDirection == callDirection or queueDirection == 0)) then
				nearestElevator = elevator
				minDistance = distance
			end
		end
	end
	if (not nearestElevator) then
		nearestElevator = availableElevators[1]
	end

	return nearestElevator

end

return module