-- ========================================================================
--  PROJECT MAKI: ENCHANTED FOREST (NIGHTMARE) LOBBY AUTO-CREATE ENGINE
--  - Automatically detects Main Lobby (PlaceId: 77649408247578)
--  - Creates Private "Enchanted Forest" [Nightmare] immediately
--  - Hardcore Toggle (Default: OFF / Non-Hardcore)
--  - 100% Mobile Touch & PC Draggable HUD (TouchTap, MouseButton1Click, Activated)
--  - Zero hotkeys: 100% pure touch/click interface for full mobile reliability
--  - Saves persistent settings to ef_settings.json
-- ========================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ========================================================================
-- 1. MAIN LOBBY DETECTION
-- ========================================================================
local PlaceManager
pcall(function()
    PlaceManager = require(ReplicatedStorage:WaitForChild("Utility", 5):WaitForChild("PlaceManager", 5))
end)

local function isMainLobby()
    if game.PlaceId == 77649408247578 then return true end
    if PlaceManager and typeof(PlaceManager.GetPlaceName) == "function" and PlaceManager.GetPlaceName(game.PlaceId) == "Lobby" then
        return true
    end
    if not workspace:FindFirstChild("dungeon") and workspace:FindFirstChild("games") then
        return true
    end
    return false
end

if not isMainLobby() then
    print(string.format("[EF Lobby Manager] Detected place is not the Main Lobby (PlaceId: %d). Skipping lobby script.", game.PlaceId))
    return
end

print("[EF Lobby Manager] Main Lobby detected! Initializing Auto-Create Engine...")

-- ========================================================================
-- 2. PERSISTENT SETTINGS (ef_settings.json)
-- ========================================================================
local SETTINGS_FILE = "ef_settings.json"

local function loadSettings()
    local defaults = {
        potatoMode = true,
        autoReplay = true,
        autoSell = true,
        hardcore = false,    -- Default: Non-Hardcore as requested
        autoCreate = true    -- Default: Auto-Create immediately upon joining lobby
    }
    pcall(function()
        if typeof(isfile) == "function" and isfile(SETTINGS_FILE) then
            local data = readfile(SETTINGS_FILE)
            local decoded = HttpService:JSONDecode(data)
            if type(decoded) == "table" then
                if decoded.potatoMode ~= nil then defaults.potatoMode = decoded.potatoMode end
                if decoded.autoReplay ~= nil then defaults.autoReplay = decoded.autoReplay end
                if decoded.autoSell ~= nil then defaults.autoSell = decoded.autoSell end
                if decoded.hardcore ~= nil then defaults.hardcore = decoded.hardcore end
                if decoded.autoCreate ~= nil then defaults.autoCreate = decoded.autoCreate end
            end
        end
    end)
    return defaults
end

local function saveSettings(settingsTable)
    pcall(function()
        if typeof(writefile) == "function" then
            local encoded = HttpService:JSONEncode(settingsTable)
            writefile(SETTINGS_FILE, encoded)
        end
    end)
end

local currentSettings = loadSettings()
saveSettings(currentSettings)
local isHardcore = currentSettings.hardcore
local autoCreate = currentSettings.autoCreate
local isCreatingOrStarting = false

-- ========================================================================
-- 3. MOBILE & PC DRAGGABLE LOBBY HUD (100% CLICK / TOUCH DRIVEN)
-- ========================================================================
local guiParent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if typeof(gethui) == "function" then
        guiParent = gethui()
    elseif CoreGui then
        guiParent = CoreGui
    end
end)

local oldGui = guiParent:FindFirstChild("EF_Lobby_HUD")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EF_Lobby_HUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = guiParent

local hudFrame = Instance.new("Frame", screenGui)
hudFrame.Name = "MainFrame"
hudFrame.Size = UDim2.new(0, 225, 0, 172)
hudFrame.Position = UDim2.new(1, -240, 0.5, -86)
hudFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
hudFrame.BackgroundTransparency = 0.15
hudFrame.BorderSizePixel = 0
Instance.new("UICorner", hudFrame).CornerRadius = UDim.new(0, 8)

local hudStroke = Instance.new("UIStroke", hudFrame)
hudStroke.Color = Color3.fromRGB(0, 220, 255)
hudStroke.Thickness = 1.5

local titleLabel = Instance.new("TextLabel", hudFrame)
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -16, 0, 20)
titleLabel.Position = UDim2.new(0, 8, 0, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "ENCHANTED FOREST LOBBY"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Center

local targetLabel = Instance.new("TextLabel", hudFrame)
targetLabel.Name = "TargetLabel"
targetLabel.Size = UDim2.new(1, -16, 0, 16)
targetLabel.Position = UDim2.new(0, 8, 0, 26)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "Target: Private EF [Nightmare]"
targetLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
targetLabel.Font = Enum.Font.SourceSansBold
targetLabel.TextSize = 12
targetLabel.TextXAlignment = Enum.TextXAlignment.Left

local statusLabel = Instance.new("TextLabel", hudFrame)
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -16, 0, 16)
statusLabel.Position = UDim2.new(0, 8, 0, 44)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Initializing..."
statusLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Button 1: Immediate Manual Create & Start
local createBtn = Instance.new("TextButton", hudFrame)
createBtn.Name = "CreateBtn"
createBtn.Size = UDim2.new(1, -16, 0, 28)
createBtn.Position = UDim2.new(0, 8, 0, 66)
createBtn.BackgroundColor3 = Color3.fromRGB(30, 140, 70)
createBtn.Text = "[ 🚀 CREATE & START NOW ]"
createBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
createBtn.Font = Enum.Font.SourceSansBold
createBtn.TextSize = 12
createBtn.Active = true
createBtn.AutoButtonColor = true
createBtn.ZIndex = 10
Instance.new("UICorner", createBtn).CornerRadius = UDim.new(0, 6)

-- Button 2: Hardcore Toggle (Default: OFF)
local hardcoreBtn = Instance.new("TextButton", hudFrame)
hardcoreBtn.Name = "HardcoreBtn"
hardcoreBtn.Size = UDim2.new(1, -16, 0, 28)
hardcoreBtn.Position = UDim2.new(0, 8, 0, 98)
hardcoreBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
hardcoreBtn.Text = "[ 💀 HARDCORE: OFF ]"
hardcoreBtn.TextColor3 = Color3.fromRGB(190, 210, 235)
hardcoreBtn.Font = Enum.Font.SourceSansBold
hardcoreBtn.TextSize = 12
hardcoreBtn.Active = true
hardcoreBtn.AutoButtonColor = true
hardcoreBtn.ZIndex = 10
Instance.new("UICorner", hardcoreBtn).CornerRadius = UDim.new(0, 6)

-- Button 3: Auto-Create Toggle (Default: ON)
local autoCreateBtn = Instance.new("TextButton", hudFrame)
autoCreateBtn.Name = "AutoCreateBtn"
autoCreateBtn.Size = UDim2.new(1, -16, 0, 28)
autoCreateBtn.Position = UDim2.new(0, 8, 0, 130)
autoCreateBtn.BackgroundColor3 = Color3.fromRGB(20, 130, 160)
autoCreateBtn.Text = "[ 🔄 AUTO-CREATE: ON ]"
autoCreateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoCreateBtn.Font = Enum.Font.SourceSansBold
autoCreateBtn.TextSize = 12
autoCreateBtn.Active = true
autoCreateBtn.AutoButtonColor = true
autoCreateBtn.ZIndex = 10
Instance.new("UICorner", autoCreateBtn).CornerRadius = UDim.new(0, 6)

-- UI Update Functions
local function updateHardcoreBtnUI()
    if isHardcore then
        hardcoreBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        hardcoreBtn.Text = "[ 💀 HARDCORE: ON ]"
        hardcoreBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        hardcoreBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
        hardcoreBtn.Text = "[ 💀 HARDCORE: OFF ]"
        hardcoreBtn.TextColor3 = Color3.fromRGB(190, 210, 235)
    end
end

local function toggleHardcore()
    isHardcore = not isHardcore
    currentSettings.hardcore = isHardcore
    saveSettings(currentSettings)
    updateHardcoreBtnUI()
    if isHardcore then
        print("[EF Lobby Manager] Hardcore mode ENABLED! (Saved to settings)")
    else
        print("[EF Lobby Manager] Hardcore mode DISABLED (Normal)! (Saved to settings)")
    end
end

local function updateAutoCreateBtnUI()
    if autoCreate then
        autoCreateBtn.BackgroundColor3 = Color3.fromRGB(20, 130, 160)
        autoCreateBtn.Text = "[ 🔄 AUTO-CREATE: ON ]"
        autoCreateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        autoCreateBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
        autoCreateBtn.Text = "[ 🔄 AUTO-CREATE: OFF ]"
        autoCreateBtn.TextColor3 = Color3.fromRGB(190, 210, 235)
    end
end

local function toggleAutoCreate()
    autoCreate = not autoCreate
    currentSettings.autoCreate = autoCreate
    saveSettings(currentSettings)
    updateAutoCreateBtnUI()
    if autoCreate then
        print("[EF Lobby Manager] Auto-Create ENABLED! (Saved to settings)")
    else
        print("[EF Lobby Manager] Auto-Create DISABLED! (Saved to settings)")
        statusLabel.Text = "Status: Auto-create paused"
        statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
end

updateHardcoreBtnUI()
updateAutoCreateBtnUI()

-- Connect Click, Tap and Activated (100% Mobile + PC compatible)
hardcoreBtn.Activated:Connect(toggleHardcore)
hardcoreBtn.MouseButton1Click:Connect(toggleHardcore)
pcall(function() hardcoreBtn.TouchTap:Connect(toggleHardcore) end)

autoCreateBtn.Activated:Connect(toggleAutoCreate)
autoCreateBtn.MouseButton1Click:Connect(toggleAutoCreate)
pcall(function() autoCreateBtn.TouchTap:Connect(toggleAutoCreate) end)

-- Mobile Touch Drag Isolation
local function isInsideButton(btn, inputPos)
    if not btn or not btn.Visible then return false end
    local bPos = btn.AbsolutePosition
    local bSize = btn.AbsoluteSize
    return inputPos.X >= bPos.X and inputPos.X <= (bPos.X + bSize.X) and
           inputPos.Y >= bPos.Y and inputPos.Y <= (bPos.Y + bSize.Y)
end

local dragging = false
local dragStart = Vector2.zero
local startPos = UDim2.new()

hudFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if isInsideButton(createBtn, input.Position) or
           isInsideButton(hardcoreBtn, input.Position) or
           isInsideButton(autoCreateBtn, input.Position) then
            return
        end
        dragging = true
        dragStart = input.Position
        startPos = hudFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

hudFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            local delta = input.Position - dragStart
            hudFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end
end)

-- ========================================================================
-- 4. DUNGEON CREATION & START ENGINE
-- ========================================================================
local function cleanOldLobbies()
    pcall(function()
        local games = workspace:FindFirstChild("games")
        local inLobby = games and games:FindFirstChild("inLobby")
        if inLobby and inLobby:FindFirstChild(LocalPlayer.Name) then
            local remotes = ReplicatedStorage:FindFirstChild("remotes")
            if remotes and remotes:FindFirstChild("leaveGame") then
                remotes.leaveGame:FireServer()
                task.wait(0.3)
            end
        end
    end)
end

local function createAndStartDungeon()
    if isCreatingOrStarting then return end
    isCreatingOrStarting = true

    statusLabel.Text = "Status: Preparing lobby..."
    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)

    local remotes = ReplicatedStorage:WaitForChild("remotes", 10)
    if not remotes then
        statusLabel.Text = "Error: remotes not found!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        isCreatingOrStarting = false
        return
    end

    local createRemote = remotes:WaitForChild("createLobby", 5)
    local startRemote = remotes:WaitForChild("startDungeon", 5)

    if not createRemote or not startRemote then
        statusLabel.Text = "Error: Lobby remotes missing!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        isCreatingOrStarting = false
        return
    end

    cleanOldLobbies()

    local hcModeText = isHardcore and "HARDCORE" or "NORMAL"
    statusLabel.Text = string.format("Status: Creating Private EF (%s)...", hcModeText)
    statusLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
    print(string.format("[EF Lobby Manager] Creating Private Enchanted Forest Nightmare (%s)...", hcModeText))

    local createSuccess, res = pcall(function()
        return createRemote:InvokeServer("Enchanted Forest", "Nightmare", 0, isHardcore, true, false)
    end)

    if not createSuccess or res ~= true then
        statusLabel.Text = "Status: Create failed, retrying in 2s..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        print("[EF Lobby Manager] createLobby failed or returned false. Will retry...")
        isCreatingOrStarting = false
        task.wait(2.0)
        if autoCreate then
            createAndStartDungeon()
        end
        return
    end

    statusLabel.Text = "Status: Lobby created! Starting dungeon..."
    statusLabel.TextColor3 = Color3.fromRGB(80, 255, 140)
    print("[EF Lobby Manager] Lobby created successfully! Starting dungeon...")

    task.wait(0.35)

    pcall(function()
        startRemote:FireServer()
    end)

    statusLabel.Text = "Status: Teleporting to Enchanted Forest..."
    statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    print("[EF Lobby Manager] Teleporting to Enchanted Forest Nightmare!")
end

createBtn.Activated:Connect(createAndStartDungeon)
createBtn.MouseButton1Click:Connect(createAndStartDungeon)
pcall(function() createBtn.TouchTap:Connect(createAndStartDungeon) end)

_G.EF_LOBBY_CREATE = createAndStartDungeon

-- ========================================================================
-- 5. AUTO-CREATE TRIGGER ON JOIN
-- ========================================================================
task.spawn(function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.6)

    if autoCreate then
        createAndStartDungeon()
    else
        statusLabel.Text = "Status: Ready (Auto-create is OFF)"
        statusLabel.TextColor3 = Color3.fromRGB(160, 200, 240)
    end
end)

print("[EF Lobby Manager] Lobby Auto-Create Engine Loaded Successfully!")
