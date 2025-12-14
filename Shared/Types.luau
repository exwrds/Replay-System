--!strict
--[=[
	Types.luau
]=]

export type TemplateCharacter = typeof(script.TemplateCharacter)
export type MapData = { MapName: string, MapCFrame: CFrame, MapTime: number }

export type ReplayRecordingData = {
	StopRecording: boolean?,
	ReplayBuffer: buffer,
	BytesOffset: number,
	MaxSize: number,
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