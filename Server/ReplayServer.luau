--!strict
--!optimize 2
--!native
--[=[
	ReplayServer.luau | Author: @exwrdss
]=]

-- // Loaded Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PlayersService = game:GetService("Players")

-- // Dependencies
local BufferUtil = require("../Shared/BufferUtil")
local Types = require("../Shared/Types")
local Cloud = require("./Cloud")

-- // Session Handler
local DeltaAccumalator = 0;
local FPS_Rate = 1 / BufferUtil.FPS_RATE;
local RecordingSessionsHandler: {[Player]: Types.ReplayRecordingData} = {}

-- // Native Function Cache
local ItterateDict = pairs;
local OrderItterateDict = ipairs;
local FrameToBuffer = BufferUtil.FrameToBuffer;

-- // Funcs

local function StartRecording(player: Player, mapData: Types.ReplayMapData)
	if not Cloud.CanSaveReplayBuffer(player) then return; end
	if RecordingSessionsHandler[player] then return; end
	
	local recordingSession = BufferUtil.CreateReplayBuffer(mapData, player)
	RecordingSessionsHandler[player] = recordingSession;
	print("started")
end

local function StopRecording(player: Player)
	local recording_session = RecordingSessionsHandler[player]
	if not recording_session then
		return;
	end
	
	recording_session.StopRecording = true;
end

-- // Recording Session Daemon

RunService.Heartbeat:Connect(function(deltaTime: number)
	DeltaAccumalator += deltaTime;
	while DeltaAccumalator >= FPS_Rate do
		for player, recordingSession in ItterateDict(RecordingSessionsHandler) do
			if recordingSession.StopRecording then
				task.spawn(Cloud.SaveReplayBuffer, player, recordingSession.ReplayBuffer)
				RecordingSessionsHandler[player] = nil;
				return;
			end

			local cframes = {}
			for insertIndex, recordPart in OrderItterateDict(recordingSession.RecordParts) do
				cframes[insertIndex] = recordPart.CFrame
			end

			recordingSession.BytesOffset = FrameToBuffer(recordingSession.ReplayBuffer, recordingSession.BytesOffset, cframes)
			recordingSession.StopRecording = recordingSession.BytesOffset >= recordingSession.MaxSize;
		end

		DeltaAccumalator -= FPS_Rate
	end
end)

-- // Player Connections

PlayersService.PlayerRemoving:Connect(function(remPlayer: Player)
	local recordingSession = RecordingSessionsHandler[remPlayer]
	if not recordingSession then
		return;
	end

	recordingSession.StopRecording = true;
	Cloud.CanSaveReplayCache[remPlayer] = nil;
end)

return {
	StartRecording = StartRecording,
	StopRecording = StopRecording
}