local TweenService = game:GetService('TweenService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local module = {}

module.className = 'Controller'

function module.new(source, config, meta, panel)

	local self = setmetatable({}, module)

	math.randomseed(os.clock())
	self.Id = math.random(0, 999999)

	local This = panel
	local Dependencies = script.Dependencies

	local Allocator = require('@self/Allocator')
	local LocalConfig = require(This.Config)
	local Welding = require('@self/Welding')
	local Signal = require('@self/Signal')
	
	local API = source:FindFirstChild('FS_API')

	local ThisFloor = tonumber(string.split(This.Parent.Name, 'Floor_')[2])

	local Screen = This.Screen
	local Display = Screen.Display
	
	local CurrentFrame = 'Home'

	local BackPageEntries = {}

	local Floors = {}
	for i, v in source.Panels:GetChildren() do
		local Floor = tonumber(string.split(v.Name, 'Floor_')[2])
		if not Floor then continue end

		Floors[#Floors+1] = Floor
	end
	table.sort(Floors, function(a, b)
		return a < b
	end)

	local ConfigModule = config
	config = require(config)
	local customLabels = config.CustomLabels or {}
	local buttonStyles = LocalConfig.ButtonStyles

	-- Setup handicap button
	local HandicapDisabled = false

	local HandicapBtn: DragDetector = Instance.new('DragDetector')
	HandicapBtn.MaxActivationDistance = 10
	HandicapBtn.DragStyle = Enum.DragDetectorDragStyle.Scriptable
	HandicapBtn.ResponseStyle = Enum.DragDetectorResponseStyle.Custom
	HandicapBtn.Parent = This.Handicap_Button.Button

	Welding.WeldPartsInModel(This.Handicap_Button)
	This.Handicap_Button.Button.Anchored = true
	This.Handicap_Button.Button:SetAttribute('Press_In', This.Handicap_Button.Button.CFrame*CFrame.new(0, 0, .0035))
	This.Handicap_Button.Button:SetAttribute('Press_Out', This.Handicap_Button.Button.CFrame)

	local Animator = Dependencies.HandicapBtnAnimator:Clone()
	Animator.Parent = This.Handicap_Button.Button
	Animator.Enabled = true
	--

	-- Panel switching function
	local function SwitchToPanel(Panel: string, PanelEntryAction: string)
		if not Display.Panels:FindFirstChild(Panel) then return end

		if PanelEntryAction == 'add' then
			if not table.find(BackPageEntries, Panel) then
				BackPageEntries[#BackPageEntries+1] = Panel
			end
		elseif PanelEntryAction == 'remove' then
			local Index = table.find(BackPageEntries, Panel)
			if Index then
				BackPageEntries[Index] = nil
			end
		end
		
		if #BackPageEntries == 0 then
			local Tween = TweenService:Create(Display.Bottom.Transition, TweenInfo.new(.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Offset = Vector2.new(-2, 0) })
			Tween:Play()
			Display.Panels.Keypad.Input.Text = ''
			Tween.Completed:Once(function()
				if Tween.PlaybackState ~= Enum.PlaybackState.Completed then return end

				Display.Bottom.Visible = false
			end)
		end
		
		CurrentFrame = Panel

		for i, f in Display.Panels:GetChildren() do
			local Gradient = f:FindFirstChild('Transition')
			if not Gradient then continue end

			local Tween = TweenService:Create(Gradient, TweenInfo.new(.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Offset = Vector2.new(f.Name == Panel and 2 or -2, 0) })
			Tween:Play()
			if f.Name == Panel then
				f.Visible = true
			else
				Tween.Completed:Once(function()
					if Tween.PlaybackState ~= Enum.PlaybackState.Completed then return end

					f.Visible = false
				end)
			end
		end
	end
	--

	--Create 3D-2D Attachments
	local dimensionalAttachments = {}
	local function createAttachment(name, pos, multiplier)
		local attachment = Instance.new('Attachment', Screen)
		attachment.Name = name
		attachment.Position = pos*multiplier
		table.insert(dimensionalAttachments, attachment)
		return attachment
	end

	--Right/Left
	local att1 = createAttachment('Attachment_Left', Vector3.new(1, 0, 0), 1)
	local att2 = createAttachment('Attachment_Right', Vector3.new(-1, 0, 0), 1)

	--Top/Bottom
	local att2 = createAttachment('Attachment_Up', Vector3.new(0, 0, 1), 1)
	local att3 = createAttachment('Attachment_Down', Vector3.new(0, 0, -1), 1)

	--TopLeft/TopRight // BottomLeft/BottomRight
	local att4 = createAttachment('Attachment_Left_Up', Vector3.new(1, 1, 0), 1)
	local att5 = createAttachment('Attachment_Left_Down', Vector3.new(1, -1, -1), 1)
	local att6 = createAttachment('Attachment_Right_Up', Vector3.new(-1, 1, 0), 1)
	local att7 = createAttachment('Attachment_Right_Down', Vector3.new(-1, -1, -1), 1)

	local function pointArrowTo(attachment, elevName)
		local offset = .375
		local arrow = Display.Panels.Elevator.Arrow
		local directions = {
			['Left'] = { ['Angle'] = -90, ['PositionOffset'] = { -offset,0 } },
			['Right'] = { ['Angle'] = 90, ['PositionOffset'] = { offset,0 } },
			['Up'] = { ['Angle'] = 0, ['PositionOffset'] = { 0,offset } },
			['Down'] = { ['Angle'] = 180, ['PositionOffset'] = { 0,-offset } },
			['Left_Down'] = { ['Angle'] = -145, ['PositionOffset'] = { -offset,offset } },
			['Left_Up'] = { ['Angle'] = -45, ['PositionOffset'] = { offset,-offset } },
			['Right_Down'] = { ['Angle'] = 145, ['PositionOffset'] = { offset,offset } },
			['Right_Up'] = { ['Angle'] = 45, ['PositionOffset'] = { -offset,-offset } }
		}

		local angleName = string.split(attachment.Name, 'Attachment_')[2]
		local angle = directions[angleName]
		angleName =
			angleName == 'Left' and 'To_Your_Left' or
			angleName == 'Right' and 'To_Your_Right' or
			angleName == 'Up' and 'To_The_Right_Ahead' or
			angleName == 'Down' and 'To_Your_Back_Left' or
			angleName == 'Left_Down' and 'To_Your_Back_Left' or
			angleName == 'Left_Up' and 'To_The_Left_Ahead' or
			angleName == 'Right_Down' and 'To_Your_Back_Right' or
			angleName == 'Right_Up' and 'To_The_Right_Ahead'
		arrow.Position = Display.Panels.Elevator.Label.Position
		arrow.ImageTransparency = 1
		arrow.Rotation = angle.Angle
		task.wait(.2)
		local tween = TweenService:Create(arrow, TweenInfo.new(.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { ImageTransparency = 0 })
		TweenService:Create(arrow, TweenInfo.new(.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = Display.Panels.Elevator.Label.Position+UDim2.new(angle.PositionOffset[1], 0, angle.PositionOffset[2]/1.5,0) }):Play()
		tween:Play()
		tween.Completed:Wait()
		for i=1,7 do
			local tween = TweenService:Create(arrow, TweenInfo.new(.15, Enum.EasingStyle.Linear, Enum.EasingDirection.In), { ImageTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			local tween = TweenService:Create(arrow, TweenInfo.new(.15, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { ImageTransparency = 0 })
			tween:Play()
			tween.Completed:Wait()
		end
	end

	local function KelvinsToFahrenheit(value)
		return math.floor((value-273.15)*(9/5)+32)
	end
	local function KelvinToCelsius(kelvin)
		return math.floor(kelvin-273.15)
	end

	-- Elevator handler --
	local function AllocateElevator(Floor: number, Direction: number)
		local Elevator = Allocator.Allocate(ThisFloor, Floor, Direction, source.Elevators:GetChildren())
		if not Elevator then return end

		local ElevName = string.split(Elevator.Name, config.Car_Name_Split)[2]
		Display.Panels.Elevator.Label.Text = tostring(ElevName)
		Display.Panels.Elevator.Floor.Text = `to floor {Floor}`
		local LastPanel
		for i, v in Display.Panels:GetChildren() do
			if v.Visible then
				LastPanel = v.Name
				break
			end
		end
		local Tween = TweenService:Create(Display.Bottom.Transition, TweenInfo.new(.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Offset = Vector2.new(-2, 0) })
		Tween:Play()
		Tween.Completed:Once(function()
			if Tween.PlaybackState ~= Enum.PlaybackState.Completed then return end

			Display.Bottom.Visible = false
		end)

		HandicapDisabled = true
		SwitchToPanel('Elevator')
		
		API:Fire('Elevator_Allocated', { Elevator = Elevator, Elev_Name = ElevName, Call_Floor = ThisFloor, Destination = Floor, Call_Direction = Direction })

		Elevator.API:Fire('AddHallCall', { call = ThisFloor, direction = Direction })
		task.wait()
		if (Elevator.Values.Floor.Value == ThisFloor and (Elevator.Values.Move_Direction.Value == 0 or Elevator.Values.Leveling.Value)) then
			Elevator.API:Fire('AddCarCall', { call = Floor })
		else
			local Connection: RBXScriptConnection
			Connection = Elevator.API.Event:Connect(function(protocol, params)
				if protocol == 'on_call_respond' and params.floor == ThisFloor then
					Connection:Disconnect()
					Connection = nil
					Elevator.API:Fire('AddCarCall', { call = Floor })
				end
			end)
		end

		local elevatorLanding = Elevator:FindFirstChild('Floors') and Elevator.Floors:FindFirstChild(`Floor_{ThisFloor}`)
		if elevatorLanding then
			elevatorLanding = elevatorLanding:FindFirstChild('Level')
		end
		local elevatorPos = Vector3.new(elevatorLanding.Position.X, Screen.Position.Y, elevatorLanding.Position.Z)
		--Get the dimensional attachment to calculate which one to point towards
		local dist = math.huge
		local chosenAttachment
		for i,v in dimensionalAttachments do
			if ((elevatorPos-v.WorldPosition).Magnitude <= dist) then
				dist = (elevatorPos-v.WorldPosition).Magnitude
				chosenAttachment = v
			end
		end
		if chosenAttachment then
			pointArrowTo(chosenAttachment, ElevName)
		end
		task.wait(2)
		Display.Bottom.Visible = true
		local Tween = TweenService:Create(Display.Bottom.Transition, TweenInfo.new(.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Offset = Vector2.new(2, 0) })
		Tween:Play()
		SwitchToPanel(LastPanel)
		HandicapDisabled = false
	end
	--

	-- Button input handler function
	local function HandleButtonInput(Button: Frame, Callback: any)

		-- Tweens
		local HoverTweens = {
			TweenService:Create(Button, TweenInfo.new(.145, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1) }),
			if Button:FindFirstChild('Label') then TweenService:Create(Button.Label, TweenInfo.new(.145, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = Color3.new(0, 0, 0) }) else nil,
			if Button:FindFirstChild('Icon') then TweenService:Create(Button.Icon, TweenInfo.new(.145, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {ImageColor3 = Color3.new(0, 0, 0) }) else nil,

			TweenService:Create(Button.UIScale, TweenInfo.new(.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = 1.075 }),
		}

		local ReleaseTweens = {
			TweenService:Create(Button, TweenInfo.new(.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { BackgroundTransparency = Button.BackgroundTransparency, BackgroundColor3 = Button.BackgroundColor3 }),
			if Button:FindFirstChild('Label') then TweenService:Create(Button.Label, TweenInfo.new(.145, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextColor3 = Button.Label.TextColor3 }) else nil,
			if Button:FindFirstChild('Icon') then TweenService:Create(Button.Icon, TweenInfo.new(.145, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {ImageColor3 = Button.Icon.ImageColor3 }) else nil,

			TweenService:Create(Button.UIScale, TweenInfo.new(.225, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }),
		}

		if Button.Button:GetAttribute('Disabled') then
			Button.BackgroundTransparency = .9
			Button.Label.TextTransparency = .65
			Button.Icon.ImageTransparency = .65
			Button.UIStroke.Transparency = .65
		end
		Button.Button:GetAttributeChangedSignal('Disabled'):Connect(function()
			Button.BackgroundTransparency = Button.Button:GetAttribute('Disabled') and .9 or .75
			Button.Label.TextTransparency = Button.Button:GetAttribute('Disabled') and .65 or 0
			Button.Icon.ImageTransparency = Button.Button:GetAttribute('Disabled') and .65 or 0
			Button.UIStroke.Transparency = Button.Button:GetAttribute('Disabled') and .65 or 0
		end)

		Button:GetAttributeChangedSignal('Highlight'):Connect(function()
			for i, v in Button:GetAttribute('Highlight') and HoverTweens or ReleaseTweens do
				v:Play()
			end
		end)

		Button.Button.MouseButton1Click:Connect(function()
			if Button.Button:GetAttribute('Debounce') or Button.Button:GetAttribute('Disabled') then return end

			Button.Button:SetAttribute('Debounce', true)
			Button:SetAttribute('Highlight', true)
			task.delay(.225, function()
				Button.Button:SetAttribute('Debounce', nil)
				Button:SetAttribute('Highlight', false)
			end)
			if typeof(Callback) == 'function' then
				local ran, res = pcall(Callback)
				if not ran then return error(res) end
			end
		end)

	end
	--
	
	local function ChangeTitleText(instance: Instance, text: string)
		local Tween = TweenService:Create(instance, TweenInfo.new(.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { TextTransparency = 1 })
		Tween:Play()
		Tween.Completed:Wait()
		instance.Text = text
		local Tween = TweenService:Create(instance, TweenInfo.new(.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { TextTransparency = 0 })
		Tween:Play()
	end
	
	-- Pin prompt handler --
	
	local InputSignal = Signal.new()
	local EntryDisabled = false
	local PinEntry = ''
	
	local function PromptPinEntry(Callback: any)
		EntryDisabled = false
		local PreviousFrame = CurrentFrame
		SwitchToPanel('Pin', 'add')
		if typeof(Callback) ~= 'function' then return end
		
		local Result = InputSignal:Wait()
		if Result ~= 'accept' then
			print(BackPageEntries)
			local Index = table.find(BackPageEntries, 'Pin')
			if Index then
				BackPageEntries[Index] = nil
			end
			return SwitchToPanel(PreviousFrame, 'remove')
		end
		Callback(Result)
	end
	
	for i, v in Display.Panels.Pin.List:GetDescendants() do
		if not v:FindFirstChild('Button') then continue end
		
		HandleButtonInput(v, function()
			if EntryDisabled then return end
			
			if v.Name == 'Enter' then
				if tonumber(PinEntry) ~= config.Access_Config.Pin then
					EntryDisabled = true
					PinEntry = ''
					Display.Panels.Pin.Input.Text = ''
					local PrevText = Display.Panels.Pin.Title.Text
					ChangeTitleText(Display.Panels.Pin.Title, 'invalid PIN')
					task.wait(1)
					ChangeTitleText(Display.Panels.Pin.Title, PrevText)
					InputSignal:Fire('decline')
					return
				end
				EntryDisabled = true
				PinEntry = ''
				Display.Panels.Pin.Input.Text = ''
				InputSignal:Fire('accept')
			elseif v.Name == '-' and string.len(PinEntry) > 0 then
				PinEntry = string.sub(PinEntry, 1, string.len(PinEntry)-1)
			else
				PinEntry = `{PinEntry}{v.Name}`
			end
			Display.Panels.Pin.Input.Text = string.rep('*', string.len(PinEntry))
		end)
	end
	--

	-- Floow selection handler
	local function GenerateRowFrame(index: number)
		local CurrentRowFrame: Frame = Dependencies.Row:Clone()
		CurrentRowFrame.LayoutOrder = index
		CurrentRowFrame.Name = tostring(index)
		CurrentRowFrame.Parent = Display.Panels.Floor_Selection.Content.List
		return CurrentRowFrame
	end

	local CurrentRowFrame: Frame
	for i, v in Floors do
		local buttonStyle = buttonStyles[tostring(v)]
		if (not CurrentRowFrame) or buttonStyle == 'Main' then
			CurrentRowFrame = GenerateRowFrame(v)
		end
		local Button = Dependencies.Floor_Button:Clone()
		Button.Name = v
		Button.LayoutOrder = v
		Button.Icon.Visible = v == config.GroundFloor

		if v == ThisFloor then
			Button.Button:SetAttribute('Disabled', true)
		end

		Button.Label.Text = if customLabels[tostring(v)] then
			if buttonStyle  == 'Main' then
			customLabels[tostring(v)].FullLabel
			else
			customLabels[tostring(v)].ShortLabel
		else tostring(v)
			Button.Parent = CurrentRowFrame

			if buttonStyle then
				if buttonStyle == 'Double' then
					Button.UIAspectRatioConstraint.AspectRatio = 2.15
				elseif buttonStyle == 'Main' then
					Button.UIAspectRatioConstraint:Destroy()
					--CurrentRowFrame = Dependencies.Row:Clone()
					--CurrentRowFrame.LayoutOrder = v
					--CurrentRowFrame.Name = v
					--CurrentRowFrame.Parent = Display.Panels.Floor_Selection.Content.List
					--Button.Parent = CurrentRowFrame
				end
			end

			HandleButtonInput(Button, function()
				AllocateElevator(v, v > ThisFloor and 1 or -1)
			end)

			if CurrentRowFrame.UIListLayout.AbsoluteContentSize.X > CurrentRowFrame.AbsoluteSize.X/1.5 then
				CurrentRowFrame = nil
			end
		end
		--

		-- Keypad

		Display.Panels.Keypad.Input.Text = ''

		local KeypadRegisterDelay: thread
		local KeypadDisabled = false

		local function KeypadDelay()
			if KeypadRegisterDelay then
				pcall(task.cancel, KeypadRegisterDelay)
			end
			KeypadRegisterDelay = task.delay(2, function()
				KeypadRegisterDelay = nil
				KeypadDisabled = true
				local Num = tonumber(Display.Panels.Keypad.Input.Text)
				local PrevText = Display.Panels.Keypad.Title.Text
				if not Num then
					Display.Panels.Keypad.Input.Text = '???'
					ChangeTitleText(Display.Panels.Keypad.Title, 'unknown entry')
					task.wait(1.5)
					Display.Panels.Keypad.Input.Text = ''
					KeypadDisabled = false
					ChangeTitleText(Display.Panels.Keypad.Title, PrevText)
					return
				end
				warn(`Final input: {Display.Panels.Keypad.Input.Text}`)
				local Elevator = AllocateElevator(Num, Num > ThisFloor and 1 or -1)
				if not Elevator then
					Display.Panels.Keypad.Input.Text = '---'
					ChangeTitleText(Display.Panels.Keypad.Title, 'no elevator found')
					task.wait(1.5)
					Display.Panels.Keypad.Input.Text = ''
					KeypadDisabled = false
					ChangeTitleText(Display.Panels.Keypad.Title, PrevText)
					return
				end
				Display.Panels.Keypad.Input.Text = ''
				KeypadDisabled = false
			end)
		end
		for i, v in Display.Panels.Keypad.List:GetDescendants() do
			if not v:FindFirstChild('Button') then continue end

			if v.Name == '*' and ThisFloor == config.GroundFloor then
				v.Button:SetAttribute('Disabled', true)
			end

			HandleButtonInput(v, function()
				if KeypadDisabled then return end

				local Input = tonumber(v.Name)

				if Input and string.len(Display.Panels.Keypad.Input.Text) < 4 then
					Display.Panels.Keypad.Input.Text = `{Display.Panels.Keypad.Input.Text}{Input}`
					KeypadDelay()
				elseif v.Name == '-' then
					if string.len(Display.Panels.Keypad.Input.Text) > 0 then
						Display.Panels.Keypad.Input.Text = string.sub(Display.Panels.Keypad.Input.Text, 1, string.len(Display.Panels.Keypad.Input.Text)-1)
						KeypadDelay()
					else
						Display.Panels.Keypad.Input.Text = '-'
					end
				elseif string.len(Display.Panels.Keypad.Input.Text) == 0 and v.Name == '*' then
					warn('Ground floor selected')
					Display.Panels.Keypad.Input.Text = ''
					AllocateElevator(config.GroundFloor, config.GroundFloor > ThisFloor and 1 or -1)
				end
			end)
		end
		--

		-- Home buttons
		for i, v in Display.Panels.Home.Buttons:GetChildren() do
			if not v:FindFirstChild('Button') then continue end

			HandleButtonInput(v, function()
				Display.Bottom.Visible = true
				local Tween = TweenService:Create(Display.Bottom.Transition, TweenInfo.new(.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Offset = Vector2.new(2, 0) })
				Tween:Play()
				
				if v.Name == 'Admin_Panel' then
					local LastFrame = CurrentFrame
					return PromptPinEntry(function(access: string)
						if access ~= 'accept' then return SwitchToPanel(CurrentFrame) end
						
						SwitchToPanel(v.Name, 'add')
					end)
				end

				SwitchToPanel(v.Name, 'add')
			end)
		end
		--
		-- Panels reset
		for i, f in Display.Panels:GetChildren() do
			local Gradient = f:FindFirstChild('Transition')
			if not Gradient then continue end

			f.Visible = f.Name == 'Home'
			Gradient.Offset = Vector2.new(f.Name == 'Home' and 2 or -2, 0)
		end
		--

		-- Bottom back arrow
		Display.Bottom.Back.MouseButton1Click:Connect(function()
			local ThisPage, LastPage = BackPageEntries[#BackPageEntries], BackPageEntries[#BackPageEntries-1]
			local Index = table.find(BackPageEntries, ThisPage)
			if Index then
				BackPageEntries[Index] = nil
			end
			if LastPage then
				SwitchToPanel(LastPage, 'remove')
			else
				local Tween = TweenService:Create(Display.Bottom.Transition, TweenInfo.new(.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Offset = Vector2.new(-2, 0) })
				Tween:Play()
				if KeypadRegisterDelay then
					pcall(task.cancel, KeypadRegisterDelay)
				end
				KeypadRegisterDelay = nil
				Display.Panels.Keypad.Input.Text = ''
				Tween.Completed:Once(function()
					if Tween.PlaybackState ~= Enum.PlaybackState.Completed then return end

					Display.Bottom.Visible = false
				end)

				SwitchToPanel('Home')
			end
		end)

		for i, v in Display.Panels.Admin_Panel.Buttons:GetChildren() do
			if not v:FindFirstChild('Button') then continue end

			HandleButtonInput(v, function()
				SwitchToPanel(v.Name, 'add')
			end)
		end

		for i, v in Floors do
			local LockoutButton = Dependencies.Floor_Lock_Button:Clone()
			LockoutButton.Name = `Floor_{v}`
			LockoutButton.Label.Text = customLabels[tostring(v)] and customLabels[tostring(v)].ShortLabel or tostring(v)
			LockoutButton.LayoutOrder = 1000000-v
			LockoutButton.Parent = Display.Panels.Config_Panel.Content.List.Floor_Locking.Entry_Contents.List
		end

		for i, v in Display.Panels.Config_Panel.Content.List:GetDescendants() do
			local EntryContents = v:FindFirstChild('Entry_Contents')
			if EntryContents then
				EntryContents.Visible = true
				EntryContents.Size = UDim2.new(1, 50, 0, 50000)
			end
			if v:FindFirstChild('Button') then
				local RootFrame = Instance.new('Frame')
				RootFrame.BackgroundTransparency = 1
				RootFrame.Name = `Root_{v.LayoutOrder}`
				RootFrame.LayoutOrder = v.LayoutOrder
				RootFrame.Size = UDim2.fromOffset(v.AbsoluteSize.X, v.AbsoluteSize.Y)
				RootFrame.Parent = v.Parent
				v.Parent = RootFrame
				v.AnchorPoint = Vector2.new(.5, 0)
				v.Position = UDim2.new(0.5, 0, 0, 0)
				v.Size = RootFrame.Size
				if EntryContents then
					EntryContents.GroupTransparency = 1
					EntryContents.UIStroke.Transparency = 1
					EntryContents:SetAttribute('IsOpen', false)
					RootFrame:SetAttribute('ExpandSize', UDim2.new(0, RootFrame.Size.X.Offset, 0, RootFrame.Size.Y.Offset+EntryContents:GetAttribute('ExpandSize')))
					RootFrame:SetAttribute('NormalSize', RootFrame.Size)
				end

				HandleButtonInput(v, function()
					if EntryContents then
						if not EntryContents:GetAttribute('IsOpen') then
							EntryContents.Size = UDim2.new(1, 50, 0, 0)
						end
						EntryContents:SetAttribute('IsOpen', not EntryContents:GetAttribute('IsOpen'))
						TweenService:Create(EntryContents, TweenInfo.new(EntryContents:GetAttribute('IsOpen') and .5 or .265, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 50, 0, EntryContents:GetAttribute('IsOpen') and EntryContents:GetAttribute('ExpandSize') or 0), GroupTransparency = EntryContents:GetAttribute('IsOpen') and 0 or 1 }):Play()
						TweenService:Create(EntryContents.UIStroke, TweenInfo.new(EntryContents:GetAttribute('IsOpen') and .5 or .265, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Transparency = EntryContents:GetAttribute('IsOpen') and 0.5 or 1 }):Play()
						TweenService:Create(RootFrame, TweenInfo.new(EntryContents:GetAttribute('IsOpen') and .5 or .265, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = EntryContents:GetAttribute('IsOpen') and RootFrame:GetAttribute('ExpandSize') or RootFrame:GetAttribute('NormalSize') }):Play()
					end
				end)
				if v.Name == 'City' then
					EntryContents.Input:GetPropertyChangedSignal('Text'):Connect(function()
						warn('Text updated')
						require(ConfigModule).WeatherServer.City = EntryContents.Input.Text
					end)
				end
			end
			if v:FindFirstChild('R1') then
				v:GetAttributeChangedSignal('IsSelected'):Connect(function()
					TweenService:Create(v.R1.Fill, TweenInfo.new(.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromScale( v:GetAttribute('IsSelected') and 1 or 0, v:GetAttribute('IsSelected') and 1 or 0 )-UDim2.fromOffset(15, 15), BackgroundTransparency = v:GetAttribute('IsSelected') and 0 or 1 }):Play()
				end)
				v.Btn.MouseButton1Click:Connect(function()
					for i, b in v.Parent:GetChildren() do
						if not b:FindFirstChild('R1') then continue end
						
						b:SetAttribute('IsSelected', b.Name == v.Name)
						
						require(ConfigModule).WeatherServer.Temp = v.Name
						local attr = script.Parent:GetAttribute('Temp')
						script.Parent:SetAttribute('Temp', nil)
						script.Parent:SetAttribute('Temp', attr)
					end
				end)
				v:SetAttribute('IsSelected', v.Name == config.WeatherServer.Temp)
			end
		end

		Display.Bottom.Visible = false
		--

		-- Handle handicap button
		local HighlightedButton
		local IterationThread: thread
		HandicapBtn.DragStart:Connect(function()
			This.Handicap_Button.Button:SetAttribute('Pressed', true)

			if HandicapDisabled and HighlightedButton then
				for i, b in Display.Panels.Floor_Selection.Content.List:GetDescendants() do
					if (not tonumber(b.Name)) or not b:FindFirstChild('Button') or b.Button:GetAttribute('Disabled') then continue end

					b:SetAttribute('Highlight', false)
				end
				local Floor = tonumber(HighlightedButton.Name)
				if IterationThread then
					pcall(task.cancel, IterationThread)
				end
				IterationThread = nil
				HighlightedButton = nil
				local Elevator = AllocateElevator(Floor, Floor > ThisFloor and 1 or -1)
				if not Elevator then
					HandicapDisabled = false
					Display.Bottom.Visible = true
					local Tween = TweenService:Create(Display.Bottom.Transition, TweenInfo.new(.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Offset = Vector2.new(2, 0) })
					Tween:Play()
					return
				end
			end

			if HandicapDisabled then return end

			HandicapDisabled = true
			if KeypadRegisterDelay then
				pcall(task.cancel, KeypadRegisterDelay)
			end
			KeypadRegisterDelay = nil
			SwitchToPanel('Floor_Selection')
			task.wait(1)

			local FloorsList = {}
			for i, v in Display.Panels.Floor_Selection.Content.List:GetChildren() do
				for i, b in v:GetChildren() do
					if (not tonumber(b.Name)) or not b:FindFirstChild('Button') or b.Button:GetAttribute('Disabled') then continue end

					FloorsList[#FloorsList+1] = b
				end
			end

			IterationThread = task.spawn(function()
				for i = 1, #FloorsList do
					local button = FloorsList[i]

					for i, v in FloorsList do
						v:SetAttribute('Highlight', button == v)
					end
					HighlightedButton = button
					task.wait(2)
				end
				for i, v in FloorsList do
					v:SetAttribute('Highlight', false)
				end
				IterationThread = nil
				HandicapDisabled = false
				Display.Bottom.Visible = true
				local Tween = TweenService:Create(Display.Bottom.Transition, TweenInfo.new(.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Offset = Vector2.new(2, 0) })
				Tween:Play()
			end)
		end)
		HandicapBtn.DragEnd:Connect(function()
			This.Handicap_Button.Button:SetAttribute('Pressed', false)
		end)
		--

		-- Weather updater
		if not script.Parent:GetAttribute('Icon') then
			script.Parent:GetAttributeChangedSignal('Icon'):Wait()
		end
		Display.Panels.Home.Weather.Info.Icon.Image = script.Parent:GetAttribute('Icon')
		Display.Panels.Home.Weather.Info.Temp.Text = `{require(ConfigModule).WeatherServer.Temp == 'F' and KelvinsToFahrenheit(script.Parent:GetAttribute('Temp')) or KelvinToCelsius(script.Parent:GetAttribute('Temp'))}°{require(ConfigModule).WeatherServer.Temp}`
		Display.Panels.Home.Weather.City_Name.Text = script.Parent:GetAttribute('City')
		script.Parent:GetAttributeChangedSignal('Icon'):Connect(function()
			Display.Panels.Home.Weather.Info.Icon.Image = script.Parent:GetAttribute('Icon')
		end)
		script.Parent:GetAttributeChangedSignal('Temp'):Connect(function()
			print(require(ConfigModule).WeatherServer.Temp)
			Display.Panels.Home.Weather.Info.Temp.Text = `{require(ConfigModule).WeatherServer.Temp == 'F' and KelvinsToFahrenheit(script.Parent:GetAttribute('Temp')) or KelvinToCelsius(script.Parent:GetAttribute('Temp'))}°{require(ConfigModule).WeatherServer.Temp}`
		end)
		script.Parent:GetAttributeChangedSignal('City'):Connect(function()
			Display.Panels.Home.Weather.City_Name.Text = script.Parent:GetAttribute('City')
		end)
		--

		return self

	end

	return module