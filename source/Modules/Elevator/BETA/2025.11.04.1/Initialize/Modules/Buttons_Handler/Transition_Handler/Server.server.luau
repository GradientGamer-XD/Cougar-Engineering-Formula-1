local CollectionService = game:GetService('CollectionService')
local TweenService = game:GetService('TweenService')

script.Parent.Event.Event:Connect(function(data: { Part: BasePart, Active: boolean, Duration: number, EasingStyle: Enum.EasingStyle, EasingDirection: Enum.EasingDirection })
	if not data or not data.Part then return end
	
	TweenService:Create(data.Part, TweenInfo.new(data.Duration, data.EasingStyle, data.EasingDirection), { Transparency = data.Active == true and 0 or 1 }):Play()
end)