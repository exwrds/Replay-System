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
local Cloud = require("@self/Cloud")
local ReplayRecorder = require("./ReplayRecorder") :: any

-- // State Variables
local RecordingStates: {[Player]: boolean} = {}

-- // Funcs

local function StartRecording(player_instance: Player, map_data: Types.ReplayMapData)
	if not Cloud.CanSaveReplayBuffer(player_instance) then return; end
	if RecordingStates[player_instance] then return; end
	
	local recorder_thread = ReplayRecorder.GetRecorderThreadForPlayer(player_instance, true)
	local recording_session = BufferUtil.CreateReplayBuffer(map_data, player_instance, recorder_thread)
	
	recorder_thread:SendMessage("StartRecording", recording_session)
	RecordingStates[player_instance] = true;
end

local function StopRecording(player_instance: Player)
	if not RecordingStates[player_instance] then return; end

	RecordingStates[player_instance] = nil

	local recorder_thread = ReplayRecorder.GetRecorderThreadForPlayer(player_instance)
	if recorder_thread then
		recorder_thread:SendMessage("StopRecording")
	end
end

-- // Player Connections

PlayersService.PlayerRemoving:Connect(function(removing_player: Player)
	Cloud.CanSaveReplayCache[removing_player] = nil;
	StopRecording(removing_player)
end)

return {
	RecordingStates = RecordingStates,
	StartRecording = StartRecording,
	StopRecording = StopRecording
}