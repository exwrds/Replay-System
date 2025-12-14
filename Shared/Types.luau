--!strict
--[=[
	Types.luau
]=]

export type PlayerCache = { CanSave: boolean, CacheUnixTimestamp: number }
export type ReplayCacheType = typeof(setmetatable({} :: {[Player]: PlayerCache}, {__mode = "k"}))
export type TemplateCharacter = typeof(script.TemplateCharacter)
export type MapData = { MapName: string, MapCFrame: CFrame, MapTime: number }

export type ReplayRecordingData = {
	StopRecording: boolean?,
	ReplayBuffer: buffer,
	BytesOffset: number,
	MaxSize: number,
	Character: TemplateCharacter,
	RecordParts: {Part}
}

export type ReplayMetaData = {
	MapName: string,
	MapCFrame: CFrame,
	
	UserID: number,
	UnixTimestamp: number,
	
	ReplayBuffer: buffer,
	FrameRate: number,
	BytesOffset: number,
	MaxSize: number
}

return {}