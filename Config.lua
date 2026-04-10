--!strict
--[=[
	Config.luau | Author: @exwrdss
]=]

-- // Loaded Services
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

-- // Constant Variables
local REPLAY_COLLISION_GROUP = (function()
	local collisionGroupName = "ReplayParts"

	if RunService:IsServer() then
		if not PhysicsService:IsCollisionGroupRegistered(collisionGroupName) then
			PhysicsService:RegisterCollisionGroup(collisionGroupName)
		end

		local registeredGroups = PhysicsService:GetRegisteredCollisionGroups()
		for _, groupData in pairs(registeredGroups) do
			local groupName = groupData.name;
			if not groupName then continue; end

			PhysicsService:CollisionGroupSetCollidable(collisionGroupName, groupName, false)
		end
	end

	return collisionGroupName;
end)()

return {
	ReplaysRecordingsPerThread = 3,
	MaxReplaysPerPlayer = 3,
	Version = 1.2,
	CacheExpiryTime = 60 * 2,
	ReplayCollisionGroup = REPLAY_COLLISION_GROUP
}