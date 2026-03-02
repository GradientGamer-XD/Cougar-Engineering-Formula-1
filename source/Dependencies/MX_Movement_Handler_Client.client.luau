local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

local elevators = ReplicatedStorage:WaitForChild('MX_Elevator_Storage')
local dtTimeValue = ReplicatedStorage:WaitForChild('MXV2_DeltaTime')

local bindString = 'Elevator_Bind_Event'

local engineWelds = {}
local platforms = {}

local function lerp(a, b, t)
	return a+(b-a)*t
end

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local root, humanoid
local currentWeld = nil

local function handleChar(char)
	root = char:WaitForChild('HumanoidRootPart')
	humanoid = char:WaitForChild('Humanoid')

	root.ChildAdded:Connect(function(child: Instance)
		if (not child:IsA('Weld')) or child.Name ~= 'MX_Elevator_Player_Weld' then return end
		local charSize = select(2, char:GetBoundingBox())
		
		--local params = RaycastParams.new()
		--params.FilterType = Enum.RaycastFilterType.Exclude
		--params.FilterDescendantsInstances = {char}
		--params.RespectCanCollide = true
		
		--local result = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), params)
		--local offset = result and result.Instance and (root.Size.Y/2)+(root.Position.Y-result.Position.Y)-child.Part0.Size.Y/2+.05 or 0
		local offset = root.Position.Y-child.Part1.Position.Y
		
		child.Enabled = false
		currentWeld = {
			offset = offset,
			weld = child
		}
	end)
	root.ChildRemoved:Connect(function(child: Instance)
		if not currentWeld or child ~= currentWeld.weld then return end
		currentWeld = nil
	end)
	humanoid.Died:Once(function()
		if not currentWeld then return end
		if currentWeld.weld then
			currentWeld.weld:Destroy()
		end
		root = nil
		humanoid = nil
		currentWeld = nil
	end)
end
player.CharacterAdded:Connect(handleChar)
player.CharacterRemoving:Connect(function(char)
	if currentWeld and currentWeld.weld then
		currentWeld.weld:Destroy()
	end
	root = nil
	humanoid = nil
	currentWeld = nil
end)
handleChar(character)

local function bindElevator(elevator: any)
	while not elevator:WaitForChild('Target_Object').Value do task.wait() end
	if elevator.Target_Object.Value.Parent.Parent.Values.Move_Direction.Value ~= 0 then
		platforms[elevator.Target_Object.Value] = {
			Instance = elevator.Target_Object.Value,
			Connection = connection
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
				while not weld.Value do task.wait() end
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
				target_position:GetAttributeChangedSignal('is_active'):Connect(function()
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
		while not targetCW.Value do
			task.wait()
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
		local val = 0.075*(v.Instance.Values.Value.Speed.Value^(1/2))
		if val ~= val then val = 0 end
		v.Instance.CFrame = v.Instance.CFrame:Lerp(v.Instance.target_position.Value, math.min(dtTime/val, 1))
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
	
	if (not currentWeld) or (not root) or currentWeld.Enabled then return end
	root.CFrame = CFrame.new(root.CFrame.Position.X, currentWeld.weld.Part1.CFrame.Position.Y+currentWeld.offset, root.CFrame.Position.Z)*CFrame.fromOrientation(root.CFrame:ToOrientation())
end

--local runtimeConnection: RBXScriptConnection
--runtimeConnection = runService.PreRender:Connect(bindFunction)
RunService:BindToRenderStep(bindString, 2, bindFunction)

for i, v in elevators:GetChildren() do
	task.spawn(bindElevator, v)
end
elevators.ChildAdded:Connect(bindElevator)

player.Changed:Connect(function()
	if player.Parent then return end
	print('Player is leaving')
	RunService:UnbindFromRenderStep(bindString)
end)