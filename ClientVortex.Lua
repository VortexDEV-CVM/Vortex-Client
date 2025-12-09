--[[
    Roblox Client Utility Menu Script (Lua)

    This script creates a simple GUI that allows the local player to modify
    client-side properties like Field of View (FOV), WalkSpeed, JumpPower,
    and includes various client-side exploits:
    
    Mods:
    1. FOV, Speed, Jump.
    2. No Clip.
    3. Kill Aura (Auto-attacks nearest enemy).
    4. Click-to-Teleport.

    To use this, you would typically place it in a LocalScript inside a ScreenGui
    in the StarterGui service.
--]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService") 

if not LocalPlayer then
	warn("LocalPlayer not found. This script must run on the client.")
	return
end

-- =============================================================================
-- Core Variables and State
-- =============================================================================
local defaultWalkSpeed = 16
local boostSpeed = 22
local defaultJumpPower = 50
local boostJumpPower = 60
local defaultFOV = 70
local minFOV = 40
local maxFOV = 120
local currentFOV = defaultFOV

-- Kill Aura Settings
local KILL_AURA_RANGE = 15 -- Max distance in studs for Kill Aura attack

-- References that will hold the GUI instances
local ScreenGui
local MenuFrame
local ScrollFrame -- New ScrollingFrame container
local ShowButton
local fovTextBox
local fovLabel
local speedButton
local jumpButton
local noClipButton
local killAuraButton
local teleportButton 
local HideMenuButton 

-- State variables
local isSpeedBoostActive = false
local isJumpBoostActive = false
local isNoClipActive = false
local isKillAuraActive = false 
local isTeleportActive = false 

-- Runtime connections/threads for continuous mods
local noClipConnection 
local killAuraConnection -- Connection for the kill aura loop
local teleportConnection 

-- =============================================================================
-- Helper Functions (Creation and Connection)
-- =============================================================================

-- Helper function to create standard buttons (inside ScrollFrame)
local function createButton(name, text, positionY)
	local Button = Instance.new("TextButton")
	Button.Name = name
	Button.Text = text
	Button.Size = UDim2.new(0.9, 0, 0, 30)
	Button.Position = UDim2.new(0.05, 0, 0, positionY)
	Button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	Button.TextColor3 = Color3.new(1, 1, 1)
	Button.Font = Enum.Font.SourceSans
	Button.TextSize = 16
	Button.Parent = ScrollFrame -- IMPORTANT: Parented to ScrollFrame

	Button.MouseEnter:Connect(function()
		Button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	end)
	Button.MouseLeave:Connect(function()
		Button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	end)

	return Button
end

-- =============================================================================
-- Mod Logic
-- =============================================================================

-- Logic to set FOV
local function setFOV(input)
	local Camera = game.Workspace.CurrentCamera
	if Camera then
		local newFOV = tonumber(input)
		if newFOV then
			newFOV = math.clamp(newFOV, minFOV, maxFOV)

			Camera.FieldOfView = newFOV
			currentFOV = newFOV
			fovLabel.Text = "Set FOV (Range: "..minFOV.." - "..maxFOV..", Current: "..currentFOV..")"
			fovTextBox.Text = tostring(newFOV)
		else
			fovTextBox.Text = tostring(currentFOV)
			warn("Invalid FOV value entered. Please enter a number.")
		end
	end
end

-- Logic to toggle speed
local function toggleSpeedBoost(humanoid, button)
	isSpeedBoostActive = not isSpeedBoostActive
	if isSpeedBoostActive then
		humanoid.WalkSpeed = boostSpeed
		button.Text = "Mini Speed Boost: ON"
	else
		humanoid.WalkSpeed = defaultWalkSpeed
		button.Text = "Mini Speed Boost: OFF"
	end
end

-- Logic to toggle jump power
local function toggleJumpBoost(humanoid, button)
	isJumpBoostActive = not isJumpBoostActive
	if isJumpBoostActive then
		humanoid.JumpPower = boostJumpPower
		button.Text = "Mini Jump Boost: ON"
	else
		humanoid.JumpPower = defaultJumpPower
		button.Text = "Mini Jump Boost: OFF"
	end
end

-- Logic for No Clip (constantly disables collision on all character parts)
local function toggleNoClip()
	isNoClipActive = not isNoClipActive

	if noClipConnection then
		noClipConnection:Disconnect()
		noClipConnection = nil
	end

	if isNoClipActive then
		noClipButton.Text = "No Clip: ON"

		noClipConnection = RunService.Heartbeat:Connect(function()
			local character = LocalPlayer.Character
			if character then
				for _, part in ipairs(character:GetChildren()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end
		end)
	else
		noClipButton.Text = "No Clip: OFF"
		local character = LocalPlayer.Character
		if character then
			for _, part in ipairs(character:GetChildren()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end
	end
end

-- Logic for Kill Aura (Auto-Attack nearest player)
local function toggleKillAura()
	isKillAuraActive = not isKillAuraActive

	if killAuraConnection then
		killAuraConnection:Disconnect()
		killAuraConnection = nil
	end

	if isKillAuraActive then
		killAuraButton.Text = "Kill Aura: ON"

		killAuraConnection = RunService.Heartbeat:Connect(function()
			local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if not root then return end

			local nearestPlayer
			local shortestDistance = math.huge

			-- 1. Find the nearest enemy player
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					local enemyRoot = player.Character.HumanoidRootPart
					local distance = (root.Position - enemyRoot.Position).magnitude

					if distance <= KILL_AURA_RANGE and distance < shortestDistance then
						shortestDistance = distance
						nearestPlayer = player
					end
				end
			end

			-- 2. Attack the nearest player (if found)
			if nearestPlayer then
				local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
				if tool then
					-- Simulate a mouse click to activate the tool (often triggers damage scripts)
					-- We use the enemy's position to ensure the client targets them.
					local enemyRoot = nearestPlayer.Character.HumanoidRootPart

					-- Simple tool activation
					tool:Activate()

					-- Optionally, if the game uses mouse clicks for damage:
					-- game:GetService("RunService").Stepped:wait() 
					-- tool:Activate()
				end
			end
		end)
	else
		killAuraButton.Text = "Kill Aura: OFF"
	end
end

-- Logic for Click to Teleport
local function doTeleport(input, gameProcessedEvent)
	-- Only act on left click (MouseButton1) and if the click was not processed by a Roblox UI element
	if not gameProcessedEvent and input.UserInputType == Enum.UserInputType.MouseButton1 then
		local camera = game.Workspace.CurrentCamera
		local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not camera or not root then return end

		local mouseX = input.Position.X
		local mouseY = input.Position.Y
		local ray = camera:ScreenPointToRay(mouseX, mouseY)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}

		local raycastResult = game.Workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)

		if raycastResult and raycastResult.Instance and raycastResult.Position then
			local newPosition = raycastResult.Position + Vector3.new(0, 3, 0)
			root.CFrame = CFrame.new(newPosition)
		end
	end
end

local function toggleTeleport()
	isTeleportActive = not isTeleportActive

	if teleportConnection then
		teleportConnection:Disconnect()
		teleportConnection = nil
	end

	if isTeleportActive then
		teleportButton.Text = "Click to Teleport: ON"
		teleportConnection = UserInputService.InputBegan:Connect(doTeleport)
	else
		teleportButton.Text = "Click to Teleport: OFF"
	end
end


-- =============================================================================
-- Connection and Initialization
-- =============================================================================

-- Function to connect ALL button events.
local function connectEvents()
	-- Re-synchronize state from UI text
	isSpeedBoostActive = speedButton.Text == "Mini Speed Boost: ON"
	isJumpBoostActive = jumpButton.Text == "Mini Jump Boost: ON"
	isNoClipActive = noClipButton.Text == "No Clip: ON"
	isKillAuraActive = killAuraButton.Text == "Kill Aura: ON"
	isTeleportActive = teleportButton.Text == "Click to Teleport: ON"

	-- 1. FOV Input Connection
	fovTextBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			setFOV(fovTextBox.Text)
		end
	end)

	-- 2. Speed Button Connection
	speedButton.MouseButton1Click:Connect(function()
		local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then toggleSpeedBoost(humanoid, speedButton) else warn("Humanoid not found!") end
	end)

	-- 3. Jump Button Connection
	jumpButton.MouseButton1Click:Connect(function()
		local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then toggleJumpBoost(humanoid, jumpButton) else warn("Humanoid not found!") end
	end)

	-- 4. No Clip Connection
	noClipButton.MouseButton1Click:Connect(toggleNoClip)

	-- 5. Kill Aura Connection
	killAuraButton.MouseButton1Click:Connect(toggleKillAura)

	-- 6. Teleport Connection
	teleportButton.MouseButton1Click:Connect(toggleTeleport)

	-- 7. Visibility (Hide) Button Connection
	HideMenuButton.MouseButton1Click:Connect(function()
		ShowButton.Position = MenuFrame.Position
		MenuFrame.Visible = false
		ShowButton.Visible = true
	end)

	-- 8. Visibility (Show) Button Connection
	ShowButton.MouseButton1Click:Connect(function()
		MenuFrame.Position = ShowButton.Position
		MenuFrame.Visible = true
		ShowButton.Visible = false
	end)

	-- 9. Character Added Connection (Re-apply effects and mods on respawn)
	LocalPlayer.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		if isSpeedBoostActive then humanoid.WalkSpeed = boostSpeed end
		if isJumpBoostActive then 
			humanoid.JumpPower = boostJumpPower
		end

		setFOV(fovTextBox.Text)

		-- Restart persistent mods (double toggle handles clean reconnect)
		if isNoClipActive then toggleNoClip(); toggleNoClip() end
		if isKillAuraActive then toggleKillAura(); toggleKillAura() end
		if isTeleportActive then toggleTeleport(); toggleTeleport() end
	end)

	-- Initial FOV setup
	setFOV(fovTextBox.Text)

	-- Initial restart of persistent mods (must run once if not already active)
	if isNoClipActive then toggleNoClip(); end
	if isKillAuraActive then toggleKillAura(); end
	if isTeleportActive then toggleTeleport(); end
end


-- =============================================================================
-- Initialization Logic
-- =============================================================================
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local existingScreenGui = playerGui:FindFirstChild("UtilityMenu")

if existingScreenGui then
	-- CASE 1: Menu already exists (due to persistence after death)
	ScreenGui = existingScreenGui
	MenuFrame = ScreenGui:FindFirstChild("MenuFrame")
	ScrollFrame = MenuFrame:FindFirstChild("ScrollFrame") 
	ShowButton = ScreenGui:FindFirstChild("ShowMenuButton")
	HideMenuButton = MenuFrame:FindFirstChild("HideMenuButton") 

	fovLabel = ScrollFrame:FindFirstChild("FOVLabel") 
	fovTextBox = ScrollFrame:FindFirstChild("FOVTextBox")
	speedButton = ScrollFrame:FindFirstChild("SpeedButton")
	jumpButton = ScrollFrame:FindFirstChild("JumpButton")
	noClipButton = ScrollFrame:FindFirstChild("NoClipButton")
	killAuraButton = ScrollFrame:FindFirstChild("KillAuraButton")
	teleportButton = ScrollFrame:FindFirstChild("TeleportButton") 

	print("Vortex Client found existing menu. Re-establishing connections.")
else
	-- CASE 2: Menu needs to be created (first load)
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "UtilityMenu"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.Parent = playerGui 

	MenuFrame = Instance.new("Frame")
	MenuFrame.Name = "MenuFrame"
	MenuFrame.Size = UDim2.new(0, 200, 0, 320)
	MenuFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
	MenuFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	MenuFrame.BorderSizePixel = 0
	MenuFrame.ClipsDescendants = true
	MenuFrame.Draggable = true 
	MenuFrame.Parent = ScreenGui

	-- UI Decoration (Title fixed at top)
	local Title = Instance.new("TextLabel")
	Title.Name = "Title"
	Title.Text = "Vortex Client"
	Title.Size = UDim2.new(1, 0, 0, 30)
	Title.Position = UDim2.new(0, 0, 0, 0)
	Title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	Title.TextColor3 = Color3.new(1, 1, 1)
	Title.Font = Enum.Font.SourceSansBold
	Title.TextSize = 18
	Title.Parent = MenuFrame

	-- SCROLLING FRAME SETUP
	ScrollFrame = Instance.new("ScrollingFrame")
	ScrollFrame.Name = "ScrollFrame"
	ScrollFrame.Size = UDim2.new(1, 0, 1, -60) 
	ScrollFrame.Position = UDim2.new(0, 0, 0, 30)
	ScrollFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	ScrollFrame.BorderSizePixel = 0
	ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 280) -- Adjusted CanvasSize to fit remaining buttons
	ScrollFrame.ScrollBarThickness = 6
	ScrollFrame.Parent = MenuFrame

	-- FOV components (Y positions are relative to ScrollFrame)
	fovLabel = Instance.new("TextLabel")
	fovLabel.Name = "FOVLabel"
	fovLabel.Text = "Set FOV (Range: "..minFOV.." - "..maxFOV..", Current: "..defaultFOV..")"
	fovLabel.Size = UDim2.new(0.9, 0, 0, 20)
	fovLabel.Position = UDim2.new(0.05, 0, 0, 5) 
	fovLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	fovLabel.TextColor3 = Color3.new(1, 1, 1)
	fovLabel.Font = Enum.Font.SourceSans
	fovLabel.TextSize = 14
	fovLabel.TextXAlignment = Enum.TextXAlignment.Left
	fovLabel.Parent = ScrollFrame

	fovTextBox = Instance.new("TextBox")
	fovTextBox.Name = "FOVTextBox"
	fovTextBox.PlaceholderText = "Enter FOV (e.g., 90)"
	fovTextBox.Text = tostring(defaultFOV)
	fovTextBox.Size = UDim2.new(0.9, 0, 0, 30)
	fovTextBox.Position = UDim2.new(0.05, 0, 0, 30)
	fovTextBox.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	fovTextBox.TextColor3 = Color3.new(1, 1, 1)
	fovTextBox.TextStrokeTransparency = 0
	fovTextBox.Font = Enum.Font.SourceSans
	fovTextBox.TextSize = 16
	fovTextBox.TextYAlignment = Enum.TextYAlignment.Center
	fovTextBox.Parent = ScrollFrame

	-- Mod buttons (Y positions are relative to ScrollFrame)
	speedButton = createButton("SpeedButton", "Mini Speed Boost: OFF", 75) 
	jumpButton = createButton("JumpButton", "Mini Jump Boost: OFF", 115) 
	noClipButton = createButton("NoClipButton", "No Clip: OFF", 155)
	killAuraButton = createButton("KillAuraButton", "Kill Aura: OFF", 195) -- Moved up
	teleportButton = createButton("TeleportButton", "Click to Teleport: OFF", 235) -- Moved up

	-- Hide/Show components
	HideMenuButton = Instance.new("TextButton")
	HideMenuButton.Name = "HideMenuButton"
	HideMenuButton.Text = "Hide Menu"
	HideMenuButton.Size = UDim2.new(0.9, 0, 0, 30)
	HideMenuButton.Position = UDim2.new(0.05, 0, 0, 285)
	HideMenuButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	HideMenuButton.TextColor3 = Color3.new(1, 1, 1)
	HideMenuButton.Font = Enum.Font.SourceSansBold
	HideMenuButton.TextSize = 16
	HideMenuButton.BorderSizePixel = 0
	HideMenuButton.Parent = MenuFrame 

	HideMenuButton.MouseEnter:Connect(function()
		HideMenuButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	end)
	HideMenuButton.MouseLeave:Connect(function()
		HideMenuButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	end)

	ShowButton = Instance.new("TextButton")
	ShowButton.Name = "ShowMenuButton"
	ShowButton.Text = "Show Menu"
	ShowButton.Size = UDim2.new(0, 80, 0, 25)
	ShowButton.Position = MenuFrame.Position
	ShowButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	ShowButton.TextColor3 = Color3.new(1, 1, 1)
	ShowButton.Font = Enum.Font.SourceSansBold
	ShowButton.TextSize = 14
	ShowButton.BorderSizePixel = 0
	ShowButton.Visible = false
	ShowButton.Draggable = true 
	ShowButton.Parent = ScreenGui

	ShowButton.MouseEnter:Connect(function(this)
		this.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	end)
	ShowButton.MouseLeave:Connect(function(this)
		this.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	end)

	print("Vortex Client Initialized and created new menu.")
end

-- Connect all event handlers (runs for both new creation and existing menu reload)
connectEvents()

print("Vortex Client functionality active and persistent.")
