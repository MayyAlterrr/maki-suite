-- ========================================================================
--  PROJECT MAKI: BOSS RAID SPEEDRUN & AUTO-FARM ENGINE (V3.1)
--  Dedicated High-Tier Boss Raid Leveling (Level 130 - 145+)
--  
--  CORE BOSS RAID MECHANICS:
--    1. Vanilla WalkSpeed: Movement driven naturally by Infinite Pulse Wave propulsion.
--    2. Universal Auto-Ready: BOTH Carry and ALL Alts instantly click Ready / fire readyUp (0ms).
--    3. Direct Boss Homing Navigation: No map recording needed! Carry finds the Boss and walks straight to it.
--    4. Infinite Pulse Wave Elimination: Continuous Q/E spell rotation to burst the Boss down instantly.
--    5. Highest Available Tier Selector: Automatically launches max unlocked tier (up to Tier 30).
--    6. Progression Master Instant Auto-Accept: showJoinRequest listener + joinRequestConfirm 0ms button fire.
--    7. "Next Tier" & Replay Engine: Clicks Next Tier for < Tier 30, and loops Tier 30 for max gold/XP.
--    8. 100% Protected Loot & Auto-Sell: Collect armors, EF/NL weapons, & Legendaries completely safe.
--    9. Universal Mobile & PC Persistence: Live In-GUI Main/Alts configuration saved to dqr_party_config.json.
-- ========================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- Prevent duplicate instances
if _G.MAKI_BOSS_RAID_RUNNING then
    _G.MAKI_BOSS_RAID_RUNNING = false
    task.wait(0.15)
end
_G.MAKI_BOSS_RAID_RUNNING = true

-- ========================================================================
--  UNIVERSAL EXECUTOR & MOBILE (DELTA) COMPATIBLE FILE I/O
-- ========================================================================
local function safeIsFile(fileName)
    if typeof(isfile) == "function" then
        local ok, res = pcall(isfile, fileName)
        if ok and res ~= nil then return res end
    end
    if typeof(readfile) == "function" then
        local ok, res = pcall(readfile, fileName)
        if ok and res and #res > 0 then return true end
    end
    return false
end

local function safeReadFile(fileName)
    if typeof(readfile) == "function" then
        local ok, res = pcall(readfile, fileName)
        if ok and res and #res > 0 then
            return res
        end
    end
    return nil
end

local function safeWriteFile(fileName, content)
    if typeof(writefile) == "function" then
        return pcall(writefile, fileName, content)
    end
    return false
end

-- ========================================================================
--  REMOTES & NETWORKING
-- ========================================================================
local remotes = ReplicatedStorage:WaitForChild("remotes", 15)
local createBossLobbyRemote          = remotes and remotes:FindFirstChild("createBossLobby")
local addPlayerToBossWhitelistRemote = remotes and remotes:FindFirstChild("addPlayerToBossWhitelist")
local removePlayerFromBossWhitelistRemote = remotes and remotes:FindFirstChild("removePlayerFromBossWhitelist")
local playerJoinBossLobbyRemote      = remotes and remotes:FindFirstChild("playerJoinBossLobby")
local startBossRaidRemote            = remotes and remotes:FindFirstChild("startBossRaid")
local leaveBossLobbyRemote           = remotes and remotes:FindFirstChild("leaveBossLobby")

-- Standard Dungeon Remotes (Fallback & Universal Support)
local createLobbyRemote          = remotes and remotes:FindFirstChild("createLobby")
local addPlayerToWhitelistRemote = remotes and remotes:FindFirstChild("addPlayerToWhitelist")
local startDungeonRemote         = remotes and remotes:FindFirstChild("startDungeon")
local changeStartValueRemote     = remotes and remotes:FindFirstChild("changeStartValue")
local sendJoinRequestRemote      = remotes and remotes:FindFirstChild("sendJoinRequest")
local showJoinRemote             = remotes and remotes:FindFirstChild("showJoinRequest")
local joinDungeonRemote          = remotes and remotes:FindFirstChild("joinDungeon")
local respondJoinRequestRemote   = remotes and remotes:FindFirstChild("respondJoinRequest")
local readyUpRemote              = remotes and remotes:FindFirstChild("readyUp")
local showReadyGuiRemote         = remotes and remotes:FindFirstChild("showReadyGui")
local replayRemote               = remotes and remotes:FindFirstChild("replayDungeon")
local sellItemEventRemote        = remotes and remotes:FindFirstChild("sellItemEvent")
local reloadInvyRemote           = remotes and remotes:FindFirstChild("reloadInvy")
local abilityUsedRemote          = remotes and remotes:FindFirstChild("abilityUsed")
local abilityCastRemote          = remotes and remotes:FindFirstChild("abilityCast")
local weaponUsedRemote           = remotes and remotes:FindFirstChild("weaponUsed")
local teleToLobbyRemote          = remotes and (remotes:FindFirstChild("teleToLobby") or remotes:FindFirstChild("ReturnToLobbyEvent") or remotes:FindFirstChild("leaveGame"))
local announceDropRemote         = remotes and remotes:FindFirstChild("AnnounceDrop")
local upgradeKeyRemote           = remotes and remotes:FindFirstChild("upgradeKey")

-- ========================================================================
--  PURPLE COLLECTIBLES DICTIONARY & TIER MATRIX
-- ========================================================================
local PurpleCollectPrefixes = {
    { prefix = "godly",        dungeon = "Pirate Island (PI)",    tier = 1, isHighTier = false },
    { prefix = "titan-forged", dungeon = "King's Castle (KC)",    tier = 2, isHighTier = false },
    { prefix = "titan forged", dungeon = "King's Castle (KC)",    tier = 2, isHighTier = false },
    { prefix = "titanforged",  dungeon = "King's Castle (KC)",    tier = 2, isHighTier = false },
    { prefix = "glorious",     dungeon = "The Underworld (UW)",   tier = 3, isHighTier = false },
    { prefix = "ancestral",    dungeon = "Samurai Palace (SP)",   tier = 4, isHighTier = false },
    { prefix = "overlord",     dungeon = "The Canals (TC)",       tier = 5, isHighTier = false },
    { prefix = "mythical",     dungeon = "Ghastly Harbor (GH)",   tier = 6, isHighTier = false },
    { prefix = "war-forged",   dungeon = "Steampunk Sewers (SS)", tier = 7, isHighTier = false },
    { prefix = "war forged",   dungeon = "Steampunk Sewers (SS)", tier = 7, isHighTier = false },
    { prefix = "warforged",    dungeon = "Steampunk Sewers (SS)", tier = 7, isHighTier = false },
    { prefix = "alien",        dungeon = "Orbital Outpost (OO)",  tier = 8, isHighTier = false },
    { prefix = "triton",       dungeon = "Aquatic Temple (AT)",   tier = 0, isHighTier = false },
    { prefix = "eldenbark",    dungeon = "Enchanted Forest (EF)", tier = 9, isHighTier = true  },
    { prefix = "valhalla",     dungeon = "Northern Lands (NL)",   tier = 10, isHighTier = true },
}

local function isPurpleCollect(itemName)
    if not itemName or #itemName == 0 then return false, nil, nil, false end
    local nameLower = itemName:lower()
    for _, item in ipairs(PurpleCollectPrefixes) do
        local pClean = item.prefix:gsub("%-", "%%-")
        if nameLower:find(pClean) or nameLower:find(item.prefix:gsub("%-", " ")) or nameLower:find(item.prefix:gsub("%-", "")) then
            return true, item.prefix:upper(), item.dungeon, item.isHighTier
        end
    end
    return false, nil, nil, false
end

local function isSpecialEventItem(itemName)
    if not itemName then return false end
    local n = itemName:lower()
    if n:find("eif") or n:find("eir") or n:find("eye of") or n:find("inferno") or n:find("valhalla") or n:find("eldenbark") then
        return true
    end
    return false
end

-- ========================================================================
--  CONFIG & PERSISTENCE
-- ========================================================================
local ConfigFileName = "dqr_party_config.json"
local Config = {
    CarryUsername       = "",
    AltUsernames        = {},
    AltLevels           = {},
    CurrentTier         = 30,
    HardcoreMode        = true,
    AutoAcceptJoins     = true,
    AutoReadyUp         = true,
    AutoNextTier        = true,
    AutoSellTrashes     = true,
    DiscordWebhookUrl   = "",
    NotifyLegendary     = true,
    NotifyUltimate      = true,
    NotifyCollects      = true,
    CpuSaverMode        = true,
    UltraPotatoGraphics = true,
    Disable3dOnAlts     = true,
    AltFpsCap           = 12,
    CarryFpsCap         = 55
}

local function loadConfig()
    local raw = safeReadFile(ConfigFileName)
    if raw and #raw > 0 then
        local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and type(parsed) == "table" then
            for k, v in pairs(parsed) do Config[k] = v end
            print(string.format("[Maki Config 📂] Loaded config! Main: '%s', Alts: %d", tostring(Config.CarryUsername), #(Config.AltUsernames or {})))
        end
    end
    if not Config.CarryUsername then Config.CarryUsername = "" end
    if not Config.AltLevels then Config.AltLevels = {} end
    if not Config.AltUsernames then Config.AltUsernames = {} end
    if not Config.CurrentTier then Config.CurrentTier = 30 end
    if Config.AutoReadyUp == nil then Config.AutoReadyUp = true end
    if Config.AutoNextTier == nil then Config.AutoNextTier = true end
    if Config.AutoSellTrashes == nil then Config.AutoSellTrashes = true end
    if not Config.DiscordWebhookUrl then Config.DiscordWebhookUrl = "" end
    if Config.CpuSaverMode == nil then Config.CpuSaverMode = true end
    if Config.UltraPotatoGraphics == nil then Config.UltraPotatoGraphics = true end
    if Config.Disable3dOnAlts == nil then Config.Disable3dOnAlts = true end
    if Config.NotifyCollects == nil then Config.NotifyCollects = true end
    if not Config.AltFpsCap then Config.AltFpsCap = 12 end
    Config.CarryFpsCap = 55
end

local function saveConfig()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(Config) end)
    if ok and encoded then
        safeWriteFile(ConfigFileName, encoded)
    end
end

loadConfig()

local isCarry = false
local function updateCarryRole()
    if Config.CarryUsername and #Config.CarryUsername > 0 then
        isCarry = (LocalPlayer.Name:lower() == Config.CarryUsername:lower())
    else
        isCarry = false
    end
end
updateCarryRole()

local function areAllAltsPresent()
    if not Config.AltUsernames or #Config.AltUsernames == 0 then return true end
    local validAlts = {}
    for _, name in ipairs(Config.AltUsernames) do
        if type(name) == "string" and #name > 0 then
            table.insert(validAlts, name)
        end
    end
    if #validAlts == 0 then return true end

    for _, altName in ipairs(validAlts) do
        local p = Players:FindFirstChild(altName)
        if not p then return false end
        local char = p.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hrp or not hum then
            return false
        end
    end
    return true
end

-- ========================================================================
--  MODULE 6: ULTRA-POTATO GRAPHICS & CPU SAVER ENGINE
-- ========================================================================
local function stripObjectVisuals(obj)
    if not Config.UltraPotatoGraphics then return end
    pcall(function()
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.CastShadow = false
            obj.Reflectance = 0
            if obj:IsA("MeshPart") then
                obj.TextureID = ""
            end
        elseif obj:IsA("SpecialMesh") then
            obj.TextureId = ""
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            obj.Enabled = false
        elseif obj:IsA("Light") then
            obj.Enabled = false
        elseif obj:IsA("PostEffect") or obj:IsA("Atmosphere") or obj:IsA("Sky") or obj:IsA("Clouds") then
            obj.Enabled = false
        end
    end)
end

local function applyUltraPotatoGraphics()
    if not Config.UltraPotatoGraphics then return end

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        for _, obj in ipairs(Lighting:GetChildren()) do
            if obj:IsA("PostEffect") or obj:IsA("Atmosphere") or obj:IsA("Sky") or obj:IsA("Clouds") then
                pcall(function() obj.Enabled = false end)
            end
        end
    end)

    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
        end
    end)

    for _, desc in ipairs(Workspace:GetDescendants()) do
        stripObjectVisuals(desc)
    end

    pcall(function()
        if settings and settings():GetService("RenderSettings") then
            settings():GetService("RenderSettings").QualityLevel = Enum.QualityLevel.Level01
        end
    end)

    if typeof(setfpscap) == "function" then
        if isCarry then
            setfpscap(Config.CarryFpsCap or 55)
        else
            setfpscap(Config.AltFpsCap or 12)
        end
    end

    if not isCarry and Config.Disable3dOnAlts then
        pcall(function() RunService:Set3dRenderingEnabled(false) end)
    else
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
    end

    if not isCarry then
        pcall(function() SoundService:SetVolume(0) end)
    end
end

Workspace.DescendantAdded:Connect(function(child)
    if Config.UltraPotatoGraphics then
        task.defer(function()
            stripObjectVisuals(child)
        end)
    end
end)

task.spawn(function()
    task.wait(1.0)
    applyUltraPotatoGraphics()
end)

task.spawn(function()
    while _G.MAKI_BOSS_RAID_RUNNING do
        task.wait(8.0)
        if Config.UltraPotatoGraphics then
            for _, desc in ipairs(Workspace:GetDescendants()) do
                if desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
                    desc.Enabled = false
                elseif desc:IsA("Decal") or desc:IsA("Texture") then
                    desc.Transparency = 1
                end
            end
        end
    end
end)

-- ========================================================================
--  DISCORD WEBHOOK NOTIFIER
-- ========================================================================
local httpReq = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)

local function sendDiscordWebhook(embed)
    if not Config.DiscordWebhookUrl or #Config.DiscordWebhookUrl < 15 or not httpReq then return end
    task.spawn(function()
        local payload = {
            username = "Maki Boss Raid Notifier 👑",
            avatar_url = "https://raw.githubusercontent.com/Real-Roblox/Assets/main/maki_avatar.png",
            embeds = { embed }
        }
        pcall(function()
            httpReq({
                Url = Config.DiscordWebhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)
end

local function sendDropNotification(playerName, itemName, rarity, category, raidTier)
    local rLower = rarity and rarity:lower() or "common"
    local isCollect, collectPrefix, collectSource, isHighTier = isPurpleCollect(itemName)
    local isEvent = isSpecialEventItem(itemName)

    local color = 10181046
    local titlePrefix = "💜 PURPLE DROP!"
    local rarityText = (rarity or "Item"):upper()

    if isCollect then
        if not Config.NotifyCollects then return end
        color = 10181046
        titlePrefix = string.format("💎 PURPLE COLLECT DROP! [%s] ⭐", collectPrefix)
        rarityText = string.format("PURPLE COLLECT (%s)", collectPrefix)
    elseif isEvent then
        color = 16753920
        titlePrefix = "🔥 SPECIAL EVENT / UNIQUE DROP! ⭐"
        rarityText = "EVENT / MYTHIC"
    elseif rLower == "legendary" then
        if not Config.NotifyLegendary then return end
        color = 16766720
        titlePrefix = "🌟 LEGENDARY DROP!"
    elseif rLower == "ultimate" then
        if not Config.NotifyUltimate then return end
        color = 16711680
        titlePrefix = "🔥 ULTIMATE DROP!"
    elseif rLower == "mythic" then
        color = 33023
        titlePrefix = "💎 MYTHIC DROP!"
    else
        return
    end

    local embed = {
        title = titlePrefix,
        color = color,
        fields = {
            { name = "👤 Account", value = string.format("`%s`", playerName), inline = true },
            { name = "⚔️ Item Dropped", value = string.format("**%s**", itemName), inline = true },
            { name = "💎 Rarity / Tier", value = string.format("`%s` (%s)", rarityText, category or "Gear"), inline = true },
            { name = "👑 Raid Tier", value = string.format("Boss Raid Tier %s", tostring(raidTier or Config.CurrentTier or "30")), inline = true },
            { name = "🔒 Inventory Status", value = "🛡️ **100% PROTECTED & KEPT IN INVENTORY**", inline = false }
        },
        footer = { text = "Project Maki • Boss Raid Auto-Farm V3.1" },
        timestamp = DateTime.now():ToIsoDate()
    }

    sendDiscordWebhook(embed)
    print(string.format("[Maki Loot 📢] %s dropped %s (%s) in Tier %s ➔ Sent to Discord!", playerName, itemName, rarity, tostring(raidTier or Config.CurrentTier)))
end

-- ========================================================================
--  LOCATION & RAID DETECTION
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

local function isRaidOrDungeon()
    return not isMainLobby()
end

local function getMatchProgress()
    local dProg = Workspace:FindFirstChild("dungeonProgress")
    return (dProg and dProg:IsA("StringValue")) and dProg.Value:lower() or "active"
end

local function getCurrentRaidTier()
    local dObj = Workspace:FindFirstChild("dungeon")
    local tVal = dObj and (dObj:FindFirstChild("tier") or dObj:FindFirstChild("raidTier"))
    if tVal and tVal:IsA("IntValue") and tVal.Value > 0 then
        return tVal.Value
    end
    return Config.CurrentTier or 30
end

local function isClientStuckInLoading()
    if isMainLobby() then return false end

    local dObj  = Workspace:FindFirstChild("dungeon")
    local char  = LocalPlayer.Character
    local hrp   = char and char:FindFirstChild("HumanoidRootPart")

    if dObj and hrp then return false end

    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        for _, name in ipairs({"loadingGui", "teleportGui", "transitionGui", "blackScreen", "loadingScreen"}) do
            local g = pG:FindFirstChild(name)
            if g and ((g:IsA("ScreenGui") and g.Enabled) or (g:IsA("GuiObject") and g.Visible)) then
                return true
            end
        end
    end

    if not dObj and not hrp then return true end
    return false
end

-- ========================================================================
--  MODULE 0: 20-SECOND LOADING WATCHDOG
-- ========================================================================
local stuckLoadingSeconds = 0
task.spawn(function()
    while _G.MAKI_BOSS_RAID_RUNNING do
        task.wait(1.0)
        if isClientStuckInLoading() then
            stuckLoadingSeconds = stuckLoadingSeconds + 1
            if stuckLoadingSeconds >= 20 then
                warn("[Maki Watchdog 🚨] Stuck on loading screen for 20s! Returning to Main Lobby...")
                stuckLoadingSeconds = 0
                if teleToLobbyRemote then pcall(function() teleToLobbyRemote:FireServer() end) end
                task.wait(0.5)
                pcall(function() TeleportService:Teleport(77649408247578, LocalPlayer) end)
            end
        else
            stuckLoadingSeconds = 0
        end
    end
end)

-- ========================================================================
--  KEY SCANNER: DYNAMIC HIGHEST TIER SELECTION
-- ========================================================================
local function getHighestUnlockedTier()
    if not reloadInvyRemote then return 30 end
    local ok, inv = pcall(function() return reloadInvyRemote:InvokeServer() end)
    if not ok or type(inv) ~= "table" or not inv.keys then return 30 end

    local maxTier = 1
    for keyStr, hasKey in pairs(inv.keys) do
        if hasKey == true then
            local tNum = tonumber(keyStr)
            if tNum and tNum > maxTier then
                maxTier = tNum
            end
        end
    end
    return maxTier
end

-- ========================================================================
--  UNIVERSAL AUTO-READY ENGINE (CARRY + ALL ALTS)
-- ========================================================================
local function executeInstantReadyUp()
    if not Config.AutoReadyUp or not isRaidOrDungeon() then return end

    -- If Carry, DO NOT ready up until ALL configured alts are inside the raid room with loaded characters!
    if isCarry and not areAllAltsPresent() then
        return
    end

    if readyUpRemote then
        pcall(function() readyUpRemote:FireServer() end)
    end

    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        for _, gui in ipairs(pG:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("GuiButton") then
                        local text = (desc:IsA("TextButton") and desc.Text or ""):lower()
                        local name = desc.Name:lower()
                        if text:find("ready") or name:find("ready") then
                            pcall(function()
                                for _, c in ipairs(getconnections(desc.Activated)) do c:Fire() end
                                for _, c in ipairs(getconnections(desc.MouseButton1Click)) do c:Fire() end
                                for _, c in ipairs(getconnections(desc.MouseButton1Down)) do c:Fire() end
                            end)
                        end
                    end
                end
            end
        end
    end
end

if showReadyGuiRemote then
    showReadyGuiRemote.OnClientEvent:Connect(function()
        task.spawn(executeInstantReadyUp)
    end)
end

task.spawn(function()
    while _G.MAKI_BOSS_RAID_RUNNING do
        task.wait(0.15)
        if isRaidOrDungeon() then
            local prog = getMatchProgress()
            if prog == "playersnotready" or prog:find("ready") or (isCarry and areAllAltsPresent()) then
                executeInstantReadyUp()
            end
        end
    end
end)

-- ========================================================================
--  DIRECT BOSS HOMING & CONTINUOUS FORWARD ADVANCE ENGINE
-- ========================================================================
local function findBossTarget()
    local containers = {
        Workspace:FindFirstChild("enemies"),
        Workspace:FindFirstChild("boss"),
        Workspace:FindFirstChild("dungeon"),
        Workspace:FindFirstChild("Arena"),
        Workspace
    }

    local function checkModel(obj)
        if not obj or not obj:IsA("Model") or obj == LocalPlayer.Character then return nil end
        local hum = obj:FindFirstChildOfClass("Humanoid")
        local hrp = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head") or obj:FindFirstChild("Torso")
        if hum and hrp and hum.Health > 0 then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character == obj or p.Name == obj.Name then
                    return nil
                end
            end
            return obj, hrp, hum
        end
        return nil
    end

    for _, container in ipairs(containers) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                local m, r, h = checkModel(child)
                if m and r and h then return m, r, h end
            end
        end
    end

    for _, container in ipairs(containers) do
        if container then
            for _, desc in ipairs(container:GetDescendants()) do
                local m, r, h = checkModel(desc)
                if m and r and h then return m, r, h end
            end
        end
    end

    return nil, nil, nil
end

-- Continuous Arena Wall/Barrier Bypass
task.spawn(function()
    while _G.MAKI_BOSS_RAID_RUNNING do
        if isCarry and isRaidOrDungeon() then
            local dungeon = Workspace:FindFirstChild("dungeon") or Workspace
            for _, desc in ipairs(dungeon:GetDescendants()) do
                if desc:IsA("BasePart") then
                    local pName = desc.Name:lower()
                    local parName = desc.Parent and desc.Parent.Name:lower() or ""
                    if pName:find("door") or pName:find("gate") or pName:find("barrier") or pName:find("blocker") or parName:find("doors") or parName:find("gates") or desc.Transparency >= 0.8 then
                        if not pName:find("floor") and not pName:find("ground") and not pName:find("step") and not pName:find("stair") then
                            desc.CanCollide = false
                        end
                    end
                end
            end
        end
        task.wait(1.5)
    end
end)

-- Continuous Boss Chasing & Movement Drive
task.spawn(function()
    while _G.MAKI_BOSS_RAID_RUNNING do
        task.wait(0.03)
        if isCarry and isRaidOrDungeon() then
            local myChar = LocalPlayer.Character
            local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")

            if myHrp and myHum and myHum.Health > 0 then
                local bossModel, bossHrp, bossHum = findBossTarget()
                if bossHrp and bossHum and bossHum.Health > 0 then
                    local myPos = myHrp.Position
                    local bossPos = bossHrp.Position
                    local toBoss = (bossPos - myPos)
                    local dist = toBoss.Magnitude

                    -- Continuously face the boss
                    local flatLook = Vector3.new(toBoss.X, 0, toBoss.Z)
                    if flatLook.Magnitude > 0.1 then
                        myHrp.CFrame = CFrame.lookAt(myPos, Vector3.new(bossPos.X, myPos.Y, bossPos.Z))
                    end

                    -- Continuously drive character forward towards boss
                    if dist > 3.5 then
                        local walkDir = flatLook.Unit
                        myHum:Move(walkDir, false)
                        myHum:MoveTo(bossPos)
                    else
                        myHum:Move(Vector3.zero, false)
                    end
                end
            end
        end
    end
end)

-- ========================================================================
--  MODULE 1: DEATH AURA (INFINITE PULSE WAVE ROTATION)
-- ========================================================================
local function getAbilityTools()
    local qTool, eTool = nil, nil
    local allTools = {}
    local function scan(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA('Tool') then
                table.insert(allTools, item)
                local slotVal = item:FindFirstChild('abilitySlot') or item:FindFirstChild('slot') or item:FindFirstChild('Slot')
                local sName = slotVal and tostring(slotVal.Value):lower()
                if sName == 'q' and not qTool then qTool = item
                elseif sName == 'e' and not eTool then eTool = item end
            end
        end
    end
    scan(LocalPlayer:FindFirstChild('Backpack'))
    scan(LocalPlayer.Character)
    if not qTool and #allTools >= 1 then qTool = allTools[1] end
    if not eTool and #allTools >= 2 then eTool = allTools[2] end
    return qTool, eTool
end

local function getToolCooldown(tool)
    if not tool then return 0 end
    local cd = tool:FindFirstChild("cooldown")
    if cd and cd:IsA("NumberValue") then return cd.Value end
    return 0
end

local lastCastedSlot = nil
local lastCastTimestamp = 0

local function castSlot(slotKey, tool)
    if not tool then return end
    task.spawn(function()
        local le = tool:FindFirstChild('localEvent')
        if le and le:IsA('BindableEvent') then pcall(function() le:Fire() end) end
        local se = tool:FindFirstChild('spellEvent')
        if se and se:IsA('RemoteEvent') then pcall(function() se:FireServer() end) end
        local ev = tool:FindFirstChild('abilityEvent')
        if ev and ev:IsA('RemoteEvent') then pcall(function() ev:FireServer() end) end
        if abilityUsedRemote then pcall(function() abilityUsedRemote:FireServer(slotKey, tool) end) end
        if abilityCastRemote then pcall(function() abilityCastRemote:FireServer(slotKey) end) end
        pcall(function() tool:Activate() end)
        if VirtualInputManager then
            local key = (slotKey == 'q' and Enum.KeyCode.Q) or (slotKey == 'e' and Enum.KeyCode.E) or Enum.KeyCode.Q
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, key, false, game)
                task.wait(0.01)
                VirtualInputManager:SendKeyEvent(false, key, false, game)
            end)
        end
    end)
end

task.spawn(function()
    while _G.MAKI_BOSS_RAID_RUNNING do
        task.wait(0.03)
        if isCarry and isRaidOrDungeon() then
            local now = os.clock()
            local qTool, eTool = getAbilityTools()
            local qCd = getToolCooldown(qTool)
            local eCd = getToolCooldown(eTool)

            if lastCastedSlot == nil then
                if qTool and qCd <= 0.05 then
                    castSlot("q", qTool)
                    lastCastedSlot = "q"
                    lastCastTimestamp = now
                elseif eTool and eCd <= 0.05 then
                    castSlot("e", eTool)
                    lastCastedSlot = "e"
                    lastCastTimestamp = now
                end
            elseif lastCastedSlot == "q" then
                if qCd <= 2.0 and (now - lastCastTimestamp) >= 1.5 then
                    if eTool and eCd <= 0.08 then
                        castSlot("e", eTool)
                        lastCastedSlot = "e"
                        lastCastTimestamp = now
                    end
                end
            elseif lastCastedSlot == "e" then
                if eCd <= 2.0 and (now - lastCastTimestamp) >= 1.5 then
                    if qTool and qCd <= 0.08 then
                        castSlot("q", qTool)
                        lastCastedSlot = "q"
                        lastCastTimestamp = now
                    end
                end
            end
        end
    end
end)

-- Pure vanilla WalkSpeed: Pulse Wave ability provides natural movement buff

-- ========================================================================
--  MODULE 3: REFINED AUTO-SELL & PURPLE COLLECT PROTECTION ENGINE
-- ========================================================================
local knownInventoryKeys = {}
local initialScanComplete = false

local function isItemProtectedFromSell(category, itemName, rarity, isEquipped)
    if isEquipped then return true end

    local rLower = rarity and rarity:lower() or "common"
    if rLower == "legendary" or rLower == "ultimate" or rLower == "mythic" then
        return true
    end

    if isSpecialEventItem(itemName) then
        return true
    end

    local isCollect, collectPrefix, collectSource, isHighTier = isPurpleCollect(itemName)

    if category == "ability" then
        return false
    end

    if category == "weapon" then
        if isCollect and isHighTier then
            return true
        end
        return false
    end

    if category == "chest" or category == "helmet" then
        if isCollect then
            return true
        end
        return false
    end

    return false
end

local function executeUniversalAutoSell()
    if not Config.AutoSellTrashes or not reloadInvyRemote or not sellItemEventRemote then return end
    local ok, inv = pcall(function() return reloadInvyRemote:InvokeServer() end)
    if not ok or type(inv) ~= "table" then return end

    local itemsToSell = { weapon = {}, ability = {}, chest = {}, helmet = {} }
    local totalSold = 0

    local function scanCategory(category, tbl, keyPrefix)
        if type(tbl) ~= "table" then return end
        for key, item in pairs(tbl) do
            local itemKey = tostring(key)
            local isEquipped = (typeof(item.equipped) == "table" and (item.equipped.q or item.equipped.e)) or (item.equipped == true)
            local rarity = item.rarity and item.rarity:lower() or "common"
            local itemName = item.name or item.displayName or itemKey

            local protected = isItemProtectedFromSell(category, itemName, rarity, isEquipped)

            if initialScanComplete and not knownInventoryKeys[itemKey] then
                knownInventoryKeys[itemKey] = true
                if protected and (rarity == "legendary" or rarity == "ultimate" or rarity == "mythic" or isPurpleCollect(itemName) or isSpecialEventItem(itemName)) then
                    sendDropNotification(LocalPlayer.Name, itemName, rarity, category, Config.CurrentTier)
                end
            else
                knownInventoryKeys[itemKey] = true
            end

            if not protected then
                local idNum = tonumber(string.sub(itemKey, #keyPrefix + 1)) or tonumber(string.match(itemKey, "%d+"))
                if idNum then
                    table.insert(itemsToSell[category], idNum)
                    totalSold = totalSold + 1
                end
            end
        end
    end

    scanCategory("weapon", inv.weapons, "weapon_")
    scanCategory("ability", inv.abilities, "ability_")
    scanCategory("chest", inv.chests, "chest_")
    scanCategory("helmet", inv.helmets, "helmet_")

    initialScanComplete = true

    if totalSold > 0 then
        pcall(function() sellItemEventRemote:FireServer(itemsToSell) end)
        print(string.format("[%s] 💰 Auto-Sold %d trash items! (Collect Armors, High-Tier Weapons & Legendaries 100%% SAFE)", LocalPlayer.Name, totalSold))
    end
end

task.spawn(function()
    task.wait(2.0)
    if reloadInvyRemote then
        local ok, inv = pcall(function() return reloadInvyRemote:InvokeServer() end)
        if ok and type(inv) == "table" then
            local function seed(tbl)
                if type(tbl) ~= "table" then return end
                for key, _ in pairs(tbl) do knownInventoryKeys[tostring(key)] = true end
            end
            seed(inv.weapons)
            seed(inv.abilities)
            seed(inv.chests)
            seed(inv.helmets)
            initialScanComplete = true
        end
    end
end)

if announceDropRemote then
    announceDropRemote.OnClientEvent:Connect(function(dropPlayerName, dropItemName, dropRarity, ...)
        if dropPlayerName and dropItemName and dropRarity then
            local pName = tostring(dropPlayerName)
            local iName = tostring(dropItemName)
            local rName = tostring(dropRarity)
            sendDropNotification(pName, iName, rName, "Boss Raid Drop", Config.CurrentTier)
        end
    end)
end

-- ========================================================================
--  MODULE 4: TRUE ZERO-LATENCY INSTANT AUTO-ACCEPT ENGINE (0ms APPROVAL)
--  (EXACT PROGRESSION MASTER ARCHITECTURE)
-- ========================================================================
local function instantAcceptAndDestroyPopup(gui)
    if not gui or gui.Name ~= "joinRequestConfirm" then return end
    if not isCarry or not Config.AutoAcceptJoins then return end

    local cBtn = gui:FindFirstChild("confirm", true) and gui.confirm:FindFirstChild("TextButton", true)
    if cBtn then
        pcall(function()
            for _, c in ipairs(getconnections(cBtn.MouseButton1Click)) do c:Fire() end
            for _, c in ipairs(getconnections(cBtn.MouseButton1Down)) do c:Fire() end
            for _, c in ipairs(getconnections(cBtn.Activated)) do c:Fire() end
        end)
    end

    local pLbl = gui:FindFirstChild("prompt", true)
    if pLbl and pLbl.Text and respondJoinRequestRemote then
        for _, altName in ipairs(Config.AltUsernames) do
            if pLbl.Text:lower():find(altName:lower()) then
                pcall(function() respondJoinRequestRemote:FireServer(altName, true) end)
            end
        end
    end

    pcall(function() gui:Destroy() end)
end

local pGui = LocalPlayer:WaitForChild("PlayerGui")

pGui.ChildAdded:Connect(function(child)
    if child.Name == "joinRequestConfirm" then
        instantAcceptAndDestroyPopup(child)
    end
end)

if showJoinRemote and respondJoinRequestRemote then
    showJoinRemote.OnClientEvent:Connect(function(requesterName, ...)
        if isCarry and Config.AutoAcceptJoins then
            local nameStr = tostring(requesterName)
            pcall(function()
                respondJoinRequestRemote:FireServer(nameStr, true)
            end)
            print(string.format("[Maki Instant Accept] ⚡ Instantly Approved Alt: %s (0ms)!", nameStr))

            task.spawn(function()
                for _, c in ipairs(pGui:GetChildren()) do
                    if c.Name == "joinRequestConfirm" then
                        instantAcceptAndDestroyPopup(c)
                    end
                end
            end)
        end
    end)
end

task.spawn(function()
    while _G.MAKI_BOSS_RAID_RUNNING do
        task.wait(0.08)
        if isCarry and isRaidOrDungeon() and Config.AutoAcceptJoins then
            for _, c in ipairs(pGui:GetChildren()) do
                if c.Name == "joinRequestConfirm" then
                    instantAcceptAndDestroyPopup(c)
                end
            end
            if respondJoinRequestRemote then
                for _, altName in ipairs(Config.AltUsernames) do
                    if not Players:FindFirstChild(altName) then
                        pcall(function()
                            respondJoinRequestRemote:FireServer(altName, true)
                        end)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while _G.MAKI_BOSS_RAID_RUNNING do
        if not isCarry and isMainLobby() then
            pcall(function()
                if sendJoinRequestRemote then
                    if Config.CarryUsername and #Config.CarryUsername > 0 then sendJoinRequestRemote:InvokeServer(Config.CarryUsername) end
                end
                if joinDungeonRemote then
                    if Config.CarryUsername and #Config.CarryUsername > 0 then joinDungeonRemote:InvokeServer(Config.CarryUsername) end
                end
            end)
        end
        task.wait(0.5)
    end
end)

-- ========================================================================
--  MODULE 5: BOSS RAID HOST & STAGING ENGINE
-- ========================================================================
local isCreatingBossLobby = false
local function carryCreateAndLaunchBossRaid()
    if not isCarry or not isMainLobby() or isCreatingBossLobby then return end
    isCreatingBossLobby = true

    loadConfig()

    local highestTier = getHighestUnlockedTier()
    Config.CurrentTier = highestTier
    saveConfig()

    print(string.format("[Maki Boss Raid Host] 👑 Creating Boss Raid Lobby: Tier %d (Private)...", highestTier))

    local ok, res = pcall(function()
        return createBossLobbyRemote:InvokeServer(highestTier, true, 0)
    end)

    if ok and res == true then
        print("[Maki Boss Raid Host] ✅ Boss Lobby Created! Whitelisting Alts...")
        if addPlayerToBossWhitelistRemote then
            for _, name in ipairs(Config.AltUsernames) do
                pcall(function() addPlayerToBossWhitelistRemote:FireServer(name) end)
                task.wait(0.01)
            end
        end

        if changeStartValueRemote then pcall(function() changeStartValueRemote:FireServer() end) end
        task.wait(0.2)
        print("[Maki Boss Raid Host] 🚀 Teleporting Carry ALONE to Boss Staging Room...")
        if startBossRaidRemote then pcall(function() startBossRaidRemote:FireServer() end) end
        task.wait(3.0)
        isCreatingBossLobby = false
    else
        warn("[Maki Boss Raid Host] ❌ Creation failed: " .. tostring(res))
        task.wait(2.0)
        isCreatingBossLobby = false
    end
end

local function triggerCarryStartBossRaid()
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        local bQ = pG:FindFirstChild("bossQueueGui")
        local sBtn = bQ and bQ:FindFirstChild("lobbyInfo") and bQ.lobbyInfo:FindFirstChild("startButton", true)
        if sBtn then
            pcall(function()
                for _, c in ipairs(getconnections(sBtn.Activated)) do c:Fire() end
                for _, c in ipairs(getconnections(sBtn.MouseButton1Click)) do c:Fire() end
            end)
        end
    end

    if startBossRaidRemote then pcall(function() startBossRaidRemote:FireServer() end) end
    if startDungeonRemote then pcall(function() startDungeonRemote:FireServer() end) end
    if changeStartValueRemote then pcall(function() changeStartValueRemote:FireServer() end) end
    executeInstantReadyUp()
end

-- ========================================================================
--  NEXT TIER / REPLAY ENGINE (INFINITE NON-STOP BOSS RAID FARM)
-- ========================================================================
local isProcessingReplay = false
local function isRaidFinished()
    local prog = getMatchProgress()
    if prog == "bosskilled" or prog == "victory" or prog == "complete" or prog == "dungeoncomplete" or prog:find("kill") or prog:find("won") or prog:find("win") then
        return true
    end

    local dungeon = Workspace:FindFirstChild("dungeon")
    local bossRoom = dungeon and (dungeon:FindFirstChild("bossRoom") or dungeon:FindFirstChild("room"))
    local finished = bossRoom and (bossRoom:FindFirstChild("dungeonFinished") or bossRoom:FindFirstChild("finished"))
    if finished and finished:IsA("BoolValue") and finished.Value == true then
        return true
    end

    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        for _, name in ipairs({"dungeonResultGui", "resultsGui", "raidCompleteGui", "completeGui", "dungeonEndGui", "gameEndGui", "ReplayDungeonButton"}) do
            local g = pG:FindFirstChild(name)
            if g and ((g:IsA("ScreenGui") and g.Enabled) or (g:IsA("GuiObject") and g.Visible)) then
                return true
            end
        end
    end

    return false
end

local function handleNextTierAndReplay()
    if isProcessingReplay then return end
    isProcessingReplay = true

    task.spawn(function()
        local curTier = getCurrentRaidTier()
        print(string.format("[Maki Replay] ⚡ Boss Defeated in Tier %d! Starting continuous Next Tier / Replay spam...", curTier))

        executeUniversalAutoSell()

        local startTime = os.clock()
        while _G.MAKI_BOSS_RAID_RUNNING and isRaidOrDungeon() and (os.clock() - startTime < 12.0) do
            -- 1. Upgrade Key / Next Tier if tier < 30
            if Config.AutoNextTier and curTier < 30 then
                if upgradeKeyRemote then
                    pcall(function() upgradeKeyRemote:FireServer() end)
                end

                local pG = LocalPlayer:FindFirstChild("PlayerGui")
                if pG then
                    for _, gui in ipairs(pG:GetChildren()) do
                        if gui:IsA("ScreenGui") and gui.Enabled then
                            for _, btn in ipairs(gui:GetDescendants()) do
                                if btn:IsA("GuiButton") then
                                    local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                                    local bName = btn.Name:lower()
                                    if bText:find("next") or bText:find("upgrade") or bName:find("nexttier") or bName:find("upgradetier") or bName:find("upgrade") then
                                        pcall(function()
                                            for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                                            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                                            for _, c in ipairs(getconnections(btn.MouseButton1Down)) do c:Fire() end
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- 2. Fire Replay Remote & Click Replay Buttons
            if replayRemote then
                pcall(function() replayRemote:FireServer() end)
                pcall(function() replayRemote:FireServer({ isHardcore = true, hardcore = true }) end)
            end

            local pG = LocalPlayer:FindFirstChild("PlayerGui")
            if pG then
                for _, gui in ipairs(pG:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled then
                        for _, btn in ipairs(gui:GetDescendants()) do
                            if btn:IsA("GuiButton") then
                                local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                                local bName = btn.Name:lower()
                                if bText:find("replay") or bText:find("retry") or bName:find("replay") or bName:find("retry") or bName:find("playagain") then
                                    pcall(function()
                                        for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                                        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                                        for _, c in ipairs(getconnections(btn.MouseButton1Down)) do c:Fire() end
                                    end)
                                end
                            end
                        end
                    end
                end
            end

            task.wait(0.35)
        end

        -- Failsafe: if still in finished raid after 12s, return to Main Lobby so carry re-hosts immediately
        if isRaidOrDungeon() and _G.MAKI_BOSS_RAID_RUNNING and isRaidFinished() then
            print("[Maki Replay] 🔄 Replay timed out after 12s, returning to Main Lobby to re-host...")
            if teleToLobbyRemote then pcall(function() teleToLobbyRemote:FireServer() end) end
            task.wait(0.5)
            pcall(function() TeleportService:Teleport(77649408247578, LocalPlayer) end)
        end

        isProcessingReplay = false
    end)
end

-- Alt Spawn Anchor & Safety
local altSpawnPosition = nil
local function lockAltSpawn()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart", 10)
    local hum  = char:WaitForChild("Humanoid", 10)
    if hrp and hum then
        local timeout = os.clock()
        while hum.FloorMaterial == Enum.Material.Air and (os.clock() - timeout) < 5.0 do task.wait(0.05) end
        task.wait(0.25)
        altSpawnPosition = hrp.Position
    end
end

LocalPlayer.Idled:Connect(function()
    if not isCarry and _G.MAKI_BOSS_RAID_RUNNING then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(100, 100))
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    if not isCarry and isRaidOrDungeon() and altSpawnPosition and _G.MAKI_BOSS_RAID_RUNNING then
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dist = (hrp.Position - altSpawnPosition).Magnitude
            if dist > 15.0 then
                hrp.CFrame = CFrame.new(altSpawnPosition)
            end
        end
    end
end)

-- Main Automation Loop
local isStagingStarted = false
local raidFinishedHandled = false

task.spawn(function()
    while _G.MAKI_BOSS_RAID_RUNNING do
        task.wait(0.5)
        if isRaidOrDungeon() then
            if isCarry and not isStagingStarted then
                local altsReady = areAllAltsPresent()
                if altsReady then
                    print("[Maki Boss Staging] 👥 100% of Alts loaded in Raid Room! Starting Boss Encounter & Readying Up...")
                    isStagingStarted = true
                    triggerCarryStartBossRaid()
                else
                    local count = 0
                    for _, altName in ipairs(Config.AltUsernames) do
                        if Players:FindFirstChild(altName) and Players[altName].Character then count = count + 1 end
                    end
                    print(string.format("[Maki Boss Staging ⏳] Waiting for Alts to load into Raid Room (%d/%d loaded)...", count, #Config.AltUsernames))
                end
            elseif not isCarry then
                if not altSpawnPosition then
                    lockAltSpawn()
                end
                executeInstantReadyUp()
            end

            if isRaidFinished() and not raidFinishedHandled then
                raidFinishedHandled = true
                if isCarry then
                    handleNextTierAndReplay()
                end
            end
        elseif isMainLobby() then
            isStagingStarted = false
            raidFinishedHandled = false
            altSpawnPosition = nil
            isProcessingReplay = false

            if isCarry and not isCreatingBossLobby then
                print("[Maki Boss Host] ⏳ Main Lobby arrived! Launching Boss Raid in 4s...")
                task.wait(4.0)
                if isMainLobby() and _G.MAKI_BOSS_RAID_RUNNING then
                    carryCreateAndLaunchBossRaid()
                end
            end
        end
    end
end)

-- ========================================================================
--  MULTI-TAB CONTROLLER GUI
-- ========================================================================
local oldGui = pGuiRef:FindFirstChild("Maki_MasterGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Maki_MasterGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = pGuiRef

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 290, 0, 280)
frame.Position = UDim2.new(0, 20, 0.5, -140)
frame.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

local stroke = Instance.new("UIStroke", frame)
stroke.Color = isCarry and Color3.fromRGB(255, 180, 0) or Color3.fromRGB(180, 120, 255)
stroke.Thickness = 1.5

local titleLbl = Instance.new("TextLabel", frame)
titleLbl.Size = UDim2.new(1, -16, 0, 20)
titleLbl.Position = UDim2.new(0, 8, 0, 4)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = isCarry and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(200, 160, 255)
titleLbl.TextSize = 10
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Text = isCarry and "👑 MAKI BOSS RAID CONTROLLER (V3.1)" or "🛡️ MAKI RAID PASSENGER (V3.1)"

local tabBar = Instance.new("Frame", frame)
tabBar.Size = UDim2.new(1, -16, 0, 22)
tabBar.Position = UDim2.new(0, 8, 0, 26)
tabBar.BackgroundTransparency = 1

local tabDashBtn = Instance.new("TextButton", tabBar)
tabDashBtn.Size = UDim2.new(0.33, -2, 1, 0)
tabDashBtn.Position = UDim2.new(0, 0, 0, 0)
tabDashBtn.BackgroundColor3 = Color3.fromRGB(200, 140, 0)
tabDashBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tabDashBtn.TextSize = 7.5
tabDashBtn.Font = Enum.Font.GothamBold
tabDashBtn.Text = "📊 DASHBOARD"
Instance.new("UICorner", tabDashBtn).CornerRadius = UDim.new(0, 4)

local tabAltsBtn = Instance.new("TextButton", tabBar)
tabAltsBtn.Size = UDim2.new(0.33, -2, 1, 0)
tabAltsBtn.Position = UDim2.new(0.33, 2, 0, 0)
tabAltsBtn.BackgroundColor3 = Color3.fromRGB(35, 42, 60)
tabAltsBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
tabAltsBtn.TextSize = 7.5
tabAltsBtn.Font = Enum.Font.GothamBold
tabAltsBtn.Text = string.format("👥 ALTS (%d)", #Config.AltUsernames)
Instance.new("UICorner", tabAltsBtn).CornerRadius = UDim.new(0, 4)

local tabDiscordBtn = Instance.new("TextButton", tabBar)
tabDiscordBtn.Size = UDim2.new(0.34, -2, 1, 0)
tabDiscordBtn.Position = UDim2.new(0.66, 4, 0, 0)
tabDiscordBtn.BackgroundColor3 = Color3.fromRGB(35, 42, 60)
tabDiscordBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
tabDiscordBtn.TextSize = 7.5
tabDiscordBtn.Font = Enum.Font.GothamBold
tabDiscordBtn.Text = "💬 DISCORD"
Instance.new("UICorner", tabDiscordBtn).CornerRadius = UDim.new(0, 4)

local pageDashboard = Instance.new("Frame", frame)
pageDashboard.Size = UDim2.new(1, -16, 0, 222)
pageDashboard.Position = UDim2.new(0, 8, 0, 52)
pageDashboard.BackgroundTransparency = 1
pageDashboard.Visible = true

local pageAlts = Instance.new("Frame", frame)
pageAlts.Size = UDim2.new(1, -16, 0, 222)
pageAlts.Position = UDim2.new(0, 8, 0, 52)
pageAlts.BackgroundTransparency = 1
pageAlts.Visible = false

local pageDiscord = Instance.new("Frame", frame)
pageDiscord.Size = UDim2.new(1, -16, 0, 222)
pageDiscord.Position = UDim2.new(0, 8, 0, 52)
pageDiscord.BackgroundTransparency = 1
pageDiscord.Visible = false

local function setTab(tab)
    pageDashboard.Visible = (tab == "dash")
    pageAlts.Visible = (tab == "alts")
    pageDiscord.Visible = (tab == "discord")

    tabDashBtn.BackgroundColor3 = (tab == "dash") and Color3.fromRGB(200, 140, 0) or Color3.fromRGB(35, 42, 60)
    tabDashBtn.TextColor3 = (tab == "dash") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 190, 210)

    tabAltsBtn.BackgroundColor3 = (tab == "alts") and Color3.fromRGB(140, 80, 220) or Color3.fromRGB(35, 42, 60)
    tabAltsBtn.TextColor3 = (tab == "alts") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 190, 210)

    tabDiscordBtn.BackgroundColor3 = (tab == "discord") and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(35, 42, 60)
    tabDiscordBtn.TextColor3 = (tab == "discord") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 190, 210)
end

tabDashBtn.Activated:Connect(function() setTab("dash") end)
tabAltsBtn.Activated:Connect(function() setTab("alts") end)
tabDiscordBtn.Activated:Connect(function() setTab("discord") end)

local statsBox = Instance.new("Frame", pageDashboard)
statsBox.Size = UDim2.new(1, 0, 0, 96)
statsBox.Position = UDim2.new(0, 0, 0, 0)
statsBox.BackgroundColor3 = Color3.fromRGB(10, 13, 22)
Instance.new("UICorner", statsBox).CornerRadius = UDim.new(0, 4)

local statusLbl = Instance.new("TextLabel", statsBox)
statusLbl.Size = UDim2.new(1, -10, 0, 14)
statusLbl.Position = UDim2.new(0, 6, 0, 2)
statusLbl.BackgroundTransparency = 1
statusLbl.TextColor3 = Color3.fromRGB(100, 255, 180)
statusLbl.TextSize = 8
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Text = "● STATUS: 🟢 ACTIVE (BOSS RAID)"

local tierInfoLbl = Instance.new("TextLabel", statsBox)
tierInfoLbl.Size = UDim2.new(1, -10, 0, 14)
tierInfoLbl.Position = UDim2.new(0, 6, 0, 18)
tierInfoLbl.BackgroundTransparency = 1
tierInfoLbl.TextColor3 = Color3.fromRGB(255, 200, 50)
tierInfoLbl.TextSize = 7.5
tierInfoLbl.Font = Enum.Font.GothamBold
tierInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
tierInfoLbl.Text = "👑 Boss Raid: Scanning..."

local maxTierLbl = Instance.new("TextLabel", statsBox)
maxTierLbl.Size = UDim2.new(1, -10, 0, 14)
maxTierLbl.Position = UDim2.new(0, 6, 0, 34)
maxTierLbl.BackgroundTransparency = 1
maxTierLbl.TextColor3 = Color3.fromRGB(120, 220, 255)
maxTierLbl.TextSize = 7.5
maxTierLbl.Font = Enum.Font.Gotham
maxTierLbl.TextXAlignment = Enum.TextXAlignment.Left
maxTierLbl.Text = "🔑 Unlocked Max Tier: Checking..."

local nextTierLbl = Instance.new("TextLabel", statsBox)
nextTierLbl.Size = UDim2.new(1, -10, 0, 14)
nextTierLbl.Position = UDim2.new(0, 6, 0, 50)
nextTierLbl.BackgroundTransparency = 1
nextTierLbl.TextColor3 = Color3.fromRGB(180, 200, 240)
nextTierLbl.TextSize = 7.5
nextTierLbl.Font = Enum.Font.Gotham
nextTierLbl.TextXAlignment = Enum.TextXAlignment.Left
nextTierLbl.Text = "⚡ Next Tier Auto-Upgrade: ON"

local autoAcceptLbl = Instance.new("TextLabel", statsBox)
autoAcceptLbl.Size = UDim2.new(1, -10, 0, 14)
autoAcceptLbl.Position = UDim2.new(0, 6, 0, 66)
autoAcceptLbl.BackgroundTransparency = 1
autoAcceptLbl.TextColor3 = Color3.fromRGB(255, 215, 80)
autoAcceptLbl.TextSize = 7.5
autoAcceptLbl.Font = Enum.Font.GothamBold
autoAcceptLbl.TextXAlignment = Enum.TextXAlignment.Left
autoAcceptLbl.Text = "⚡ Universal Ready-Up: 0ms (All Accounts)"

local potatoToggleBtn = Instance.new("TextButton", pageDashboard)
potatoToggleBtn.Size = UDim2.new(1, 0, 0, 22)
potatoToggleBtn.Position = UDim2.new(0, 0, 0, 102)
potatoToggleBtn.BackgroundColor3 = Config.UltraPotatoGraphics and Color3.fromRGB(180, 90, 20) or Color3.fromRGB(60, 60, 60)
potatoToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
potatoToggleBtn.TextSize = 7.5
potatoToggleBtn.Font = Enum.Font.GothamBold
potatoToggleBtn.Text = Config.UltraPotatoGraphics and "🥔 ULTRA-POTATO GRAPHICS: ON (55 FPS Main / 12 FPS Alts)" or "🥔 ULTRA-POTATO GRAPHICS: OFF"
Instance.new("UICorner", potatoToggleBtn).CornerRadius = UDim.new(0, 4)

potatoToggleBtn.Activated:Connect(function()
    Config.UltraPotatoGraphics = not Config.UltraPotatoGraphics
    potatoToggleBtn.Text = Config.UltraPotatoGraphics and "🥔 ULTRA-POTATO GRAPHICS: ON (55 FPS Main / 12 FPS Alts)" or "🥔 ULTRA-POTATO GRAPHICS: OFF"
    potatoToggleBtn.BackgroundColor3 = Config.UltraPotatoGraphics and Color3.fromRGB(180, 90, 20) or Color3.fromRGB(60, 60, 60)
    saveConfig()
    applyUltraPotatoGraphics()
end)

local nextTierToggleBtn = Instance.new("TextButton", pageDashboard)
nextTierToggleBtn.Size = UDim2.new(1, 0, 0, 22)
nextTierToggleBtn.Position = UDim2.new(0, 0, 0, 128)
nextTierToggleBtn.BackgroundColor3 = Config.AutoNextTier and Color3.fromRGB(160, 100, 20) or Color3.fromRGB(60, 60, 60)
nextTierToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
nextTierToggleBtn.TextSize = 7.5
nextTierToggleBtn.Font = Enum.Font.GothamBold
nextTierToggleBtn.Text = Config.AutoNextTier and "🌟 AUTO-NEXT TIER / REPLAY: ON" or "🌟 AUTO-NEXT TIER / REPLAY: OFF"
Instance.new("UICorner", nextTierToggleBtn).CornerRadius = UDim.new(0, 4)

nextTierToggleBtn.Activated:Connect(function()
    Config.AutoNextTier = not Config.AutoNextTier
    nextTierToggleBtn.Text = Config.AutoNextTier and "🌟 AUTO-NEXT TIER / REPLAY: ON" or "🌟 AUTO-NEXT TIER / REPLAY: OFF"
    nextTierToggleBtn.BackgroundColor3 = Config.AutoNextTier and Color3.fromRGB(160, 100, 20) or Color3.fromRGB(60, 60, 60)
    saveConfig()
end)

local autoSellToggleBtn = Instance.new("TextButton", pageDashboard)
autoSellToggleBtn.Size = UDim2.new(1, 0, 0, 22)
autoSellToggleBtn.Position = UDim2.new(0, 0, 0, 154)
autoSellToggleBtn.BackgroundColor3 = Config.AutoSellTrashes and Color3.fromRGB(30, 120, 60) or Color3.fromRGB(60, 60, 60)
autoSellToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoSellToggleBtn.TextSize = 7.5
autoSellToggleBtn.Font = Enum.Font.GothamBold
autoSellToggleBtn.Text = Config.AutoSellTrashes and "💰 AUTO-SELL TRASHES: ON (Collects Safe)" or "💰 AUTO-SELL TRASHES: OFF"
Instance.new("UICorner", autoSellToggleBtn).CornerRadius = UDim.new(0, 4)

autoSellToggleBtn.Activated:Connect(function()
    Config.AutoSellTrashes = not Config.AutoSellTrashes
    autoSellToggleBtn.Text = Config.AutoSellTrashes and "💰 AUTO-SELL TRASHES: ON (Collects Safe)" or "💰 AUTO-SELL TRASHES: OFF"
    autoSellToggleBtn.BackgroundColor3 = Config.AutoSellTrashes and Color3.fromRGB(30, 120, 60) or Color3.fromRGB(60, 60, 60)
    saveConfig()
end)

local mainActionBtn = Instance.new("TextButton", pageDashboard)
mainActionBtn.Size = UDim2.new(1, 0, 0, 26)
mainActionBtn.Position = UDim2.new(0, 0, 0, 180)
mainActionBtn.BackgroundColor3 = isCarry and Color3.fromRGB(200, 120, 0) or Color3.fromRGB(140, 80, 220)
mainActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
mainActionBtn.TextSize = 8.5
mainActionBtn.Font = Enum.Font.GothamBold
mainActionBtn.Text = isCarry and "👑 LAUNCH MAX TIER RAID" or "🛡️ ALT STANDBY (Auto-Sync Active)"
Instance.new("UICorner", mainActionBtn).CornerRadius = UDim.new(0, 4)

mainActionBtn.Activated:Connect(function()
    if isCarry and isMainLobby() then
        carryCreateAndLaunchBossRaid()
    end
end)

-- Discord Tab
local dcTitle = Instance.new("TextLabel", pageDiscord)
dcTitle.Size = UDim2.new(1, 0, 0, 16)
dcTitle.Position = UDim2.new(0, 0, 0, 0)
dcTitle.BackgroundTransparency = 1
dcTitle.TextColor3 = Color3.fromRGB(180, 200, 255)
dcTitle.TextSize = 8.5
dcTitle.Font = Enum.Font.GothamBold
dcTitle.TextXAlignment = Enum.TextXAlignment.Left
dcTitle.Text = "🔗 Discord Webhook URL:"

local dcInput = Instance.new("TextBox", pageDiscord)
dcInput.Size = UDim2.new(1, 0, 0, 26)
dcInput.Position = UDim2.new(0, 0, 0, 20)
dcInput.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
dcInput.TextColor3 = Color3.fromRGB(255, 255, 255)
dcInput.TextSize = 7.5
dcInput.Font = Enum.Font.Gotham
dcInput.PlaceholderText = "Paste Discord Webhook URL here..."
dcInput.Text = Config.DiscordWebhookUrl or ""
Instance.new("UICorner", dcInput).CornerRadius = UDim.new(0, 4)

dcInput.FocusLost:Connect(function()
    Config.DiscordWebhookUrl = dcInput.Text:gsub("%s+", "")
    saveConfig()
end)

local dcSaveBtn = Instance.new("TextButton", pageDiscord)
dcSaveBtn.Size = UDim2.new(0.48, -2, 0, 24)
dcSaveBtn.Position = UDim2.new(0, 0, 0, 52)
dcSaveBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
dcSaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dcSaveBtn.TextSize = 8
dcSaveBtn.Font = Enum.Font.GothamBold
dcSaveBtn.Text = "💾 SAVE WEBHOOK"
Instance.new("UICorner", dcSaveBtn).CornerRadius = UDim.new(0, 4)

dcSaveBtn.Activated:Connect(function()
    Config.DiscordWebhookUrl = dcInput.Text:gsub("%s+", "")
    saveConfig()
    dcSaveBtn.Text = "✅ SAVED!"
    task.wait(1.0)
    dcSaveBtn.Text = "💾 SAVE WEBHOOK"
end)

local dcTestBtn = Instance.new("TextButton", pageDiscord)
dcTestBtn.Size = UDim2.new(0.48, -2, 0, 24)
dcTestBtn.Position = UDim2.new(0.52, 2, 0, 52)
dcTestBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
dcTestBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dcTestBtn.TextSize = 8
dcTestBtn.Font = Enum.Font.GothamBold
dcTestBtn.Text = "🔔 TEST WEBHOOK"
Instance.new("UICorner", dcTestBtn).CornerRadius = UDim.new(0, 4)

dcTestBtn.Activated:Connect(function()
    Config.DiscordWebhookUrl = dcInput.Text:gsub("%s+", "")
    saveConfig()
    sendDropNotification(LocalPlayer.Name, "Valhalla Greatsword [TEST]", "epic", "Weapon", "Tier 30")
    dcTestBtn.Text = "📨 SENT!"
    task.wait(1.0)
    dcTestBtn.Text = "🔔 TEST WEBHOOK"
end)

local toggleLegendaryBtn = Instance.new("TextButton", pageDiscord)
toggleLegendaryBtn.Size = UDim2.new(1, 0, 0, 24)
toggleLegendaryBtn.Position = UDim2.new(0, 0, 0, 84)
toggleLegendaryBtn.BackgroundColor3 = Config.NotifyLegendary and Color3.fromRGB(180, 130, 20) or Color3.fromRGB(50, 50, 50)
toggleLegendaryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleLegendaryBtn.TextSize = 8
toggleLegendaryBtn.Font = Enum.Font.GothamBold
toggleLegendaryBtn.Text = Config.NotifyLegendary and "🌟 NOTIFY LEGENDARY DROPS: ON" or "🌟 NOTIFY LEGENDARY DROPS: OFF"
Instance.new("UICorner", toggleLegendaryBtn).CornerRadius = UDim.new(0, 4)

toggleLegendaryBtn.Activated:Connect(function()
    Config.NotifyLegendary = not Config.NotifyLegendary
    toggleLegendaryBtn.Text = Config.NotifyLegendary and "🌟 NOTIFY LEGENDARY DROPS: ON" or "🌟 NOTIFY LEGENDARY DROPS: OFF"
    toggleLegendaryBtn.BackgroundColor3 = Config.NotifyLegendary and Color3.fromRGB(180, 130, 20) or Color3.fromRGB(50, 50, 50)
    saveConfig()
end)

local toggleCollectBtn = Instance.new("TextButton", pageDiscord)
toggleCollectBtn.Size = UDim2.new(1, 0, 0, 24)
toggleCollectBtn.Position = UDim2.new(0, 0, 0, 114)
toggleCollectBtn.BackgroundColor3 = Config.NotifyCollects and Color3.fromRGB(120, 50, 180) or Color3.fromRGB(50, 50, 50)
toggleCollectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleCollectBtn.TextSize = 8
toggleCollectBtn.Font = Enum.Font.GothamBold
toggleCollectBtn.Text = Config.NotifyCollects and "💜 NOTIFY PURPLE COLLECTS (11 Types): ON" or "💜 NOTIFY PURPLE COLLECTS: OFF"
Instance.new("UICorner", toggleCollectBtn).CornerRadius = UDim.new(0, 4)

toggleCollectBtn.Activated:Connect(function()
    Config.NotifyCollects = not Config.NotifyCollects
    toggleCollectBtn.Text = Config.NotifyCollects and "💜 NOTIFY PURPLE COLLECTS (11 Types): ON" or "💜 NOTIFY PURPLE COLLECTS: OFF"
    toggleCollectBtn.BackgroundColor3 = Config.NotifyCollects and Color3.fromRGB(120, 50, 180) or Color3.fromRGB(50, 50, 50)
    saveConfig()
end)

-- Alts Tab
local carryInput = Instance.new("TextBox", pageAlts)
carryInput.Size = UDim2.new(0.68, -4, 0, 24)
carryInput.Position = UDim2.new(0, 0, 0, 0)
carryInput.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
carryInput.TextColor3 = Color3.fromRGB(255, 255, 255)
carryInput.TextSize = 8.5
carryInput.Font = Enum.Font.Gotham
carryInput.PlaceholderText = "👑 Enter Main/Carry Username..."
carryInput.Text = Config.CarryUsername or ""
carryInput.ClearTextOnFocus = false
Instance.new("UICorner", carryInput).CornerRadius = UDim.new(0, 4)

local carrySaveBtn = Instance.new("TextButton", pageAlts)
carrySaveBtn.Size = UDim2.new(0.32, 0, 0, 24)
carrySaveBtn.Position = UDim2.new(0.68, 4, 0, 0)
carrySaveBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
carrySaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
carrySaveBtn.TextSize = 8.5
carrySaveBtn.Font = Enum.Font.GothamBold
carrySaveBtn.Text = "💾 SET MAIN"
Instance.new("UICorner", carrySaveBtn).CornerRadius = UDim.new(0, 4)

local function applyCarryUsername(name)
    local clean = (name or ""):gsub("%s+", "")
    Config.CarryUsername = clean
    saveConfig()
    updateCarryRole()
    carryInput.Text = Config.CarryUsername
    mainActionBtn.BackgroundColor3 = isCarry and Color3.fromRGB(200, 120, 0) or Color3.fromRGB(140, 80, 220)
    mainActionBtn.Text = isCarry and "👑 LAUNCH MAX TIER RAID" or "🛡️ ALT STANDBY (Auto-Sync Active)"
    titleLbl.Text = isCarry and "👑 MAKI BOSS RAID CONTROLLER (V3.1)" or "🛡️ MAKI RAID PASSENGER (V3.1)"
    titleLbl.TextColor3 = isCarry and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(200, 160, 255)
    stroke.Color = isCarry and Color3.fromRGB(255, 180, 0) or Color3.fromRGB(180, 120, 255)
    carrySaveBtn.Text = "✅ SAVED!"
    print(string.format("[Maki Config 💾] Saved Main Username: '%s'", Config.CarryUsername))
    task.delay(1.0, function() carrySaveBtn.Text = "💾 SET MAIN" end)
end

carrySaveBtn.MouseButton1Click:Connect(function() applyCarryUsername(carryInput.Text) end)
carrySaveBtn.Activated:Connect(function() applyCarryUsername(carryInput.Text) end)
carryInput.FocusLost:Connect(function() applyCarryUsername(carryInput.Text) end)

local altInput = Instance.new("TextBox", pageAlts)
altInput.Size = UDim2.new(0.68, -4, 0, 24)
altInput.Position = UDim2.new(0, 0, 0, 28)
altInput.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
altInput.TextColor3 = Color3.fromRGB(255, 255, 255)
altInput.TextSize = 8.5
altInput.Font = Enum.Font.Gotham
altInput.PlaceholderText = "👥 Enter Alt Username..."
altInput.ClearTextOnFocus = false
Instance.new("UICorner", altInput).CornerRadius = UDim.new(0, 4)

local addAltBtn = Instance.new("TextButton", pageAlts)
addAltBtn.Size = UDim2.new(0.32, 0, 0, 24)
addAltBtn.Position = UDim2.new(0.68, 4, 0, 28)
addAltBtn.BackgroundColor3 = Color3.fromRGB(30, 140, 80)
addAltBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
addAltBtn.TextSize = 8.5
addAltBtn.Font = Enum.Font.GothamBold
addAltBtn.Text = "➕ ADD ALT"
Instance.new("UICorner", addAltBtn).CornerRadius = UDim.new(0, 4)

local altsScroll = Instance.new("ScrollingFrame", pageAlts)
altsScroll.Size = UDim2.new(1, 0, 0, 162)
altsScroll.Position = UDim2.new(0, 0, 0, 56)
altsScroll.BackgroundColor3 = Color3.fromRGB(10, 13, 22)
altsScroll.ScrollBarThickness = 3
Instance.new("UICorner", altsScroll).CornerRadius = UDim.new(0, 4)

local altsListLayout = Instance.new("UIListLayout", altsScroll)
altsListLayout.Padding = UDim.new(0, 4)

local function refreshAltsUI()
    tabAltsBtn.Text = string.format("👥 ALTS (%d)", #Config.AltUsernames)
    for _, child in ipairs(altsScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    if #Config.AltUsernames == 0 then
        local emptyLbl = Instance.new("TextLabel", altsScroll)
        emptyLbl.Name = "EmptyNotice"
        emptyLbl.Size = UDim2.new(1, 0, 0, 40)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.TextColor3 = Color3.fromRGB(140, 150, 170)
        emptyLbl.TextSize = 8
        emptyLbl.Font = Enum.Font.Gotham
        emptyLbl.Text = "No alts added yet.\nEnter username above to add."
        return
    end

    for idx, altName in ipairs(Config.AltUsernames) do
        local p = Players:FindFirstChild(altName)
        local isOnline = (p ~= nil)
        local statusStr = isOnline and "🟢 In Server" or "⚪ In Lobby / Offline"

        local row = Instance.new("Frame", altsScroll)
        row.Size = UDim2.new(1, -6, 0, 30)
        row.BackgroundColor3 = Color3.fromRGB(20, 26, 42)
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

        local dot = Instance.new("Frame", row)
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.Position = UDim2.new(0, 6, 0.5, -3)
        dot.BackgroundColor3 = isOnline and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(140, 140, 140)
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local nameLbl = Instance.new("TextLabel", row)
        nameLbl.Size = UDim2.new(0.6, -16, 0, 14)
        nameLbl.Position = UDim2.new(0, 16, 0, 2)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLbl.TextSize = 8.5
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Text = altName

        local statusSubLbl = Instance.new("TextLabel", row)
        statusSubLbl.Size = UDim2.new(0.6, -16, 0, 12)
        statusSubLbl.Position = UDim2.new(0, 16, 0, 16)
        statusSubLbl.BackgroundTransparency = 1
        statusSubLbl.TextColor3 = isOnline and Color3.fromRGB(100, 220, 160) or Color3.fromRGB(130, 140, 160)
        statusSubLbl.TextSize = 7
        statusSubLbl.Font = Enum.Font.Gotham
        statusSubLbl.TextXAlignment = Enum.TextXAlignment.Left
        statusSubLbl.Text = statusStr

        local removeBtn = Instance.new("TextButton", row)
        removeBtn.Size = UDim2.new(0, 22, 0, 20)
        removeBtn.Position = UDim2.new(1, -26, 0.5, -10)
        removeBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
        removeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        removeBtn.TextSize = 8.5
        removeBtn.Font = Enum.Font.GothamBold
        removeBtn.Text = "❌"
        Instance.new("UICorner", removeBtn).CornerRadius = UDim.new(0, 3)

        removeBtn.Activated:Connect(function()
            table.remove(Config.AltUsernames, idx)
            saveConfig()
            refreshAltsUI()
        end)
    end
    altsScroll.CanvasSize = UDim2.new(0, 0, 0, #Config.AltUsernames * 34)
end

local function handleAddAlt()
    local text = (altInput.Text or ""):gsub("%s+", "")
    if #text > 0 then
        local exists = false
        for _, ex in ipairs(Config.AltUsernames) do
            if ex:lower() == text:lower() then exists = true break end
        end
        if not exists then
            table.insert(Config.AltUsernames, text)
            saveConfig()
            print(string.format("[Maki Config 💾] Added Alt: '%s' (Total: %d)", text, #Config.AltUsernames))
        end
        altInput.Text = ""
        refreshAltsUI()
    end
end

addAltBtn.MouseButton1Click:Connect(handleAddAlt)
addAltBtn.Activated:Connect(handleAddAlt)
altInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        handleAddAlt()
    end
end)

refreshAltsUI()

task.spawn(function()
    while _G.MAKI_BOSS_RAID_RUNNING do
        task.wait(3.0)
        pcall(refreshAltsUI)
    end
end)

task.spawn(function()
    while _G.MAKI_BOSS_RAID_RUNNING do
        task.wait(0.5)
        local maxTier = getHighestUnlockedTier()
        local curTier = getCurrentRaidTier()

        if isMainLobby() then
            tierInfoLbl.Text = "🏰 Location: Main Lobby"
            maxTierLbl.Text = string.format("🔑 Max Unlocked: Tier %d", maxTier)
            nextTierLbl.Text = string.format("🎯 Target Launch: Tier %d (Private)", maxTier)
        else
            tierInfoLbl.Text = string.format("👑 Active Raid: Tier %d", curTier)
            maxTierLbl.Text = string.format("🔑 Max Unlocked: Tier %d", maxTier)
            nextTierLbl.Text = (curTier < 30) and "🌟 Auto-Upgrade: Next Tier" or "🔄 Auto-Loop: Tier 30 (Max)"
        end
    end
end)

print("[Project Maki V3.1] 👑 Boss Raid Controller (40 Speed + Auto-Ready + Boss Homing) Loaded!")
