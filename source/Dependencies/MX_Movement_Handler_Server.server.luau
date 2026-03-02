local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

local elevators = ReplicatedStorage:WaitForChild('MX_Elevator_Storage')
local dtTimeValue = ReplicatedStorage:WaitForChild('MXV2_DeltaTime')

local bindString = 'Elevator_Bind_Event'

local engineWelds = {}
local platforms = {}

local function lerp(a, b, t)
	return a+(b-a)*t
end

local function bindElevator(elevator: any)
	if not elevator:WaitForChild('Target_Object').Value then elevator.Target_Object.Changed:Wait() end
	if elevator.Target_Object.Value.Parent.Parent.Values.Move_Direction.Value ~= 0 then
		platforms[elevator.Target_Object.Value] = {
			Instance = elevator.Target_Object.Value
		}
	end
	elevator.Target_Object.Value.CFrame = elevator.Target_Object.Value.target_position.Value
	local connection: RBXScriptConnection
	connection = elevator.Target_Object.Value.Parent.Parent.Values:WaitForChild('Move_Direction'):GetPropertyChangedSignal('Value'):Connect(function()
		if elevator.Target_Object.Value.Parent.Parent.Values.Move_Direction.Value ~= 0 then
			platforms[elevator.Target_Object.Value] = {
				Instance = elevator.Target_Object.Value,
				Connection = connection
			}
		else
			if not platforms[elevator.Target_Object.Value] then return end
			platforms[elevator.Target_Object.Value] = nil
		end
	end)
	
	for i, v in elevator:GetChildren() do
		local doorSide = string.split(v.Name, 'Doors_Data')[2] and string.split(v.Name, 'Doors_Data')[1]
		if (not doorSide) then continue end
		if string.match(doorSide, '_') then
			doorSide = string.split(doorSide, '_')[2] and string.split(doorSide, '_')[1]
		end
		for i, weld in v.Engine_Welds:GetChildren() do
			task.spawn(function()
				if not weld.Value then weld.Changed:Wait() end
				local target_position = weld.Value:WaitForChild('target_position', 5)
				if not target_position then return end
				if target_position:GetAttribute('is_active') == true then
					engineWelds[weld.Value] = {
						Instance = weld.Value,
						InterpolationStart = os.clock(),
						Delta = 0,
						Goal = target_position.Value,
						LastFrame = weld.Value.C0,
						LastPos = weld.Value.C0,
						Connection = connection,
						IsFloorWeld = weld.Value:FindFirstAncestor('Floors'),
						Velocity = 0,
						VelocityDiff = 0,
						T = 0,
						Config = require((weld.Value:FindFirstAncestor('Car') or weld.Value:FindFirstAncestor('Floors')).Parent.Controller.Config)
					}
				end
				weld.Value.C0 = target_position.Value
				local connection: RBXScriptConnection
				connection = target_position:GetAttributeChangedSignal('is_active'):Connect(function()
					if target_position:GetAttribute('is_active') == true then
						engineWelds[weld.Value] = {
							Instance = weld.Value,
							InterpolationStart = os.clock(),
							Delta = 0,
							Goal = target_position.Value,
							LastFrame = weld.Value.C0,
							LastPos = weld.Value.C0,
							Connection = connection,
							IsFloorWeld = weld.Value:FindFirstAncestor('Floors'),
							Velocity = 0,
							VelocityDiff = 0,
							T = 0,
							Config = require((weld.Value:FindFirstAncestor('Car') or weld.Value:FindFirstAncestor('Floors')).Parent.Controller.Config)
						}
					else
						if not engineWelds[weld.Value] then return end
						engineWelds[weld.Value] = nil
					end
				end)
			end)
		end
	end
	
	-- 09/06/2025: Implement counterweight movement
	local targetCW = elevator:WaitForChild('Target_Counterweight')
	if targetCW:GetAttribute('IsAvailable') then
		if not targetCW.Value then
			while not targetCW.Value do
				task.wait()
			end
		end
		if targetCW.Value.target_position:GetAttribute('is_active') then
			platforms[elevator.Target_Counterweight.Value] = {
				Instance = elevator.Target_Counterweight.Value
			}
		end
		-- Set initial CFrame
		elevator.Target_Counterweight.Value.CFrame = elevator.Target_Counterweight.Value.target_position.Value

		local connection: RBXScriptConnection
		connection = targetCW.Value.target_position:GetAttributeChangedSignal('is_active'):Connect(function()
			if targetCW.Value.target_position:GetAttribute('is_active') then
				platforms[elevator.Target_Counterweight.Value] = {
					Instance = elevator.Target_Counterweight.Value,
					Connection = connection
				}
			else
				if not platforms[elevator.Target_Counterweight.Value] then return end
				platforms[elevator.Target_Counterweight.Value] = nil
			end
		end)
	end
end

local function bindFunction(dtTime: number)
	for i, v in platforms do
		v.Instance.CFrame = v.Instance.CFrame:Lerp(v.Instance.target_position.Value, math.min(dtTime / (0.075 * (v.Instance.Values.Value.Speed.Value^(1/2))), 1))
	end
	
	for i, v in engineWelds do
		--v.instance.C0 = v.instance.C0:Lerp(v.instance.target_position.Value, math.min(dtTime / 0.035^1/2, 1))
		local nextFrame = v.LastFrame:Lerp(v.Goal, math.min((os.clock()-v.InterpolationStart)/0.075, 1))
		if v.Goal ~= v.Instance.target_position.Value then
			v.LastFrame = nextFrame
			v.Goal = v.Instance.target_position.Value
			v.InterpolationStart = os.clock()
		end

		v.LastPos = v.Instance.C0.Position
		if v.IsFloorWeld then
			local velocityValue = v.IsFloorWeld.Parent.Values:FindFirstChild(`{v.Instance:GetAttribute('Side')}_Door_Speed`)
			if velocityValue then
				local threshold = ( if v.Config.doors.opening.outer_door_spring_effect and v.Config.doors.opening.outer_door_spring_effect.enable then v.Config.doors.opening.outer_door_spring_effect.threshold else 0 )
				v.VelocityDiff = lerp(v.VelocityDiff, math.min(math.abs(velocityValue.Value-v.Velocity)/(dtTime/.005), .075), dtTime/0.1)
				v.Velocity = velocityValue.Value
				v.T += dtTime*v.VelocityDiff/.02

				local s = math.cos(v.T*12.5)*(v.VelocityDiff*3*threshold)
				local diff = (nextFrame.Position-v.Instance.target_position.Value.Position)
				--local diff = (v.Instance:GetAttribute('open_point').Position-v.Instance:GetAttribute('closed_point').Position)
				if diff ~= diff or diff.Unit ~= diff.Unit or diff.Magnitude ~= diff.Magnitude then
					continue
				end
				nextFrame = CFrame.new(nextFrame.Position-diff.Unit*s)*CFrame.fromOrientation(nextFrame:ToOrientation())
			end
		end
		v.Instance.C0 = nextFrame
	end
	
end

local mainConnection: RBXScriptConnection
mainConnection = RunService.PreAnimation:Connect(bindFunction)

for i, v in elevators:GetChildren() do
	bindElevator(v)
end
elevators.ChildAdded:Connect(bindElevator)

Players.PlayerAdded:Connect(function()
	if not mainConnection then return end
	for i, v in engineWelds do
		if not v.connection then continue end
		connection:Disconnect()
	end
	for i, v in platforms do
		if not v.connection then continue end
		connection:Disconnect()
	end
	table.clear(engineWelds)
	table.clear(platforms)
	mainConnection:Disconnect()
	mainConnection = nil
	script:Destroy()
end)
if #Players:GetChildren() == 0 or (not mainConnection) then return end
for i, v in engineWelds do
	if not v.connection then continue end
	connection:Disconnect()
end
for i, v in platforms do
	if not v.connection then continue end
	connection:Disconnect()
end
table.clear(engineWelds)
table.clear(platforms)
mainConnection:Disconnect()
mainConnection = nil
script:Destroy()