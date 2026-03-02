local module = {}

-- Service check
local function CheckElevator(E)
	local V = E:FindFirstChild("Values")
	if not V then return false end
	if not V:FindFirstChild("Floor") or not V:FindFirstChild("Destination") or not V:FindFirstChild("Queue_Direction")
		or not V:FindFirstChild("Move_Direction") or not V:FindFirstChild("Leveling") then
		return false
	end
	if V:FindFirstChild("Out_Of_Service") and V.Out_Of_Service.Value then return false end
	
	if (V:FindFirstChild('Fire_Service_Recall') and V.Fire_Service_Recall.Value) or (V:FindFirstChild('Fire_Service_Phase_2') and V.Fire_Service_Phase_2.Value) then return false end
	
	return true
end

-- Get controller
local function GetController(E)
	local bf = E:FindFirstChildWhichIsA("BindableFunction")
	if not bf then return nil end
	local ok, controller = pcall(function()
		return bf:Invoke("GetController")
	end)
	return ok and controller or nil
end

-- Opposite hall call check
local function HasOppositeHallCall(controller, floor, dir)
	if not controller or not controller.Queue or not controller.Queue.HallCalls then return false end
	for _, call in ipairs(controller.Queue.HallCalls) do
		if call.Floor == floor and call.Direction ~= dir then return true end
	end
	return false
end

-- Prediction check: can elevator serve hall call in correct direction?
local function CanServeCall(E, Call_Floor, Call_Direction)
	local V = E:FindFirstChild("Values")
	local floor = V.Floor.Value
	local moveDir = V.Move_Direction.Value

	local controller = GetController(E)
	if not controller or not controller.Queue or not controller.Queue.CarCalls then return true end

	local carCalls = controller.Queue.CarCalls

	-- Hall call is Up
	if Call_Direction == 1 then
		-- Elevator moving down and has car calls below call floor → cannot serve
		for _, cf in ipairs(carCalls) do
			if cf < Call_Floor and moveDir == -1 then
				return false
			end
		end
	end

	-- Hall call is Down
	if Call_Direction == -1 then
		-- Elevator moving up and has car calls above call floor → cannot serve
		for _, cf in ipairs(carCalls) do
			if cf > Call_Floor and moveDir == 1 then
				return false
			end
		end
	end

	return true
end

local function GetTableLength(t: any)
	if typeof(t) ~= 'table' then return end
	
	local Length = 0
	for i, v in t do
		Length += 1
	end
	return Length
end

-- Calculate score
local function CalculateScore(E, Call_Floor, Call_Direction)
	local V = E:FindFirstChild("Values")
	local floor = V.Floor.Value
	local moveDir = V.Move_Direction.Value
	local queueDir = V.Queue_Direction.Value
	local leveling = V.Leveling.Value

	local controller = nil
	local ok
	local bf = E:FindFirstChildWhichIsA("BindableFunction")
	if bf then
		ok, controller = pcall(function()
			return bf:Invoke("GetController")
		end)
		if not ok then controller = nil end
	end

	local queueLength = 0
	if controller and controller.Queue and controller.Queue.CarCalls then
		queueLength = GetTableLength(controller.Queue.CarCalls)
	end

	-- Direction from elevator to call floor
	local dirToCall = (Call_Floor > floor) and 1 or -1

	-- ---- Opposite-direction hall call check ----
	if controller and controller.Queue and controller.Queue.HallCalls then
		for _, call in ipairs(controller.Queue.HallCalls) do
			if call.Floor == Call_Floor and call.Direction ~= Call_Direction then
				return math.huge
			end
		end
	end

	-- ---- Prediction: can elevator serve this call? ----
	if controller and controller.Queue and controller.Queue.CarCalls then
		for _, cf in ipairs(controller.Queue.CarCalls) do
			-- Up hall call cannot be assigned to elevator moving down past call floor
			if Call_Direction == 1 and cf < Call_Floor and moveDir == -1 then
				return math.huge
			end
			-- Down hall call cannot be assigned to elevator moving up past call floor
			if Call_Direction == -1 and cf > Call_Floor and moveDir == 1 then
				return math.huge
			end
		end
	end

	-- Base score: distance
	local score = math.abs(floor - Call_Floor) * 10

	-- ---- Leveling elevators at call floor ----
	if leveling and floor == Call_Floor then
		if queueDir == 0 or queueDir == Call_Direction then
			return -1000
		else
			return math.huge
		end
	end

	-- ---- Idle elevators ----
	if moveDir == 0 then
		if floor == Call_Floor then
			if queueDir == 0 or queueDir == Call_Direction then
				score = score - 50
			else
				score = score + 100
			end
		else
			score = score - 10
		end
	end

	-- ---- Moving elevators ----
	if moveDir ~= 0 then
		if moveDir == dirToCall then
			score = score - 20 -- moving toward call
		elseif moveDir == -dirToCall then
			score = score + 100 -- moving away penalty
		end
	end

	-- ---- Queue direction penalty if going opposite ----
	if queueDir ~= 0 and queueDir ~= dirToCall then
		score = score + 50
	end

	-- ---- Queue length penalty ----
	--score = score + queueLength * 5

	-- ---- Door state penalty ----
	for _, value in ipairs(V:GetChildren()) do
		if value:IsA("StringValue") and value.Name:match("_Door_State$") then
			if value.Value ~= "Closing" and value.Value ~= "Closed" then
				score = score + 30
			end
		end
	end

	return score
end



-- Main allocator
function module.Allocate(Call_Floor, Call_Direction, ElevatorList)
	local bestElevator = nil
	local bestScore = math.huge

	for _, E in ipairs(ElevatorList) do
		if not CheckElevator(E) then continue end
		local score = CalculateScore(E, Call_Floor, Call_Direction)
		if score < bestScore then
			bestScore = score
			bestElevator = E
		end
	end
	
	print(bestElevator)

	return bestElevator
end

return module
