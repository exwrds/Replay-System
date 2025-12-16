--!strict
--[=[
	Types.luau | Author: @exwrdss
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

export type ReplayPlayer = {
	ReplayMetaData: ReplayMetaData,
	BytesOffset: number,
	
	ReplayCharacter: TemplateCharacter,
	ReplayParts: {Part},
	
	HasFinished: boolean,
	IsPlaying: boolean,
	HasStarted: boolean,
	HeartbeatConnection: RBXScriptConnection,
	
	UpdateReplayPlayerAppearanceAsync: (self: ReplayPlayer, HumanoidDescription: HumanoidDescription) -> ReplayPlayer,
	
	CreateHeartbeatConnection: (self: ReplayPlayer) -> ReplayPlayer,
	EndHeartbeatConnection: (self: ReplayPlayer) -> ReplayPlayer,
	
	StartReplay: (self: ReplayPlayer) -> ReplayPlayer,
	PauseReplay: (self: ReplayPlayer) -> ReplayPlayer,
	ResumeReplay: (self: ReplayPlayer) -> ReplayPlayer,
}

return { TemplateCharacter = script:WaitForChild("TemplateCharacter") }