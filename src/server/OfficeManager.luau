--!strict
--[[
	OfficeManager.luau
	Server-side environment controller for SHIFT 13: The Night Audit
	
	Responsible for:
	1. Generating or binding to the physical office environment in Workspace.
	2. Maintaining the pristine baseline state for all office props.
	3. Applying visual and physical environmental mutations for each anomaly category.
	4. Resetting the room cleanly between shifts.
]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local OfficeManager = {}

-- Store references to office props
local officeFolder: Folder? = nil
type PropsTable = {
	Light: PointLight?,
	LightFixture: BasePart?,
	Door: BasePart?,
	DoorFrame: BasePart?,
	Chair: BasePart?,
	Cabinet: BasePart?,
	ClockFace: BasePart?,
	MinuteHand: BasePart?,
	HourHand: BasePart?,
	Painting: BasePart?,
	PaintingImage: Decal?,
	TerminalScreen: BasePart?,
	TerminalGui: SurfaceGui?,
	TerminalText: TextLabel?,
	TerminalPrompt: ProximityPrompt?,
}

local props: PropsTable = {
	Light = nil,
	LightFixture = nil,
	Door = nil,
	DoorFrame = nil,
	Chair = nil,
	Cabinet = nil,
	ClockFace = nil,
	MinuteHand = nil,
	HourHand = nil,
	Painting = nil,
	PaintingImage = nil,
	TerminalScreen = nil,
	TerminalGui = nil,
	TerminalText = nil,
	TerminalPrompt = nil,
}

-- Baseline transforms and properties
local baseline = {
	ChairCFrame = CFrame.new(),
	CabinetCFrame = CFrame.new(),
	DoorCFrame = CFrame.new(),
	PaintingCFrame = CFrame.new(),
	LightColor = Color3.fromRGB(240, 245, 255),
	LightBrightness = 2.0,
	TerminalColor = Color3.fromRGB(20, 20, 25),
	TerminalScreenText = "AUDIT TERMINAL OS v1.03\nSTATUS: ONLINE\nSTANDBY FOR INPUT...",
	TerminalScreenColor = Color3.fromRGB(0, 255, 128),
}

-- Active runtime connections (e.g. flickering light, spinning clock)
local activeConnections: { [string]: RBXScriptConnection } = {}

-- Helper to safely create an anchored part
local function createPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Builds a retro atmospheric 1980s audit office if one doesn't exist
function OfficeManager.EnsureEnvironment(): Folder
	local existing = Workspace:FindFirstChild("OfficeEnvironment")
	if existing and existing:IsA("Folder") then
		officeFolder = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = "OfficeEnvironment"
		folder.Parent = Workspace
		officeFolder = folder

		local center = Vector3.new(0, 5, 0)
		local roomWidth = 28
		local roomLength = 32
		local roomHeight = 12

		-- Floor (Dark industrial carpet)
		createPart("Floor", Vector3.new(roomWidth, 1, roomLength), CFrame.new(center + Vector3.new(0, -0.5, 0)), Color3.fromRGB(35, 38, 45), Enum.Material.Fabric, folder)

		-- Ceiling
		createPart("Ceiling", Vector3.new(roomWidth, 1, roomLength), CFrame.new(center + Vector3.new(0, roomHeight, 0)), Color3.fromRGB(50, 52, 58), Enum.Material.SmoothPlastic, folder)

		-- North Wall (Behind desk)
		createPart("NorthWall", Vector3.new(roomWidth, roomHeight, 1), CFrame.new(center + Vector3.new(0, roomHeight / 2, -roomLength / 2)), Color3.fromRGB(60, 65, 72), Enum.Material.WoodPlanks, folder)

		-- South Wall (With entrance door opening)
		createPart("SouthWallLeft", Vector3.new(11, roomHeight, 1), CFrame.new(center + Vector3.new(-8.5, roomHeight / 2, roomLength / 2)), Color3.fromRGB(60, 65, 72), Enum.Material.WoodPlanks, folder)
		createPart("SouthWallRight", Vector3.new(11, roomHeight, 1), CFrame.new(center + Vector3.new(8.5, roomHeight / 2, roomLength / 2)), Color3.fromRGB(60, 65, 72), Enum.Material.WoodPlanks, folder)
		createPart("SouthWallTop", Vector3.new(6, 4, 1), CFrame.new(center + Vector3.new(0, roomHeight - 2, roomLength / 2)), Color3.fromRGB(60, 65, 72), Enum.Material.WoodPlanks, folder)

		-- West Wall
		createPart("WestWall", Vector3.new(1, roomHeight, roomLength), CFrame.new(center + Vector3.new(-roomWidth / 2, roomHeight / 2, 0)), Color3.fromRGB(60, 65, 72), Enum.Material.WoodPlanks, folder)

		-- East Wall
		createPart("EastWall", Vector3.new(1, roomHeight, roomLength), CFrame.new(center + Vector3.new(roomWidth / 2, roomHeight / 2, 0)), Color3.fromRGB(60, 65, 72), Enum.Material.WoodPlanks, folder)

		-- Main Ceiling Light Fixture
		local fixture = createPart("CeilingLight", Vector3.new(6, 0.4, 3), CFrame.new(center + Vector3.new(0, roomHeight - 0.3, 0)), Color3.fromRGB(240, 240, 230), Enum.Material.Neon, folder)
		local pLight = Instance.new("PointLight")
		pLight.Name = "Light"
		pLight.Color = baseline.LightColor
		pLight.Brightness = baseline.LightBrightness
		pLight.Range = 38
		pLight.Shadows = true
		pLight.Parent = fixture

		-- Desk
		local desk = createPart("Desk", Vector3.new(8, 3, 4.5), CFrame.new(center + Vector3.new(0, 1.5, -6)), Color3.fromRGB(80, 50, 30), Enum.Material.Wood, folder)

		-- Terminal Computer on Desk
		local terminalBase = createPart("TerminalBase", Vector3.new(2.4, 0.4, 2), CFrame.new(center + Vector3.new(0, 3.2, -6)), Color3.fromRGB(160, 155, 140), Enum.Material.SmoothPlastic, folder)
		local terminalScreen = createPart("TerminalScreen", Vector3.new(2.2, 1.6, 0.3), CFrame.new(center + Vector3.new(0, 4.2, -5.6)), baseline.TerminalColor, Enum.Material.SmoothPlastic, folder)
		terminalScreen.Parent = folder

		-- SurfaceGui on the screen
		local sGui = Instance.new("SurfaceGui")
		sGui.Name = "TerminalDisplay"
		sGui.Face = Enum.NormalId.Back
		sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sGui.PixelsPerStud = 50
		sGui.Parent = terminalScreen

		local screenLabel = Instance.new("TextLabel")
		screenLabel.Name = "StatusText"
		screenLabel.Size = UDim2.new(1, 0, 1, 0)
		screenLabel.BackgroundColor3 = Color3.fromRGB(10, 12, 15)
		screenLabel.TextColor3 = baseline.TerminalScreenColor
		screenLabel.Font = Enum.Font.Code
		screenLabel.TextSize = 18
		screenLabel.TextWrapped = true
		screenLabel.Text = baseline.TerminalScreenText
		screenLabel.Parent = sGui

		-- Proximity Prompt for interaction
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "AuditPrompt"
		prompt.ActionText = "Audit Terminal"
		prompt.ObjectText = "File Shift Report"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = terminalScreen

		-- Office Chair behind desk
		local chair = createPart("OfficeChair", Vector3.new(2.5, 3.5, 2.5), CFrame.new(center + Vector3.new(0, 1.75, -9.5)), Color3.fromRGB(30, 30, 35), Enum.Material.SmoothPlastic, folder)

		-- Filing Cabinet
		local cabinet = createPart("FilingCabinet", Vector3.new(2.5, 6, 2.5), CFrame.new(center + Vector3.new(-10, 3, -10)), Color3.fromRGB(100, 105, 110), Enum.Material.Metal, folder)

		-- Office Door (In South opening)
		local door = createPart("OfficeDoor", Vector3.new(5.8, 8, 0.6), CFrame.new(center + Vector3.new(0, 4, roomLength / 2)), Color3.fromRGB(75, 45, 25), Enum.Material.Wood, folder)

		-- Wall Clock on North Wall
		local clockFace = createPart("ClockFace", Vector3.new(3, 3, 0.3), CFrame.new(center + Vector3.new(0, 8.5, -roomLength / 2 + 0.6)), Color3.fromRGB(235, 235, 225), Enum.Material.SmoothPlastic, folder)
		local minuteHand = createPart("MinuteHand", Vector3.new(0.2, 1.2, 0.1), CFrame.new(center + Vector3.new(0, 8.8, -roomLength / 2 + 0.75)), Color3.fromRGB(20, 20, 20), Enum.Material.Metal, folder)
		local hourHand = createPart("HourHand", Vector3.new(0.25, 0.8, 0.1), CFrame.new(center + Vector3.new(0, 8.6, -roomLength / 2 + 0.75)), Color3.fromRGB(20, 20, 20), Enum.Material.Metal, folder)

		-- Framed Wall Painting on East Wall
		local painting = createPart("OfficePainting", Vector3.new(0.3, 4.5, 6), CFrame.new(center + Vector3.new(roomWidth / 2 - 0.3, 7, 0)), Color3.fromRGB(120, 90, 50), Enum.Material.Wood, folder)
		local decal = Instance.new("Decal")
		decal.Name = "ArtDecal"
		decal.Face = Enum.NormalId.Left
		decal.Texture = "rbxassetid://138356974" -- Stock landscape texture
		decal.Parent = painting

		-- Spawn Location inside the office
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "AuditSpawn"
		spawn.Size = Vector3.new(6, 0.5, 6)
		spawn.CFrame = CFrame.new(center + Vector3.new(0, 0.25, 6))
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.Transparency = 1
		spawn.Duration = 0
		spawn.Parent = folder
	end

	-- Cache references
	local f = officeFolder :: Folder
	props.LightFixture = f:FindFirstChild("CeilingLight") :: BasePart?
	if props.LightFixture then
		props.Light = props.LightFixture:FindFirstChild("Light") :: PointLight?
	end
	props.Door = f:FindFirstChild("OfficeDoor") :: BasePart?
	props.Chair = f:FindFirstChild("OfficeChair") :: BasePart?
	props.Cabinet = f:FindFirstChild("FilingCabinet") :: BasePart?
	props.ClockFace = f:FindFirstChild("ClockFace") :: BasePart?
	props.MinuteHand = f:FindFirstChild("MinuteHand") :: BasePart?
	props.HourHand = f:FindFirstChild("HourHand") :: BasePart?
	props.Painting = f:FindFirstChild("OfficePainting") :: BasePart?
	if props.Painting then
		props.PaintingImage = props.Painting:FindFirstChild("ArtDecal") :: Decal?
	end
	props.TerminalScreen = f:FindFirstChild("TerminalScreen") :: BasePart?
	if props.TerminalScreen then
		props.TerminalPrompt = props.TerminalScreen:FindFirstChild("AuditPrompt") :: ProximityPrompt?
		local sGui = props.TerminalScreen:FindFirstChild("TerminalDisplay") :: SurfaceGui?
		if sGui then
			props.TerminalText = sGui:FindFirstChild("StatusText") :: TextLabel?
		end
	end

	-- Store baseline CFrames
	if props.Chair then baseline.ChairCFrame = props.Chair.CFrame end
	if props.Cabinet then baseline.CabinetCFrame = props.Cabinet.CFrame end
	if props.Door then baseline.DoorCFrame = props.Door.CFrame end
	if props.Painting then baseline.PaintingCFrame = props.Painting.CFrame end

	return f
end

-- Stops any running animations/tweens/heartbeat loops
local function stopActiveMutations()
	for key, conn in pairs(activeConnections) do
		conn:Disconnect()
		activeConnections[key] = nil
	end
end

-- Resets all props to their exact baseline normal state
function OfficeManager.SetBaseline()
	stopActiveMutations()

	-- Reset Light
	if props.Light then
		props.Light.Enabled = true
		props.Light.Color = baseline.LightColor
		props.Light.Brightness = baseline.LightBrightness
	end
	if props.LightFixture then
		props.LightFixture.Color = Color3.fromRGB(240, 240, 230)
		props.LightFixture.Material = Enum.Material.Neon
	end

	-- Reset Furniture
	if props.Chair then
		props.Chair.CFrame = baseline.ChairCFrame
		props.Chair.Color = Color3.fromRGB(30, 30, 35)
	end
	if props.Cabinet then
		props.Cabinet.CFrame = baseline.CabinetCFrame
	end

	-- Reset Door
	if props.Door then
		props.Door.CFrame = baseline.DoorCFrame
	end

	-- Reset Painting
	if props.Painting then
		props.Painting.CFrame = baseline.PaintingCFrame
		props.Painting.Color = Color3.fromRGB(120, 90, 50)
	end
	if props.PaintingImage then
		props.PaintingImage.Transparency = 0
		props.PaintingImage.Color3 = Color3.new(1, 1, 1)
	end

	-- Reset Clock
	if props.ClockFace then
		props.ClockFace.Color = Color3.fromRGB(235, 235, 225)
	end
	if props.MinuteHand and props.ClockFace then
		props.MinuteHand.CFrame = props.ClockFace.CFrame * CFrame.new(0, 0.4, 0.15)
	end
	if props.HourHand and props.ClockFace then
		props.HourHand.CFrame = props.ClockFace.CFrame * CFrame.new(0, 0.25, 0.15)
	end

	-- Reset Terminal Screen
	if props.TerminalScreen then
		props.TerminalScreen.Color = baseline.TerminalColor
	end
	if props.TerminalText then
		props.TerminalText.Text = baseline.TerminalScreenText
		props.TerminalText.TextColor3 = baseline.TerminalScreenColor
		props.TerminalText.BackgroundColor3 = Color3.fromRGB(10, 12, 15)
	end
end

-- Mutates the environment based on the chosen anomaly category
function OfficeManager.ApplyAnomaly(anomalyId: string)
	-- Always clear previous state first
	OfficeManager.SetBaseline()

	if anomalyId == "Normal" then
		-- Intentionally normal
		return
	elseif anomalyId == "ClockTime" then
		-- Anomaly 1: Wall Clock hands spin wildly out of control and clock glows blood-tinted
		if props.ClockFace then
			props.ClockFace.Color = Color3.fromRGB(255, 180, 180)
		end
		local clockAngle = 0
		activeConnections["ClockSpin"] = RunService.Heartbeat:Connect(function(dt: number)
			clockAngle += dt * 720 -- 2 full rotations per second
			if props.MinuteHand and props.ClockFace then
				props.MinuteHand.CFrame = props.ClockFace.CFrame 
					* CFrame.Angles(0, 0, math.rad(clockAngle)) 
					* CFrame.new(0, 0.4, 0.15)
			end
			if props.HourHand and props.ClockFace then
				props.HourHand.CFrame = props.ClockFace.CFrame 
					* CFrame.Angles(0, 0, math.rad(-clockAngle * 0.5)) 
					* CFrame.new(0, 0.25, 0.15)
			end
		end)

	elseif anomalyId == "FurnitureShift" then
		-- Anomaly 2: Office chair levitates 3.5 studs into the air and rotates unnaturally
		if props.Chair then
			props.Chair.CFrame = baseline.ChairCFrame * CFrame.new(0, 3.5, 1) * CFrame.Angles(math.rad(35), math.rad(180), math.rad(-20))
			props.Chair.Color = Color3.fromRGB(60, 20, 20)
		end

	elseif anomalyId == "TerminalError" then
		-- Anomaly 3: Terminal display glitched with eerie warning and pulsing blood-red neon
		if props.TerminalScreen then
			props.TerminalScreen.Color = Color3.fromRGB(180, 0, 0)
		end
		if props.TerminalText then
			props.TerminalText.Text = "SYSTEM OVERRIDE\n[ANOMALY MANIFESTED]\nDO NOT TRUST YOUR MEMORY\nERROR CODE: 0x666_AUDIT"
			props.TerminalText.TextColor3 = Color3.fromRGB(255, 60, 60)
			props.TerminalText.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
		end

	elseif anomalyId == "DoorAjar" then
		-- Anomaly 4: The office door has swung open 75 degrees into pitch black darkness
		if props.Door then
			-- Pivot door on its hinge
			local hingeOffset = CFrame.new(2.8, 0, 0)
			props.Door.CFrame = baseline.DoorCFrame * hingeOffset * CFrame.Angles(0, math.rad(75), 0) * hingeOffset:Inverse()
		end

	elseif anomalyId == "FlickeringLight" then
		-- Anomaly 5: Ceiling fluorescent lamp violently flickers and shifts to an ominous amber hue
		if props.Light then
			props.Light.Color = Color3.fromRGB(255, 120, 40)
		end
		if props.LightFixture then
			props.LightFixture.Color = Color3.fromRGB(255, 140, 60)
		end
		local timer = 0
		local flickerInterval = 0.15
		activeConnections["LightFlicker"] = RunService.Heartbeat:Connect(function(dt: number)
			timer += dt
			if timer >= flickerInterval then
				timer = 0
				flickerInterval = math.random(5, 25) / 100 -- 0.05s to 0.25s
				if props.Light then
					props.Light.Enabled = (math.random(1, 10) > 4)
					props.Light.Brightness = math.random(10, 30) / 10
				end
			end
		end)

	elseif anomalyId == "PaintingChange" then
		-- Anomaly 6: Wall Painting has flipped 180 degrees upside down with inverted color tint
		if props.Painting then
			props.Painting.CFrame = baseline.PaintingCFrame * CFrame.Angles(0, 0, math.rad(180))
			props.Painting.Color = Color3.fromRGB(30, 0, 0)
		end
		if props.PaintingImage then
			props.PaintingImage.Color3 = Color3.fromRGB(255, 100, 100)
		end
	end
end

-- Get ProximityPrompt instance
function OfficeManager.GetTerminalPrompt(): ProximityPrompt?
	return props.TerminalPrompt
end

return OfficeManager
