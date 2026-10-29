--!strict
--[[
	AnomalyConfig.luau
	Shared configuration module for SHIFT 13: The Night Audit (Milestone 5)
	
	Defines the master list of anomaly categories, display names, descriptions,
	and reward parameters used by both Server (validation) and Client (HUD reporting).
]]

export type AnomalyCategory = {
	id: string,
	displayName: string,
	icon: string,
	hint: string,
	evidenceReward: number,
}

local AnomalyConfig = {}

AnomalyConfig.Categories = {
	Normal = {
		id = "Normal",
		displayName = "Normal (No Anomaly)",
		icon = "✅",
		hint = "Everything in the office matches baseline specifications.",
		evidenceReward = 15,
	},
	ClockTime = {
		id = "ClockTime",
		displayName = "Clock / Time",
		icon = "🕰️",
		hint = "Wall clock hands are spinning wildly or frozen in impossible time.",
		evidenceReward = 20,
	},
	FurnitureShift = {
		id = "FurnitureShift",
		displayName = "Furniture Shift",
		icon = "🪑",
		hint = "Office chair or filing cabinet has moved, rotated, or levitated.",
		evidenceReward = 20,
	},
	TerminalError = {
		id = "TerminalError",
		displayName = "Terminal Glitch",
		icon = "💻",
		hint = "Monitor screen displays corrupted static or ominous broadcast text.",
		evidenceReward = 20,
	},
	DoorAjar = {
		id = "DoorAjar",
		displayName = "Door / Passage",
		icon = "🚪",
		hint = "An office door that should be shut has swung wide open into the void.",
		evidenceReward = 20,
	},
	FlickeringLight = {
		id = "FlickeringLight",
		displayName = "Electrical / Lights",
		icon = "💡",
		hint = "Ceiling lighting flickers erratically with unnatural tint or hum.",
		evidenceReward = 20,
	},
	PaintingChange = {
		id = "PaintingChange",
		displayName = "Painting / Decor",
		icon = "🖼️",
		hint = "Wall framed artwork has rotated upside down or morphed unnaturally.",
		evidenceReward = 20,
	},
} :: { [string]: AnomalyCategory }

-- Ordered list for rendering buttons in UI
AnomalyConfig.CategoryList = {
	"Normal",
	"ClockTime",
	"FurnitureShift",
	"TerminalError",
	"DoorAjar",
	"FlickeringLight",
	"PaintingChange",
}

-- List of anomalies excluding "Normal" used by server RNG when picking anomalies
AnomalyConfig.ActiveAnomalyTypes = {
	"ClockTime",
	"FurnitureShift",
	"TerminalError",
	"DoorAjar",
	"FlickeringLight",
	"PaintingChange",
}

-- Base settings
AnomalyConfig.Settings = {
	ShiftDuration = 60, -- Length of audit in seconds
	IntermissionDuration = 6, -- Rest period between shifts
	IncorrectPenalty = 5, -- Evidence deducted for inaccurate report
	AnomalyProbability = 0.75, -- 75% chance an anomaly occurs; 25% normal
}

return AnomalyConfig
