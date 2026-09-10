-- ========================================================================
--  PROJECT MAKI: ENCHANTED FOREST (NIGHTMARE) MASTER AUTO-FARM ENGINE v1.3
--  - Version Milestone: v1.3 (Safe Auto-Sell + Auto-Replay + Potato Mode + Persistence)
--  - 100% Mobile & PC Compatible (Touch Draggable Middle-Right HUD)
--  - Persistent Settings: saves/loads potatoMode & autoReplay to ef_settings.json
--  - Seamless Sprint Combat Architecture:
--      * Normal Packs:
--          - Zone 1 (110-115s): Pre-buff Q on the run (+80% speed & damage)
--          - Zone 2 (85s): Safe Standoff Guard ONLY if E is on cooldown.
--            (If Q buff is active or E is ready, NEVER stops—sprints right through!)
--          - Zone 3 (<= 82s): Backline AoE Wipe (Halt, Aim Pack Center, Detonate E)
--      * Sub-Bosses & Bosses (Golem, Ancient Tree, The Dragon):
--          - Pre-Buff Charge (130s): Pop Q on the run
--          - Immediate E Strike (<= 82s): Halt, Face Boss, Fire E immediately
--          - Kamikaze Loop: Hold ground until respawn, walk back and repeat
--      * Empty Highway (> 150s): Pop Q on cooldown for top travel speed
--  - Dynamic Respawn Checkpoint Recovery (snaps to closest highway waypoint)
--  - Room 5 Ancient Tree Stone Platform Shortcut
--  - 100% Legit Native Physics: 0 speed tampering, 0 rubberbands
-- ========================================================================

if _G.EF_RESTORE_POTATO then
    pcall(_G.EF_RESTORE_POTATO)
    _G.EF_RESTORE_POTATO = nil
end
if _G.EF_AUTOFARM_RUNNING then
    _G.EF_AUTOFARM_RUNNING = false
    task.wait(0.25)
end
_G.EF_AUTOFARM_RUNNING = true

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ========================================================================
-- PERSISTENT SETTINGS ENGINE (ef_settings.json)
-- ========================================================================
local SETTINGS_FILE = "ef_settings.json"

local function loadSettings()
    local defaults = {
        potatoMode = true, -- Default is ON for 60 FPS
        autoReplay = true, -- Default is ON for infinite overnight farming!
        autoSell = true    -- Default is ON for foolproof safe inventory management!
    }
    pcall(function()
        if typeof(isfile) == "function" and isfile(SETTINGS_FILE) then
            local data = readfile(SETTINGS_FILE)
            local decoded = HttpService:JSONDecode(data)
            if type(decoded) == "table" then
                if decoded.potatoMode ~= nil then
                    defaults.potatoMode = decoded.potatoMode
                end
                if decoded.autoReplay ~= nil then
                    defaults.autoReplay = decoded.autoReplay
                end
                if decoded.autoSell ~= nil then
                    defaults.autoSell = decoded.autoSell
                end
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
local isRunning = true
local potatoMode = currentSettings.potatoMode
local autoReplay = currentSettings.autoReplay
local autoSell = currentSettings.autoSell
local isReplaying = false
local potatoDescendantConn = nil
local savedLighting = {}
local savedEffects = {}
local savedParticles = {}
local savedDecals = {}
local savedMaterials = {}
local startTime = tick()
local currentWpIndex = 1
local runsCompleted = 0
local bossHitsLanded = 0
local isCastingCombo = false
local lastQCastTime = 0
local treeKilledThisRun = false
local treeSpawnDetected = false
local treeHitsLanded = 0
local shortcutActive = false
local shortcutIdx = 1

-- Room 5 Bump Bypass Channel: skirts around the left side of the platform bump to Room 6 door
local SHORTCUT_POINTS = {
    Vector3.new(-671.1, -24.4, 290.1),
    Vector3.new(-730.0, -26.0, 290.0),
    Vector3.new(-780.0, -27.5, 310.0),
    Vector3.new(-815.0, -27.5, 360.0),
    Vector3.new(-815.0, -27.5, 410.0),
    Vector3.new(-800.0, -27.0, 460.0),
    Vector3.new(-825.0, -25.0, 490.0),
    Vector3.new(-837.5, -24.5, 505.1)
}

local function isQBuffActive()
    return (tick() - lastQCastTime) < 4.5
end

local function smoothMoveTo(hum, targetPos)
    hum.AutoRotate = true
    hum:MoveTo(targetPos)
end

-- ========================================================================
-- 1. LOAD HIGHWAY WAYPOINTS (1,015 Points from Spawn to Dragon)
--    Tier 1: Local readfile (PC - fastest)
--    Tier 2: GitHub HttpGet (Mobile / Cloud - automatic fallback)
-- ========================================================================
local GITHUB_PATH_URL = "https://raw.githubusercontent.com/MayyAlterrr/maki-suite/main/paths/dqr_highway_enchanted_forest.json"
local waypoints = {}

local function parseWaypoints(raw)
    local parsed = HttpService:JSONDecode(raw)
    if parsed and parsed.points then
        for _, pt in ipairs(parsed.points) do
            table.insert(waypoints, Vector3.new(pt.x, pt.y, pt.z))
        end
    end
end

-- Tier 1: Try local file (PC only)
if #waypoints == 0 then
    pcall(function()
        if typeof(isfile) == "function" and isfile("dqr_highway_enchanted_forest.json") then
            local raw = readfile("dqr_highway_enchanted_forest.json")
            parseWaypoints(raw)
            if #waypoints > 0 then
                print(string.format("[EF Master] Tier 1 (Local): Loaded %d waypoints", #waypoints))
            end
        end
    end)
end

-- Tier 2: Fallback to GitHub (Mobile / Cloud / any device)
if #waypoints == 0 then
    pcall(function()
        print("[EF Master] Tier 2 (GitHub): Fetching highway waypoints...")
        local raw = game:HttpGet(GITHUB_PATH_URL)
        parseWaypoints(raw)
        if #waypoints > 0 then
            print(string.format("[EF Master] Tier 2 (GitHub): Loaded %d waypoints", #waypoints))
            -- Cache locally for next time if possible
            pcall(function()
                if typeof(writefile) == "function" then
                    writefile("dqr_highway_enchanted_forest.json", raw)
                    print("[EF Master] Path cached locally for next run.")
                end
            end)
        end
    end)
end

local totalWps = #waypoints
print(string.format("[EF Master] Highway ready: %d waypoints total", totalWps))

local function findClosestWaypointIndex(pos, startIdx, endIdx)
    local s = math.max(1, startIdx or 1)
    local e = math.min(totalWps, endIdx or totalWps)
    local bestIdx = s
    local minD = 999999
    for i = s, e do
        local wp = waypoints[i]
        if wp then
            local d = (wp - pos).Magnitude
            if d < minD then
                minD = d
                bestIdx = i
            end
        end
    end
    return bestIdx, minD
end

-- ========================================================================
-- 2. SAFE COLLISION ENGINE
-- ========================================================================
local function stripWalls()
    local borders = Workspace:FindFirstChild("borders")
    if borders then
        for _, b in ipairs(borders:GetDescendants()) do
            if b:IsA("BasePart") then
                b.CanCollide = false
                b.Transparency = 1
            end
        end
    end

    local dung = Workspace:FindFirstChild("dungeon")
    if dung then
        for _, d in ipairs(dung:GetDescendants()) do
            if d:IsA("BasePart") then
                local n = d.Name:lower()
                if n:find("barrier") or n:find("border") then
                    d.CanCollide = false
                end
            end
        end
    end

    local map = Workspace:FindFirstChild("map")
    if map then
        for _, d in ipairs(map:GetDescendants()) do
            if d:IsA("BasePart") then
                local n = d.Name:lower()
                local pName = d.Parent and d.Parent.Name:lower() or ""
                -- Strip collision on invisible barriers, decorative trees, leaves, and foliage
                if n:find("barrier") or n:find("border") or n:find("tree") or n:find("leave") or pName:find("tree") or pName:find("leave") then
                    d.CanCollide = false
                -- Keep walkable platforms, floors, and bridges solid
                elseif not d.CanCollide and (n:find("platform") or n:find("floor") or n:find("plunge") or n:find("bridge")) then
                    d.CanCollide = true
                end
            end
        end
    end
end

stripWalls()
task.spawn(function()
    while _G.EF_AUTOFARM_RUNNING do
        task.wait(4.0)
        pcall(stripWalls)
    end
end)

-- ========================================================================
-- 3. ABILITY ENGINE: Q (INNER FOCUS) & E (GEYSER)
-- ========================================================================
local function getToolBySlot(slotName)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            local s = t:FindFirstChild("abilitySlot")
            if s and s.Value:lower() == slotName:lower() then return t end
        end
    end
    if char then
        for _, t in ipairs(char:GetChildren()) do
            local s = t:FindFirstChild("abilitySlot")
            if s and s.Value:lower() == slotName:lower() then return t end
        end
    end
    return nil
end

local function isQReady()
    local t = getToolBySlot("q")
    if not t then return false end
    local cd = t:FindFirstChild("cooldown")
    return cd and cd.Value <= 0.05
end

local function isEReady()
    local t = getToolBySlot("e")
    if not t then return false end
    local cd = t:FindFirstChild("cooldown")
    local char = LocalPlayer.Character
    local busy = char and char:FindFirstChild("busyCasting")
    return cd and cd.Value <= 0.05 and (busy == nil or busy.Value == false)
end

local function getQCDRemaining()
    local t = getToolBySlot("q")
    local cd = t and t:FindFirstChild("cooldown")
    return cd and math.max(0, cd.Value) or 0
end

local function getECDRemaining()
    local t = getToolBySlot("e")
    local cd = t and t:FindFirstChild("cooldown")
    return cd and math.max(0, cd.Value) or 0
end

local function castQ()
    local t = getToolBySlot("q")
    if t and isQReady() then
        local le = t:FindFirstChild("localEvent")
        if le then
            le:Fire()
        else
            local ae = t:FindFirstChild("abilityEvent")
            if ae then ae:FireServer() end
        end
        lastQCastTime = tick()
        return true
    end
    return false
end

local function castE()
    local t = getToolBySlot("e")
    if t and isEReady() then
        local le = t:FindFirstChild("localEvent")
        if le then
            le:Fire()
        else
            local ae = t:FindFirstChild("abilityEvent")
            if ae then ae:FireServer() end
        end
        return true
    end
    return false
end

-- ========================================================================
-- 3B. SAFE AUTO-SELL ENGINE (7-LAYER FOOLPROOF PROTECTION)
-- ========================================================================
local COLLECT_PREFIXES = {
    "triton", "godly", "titan-forged", "titan forged", "glorious",
    "ancestral", "overlord", "mythical", "war-forged", "war forged",
    "alien", "eldenbark", "valhalla"
}

local PROTECTED_SPELLS = {
    "enchanted inner focus", "enchanted inner rage",
    "enhanced inner focus", "enhanced inner rage"
}

local function isTargetKeptEpic(nameLower)
    if nameLower:find("crystalline mage") or nameLower:find("crystalline warrior") then
        return true
    end
    if nameLower:find("overgrown war scythe") or nameLower:find("crystalline shard staff") then
        return true
    end
    return false
end

local function isEnchantedForestItem(nameLower)
    if nameLower:find("enchanted shard") or
       nameLower:find("forest vine") or
       nameLower:find("crystalline") or
       nameLower:find("overgrown") or
       nameLower:find("wind blast") or
       nameLower:find("lightning burst") or
       nameLower:find("agony orbs") or
       nameLower:find("gale barrage") then
        return true
    end
    return false
end

local function shouldSellItem(cat, key, item)
    local nameLower = string.lower(item.name or "")
    local rarityLower = string.lower(item.rarity or "")
    local upg = item.currentUpgrade or 0
    local isEq = (type(item.equipped) == "table" and (item.equipped.q or item.equipped.e)) or (item.equipped == true)

    -- Layer 1: Equipped Lock (100% immune)
    if isEq then return false, "EQUIPPED" end

    -- Layer 2: Upgrade Lock (>0 upgrades 100% immune)
    if upg > 0 then return false, "UPGRADED" end

    -- Layer 3: God-Tier Rarity Ceiling (Legendary, Ultimate, Dev 100% immune)
    if rarityLower == "legendary" or rarityLower == "ultimate" or rarityLower == "dev" then
        return false, "GOD_TIER_RARITY"
    end

    -- Layer 4: 11 Collects Prefix Blacklist (Any rarity with collect prefix 100% immune)
    for _, pfx in ipairs(COLLECT_PREFIXES) do
        if nameLower:find(pfx) then return false, "COLLECT" end
    end

    -- Layer 5: Valuable Spells Blacklist (Enchanted/Enhanced Inner Focus & Rage 100% immune)
    for _, sp in ipairs(PROTECTED_SPELLS) do
        if nameLower:find(sp) then return false, "VALUABLE_SPELL" end
    end

    -- Layer 6: Dungeon Origin Filter (Only items originating from Enchanted Forest can be sold)
    if not isEnchantedForestItem(nameLower) then
        return false, "OTHER_DUNGEON_ITEM"
    end

    -- Layer 7: User-Hunted Target Epics (Purple Crystalline Mage/Warrior & Purple Weapons kept)
    if rarityLower == "epic" and isTargetKeptEpic(nameLower) then
        return false, "HUNTED_TARGET_EPIC"
    end

    -- Passed all 7 safety layers -> safe to sell EF junk!
    return true, "SELLABLE_EF_JUNK"
end

local function runSafeAutoSell()
    local remotes = ReplicatedStorage:FindFirstChild("remotes")
    if not remotes then
        warn("[EF Master v1.3] remotes folder not found!")
        return 0, 0
    end
    local reloadRemote = remotes:FindFirstChild("reloadInvy")
    local sellRemote = remotes:FindFirstChild("sellItemEvent")
    if not reloadRemote or not sellRemote then
        warn("[EF Master v1.3] Inventory remotes missing!")
        return 0, 0
    end

    local success, invy = pcall(function()
        return reloadRemote:InvokeServer()
    end)
    if not success or type(invy) ~= "table" then
        warn("[EF Master v1.3] Failed to reload inventory!")
        return 0, 0
    end

    local payload = {weapon = {}, ability = {}, chest = {}, helmet = {}}
    local soldCount = 0
    local keptCount = 0

    local function checkCategory(tbl, catKey)
        for k, v in pairs(tbl or {}) do
            local canSell, reason = shouldSellItem(catKey, k, v)
            local idNum = tonumber(string.match(k, "%d+"))
            if canSell and idNum then
                soldCount = soldCount + 1
                table.insert(payload[catKey], idNum)
            else
                keptCount = keptCount + 1
            end
        end
    end

    checkCategory(invy.weapons, "weapon")
    checkCategory(invy.abilities, "ability")
    checkCategory(invy.chests, "chest")
    checkCategory(invy.helmets, "helmet")

    if soldCount > 0 then
        sellRemote:FireServer(payload)
        print(string.format("[EF Master v1.3] Auto-Sell: Sold %d EF junk items (Protected %d items safely)", soldCount, keptCount))
    else
        print(string.format("[EF Master v1.3] Auto-Sell: 0 junk to sell (Protected %d items safely)", keptCount))
    end

    return soldCount, keptCount
end
_G.EF_SELL_NOW = runSafeAutoSell

-- ========================================================================
-- 4. MIDDLE-RIGHT TOUCH & PC DRAGGABLE HUD
-- ========================================================================
local guiParent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if typeof(gethui) == "function" then
        guiParent = gethui()
    elseif CoreGui then
        guiParent = CoreGui
    end
end)

local oldGui = guiParent:FindFirstChild("EF_Master_HUD")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EF_Master_HUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = guiParent

local hudFrame = Instance.new("Frame", screenGui)
hudFrame.Name = "MainFrame"
hudFrame.Size = UDim2.new(0, 225, 0, 256)
hudFrame.Position = UDim2.new(1, -240, 0.5, -128)
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
titleLabel.Text = "ENCHANTED FOREST [NM] v1.3"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Center

local phaseLabel = Instance.new("TextLabel", hudFrame)
phaseLabel.Name = "PhaseLabel"
phaseLabel.Size = UDim2.new(1, -16, 0, 16)
phaseLabel.Position = UDim2.new(0, 8, 0, 28)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Text = "Phase: Initializing..."
phaseLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
phaseLabel.Font = Enum.Font.SourceSansBold
phaseLabel.TextSize = 12
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left

local statusLabel = Instance.new("TextLabel", hudFrame)
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -16, 0, 16)
statusLabel.Position = UDim2.new(0, 8, 0, 46)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Starting run..."
statusLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left

local cdLabel = Instance.new("TextLabel", hudFrame)
cdLabel.Name = "CdLabel"
cdLabel.Size = UDim2.new(1, -16, 0, 16)
cdLabel.Position = UDim2.new(0, 8, 0, 64)
cdLabel.BackgroundTransparency = 1
cdLabel.Text = "Q: Ready | E: Ready"
cdLabel.TextColor3 = Color3.fromRGB(100, 255, 140)
cdLabel.Font = Enum.Font.SourceSansBold
cdLabel.TextSize = 12
cdLabel.TextXAlignment = Enum.TextXAlignment.Left

local statsLabel = Instance.new("TextLabel", hudFrame)
statsLabel.Name = "StatsLabel"
statsLabel.Size = UDim2.new(1, -16, 0, 16)
statsLabel.Position = UDim2.new(0, 8, 0, 84)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "Runs: 0 | Time: 00:00"
statsLabel.TextColor3 = Color3.fromRGB(160, 175, 200)
statsLabel.Font = Enum.Font.SourceSans
statsLabel.TextSize = 11
statsLabel.TextXAlignment = Enum.TextXAlignment.Left

local toggleBtn = Instance.new("TextButton", hudFrame)
toggleBtn.Name = "ToggleBtn"
toggleBtn.Size = UDim2.new(1, -16, 0, 26)
toggleBtn.Position = UDim2.new(0, 8, 0, 104)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 140, 70)
toggleBtn.Text = "[ AUTO-FARM: RUNNING ]"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 12
toggleBtn.Active = true
toggleBtn.AutoButtonColor = true
toggleBtn.ZIndex = 10
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

local potatoBtn = Instance.new("TextButton", hudFrame)
potatoBtn.Name = "PotatoBtn"
potatoBtn.Size = UDim2.new(1, -16, 0, 26)
potatoBtn.Position = UDim2.new(0, 8, 0, 134)
potatoBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
potatoBtn.Text = "[ ⚡ POTATO MODE: OFF ]"
potatoBtn.TextColor3 = Color3.fromRGB(190, 210, 235)
potatoBtn.Font = Enum.Font.SourceSansBold
potatoBtn.TextSize = 12
potatoBtn.Active = true
potatoBtn.AutoButtonColor = true
potatoBtn.ZIndex = 10
Instance.new("UICorner", potatoBtn).CornerRadius = UDim.new(0, 6)

local replayBtn = Instance.new("TextButton", hudFrame)
replayBtn.Name = "ReplayBtn"
replayBtn.Size = UDim2.new(1, -16, 0, 26)
replayBtn.Position = UDim2.new(0, 8, 0, 164)
replayBtn.BackgroundColor3 = Color3.fromRGB(20, 130, 160)
replayBtn.Text = "[ 🔄 AUTO-REPLAY: ON ]"
replayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
replayBtn.Font = Enum.Font.SourceSansBold
replayBtn.TextSize = 12
replayBtn.Active = true
replayBtn.AutoButtonColor = true
replayBtn.ZIndex = 10
Instance.new("UICorner", replayBtn).CornerRadius = UDim.new(0, 6)

local autoSellBtn = Instance.new("TextButton", hudFrame)
autoSellBtn.Name = "AutoSellBtn"
autoSellBtn.Size = UDim2.new(1, -16, 0, 26)
autoSellBtn.Position = UDim2.new(0, 8, 0, 194)
autoSellBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 20)
autoSellBtn.Text = "[ 🗑️ AUTO-SELL: ON ]"
autoSellBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoSellBtn.Font = Enum.Font.SourceSansBold
autoSellBtn.TextSize = 12
autoSellBtn.Active = true
autoSellBtn.AutoButtonColor = true
autoSellBtn.ZIndex = 10
Instance.new("UICorner", autoSellBtn).CornerRadius = UDim.new(0, 6)

local sellNowBtn = Instance.new("TextButton", hudFrame)
sellNowBtn.Name = "SellNowBtn"
sellNowBtn.Size = UDim2.new(1, -16, 0, 24)
sellNowBtn.Position = UDim2.new(0, 8, 0, 224)
sellNowBtn.BackgroundColor3 = Color3.fromRGB(50, 60, 80)
sellNowBtn.Text = "[ 🧹 SELL JUNK NOW ]"
sellNowBtn.TextColor3 = Color3.fromRGB(240, 220, 120)
sellNowBtn.Font = Enum.Font.SourceSansBold
sellNowBtn.TextSize = 12
sellNowBtn.Active = true
sellNowBtn.AutoButtonColor = true
sellNowBtn.ZIndex = 10
Instance.new("UICorner", sellNowBtn).CornerRadius = UDim.new(0, 6)

-- Potato Mode Engine: Strips lighting, shadows, particles, and shaders for 60 FPS
local function enablePotatoMode()
    savedLighting.GlobalShadows = Lighting.GlobalShadows
    savedLighting.FogEnd = Lighting.FogEnd
    savedLighting.Brightness = Lighting.Brightness

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
    end)

    for _, eff in ipairs(Lighting:GetChildren()) do
        if eff:IsA("PostProcessEffect") then
            if savedEffects[eff] == nil then
                savedEffects[eff] = eff.Enabled
            end
            pcall(function() eff.Enabled = false end)
        elseif eff:IsA("Atmosphere") then
            if savedEffects[eff] == nil then
                savedEffects[eff] = eff.Density
            end
            pcall(function() eff.Density = 0 end)
        end
    end

    local function stripFX(inst)
        if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") or inst:IsA("Highlight") then
            if savedParticles[inst] == nil then
                savedParticles[inst] = inst.Enabled
            end
            pcall(function() inst.Enabled = false end)
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            if savedDecals[inst] == nil then
                savedDecals[inst] = inst.Transparency
            end
            pcall(function() inst.Transparency = 1 end)
        elseif inst:IsA("BasePart") then
            if not (LocalPlayer.Character and inst:IsDescendantOf(LocalPlayer.Character)) and inst.Material ~= Enum.Material.SmoothPlastic then
                if savedMaterials[inst] == nil then
                    savedMaterials[inst] = inst.Material
                end
                pcall(function() inst.Material = Enum.Material.SmoothPlastic end)
            end
        end
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        stripFX(obj)
    end

    if potatoDescendantConn then
        potatoDescendantConn:Disconnect()
    end
    potatoDescendantConn = Workspace.DescendantAdded:Connect(function(inst)
        if potatoMode then
            task.wait(0.05)
            stripFX(inst)
        end
    end)
end

local function disablePotatoMode()
    if potatoDescendantConn then
        potatoDescendantConn:Disconnect()
        potatoDescendantConn = nil
    end

    pcall(function()
        if savedLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = savedLighting.GlobalShadows end
        if savedLighting.FogEnd ~= nil then Lighting.FogEnd = savedLighting.FogEnd end
        if savedLighting.Brightness ~= nil then Lighting.Brightness = savedLighting.Brightness end
    end)

    for eff, origVal in pairs(savedEffects) do
        if eff and eff.Parent then
            pcall(function()
                if eff:IsA("Atmosphere") then
                    eff.Density = origVal
                else
                    eff.Enabled = origVal
                end
            end)
        end
    end
    savedEffects = {}

    for inst, wasEnabled in pairs(savedParticles) do
        if inst and inst.Parent then
            pcall(function() inst.Enabled = wasEnabled end)
        end
    end
    savedParticles = {}

    for inst, origTrans in pairs(savedDecals) do
        if inst and inst.Parent then
            pcall(function() inst.Transparency = origTrans end)
        end
    end
    savedDecals = {}

    for inst, origMat in pairs(savedMaterials) do
        if inst and inst.Parent then
            pcall(function() inst.Material = origMat end)
        end
    end
    savedMaterials = {}
end

_G.EF_RESTORE_POTATO = disablePotatoMode

local function updatePotatoBtnUI()
    if potatoMode then
        potatoBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 130)
        potatoBtn.Text = "[ ⚡ POTATO MODE: ON ]"
        potatoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        potatoBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
        potatoBtn.Text = "[ ⚡ POTATO MODE: OFF ]"
        potatoBtn.TextColor3 = Color3.fromRGB(190, 210, 235)
    end
end

local function togglePotatoMode()
    potatoMode = not potatoMode
    currentSettings.potatoMode = potatoMode
    saveSettings(currentSettings)
    updatePotatoBtnUI()
    if potatoMode then
        enablePotatoMode()
        print("[EF Master v1.3] Potato Mode ENABLED: FPS optimized! (Saved to settings)")
    else
        disablePotatoMode()
        print("[EF Master v1.3] Potato Mode DISABLED: Graphics restored! (Saved to settings)")
    end
end

-- Replay Button UI & Toggle
local function updateReplayBtnUI()
    if autoReplay then
        replayBtn.BackgroundColor3 = Color3.fromRGB(20, 130, 160)
        replayBtn.Text = "[ 🔄 AUTO-REPLAY: ON ]"
        replayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        replayBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
        replayBtn.Text = "[ 🔄 AUTO-REPLAY: OFF ]"
        replayBtn.TextColor3 = Color3.fromRGB(190, 210, 235)
    end
end

local function toggleAutoReplay()
    autoReplay = not autoReplay
    currentSettings.autoReplay = autoReplay
    saveSettings(currentSettings)
    updateReplayBtnUI()
    if autoReplay then
        print("[EF Master v1.3] Auto-Replay ENABLED! (Saved to settings)")
    else
        print("[EF Master v1.3] Auto-Replay DISABLED! (Saved to settings)")
    end
end

updateReplayBtnUI()

replayBtn.Activated:Connect(toggleAutoReplay)
replayBtn.MouseButton1Click:Connect(toggleAutoReplay)
pcall(function()
    replayBtn.TouchTap:Connect(toggleAutoReplay)
end)
_G.EF_TOGGLE_REPLAY = toggleAutoReplay

-- Auto-Sell Button UI & Toggle
local function updateAutoSellBtnUI()
    if autoSell then
        autoSellBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 20)
        autoSellBtn.Text = "[ 🗑️ AUTO-SELL: ON ]"
        autoSellBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        autoSellBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
        autoSellBtn.Text = "[ 🗑️ AUTO-SELL: OFF ]"
        autoSellBtn.TextColor3 = Color3.fromRGB(190, 210, 235)
    end
end

local function toggleAutoSell()
    autoSell = not autoSell
    currentSettings.autoSell = autoSell
    saveSettings(currentSettings)
    updateAutoSellBtnUI()
    if autoSell then
        print("[EF Master v1.3] Auto-Sell ENABLED! (Saved to settings)")
    else
        print("[EF Master v1.3] Auto-Sell DISABLED! (Saved to settings)")
    end
end
_G.EF_TOGGLE_AUTOSELL = toggleAutoSell

autoSellBtn.Activated:Connect(toggleAutoSell)
autoSellBtn.MouseButton1Click:Connect(toggleAutoSell)
pcall(function()
    autoSellBtn.TouchTap:Connect(toggleAutoSell)
end)
updateAutoSellBtnUI()

-- Manual "Sell Junk Now" button handler
local isSellingManual = false
local function onSellNowClicked()
    if isSellingManual then return end
    isSellingManual = true
    sellNowBtn.Text = "[ SELLING JUNK... ]"
    sellNowBtn.TextColor3 = Color3.fromRGB(255, 200, 50)
    task.spawn(function()
        local sold, kept = runSafeAutoSell()
        if sold > 0 then
            sellNowBtn.Text = string.format("[ SOLD %d JUNK! ]", sold)
            sellNowBtn.TextColor3 = Color3.fromRGB(80, 255, 140)
            statusLabel.Text = string.format("Status: Sold %d EF junk items!", sold)
            statusLabel.TextColor3 = Color3.fromRGB(80, 255, 140)
        else
            sellNowBtn.Text = "[ INVENTORY CLEAN ]"
            sellNowBtn.TextColor3 = Color3.fromRGB(140, 200, 255)
            statusLabel.Text = string.format("Status: Inventory clean (%d safe)", kept)
            statusLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
        end
        task.wait(2.2)
        sellNowBtn.Text = "[ 🧹 SELL JUNK NOW ]"
        sellNowBtn.TextColor3 = Color3.fromRGB(240, 220, 120)
        isSellingManual = false
    end)
end

sellNowBtn.Activated:Connect(onSellNowClicked)
sellNowBtn.MouseButton1Click:Connect(onSellNowClicked)
pcall(function()
    sellNowBtn.TouchTap:Connect(onSellNowClicked)
end)

-- Initialize Potato Mode UI and State on load (default is ON)
updatePotatoBtnUI()
if potatoMode then
    task.spawn(function()
        task.wait(0.15)
        enablePotatoMode()
        updatePotatoBtnUI()
    end)
end

local function isInsideButton(btn, inputPos)
    local bPos = btn.AbsolutePosition
    local bSize = btn.AbsoluteSize
    return inputPos.X >= bPos.X and inputPos.X <= (bPos.X + bSize.X) and
           inputPos.Y >= bPos.Y and inputPos.Y <= (bPos.Y + bSize.Y)
end

potatoBtn.Activated:Connect(togglePotatoMode)
potatoBtn.MouseButton1Click:Connect(togglePotatoMode)
pcall(function()
    potatoBtn.TouchTap:Connect(togglePotatoMode)
end)
_G.EF_TOGGLE_POTATO = togglePotatoMode

local function updateToggleBtnUI()
    if isRunning then
        toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 140, 70)
        toggleBtn.Text = "[ AUTO-FARM: RUNNING ]"
    else
        toggleBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
        toggleBtn.Text = "[ AUTO-FARM: PAUSED ]"
        statusLabel.Text = "Status: Paused by user"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:MoveTo(char:GetPivot().Position) end
    end
end

local function toggleRunning()
    isRunning = not isRunning
    updateToggleBtnUI()
end

toggleBtn.Activated:Connect(toggleRunning)
toggleBtn.MouseButton1Click:Connect(toggleRunning)
pcall(function()
    toggleBtn.TouchTap:Connect(toggleRunning)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed then
        if input.KeyCode == Enum.KeyCode.H then
            isRunning = not isRunning
            updateToggleBtnUI()
        elseif input.KeyCode == Enum.KeyCode.P then
            togglePotatoMode()
        elseif input.KeyCode == Enum.KeyCode.R then
            toggleAutoReplay()
        elseif input.KeyCode == Enum.KeyCode.X then
            toggleAutoSell()
        end
    end
end)

local dragging = false
local dragStart = Vector2.zero
local startPos = UDim2.new()

hudFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        -- Prevent window dragging from swallowing clicks or taps on buttons!
        if isInsideButton(toggleBtn, input.Position) or
           isInsideButton(potatoBtn, input.Position) or
           isInsideButton(replayBtn, input.Position) or
           isInsideButton(autoSellBtn, input.Position) or
           isInsideButton(sellNowBtn, input.Position) then
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
-- 5. LINEAR ROOM SCANNER & SPATIAL TARGET RESOLVER
-- ========================================================================
local ROOM_ORDER = {"room1", "room2", "room3", "room4", "room5", "room6", "bossRoom"}
local BOSS_ROOMS = {room2 = true, room5 = true, bossRoom = true}
local BOSS_NAMES = {["Crystal Golem"] = true, ["Ancient Enchanted Tree"] = true, ["Enchanted Forest Dragon"] = true}

local function checkAutoStart()
    local started = Workspace:FindFirstChild("dungeonStarted")
    if started and not started.Value then
        local remotes = ReplicatedStorage:FindFirstChild("remotes")
        if remotes and remotes:FindFirstChild("changeStartValue") then
            remotes.changeStartValue:FireServer()
        end
    end
end

local PACK_CLUSTER_THRESHOLD = 30 -- studs: cleanly groups mobs into isolated packs (handles side-by-side packs)

local function getTargetCluster(myPos)
    local dung = Workspace:FindFirstChild("dungeon")
    if not dung then return nil end

    for _, rName in ipairs(ROOM_ORDER) do
        local r = dung:FindFirstChild(rName)
        if r and r:FindFirstChild("enemyFolder") then
            local isBossZone = BOSS_ROOMS[rName] or false
            local aliveMobs = {}

            for _, m in ipairs(r.enemyFolder:GetChildren()) do
                if m:IsA("Model") then
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    local hrp = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso")
                    if hum and hrp and hum.Health > 0 then
                        table.insert(aliveMobs, {model = m, hrp = hrp, hum = hum, name = m.Name, pos = hrp.Position})
                    end
                end
            end

            -- Room 5 (Ancient Enchanted Tree) Spawn Guard:
            -- Must wait for tree to spawn after Room 4 mobs die, never skip to Room 6 early!
            if rName == "room5" then
                if treeKilledThisRun then
                    continue
                end

                if #aliveMobs > 0 then
                    treeSpawnDetected = true
                    local boss = aliveMobs[1]
                    local d = (boss.pos - myPos).Magnitude
                    return {
                        isBoss = true,
                        room = rName,
                        name = boss.name,
                        model = boss.model,
                        hrp = boss.hrp,
                        hum = boss.hum,
                        dist = d,
                        minDist = d,
                        backlineDist = d,
                        centerPos = boss.pos
                    }
                else
                    if treeHitsLanded > 0 then
                        -- Tree was fought, took hits and is now gone: confirmed dead!
                        treeKilledThisRun = true
                        continue
                    else
                        -- Tree has not been fought yet (coming up from the ground). Keep waiting!
                        local treePos = Vector3.new(-725.5, -24.1, 366.4)
                        local d = (treePos - myPos).Magnitude
                        return {
                            isBoss = true,
                            isWaitingSpawn = true,
                            room = "room5",
                            name = "Ancient Enchanted Tree",
                            dist = d,
                            minDist = d,
                            backlineDist = d,
                            centerPos = treePos
                        }
                    end
                end
            end

            if #aliveMobs > 0 then
                if isBossZone or BOSS_NAMES[aliveMobs[1].name] then
                    local boss = aliveMobs[1]
                    local d = (boss.pos - myPos).Magnitude
                    return {
                        isBoss = true,
                        room = rName,
                        name = boss.name,
                        model = boss.model,
                        hrp = boss.hrp,
                        hum = boss.hum,
                        dist = d,
                        minDist = d,
                        backlineDist = d,
                        centerPos = boss.pos
                    }
                else
                    -- ========================================================
                    -- MULTI-PACK CLUSTERING ENGINE (Connected Components)
                    -- Groups mobs into distinct isolated packs (handles side-by-side packs)
                    -- ========================================================
                    local n = #aliveMobs
                    local adj = {}
                    for i = 1, n do adj[i] = {} end

                    for i = 1, n do
                        for j = i + 1, n do
                            local pA = aliveMobs[i].pos
                            local pB = aliveMobs[j].pos
                            local dx = pA.X - pB.X
                            local dz = pA.Z - pB.Z
                            if (dx * dx + dz * dz) <= (PACK_CLUSTER_THRESHOLD * PACK_CLUSTER_THRESHOLD) then
                                table.insert(adj[i], j)
                                table.insert(adj[j], i)
                            end
                        end
                    end

                    local visited = {}
                    local packs = {}

                    for i = 1, n do
                        if not visited[i] then
                            local packMobs = {}
                            local stack = {i}
                            visited[i] = true

                            while #stack > 0 do
                                local curr = table.remove(stack)
                                table.insert(packMobs, aliveMobs[curr])
                                for _, neighbor in ipairs(adj[curr]) do
                                    if not visited[neighbor] then
                                        visited[neighbor] = true
                                        table.insert(stack, neighbor)
                                    end
                                end
                            end

                            local sumPos = Vector3.zero
                            local minDist = 999999
                            local backlineDist = 0
                            local closestMob = nil

                            for _, mob in ipairs(packMobs) do
                                local mPos = mob.pos
                                sumPos = sumPos + mPos
                                local d = (mPos - myPos).Magnitude
                                if d < minDist then
                                    minDist = d
                                    closestMob = mob
                                end
                                if d > backlineDist then
                                    backlineDist = d
                                end
                            end

                            local packCenter = sumPos / #packMobs
                            table.insert(packs, {
                                isBoss = false,
                                room = rName,
                                name = closestMob and closestMob.name or "Mob",
                                count = #packMobs,
                                minDist = minDist,
                                backlineDist = backlineDist,
                                centerPos = packCenter,
                                closestMob = closestMob
                            })
                        end
                    end

                    if #packs > 0 then
                        -- Sort packs by distance to player: engage the closest pack first
                        table.sort(packs, function(a, b)
                            return a.minDist < b.minDist
                        end)
                        local bestPack = packs[1]
                        bestPack.totalPacksInRoom = #packs
                        return bestPack
                    end
                end
            end
        end
    end
    return nil
end

-- Highway contains integrated Room 5 platform shortcut (wp 551 to 657)

-- ========================================================================
-- 6. MAIN SPEEDRUN ENGINE (SEAMLESS SPRINT COMBAT)
-- ========================================================================
task.spawn(function()
    while _G.EF_AUTOFARM_RUNNING do
        task.wait(0.04)
        if not isRunning or isCastingCombo or isReplaying then continue end

        local char = LocalPlayer.Character
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end

        local myPos = hrp.Position
        local now = tick()

        if myPos.X > 50 then
            treeKilledThisRun = false
            treeSpawnDetected = false
            treeHitsLanded = 0
            shortcutActive = false
            shortcutIdx = 1
        end

        local inRoom5Shortcut = treeKilledThisRun and myPos.Z < 505 and myPos.X < -630

        checkAutoStart()

        -- Update HUD Timers & Stats
        local elapsed = math.floor(now - startTime)
        local mins = math.floor(elapsed / 60)
        local secs = elapsed % 60
        statsLabel.Text = string.format("Runs: %d | Time: %02d:%02d", runsCompleted, mins, secs)

        local qCd = getQCDRemaining()
        local eCd = getECDRemaining()
        local buffActive = isQBuffActive()
        local qStr = buffActive and "Q: BUFFED" or ((qCd <= 0.05) and "Q: Ready" or string.format("Q: %.1fs", qCd))
        local eStr = (eCd <= 0.05) and "E: Ready" or string.format("E: %.1fs", eCd)
        cdLabel.Text = string.format("%s | %s", qStr, eStr)
        if (buffActive or qCd <= 0.05) and eCd <= 0.05 then
            cdLabel.TextColor3 = Color3.fromRGB(80, 255, 140)
        else
            cdLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
        end

        -- Update Current Highway Waypoint Index (bypassed during straight shortcut)
        if not inRoom5Shortcut and totalWps > 0 then
            local distToCurrent = waypoints[currentWpIndex] and (waypoints[currentWpIndex] - myPos).Magnitude or 999999
            if distToCurrent > 80 then
                currentWpIndex = findClosestWaypointIndex(myPos, 1, totalWps)
            else
                local searchStart = math.max(1, currentWpIndex - 3)
                local searchEnd = math.min(totalWps, currentWpIndex + 25)
                local bestIdx = currentWpIndex
                local bestDist = 999999
                for i = searchStart, searchEnd do
                    local wp = waypoints[i]
                    if wp then
                        local d = (wp - myPos).Magnitude
                        if d < bestDist then
                            bestDist = d
                            bestIdx = i
                        end
                    end
                end
                currentWpIndex = bestIdx
            end

            if waypoints[currentWpIndex] and (waypoints[currentWpIndex] - myPos).Magnitude < 14 then
                currentWpIndex = math.min(totalWps, currentWpIndex + 1)
            end
        end

        -- Resolve Target
        local target = getTargetCluster(myPos)

        if inRoom5Shortcut then
            -- Anti-stuck watchdog: hop over any lip or bump automatically
            if hum.MoveDirection.Magnitude > 0.1 and hrp.AssemblyLinearVelocity.Magnitude < 3 then
                hum.Jump = true
            end

            if not shortcutActive then
                shortcutActive = true
                local bestIdx = 1
                local bestDist = 999999
                for i, pt in ipairs(SHORTCUT_POINTS) do
                    local d = (pt - myPos).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestIdx = i
                    end
                end
                shortcutIdx = math.min(#SHORTCUT_POINTS, bestIdx + 1)
            end

            local targetPt = SHORTCUT_POINTS[shortcutIdx]
            if (myPos - targetPt).Magnitude <= 14 then
                if shortcutIdx < #SHORTCUT_POINTS then
                    shortcutIdx = shortcutIdx + 1
                    targetPt = SHORTCUT_POINTS[shortcutIdx]
                else
                    currentWpIndex = 621
                    shortcutActive = false
                end
            end

            phaseLabel.Text = string.format("Phase: Bypass Bump (%d/%d)", shortcutIdx, #SHORTCUT_POINTS)
            statusLabel.Text = string.format("Status: Skirting Bump to Room 6 (%.0f studs)", (targetPt - myPos).Magnitude)
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 200)

            hum.AutoRotate = true
            if isQReady() then
                castQ()
            end
            smoothMoveTo(hum, targetPt)

            if (myPos - SHORTCUT_POINTS[#SHORTCUT_POINTS]).Magnitude <= 14 or myPos.Z >= 504 then
                currentWpIndex = 621
                shortcutActive = false
                print("[EF Master] Room 5 bump bypass complete! Entering Room 6.")
            end
        elseif target then
            if target.isBoss then
                if target.isWaitingSpawn then
                    phaseLabel.Text = "BOSS: Ancient Tree (Spawning...)"
                    statusLabel.Text = "Status: Holding ground, waiting for Tree..."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)

                    hum:MoveTo(myPos)
                    hum.AutoRotate = false
                    local lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                    hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)

                    if isQReady() then
                        castQ()
                    end
                else
                    -- ============================================================
                    -- SUB-BOSS & BOSS LOGIC (Crystal Golem, Ancient Enchanted Tree, Dragon)
                    -- ============================================================
                    local bossDist = target.dist
                    local isTree = (target.name == "Ancient Enchanted Tree")
                    local strikeThreshold = isTree and 98 or 82
                    phaseLabel.Text = string.format("BOSS: %s (%.0f studs)", target.name, bossDist)

                    -- Pre-buff Q on the run at 130 studs so we sprint towards boss with +80% speed!
                    if bossDist <= 130 and isQReady() then
                        castQ()
                        statusLabel.Text = "Status: Boss Sprint Buff Q Activated!"
                        statusLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
                    end

                    if bossDist <= strikeThreshold then
                        hum:MoveTo(myPos)
                        hum.AutoRotate = false

                        -- Face Boss dead-on
                        local lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                        hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)

                        if isEReady() then
                            isCastingCombo = true
                            statusLabel.Text = "Status: Striking Boss with E!"
                            statusLabel.TextColor3 = Color3.fromRGB(255, 60, 180)

                            if not isQBuffActive() and isQReady() then
                                castQ()
                                task.wait(0.08)
                            end

                            lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                            hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)

                            castE()
                            bossHitsLanded = bossHitsLanded + 1
                            if isTree then
                                treeHitsLanded = treeHitsLanded + 1
                                if target.hum and target.hum.Health <= 0 then
                                    treeKilledThisRun = true
                                    print("[EF Master] Ancient Enchanted Tree killed by E strike!")
                                end
                            end

                            statusLabel.Text = string.format("Status: Boss Hit #%d! Holding ground.", bossHitsLanded)
                            statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                            task.wait(0.6)
                            isCastingCombo = false
                        else
                            statusLabel.Text = string.format("Status: In range, waiting E (%.1fs)", eCd)
                            statusLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
                        end
                    else
                        hum.AutoRotate = true
                        if isTree then
                            -- Step towards tree ONLY until within 92 studs, staying far away from central bump!
                            local dir = (target.centerPos - myPos).Unit
                            local approachPos = target.centerPos - dir * 92
                            statusLabel.Text = string.format("Status: Stepping into Strike Range (%.0f studs)", bossDist)
                            statusLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
                            smoothMoveTo(hum, approachPos)
                        else
                            -- Golem / Dragon: Approach strictly along highway
                            statusLabel.Text = string.format("Status: Approaching Boss along Path (%.0f studs)", bossDist)
                            statusLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
                            local lookaheadIdx = math.min(totalWps, currentWpIndex + 5)
                            local targetWp = waypoints[lookaheadIdx] or waypoints[currentWpIndex]
                            if targetWp then smoothMoveTo(hum, targetWp) end
                        end
                    end
                end
            else
                -- ============================================================
                -- NORMAL PACK LOGIC (Seamless Sprint Architecture)
                -- ============================================================
                local minDist = target.minDist
                local backDist = target.backlineDist
                if target.totalPacksInRoom and target.totalPacksInRoom > 1 then
                    phaseLabel.Text = string.format("%s [Pack %d mobs | %d left]", target.room:upper(), target.count, target.totalPacksInRoom)
                else
                    phaseLabel.Text = string.format("%s: %d mobs (backline: %.0f studs)", target.room:upper(), target.count, backDist)
                end

                -- ZONE 3: AoE WIPE ZONE (Backline is <= 82 studs)
                if backDist <= 82 then
                    hum:MoveTo(myPos)
                    hum.AutoRotate = false

                    -- Shift-lock face the pack center
                    local lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                    hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)

                    local eReady = isEReady()

                    if eReady then
                        isCastingCombo = true
                        statusLabel.Text = string.format("Status: Wiping Pack (%d mobs)!", target.count)
                        statusLabel.TextColor3 = Color3.fromRGB(255, 80, 200)

                        -- If buff not active but Q ready, pop Q before E
                        if not isQBuffActive() and isQReady() then
                            castQ()
                            task.wait(0.12)
                        end

                        -- Re-aim at pack center
                        lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                        hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)

                        -- Detonate E
                        castE()
                        task.wait(0.5)
                        isCastingCombo = false
                    else
                        statusLabel.Text = string.format("Status: Wipe stance (E CD: %.1fs)", eCd)
                        statusLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
                    end

                -- ZONE 2: SAFE STANDOFF GUARD (ONLY IF E IS ACTUALLY ON COOLDOWN AND NO BUFF)
                elseif minDist <= 85 and (not isEReady() and not isQBuffActive()) then
                    hum:MoveTo(myPos)
                    hum.AutoRotate = false
                    local lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                    hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)

                    -- Pre-buff Q before breaking standoff so we start sprinting with buff already active!
                    if isQReady() and eCd <= 1.2 then
                        castQ()
                        statusLabel.Text = "Status: Pre-Buffing Q in Standoff!"
                        statusLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
                    else
                        statusLabel.Text = string.format("Status: Safe Standoff (E CD: %.1fs)", eCd)
                        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
                    end

                -- ZONE 1 & HIGHWAY ADVANCE: NEVER LEAVE RECORDED HIGHWAY WAYPOINTS!
                else
                    hum.AutoRotate = true

                    -- The instant we start walking or advance, pop Q immediately!
                    if isQReady() and (eCd <= 1.5 or isEReady()) then
                        castQ()
                        statusLabel.Text = "Status: Sprint Buff Q Activated!"
                        statusLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
                    end

                    local lookaheadIdx = math.min(totalWps, currentWpIndex + 5)
                    local targetWp = waypoints[lookaheadIdx] or waypoints[currentWpIndex]
                    if targetWp then
                        smoothMoveTo(hum, targetWp)
                        if minDist <= 85 then
                            statusLabel.Text = string.format("Status: Highway Sprint to Wipe (backline: %.0f studs)", backDist)
                            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 220)
                        else
                            statusLabel.Text = string.format("Status: Highway Transit (%.0f studs to pack)", minDist)
                            statusLabel.TextColor3 = Color3.fromRGB(120, 220, 255)
                        end
                    end
                end
            end
        else
            -- ================================================================
            -- ZONE 4: EMPTY HIGHWAY (> 150 studs or no mobs alive)
            -- ================================================================
            hum.AutoRotate = true

            if isQReady() then
                castQ()
            end

            phaseLabel.Text = string.format("Phase: Highway %d/%d", currentWpIndex, totalWps)
            local lookaheadIdx = math.min(totalWps, currentWpIndex + 5)
            local targetWp = waypoints[lookaheadIdx] or waypoints[currentWpIndex]

            if targetWp then
                smoothMoveTo(hum, targetWp)
                statusLabel.Text = string.format("Status: Highway Sprint (wp %d/%d)", currentWpIndex, totalWps)
                statusLabel.TextColor3 = Color3.fromRGB(120, 220, 255)
            end
        end
    end
end)

-- ========================================================================
-- 7. RESPAWN & DEATH HANDLER (KAMIKAZE BOSS LOOP)
-- ========================================================================
LocalPlayer.CharacterAdded:Connect(function(newChar)
    isCastingCombo = false

    task.wait(0.4)
    local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
    local hum = newChar:WaitForChild("Humanoid", 5)
    if hrp and hum then
        hum.AutoRotate = true
        stripWalls()

        local snapIdx = findClosestWaypointIndex(hrp.Position, 1, totalWps)
        currentWpIndex = snapIdx
        print(string.format("[EF Master v1.3] Respawned at %s, resumed at highway wp %d/%d", tostring(hrp.Position), currentWpIndex, totalWps))
    end
end)

-- ========================================================================
-- 8. AUTO-REPLAY & INFINITE FARMING ENGINE
-- ========================================================================
local function getDungeonFinished()
    local dung = Workspace:FindFirstChild("dungeon")
    local br = dung and dung:FindFirstChild("bossRoom")
    local df = br and br:FindFirstChild("dungeonFinished")
    if df and df:IsA("BoolValue") and df.Value == true then
        return true
    end
    return false
end

local function collectDungeonData()
    local data = {}
    local dName = Workspace:FindFirstChild("dungeonName")
    if dName and dName:IsA("StringValue") then data.dungeonName = dName.Value end
    local dProg = Workspace:FindFirstChild("dungeonProgress")
    if dProg and dProg:IsA("StringValue") then data.dungeonProgress = dProg.Value end
    local dStarted = Workspace:FindFirstChild("dungeonStarted")
    if dStarted and dStarted:IsA("BoolValue") then data.dungeonStarted = dStarted.Value end
    local hc = Workspace:FindFirstChild("hardcore")
    if hc and hc:IsA("BoolValue") then
        data.hardcore = hc.Value
        data.isHardcore = hc.Value
    end

    local dung = Workspace:FindFirstChild("dungeon")
    if dung then
        for _, v in ipairs(dung:GetChildren()) do
            if v:IsA("ValueBase") then data[v.Name] = v.Value end
        end
        local br = dung:FindFirstChild("bossRoom")
        if br then
            for _, v in ipairs(br:GetChildren()) do
                if v:IsA("ValueBase") then data[v.Name] = v.Value end
            end
        end
    end
    return data
end

task.spawn(function()
    while _G.EF_AUTOFARM_RUNNING do
        task.wait(0.5)
        if not autoReplay or isReplaying then continue end

        if getDungeonFinished() then
            isReplaying = true
            runsCompleted = runsCompleted + 1
            print(string.format("[EF Master v1.3] Dungeon Victory detected! Total runs completed: %d", runsCompleted))

            -- 5-second reward, auto-sell & EXP safety countdown
            for sec = 5, 1, -1 do
                if not _G.EF_AUTOFARM_RUNNING or not autoReplay then break end
                phaseLabel.Text = string.format("VICTORY! (Replay in %ds)", sec)

                -- At 3s mark, run safe auto-sell once drops are settled
                if sec == 3 and autoSell then
                    statusLabel.Text = "Status: Auto-Selling EF junk..."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
                    task.spawn(function()
                        local sold, kept = runSafeAutoSell()
                        if sold > 0 then
                            statusLabel.Text = string.format("Status: Sold %d EF junk items!", sold)
                            statusLabel.TextColor3 = Color3.fromRGB(80, 255, 140)
                        end
                    end)
                else
                    if not autoSell or sec > 3 then
                        statusLabel.Text = "Status: Saving EXP, Gold & Loot drops..."
                        statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
                    end
                end
                task.wait(1.0)
            end

            if not _G.EF_AUTOFARM_RUNNING or not autoReplay then
                isReplaying = false
                continue
            end

            phaseLabel.Text = "VICTORY! Replaying..."
            statusLabel.Text = "Status: Firing replayDungeon remote..."
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 180)

            local data = collectDungeonData()
            local remotes = ReplicatedStorage:FindFirstChild("remotes")
            local replayRemote = remotes and remotes:FindFirstChild("replayDungeon")
            if replayRemote then
                replayRemote:FireServer(data)
                print("[EF Master v1.3] Fired replayDungeon:FireServer successfully!")
            else
                warn("[EF Master v1.3] replayDungeon remote not found!")
            end

            -- Wait for dungeon to reset / reload
            statusLabel.Text = "Status: Waiting for new dungeon to load..."
            local waitStart = tick()
            while _G.EF_AUTOFARM_RUNNING and (tick() - waitStart) < 15 do
                task.wait(0.5)
                if not getDungeonFinished() then
                    break
                end
            end

            -- Reset run variables for the new run
            currentWpIndex = 1
            treeKilledThisRun = false
            treeSpawnDetected = false
            treeHitsLanded = 0
            shortcutActive = false
            shortcutIdx = 1
            bossHitsLanded = 0
            startTime = tick()
            isCastingCombo = false
            isReplaying = false

            print("[EF Master v1.3] State reset for new run. Ready to farm!")
        end
    end
end)

print("[EF Master v1.3] Enchanted Forest Nightmare Master Auto-Farm Loaded Successfully!")
