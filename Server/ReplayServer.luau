--!strict
--!optimize 2
--!native
--[=[
	ReplayServer.luau | Author: @exwrdss
]=]

-- // Loaded Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local PlayersService = game:GetService("Players")

-- // Dependencies
local BufferUtil = require("../Shared/BufferUtil")
local Config = require("../Config")
local Types = require("../Shared/Types")

-- // Session Handler
local DeltaAccumalator = 0;
local FPS_Rate = 1 / BufferUtil.FPS_RATE;
local RecordingSessionsHandler: {[Player]: Types.ReplayRecordingData} = {}

-- // Native Function Cache
local Yeild = task.wait;
local ImmediateNewTask = task.spawn;
local ProectedFunctionCall = pcall;
local Table_Insert = table.insert;
local ItterateDict = pairs;
local OrderItterateDict = ipairs;
local FrameToBuffer = BufferUtil.FrameToBuffer;

-- // Module Table
local ReplayServer = {}

-- // DataStore
local CanSaveReplayCache: Types.ReplayCacheType = setmetatable({}, {__mode = "k"})
local ReplayBufferStore = DataStoreService:GetDataStore("ReplayBufferStore_V" .. Config.Version)

-- // Data Funcs

local function ValidateCache(player: Player, cache: Types.PlayerCache)
	local cacheTimeElapsed = os.time() - cache.CacheUnixTimestamp
	if cacheTimeElapsed > Config.CacheExpiryTime then
		CanSaveReplayCache[player] = nil; -- cache expired, remove entry
		return false;
	end
	
	return true;
end

local function GetRecentReplayBuffers(): (boolean, {buffer})
	local listSuccess, dataStoreKeyPages = ProectedFunctionCall(ReplayBufferStore.ListKeysAsync, ReplayBufferStore, nil, nil, nil, true)
	if not listSuccess or not dataStoreKeyPages then
		return false, "API Fetch failed." :: any
	end

	local recentReplayBuffers = {}
	local pages = dataStoreKeyPages:GetCurrentPage()
	local tasksLeft = #pages
	
	for _, dataStoreKey: DataStoreKey in ItterateDict(pages) do
		ImmediateNewTask(ProectedFunctionCall, ReplayBufferStore.UpdateAsync, ReplayBufferStore, dataStoreKey.KeyName, function(exisitingData: {buffer})
			if not exisitingData then
				exisitingData = {}
			else
				Table_Insert(recentReplayBuffers, exisitingData[#exisitingData])
			end
			
			tasksLeft -= 1;
			return exisitingData;
		end)
	end
	
	while tasksLeft > 0 do Yeild() end
	
	return true, recentReplayBuffers
end

local function CanSaveReplayBuffer(player: Player)
	local exisitingCache = CanSaveReplayCache[player]
	if exisitingCache and ValidateCache(player, exisitingCache) then
		return exisitingCache.CanSave;
	end
	
	local canSave: boolean
	
	local saveSuccess, errCallback = ProectedFunctionCall(ReplayBufferStore.UpdateAsync, ReplayBufferStore, player.UserId, function(exisitingData: {buffer})
		if not exisitingData then
			exisitingData = {}
		end
		
		canSave = Config.MaxReplaysPerPlayer > #exisitingData
		return exisitingData;
	end)
	
	return canSave;
end

local function SaveReplayBuffer(player: Player, replayBuffer: buffer): (boolean)
	local saveSuccess, errCallback = ProectedFunctionCall(ReplayBufferStore.UpdateAsync, ReplayBufferStore, player.UserId, function(exisitingData: {buffer})
		if not exisitingData then
			exisitingData = {}
		end
		
		table.insert(exisitingData, replayBuffer)
		return exisitingData
	end)
	
	return saveSuccess
end 

-- // Funcs

local function StartRecording(player: Player, mapData: Types.MapData)
	if not CanSaveReplayBuffer(player) then return; end
	
	local recordingSession = BufferUtil.CreateReplayBuffer(mapData, player)
	RecordingSessionsHandler[player] = recordingSession;
end

-- // Recording Session Daemon

RunService.Heartbeat:Connect(function(deltaTime: number)
	DeltaAccumalator += deltaTime;
	if (DeltaAccumalator < FPS_Rate) then return; end
	DeltaAccumalator = 0;
	
	for player, recordingSession in ItterateDict(RecordingSessionsHandler) do
		if recordingSession.StopRecording then
			task.spawn(SaveReplayBuffer, player, recordingSession.ReplayBuffer)
			RecordingSessionsHandler[player] = nil;
			return;
		end
		
		local cframes = {}
		for insertIndex, recordPart in OrderItterateDict(recordingSession.RecordParts) do
			Table_Insert(cframes, insertIndex, recordPart.CFrame)
		end
		
		recordingSession.BytesOffset = FrameToBuffer(recordingSession.ReplayBuffer, recordingSession.BytesOffset, cframes)
		recordingSession.StopRecording = recordingSession.BytesOffset >= recordingSession.MaxSize;
	end
end)

-- // Player Connections

PlayersService.PlayerRemoving:Connect(function(remPlayer: Player)
	local recordingSession = RecordingSessionsHandler[remPlayer]
	if not recordingSession then
		return;
	end
	
	recordingSession.StopRecording = true;
	CanSaveReplayCache[remPlayer] = nil;
end)

return {
	GetRecentReplayBuffers = GetRecentReplayBuffers,
	StartRecording = StartRecording,
}