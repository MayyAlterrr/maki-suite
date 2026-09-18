-- ========================================================================
--  PROJECT MAKI: STANDALONE PARTY LAUNCHER & COORDINATOR
--  VERSION: 2.0 (FULL ZERO-CLICK AUTONOMOUS EDITION)
-- ========================================================================
--  FEATURES:
--    • 100% Zero-Click Full Automation:
--        - Automatically creates private party lobby on Host.
--        - Automatically whitelists selected accounts.
--        - Automatically sends join requests & readies up on Members.
--        - Automatically launches dungeon match as soon as party is assembled.
--    • Fixed Layout: Difficulty row and Hardcore toggle have dedicated spaces
--      with zero visual overlap.
--    • Instant Persistent Storage: Automatically remembers your chosen
--      Dungeon, Difficulty, Hardcore setting, Host, and Party Accounts.
--    • Live Visual Feedback: Shows which accounts have joined the party in real-time.
-- ========================================================================

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

local CONFIG_FILE = "maki_party_launcher_config.json"

-- Prevent duplicate instances
if _G.MAKI_PARTY_LAUNCHER_RUNNING then
    _G.MAKI_PARTY_LAUNCHER_RUNNING = false
    task.wait(0.2)
end
_G.MAKI_PARTY_LAUNCHER_RUNNING = true

local function getGuiParent()
    if typeof(gethui) == "function" then
        return gethui()
    elseif CoreGui then
        return CoreGui
    else
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

-- ========================================================================
--  [1] NETWORKING & REMOTES
-- ========================================================================
local remotes = ReplicatedStorage:WaitForChild("remotes", 15)
local createLobbyRemote          = remotes and remotes:FindFirstChild("createLobby")
local addPlayerToWhitelistRemote = remotes and remotes:FindFirstChild("addPlayerToWhitelist")
local startDungeonRemote         = remotes and remotes:FindFirstChild("startDungeon")
local changeStartValueRemote     = remotes and remotes:FindFirstChild("changeStartValue")
local sendJoinRequestRemote      = remotes and remotes:FindFirstChild("sendJoinRequest")
local joinDungeonRemote          = remotes and remotes:FindFirstChild("joinDungeon")
local respondJoinRequestRemote   = remotes and remotes:FindFirstChild("respondJoinRequest")
local readyUpRemote              = remotes and remotes:FindFirstChild("readyUp")
local showJoinRemote             = remotes and remotes:FindFirstChild("showJoinRequest")

-- ========================================================================
--  [2] DUNGEON DATA & LEVEL REQUIREMENTS
-- ========================================================================
local DUNGEONS = {
    "Desert Temple",
    "Winter Outpost",
    "Pirate Island",
    "King's Castle",
    "The Underworld",
    "Samurai Palace",
    "The Canals",
    "Ghastly Harbor",
    "Steampunk Sewers",
    "Orbital Outpost",
    "Volcanic Chambers",
    "Aquatic Temple",
    "Enchanted Forest",
    "Northern Lands",
    "Gilded Skies",
    "Yokai Peak",
    "Abyssal Void"
}

local DIFFICULTIES = {
    "Easy",
    "Medium",
    "Hard",
    "Insane",
    "Nightmare"
}

local DungeonReqs = {
    ["Desert Temple"]     = { Easy = 1,   Medium = 5,   Hard = 15,  Insane = 20,  Nightmare = 25 },
    ["Winter Outpost"]    = { Easy = 33,  Medium = 40,  Hard = 45,  Insane = 50,  Nightmare = 55 },
    ["Pirate Island"]     = { Easy = 60,  Medium = 60,  Hard = 60,  Insane = 60,  Nightmare = 65 },
    ["King's Castle"]     = { Easy = 70,  Medium = 70,  Hard = 70,  Insane = 70,  Nightmare = 75 },
    ["The Underworld"]    = { Easy = 80,  Medium = 80,  Hard = 80,  Insane = 80,  Nightmare = 85 },
    ["Samurai Palace"]    = { Easy = 90,  Medium = 90,  Hard = 90,  Insane = 90,  Nightmare = 95 },
    ["The Canals"]        = { Easy = 100, Medium = 100, Hard = 100, Insane = 100, Nightmare = 105 },
    ["Ghastly Harbor"]    = { Easy = 110, Medium = 110, Hard = 110, Insane = 110, Nightmare = 115 },
    ["Steampunk Sewers"]  = { Easy = 120, Medium = 120, Hard = 120, Insane = 120, Nightmare = 125 },
    ["Orbital Outpost"]   = { Easy = 145, Medium = 145, Hard = 145, Insane = 145, Nightmare = 145 },
    ["Volcanic Chambers"] = { Easy = 150, Medium = 150, Hard = 150, Insane = 150, Nightmare = 155 },
    ["Aquatic Temple"]    = { Easy = 165, Medium = 165, Hard = 165, Insane = 165, Nightmare = 165 },
    ["Enchanted Forest"]  = { Easy = 175, Medium = 175, Hard = 175, Insane = 175, Nightmare = 175 },
    ["Northern Lands"]    = { Easy = 180, Medium = 180, Hard = 180, Insane = 180, Nightmare = 185 },
    ["Gilded Skies"]      = { Easy = 190, Medium = 190, Hard = 190, Insane = 190, Nightmare = 195 },
    ["Yokai Peak"]        = { Easy = 200, Medium = 200, Hard = 200, Insane = 200, Nightmare = 205 },
    ["Abyssal Void"]      = { Easy = 210, Medium = 210, Hard = 210, Insane = 210, Nightmare = 215 },
}

local function getLevelRequirement(dungeon, diff)
    if DungeonReqs[dungeon] and DungeonReqs[dungeon][diff] then
        return DungeonReqs[dungeon][diff]
    end
    return 1
end

-- ========================================================================
--  [3] CONFIGURATION PERSISTENCE
-- ========================================================================
local Config = {
    HostUsername        = "",
    WhitelistedAccounts = {},
    SelectedDungeon     = "Northern Lands",
    SelectedDifficulty  = "Nightmare",
    HardcoreMode        = false,
    AutoLaunchEnabled   = true
}

local function safeReadFile(fileName)
    if typeof(readfile) == "function" then
        local ok, res = pcall(readfile, fileName)
        if ok and res and #res > 0 then return res end
    end
    return nil
end

local function safeWriteFile(fileName, content)
    if typeof(writefile) == "function" then
        return pcall(writefile, fileName, content)
    end
    return false
end

local function saveConfig()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(Config) end)
    if ok and encoded then
        safeWriteFile(CONFIG_FILE, encoded)
    end
end

local function loadConfig()
    local raw = safeReadFile(CONFIG_FILE)
    if raw then
        local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and type(parsed) == "table" then
            for k, v in pairs(parsed) do
                Config[k] = v
            end
        end
    end
    -- Default host to local player if empty
    if not Config.HostUsername or #Config.HostUsername == 0 then
        Config.HostUsername = LocalPlayer.Name
    end
    if Config.AutoLaunchEnabled == nil then
        Config.AutoLaunchEnabled = true
    end
end

loadConfig()

-- Sync dungeon & difficulty indices
local currentDungeonIdx = 1
local function syncDungeonIndex()
    for i, d in ipairs(DUNGEONS) do
        if d:lower() == tostring(Config.SelectedDungeon):lower() then
            currentDungeonIdx = i
            Config.SelectedDungeon = d
            return
        end
    end
    currentDungeonIdx = 1
    Config.SelectedDungeon = DUNGEONS[1]
end

local currentDiffIdx = 1
local function syncDiffIndex()
    for i, d in ipairs(DIFFICULTIES) do
        if d:lower() == tostring(Config.SelectedDifficulty):lower() then
            currentDiffIdx = i
            Config.SelectedDifficulty = d
            return
        end
    end
    currentDiffIdx = 1
    Config.SelectedDifficulty = DIFFICULTIES[1]
end

syncDungeonIndex()
syncDiffIndex()

-- Helpers for Whitelist
local function isAccountWhitelisted(name)
    if not name or #name == 0 then return false end
    local lower = string.lower(name)
    for _, acc in ipairs(Config.WhitelistedAccounts) do
        if string.lower(acc) == lower then return true end
    end
    return false
end

local function addWhitelistAccount(name)
    local trimmed = name and name:match("^%s*(.-)%s*$")
    if not trimmed or #trimmed == 0 then return false end
    if isAccountWhitelisted(trimmed) then return false end
    table.insert(Config.WhitelistedAccounts, trimmed)
    saveConfig()
    return true
end

local function removeWhitelistAccount(name)
    local lower = string.lower(name)
    for idx, acc in ipairs(Config.WhitelistedAccounts) do
        if string.lower(acc) == lower then
            table.remove(Config.WhitelistedAccounts, idx)
            saveConfig()
            return true
        end
    end
    return false
end

-- ========================================================================
--  [4] ENVIRONMENT CHECK
-- ========================================================================
local function isMainLobby()
    if game.PlaceId == 77649408247578 or game.PlaceId == 2414851778 then
        return true
    end
    local dName = Workspace:FindFirstChild("dungeonName")
    if dName and dName:IsA("StringValue") and #dName.Value > 0 then
        return false
    end
    local dObj = Workspace:FindFirstChild("dungeon")
    if dObj then
        return false
    end
    return true
end

local function isCurrentHost()
    return string.lower(Config.HostUsername) == string.lower(LocalPlayer.Name)
end

-- ========================================================================
--  [5] HOST & MEMBER AUTOMATION CORE
-- ========================================================================
local isLobbyActive = false
local joinedMembers = {}
local isStartingMatch = false
local autoHostCooldown = 0

local function destroyJoinPopups()
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if not pG then return end
    for _, c in ipairs(pG:GetChildren()) do
        if c.Name == "joinRequestConfirm" then
            local cBtn = c:FindFirstChild("confirm", true) or c:FindFirstChild("accept", true) or c:FindFirstChild("yes", true)
            if cBtn and (cBtn:IsA("TextButton") or cBtn:IsA("ImageButton")) then
                pcall(function()
                    for _, conn in ipairs(getconnections(cBtn.MouseButton1Click)) do conn:Fire() end
                    for _, conn in ipairs(getconnections(cBtn.Activated)) do conn:Fire() end
                end)
            end
            pcall(function() c:Destroy() end)
        end
    end
end

local function isMemberInPartyGui(accName)
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if not pG then return false end
    local lower = string.lower(accName)
    local qG = pG:FindFirstChild("queueGui")
    if qG then
        for _, d in ipairs(qG:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text and d.Text:lower():find(lower) then
                return true
            end
        end
    end
    local statusFrame = pG:FindFirstChild("playerStatus")
    local tHolder = statusFrame and statusFrame:FindFirstChild("teammateHolder", true)
    if tHolder and tHolder:FindFirstChild(accName) then
        return true
    end
    return false
end

-- Auto-accept join requests on Host
if showJoinRemote and respondJoinRequestRemote then
    showJoinRemote.OnClientEvent:Connect(function(requesterName, ...)
        if isCurrentHost() and isMainLobby() then
            local nameStr = tostring(requesterName)
            if isAccountWhitelisted(nameStr) then
                pcall(function()
                    respondJoinRequestRemote:FireServer(nameStr, true)
                end)
                joinedMembers[string.lower(nameStr)] = true
                print(string.format("[Maki Party] ✅ Instantly approved party join: %s", nameStr))
                destroyJoinPopups()
            end
        end
    end)
end

local function startDungeonMatch()
    if isStartingMatch then return end
    isStartingMatch = true
    print("[Maki Party] 🚀 Starting Dungeon Match with party!")

    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        local qG = pG:FindFirstChild("queueGui")
        local sBtn = (pG and pG:FindFirstChild("startButton", true)) or (qG and qG:FindFirstChild("startButton", true))
        if sBtn and (sBtn:IsA("TextButton") or sBtn:IsA("ImageButton")) then
            pcall(function()
                for _, c in ipairs(getconnections(sBtn.Activated)) do c:Fire() end
                for _, c in ipairs(getconnections(sBtn.MouseButton1Click)) do c:Fire() end
            end)
        end
        for _, btn in ipairs(pG:GetDescendants()) do
            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                local bName = btn.Name:lower()
                local bText = btn:IsA("TextButton") and btn.Text:lower() or ""
                if bName:find("start") or bText:find("start") then
                    pcall(function()
                        for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                    end)
                end
            end
        end
    end

    if changeStartValueRemote then pcall(function() changeStartValueRemote:FireServer() end) end
    task.wait(0.2)
    if startDungeonRemote then pcall(function() startDungeonRemote:FireServer() end) end
    if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
end

local function hostCreatePartyLobby()
    if not isMainLobby() or not isCurrentHost() then return end
    if isLobbyActive then return end
    isLobbyActive = true
    joinedMembers = {}

    local dName = Config.SelectedDungeon
    local dDiff = Config.SelectedDifficulty
    local dReq  = getLevelRequirement(dName, dDiff)

    print(string.format("[Maki Party] 🏰 Auto-Creating Lobby: %s (%s) [Req: %d, Hardcore: %s]...", 
        dName, dDiff, dReq, tostring(Config.HardcoreMode)))

    local ok, res = pcall(function()
        return createLobbyRemote:InvokeServer(dName, dDiff, dReq, Config.HardcoreMode, true, false)
    end)

    if ok and res == true then
        print("[Maki Party] ✅ Lobby Created! Whitelisting party accounts...")
        if addPlayerToWhitelistRemote then
            for _, acc in ipairs(Config.WhitelistedAccounts) do
                pcall(function() addPlayerToWhitelistRemote:FireServer(acc) end)
                task.wait(0.02)
            end
        end
    else
        warn("[Maki Party] ❌ Lobby creation returned: " .. tostring(res))
        isLobbyActive = false
    end
end

-- ========================================================================
--  [6] PERIODIC AUTOMATION ENGINE
-- ========================================================================
task.spawn(function()
    task.wait(1.5) -- Initial startup grace period
    
    while _G.MAKI_PARTY_LAUNCHER_RUNNING do
        task.wait(0.4)

        if isMainLobby() then
            if isCurrentHost() then
                destroyJoinPopups()

                -- Automatically create lobby if enabled and not already hosted
                if Config.AutoLaunchEnabled and not isLobbyActive and not isStartingMatch then
                    if os.clock() > autoHostCooldown then
                        autoHostCooldown = os.clock() + 3.0
                        hostCreatePartyLobby()
                    end
                end

                -- Check if all members have assembled
                if isLobbyActive and not isStartingMatch and Config.AutoLaunchEnabled then
                    local allJoined = true
                    local requiredCount = 0

                    for _, acc in ipairs(Config.WhitelistedAccounts) do
                        if string.lower(acc) ~= string.lower(LocalPlayer.Name) then
                            requiredCount = requiredCount + 1
                            local isPresent = joinedMembers[string.lower(acc)] or isMemberInPartyGui(acc)
                            if not isPresent then
                                allJoined = false
                            end
                        end
                    end

                    -- If party is assembled (or solo host), start dungeon automatically!
                    if allJoined then
                        print("[Maki Party] 🎯 All whitelisted members have assembled! Auto-starting match...")
                        task.wait(0.8)
                        startDungeonMatch()
                    end
                end
            else
                -- Member Mode: continuously send join request to Host
                local host = Config.HostUsername
                if host and #host > 0 and Config.AutoLaunchEnabled then
                    pcall(function()
                        if sendJoinRequestRemote then
                            sendJoinRequestRemote:InvokeServer(host)
                        end
                        if joinDungeonRemote then
                            joinDungeonRemote:InvokeServer(host)
                        end
                    end)
                end

                -- Auto ready up if in party / queueGui
                local pG = LocalPlayer:FindFirstChild("PlayerGui")
                local qG = pG and pG:FindFirstChild("queueGui")
                if qG and readyUpRemote then
                    pcall(function() readyUpRemote:FireServer() end)
                end
            end
        end
    end
end)

-- ========================================================================
--  [7] MODERN GRAPHICAL USER INTERFACE
-- ========================================================================
local parent = getGuiParent()
local existingGui = parent:FindFirstChild("MakiPartyLauncherGui")
if existingGui then existingGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MakiPartyLauncherGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parent

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 340, 0, 520)
MainFrame.Position = UDim2.new(1, -370, 0, 100)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 70, 95)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Draggable handler
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -70, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🎮 MAKI PARTY LAUNCHER"
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
TitleLabel.TextSize = 13
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 24, 0, 24)
MinBtn.Position = UDim2.new(1, -56, 0, 6)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 62)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 215)
MinBtn.TextSize = 13
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -28, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(75, 25, 30)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
CloseBtn.TextSize = 12
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Content Scrollable Container
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, 0, 1, -36)
Content.Position = UDim2.new(0, 0, 0, 36)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(60, 70, 95)
Content.CanvasSize = UDim2.new(0, 0, 0, 560)
Content.Parent = MainFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = Content

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingTop = UDim.new(0, 8)
ContentPadding.PaddingBottom = UDim.new(0, 10)
ContentPadding.PaddingLeft = UDim.new(0, 12)
ContentPadding.PaddingRight = UDim.new(0, 12)
ContentPadding.Parent = Content

-- [1] Host & Role Section
local HostCard = Instance.new("Frame")
HostCard.Size = UDim2.new(1, 0, 0, 64)
HostCard.BackgroundColor3 = Color3.fromRGB(25, 29, 39)
HostCard.BorderSizePixel = 0
HostCard.Parent = Content

local HostCorner = Instance.new("UICorner")
HostCorner.CornerRadius = UDim.new(0, 8)
HostCorner.Parent = HostCard

local HostLabel = Instance.new("TextLabel")
HostLabel.Size = UDim2.new(1, -16, 0, 16)
HostLabel.Position = UDim2.new(0, 10, 0, 6)
HostLabel.BackgroundTransparency = 1
HostLabel.Text = "HOST USERNAME:"
HostLabel.TextColor3 = Color3.fromRGB(150, 160, 180)
HostLabel.TextSize = 11
HostLabel.Font = Enum.Font.GothamBold
HostLabel.TextXAlignment = Enum.TextXAlignment.Left
HostLabel.Parent = HostCard

local HostBox = Instance.new("TextBox")
HostBox.Size = UDim2.new(1, -110, 0, 28)
HostBox.Position = UDim2.new(0, 10, 0, 26)
HostBox.BackgroundColor3 = Color3.fromRGB(32, 37, 50)
HostBox.BorderSizePixel = 0
HostBox.Text = Config.HostUsername
HostBox.TextColor3 = Color3.fromRGB(255, 255, 255)
HostBox.TextSize = 12
HostBox.Font = Enum.Font.Gotham
HostBox.ClearTextOnFocus = false
HostBox.Parent = HostCard

local HostBoxCorner = Instance.new("UICorner")
HostBoxCorner.CornerRadius = UDim.new(0, 6)
HostBoxCorner.Parent = HostBox

local SetHostBtn = Instance.new("TextButton")
SetHostBtn.Size = UDim2.new(0, 88, 0, 28)
SetHostBtn.Position = UDim2.new(1, -98, 0, 26)
SetHostBtn.BackgroundColor3 = Color3.fromRGB(45, 95, 170)
SetHostBtn.BorderSizePixel = 0
SetHostBtn.Text = "👑 Set Me"
SetHostBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SetHostBtn.TextSize = 11
SetHostBtn.Font = Enum.Font.GothamBold
SetHostBtn.Parent = HostCard

local SetHostCorner = Instance.new("UICorner")
SetHostCorner.CornerRadius = UDim.new(0, 6)
SetHostCorner.Parent = SetHostBtn

-- [2] Dungeon & Difficulty Selectors (Dedicated Rows, Zero Overlap)
local SelectCard = Instance.new("Frame")
SelectCard.Size = UDim2.new(1, 0, 0, 154)
SelectCard.BackgroundColor3 = Color3.fromRGB(25, 29, 39)
SelectCard.BorderSizePixel = 0
SelectCard.Parent = Content

local SelectCorner = Instance.new("UICorner")
SelectCorner.CornerRadius = UDim.new(0, 8)
SelectCorner.Parent = SelectCard

-- Row 1: Dungeon
local DungeonLabel = Instance.new("TextLabel")
DungeonLabel.Size = UDim2.new(1, -20, 0, 16)
DungeonLabel.Position = UDim2.new(0, 10, 0, 6)
DungeonLabel.BackgroundTransparency = 1
DungeonLabel.Text = "DUNGEON:"
DungeonLabel.TextColor3 = Color3.fromRGB(150, 160, 180)
DungeonLabel.TextSize = 11
DungeonLabel.Font = Enum.Font.GothamBold
DungeonLabel.TextXAlignment = Enum.TextXAlignment.Left
DungeonLabel.Parent = SelectCard

local DungeonPrevBtn = Instance.new("TextButton")
DungeonPrevBtn.Size = UDim2.new(0, 28, 0, 28)
DungeonPrevBtn.Position = UDim2.new(0, 10, 0, 24)
DungeonPrevBtn.BackgroundColor3 = Color3.fromRGB(35, 42, 56)
DungeonPrevBtn.Text = "◀"
DungeonPrevBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
DungeonPrevBtn.TextSize = 11
DungeonPrevBtn.Font = Enum.Font.GothamBold
DungeonPrevBtn.Parent = SelectCard

local DPrevCorner = Instance.new("UICorner")
DPrevCorner.CornerRadius = UDim.new(0, 6)
DPrevCorner.Parent = DungeonPrevBtn

local DungeonNameLabel = Instance.new("TextLabel")
DungeonNameLabel.Size = UDim2.new(1, -84, 0, 28)
DungeonNameLabel.Position = UDim2.new(0, 42, 0, 24)
DungeonNameLabel.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
DungeonNameLabel.BorderSizePixel = 0
DungeonNameLabel.Text = Config.SelectedDungeon
DungeonNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
DungeonNameLabel.TextSize = 12
DungeonNameLabel.Font = Enum.Font.GothamBold
DungeonNameLabel.Parent = SelectCard

local DNameCorner = Instance.new("UICorner")
DNameCorner.CornerRadius = UDim.new(0, 6)
DNameCorner.Parent = DungeonNameLabel

local DungeonNextBtn = Instance.new("TextButton")
DungeonNextBtn.Size = UDim2.new(0, 28, 0, 28)
DungeonNextBtn.Position = UDim2.new(1, -38, 0, 24)
DungeonNextBtn.BackgroundColor3 = Color3.fromRGB(35, 42, 56)
DungeonNextBtn.Text = "▶"
DungeonNextBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
DungeonNextBtn.TextSize = 11
DungeonNextBtn.Font = Enum.Font.GothamBold
DungeonNextBtn.Parent = SelectCard

local DNextCorner = Instance.new("UICorner")
DNextCorner.CornerRadius = UDim.new(0, 6)
DNextCorner.Parent = DungeonNextBtn

-- Row 2: Difficulty (Full Width, Matching Dungeon Row)
local DiffLabel = Instance.new("TextLabel")
DiffLabel.Size = UDim2.new(1, -20, 0, 16)
DiffLabel.Position = UDim2.new(0, 10, 0, 56)
DiffLabel.BackgroundTransparency = 1
DiffLabel.Text = "DIFFICULTY:"
DiffLabel.TextColor3 = Color3.fromRGB(150, 160, 180)
DiffLabel.TextSize = 11
DiffLabel.Font = Enum.Font.GothamBold
DiffLabel.TextXAlignment = Enum.TextXAlignment.Left
DiffLabel.Parent = SelectCard

local DiffPrevBtn = Instance.new("TextButton")
DiffPrevBtn.Size = UDim2.new(0, 28, 0, 28)
DiffPrevBtn.Position = UDim2.new(0, 10, 0, 74)
DiffPrevBtn.BackgroundColor3 = Color3.fromRGB(35, 42, 56)
DiffPrevBtn.Text = "◀"
DiffPrevBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
DiffPrevBtn.TextSize = 11
DiffPrevBtn.Font = Enum.Font.GothamBold
DiffPrevBtn.Parent = SelectCard

local DiffPrevCorner = Instance.new("UICorner")
DiffPrevCorner.CornerRadius = UDim.new(0, 6)
DiffPrevCorner.Parent = DiffPrevBtn

local DiffNameLabel = Instance.new("TextLabel")
DiffNameLabel.Size = UDim2.new(1, -84, 0, 28)
DiffNameLabel.Position = UDim2.new(0, 42, 0, 74)
DiffNameLabel.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
DiffNameLabel.BorderSizePixel = 0
DiffNameLabel.Text = Config.SelectedDifficulty
DiffNameLabel.TextColor3 = Color3.fromRGB(255, 215, 100)
DiffNameLabel.TextSize = 12
DiffNameLabel.Font = Enum.Font.GothamBold
DiffNameLabel.Parent = SelectCard

local DiffNameCorner = Instance.new("UICorner")
DiffNameCorner.CornerRadius = UDim.new(0, 6)
DiffNameCorner.Parent = DiffNameLabel

local DiffNextBtn = Instance.new("TextButton")
DiffNextBtn.Size = UDim2.new(0, 28, 0, 28)
DiffNextBtn.Position = UDim2.new(1, -38, 0, 74)
DiffNextBtn.BackgroundColor3 = Color3.fromRGB(35, 42, 56)
DiffNextBtn.Text = "▶"
DiffNextBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
DiffNextBtn.TextSize = 11
DiffNextBtn.Font = Enum.Font.GothamBold
DiffNextBtn.Parent = SelectCard

local DiffNextCorner = Instance.new("UICorner")
DiffNextCorner.CornerRadius = UDim.new(0, 6)
DiffNextCorner.Parent = DiffNextBtn

-- Row 3: Dedicated Hardcore Toggle (No Overlap)
local HardcoreBtn = Instance.new("TextButton")
HardcoreBtn.Size = UDim2.new(1, -20, 0, 30)
HardcoreBtn.Position = UDim2.new(0, 10, 0, 112)
HardcoreBtn.BackgroundColor3 = Config.HardcoreMode and Color3.fromRGB(150, 40, 45) or Color3.fromRGB(40, 45, 60)
HardcoreBtn.BorderSizePixel = 0
HardcoreBtn.Text = Config.HardcoreMode and "🔥 Hardcore Mode: ON" or "🛡️ Hardcore Mode: OFF"
HardcoreBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HardcoreBtn.TextSize = 12
HardcoreBtn.Font = Enum.Font.GothamBold
HardcoreBtn.Parent = SelectCard

local HardcoreCorner = Instance.new("UICorner")
HardcoreCorner.CornerRadius = UDim.new(0, 6)
HardcoreCorner.Parent = HardcoreBtn

-- [3] Whitelist Accounts Section
local AccountsCard = Instance.new("Frame")
AccountsCard.Size = UDim2.new(1, 0, 0, 160)
AccountsCard.BackgroundColor3 = Color3.fromRGB(25, 29, 39)
AccountsCard.BorderSizePixel = 0
AccountsCard.Parent = Content

local AccCorner = Instance.new("UICorner")
AccCorner.CornerRadius = UDim.new(0, 8)
AccCorner.Parent = AccountsCard

local AccHeader = Instance.new("TextLabel")
AccHeader.Size = UDim2.new(1, -20, 0, 16)
AccHeader.Position = UDim2.new(0, 10, 0, 6)
AccHeader.BackgroundTransparency = 1
AccHeader.Text = "WHITELISTED PARTY ACCOUNTS:"
AccHeader.TextColor3 = Color3.fromRGB(150, 160, 180)
AccHeader.TextSize = 11
AccHeader.Font = Enum.Font.GothamBold
AccHeader.TextXAlignment = Enum.TextXAlignment.Left
AccHeader.Parent = AccountsCard

local AccInputBox = Instance.new("TextBox")
AccInputBox.Size = UDim2.new(1, -78, 0, 28)
AccInputBox.Position = UDim2.new(0, 10, 0, 26)
AccInputBox.BackgroundColor3 = Color3.fromRGB(32, 37, 50)
AccInputBox.BorderSizePixel = 0
AccInputBox.PlaceholderText = "Account username..."
AccInputBox.PlaceholderColor3 = Color3.fromRGB(120, 130, 150)
AccInputBox.Text = ""
AccInputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
AccInputBox.TextSize = 12
AccInputBox.Font = Enum.Font.Gotham
AccInputBox.ClearTextOnFocus = false
AccInputBox.Parent = AccountsCard

local AccBoxCorner = Instance.new("UICorner")
AccBoxCorner.CornerRadius = UDim.new(0, 6)
AccBoxCorner.Parent = AccInputBox

local AddAccBtn = Instance.new("TextButton")
AddAccBtn.Size = UDim2.new(0, 56, 0, 28)
AddAccBtn.Position = UDim2.new(1, -66, 0, 26)
AddAccBtn.BackgroundColor3 = Color3.fromRGB(35, 120, 75)
AddAccBtn.BorderSizePixel = 0
AddAccBtn.Text = "+ Add"
AddAccBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AddAccBtn.TextSize = 11
AddAccBtn.Font = Enum.Font.GothamBold
AddAccBtn.Parent = AccountsCard

local AddAccCorner = Instance.new("UICorner")
AddAccCorner.CornerRadius = UDim.new(0, 6)
AddAccCorner.Parent = AddAccBtn

local AccScroll = Instance.new("ScrollingFrame")
AccScroll.Size = UDim2.new(1, -20, 0, 92)
AccScroll.Position = UDim2.new(0, 10, 0, 60)
AccScroll.BackgroundColor3 = Color3.fromRGB(20, 23, 31)
AccScroll.BorderSizePixel = 0
AccScroll.ScrollBarThickness = 3
AccScroll.ScrollBarImageColor3 = Color3.fromRGB(55, 65, 85)
AccScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
AccScroll.Parent = AccountsCard

local AccScrollCorner = Instance.new("UICorner")
AccScrollCorner.CornerRadius = UDim.new(0, 6)
AccScrollCorner.Parent = AccScroll

local AccListLayout = Instance.new("UIListLayout")
AccListLayout.Padding = UDim.new(0, 4)
AccListLayout.SortOrder = Enum.SortOrder.LayoutOrder
AccListLayout.Parent = AccScroll

local AccListPadding = Instance.new("UIPadding")
AccListPadding.PaddingTop = UDim.new(0, 4)
AccListPadding.PaddingBottom = UDim.new(0, 4)
AccListPadding.PaddingLeft = UDim.new(0, 4)
AccListPadding.PaddingRight = UDim.new(0, 4)
AccListPadding.Parent = AccScroll

-- [4] Action & Launch Controls
local ActionCard = Instance.new("Frame")
ActionCard.Size = UDim2.new(1, 0, 0, 90)
ActionCard.BackgroundColor3 = Color3.fromRGB(25, 29, 39)
ActionCard.BorderSizePixel = 0
ActionCard.Parent = Content

local ActionCorner = Instance.new("UICorner")
ActionCorner.CornerRadius = UDim.new(0, 8)
ActionCorner.Parent = ActionCard

local LaunchBtn = Instance.new("TextButton")
LaunchBtn.Size = UDim2.new(1, -20, 0, 36)
LaunchBtn.Position = UDim2.new(0, 10, 0, 8)
LaunchBtn.BackgroundColor3 = Config.AutoLaunchEnabled and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(70, 75, 90)
LaunchBtn.BorderSizePixel = 0
LaunchBtn.Text = Config.AutoLaunchEnabled and "⚡ AUTO-LAUNCH: ACTIVE" or "⏸️ AUTO-LAUNCH: PAUSED"
LaunchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
LaunchBtn.TextSize = 12
LaunchBtn.Font = Enum.Font.GothamBold
LaunchBtn.Parent = ActionCard

local LaunchCorner = Instance.new("UICorner")
LaunchCorner.CornerRadius = UDim.new(0, 8)
LaunchCorner.Parent = LaunchBtn

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 34)
StatusLabel.Position = UDim2.new(0, 10, 0, 48)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Initializing..."
StatusLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextWrapped = true
StatusLabel.Parent = ActionCard

-- ========================================================================
--  [8] UI CONTROLLER & EVENT CONNECTIONS
-- ========================================================================
local function refreshWhitelistUI()
    for _, child in ipairs(AccScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local totalHeight = 0
    local rowHeight = 24

    for idx, name in ipairs(Config.WhitelistedAccounts) do
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, rowHeight)
        Row.BackgroundColor3 = Color3.fromRGB(28, 33, 44)
        Row.BorderSizePixel = 0
        Row.Parent = AccScroll

        local RowCorner = Instance.new("UICorner")
        RowCorner.CornerRadius = UDim.new(0, 5)
        RowCorner.Parent = Row

        local isJoined = joinedMembers[string.lower(name)] or isMemberInPartyGui(name)
        local statusIcon = isJoined and "✅" or "🔄"

        local NameLbl = Instance.new("TextLabel")
        NameLbl.Size = UDim2.new(1, -30, 1, 0)
        NameLbl.Position = UDim2.new(0, 8, 0, 0)
        NameLbl.BackgroundTransparency = 1
        NameLbl.Text = string.format("%d. %s %s", idx, name, statusIcon)
        NameLbl.TextColor3 = isJoined and Color3.fromRGB(150, 255, 170) or Color3.fromRGB(225, 230, 240)
        NameLbl.TextSize = 11
        NameLbl.Font = Enum.Font.GothamMedium
        NameLbl.TextXAlignment = Enum.TextXAlignment.Left
        NameLbl.Parent = Row

        local DelBtn = Instance.new("TextButton")
        DelBtn.Size = UDim2.new(0, 20, 0, 20)
        DelBtn.Position = UDim2.new(1, -22, 0.5, -10)
        DelBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 35)
        DelBtn.BorderSizePixel = 0
        DelBtn.Text = "✕"
        DelBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
        DelBtn.TextSize = 10
        DelBtn.Font = Enum.Font.GothamBold
        DelBtn.Parent = Row

        local DelCorner = Instance.new("UICorner")
        DelCorner.CornerRadius = UDim.new(0, 4)
        DelCorner.Parent = DelBtn

        DelBtn.MouseButton1Click:Connect(function()
            removeWhitelistAccount(name)
            refreshWhitelistUI()
        end)

        totalHeight = totalHeight + rowHeight + 4
    end

    AccScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 8)
    AccHeader.Text = string.format("WHITELISTED PARTY ACCOUNTS (%d):", #Config.WhitelistedAccounts)
end

refreshWhitelistUI()

-- Set Me As Host
SetHostBtn.MouseButton1Click:Connect(function()
    Config.HostUsername = LocalPlayer.Name
    HostBox.Text = LocalPlayer.Name
    saveConfig()
    isLobbyActive = false
    print("[Maki Party] 👑 Host set to LocalPlayer: " .. LocalPlayer.Name)
end)

HostBox.FocusLost:Connect(function()
    local text = HostBox.Text:match("^%s*(.-)%s*$")
    if text and #text > 0 then
        Config.HostUsername = text
        saveConfig()
        isLobbyActive = false
    end
end)

-- Add Account Handler
local function handleAddAcc()
    local text = AccInputBox.Text
    if addWhitelistAccount(text) then
        AccInputBox.Text = ""
        refreshWhitelistUI()
    end
end

AddAccBtn.MouseButton1Click:Connect(handleAddAcc)
AccInputBox.FocusLost:Connect(function(enter)
    if enter then handleAddAcc() end
end)

-- Dungeon Cycle Handlers (With Instant Persistence)
DungeonPrevBtn.MouseButton1Click:Connect(function()
    currentDungeonIdx = currentDungeonIdx - 1
    if currentDungeonIdx < 1 then currentDungeonIdx = #DUNGEONS end
    Config.SelectedDungeon = DUNGEONS[currentDungeonIdx]
    DungeonNameLabel.Text = Config.SelectedDungeon
    saveConfig()
    isLobbyActive = false
    print("[Maki Party] 💾 Saved Dungeon: " .. Config.SelectedDungeon)
end)

DungeonNextBtn.MouseButton1Click:Connect(function()
    currentDungeonIdx = currentDungeonIdx + 1
    if currentDungeonIdx > #DUNGEONS then currentDungeonIdx = 1 end
    Config.SelectedDungeon = DUNGEONS[currentDungeonIdx]
    DungeonNameLabel.Text = Config.SelectedDungeon
    saveConfig()
    isLobbyActive = false
    print("[Maki Party] 💾 Saved Dungeon: " .. Config.SelectedDungeon)
end)

-- Difficulty Cycle Handlers (With Instant Persistence)
DiffPrevBtn.MouseButton1Click:Connect(function()
    currentDiffIdx = currentDiffIdx - 1
    if currentDiffIdx < 1 then currentDiffIdx = #DIFFICULTIES end
    Config.SelectedDifficulty = DIFFICULTIES[currentDiffIdx]
    DiffNameLabel.Text = Config.SelectedDifficulty
    saveConfig()
    isLobbyActive = false
    print("[Maki Party] 💾 Saved Difficulty: " .. Config.SelectedDifficulty)
end)

DiffNextBtn.MouseButton1Click:Connect(function()
    currentDiffIdx = currentDiffIdx + 1
    if currentDiffIdx > #DIFFICULTIES then currentDiffIdx = 1 end
    Config.SelectedDifficulty = DIFFICULTIES[currentDiffIdx]
    DiffNameLabel.Text = Config.SelectedDifficulty
    saveConfig()
    isLobbyActive = false
    print("[Maki Party] 💾 Saved Difficulty: " .. Config.SelectedDifficulty)
end)

-- Hardcore Toggle Handler
HardcoreBtn.MouseButton1Click:Connect(function()
    Config.HardcoreMode = not Config.HardcoreMode
    HardcoreBtn.BackgroundColor3 = Config.HardcoreMode and Color3.fromRGB(150, 40, 45) or Color3.fromRGB(40, 45, 60)
    HardcoreBtn.Text = Config.HardcoreMode and "🔥 Hardcore Mode: ON" or "🛡️ Hardcore Mode: OFF"
    saveConfig()
    isLobbyActive = false
    print("[Maki Party] 💾 Saved Hardcore: " .. tostring(Config.HardcoreMode))
end)

-- Auto-Launch Toggle Button
LaunchBtn.MouseButton1Click:Connect(function()
    Config.AutoLaunchEnabled = not Config.AutoLaunchEnabled
    LaunchBtn.BackgroundColor3 = Config.AutoLaunchEnabled and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(70, 75, 90)
    LaunchBtn.Text = Config.AutoLaunchEnabled and "⚡ AUTO-LAUNCH: ACTIVE" or "⏸️ AUTO-LAUNCH: PAUSED"
    saveConfig()
end)

-- Minimize & Hide Controls
local isMin = false
MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    if isMin then
        MainFrame.Size = UDim2.new(0, 340, 0, 36)
        Content.Visible = false
        MinBtn.Text = "+"
    else
        MainFrame.Size = UDim2.new(0, 340, 0, 520)
        Content.Visible = true
        MinBtn.Text = "—"
    end
end)

local FloatingBadge = Instance.new("TextButton")
FloatingBadge.Size = UDim2.new(0, 36, 0, 36)
FloatingBadge.Position = UDim2.new(1, -50, 0, 75)
FloatingBadge.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
FloatingBadge.Text = "🎮"
FloatingBadge.TextSize = 18
FloatingBadge.Visible = false
FloatingBadge.Parent = ScreenGui

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(1, 0)
BadgeCorner.Parent = FloatingBadge

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatingBadge.Visible = true
end)

FloatingBadge.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    FloatingBadge.Visible = false
end)

-- Initial Auto-Hide if loaded inside a dungeon
if not isMainLobby() then
    MainFrame.Visible = false
    FloatingBadge.Visible = false
end

local wasInDungeon = not isMainLobby()

-- Live Status Monitor Loop
task.spawn(function()
    while _G.MAKI_PARTY_LAUNCHER_RUNNING and ScreenGui and ScreenGui.Parent do
        if not isMainLobby() then
            if not wasInDungeon then
                wasInDungeon = true
                MainFrame.Visible = false
                FloatingBadge.Visible = false
                print("[Maki Party] 🟢 Inside dungeon: UI automatically hidden.")
            end
            StatusLabel.Text = "Status: 🟢 Inside Dungeon (Party Complete)"
            StatusLabel.TextColor3 = Color3.fromRGB(140, 240, 160)
        else
            if wasInDungeon then
                wasInDungeon = false
                MainFrame.Visible = true
                FloatingBadge.Visible = false
                print("[Maki Party] 🏰 Returned to lobby: UI automatically restored.")
            end

            refreshWhitelistUI()

            if not Config.AutoLaunchEnabled then
                StatusLabel.Text = "Status: ⏸️ Automation Paused (Click button to resume)"
                StatusLabel.TextColor3 = Color3.fromRGB(240, 200, 100)
            elseif isCurrentHost() then
                if isStartingMatch then
                    StatusLabel.Text = "Status: 🚀 Teleporting Party to Dungeon..."
                    StatusLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
                elseif isLobbyActive then
                    local count = 0
                    for _, acc in ipairs(Config.WhitelistedAccounts) do
                        if string.lower(acc) ~= string.lower(LocalPlayer.Name) then
                            if joinedMembers[string.lower(acc)] or isMemberInPartyGui(acc) then
                                count = count + 1
                            end
                        end
                    end
                    local totalNeeded = math.max(0, #Config.WhitelistedAccounts - 1)
                    StatusLabel.Text = string.format("Status: 🏰 Lobby Active (%d/%d Accounts Assembled)", count, totalNeeded)
                    StatusLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
                else
                    StatusLabel.Text = "Status: 👑 Host (Auto-creating party lobby...)"
                    StatusLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
                end
            else
                local inParty = isMemberInPartyGui(LocalPlayer.Name) or (LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("queueGui"))
                if inParty then
                    StatusLabel.Text = string.format("Status: ✅ In Party & Readied Up! (Waiting for %s to start)", Config.HostUsername)
                    StatusLabel.TextColor3 = Color3.fromRGB(150, 255, 170)
                else
                    StatusLabel.Text = string.format("Status: 👥 Member (Auto-joining Host: %s...)", Config.HostUsername)
                    StatusLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
                end
            end
        end
        task.wait(1.0)
    end
end)

print(string.format("[MAKI LAUNCHER v2.0] Autonomous Party Launcher online. Role: %s (Host: %s, Dungeon: %s - %s)", 
    isCurrentHost() and "HOST" or "MEMBER", Config.HostUsername, Config.SelectedDungeon, Config.SelectedDifficulty))
