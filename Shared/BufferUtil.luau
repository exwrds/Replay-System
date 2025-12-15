--!strict
--!optimize 2
--!native
--[=[
	BufferUtil.luau | Author: @exwrdss
]=]

-- // Native Function Cache

local OrderItterateDict = ipairs;
local CreateCFrame = CFrame.new;
local CFrameFromEulerAngles = CFrame.fromEulerAnglesXYZ;
local DegreesToRadians, RadiansToDegrees = math.rad, math.deg;

-- Float32, primarily used for storing CFrames & Unix Timestamp (4 Bytes)
local Buffer_WriteFloat32 = buffer.writef32;
local Buffer_ReadFloat32 = buffer.readf32;

-- Float64, primarily used for storing UserIDs (8 Bytes)
local Buffer_WriteFloat64 = buffer.writef64;
local Buffer_ReadFloat64 = buffer.readf64;

-- Read/Write String, primarily used for MetaData (Bytes Vary)
local Buffer_WriteUnsigned8 = buffer.writeu8;
local Buffer_ReadUnsigned8 = buffer.readu8;

local Buffer_ReadString = buffer.readstring;
local Buffer_WriteString = buffer.writestring;

-- // Dependencies
local Types = require("./Types")

-- // Module Table
local BufferUtil = {}

-- // Constant Variables
local BYTES_PER_CFRAME = 24;
local BYTES_PER_FRAME = BYTES_PER_CFRAME * 7;
local FPS_RATE = 60;
local BODY_PARTS = { "HumanoidRootPart", "Head", "Left Arm", "Left Leg", "Right Arm", "Right Leg", "Torso" } -- Order is very important

-- // Conversion Functions

local function BytesToKB(bytes: number)
	return math.floor(bytes / 1024) .. "KB"
end

local function StringToBuffer(buf: buffer, offset: number, str: string): number
	local strLength = str:len()
	Buffer_WriteUnsigned8(buf, offset, strLength); Buffer_WriteString(buf, offset + 1, str, strLength)
	return offset + strLength + 1
end

local function BufferToString(buf: buffer, offset: number): (string, number)
	local strLength = Buffer_ReadUnsigned8(buf, offset)
	local str = Buffer_ReadString(buf, offset + 1, strLength)
	return str, offset + strLength + 1
end

local function CFrameToBuffer(buf: buffer, offset: number, cframe: CFrame): number
	local position = cframe.Position;
	Buffer_WriteFloat32(buf, offset, position.X); Buffer_WriteFloat32(buf, offset + 4, position.Y); Buffer_WriteFloat32(buf, offset + 8, position.Z)
	local roll, pitch, yaw = cframe:ToEulerAnglesXYZ()
	roll, pitch, yaw = DegreesToRadians(roll), DegreesToRadians(pitch), DegreesToRadians(yaw)
	Buffer_WriteFloat32(buf, offset + 12, roll); Buffer_WriteFloat32(buf, offset + 16, pitch); Buffer_WriteFloat32(buf, offset + 20, yaw)
	return offset + 24;
end

local function BufferToCFrame(buf: buffer, offset: number): (CFrame, number)
	local x, y, z = Buffer_ReadFloat32(buf, offset), Buffer_ReadFloat32(buf, offset + 4), Buffer_ReadFloat32(buf, offset + 8)
	local roll, pitch, yaw = Buffer_ReadFloat32(buf, offset + 12), Buffer_ReadFloat32(buf, offset + 16), Buffer_ReadFloat32(buf, offset + 20)
	roll, pitch, yaw = RadiansToDegrees(roll), RadiansToDegrees(pitch), RadiansToDegrees(yaw)
	return (CreateCFrame(x, y, z) * CFrameFromEulerAngles(roll, pitch, yaw :: any)), offset + 24;
end

local function FrameToBuffer(buf: buffer, offset: number, cframes: {CFrame}): number
	for _, cframe in OrderItterateDict(cframes) do
		offset = CFrameToBuffer(buf, offset, cframe)
	end
	
	return offset;
end

local function BufferToFrame(buf: buffer, offset: number): ({CFrame}, number)
	local cframes = {}
	for i = 1, 7 do
		cframes[i], offset = BufferToCFrame(buf, offset)
	end
	return cframes, offset
end

-- // Util Functions

local function ValidateMapData(mapData: Types.MapData): Types.MapData
	if type(mapData) ~= "table" then return false :: any; end

	if not mapData.MapName then return false :: any; end
	if not mapData.MapCFrame then return false :: any; end
	if not tonumber(mapData.MapTime) then
		mapData.MapTime = 120;
	else
		mapData.MapTime = math.abs(mapData.MapTime)
	end

	return mapData
end

local function ReadReplayBuffer(replayBuffer: buffer): Types.ReplayMetaData
	assert(typeof(replayBuffer) == "buffer", "BufferUtil.ReadReplayBuffer failed; Expected buffer!")
	
	local currentOffset = 0;
	
	local userId = Buffer_ReadFloat64(replayBuffer, 0)
	currentOffset += 8;
	
	local unixTimestamp = Buffer_ReadFloat32(replayBuffer, currentOffset)
	currentOffset += 4;

	local mapName, currentOffset = BufferToString(replayBuffer, currentOffset)

	local mapCFrame, currentOffset = BufferToCFrame(replayBuffer, currentOffset)
	local frameRate = Buffer_ReadUnsigned8(replayBuffer, currentOffset)
	currentOffset += 1;
	
	return {
		MapName = mapName,
		MapCFrame = mapCFrame,
		UserID = userId,
		UnixTimestamp = unixTimestamp,
		ReplayBuffer = replayBuffer,
		FrameRate = frameRate,
		BytesOffset = currentOffset,
		MaxSize = buffer.len(replayBuffer)
	}
end

local function CreateReplayBuffer(mapData: Types.MapData, player: Player): Types.ReplayRecordingData
	mapData = ValidateMapData(mapData)
	if not mapData then
		return error("BufferUtil.CreateReplyBuffer failed; MapData could not be validated!", 2);
	end
	
	local replayRecordingData = {}
	
	local plrCharacter = player.Character :: Types.TemplateCharacter
	if not plrCharacter then
		warn("BufferUtil.CreateReplayBuffer failed; there must be an alive character of the player passed.")
		return nil :: any
	end
	
	local healthChangedSignal: RBXScriptConnection
	healthChangedSignal = plrCharacter.Humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		if plrCharacter.Humanoid.Health == 0 then -- player has died
			replayRecordingData.StopRecording = true;
			
			healthChangedSignal:Disconnect()
			healthChangedSignal = nil :: any
		end
	end)
	
	player.AncestryChanged:Once(function(_, newParent: Instance?)
		if not newParent then
			replayRecordingData.StopRecording = true;
			
			if healthChangedSignal then
				healthChangedSignal:Disconnect()
				healthChangedSignal = nil :: any
			end
		end
	end)
	
	-- Create Replay Buffer
	local bufferSize = ((mapData.MapName:len() + 1) + BYTES_PER_CFRAME + 8 + 4 + 1) + ((BYTES_PER_FRAME * 60) * mapData.MapTime)
	local replayBuffer = buffer.create(bufferSize)
	local currentOffset = 0;
	
	-- Write UserID (8 Bytes)
	Buffer_WriteFloat64(replayBuffer, 0, player.UserId)
	currentOffset += 8;
	
	-- Write Unix Timestamp (4 Bytes)
	Buffer_WriteFloat32(replayBuffer, currentOffset, os.time())
	currentOffset += 4;
	
	-- Write MapName (Bytes Varies)
	currentOffset = StringToBuffer(replayBuffer, currentOffset, mapData.MapName)
	
	-- Write MapCFrame (24 Bytes)
	currentOffset = CFrameToBuffer(replayBuffer, currentOffset, mapData.MapCFrame)
	
	-- Write FrameRate (1 Byte)
	Buffer_WriteUnsigned8(replayBuffer, currentOffset, FPS_RATE)
	currentOffset += 1;
	
	replayRecordingData.ReplayBuffer = replayBuffer
	replayRecordingData.MaxSize = bufferSize
	replayRecordingData.BytesOffset = currentOffset
	replayRecordingData.Character = plrCharacter
	
	replayRecordingData.RecordParts = {}
	for _, bodyPart in OrderItterateDict(plrCharacter:GetChildren()) do
		if not bodyPart:IsA("BasePart") then continue; end
		
		local insertIndex = table.find(BODY_PARTS, bodyPart.Name)
		if insertIndex ~= nil then
			replayRecordingData.RecordParts[insertIndex] = bodyPart :: Part
		end
	end
	
	print("Replay Buffer created, size: " .. BytesToKB(bufferSize));
	return replayRecordingData :: any
end

return {
	FPS_RATE = FPS_RATE,
	BODY_PARTS = BODY_PARTS,
	StringToBuffer = StringToBuffer,
	BufferToString = BufferToString,
	CFrameToBuffer = CFrameToBuffer,
	BufferToCFrame = BufferToCFrame,
	FrameToBuffer = FrameToBuffer,
	BufferToFrame = BufferToFrame,
	CreateReplayBuffer = CreateReplayBuffer,
	ReadReplayBuffer = ReadReplayBuffer
}