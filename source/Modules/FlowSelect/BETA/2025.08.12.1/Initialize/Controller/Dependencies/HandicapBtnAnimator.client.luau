local TweenService = game:GetService('TweenService')

local Button = script.Parent
Button:GetAttributeChangedSignal('Pressed'):Connect(function()
	TweenService:Create(Button, TweenInfo.new(.085, Enum.EasingStyle.Linear), { CFrame = Button:GetAttribute('Pressed') and Button:GetAttribute('Press_In') or Button:GetAttribute('Press_Out') }):Play()
end)