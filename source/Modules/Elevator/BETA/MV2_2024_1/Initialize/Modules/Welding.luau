local module = {}

function module.weldPartsInModel(model: Instance | Model, mainPart: BasePart?, ignoreList: any, parent: Instance?)
	for i, v in model:GetDescendants() do
		if (not v:IsA('BasePart')) then continue end
		if (not mainPart) then mainPart = v end
		if (typeof(ignoreList) == 'table' and table.find(ignoreList, v)) then continue end
		if (v ~= mainPart) then
			local weld = Instance.new('Weld')
			weld.Name = `{v.Name}Weld`
			weld.Part0, weld.Part1 = mainPart, v
			weld.C0, weld.C1 = CFrame.new(), weld.Part1.CFrame:ToObjectSpace(weld.Part0.CFrame)
			weld.Parent = parent or mainPart
		end
		v.Anchored = false
	end
end

function module.weldParts(part0: BasePart, part1: BasePart, joinInPlace: boolean?, animatable: boolean?)
	local weld = animatable == true and Instance.new('Motor6D') or Instance.new('Weld')
	weld.Name = `{part0.Name}Weld`
	weld.Part0, weld.Part1 = part1, part0
	if (joinInPlace == true) then
		weld.C0, weld.C1 = CFrame.new(), weld.Part1.CFrame:ToObjectSpace(weld.Part0.CFrame)
	end
	weld.Parent = part0
	return weld
end

return module
