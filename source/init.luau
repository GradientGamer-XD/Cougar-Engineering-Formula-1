--[[


███╗░░░███╗░█████╗░██████╗░██╗░░░██╗██╗░░░░░██╗░░░██╗██╗░░██╗  ██╗░░░██╗██████╗░
████╗░████║██╔══██╗██╔══██╗██║░░░██║██║░░░░░██║░░░██║╚██╗██╔╝  ██║░░░██║╚════██╗
██╔████╔██║██║░░██║██║░░██║██║░░░██║██║░░░░░██║░░░██║░╚███╔╝░  ╚██╗░██╔╝░░███╔═╝
██║╚██╔╝██║██║░░██║██║░░██║██║░░░██║██║░░░░░██║░░░██║░██╔██╗░  ░╚████╔╝░██╔══╝░░
██║░╚═╝░██║╚█████╔╝██████╔╝╚██████╔╝███████╗╚██████╔╝██╔╝╚██╗  ░░╚██╔╝░░███████╗
╚═╝░░░░░╚═╝░╚════╝░╚═════╝░░╚═════╝░╚══════╝░╚═════╝░╚═╝░░╚═╝  ░░░╚═╝░░░╚══════╝
Published: August 7th, 2025

© 2026 Project MODULUX. All rights reserved.

Modulux V2 is a new-technology elevator controller, which focuses on efficiency, modularity & accuracy. It is open-source, user-friendly & free to use.
    Copyright (C) 2026  aaxtatious.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.


]]

local module = {}

local ServerScriptService = game:GetService('ServerScriptService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedFirst = game:GetService('ReplicatedFirst')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

local elevatorStorageFolder = ReplicatedStorage:FindFirstChild('MX_Elevator_Storage') or Instance.new('Folder')
elevatorStorageFolder.Name = 'MX_Elevator_Storage'
elevatorStorageFolder.Parent = ReplicatedStorage

local dtTimeValue: NumberValue = ReplicatedStorage:FindFirstChild('MXV2_DeltaTime') or Instance.new('NumberValue')
dtTimeValue.Name = 'MXV2_DeltaTime'
dtTimeValue.Parent = ReplicatedStorage

RunService.PreAnimation:Connect(function(dtTime: number)
	dtTimeValue.Value = dtTime
end)

module.ActiveControllers = {}

local dependencies = script:WaitForChild('Dependencies')

--players.PlayerAdded:Connect(function(player: Player)
--	local doorHandler = player:FindFirstChild('MX_Movement_Handler_Client')
--	if doorHandler then return end
--	doorHandler = dependencies.MX_Movement_Handler_Client:Clone()
--	doorHandler.Parent = player
--	doorHandler.Enabled = true
--end)
--for i, player in players:GetChildren() do
--	local doorHandler = player:FindFirstChild('MX_Movement_Handler_Client')
--	if doorHandler then continue end
--	doorHandler = dependencies.MX_Movement_Handler_Client:Clone()
--	doorHandler.Parent = player
--	doorHandler.Enabled = true
--end
local doorHandler = ReplicatedStorage:FindFirstChild('MX_Movement_Handler_Client')
if not doorHandler then
	doorHandler = dependencies.MX_Movement_Handler_Client:Clone()
	doorHandler.Parent = ReplicatedStorage
	doorHandler.Enabled = true
end

if #Players:GetChildren() == 0 then
	local doorHandler = ServerScriptService:FindFirstChild('MX_Movement_Handler_Server')
	if not doorHandler then
		doorHandler = dependencies.MX_Movement_Handler_Server:Clone()
		doorHandler.Parent = ServerScriptService
		doorHandler.Enabled = true
	end
end

function module.init_module(src, loader_meta)

	local mod = script.Modules:FindFirstChild(src)
	if not mod then return error(`MODULUX Loader : Branch module \'{src}\' not found!`) end
	local branch = mod:FindFirstChild(loader_meta.version.branch)
	if not branch then
		branch = 'Production'
		warn(`MODULUX Initialization Error : Branch '{loader_meta.version.branch}' is not found! Fallback version set to '{branch}'`)
	end

	local versionInstance = {['Name'] = loader_meta.version.version}
	local d = -math.huge
	if versionInstance.Name == 'latest' then
		for i, v in branch:GetChildren() do
			if not v:FindFirstChild('Meta') then continue end
			local meta = require(v.Meta)
			if meta.VersionNumber >= d and (meta.Key == '' or meta.Key == loader_meta.version.key) then
				d = meta.VersionNumber
				versionInstance = meta
			end
		end
	end

	local version = branch:FindFirstChild(versionInstance.Name)
	if not version then
		warn(`MODULUX Initialization Error : Version '{loader_meta.version.version}' is not found! Fallback version set to '{versionInstance.Name}' (latest)`)

		for i, v in branch:GetChildren() do
			if not v:FindFirstChild('Meta') then continue end
			local meta = require(v.Meta)
			if meta.VersionNumber >= d then
				d = meta.VersionNumber
				versionInstance = meta
			end
		end
		version = branch:FindFirstChild(versionInstance.Name)
	end
	local init = require(version.Initialize)
	local data = init.start(loader_meta.source, loader_meta.config, { branch =  branch.Name, version = versionInstance.Name}, loader_meta)
	if not module.ActiveControllers[tostring(data.id)] then
		module.ActiveControllers[tostring(data.id)] = init
	end

end

return module