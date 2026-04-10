--!strict
--!optimize 2
--!native
--[=[
	Save.luau | Author: @exwrdss
]=]

-- // Loaded Services
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local PlayersService = game:GetService("Players")

-- // Dependencies
local BufferUtil = require("../../Shared/BufferUtil")
local Config = require("../../Config")
local Types = require("../../Shared/Types")

-- // Data Store
local CanSaveReplayCache: Types.ReplayCacheType = setmetatable({}, {__mode = "k"})
local ReplayPointerStore = DataStoreService:GetDataStore("ReplayPointerStore_V" .. Config.Version)
local ReplayBufferStore = DataStoreService:GetDataStore("ReplayBufferStore_V" .. Config.Version)

-- // Data Functions

local function YieldUntilAppropriateBudget(data_store_request_type: Enum.DataStoreRequestType)
	while 0 > DataStoreService:GetRequestBudgetForRequestType(data_store_request_type) do
		task.wait()
	end
end

local function SafeDataStoreCall(data_store_request_type: Enum.DataStoreRequestType, data_function: (...any) -> ...any, ...): ...any
	YieldUntilAppropriateBudget(data_store_request_type)
	
	local result: any
	for att = 1, 5 do
		result = table.pack(pcall(data_function, ...))
		
		if result[1] then break; end
		if att < 5 then task.wait(att * 1.25) end;
	end
	
	return unpack(result)
end

local function ValidateCache(player: Player, cache: Types.PlayerCache)
	local cache_time_elapsed = os.time() - cache.CacheUnixTimestamp
	if cache_time_elapsed > Config.CacheExpiryTime then
		CanSaveReplayCache[player] = nil;
		return false;
	end
	
	return true;
end

local function CanSaveReplayBuffer(player: Player)
	local existing_cache = CanSaveReplayCache[player]
	if existing_cache and ValidateCache(player, existing_cache) then
		return existing_cache.CanSave
	end
	
	local can_save: boolean
	
	local update_success = SafeDataStoreCall(
		Enum.DataStoreRequestType.UpdateAsync,
		ReplayPointerStore.UpdateAsync,
		ReplayPointerStore,
		player.UserId,
		function(existing_data: {string})
			existing_data = existing_data or {}
			can_save = Config.MaxReplaysPerPlayer > #existing_data;
			return existing_data;
		end
	);
	
	CanSaveReplayCache[player] = { CanSave = can_save, CacheUnixTimestamp = os.time() }
	return can_save;
end

local function SaveReplayBuffer(player: Player, replay_buffer: buffer): boolean
	local save_guid = HttpService:GenerateGUID(false);
	
	local saveSuccess = SafeDataStoreCall(
		Enum.DataStoreRequestType.SetIncrementAsync,
		ReplayBufferStore.SetAsync,
		ReplayBufferStore,
		save_guid,
		replay_buffer,
		{player.UserId}
	);
	
	local stored_count = 0;
	local update_success = SafeDataStoreCall(
		Enum.DataStoreRequestType.UpdateAsync,
		ReplayPointerStore.UpdateAsync,
		ReplayPointerStore,
		player.UserId,
		function(existing_data)
			existing_data = existing_data or {}
			
			stored_count = #existing_data;
			
			if stored_count >= Config.MaxReplaysPerPlayer then
				return existing_data;
			end
			
			table.insert(existing_data, save_guid)
			return existing_data;
		end
	);
	
	local successful_save = saveSuccess and update_success;
	if successful_save then
		CanSaveReplayCache[player] = { CanSave = stored_count, CacheUnixTimestamp = os.time() }
	end
	
	return successful_save;
end

local function GetRecentReplayBuffers(user_id: number?): (boolean, {buffer})
	if user_id then
		local get_success, pointer_data = SafeDataStoreCall(
			Enum.DataStoreRequestType.GetAsync,
			ReplayPointerStore.GetAsync,
			ReplayPointerStore,
			user_id
		);
		
		if not get_success or not pointer_data then
			return get_success, {}
		end
		
		local found_replays = {}
		for _, guid in pairs(pointer_data) do
			local get_success, replay_data = SafeDataStoreCall(
				Enum.DataStoreRequestType.GetAsync,
				ReplayBufferStore.GetAsync,
				ReplayBufferStore,
				guid
			);
			
			if not get_success or not replay_data then continue; end
			table.insert(found_replays, replay_data);
		end
		
		return true, found_replays;
	end
	
	local list_success, key_pages: DataStorePages = SafeDataStoreCall(
		Enum.DataStoreRequestType.ListAsync,
		ReplayBufferStore.ListKeysAsync,
		ReplayBufferStore,
		nil, nil, nil,
		true
	);
	
	if not list_success or not key_pages then
		return false, {}
	end
	
	local recent_replay_buffers = {}
	local pages = key_pages:GetCurrentPage()
	local tasks_left = #pages;
	
	for _, data_store_key: DataStoreKey in pairs(pages) do
		task.spawn(
			SafeDataStoreCall,
			Enum.DataStoreRequestType.UpdateAsync,
			ReplayBufferStore.UpdateAsync,
			ReplayBufferStore,
			data_store_key.KeyName,
			function(existing_data: {buffer})
				tasks_left -= 1;
				
				if not existing_data then
					existing_data = {}
				else
					table.insert(recent_replay_buffers, existing_data[#existing_data])
				end
				
				return existing_data;
			end
		)
	end
	
	local yield_start = time();
	while tasks_left > 0 and time() - yield_start < 15 do
		task.wait()
	end
	
	return true, recent_replay_buffers;
end

return {
	CanSaveReplayCache = CanSaveReplayCache,
	SafeDataStoreCall = SafeDataStoreCall,
	ValidateCache = ValidateCache,
	CanSaveReplayBuffer = CanSaveReplayBuffer,
	SaveReplayBuffer = SaveReplayBuffer,
	GetRecentReplayBuffers = GetRecentReplayBuffers
}