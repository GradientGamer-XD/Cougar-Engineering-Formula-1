local replicatedStorage = game:GetService('ReplicatedStorage')
local runService = game:GetService('RunService')

local elevators = replicatedStorage:WaitForChild('MX_Elevator_Storage')

local bindString = 'Elevator_Bind_Event'

local engineWelds = {}
local platforms = {}

local function bindElevator(elevator: any)
	if not elevator:WaitForChild('Target_Object').Value then elevator.Target_Object.Changed:Wait() end
	if elevator.Target_Object.Value.Parent.Parent.Values.Move_Direction.Value ~= 0 then
		table.insert(platforms, elevator.Target_Object.Value)
	end
	elevator.Target_Object.Value.CFrame = elevator.Target_Object.Value.target_position.Value
	elevator.Target_Object.Value.Parent.Parent.Values:WaitForChild('Move_Direction'):GetPropertyChangedSignal('Value'):Connect(function()
		if elevator.Target_Object.Value.Parent.Parent.Values.Move_Direction.Value ~= 0 then
			table.insert(platforms, elevator.Target_Object.Value)
		else
			local index = table.find(platforms, elevator.Target_Object.Value)
			if not index then return end
			table.remove(platforms, index)
		end
	end)
	for i, v in elevator:GetChildren() do
		local doorSide = string.split(v.Name, 'Doors_Data')[2] and string.split(v.Name, 'Doors_Data')[1]
		if (not doorSide) then continue end
		if string.match(doorSide, '_') then
			doorSide = string.split(doorSide, '_')[2] and string.split(doorSide, '_')[1]
		end
		for i, weld in v.Engine_Welds:GetChildren() do
			if not weld.Value then weld.Changed:Wait() end
			if weld.Value.target_position:GetAttribute('is_active') == true then
				table.insert(engineWelds, weld.Value)
			end
			weld.Value.C0 = weld.Value.target_position.Value
			weld.Value.target_position:GetAttributeChangedSignal('is_active'):Connect(function()
				if weld.Value.target_position:GetAttribute('is_active') == true then
					table.insert(engineWelds, weld.Value)
				else
					local index = table.find(engineWelds, weld.Value)
					if not index then return end
					table.remove(engineWelds, index)
				end
			end)
		end
	end
end

local function bindFunction(dtTime: number)
	for i, v in platforms do
		v.CFrame = v.CFrame:Lerp(v.target_position.Value, math.min(dtTime / (0.075 * (v.Parent.Parent.Values.Speed.Value^(1/2))), 1))
	end
	for i, v in engineWelds do
		v.C0 = v.C0:Lerp(v.target_position.Value, math.min(dtTime / 0.035^1/2, 1))
	end
end

if runService:IsServer() then
	runService.PreSimulation:Connect(bindFunction)
elseif runService:IsClient() then
	runService:BindToRenderStep(bindString, Enum.RenderPriority.First.Value+1, bindFunction)
end

for i, v in elevators:GetChildren() do
	bindElevator(v)
end
elevators.ChildAdded:Connect(bindElevator)