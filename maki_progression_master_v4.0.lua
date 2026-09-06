-- ========================================================================
--  PROJECT MAKI: MASTER PROGRESSION & CARRY/ALT SUITE (VERSION 4.0)
--  COMPLETE INTEGRATION: LEVELS 60-130 + 130-144 + 145-155+ + 160-165+ (AQUATIC)
-- ========================================================================
--  STATUS: 100% UNTRUNCATED FULL MONOLITHIC CODEBASE
--  FIXED:
--    • Direct In-Game Dungeon Engine Routing (getCurrentDungeonEngine)
--      (Carry immediately runs Aquatic Temple MHC highway with or without alts)
--    • Staircase Elevation Calibration for Aquatic Temple (dy > 12s -> 50s AoE Lock)
--    • Instant Hardcore Defeat Auto-Retry (Zero Lobby Reloads)
--    • Human-Like Alt Micro-Wander & Anti-Bot Jitter Engine
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
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Prevent duplicate instances
if _G.MAKI_MASTER_SUITE_RUNNING then
    _G.MAKI_MASTER_SUITE_RUNNING = false
    task.wait(0.2)
end
_G.MAKI_MASTER_SUITE_RUNNING = true

local getGuiParent = function()
    if typeof(gethui) == "function" then
        return gethui()
    elseif CoreGui then
        return CoreGui
    else
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

-- ========================================================================
--  REMOTES & NETWORKING
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
local replayRemote               = remotes and remotes:FindFirstChild("replayDungeon")
local sellItemEventRemote        = remotes and remotes:FindFirstChild("sellItemEvent")
local reloadInvyRemote           = remotes and remotes:FindFirstChild("reloadInvy")
local abilityUsedRemote          = remotes and remotes:FindFirstChild("abilityUsed")
local abilityCastRemote          = remotes and remotes:FindFirstChild("abilityCast")
local weaponUsedRemote           = remotes and remotes:FindFirstChild("weaponUsed")
local teleToLobbyRemote          = remotes and (remotes:FindFirstChild("teleToLobby") or remotes:FindFirstChild("ReturnToLobbyEvent") or remotes:FindFirstChild("leaveGame"))
local announceDropRemote         = remotes and remotes:FindFirstChild("AnnounceDrop")

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
    CurrentDungeon      = "Pirate Island",
    CurrentDiff         = "Insane",
    SelectedDungeon     = "Pirate Island",
    SelectedDiff        = "Insane",
    HardcoreMode        = true,
    AutoAcceptJoins     = true,
    AutoProgression     = true,
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
    if isfile and isfile(ConfigFileName) then
        local ok, parsed = pcall(function() return HttpService:JSONDecode(readfile(ConfigFileName)) end)
        if ok and type(parsed) == "table" then
            for k, v in pairs(parsed) do Config[k] = v end
        end
    end
    if not Config.CarryUsername then Config.CarryUsername = "" end
    if not Config.AltLevels then Config.AltLevels = {} end
    if not Config.AltUsernames then Config.AltUsernames = {} end
    if not Config.CurrentDungeon then Config.CurrentDungeon = "Pirate Island" end
    if not Config.CurrentDiff then Config.CurrentDiff = "Insane" end
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
    if writefile then
        pcall(function() writefile(ConfigFileName, HttpService:JSONEncode(Config)) end)
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

-- ========================================================================
--  [MODULE 6] ULTRA-POTATO GRAPHICS & CPU SAVER ENGINE
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
    while _G.MAKI_MASTER_SUITE_RUNNING do
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
            username = "Maki Loot Notifier 🌸",
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

local function sendDropNotification(playerName, itemName, rarity, category, dungeonName, diffTier)
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
            { name = "🏰 Dungeon & Tier", value = string.format("%s (%s)", dungeonName or Config.CurrentDungeon or "Unknown", diffTier or Config.CurrentDiff or "Normal"), inline = true },
            { name = "🔒 Inventory Status", value = "🛡️ **100% PROTECTED & KEPT IN INVENTORY**", inline = false }
        },
        footer = { text = "Project Maki • Multi-Account Speedrun Controller" },
        timestamp = DateTime.now():ToIsoDate()
    }

    sendDiscordWebhook(embed)
    print(string.format("[Maki Loot 📢] %s dropped %s (%s) ➔ Sent to Discord!", playerName, itemName, rarity))
end

-- ========================================================================
--  AUTHORITATIVE LOCATION & DUNGEON SLUG DETECTOR
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

local function isDungeon()
    return not isMainLobby()
end

local function getDungeonProgress()
    local dProg = Workspace:FindFirstChild("dungeonProgress")
    return (dProg and dProg:IsA("StringValue")) and dProg.Value:lower() or "active"
end

local function getDungeonSlug()
    local dNameVal = Workspace:FindFirstChild("dungeonName") or (Workspace:FindFirstChild("dungeon") and Workspace.dungeon:FindFirstChild("dungeonName"))
    local rawName = (dNameVal and dNameVal:IsA("StringValue") and dNameVal.Value ~= "") and dNameVal.Value or (Config.CurrentDungeon or "pirate_island")
    local slug = rawName:lower():gsub("[^%w%s]", ""):gsub("%s+", "_")
    return slug, rawName
end

local function isClientStuckInLoading()
    if isMainLobby() then
        return false
    end

    local dObj  = Workspace:FindFirstChild("dungeon")
    local dName = Workspace:FindFirstChild("dungeonName")
    local char  = LocalPlayer.Character
    local hrp   = char and char:FindFirstChild("HumanoidRootPart")

    if dObj and dName and hrp then
        return false
    end

    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        for _, name in ipairs({"loadingGui", "teleportGui", "transitionGui", "blackScreen", "loadingScreen"}) do
            local g = pG:FindFirstChild(name)
            if g and ((g:IsA("ScreenGui") and g.Enabled) or (g:IsA("GuiObject") and g.Visible)) then
                return true
            end
        end
    end

    if not dObj and not hrp then
        return true
    end

    return false
end

-- ========================================================================
--  [MODULE 0] 20-SECOND LOADING SCREEN HANG WATCHDOG
-- ========================================================================
local stuckLoadingSeconds = 0
task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(1.0)
        if isClientStuckInLoading() then
            stuckLoadingSeconds = stuckLoadingSeconds + 1
            if stuckLoadingSeconds % 5 == 0 then
                print(string.format("[Maki Watchdog ⏳] Loading screen detected... (%d/20s)", stuckLoadingSeconds))
            end
            if stuckLoadingSeconds >= 20 then
                warn("[Maki Watchdog 🚨] Stuck on loading screen for 20s! Force-teleporting to Main Lobby...")
                stuckLoadingSeconds = 0

                if teleToLobbyRemote then pcall(function() teleToLobbyRemote:FireServer() end) end

                local pG = LocalPlayer:FindFirstChild("PlayerGui")
                local rBtn = pG and pG:FindFirstChild("ReturnToLobbyButton", true)
                if rBtn then
                    pcall(function()
                        for _, c in ipairs(getconnections(rBtn.Activated)) do c:Fire() end
                        for _, c in ipairs(getconnections(rBtn.MouseButton1Click)) do c:Fire() end
                    end)
                end

                task.wait(0.5)
                pcall(function() TeleportService:Teleport(77649408247578, LocalPlayer) end)
            end
        else
            stuckLoadingSeconds = 0
        end
    end
end)

-- ========================================================================
--  [MODULE 5] OFFICIAL PROGRESSION LADDER (LEVELS 60 - 165+)
-- ========================================================================
local ProgressionLadder = {
    { dungeon = "Pirate Island",    diff = "Insane",    req = 60,  slug = "pirate_island",    engine = "waypoint" },
    { dungeon = "Pirate Island",    diff = "Nightmare", req = 65,  slug = "pirate_island",    engine = "waypoint" },
    { dungeon = "King's Castle",    diff = "Insane",    req = 70,  slug = "kings_castle",     engine = "waypoint" },
    { dungeon = "King's Castle",    diff = "Nightmare", req = 75,  slug = "kings_castle",     engine = "waypoint" },
    { dungeon = "The Underworld",   diff = "Insane",    req = 80,  slug = "the_underworld",   engine = "waypoint" },
    { dungeon = "The Underworld",   diff = "Nightmare", req = 85,  slug = "the_underworld",   engine = "waypoint" },
    { dungeon = "Samurai Palace",   diff = "Insane",    req = 90,  slug = "samurai_palace",   engine = "waypoint" },
    { dungeon = "Samurai Palace",   diff = "Nightmare", req = 95,  slug = "samurai_palace",   engine = "waypoint" },
    { dungeon = "The Canals",       diff = "Insane",    req = 100, slug = "the_canals",       engine = "waypoint" },
    { dungeon = "The Canals",       diff = "Nightmare", req = 105, slug = "the_canals",       engine = "waypoint" },
    { dungeon = "Ghastly Harbor",   diff = "Insane",    req = 110, slug = "ghastly_harbor",   engine = "waypoint" },
    { dungeon = "Ghastly Harbor",   diff = "Nightmare", req = 115, slug = "ghastly_harbor",   engine = "waypoint" },
    { dungeon = "Steampunk Sewers", diff = "Insane",    req = 120, slug = "steampunk_sewers", engine = "waypoint" },
    { dungeon = "Steampunk Sewers", diff = "Nightmare", req = 125, slug = "steampunk_sewers", engine = "waypoint" },
    { dungeon = "Boss Raids",       diff = "Tier 30",   req = 130, slug = "boss_raid",        engine = "bossraid" },
    { dungeon = "Orbital Outpost",  diff = "Nightmare", req = 145, slug = "orbital_outpost",  engine = "mhc" },
    { dungeon = "Volcanic Chambers",diff = "Insane",    req = 150, slug = "volcanic_chambers",engine = "mhc" },
    { dungeon = "Volcanic Chambers",diff = "Nightmare", req = 155, slug = "volcanic_chambers",engine = "mhc" },
    { dungeon = "Aquatic Temple",   diff = "Nightmare", req = 165, slug = "aquatic_temple",    engine = "mhc" },
}

local function getLivePlayerLevel(playerName)
    if not playerName or #playerName == 0 then return nil end
    local pG = LocalPlayer:FindFirstChild("PlayerGui")

    local statusFrame = pG and pG:FindFirstChild("playerStatus")
    local tHolder = statusFrame and statusFrame:FindFirstChild("teammateHolder", true)
    local pCard = tHolder and tHolder:FindFirstChild(playerName)
    local lvlLbl = pCard and pCard:FindFirstChild("level", true)
    if lvlLbl and tonumber(lvlLbl.Text) and tonumber(lvlLbl.Text) > 0 then
        local lvl = tonumber(lvlLbl.Text)
        Config.AltLevels[playerName] = lvl
        return lvl
    end

    local lb = pG and pG:FindFirstChild("leaderboard")
    local lbCard = lb and lb:FindFirstChild(playerName, true)
    local lbLvl = lbCard and lbCard:FindFirstChild("level", true)
    if lbLvl and tonumber(lbLvl.Text) and tonumber(lbLvl.Text) > 0 then
        local lvl = tonumber(lbLvl.Text)
        Config.AltLevels[playerName] = lvl
        return lvl
    end

    local p = Players:FindFirstChild(playerName)
    if p then
        local ls = p:FindFirstChild("leaderstats")
        local lVal = ls and (ls:FindFirstChild("Level") or ls:FindFirstChild("level"))
        if lVal and tonumber(lVal.Value) and tonumber(lVal.Value) > 0 then
            local lvl = tonumber(lVal.Value)
            Config.AltLevels[playerName] = lvl
            return lvl
        end
        local pData = p:FindFirstChild("playerData") or p:FindFirstChild("Data")
        local pLvl = pData and (pData:FindFirstChild("Level") or pData:FindFirstChild("level"))
        if pLvl and tonumber(pLvl.Value) and tonumber(pLvl.Value) > 0 then
            local lvl = tonumber(pLvl.Value)
            Config.AltLevels[playerName] = lvl
            return lvl
        end
    end

    if Config.AltLevels and Config.AltLevels[playerName] and Config.AltLevels[playerName] > 0 then
        return Config.AltLevels[playerName]
    end

    return nil
end

local function getAltStatus(altName)
    local p = Players:FindFirstChild(altName)
    local liveLvl = getLivePlayerLevel(altName) or (Config.AltLevels and Config.AltLevels[altName]) or 60
    if p then
        return true, liveLvl, "🟢 In Server"
    else
        return false, liveLvl, "⚪ In Lobby / Offline"
    end
end

local function getLowestAltLevel()
    local minLvl = math.huge
    local lowestName = "Alts"
    for _, altName in ipairs(Config.AltUsernames) do
        local lvl = getLivePlayerLevel(altName) or (Config.AltLevels and Config.AltLevels[altName])
        if lvl and lvl < minLvl then
            minLvl = lvl
            lowestName = altName
        end
    end
    if minLvl == math.huge then
        return 60, "Default (Lv 60)"
    end
    return minLvl, lowestName
end

local function getOptimalDungeonForAlts()
    local lowestLvl, altName = getLowestAltLevel()
    local best = ProgressionLadder[1]
    for _, entry in ipairs(ProgressionLadder) do
        if lowestLvl >= entry.req then
            best = entry
        else
            break
        end
    end
    return best, lowestLvl, altName
end

-- Authoritative Engine Selector for Current Dungeon
local function getCurrentDungeonEngine()
    local slug, rawName = getDungeonSlug()

    if slug == "orbital_outpost" or slug == "volcanic_chambers" or slug == "aquatic_temple" or slug == "enchanted_forest" then
        return "mhc"
    end
    if slug == "boss_raid" or rawName:lower():find("raid") then
        return "bossraid"
    end

    local optLadder = getOptimalDungeonForAlts()
    return optLadder.engine
end

-- ========================================================================
--  [MODULE 1] DEATH AURA (COMBAT BURST ENGINE FOR 60-130)
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

-- Death Aura Loop for Levels 60-144
task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.03)
        local engine = getCurrentDungeonEngine()
        if isCarry and isDungeon() and (engine == "waypoint" or engine == "bossraid") then
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

-- Walkspeed buffer for 60-144 ONLY
RunService.Heartbeat:Connect(function()
    local engine = getCurrentDungeonEngine()
    if isCarry and isDungeon() and (engine == "waypoint" or engine == "bossraid") then
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed < 23 then hum.WalkSpeed = 23 end
    end
end)

-- ========================================================================
--  [MODULE 2] GOLDEN MASTER WAYPOINT ENGINE (LEVELS 60 - 130)
-- ========================================================================
local loadedWaypoints = {}
local currentWpIndex = 1
local isPlaybackActive = false

local function loadCurrentDungeonMap()
    local slug, rawName = getDungeonSlug()
    local fileName = string.format("dqr_map_%s.json", slug)
    if not isfile or not isfile(fileName) then return false end
    local raw = readfile(fileName)
    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and parsed and parsed.points and #parsed.points > 0 then
        loadedWaypoints = parsed.points
        currentWpIndex = 1
        isPlaybackActive = true
        return true, #loadedWaypoints
    end
    return false
end

-- Global Checkpoint Recovery Helper
local function findClosestWaypointIndex(pos, points)
    if not points or #points == 0 then return 1 end
    local best = 1
    local minD = math.huge
    for i = 1, #points do
        local p = Vector3.new(points[i].x, points[i].y, points[i].z)
        local d = (pos - p).Magnitude
        if d < minD then
            minD = d
            best = i
        end
    end
    return best, minD
end

-- Dynamic Wall Collider Remover
task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        if isCarry and isDungeon() then
            local dungeon = Workspace:FindFirstChild("dungeon") or Workspace
            for _, desc in ipairs(dungeon:GetDescendants()) do
                if desc:IsA("BasePart") then
                    local pName = desc.Name:lower()
                    local parName = desc.Parent and desc.Parent.Name:lower() or ""
                    if pName:find("door") or pName:find("gate") or pName:find("barrier") or pName:find("blocker") or parName:find("doors") or parName:find("gates") or desc.Transparency >= 0.9 then
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

-- Playback loop for Levels 60-130 (With Smart Respawn Recovery)
local lastCarryPosBeforeTick = nil
task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.02)
        local engine = getCurrentDungeonEngine()
        if engine == "waypoint" and isCarry and isDungeon() and isPlaybackActive and #loadedWaypoints > 0 and currentWpIndex <= #loadedWaypoints then
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 then
                local myPos = hrp.Position

                if lastCarryPosBeforeTick and (myPos - lastCarryPosBeforeTick).Magnitude >= 28.0 then
                    local closestIdx, cDist = findClosestWaypointIndex(myPos, loadedWaypoints)
                    currentWpIndex = closestIdx
                    print(string.format("[Maki Waypoint 🛡️] Respawn detected! Synced to Waypoint %d / %d (Dist: %.1fs)", closestIdx, #loadedWaypoints, cDist))
                end
                lastCarryPosBeforeTick = myPos

                local targetPoint = loadedWaypoints[currentWpIndex]
                local targetPos = Vector3.new(targetPoint.x, targetPoint.y, targetPoint.z)
                local dist = (myPos - targetPos).Magnitude

                if dist <= 3.8 then
                    currentWpIndex = currentWpIndex + 1
                    if currentWpIndex <= #loadedWaypoints then
                        targetPoint = loadedWaypoints[currentWpIndex]
                        targetPos = Vector3.new(targetPoint.x, targetPoint.y, targetPoint.z)
                    end
                end

                if currentWpIndex <= #loadedWaypoints then
                    hum:MoveTo(targetPos)
                end
            else
                lastCarryPosBeforeTick = nil
            end
        end
    end
end)

-- ========================================================================
--  [MODULE 7] BOSS RAIDS FAST-TRACK ENGINE (LEVELS 130 - 144)
-- ========================================================================
task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.05)
        local engine = getCurrentDungeonEngine()
        if engine == "bossraid" and isCarry and isDungeon() then
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 then
                local bossModel = nil
                local enemiesFolder = Workspace:FindFirstChild("enemies") or Workspace:FindFirstChild("dungeon")
                if enemiesFolder then
                    for _, c in ipairs(enemiesFolder:GetChildren()) do
                        local bHum = c:FindFirstChildOfClass("Humanoid")
                        if bHum and bHum.Health > 0 then
                            bossModel = c
                            break
                        end
                    end
                end

                if bossModel then
                    local bRoot = bossModel.PrimaryPart or bossModel:FindFirstChild("HumanoidRootPart") or bossModel:FindFirstChild("Head")
                    if bRoot then
                        local dir = (bRoot.Position - hrp.Position).Unit
                        local standPos = bRoot.Position - (dir * 35.0)
                        hum:MoveTo(standPos)
                        hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(bRoot.Position.X, hrp.Position.Y, bRoot.Position.Z))
                    end
                end
            end
        end
    end
end)

-- ========================================================================
--  [MODULE 8] MAKI HIGHWAY-CORTEX (MHC) ENGINE (LEVELS 145 - 165+)
--  100% NATURAL WALKSPEED & STAIRCASE ELEVATION CALIBRATED
-- ========================================================================
local function hasLineOfSight(startPos, targetPos)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, Workspace:FindFirstChild("enemies") }
    rayParams.IgnoreWater = true

    local dir = (targetPos - (startPos + Vector3.new(0, 2, 0)))
    local result = Workspace:Raycast(startPos + Vector3.new(0, 2, 0), dir, rayParams)

    if result and result.Instance then
        local hitPart = result.Instance
        if hitPart.Transparency >= 0.85 or not hitPart.CanCollide then
            return true
        end
        return false
    end
    return true
end

local function scanLivingEnemies()
    local enemies = {}
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return enemies, nil end

    local myPos = myHrp.Position
    local checked = {}

    local function checkModel(obj)
        if not obj or not obj:IsA("Model") or obj == myChar or checked[obj] then return end
        checked[obj] = true

        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character == obj or p.Name == obj.Name then return end
        end

        local hum = obj:FindFirstChildOfClass("Humanoid")
        local root = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head") or obj:FindFirstChildOfClass("BasePart")
        if hum and hum.Health > 0 and root then
            local pos = root.Position
            local dist = (myPos - pos).Magnitude
            local nameLower = obj.Name:lower()
            local isBoss = (nameLower:find("boss") ~= nil or nameLower:find("guardian") ~= nil or nameLower:find("inferno") ~= nil or nameLower:find("triton") ~= nil or nameLower:find("kraken") ~= nil or hum.MaxHealth > 3000000)

            table.insert(enemies, {
                model = obj,
                hum = hum,
                root = root,
                pos = pos,
                dist = dist,
                isBoss = isBoss
            })
        end
    end

    local enemiesFolder = Workspace:FindFirstChild("enemies")
    if enemiesFolder then
        for _, c in ipairs(enemiesFolder:GetChildren()) do checkModel(c) end
    end

    local dungeon = Workspace:FindFirstChild("dungeon")
    if dungeon then
        for _, room in ipairs(dungeon:GetChildren()) do
            local eFold = room:FindFirstChild("enemyFolder") or room:FindFirstChild("enemies")
            if eFold then
                for _, c in ipairs(eFold:GetChildren()) do checkModel(c) end
            end
            for _, c in ipairs(room:GetChildren()) do checkModel(c) end
        end
    end

    local arena = Workspace:FindFirstChild("Arena")
    if arena then
        for _, c in ipairs(arena:GetChildren()) do checkModel(c) end
    end

    table.sort(enemies, function(a, b)
        if a.isBoss and not b.isBoss then return true end
        if not a.isBoss and b.isBoss then return false end
        return a.dist < b.dist
    end)

    return enemies, myPos
end

local function getTargetGroup(enemies, myPos)
    if #enemies == 0 then return nil end

    local leader = nil
    for _, e in ipairs(enemies) do
        if hasLineOfSight(myPos, e.pos) then
            leader = e
            break
        end
    end

    if not leader then return nil end

    local group = { leader }
    local maxDistInGroup = leader.dist

    for i = 1, #enemies do
        local e = enemies[i]
        if e ~= leader and (e.pos - leader.pos).Magnitude <= 45.0 then
            table.insert(group, e)
            if e.dist > maxDistInGroup then
                maxDistInGroup = e.dist
            end
        end
    end

    local sumPos = Vector3.zero
    for _, e in ipairs(group) do sumPos = sumPos + e.pos end
    local groupCenter = sumPos / #group

    return {
        mobs = group,
        count = #group,
        leader = leader,
        center = groupCenter,
        nearestDist = leader.dist,
        farthestDist = maxDistInGroup,
        isBoss = leader.isBoss
    }
end

-- MHC Execution Loop (Levels 145+ Natural Speed & Direct Dungeon Activation)
local mhcCurrentIndex = 1
local mhcLastQTime = 0
local mhcLastETime = 0
local lastMhcPosBeforeTick = nil

task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.02)
        local engine = getCurrentDungeonEngine()

        if engine == "mhc" and isCarry and isDungeon() then
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 then
                local myPos = hrp.Position
                local now = os.clock()

                local slug, _ = getDungeonSlug()
                local fileName = string.format("dqr_highway_%s.json", slug)

                if isfile and isfile(fileName) then
                    local raw = readfile(fileName)
                    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
                    local waypoints = (ok and parsed and parsed.points) or {}

                    if #waypoints > 0 then
                        -- Checkpoint / Respawn detection
                        if lastMhcPosBeforeTick and (myPos - lastMhcPosBeforeTick).Magnitude >= 28.0 then
                            local closestIdx, cDist = findClosestWaypointIndex(myPos, waypoints)
                            mhcCurrentIndex = closestIdx
                            print(string.format("[Maki MHC 🛡️] Respawn detected! Synced to Highway Point %d / %d (Dist: %.1fs)", closestIdx, #waypoints, cDist))
                        end
                        lastMhcPosBeforeTick = myPos

                        local targetPoint = waypoints[mhcCurrentIndex] or waypoints[#waypoints]
                        local targetPos = Vector3.new(targetPoint.x, targetPoint.y, targetPoint.z)
                        local distToWp = (myPos - targetPos).Magnitude

                        local enemies, _ = scanLivingEnemies()
                        local qTool, eTool = getAbilityTools()
                        local qCd = getToolCooldown(qTool)
                        local eCd = getToolCooldown(eTool)
                        local qReady = (qCd <= 0.1) and ((now - mhcLastQTime) >= 0.8)
                        local eReady = (eCd <= 0.1) and ((now - mhcLastETime) >= 0.5)

                        local targetGroup = getTargetGroup(enemies, myPos)

                        if targetGroup then
                            -- Height Difference Calculation for Staircases / Slopes
                            local heightDiff = math.abs(myPos.Y - targetGroup.center.Y)
                            local effectiveAoELimit = (heightDiff > 12.0) and 50.0 or 82.0

                            -- Pre-cast Q when approaching pack within 110 studs
                            if targetGroup.farthestDist <= 110.0 and qReady then
                                mhcLastQTime = now
                                castSlot("q", qTool)
                            end

                            if targetGroup.farthestDist <= effectiveAoELimit then
                                -- PAUSE ON HIGHWAY & WIPE GROUP!
                                hum:MoveTo(myPos)

                                local lookDir = Vector3.new(targetGroup.center.X - myPos.X, 0, targetGroup.center.Z - myPos.Z).Unit
                                hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + lookDir)

                                if qReady then
                                    mhcLastQTime = now
                                    castSlot("q", qTool)
                                end

                                if eReady then
                                    mhcLastETime = now
                                    castSlot("e", eTool)
                                end
                            else
                                -- Advance along highway
                                if distToWp <= 3.5 then
                                    mhcCurrentIndex = mhcCurrentIndex + 1
                                    if mhcCurrentIndex <= #waypoints then
                                        targetPoint = waypoints[mhcCurrentIndex]
                                        targetPos = Vector3.new(targetPoint.x, targetPoint.y, targetPoint.z)
                                    end
                                end

                                if mhcCurrentIndex <= #waypoints then
                                    hum:MoveTo(targetPos)
                                end
                            end
                        else
                            -- Sprint down highway
                            if qReady and (now - mhcLastQTime) >= 1.5 then
                                mhcLastQTime = now
                                castSlot("q", qTool)
                            end

                            -- Off-track auto-recovery
                            if distToWp > 14.0 then
                                local closestIdx, _ = findClosestWaypointIndex(myPos, waypoints)
                                mhcCurrentIndex = closestIdx
                                targetPoint = waypoints[mhcCurrentIndex]
                                targetPos = Vector3.new(targetPoint.x, targetPoint.y, targetPoint.z)
                            end

                            if distToWp <= 3.5 then
                                mhcCurrentIndex = mhcCurrentIndex + 1
                                if mhcCurrentIndex <= #waypoints then
                                    targetPoint = waypoints[mhcCurrentIndex]
                                    targetPos = Vector3.new(targetPoint.x, targetPoint.y, targetPoint.z)
                                end
                            end

                            if mhcCurrentIndex <= #waypoints then
                                hum:MoveTo(targetPos)
                            end
                        end
                    end
                end
            else
                lastMhcPosBeforeTick = nil
            end
        end
    end
end)

-- ========================================================================
--  [MODULE 3] REFINED AUTO-SELL & COLLECT PROTECTION ENGINE
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

    -- RULE 1: Abilities have NO collects. Sell all abilities below Legendary/Mythic/Ultimate!
    if category == "ability" then
        return false
    end

    -- RULE 2: Purple Weapons below EF (Eldenbark/Valhalla) are TRASH -> SELL!
    if category == "weapon" then
        if isCollect and isHighTier then
            return true
        end
        return false
    end

    -- RULE 3: Armor (Chests & Helmets) -> KEEP all Purple Collects from all 11 dungeons!
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
                    sendDropNotification(LocalPlayer.Name, itemName, rarity, category, Config.CurrentDungeon, Config.CurrentDiff)
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
            sendDropNotification(pName, iName, rName, "Dungeon Drop", Config.CurrentDungeon, Config.CurrentDiff)
        end
    end)
end

-- ========================================================================
--  [MODULE 4] ZERO-LATENCY INSTANT AUTO-ACCEPT ENGINE (0ms APPROVAL)
--  & ALTS HUMAN-LIKE MICRO-WANDER (ANTI-BOT HEURISTIC JITTER)
-- ========================================================================
local altSpawnPosition = nil
local altLobbyExitTriggered = false

local function exitAltToMainLobby()
    if altLobbyExitTriggered then return end
    altLobbyExitTriggered = true
    print("[Maki Alt] 👑 Carry left dungeon! Returning Alt to Main Lobby to receive new dungeon...")

    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    local retBtn = pG and pG:FindFirstChild("ReturnToLobbyButton", true)
    if retBtn then
        pcall(function()
            for _, c in ipairs(getconnections(retBtn.Activated)) do c:Fire() end
            for _, c in ipairs(getconnections(retBtn.MouseButton1Click)) do c:Fire() end
        end)
    end

    if teleToLobbyRemote then pcall(function() teleToLobbyRemote:FireServer() end) end
    local rLobby = remotes and (remotes:FindFirstChild("ReturnToLobbyEvent") or remotes:FindFirstChild("teleToLobby"))
    if rLobby then pcall(function() rLobby:FireServer() end) end

    task.wait(1.5)
    pcall(function() TeleportService:Teleport(77649408247578, LocalPlayer) end)
end

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
    if not isCarry and _G.MAKI_MASTER_SUITE_RUNNING then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(100, 100))
        end)
    end
end)

-- Anti-Bot Micro-Wander Leash (Safe 5-stud radius around spawn)
task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        local waitInterval = math.random(35, 70) / 10 -- Random 3.5s to 7.0s intervals
        task.wait(waitInterval)

        if not isCarry and isDungeon() and altSpawnPosition then
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 then
                local currentDist = (hrp.Position - altSpawnPosition).Magnitude

                if currentDist > 7.0 then
                    hum:MoveTo(altSpawnPosition)
                else
                    local angle = math.random() * 2 * math.pi
                    local radius = math.random(15, 45) / 10
                    local targetX = altSpawnPosition.X + (math.cos(angle) * radius)
                    local targetZ = altSpawnPosition.Z + (math.sin(angle) * radius)
                    local targetPos = Vector3.new(targetX, altSpawnPosition.Y, targetZ)

                    hum:MoveTo(targetPos)

                    if math.random(1, 5) == 1 then
                        task.wait(0.3)
                        pcall(function() hum.Jump = true end)
                    end

                    pcall(function()
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new(120 + math.random(-20, 20), 120 + math.random(-20, 20)))
                    end)
                end
            end
        end
    end
end)

-- Hard Boundary Safety Clamping (Never fall off map)
RunService.Heartbeat:Connect(function()
    if not isCarry and isDungeon() and altSpawnPosition and _G.MAKI_MASTER_SUITE_RUNNING then
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dist = (hrp.Position - altSpawnPosition).Magnitude
            if dist > 14.0 then
                hrp.CFrame = CFrame.new(altSpawnPosition)
            end
        end
    end
end)

task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        local pG = LocalPlayer:FindFirstChild("PlayerGui")
        local qG = pG and pG:FindFirstChild("queueGui")
        if qG and qG:FindFirstChild("gameSearch") and qG.gameSearch.Visible then
            qG.gameSearch.Visible = false
        end
        task.wait(0.5)
    end
end)

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

local showJoinRemote = remotes and remotes:FindFirstChild("showJoinRequest")
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
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.08)
        if isCarry and isDungeon() and not isPlaybackActive and Config.AutoAcceptJoins then
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
    while _G.MAKI_MASTER_SUITE_RUNNING do
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

local isCreatingLobby = false
local function carryCreateAndLaunch()
    if not isCarry or not isMainLobby() or isCreatingLobby then return end
    isCreatingLobby = true

    loadConfig()

    local bestLadder, curLvl, altName = getOptimalDungeonForAlts()
    local dName = bestLadder.dungeon
    local dDiff = bestLadder.diff
    local dReq  = bestLadder.req

    Config.CurrentDungeon = dName
    Config.CurrentDiff    = dDiff
    saveConfig()

    print(string.format("[Maki Host] 🏰 Creating Target Staging Lobby: %s (%s) [Lowest: %s Lv %d, Req: %d]...",
        dName, dDiff, altName, curLvl, dReq))

    local ok, res = pcall(function()
        return createLobbyRemote:InvokeServer(dName, dDiff, dReq, Config.HardcoreMode, true, false)
    end)

    if ok and res == true then
        print("[Maki Host] ✅ Lobby Created! Whitelisting Alts...")
        if addPlayerToWhitelistRemote then
            for _, name in ipairs(Config.AltUsernames) do
                pcall(function() addPlayerToWhitelistRemote:FireServer(name) end)
                task.wait(0.01)
            end
        end

        if changeStartValueRemote then pcall(function() changeStartValueRemote:FireServer() end) end
        task.wait(0.2)
        print("[Maki Host] 🚀 Fast-Teleporting Carry ALONE to Staging Room...")
        if startDungeonRemote then pcall(function() startDungeonRemote:FireServer() end) end
        task.wait(3.0)
        isCreatingLobby = false
    else
        warn("[Maki Host] ❌ Creation failed: " .. tostring(res))
        task.wait(2.0)
        isCreatingLobby = false
    end
end

-- ========================================================================
--  [MODULE 5] MASTER PROGRESSION, AUTO-START & HARDCORE DEFEAT REPLAY
-- ========================================================================
local returnToLobbyTriggered = false
local lobbyVerificationActive = false

local function returnPartyToLobby()
    if returnToLobbyTriggered then return end
    returnToLobbyTriggered = true
    print("[Maki Progression] 🚀 Milestone Reached! Returning party to Main Lobby to create new dungeon...")

    saveConfig()

    if teleToLobbyRemote then pcall(function() teleToLobbyRemote:FireServer() end) end
    task.wait(2.0)
    pcall(function() TeleportService:Teleport(77649408247578, LocalPlayer) end)
end

local function areAllAltsInDungeon()
    if #Config.AltUsernames == 0 then return true end
    for _, altName in ipairs(Config.AltUsernames) do
        if not Players:FindFirstChild(altName) then
            return false
        end
    end
    return true
end

local function triggerCarryStartDungeon()
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        local sBtn1 = pG:FindFirstChild("startButton") and pG.startButton:FindFirstChild("TextButton", true)
        if sBtn1 then
            pcall(function()
                for _, c in ipairs(getconnections(sBtn1.Activated)) do c:Fire() end
                for _, c in ipairs(getconnections(sBtn1.MouseButton1Click)) do c:Fire() end
            end)
        end
        local qG = pG:FindFirstChild("queueGui")
        local sBtn2 = qG and qG:FindFirstChild("lobbyInfo") and qG.lobbyInfo:FindFirstChild("startButton", true)
        if sBtn2 then
            pcall(function()
                for _, c in ipairs(getconnections(sBtn2.Activated)) do c:Fire() end
                for _, c in ipairs(getconnections(sBtn2.MouseButton1Click)) do c:Fire() end
            end)
        end
    end

    if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
    if startDungeonRemote then pcall(function() startDungeonRemote:FireServer() end) end
    if changeStartValueRemote then pcall(function() changeStartValueRemote:FireServer() end) end
end

-- Master Match State & Replay Handler
task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.8)
        if isDungeon() then
            lobbyVerificationActive = false
            local prog = getDungeonProgress()
            local engine = getCurrentDungeonEngine()

            if isCarry and not isPlaybackActive and engine == "waypoint" then
                local altsReady = areAllAltsInDungeon()
                if altsReady then
                    print("[Maki Staging] 👥 All Alts present in Staging Room! Starting dungeon...")
                    triggerCarryStartDungeon()
                    loadCurrentDungeonMap()
                end
            elseif isCarry and engine == "mhc" then
                local altsReady = areAllAltsInDungeon()
                if altsReady then
                    triggerCarryStartDungeon()
                end
            elseif not isCarry then
                if not altSpawnPosition then
                    lockAltSpawn()
                end

                local carryInServer = (Config.CarryUsername and #Config.CarryUsername > 0) and Players:FindFirstChild(Config.CarryUsername) or nil
                if not carryInServer and not altLobbyExitTriggered then
                    exitAltToMainLobby()
                end
            end

            -- ================================================================
            --  VICTORY CONDITION
            -- ================================================================
            if prog == "bosskilled" or prog == "victory" or prog == "complete" then
                executeUniversalAutoSell()

                if isCarry then
                    task.wait(2.0)
                    local currentLadder, altLvl, altName = getOptimalDungeonForAlts()
                    local curDungeon = Config.CurrentDungeon or "Pirate Island"
                    local curDiff = Config.CurrentDiff or "Insane"

                    local isUpgraded = (currentLadder.dungeon ~= curDungeon) or (currentLadder.diff ~= curDiff)

                    if isUpgraded and Config.AutoProgression then
                        print(string.format("[Maki Progression] 🎉 %s reached Level %d! Promoting from %s (%s) ➔ %s (%s)...",
                            altName, altLvl, curDungeon, curDiff, currentLadder.dungeon, currentLadder.diff))
                        returnPartyToLobby()
                    else
                        print(string.format("[Maki Progression] ⚡ Replaying %s (%s) in 2.5s...", curDungeon, curDiff))
                        task.wait(2.5)
                        if replayRemote then pcall(function() replayRemote:FireServer() end) end
                        if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
                        currentWpIndex = 1
                        mhcCurrentIndex = 1
                    end
                else
                    task.wait(2.8)
                    if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
                end
            end

            -- ================================================================
            --  HARDCORE DEFEAT / WIPE REPLAY HANDLER (ZERO LOBBY RELOADS)
            -- ================================================================
            if prog == "defeat" or prog == "failed" or prog == "gameover" or prog == "loss" then
                print("[Maki Hardcore 💀] Defeat/Wipe detected! Instantly retrying match in-place...")
                executeUniversalAutoSell()

                if isCarry then
                    task.wait(2.0)
                    if replayRemote then pcall(function() replayRemote:FireServer() end) end
                    if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end

                    local pG = LocalPlayer:FindFirstChild("PlayerGui")
                    if pG then
                        for _, btnName in ipairs({"RetryButton", "ReplayButton", "retry", "replay"}) do
                            local btn = pG:FindFirstChild(btnName, true)
                            if btn and btn:IsA("GuiButton") then
                                pcall(function()
                                    for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                                    for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                                end)
                            end
                        end
                    end

                    currentWpIndex = 1
                    mhcCurrentIndex = 1
                    task.wait(3.0)
                else
                    task.wait(2.5)
                    if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
                end
            end
        elseif isMainLobby() then
            returnToLobbyTriggered = false
            altLobbyExitTriggered = false
            altSpawnPosition = nil
            isPlaybackActive = false
            currentWpIndex = 1
            mhcCurrentIndex = 1

            if isCarry and Config.AutoProgression and not lobbyVerificationActive and not isCreatingLobby then
                lobbyVerificationActive = true
                print("[Maki Host] ⏳ Main Lobby arrived! Waiting 7s to verify Party levels & Target Tier...")
                task.wait(7.0)
                if isMainLobby() and _G.MAKI_MASTER_SUITE_RUNNING then
                    carryCreateAndLaunch()
                end
                lobbyVerificationActive = false
            end
        end
    end
end)

-- ========================================================================
--  [MODULE 9] ENHANCED MULTI-TAB GUI (DASHBOARD, ALTS, DISCORD)
-- ========================================================================
local pGuiRef = LocalPlayer:WaitForChild("PlayerGui")
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
stroke.Color = isCarry and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(180, 120, 255)
stroke.Thickness = 1.5

local titleLbl = Instance.new("TextLabel", frame)
titleLbl.Size = UDim2.new(1, -16, 0, 20)
titleLbl.Position = UDim2.new(0, 8, 0, 4)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = isCarry and Color3.fromRGB(0, 210, 255) or Color3.fromRGB(200, 160, 255)
titleLbl.TextSize = 10
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Text = isCarry and "👑 MAKI [MASTER PROGRESSION V4.0]" or "🛡️ MAKI ALT [MASTER PROGRESSION V4.0]"

local tabBar = Instance.new("Frame", frame)
tabBar.Size = UDim2.new(1, -16, 0, 22)
tabBar.Position = UDim2.new(0, 8, 0, 26)
tabBar.BackgroundTransparency = 1

local tabDashBtn = Instance.new("TextButton", tabBar)
tabDashBtn.Size = UDim2.new(0.33, -2, 1, 0)
tabDashBtn.Position = UDim2.new(0, 0, 0, 0)
tabDashBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
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

    tabDashBtn.BackgroundColor3 = (tab == "dash") and Color3.fromRGB(0, 140, 200) or Color3.fromRGB(35, 42, 60)
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
statusLbl.Text = "● STATUS: 🟢 ACTIVE (MASTER V4.0)"

local dungeonInfoLbl = Instance.new("TextLabel", statsBox)
dungeonInfoLbl.Size = UDim2.new(1, -10, 0, 14)
dungeonInfoLbl.Position = UDim2.new(0, 6, 0, 18)
dungeonInfoLbl.BackgroundTransparency = 1
dungeonInfoLbl.TextColor3 = Color3.fromRGB(255, 200, 50)
dungeonInfoLbl.TextSize = 7.5
dungeonInfoLbl.Font = Enum.Font.Gotham
dungeonInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
dungeonInfoLbl.Text = "🏰 Dungeon: Scanning..."

local altLvlInfoLbl = Instance.new("TextLabel", statsBox)
altLvlInfoLbl.Size = UDim2.new(1, -10, 0, 14)
altLvlInfoLbl.Position = UDim2.new(0, 6, 0, 34)
altLvlInfoLbl.BackgroundTransparency = 1
altLvlInfoLbl.TextColor3 = Color3.fromRGB(120, 220, 255)
altLvlInfoLbl.TextSize = 7.5
altLvlInfoLbl.Font = Enum.Font.Gotham
altLvlInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
altLvlInfoLbl.Text = "📊 Lowest Alt: Scanning..."

local progInfoLbl = Instance.new("TextLabel", statsBox)
progInfoLbl.Size = UDim2.new(1, -10, 0, 14)
progInfoLbl.Position = UDim2.new(0, 6, 0, 50)
progInfoLbl.BackgroundTransparency = 1
progInfoLbl.TextColor3 = Color3.fromRGB(180, 200, 240)
progInfoLbl.TextSize = 7.5
progInfoLbl.Font = Enum.Font.Gotham
progInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
progInfoLbl.Text = "🎯 Target: Checking..."

local wpInfoLbl = Instance.new("TextLabel", statsBox)
wpInfoLbl.Size = UDim2.new(1, -10, 0, 14)
wpInfoLbl.Position = UDim2.new(0, 6, 0, 66)
wpInfoLbl.BackgroundTransparency = 1
wpInfoLbl.TextColor3 = Color3.fromRGB(255, 215, 80)
wpInfoLbl.TextSize = 7.5
wpInfoLbl.Font = Enum.Font.GothamBold
wpInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
wpInfoLbl.Text = "📍 Waypoint: Standby"

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

local autoProgToggleBtn = Instance.new("TextButton", pageDashboard)
autoProgToggleBtn.Size = UDim2.new(1, 0, 0, 22)
autoProgToggleBtn.Position = UDim2.new(0, 0, 0, 128)
autoProgToggleBtn.BackgroundColor3 = Config.AutoProgression and Color3.fromRGB(20, 100, 70) or Color3.fromRGB(60, 60, 60)
autoProgToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoProgToggleBtn.TextSize = 7.5
autoProgToggleBtn.Font = Enum.Font.GothamBold
autoProgToggleBtn.Text = Config.AutoProgression and "🤖 AUTO-PROGRESSION LADDER: ON" or "🤖 AUTO-PROGRESSION LADDER: OFF"
Instance.new("UICorner", autoProgToggleBtn).CornerRadius = UDim.new(0, 4)

autoProgToggleBtn.Activated:Connect(function()
    Config.AutoProgression = not Config.AutoProgression
    autoProgToggleBtn.Text = Config.AutoProgression and "🤖 AUTO-PROGRESSION LADDER: ON" or "🤖 AUTO-PROGRESSION LADDER: OFF"
    autoProgToggleBtn.BackgroundColor3 = Config.AutoProgression and Color3.fromRGB(20, 100, 70) or Color3.fromRGB(60, 60, 60)
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
mainActionBtn.BackgroundColor3 = isCarry and Color3.fromRGB(0, 160, 120) or Color3.fromRGB(140, 80, 220)
mainActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
mainActionBtn.TextSize = 8.5
mainActionBtn.Font = Enum.Font.GothamBold
mainActionBtn.Text = isCarry and "🚀 LAUNCH CARRY LADDER" or "🛡️ ALT STANDBY (Auto-Sync Active)"
Instance.new("UICorner", mainActionBtn).CornerRadius = UDim.new(0, 4)

mainActionBtn.Activated:Connect(function()
    if isCarry and isMainLobby() then
        carryCreateAndLaunch()
    end
end)

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
    print("[Maki Discord] 💾 Discord Webhook URL saved!")
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
    sendDropNotification(LocalPlayer.Name, "Triton Armor [TEST]", "epic", "Chest", "Aquatic Temple", "Nightmare")
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

local carryInput = Instance.new("TextBox", pageAlts)
carryInput.Size = UDim2.new(0.68, -4, 0, 24)
carryInput.Position = UDim2.new(0, 0, 0, 0)
carryInput.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
carryInput.TextColor3 = Color3.fromRGB(255, 255, 255)
carryInput.TextSize = 8.5
carryInput.Font = Enum.Font.Gotham
carryInput.PlaceholderText = "👑 Enter Main/Carry Username..."
carryInput.Text = Config.CarryUsername or ""
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
    Config.CarryUsername = name:gsub("%s+", "")
    saveConfig()
    updateCarryRole()
    carryInput.Text = Config.CarryUsername
    mainActionBtn.BackgroundColor3 = isCarry and Color3.fromRGB(0, 160, 120) or Color3.fromRGB(140, 80, 220)
    mainActionBtn.Text = isCarry and "🚀 LAUNCH CARRY LADDER" or "🛡️ ALT STANDBY (Auto-Sync Active)"
    carrySaveBtn.Text = "✅ SAVED"
    task.delay(1.0, function() carrySaveBtn.Text = "💾 SET MAIN" end)
end

carrySaveBtn.Activated:Connect(function()
    applyCarryUsername(carryInput.Text)
end)

carryInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        applyCarryUsername(carryInput.Text)
    end
end)

local altInput = Instance.new("TextBox", pageAlts)
altInput.Size = UDim2.new(0.68, -4, 0, 24)
altInput.Position = UDim2.new(0, 0, 0, 28)
altInput.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
altInput.TextColor3 = Color3.fromRGB(255, 255, 255)
altInput.TextSize = 8.5
altInput.Font = Enum.Font.Gotham
altInput.PlaceholderText = "👥 Enter Alt Username..."
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
        local isOnline, liveLvl, statusStr = getAltStatus(altName)

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
        nameLbl.Size = UDim2.new(0.48, -16, 0, 14)
        nameLbl.Position = UDim2.new(0, 16, 0, 2)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLbl.TextSize = 8.5
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Text = altName

        local statusSubLbl = Instance.new("TextLabel", row)
        statusSubLbl.Size = UDim2.new(0.48, -16, 0, 12)
        statusSubLbl.Position = UDim2.new(0, 16, 0, 16)
        statusSubLbl.BackgroundTransparency = 1
        statusSubLbl.TextColor3 = isOnline and Color3.fromRGB(100, 220, 160) or Color3.fromRGB(130, 140, 160)
        statusSubLbl.TextSize = 7
        statusSubLbl.Font = Enum.Font.Gotham
        statusSubLbl.TextXAlignment = Enum.TextXAlignment.Left
        statusSubLbl.Text = statusStr

        local lvlBadge = Instance.new("TextLabel", row)
        lvlBadge.Size = UDim2.new(0, 42, 0, 18)
        lvlBadge.Position = UDim2.new(0.52, 0, 0.5, -9)
        lvlBadge.BackgroundColor3 = Color3.fromRGB(35, 45, 70)
        lvlBadge.TextColor3 = Color3.fromRGB(255, 215, 80)
        lvlBadge.TextSize = 8
        lvlBadge.Font = Enum.Font.GothamBold
        lvlBadge.Text = string.format("Lv %d", liveLvl)
        Instance.new("UICorner", lvlBadge).CornerRadius = UDim.new(0, 3)

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

addAltBtn.Activated:Connect(function()
    local text = altInput.Text:gsub("%s+", "")
    if #text > 0 then
        table.insert(Config.AltUsernames, text)
        altInput.Text = ""
        saveConfig()
        refreshAltsUI()
    end
end)

refreshAltsUI()

task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(3.0)
        pcall(refreshAltsUI)
    end
end)

task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.5)
        local bestLadder, curLvl, altName = getOptimalDungeonForAlts()
        local curDungeon = Config.CurrentDungeon or "Pirate Island"
        local curDiff = Config.CurrentDiff or "Insane"
        local engine = getCurrentDungeonEngine()

        if isMainLobby() then
            dungeonInfoLbl.Text = "🏰 Location: Main Lobby"
            altLvlInfoLbl.Text = string.format("📊 Lowest Alt: %s (Lv %d)", altName, curLvl)
            progInfoLbl.Text = string.format("🎯 Target: %s (%s)", bestLadder.dungeon, bestLadder.diff)
            if lobbyVerificationActive then
                wpInfoLbl.Text = "📍 Status: ⏳ Verifying Target (7s)..."
            else
                wpInfoLbl.Text = "📍 Status: Ready in Lobby"
            end
        else
            dungeonInfoLbl.Text = string.format("🏰 Dungeon: %s (%s)", curDungeon, curDiff)
            altLvlInfoLbl.Text = string.format("📊 Lowest Alt: %s (Lv %d)", altName, curLvl)
            progInfoLbl.Text = string.format("🎯 Target: %s (%s)", bestLadder.dungeon, bestLadder.diff)
            if isCarry and engine == "waypoint" and isPlaybackActive and #loadedWaypoints > 0 then
                local pct = (currentWpIndex / #loadedWaypoints) * 100
                wpInfoLbl.Text = string.format("📍 Waypoint: %d / %d (%.1f%%)", currentWpIndex, #loadedWaypoints, pct)
            elseif isCarry and engine == "mhc" then
                wpInfoLbl.Text = string.format("📍 MHC Highway Index: %d", mhcCurrentIndex)
            elseif isCarry and engine == "bossraid" then
                wpInfoLbl.Text = "📍 Status: ⚔️ Boss Raid Homing"
            else
                wpInfoLbl.Text = "📍 Status: Standby"
            end
        end
    end
end)

print("[Project Maki 👑] Master Progression Suite V4.0 (Aquatic Temple Direct Route Fixed) LOADED!")
