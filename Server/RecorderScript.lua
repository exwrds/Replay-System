--!strict
--!optimize 2
--!native
--[=[
	RecorderScript.lua | Author: @exwrdss
]=]

while not script:GetActor() do task.wait() end -- Yield until actor.

-- // Loaded Services
local RunService = game:GetService("RunService")

-- // Types
export type ReplayRecordingData = {
	StopRecording: boolean?,
	ReplayBuffer: buffer,
	BytesOffset: number,
	MaxSize: number,
	Character: Model,
	RecordParts: {Part}
}

-- // Dependencies
local Buffer_Util = require(script.Parent.Parent.BufferUtilPointer.Value)

-- // Thread Variables
local ALLOCATED_PLAYER: Player
local REPLAY_RECORDING_DATA: ReplayRecordingData
local CURRENT_CHARACTER: Model

local THREAD_ACTOR = script:GetActor()
local REPLAY_RECORDING_FINISHED_BINDABLE = script.Parent.ReplayRecordingFinished
local HEART_BEAT_CONNECTION: RBXScriptConnection

local FPS_RATE = 1 / Buffer_Util.FPS_RATE
local DELTA_ACCUMALATOR = 0;

-- // Main Function

local function EndHeartbeatConnection()
	task.synchronize()
	if HEART_BEAT_CONNECTION then
		HEART_BEAT_CONNECTION:Disconnect()
		HEART_BEAT_CONNECTION = nil :: any
	end
	task.desynchronize()
end

local function CreateHeartbeatConnection()
	EndHeartbeatConnection()
	
	if not REPLAY_RECORDING_DATA then
		return;
	end
	
	local order_itterate_dict = ipairs
	local frame_to_buffer = Buffer_Util.FrameToBuffer;
	
	task.synchronize()
	HEART_BEAT_CONNECTION = RunService.Heartbeat:ConnectParallel(function(delta_time)
		task.desynchronize()
		
		DELTA_ACCUMALATOR += delta_time
		while DELTA_ACCUMALATOR >= FPS_RATE do
			
			if REPLAY_RECORDING_DATA.StopRecording then
				task.synchronize()
				REPLAY_RECORDING_FINISHED_BINDABLE:Fire(REPLAY_RECORDING_DATA.ReplayBuffer)
				task.desynchronize()
				
				EndHeartbeatConnection()
				return;
			end
			
			local cframes = {}
			for insert_index, record_part in order_itterate_dict(REPLAY_RECORDING_DATA.RecordParts) do
				cframes[insert_index] = record_part.CFrame
			end
			
			REPLAY_RECORDING_DATA.BytesOffset = frame_to_buffer(REPLAY_RECORDING_DATA.ReplayBuffer, REPLAY_RECORDING_DATA.BytesOffset, cframes)
			REPLAY_RECORDING_DATA.StopRecording = REPLAY_RECORDING_DATA.BytesOffset >= REPLAY_RECORDING_DATA.MaxSize;
			
			DELTA_ACCUMALATOR -= FPS_RATE;
		end
	end)
	
end

-- // Data Listeners

local DATA_MESSAGE_LISTENER: RBXScriptConnection
DATA_MESSAGE_LISTENER = THREAD_ACTOR:BindToMessageParallel("AllocatedPlayer", function(allocated_player: Player)
	ALLOCATED_PLAYER = allocated_player
	
	task.synchronize()
	
	local function on_character_added(character_model: Model)
		if character_model == CURRENT_CHARACTER then return; end
		
		CURRENT_CHARACTER = character_model;
		
		local humanoid = character_model:WaitForChild("Humanoid") :: Humanoid
		if not humanoid then return; end

		character_model.AncestryChanged:Connect(function(_, new_parent)
			if not new_parent then
				REPLAY_RECORDING_DATA.StopRecording = true;
			end
		end)

		humanoid:GetPropertyChangedSignal("Health"):Connect(function()
			if humanoid.Health == 0 then
				REPLAY_RECORDING_DATA.StopRecording = true;
			end
		end)
	end
	
	if ALLOCATED_PLAYER.Character then
		on_character_added(ALLOCATED_PLAYER.Character)
	end
	
	ALLOCATED_PLAYER.CharacterAdded:Connect(on_character_added)
	
	DATA_MESSAGE_LISTENER:Disconnect()
end)

THREAD_ACTOR:BindToMessageParallel("StartRecording", function(replay_recording_data: ReplayRecordingData)
	REPLAY_RECORDING_DATA = replay_recording_data
	CreateHeartbeatConnection()
end)

THREAD_ACTOR:BindToMessageParallel("StopRecording", function()
	if REPLAY_RECORDING_DATA then
		REPLAY_RECORDING_DATA.StopRecording = true;
	end
end)

script.Parent.ActorInitialised:Fire()