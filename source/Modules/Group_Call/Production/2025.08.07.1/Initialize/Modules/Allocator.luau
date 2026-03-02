local module = {}

local function CheckElevator(Elevator: any)
	if
		(not Elevator:FindFirstChild('Values')) or
		(not Elevator.Values:FindFirstChild('Floor')) or
		(not Elevator.Values:FindFirstChild('Destination')) or
		(not Elevator.Values:FindFirstChild('Leveling')) or
		(not Elevator.Values:FindFirstChild('Queue_Direction')) or
		(not Elevator.Values:FindFirstChild('Move_Direction')) or
		(not Elevator.Values:FindFirstChild('Out_Of_Service')) or Elevator.Values.Out_Of_Service.Value or
		(Elevator.Values:FindFirstChild('Fire_Service_Recall') and Elevator.Values.Fire_Service_Recall.Value) or
		(Elevator.Values:FindFirstChild('Fire_Service_Phase_2') and Elevator.Values.Fire_Service_Phase_2.Value)
	then return false
	end
	return true
end

function module.allocateElevator(CallFloor: number, Direction: number, Elevators: any)

	local Dist, Elevator = math.huge, nil
	for i, elevator in Elevators do
		if not CheckElevator(elevator) or not elevator.Floors:FindFirstChild(`Floor_{CallFloor}`) then continue end

		local Floor, QueueDirection, MoveDirection, Leveling, Destination = elevator.Values.Floor.Value, elevator.Values.Queue_Direction.Value, elevator.Values.Move_Direction.Value, elevator.Values.Leveling.Value, elevator.Values.Destination.Value

		local ThisDist = math.abs(CallFloor-Floor)
		--print(`{elevator.Name} | Destination: {Destination}, Floor: {Floor}, CallFloor: {CallFloor}, QueueDirection: {QueueDirection}, MoveDirection: {MoveDirection}`)
		if ThisDist <= Dist then
			if (Floor == CallFloor and (MoveDirection == 0 or Leveling) and (QueueDirection == Direction or QueueDirection == 0)) or
				(Floor < CallFloor and ((MoveDirection ~= -1 and QueueDirection ~= -Direction) or (Floor == CallFloor and Leveling and QueueDirection ~= -1)) and Destination <= CallFloor) or
				(Floor > CallFloor and ((MoveDirection ~= 1 and QueueDirection ~= -Direction) or (Floor == CallFloor and Leveling and QueueDirection ~= 1)) and Destination >= CallFloor)
			then
				Dist = ThisDist
				Elevator = elevator
				if (Floor == CallFloor and (MoveDirection == 0 or Leveling) and (QueueDirection == Direction or QueueDirection == 0)) then break end -- Idle check passed, no need to search for other cars
			end
		end
	end

	return Elevator

end

return module