--!strict
--!optimize 2
--!native
--[=[
	ReplayRecorder.luau | Author: @exwrdss
	
	This module allows for multiple threads to be used for recording.
]=]

-- // Loaded Serivces
local ServerScriptService = game:GetService("ServerScriptService")

-- // Depenedencies
local Types = require("../Shared/Types")
local Cloud = require("./ReplayServer/Cloud")

-- // References
local Buffer_Util = script.Parent.Parent.Shared.BufferUtil;
local Template_Actor = script.RecorderThread_;

-- // 
local RECORDER_PLAYER_MAP: {[number]: Actor} = {}

-- // Create Instances
local Replay_Recorders_Directory = Instance.new("Folder", ServerScriptService)
Replay_Recorders_Directory.Name = "ReplayRecorders";

local Buffer_Util_Pointer = Instance.new("ObjectValue", Replay_Recorders_Directory)
Buffer_Util_Pointer.Name = "BufferUtilPointer"; Buffer_Util_Pointer.Value = Buffer_Util;

local function CreateRecorderThreadForPlayer(player_instance: Player): Actor
	if typeof(player_instance) ~= "Instance" or not player_instance:IsA("Player") then
		warn("ReplayRecorder.CreateRecorderThreadForPlayer() failed, Player instance is undefined / not a player.")
		return nil :: any;
	end
	
	local recorder_thread = RECORDER_PLAYER_MAP[player_instance.UserId]
	if recorder_thread then
		return recorder_thread;
	end
	
	recorder_thread = Template_Actor:Clone()
	
	recorder_thread.ReplayRecordingFinished.Event:Connect(function(replay_buffer)
		local replay_server = require("./ReplayServer") :: any
		replay_server.RecordingStates[player_instance] = nil
		Cloud.SaveReplayBuffer(player_instance, replay_buffer)
	end)
	
	recorder_thread.Parent = Replay_Recorders_Directory
	recorder_thread.Name ..= player_instance.UserId
	recorder_thread.RecorderScript.Enabled = true

	recorder_thread.ActorInitialised.Event:Wait()
	
	recorder_thread:SendMessage("AllocatedPlayer", player_instance)
	RECORDER_PLAYER_MAP[player_instance.UserId] = recorder_thread;
	
	return recorder_thread;
end

local function GetRecorderThreadForPlayer(player_instance: Player, reconcile: boolean?): Actor
	if typeof(player_instance) ~= "Instance" or not player_instance:IsA("Player") then
		warn("ReplayRecorder.GetRecorderThreadForPlayer() failed, Player instance is undefined / not a player.")
		return nil :: any;
	end

	local recorder_thread = RECORDER_PLAYER_MAP[player_instance.UserId]
	if recorder_thread then
		return recorder_thread;
	end

	if not reconcile then return nil :: any end

	recorder_thread = CreateRecorderThreadForPlayer(player_instance)
	return recorder_thread
end

local function DestroyRecorderThreadForPlayer(player_instance: Player): ...any
	if typeof(player_instance) ~= "Instance" or not player_instance:IsA("Player") then
		warn("ReplayRecorder.CreateRecorderThreadForPlayer() failed, Player instance is undefined / not a player.")
		return nil :: any;
	end
	
	local recorder_thread = GetRecorderThreadForPlayer(player_instance)
	if not recorder_thread then
		return;
	end
	
	recorder_thread:Destroy()
	RECORDER_PLAYER_MAP[player_instance.UserId] = nil
end

return {
	GetRecorderThreadForPlayer = GetRecorderThreadForPlayer,
	CreateRecorderThreadForPlayer = CreateRecorderThreadForPlayer,
	DestroyRecorderThreadForPlayer = DestroyRecorderThreadForPlayer
}