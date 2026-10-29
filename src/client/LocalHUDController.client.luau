--!strict
--[[
	LocalHUDController.client.luau
	Client-side HUD and Interactive Terminal Menu for SHIFT 13: The Night Audit
	
	Features:
	- Atmospheric horror retro terminal aesthetic
	- Dynamic shift timer and evidence counter
	- Specific anomaly category reporting modal (triggered by ProximityPrompt or UI button)
	- Real-time feedback alerts from server validation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load Config & Remotes
local AnomalyConfig = require(ReplicatedStorage:WaitForChild("AnomalyConfig") :: ModuleScript)
local remotesFolder = ReplicatedStorage:WaitForChild("Shift13Remotes")
local shiftStateUpdateRemote = remotesFolder:WaitForChild("ShiftStateUpdate") :: RemoteEvent
local submitReportRemote = remotesFolder:WaitForChild("SubmitReport") :: RemoteEvent
local openTerminalRemote = remotesFolder:WaitForChild("OpenTerminalUI") :: RemoteEvent

--------------------------------------------------------------------------------
-- CREATE SCREEN GUI
--------------------------------------------------------------------------------
local screenGui = playerGui:FindFirstChild("Shift13HUD") :: ScreenGui?
if not screenGui then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Shift13HUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
end

-- Main Canvas Container
local mainCanvas = Instance.new("Frame")
mainCanvas.Name = "MainCanvas"
mainCanvas.Size = UDim2.new(1, 0, 1, 0)
mainCanvas.BackgroundTransparency = 1
mainCanvas.Parent = screenGui

--------------------------------------------------------------------------------
-- TOP STATUS BAR
--------------------------------------------------------------------------------
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(0.9, 0, 0, 60)
topBar.Position = UDim2.new(0.05, 0, 0, 16)
topBar.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
topBar.BackgroundTransparency = 0.2
topBar.BorderSizePixel = 0
topBar.Parent = mainCanvas

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 8)
topCorner.Parent = topBar

local topStroke = Instance.new("UIStroke")
topStroke.Color = Color3.fromRGB(45, 52, 65)
topStroke.Thickness = 1.5
topStroke.Parent = topBar

-- Shift Info (Left)
local shiftTitleLabel = Instance.new("TextLabel")
shiftTitleLabel.Name = "ShiftTitle"
shiftTitleLabel.Size = UDim2.new(0.35, 0, 1, 0)
shiftTitleLabel.Position = UDim2.new(0, 16, 0, 0)
shiftTitleLabel.BackgroundTransparency = 1
shiftTitleLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
shiftTitleLabel.Font = Enum.Font.GothamBold
shiftTitleLabel.TextSize = 18
shiftTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
shiftTitleLabel.Text = "SHIFT 13: THE NIGHT AUDIT"
shiftTitleLabel.Parent = topBar

-- Timer (Center)
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(0.3, 0, 1, 0)
timerLabel.Position = UDim2.new(0.35, 0, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(255, 195, 80)
timerLabel.Font = Enum.Font.Code
timerLabel.TextSize = 22
timerLabel.Text = "TIME: --:--"
timerLabel.Parent = topBar

-- Evidence Counter (Right)
local evidenceLabel = Instance.new("TextLabel")
evidenceLabel.Name = "EvidenceLabel"
evidenceLabel.Size = UDim2.new(0.3, -16, 1, 0)
evidenceLabel.Position = UDim2.new(0.7, 0, 0, 0)
evidenceLabel.BackgroundTransparency = 1
evidenceLabel.TextColor3 = Color3.fromRGB(80, 220, 140)
evidenceLabel.Font = Enum.Font.GothamBold
evidenceLabel.TextSize = 18
evidenceLabel.TextXAlignment = Enum.TextXAlignment.Right
evidenceLabel.Text = "EVIDENCE: 0 PTS"
evidenceLabel.Parent = topBar

--------------------------------------------------------------------------------
-- FEEDBACK / TOAST NOTIFICATION BANNER
--------------------------------------------------------------------------------
local toastBanner = Instance.new("Frame")
toastBanner.Name = "ToastBanner"
toastBanner.Size = UDim2.new(0.65, 0, 0, 48)
toastBanner.Position = UDim2.new(0.175, 0, 0, 84)
toastBanner.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
toastBanner.BackgroundTransparency = 0.15
toastBanner.BorderSizePixel = 0
toastBanner.Visible = false
toastBanner.Parent = mainCanvas

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 6)
toastCorner.Parent = toastBanner

local toastStroke = Instance.new("UIStroke")
toastStroke.Color = Color3.fromRGB(60, 70, 85)
toastStroke.Thickness = 1.2
toastStroke.Parent = toastBanner

local toastText = Instance.new("TextLabel")
toastText.Name = "ToastText"
toastText.Size = UDim2.new(1, -20, 1, 0)
toastText.Position = UDim2.new(0, 10, 0, 0)
toastText.BackgroundTransparency = 1
toastText.Font = Enum.Font.GothamMedium
toastText.TextSize = 15
toastText.TextColor3 = Color3.fromRGB(240, 240, 245)
toastText.TextWrapped = true
toastText.Parent = toastBanner

local function showFeedback(msg: string, feedbackType: string)
	toastText.Text = msg
	if feedbackType == "Success" then
		toastStroke.Color = Color3.fromRGB(46, 204, 113)
		toastBanner.BackgroundColor3 = Color3.fromRGB(15, 38, 25)
		toastText.TextColor3 = Color3.fromRGB(160, 255, 190)
	elseif feedbackType == "Error" then
		toastStroke.Color = Color3.fromRGB(231, 76, 60)
		toastBanner.BackgroundColor3 = Color3.fromRGB(45, 18, 18)
		toastText.TextColor3 = Color3.fromRGB(255, 160, 160)
	else
		toastStroke.Color = Color3.fromRGB(70, 80, 100)
		toastBanner.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
		toastText.TextColor3 = Color3.fromRGB(240, 240, 245)
	end

	toastBanner.Visible = true
	toastBanner.BackgroundTransparency = 0.15
	toastText.TextTransparency = 0

	task.delay(5, function()
		if toastText.Text == msg then
			local fadeTween = TweenService:Create(toastBanner, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
			local textFade = TweenService:Create(toastText, TweenInfo.new(0.5), { TextTransparency = 1 })
			fadeTween:Play()
			textFade:Play()
			task.wait(0.5)
			if toastBanner.BackgroundTransparency >= 0.95 then
				toastBanner.Visible = false
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- TERMINAL REPORTING MODAL MENU
--------------------------------------------------------------------------------
local modalOverlay = Instance.new("Frame")
modalOverlay.Name = "TerminalModalOverlay"
modalOverlay.Size = UDim2.new(1, 0, 1, 0)
modalOverlay.BackgroundColor3 = Color3.fromRGB(5, 5, 10)
modalOverlay.BackgroundTransparency = 0.5
modalOverlay.Visible = false
modalOverlay.Parent = mainCanvas

local terminalWindow = Instance.new("Frame")
terminalWindow.Name = "TerminalWindow"
terminalWindow.Size = UDim2.new(0, 560, 0, 520)
terminalWindow.Position = UDim2.new(0.5, -280, 0.5, -260)
terminalWindow.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
terminalWindow.BorderSizePixel = 0
terminalWindow.Parent = modalOverlay

local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, 10)
winCorner.Parent = terminalWindow

local winStroke = Instance.new("UIStroke")
winStroke.Color = Color3.fromRGB(0, 255, 150)
winStroke.Thickness = 2
winStroke.Parent = terminalWindow

-- Window Header
local winHeader = Instance.new("TextLabel")
winHeader.Name = "Header"
winHeader.Size = UDim2.new(1, -30, 0, 36)
winHeader.Position = UDim2.new(0, 15, 0, 12)
winHeader.BackgroundTransparency = 1
winHeader.Font = Enum.Font.Code
winHeader.TextSize = 20
winHeader.TextColor3 = Color3.fromRGB(0, 255, 160)
winHeader.TextXAlignment = Enum.TextXAlignment.Left
winHeader.Text = "> AUDIT TERMINAL // FILE PHENOMENON REPORT"
winHeader.Parent = terminalWindow

local winSubheader = Instance.new("TextLabel")
winSubheader.Name = "Subheader"
winSubheader.Size = UDim2.new(1, -30, 0, 24)
winSubheader.Position = UDim2.new(0, 15, 0, 48)
winSubheader.BackgroundTransparency = 1
winSubheader.Font = Enum.Font.Gotham
winSubheader.TextSize = 13
winSubheader.TextColor3 = Color3.fromRGB(150, 160, 175)
winSubheader.TextXAlignment = Enum.TextXAlignment.Left
winSubheader.Text = "Identify the exact environmental mutation, or certify office as Normal."
winSubheader.Parent = terminalWindow

-- Category Buttons Scroll Frame
local scrollList = Instance.new("ScrollingFrame")
scrollList.Name = "CategoryList"
scrollList.Size = UDim2.new(1, -30, 0, 370)
scrollList.Position = UDim2.new(0, 15, 0, 80)
scrollList.BackgroundTransparency = 1
scrollList.ScrollBarThickness = 6
scrollList.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 150)
scrollList.Parent = terminalWindow

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollList

local categoryButtons: { [string]: TextButton } = {}

local function setCategoryButtonsEnabled(enabled: boolean)
	for _, btn in pairs(categoryButtons) do
		btn.Active = enabled
		btn.AutoButtonColor = enabled
		btn.BackgroundTransparency = enabled and 0.2 or 0.6
	end
end

-- Generate buttons dynamically from AnomalyConfig
for i, categoryId in ipairs(AnomalyConfig.CategoryList) do
	local info = AnomalyConfig.Categories[categoryId]
	if not info then continue end

	local btn = Instance.new("TextButton")
	btn.Name = "Btn_" .. categoryId
	btn.Size = UDim2.new(1, -10, 0, 52)
	btn.BackgroundColor3 = (categoryId == "Normal") and Color3.fromRGB(20, 35, 30) or Color3.fromRGB(22, 26, 34)
	btn.BackgroundTransparency = 0.2
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.LayoutOrder = i
	btn.Parent = scrollList

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = (categoryId == "Normal") and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(45, 55, 70)
	btnStroke.Thickness = 1.2
	btnStroke.Parent = btn

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0.6, 0, 0, 24)
	nameLabel.Position = UDim2.new(0, 14, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 15
	nameLabel.TextColor3 = (categoryId == "Normal") and Color3.fromRGB(80, 240, 140) or Color3.fromRGB(230, 235, 245)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = string.format("%s  %s", info.icon, info.displayName)
	nameLabel.Parent = btn

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HintLabel"
	hintLabel.Size = UDim2.new(0.9, 0, 0, 18)
	hintLabel.Position = UDim2.new(0, 14, 0, 27)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextSize = 12
	hintLabel.TextColor3 = Color3.fromRGB(140, 150, 165)
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Text = info.hint
	hintLabel.Parent = btn

	local rewardBadge = Instance.new("TextLabel")
	rewardBadge.Name = "RewardBadge"
	rewardBadge.Size = UDim2.new(0, 80, 0, 24)
	rewardBadge.Position = UDim2.new(1, -94, 0.5, -12)
	rewardBadge.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
	rewardBadge.BackgroundTransparency = 0.3
	rewardBadge.Font = Enum.Font.Code
	rewardBadge.TextSize = 12
	rewardBadge.TextColor3 = Color3.fromRGB(255, 200, 80)
	rewardBadge.Text = string.format("+%d PTS", info.evidenceReward)
	rewardBadge.Parent = btn

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 4)
	badgeCorner.Parent = rewardBadge

	-- Button Click Handler
	btn.MouseButton1Click:Connect(function()
		setCategoryButtonsEnabled(false)
		modalOverlay.Visible = false

		-- Submit report to server
		submitReportRemote:FireServer(categoryId)
		showFeedback(string.format("Report filed: %s. Awaiting verification...", info.displayName), "Neutral")
	end)

	categoryButtons[categoryId] = btn
end

-- Update Canvas size
scrollList.CanvasSize = UDim2.new(0, 0, 0, (#AnomalyConfig.CategoryList * 60) + 10)

-- Close / Cancel Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(1, -30, 0, 42)
closeBtn.Position = UDim2.new(0, 15, 1, -54)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 42)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(200, 205, 215)
closeBtn.Text = "DISMISS / CANCEL"
closeBtn.Parent = terminalWindow

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
	modalOverlay.Visible = false
end)

--------------------------------------------------------------------------------
-- BOTTOM QUICK-ACCESS AUDIT BUTTON (For HUD convenience)
--------------------------------------------------------------------------------
local quickAuditBtn = Instance.new("TextButton")
quickAuditBtn.Name = "QuickAuditBtn"
quickAuditBtn.Size = UDim2.new(0, 190, 0, 44)
quickAuditBtn.Position = UDim2.new(1, -210, 1, -64)
quickAuditBtn.BackgroundColor3 = Color3.fromRGB(15, 28, 22)
quickAuditBtn.BorderSizePixel = 0
quickAuditBtn.Font = Enum.Font.Code
quickAuditBtn.TextSize = 14
quickAuditBtn.TextColor3 = Color3.fromRGB(0, 255, 150)
quickAuditBtn.Text = "💻 AUDIT TERMINAL"
quickAuditBtn.Parent = mainCanvas

local qCorner = Instance.new("UICorner")
qCorner.CornerRadius = UDim.new(0, 6)
qCorner.Parent = quickAuditBtn

local qStroke = Instance.new("UIStroke")
qStroke.Color = Color3.fromRGB(0, 200, 120)
qStroke.Thickness = 1.2
qStroke.Parent = quickAuditBtn

quickAuditBtn.MouseButton1Click:Connect(function()
	setCategoryButtonsEnabled(true)
	modalOverlay.Visible = true
end)

--------------------------------------------------------------------------------
-- NETWORKING & EVENT LISTENERS
--------------------------------------------------------------------------------

-- Triggered by ProximityPrompt at the physical desk
openTerminalRemote.OnClientEvent:Connect(function()
	setCategoryButtonsEnabled(true)
	modalOverlay.Visible = true
end)

-- Shift State Updates from Server
shiftStateUpdateRemote.OnClientEvent:Connect(function(payload: any)
	if not payload then return end

	-- Timer
	local seconds = payload.timeRemaining or 0
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	timerLabel.Text = string.format("TIME: %02d:%02d", mins, secs)

	-- Shift Number & State
	local state = payload.state or "Active"
	local shiftNum = payload.shiftNumber or 1
	shiftTitleLabel.Text = string.format("SHIFT 13 // AUDIT #%d [%s]", shiftNum, string.upper(state))

	-- Evidence
	evidenceLabel.Text = string.format("EVIDENCE: %d PTS", payload.evidenceCount or 0)

	-- Handle end of shift
	if state == "Completed" or state == "Failed" then
		modalOverlay.Visible = false
	end

	-- Report Feedback Toast
	if payload.reportFeedback and payload.reportFeedback ~= "" then
		showFeedback(payload.reportFeedback, payload.feedbackType or "Neutral")
	end
end)

-- Allow ESC to close the modal
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Escape and modalOverlay.Visible then
		modalOverlay.Visible = false
	end
end)

print("[SHIFT 13] LocalHUDController loaded successfully.")

