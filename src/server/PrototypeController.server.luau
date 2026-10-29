--!strict
--[[
	PrototypeController.server.luau
	Master Server Controller for SHIFT 13: The Night Audit (Milestone 5)
	
	Maintains absolute Server Authority for:
	- Shift lifecycle (Preparation, Active, Completed, Failed)
	- Hidden anomaly selection and office environment manifestation
	- Report validation, evidence scoring, and anti-spam locks
	- Synchronized client state replication
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Ensure remotes folder and events exist
local remotesFolder = ReplicatedStorage:FindFirstChild("Shift13Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Shift13Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string): RemoteEvent
	local existing = remotesFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local shiftStateUpdateRemote = getOrCreateRemote("ShiftStateUpdate")
local submitReportRemote = getOrCreateRemote("SubmitReport")
local openTerminalRemote = getOrCreateRemote("OpenTerminalUI")

-- Load Modules
local AnomalyConfig = require(ReplicatedStorage:WaitForChild("AnomalyConfig") :: ModuleScript)
local OfficeManager = require(script.Parent:WaitForChild("OfficeManager") :: ModuleScript)

-- Initialize physical office environment
OfficeManager.EnsureEnvironment()
OfficeManager.SetBaseline()

--------------------------------------------------------------------------------
-- GAME STATE
--------------------------------------------------------------------------------
type ShiftState = "Preparation" | "Active" | "Completed" | "Failed"

local currentShiftNumber = 1
local currentState: ShiftState = "Preparation"
local currentAnomaly = "Normal"
local timeRemaining = 0
local shiftDuration = AnomalyConfig.Settings.ShiftDuration
local intermissionDuration = AnomalyConfig.Settings.IntermissionDuration

-- Player evidence database: [Player] = evidenceScore
local playerEvidence: { [Player]: number } = {}
-- Player reporting lock per shift: [Player] = boolean
local hasReportedThisShift: { [Player]: boolean } = {}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

local function broadcastState(feedback: string?, feedbackType: string?)
	for _, player in ipairs(Players:GetPlayers()) do
		local evidence = playerEvidence[player] or 0
		shiftStateUpdateRemote:FireClient(player, {
			state = currentState,
			shiftNumber = currentShiftNumber,
			timeRemaining = math.max(0, math.floor(timeRemaining)),
			evidenceCount = evidence,
			reportFeedback = feedback,
			feedbackType = feedbackType or "Neutral",
			currentAnomaly = (currentState == "Completed" or currentState == "Failed") and currentAnomaly or nil,
		})
	end
end

local function sendPlayerState(player: Player, feedback: string?, feedbackType: string?)
	local evidence = playerEvidence[player] or 0
	shiftStateUpdateRemote:FireClient(player, {
		state = currentState,
		shiftNumber = currentShiftNumber,
		timeRemaining = math.max(0, math.floor(timeRemaining)),
		evidenceCount = evidence,
		reportFeedback = feedback,
		feedbackType = feedbackType or "Neutral",
		currentAnomaly = (currentState == "Completed" or currentState == "Failed") and currentAnomaly or nil,
	})
end

-- Pick an anomaly using weighted randomness
local function pickRandomAnomaly(): string
	local roll = math.random()
	if roll > AnomalyConfig.Settings.AnomalyProbability then
		return "Normal"
	end
	local pool = AnomalyConfig.ActiveAnomalyTypes
	local index = math.random(1, #pool)
	return pool[index]
end

--------------------------------------------------------------------------------
-- SHIFT LIFECYCLE CONTROLLER
--------------------------------------------------------------------------------

local function endShift(success: boolean, feedbackText: string)
	if currentState ~= "Active" then return end
	currentState = success and "Completed" or "Failed"
	local feedbackType = success and "Success" or "Error"

	print(string.format("[SHIFT 13] Shift %d ended. Result: %s. Anomaly was: %s", 
		currentShiftNumber, currentState, currentAnomaly))

	broadcastState(feedbackText, feedbackType)

	-- Hold results for review
	task.delay(intermissionDuration, function()
		currentShiftNumber += 1
		startPreparationPhase()
	end)
end

function startPreparationPhase()
	currentState = "Preparation"
	hasReportedThisShift = {}
	OfficeManager.SetBaseline()

	print(string.format("[SHIFT 13] Preparing Shift %d...", currentShiftNumber))
	broadcastState("PREPARING AUDIT... Calibrating office baseline.", "Neutral")

	task.delay(3, function()
		startActiveShift()
	end)
end

function startActiveShift()
	currentState = "Active"
	currentAnomaly = pickRandomAnomaly()
	timeRemaining = shiftDuration
	hasReportedThisShift = {}

	-- Apply physical and visual anomaly to office
	OfficeManager.ApplyAnomaly(currentAnomaly)

	print(string.format("[SHIFT 13] Shift %d ACTIVE! Secret Anomaly: %s", currentShiftNumber, currentAnomaly))
	broadcastState("SHIFT BEGUN. Inspect the office and log anomalies at the terminal.", "Neutral")
end

--------------------------------------------------------------------------------
-- RUNTIME TICK LOOP
--------------------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		if currentState == "Active" then
			timeRemaining -= 1
			if timeRemaining <= 0 then
				local trueCategoryName = AnomalyConfig.Categories[currentAnomaly] 
					and AnomalyConfig.Categories[currentAnomaly].displayName or currentAnomaly
				endShift(false, string.format("TIME EXPIRED! The actual condition was: %s.", trueCategoryName))
			else
				broadcastState(nil, "Neutral")
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- REPORT SUBMISSION (SERVER AUTHORITY)
--------------------------------------------------------------------------------
submitReportRemote.OnServerEvent:Connect(function(player: Player, reportedCategory: any)
	-- 1. Validation: Is reportedCategory valid?
	if typeof(reportedCategory) ~= "string" then
		warn(string.format("[SECURITY] %s sent non-string report category.", player.Name))
		return
	end

	local categoryDef = AnomalyConfig.Categories[reportedCategory]
	if not categoryDef then
		warn(string.format("[SECURITY] %s sent unknown category: %s", player.Name, tostring(reportedCategory)))
		return
	end

	-- 2. State Check: Is the shift currently active?
	if currentState ~= "Active" then
		sendPlayerState(player, "CANNOT FILE REPORT: No active shift in progress.", "Error")
		return
	end

	-- 3. Anti-Spam / Rate-limiting: Has this player already submitted?
	if hasReportedThisShift[player] then
		sendPlayerState(player, "REPORT REJECTED: You have already filed an audit report for this shift.", "Error")
		return
	end

	-- Mark player as reported
	hasReportedThisShift[player] = true

	-- 4. Server Authority Validation Check
	local currentScore = playerEvidence[player] or 0
	local trueDef = AnomalyConfig.Categories[currentAnomaly] or { displayName = currentAnomaly }

	if reportedCategory == currentAnomaly then
		-- SUCCESS: Correct Identification
		local reward = categoryDef.evidenceReward
		playerEvidence[player] = currentScore + reward

		local successMsg = string.format("VERIFIED! Correctly identified: %s (+%d Evidence)", 
			categoryDef.displayName, reward)
		print(string.format("[SHIFT 13] %s WIN: Correctly identified %s. Evidence now: %d", 
			player.Name, reportedCategory, playerEvidence[player]))

		endShift(true, successMsg)
	else
		-- FAILURE: Inaccurate Identification
		local penalty = AnomalyConfig.Settings.IncorrectPenalty
		playerEvidence[player] = math.max(0, currentScore - penalty)

		local failMsg = string.format("AUDIT FAILED! Reported [%s], but actual phenomenon was [%s] (-%d Evidence)", 
			categoryDef.displayName, trueDef.displayName, penalty)
		print(string.format("[SHIFT 13] %s MISTAKE: Reported %s, was %s. Evidence now: %d", 
			player.Name, reportedCategory, currentAnomaly, playerEvidence[player]))

		endShift(false, failMsg)
	end
end)

--------------------------------------------------------------------------------
-- PROXIMITY PROMPT / TERMINAL INTERACTION
--------------------------------------------------------------------------------
task.spawn(function()
	-- Wait for terminal prompt to exist
	task.wait(1)
	local prompt = OfficeManager.GetTerminalPrompt()
	if prompt then
		prompt.Triggered:Connect(function(player: Player)
			openTerminalRemote:FireClient(player)
		end)
	end
end)

--------------------------------------------------------------------------------
-- PLAYER LIFECYCLE
--------------------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player: Player)
	playerEvidence[player] = 0
	task.wait(1)
	sendPlayerState(player, "Welcome to Night Audit Shift. Inspect the office for anomalies.", "Neutral")
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerEvidence[player] = nil
	hasReportedThisShift[player] = nil
end)

-- Start the first shift
task.delay(2, function()
	startPreparationPhase()
end)

