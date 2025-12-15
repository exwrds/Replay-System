--!strict
--!optimize 2
--!native
--[=[
	ReplayClient.luau | Author: @exwrdss
]=]

-- // Loaded Serivces
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local PlayersService = game:GetService("Players")

-- // Dependencies
local Types = require("../Shared/Types")
local BufferUtil = require("../Shared/BufferUtil")
local Config = require("../Config")

-- // Module Table
local ReplayClient = {}
ReplayClient.__index = ReplayClient

-- // Public Funcs

local function CreateReplayPlayer(replayMetadata: Types.ReplayMetaData): Types.ReplayPlayer
	assert(replayMetadata, "No Replay MetaData received!")
	
	local replayPlayer = {}
	
	replayPlayer.ReplayMetaData = replayMetadata
	replayPlayer.BytesOffset = replayMetadata.BytesOffset
	
	replayPlayer.HasFinished = false
	replayPlayer.IsPlaying = false
	replayPlayer.HasStarted = false
	
	local recordParts = {}
	
	local replayCharacter = Types.TemplateCharacter:Clone()
	replayCharacter.Name = "ReplayCharacter"
	
	for _, bodyPart in ipairs(replayCharacter:GetChildren()) do
		if not bodyPart:IsA("BasePart") then continue; end
		local insertIndex = table.find(BufferUtil.BODY_PARTS, bodyPart.Name)
		if not insertIndex then continue; end
		
		recordParts[insertIndex] = bodyPart :: Part
		
		bodyPart.Anchored = true
		bodyPart.CanCollide = false
		bodyPart.CollisionGroup = Config.ReplayCollisionGroup
	end
	
	replayPlayer.ReplayCharacter = replayCharacter
	replayCharacter.Parent = workspace
	replayPlayer.ReplayParts = recordParts
	
	local initCframes = BufferUtil.BufferToFrame(replayPlayer.ReplayMetaData.ReplayBuffer, replayPlayer.BytesOffset)
	for i, bodyPart in ipairs(recordParts) do
		bodyPart.CFrame = initCframes[i];
	end
	
	setmetatable(replayPlayer, ReplayClient)

	task.spawn(replayPlayer.UpdateReplayPlayerAppearanceAsync, replayPlayer :: any)
	return replayPlayer :: any;
end

local function OnNewBuffersReceived(buffersReceived: {buffer}) -- unused, you can do what you want with this
	if not buffersReceived then return; end

	local converted = {}
	for _, replayBuffer in pairs(buffersReceived) do
		local metadata = BufferUtil.ReadReplayBuffer(replayBuffer)
		if not metadata then continue; end
		table.insert(converted, metadata)
	end
	
	return converted
end

-- // Method Funcs

function ReplayClient:UpdateReplayPlayerAppearanceAsync(): Types.ReplayPlayer
	-- you cannot apply a HumanoidDescription if the parent is not a WorldRoot.
	if not self.ReplayCharacter.Parent or self.ReplayCharacter.Parent:IsA("WorldRoot") then
		local exitLoop: boolean
		local yeildStart = time()
		
		while time() - yeildStart < 3 do
			exitLoop = self.ReplayCharacter.Parent and (self.ReplayCharacter.Parent:IsA("WorldRoot")) or false
			if exitLoop then
				break;
			end

			task.wait()
		end
		
		if not exitLoop then
			warn("ReplayPlayer:UpdateReplayPlayerAppearanceAsync() failed; ReplayCharacter parent needs to be a WorldRoot.")
			return self;
		end
	end
	
	local getSuccess, appearanceInfo = pcall(PlayersService.GetHumanoidDescriptionFromUserIdAsync, PlayersService, self.ReplayMetaData.UserID :: any)
	if not getSuccess or not appearanceInfo then
		warn("ReplayPlayer:UpdateReplayPlayerAppearance() failed; CharacterAppearance could not be retrieved.")
		return self;
	end

	pcall(self.ReplayCharacter.Humanoid.ApplyDescriptionAsync :: any, self.ReplayCharacter.Humanoid, appearanceInfo)
	return self;
end

function ReplayClient:CreateHeartbeatConnection(): Types.ReplayPlayer
	if self.HeartbeatConnection then
		warn("ReplayPlayer:CreateHeartbeatConnection() failed; Can not create a hearbeat connection when one already exists.");
		return self;
	end
	
	self.IsPlaying = true
	
	-- variables for locking delta
	local deltaAccumalator = 0;
	local fpsRate = 1 / self.ReplayMetaData.FrameRate :: any
	
	-- variables for faster cache lookup
	local replayBuffer = self.ReplayMetaData.ReplayBuffer
	local bufferToCframe = BufferUtil.BufferToFrame;
	local replayCharacter = self.ReplayCharacter
	local replayParts = self.ReplayParts;
	local orderItterateDict = ipairs;
	
	self.HeartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
		deltaAccumalator += deltaTime;
		while deltaAccumalator >= fpsRate do
			if self.BytesOffset >= self.ReplayMetaData.MaxSize then
				self:EndHeartbeatConnection()
				return;
			end

			local cframes: {CFrame}
			cframes, self.BytesOffset = bufferToCframe(replayBuffer, self.BytesOffset)

			for i, bodyPart in orderItterateDict(replayParts) do
				(bodyPart :: Part).CFrame = cframes[i]
			end
			
			deltaAccumalator -= fpsRate
		end
	end)
	
	return self;
end

function ReplayClient:EndHeartbeatConnection(_replayFinished): Types.ReplayPlayer
	if not self.HeartbeatConnection then
		warn("ReplayPlayer:EndHeartbeatConnection() failed; Can not end a Heartbeat connection which does not exist.")
		return self;
	end
	
	if _replayFinished then self.HasFinished = true; end
	
	self.IsPlaying = false
	self.HeartbeatConnection:Disconnect()
	self.HeartbeatConnection = nil :: any
	return self;
end

function ReplayClient:StartReplay(): Types.ReplayPlayer
	if self.HasStarted then
		warn("ReplayPlayer:StartReply() failed; Can not start replay when it has already started.")
		return self;
	end
	
	self.HasStarted = true
	self:CreateHeartbeatConnection()
	return self;
end

function ReplayClient:PauseReplay(): Types.ReplayPlayer
	if not self.IsPlaying then
		warn("ReplayPlayer:PauseReplay() failed; Can not pause replay when it is already pauses / has not started.")
		return self;
	end
	
	self:EndHeartbeatConnection()
	return self;
end

function ReplayClient:ResumeReplay(): Types.ReplayPlayer
	if self.IsPlaying then
		warn("ReplayPlayer:ResumeReplay() failed; Can not resume replay when it is already playing.")
		return self; 
	end
	
	self:CreateHeartbeatConnection()
	return self;
end

return {
	OnNewBuffersReceived = OnNewBuffersReceived,
	CreateReplayPlayerAsync = CreateReplayPlayer
}