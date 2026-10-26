-- ========================================================================
--  AUTO-DOWNLOAD PREAMBLE FOR 11 MAP & HIGHWAY FILES
-- ========================================================================
local GITHUB_BASE = "https://raw.githubusercontent.com/MayyAlterrr/maki-suite/main/"
local REQUIRED_MAPS = {
    "dqr_map_winter_outpost.json",
    "dqr_map_pirate_island.json",
    "dqr_map_kings_castle.json",
    "dqr_map_the_underworld.json",
    "dqr_map_samurai_palace.json",
    "dqr_map_the_canals.json",
    "dqr_map_ghastly_harbor.json",
    "dqr_map_steampunk_sewers.json",
    "dqr_highway_orbital_outpost.json",
    "dqr_highway_volcanic_chambers.json",
    "dqr_highway_aquatic_temple.json"
}
for _, f in ipairs(REQUIRED_MAPS) do
    local exists = false
    if typeof(isfile) == "function" then
        local ok, res = pcall(isfile, f)
        if ok and res then exists = true end
    end
    if not exists and typeof(writefile) == "function" then
        pcall(function()
            local content = game:HttpGet(GITHUB_BASE .. f)
            if content and #content > 50 then
                writefile(f, content)
                print("[Maki Auto-Downloader 📥] Downloaded " .. f)
            end
        end)
    end
end

-- ========================================================================
--  PROJECT MAKI: MASTER PROGRESSION & CARRY/ALT SUITE (VERSION 4.0)
--  COMPLETE INTEGRATION: LEVELS 33-59 (WINTER OUTPOST) + 60-130 + 130-144 + 145-155+ + 160-165+ (AQUATIC)
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
while not LocalPlayer do
    LocalPlayer = Players.LocalPlayer
    task.wait(0.05)
end

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
local createBossLobbyRemote      = remotes and (remotes:FindFirstChild("createBossLobby") or remotes:FindFirstChild("createRaidLobby"))
local addPlayerToBossWhitelistRemote = remotes and (remotes:FindFirstChild("addPlayerToBossWhitelist") or remotes:FindFirstChild("addPlayerToRaidWhitelist"))
local removePlayerFromBossWhitelistRemote = remotes and (remotes:FindFirstChild("removePlayerFromBossWhitelist") or remotes:FindFirstChild("removePlayerFromRaidWhitelist"))
local playerJoinBossLobbyRemote  = remotes and (remotes:FindFirstChild("playerJoinBossLobby") or remotes:FindFirstChild("playerJoinRaidLobby"))
local startBossRaidRemote        = remotes and (remotes:FindFirstChild("startBossRaid") or remotes:FindFirstChild("startRaid"))
local leaveBossLobbyRemote       = remotes and (remotes:FindFirstChild("leaveBossLobby") or remotes:FindFirstChild("leaveRaidLobby"))
local showReadyGuiRemote         = remotes and remotes:FindFirstChild("showReadyGui")
local upgradeKeyRemote           = remotes and remotes:FindFirstChild("upgradeKey")
local buyGamepassRemote          = remotes and (remotes:FindFirstChild("requestGoldGamepassPurchase") or remotes:FindFirstChild("buyGamepass") or remotes:FindFirstChild("purchaseGamepass") or remotes:FindFirstChild("buyGamepassGold") or remotes:FindFirstChild("buyPass"))
local getGoldGamepassPriceRemote = remotes and remotes:FindFirstChild("getGoldGamepassPrice")
local getGoldAmountRemote        = remotes and (remotes:FindFirstChild("getGoldAmount") or remotes:FindFirstChild("getGold"))

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
    CarryFpsCap         = 55,
    AutoBuyGamepasses   = true,
    AutoReadyUp         = true,
    AutoNextTier        = true,
    CurrentTier         = 1
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
    if not Config.CurrentDungeon then Config.CurrentDungeon = "Pirate Island" end
    if not Config.CurrentDiff then Config.CurrentDiff = "Insane" end
    if Config.AutoSellTrashes == nil then Config.AutoSellTrashes = true end
    if not Config.DiscordWebhookUrl then Config.DiscordWebhookUrl = "" end
    if Config.CpuSaverMode == nil then Config.CpuSaverMode = true end
    if Config.UltraPotatoGraphics == nil then Config.UltraPotatoGraphics = true end
    if Config.Disable3dOnAlts == nil then Config.Disable3dOnAlts = true end
    if Config.NotifyCollects == nil then Config.NotifyCollects = true end
    if not Config.AltFpsCap then Config.AltFpsCap = 12 end
    if Config.AutoReadyUp == nil then Config.AutoReadyUp = true end
    if Config.AutoNextTier == nil then Config.AutoNextTier = true end
    Config.CarryFpsCap = 55
    Config.HardcoreMode = true
end

local function saveConfig()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(Config) end)
    if ok and encoded then
        safeWriteFile(ConfigFileName, encoded)
    end
end

loadConfig()

local isCarry = true
local function getCarryPlayer()
    if Config.CarryUsername and #Config.CarryUsername > 0 then
        local p = Players:FindFirstChild(Config.CarryUsername)
        if p then return p end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        local isAlt = false
        if Config.AltUsernames then
            for _, alt in ipairs(Config.AltUsernames) do
                if p.Name:lower() == tostring(alt):lower() then
                    isAlt = true
                    break
                end
            end
        end
        if not isAlt then
            return p
        end
    end
    return nil
end

local function updateCarryRole()
    if Config.CarryUsername and #Config.CarryUsername > 0 then
        isCarry = (LocalPlayer.Name:lower() == Config.CarryUsername:lower())
    else
        local isAlt = false
        if Config.AltUsernames and #Config.AltUsernames > 0 then
            for _, alt in ipairs(Config.AltUsernames) do
                if LocalPlayer.Name:lower() == tostring(alt):lower() then
                    isAlt = true
                    break
                end
            end
        end
        isCarry = not isAlt
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
    { dungeon = "Winter Outpost",   diff = "Easy",      req = 33,  slug = "winter_outpost",   engine = "waypoint" },
    { dungeon = "Winter Outpost",   diff = "Medium",    req = 40,  slug = "winter_outpost",   engine = "waypoint" },
    { dungeon = "Winter Outpost",   diff = "Hard",      req = 45,  slug = "winter_outpost",   engine = "waypoint" },
    { dungeon = "Winter Outpost",   diff = "Insane",    req = 50,  slug = "winter_outpost",   engine = "waypoint" },
    { dungeon = "Winter Outpost",   diff = "Nightmare", req = 55,  slug = "winter_outpost",   engine = "waypoint" },
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
    { dungeon = "Enchanted Forest", diff = "Nightmare", req = 175, slug = "enchanted_forest", engine = "mhc" },
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
        local slug, _ = getDungeonSlug()
        if slug == "enchanted_forest" then
            return 175, "Default (Lv 175)"
        elseif slug == "aquatic_temple" then
            return 165, "Default (Lv 165)"
        elseif slug == "volcanic_chambers" then
            return 150, "Default (Lv 150)"
        elseif slug == "orbital_outpost" then
            return 145, "Default (Lv 145)"
        end
        return 33, "Default (Lv 33)"
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
--  UNIVERSAL AUTO-READY ENGINE (1:1 MATCH WITH MAKI BOSS RAID V3.1)
-- ========================================================================
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
        local cleanName = tostring(altName):gsub("%s+", ""):lower()
        local found = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower() == cleanName then
                local char = p.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if char and hrp and hum then
                    found = true
                end
                break
            end
        end
        if not found then return false end
    end
    return true
end

local function executeInstantReadyUp()
    if Config.AutoReadyUp == false or not isDungeon() then return end

    -- If Carry, DO NOT ready up until ALL configured alts are inside the raid/dungeon room with loaded characters!
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
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.15)
        if isDungeon() then
            local prog = getDungeonProgress()
            if prog == "playersnotready" or prog:find("ready") or (isCarry and areAllAltsPresent()) then
                executeInstantReadyUp()
            end
        end
    end
end)

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
    local raw = safeReadFile(fileName)
    if not raw or #raw == 0 then return false end
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
    if not points or #points == 0 then return 1, 0 end
    local best = 1
    local minD = math.huge
    for i = 1, #points do
        local pt = points[i]
        if pt then
            local px = pt.x or pt[1] or 0
            local py = pt.y or pt[2] or 0
            local pz = pt.z or pt[3] or 0
            local p = Vector3.new(px, py, pz)
            local d = (pos - p).Magnitude
            if d < minD then
                minD = d
                best = i
            end
        end
    end
    return best, minD
end

-- ========================================================================
--  [MATCH UNLOCK & COUNTDOWN BUFFER ENGINE]
-- ========================================================================
local matchStartUnlockTime = 0

local function isMatchUnlocked()
    if isMainLobby() then
        matchStartUnlockTime = 0
        return false
    end

    local engine = getCurrentDungeonEngine()
    if engine == "bossraid" then
        if matchStartUnlockTime > 0 and os.clock() < matchStartUnlockTime then
            return false
        end
        if matchStartUnlockTime > 0 and os.clock() >= matchStartUnlockTime then
            return true
        end
        local pG = LocalPlayer:FindFirstChild("PlayerGui")
        if pG then
            local bQ = pG:FindFirstChild("bossQueueGui")
            if bQ and bQ.Enabled then
                local sBtn = bQ:FindFirstChild("lobbyInfo") and bQ.lobbyInfo:FindFirstChild("startButton", true)
                if sBtn and sBtn.Visible then
                    return false
                end
            end
        end
        return true
    end

    -- If in the middle of the 3.8s countdown buffer after clicking start, stay locked
    if matchStartUnlockTime > 0 and os.clock() < matchStartUnlockTime then
        return false
    end

    -- If we are already past the countdown buffer, we are 100% unlocked
    if matchStartUnlockTime > 0 and os.clock() >= matchStartUnlockTime then
        return true
    end

    -- Before clicking start: if staging GUI exists, stay locked
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        local qG = pG and (pG:FindFirstChild("queueGui") or pG:FindFirstChild("bossQueueGui"))
        local sBtn = (pG and pG:FindFirstChild("startButton", true)) or (qG and qG:FindFirstChild("startButton", true))
        if (qG and qG.Enabled) or (sBtn and sBtn.Visible) then
            return false
        end
    end

    return true
end

-- Playback loop for Levels 60-130 (With Smart Respawn Recovery & Auto Map Loading)
local lastCarryPosBeforeTick = nil
task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.02)
        local engine = getCurrentDungeonEngine()
        if engine == "waypoint" and isCarry and isDungeon() then
            if not isPlaybackActive or #loadedWaypoints == 0 then
                loadCurrentDungeonMap()
            end
            if isPlaybackActive and #loadedWaypoints > 0 and currentWpIndex <= #loadedWaypoints then
                local char = LocalPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                local hum  = char and char:FindFirstChildOfClass("Humanoid")

                if hrp and hum and hum.Health > 0 then
                    if not isMatchUnlocked() then
                        hum:MoveTo(hrp.Position)
                    else
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
                    end
                else
                    lastCarryPosBeforeTick = nil
                end
            end
        end
    end
end)

-- ========================================================================
--  [MODULE 7] BOSS RAIDS FAST-TRACK ENGINE (LEVELS 130 - 144)
--  1:1 MATCH WITH MAKI BOSS RAID V3.1 DEDICATED ENGINE
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
    while _G.MAKI_MASTER_SUITE_RUNNING do
        local engine = getCurrentDungeonEngine()
        if isCarry and isDungeon() and engine == "bossraid" then
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

-- Continuous Boss Chasing & Movement Drive (1:1 with maki_boss_raid_v3.1.lua)
task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.03)
        local engine = getCurrentDungeonEngine()
        if isCarry and isDungeon() and engine == "bossraid" then
            local myChar = LocalPlayer.Character
            local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")

            if myHrp and myHum and myHum.Health > 0 then
                if not isMatchUnlocked() then
                    myHum:MoveTo(myHrp.Position)
                else
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
            local isBoss = (nameLower:find("boss") ~= nil or nameLower:find("guardian") ~= nil or nameLower:find("inferno") ~= nil or nameLower:find("triton") ~= nil or nameLower:find("kraken") ~= nil or nameLower:find("dragon") ~= nil or nameLower:find("tree") ~= nil or nameLower:find("golem") ~= nil or hum.MaxHealth > 3000000)

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

-- ========================================================================

local executeUniversalAutoSell
local returnPartyToLobby

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
    else
        data.hardcore = true
        data.isHardcore = true
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

local efDeathRetryActive = false
local efWasAlive = false
local efLastRetryTime = 0

local function triggerEFDeathRetry(reason)
    if not isCarry then return end -- ONLY FOR CARRY! ALTS CANNOT TRIGGER RETRY
    if not isDungeon() then return end
    local slug, _ = getDungeonSlug()
    local optLadder = typeof(getOptimalDungeonForAlts) == "function" and getOptimalDungeonForAlts() or nil
    local is175Plus = (slug == "enchanted_forest") or (optLadder and optLadder.req and optLadder.req >= 175)
    if not is175Plus then return end -- ONLY LEVEL 175+

    if efDeathRetryActive then return end
    if (tick() - efLastRetryTime) < 8.0 then return end

    efDeathRetryActive = true
    efWasAlive = false -- Disarm immediately to prevent any looping
    efLastRetryTime = tick()

    task.spawn(function()
        print(string.format("[Maki EF 💀] Carry died in Enchanted Forest (175+)! In-place dungeon replay initiated (%s)...", tostring(reason or "unspecified")))

        -- Ensure Host Auto-Replay is ON
        local hostSetAutoReplay = remotes and remotes:FindFirstChild("hostSetAutoReplay")
        if hostSetAutoReplay then
            pcall(function() hostSetAutoReplay:FireServer(true) end)
        end

        pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hum and hrp then
                hum:MoveTo(hrp.Position)
            end
        end)

        pcall(function()
            if typeof(executeUniversalAutoSell) == "function" then
                executeUniversalAutoSell()
            end
        end)

        matchStartUnlockTime = 0
        currentWpIndex = 1
        mhcCurrentIndex = 1
        efCurrentWpIndex = 1
        efTreeKilledThisRun = false
        efTreeSpawnDetected = false
        efTreeHitsLanded = 0
        efShortcutActive = false
        efShortcutIdx = 1
        efRoom5ShortcutDone = false
        efBossHitsLanded = 0
        efIsCastingCombo = false

        -- 1. Fire Remote with complete Dungeon Data (Always Hardcore)
        local data = collectDungeonData()
        data.hardcore = true
        data.isHardcore = true
        if replayRemote then
            pcall(function() replayRemote:FireServer(data) end)
            pcall(function() replayRemote:FireServer({ isHardcore = true, hardcore = true }) end)
            pcall(function() replayRemote:FireServer("bossKilled") end)
            pcall(function() replayRemote:FireServer() end)
        end
        if readyUpRemote then
            pcall(function() readyUpRemote:FireServer() end)
        end

        -- 2. Click In-Place Replay GUI Buttons
        local pG = LocalPlayer:FindFirstChild("PlayerGui")
        if pG then
            -- Host panel replay button
            local hostReplay = pG:FindFirstChild("hostPanel", true)
            if hostReplay then
                local rBtn = hostReplay:FindFirstChild("replay", true)
                local tBtn = rBtn and rBtn:FindFirstChild("TextButton")
                if tBtn and tBtn:IsA("GuiButton") then
                    pcall(function()
                        for _, c in ipairs(getconnections(tBtn.Activated)) do c:Fire() end
                        for _, c in ipairs(getconnections(tBtn.MouseButton1Click)) do c:Fire() end
                    end)
                end
            end

            -- Confirmation dialog confirm button
            local replayConfirm = pG:FindFirstChild("ReplayConfirmation", true)
            if replayConfirm then
                local conf = replayConfirm:FindFirstChild("confirm", true)
                local cBtn = conf and conf:FindFirstChild("TextButton")
                if cBtn and cBtn:IsA("GuiButton") then
                    pcall(function()
                        for _, c in ipairs(getconnections(cBtn.Activated)) do c:Fire() end
                        for _, c in ipairs(getconnections(cBtn.MouseButton1Click)) do c:Fire() end
                    end)
                end
            end

            -- Defeat / Victory Menu replay button
            local menuGui = pG:FindFirstChild("Menu", true)
            if menuGui then
                local rBtn = menuGui:FindFirstChild("replayButton", true)
                local tBtn = rBtn and (rBtn:IsA("GuiButton") and rBtn or rBtn:FindFirstChild("TextButton"))
                if tBtn and tBtn:IsA("GuiButton") then
                    pcall(function()
                        for _, c in ipairs(getconnections(tBtn.Activated)) do c:Fire() end
                        for _, c in ipairs(getconnections(tBtn.MouseButton1Click)) do c:Fire() end
                    end)
                end
            end
        end

        task.wait(8.0)
        efDeathRetryActive = false
    end)
end

local function bindCarryDeathWatcher(char)
    if not isCarry then return end -- ONLY FOR CARRY! ALTS IGNORED
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 8)
    if not hum then return end

    local charAlive = (type(hum.Health) == "number" and hum.Health > 0)

    hum.Died:Connect(function()
        if isCarry and isDungeon() and charAlive and isMatchUnlocked() then
            local slug, _ = getDungeonSlug()
            local optLadder = typeof(getOptimalDungeonForAlts) == "function" and getOptimalDungeonForAlts() or nil
            local is175Plus = (slug == "enchanted_forest") or (optLadder and optLadder.req and optLadder.req >= 175)
            if is175Plus then
                triggerEFDeathRetry("Humanoid.Died event")
            end
        end
    end)

    hum.HealthChanged:Connect(function(hp)
        if type(hp) == "number" and hp > 0 then
            charAlive = true
        end
        if isCarry and isDungeon() and charAlive and type(hp) == "number" and hp <= 0 and isMatchUnlocked() then
            local slug, _ = getDungeonSlug()
            local optLadder = typeof(getOptimalDungeonForAlts) == "function" and getOptimalDungeonForAlts() or nil
            local is175Plus = (slug == "enchanted_forest") or (optLadder and optLadder.req and optLadder.req >= 175)
            if is175Plus then
                triggerEFDeathRetry(string.format("Health <= 0 (%.1f)", hp))
            end
        end
    end)
end

--  [MODULE 8-B] 1:1 ENCHANTED FOREST MASTER AUTO-FARM ENGINE
--  Ported 1:1 from maki_enchanted_forest_master.luau (Exact Behavior Match)
--  Features:
--    * Safe Collision Engine (stripEFCollision): purges tree/leaf/barrier collision
--    * 1,015 Centerline Waypoints with 5-waypoint curve lookahead
--    * Zone 1 (110-115s): Pre-buff Q on the run (+80% speed & damage)
--    * Zone 2 (85s): Safe Standoff Guard outside mob aggro line when E/Q on CD
--    * Zone 3 (<= 82s / 75s in room6): Backline AoE 1-Shot Combo (Halt, Aim, Buff Q, Fire E)
--    * Room 5 Ancient Tree Spawn Guard (isWaitingSpawn) & 98s Strike Range
--    * Room 5 Stone Platform Bump Bypass (8 SHORTCUT_POINTS + Velocity Jump Watchdog)
--    * Boss Combat: Crystal Golem, Ancient Enchanted Tree, Enchanted Forest Dragon
-- ========================================================================

local EF_SHORTCUT_POINTS = {
    Vector3.new(-671.1, -24.4, 290.1),
    Vector3.new(-730.0, -26.0, 290.0),
    Vector3.new(-780.0, -27.5, 310.0),
    Vector3.new(-815.0, -27.5, 360.0),
    Vector3.new(-815.0, -27.5, 410.0),
    Vector3.new(-800.0, -27.0, 460.0),
    Vector3.new(-825.0, -25.0, 490.0),
    Vector3.new(-837.5, -24.5, 505.1)
}

local EF_ROOM_ORDER = {"room1", "room2", "room3", "room4", "room5", "room6", "bossRoom"}
local EF_BOSS_ROOMS = {room2 = true, room5 = true, bossRoom = true}
local EF_BOSS_NAMES = {["Crystal Golem"] = true, ["Ancient Enchanted Tree"] = true, ["Enchanted Forest Dragon"] = true}
local EF_PACK_CLUSTER_THRESHOLD = 30
local EF_Q_BUFF_DURATION = 4.0

local efLastQCastTime = 0
local efCurrentWpIndex = 1
local efTreeKilledThisRun = false
local efTreeSpawnDetected = false
local efTreeHitsLanded = 0
local efShortcutActive = false
local efShortcutIdx = 1
local efRoom5ShortcutDone = false
local efBossHitsLanded = 0
local efIsCastingCombo = false
local efLastStripWallsTime = 0

local EF_EMBEDDED_WAYPOINTS = --[[EMBED_START]]



{



    {109.05,7.84,-46.66},{107.02,7.85,-46.56},{104.96,7.99,-46.47},{102.89,7.94,-46.37},{100.90,7.92,-46.28},{98.77,7.97,-46.18},{96.72,7.76,-46.09},{94.73,7.05,-46.11},



    {92.67,7.16,-46.15},{90.68,6.43,-46.18},{88.56,6.36,-46.18},{86.63,5.36,-46.17},{84.63,4.99,-46.17},{82.57,5.09,-46.17},{80.50,5.02,-46.17},{78.37,5.02,-46.16},



    {76.24,5.02,-46.16},{74.10,5.02,-46.16},{72.10,5.01,-46.16},{69.97,5.01,-46.15},{67.90,5.01,-46.15},{65.84,5.01,-46.15},{63.77,5.01,-46.15},{61.57,5.12,-46.15},



    {59.44,5.11,-46.17},{57.38,5.04,-46.18},{55.31,5.04,-46.19},{53.24,5.04,-46.19},{51.24,5.00,-46.20},{49.24,5.01,-46.21},{47.18,5.01,-46.21},{45.04,5.01,-46.20},



    {42.91,5.02,-46.19},{40.78,5.16,-46.19},{38.78,5.20,-46.18},{36.91,4.50,-46.18},{34.87,4.52,-46.18},{32.84,4.95,-46.18},{30.84,4.99,-46.17},{28.71,4.99,-46.19},



    {26.71,4.99,-46.23},{24.71,4.99,-46.26},{22.71,4.99,-46.29},{20.65,5.07,-46.33},{18.66,5.19,-46.36},{16.59,5.14,-46.40},{14.42,4.98,-46.43},{12.42,4.99,-46.47},



    {10.22,4.99,-46.49},{8.02,4.96,-46.49},{6.06,4.60,-46.49},{3.89,4.24,-46.48},{1.75,4.51,-46.48},{-0.22,4.92,-46.48},{-2.22,5.15,-46.48},{-4.31,5.19,-46.47},



    {-6.31,4.95,-46.47},{-8.31,4.99,-46.46},{-10.41,4.99,-46.43},{-12.61,4.99,-46.40},{-14.71,4.99,-46.37},{-16.81,4.99,-46.33},{-18.81,4.99,-46.29},{-20.99,5.24,-46.24},



    {-23.18,5.21,-46.20},{-25.37,4.98,-46.16},{-27.37,4.99,-46.12},{-29.56,4.98,-46.08},{-31.56,5.06,-46.04},{-33.56,4.70,-46.00},{-35.66,4.59,-45.96},{-37.65,4.96,-45.92},



    {-39.74,5.16,-45.87},{-41.74,4.90,-45.80},{-43.74,4.98,-45.69},{-45.83,4.99,-45.57},{-47.83,4.99,-45.46},{-49.83,4.99,-45.35},{-51.92,4.99,-45.23},{-53.92,4.99,-45.12},



    {-56.02,4.99,-45.01},{-58.11,4.99,-44.89},{-60.21,5.10,-44.79},{-62.41,5.14,-44.69},{-64.40,4.98,-44.61},{-66.40,4.99,-44.55},{-68.50,4.99,-44.50},{-70.60,4.99,-44.45},



    {-72.70,4.99,-44.39},{-74.80,4.99,-44.34},{-76.90,4.99,-44.29},{-79.10,4.99,-44.24},{-81.30,5.06,-44.20},{-83.30,5.18,-44.17},{-85.30,5.19,-44.15},{-87.40,5.05,-44.14},



    {-89.40,4.99,-44.14},{-91.60,4.99,-44.14},{-93.70,4.99,-44.15},{-95.80,4.99,-44.15},{-98.00,4.99,-44.15},{-100.20,4.99,-44.15},{-102.30,4.99,-44.15},{-104.29,5.20,-44.17},



    {-106.49,5.05,-44.20},{-108.49,4.99,-44.22},{-110.59,4.99,-44.26},{-112.59,5.01,-44.31},{-114.59,5.07,-44.37},{-116.69,4.99,-44.43},{-118.78,5.01,-44.50},{-120.88,5.28,-44.56},



    {-123.06,5.11,-44.64},{-125.16,4.99,-44.71},{-127.26,4.99,-44.78},{-129.26,4.99,-44.85},{-131.26,4.99,-44.92},{-133.35,4.99,-45.00},{-135.35,4.99,-45.07},{-137.45,4.99,-45.14},



    {-139.45,4.99,-45.21},{-141.45,4.99,-45.28},{-143.51,4.62,-45.35},{-145.57,4.28,-45.42},{-147.65,4.46,-45.50},{-149.83,4.78,-45.59},{-151.82,4.97,-45.68},{-153.92,4.99,-45.78},



    {-155.92,4.99,-45.87},{-158.11,5.11,-45.97},{-160.10,5.19,-46.07},{-162.10,5.04,-46.16},{-164.19,4.99,-46.26},{-166.19,4.99,-46.36},{-168.39,4.94,-46.47},{-170.56,4.62,-46.57},



    {-172.75,4.55,-46.68},{-174.84,4.66,-46.78},{-176.92,4.93,-46.88},{-178.92,4.99,-46.98},{-180.92,4.99,-47.07},{-183.01,4.99,-47.18},{-185.21,4.95,-47.28},{-187.29,4.71,-47.38},



    {-189.38,4.61,-47.49},{-191.58,4.71,-47.59},{-193.71,4.25,-47.69},{-195.77,4.01,-47.79},{-197.77,4.50,-47.89},{-199.74,4.91,-47.99},{-201.74,4.96,-48.08},{-203.84,4.97,-48.18},



    {-205.94,4.99,-48.29},{-208.03,4.93,-48.39},{-210.23,4.90,-48.49},{-212.32,4.79,-48.60},{-214.33,4.16,-48.69},{-216.49,4.05,-48.80},{-218.62,4.55,-48.90},{-220.61,4.81,-49.00},



    {-222.60,4.90,-49.09},{-224.68,4.66,-49.20},{-226.87,4.54,-49.30},{-228.96,4.56,-49.40},{-231.05,4.43,-49.50},{-233.12,4.56,-49.61},{-235.18,4.74,-49.71},{-237.16,4.45,-49.80},



    {-239.22,4.42,-49.90},{-241.27,4.66,-50.00},{-243.25,4.92,-50.10},{-245.31,4.99,-50.20},{-247.31,4.98,-50.29},{-249.38,4.99,-50.39},{-251.50,4.84,-50.50},{-253.62,4.72,-50.60},



    {-255.68,4.83,-50.70},{-257.75,4.67,-50.80},{-259.91,4.44,-50.91},{-261.77,3.28,-51.00},{-263.75,2.60,-51.09},{-265.81,1.80,-51.19},{-267.37,0.45,-51.27},{-269.46,0.34,-51.37},



    {-271.54,0.03,-51.47},{-273.19,-1.17,-51.55},{-274.97,-2.12,-51.69},{-277.05,-2.25,-51.91},{-278.93,-2.92,-52.11},{-280.38,-4.34,-52.27},{-282.46,-4.51,-52.50},{-284.44,-4.72,-52.72},



    {-286.22,-5.84,-52.92},{-288.01,-6.77,-53.11},{-290.09,-6.92,-53.34},{-292.07,-7.16,-53.56},{-293.75,-8.24,-53.75},{-295.54,-9.24,-53.94},{-297.62,-9.36,-54.16},{-299.70,-9.60,-54.36},



    {-301.39,-10.67,-54.53},{-303.17,-11.83,-54.70},{-305.15,-12.10,-54.89},{-306.78,-13.32,-55.05},{-308.84,-14.05,-55.24},{-310.82,-14.21,-55.43},{-312.70,-15.08,-55.61},{-314.28,-16.37,-55.75},



    {-316.46,-16.44,-55.96},{-318.55,-16.62,-56.16},{-320.53,-17.57,-56.35},{-322.12,-18.82,-56.51},{-324.30,-18.89,-56.72},{-326.38,-19.04,-56.93},{-328.27,-19.71,-57.11},{-329.76,-21.11,-57.26},



    {-331.74,-21.49,-57.45},{-333.53,-22.43,-57.63},{-335.11,-23.65,-57.79},{-337.29,-23.74,-58.00},{-339.28,-23.97,-58.20},{-341.46,-24.03,-58.41},{-343.54,-23.79,-58.62},{-345.63,-23.41,-58.81},



    {-347.67,-22.88,-58.96},{-349.66,-22.68,-59.06},{-351.66,-22.57,-59.11},{-353.76,-22.61,-59.14},{-355.96,-22.71,-59.17},{-358.03,-23.00,-59.14},{-360.03,-23.69,-59.11},{-362.19,-24.07,-59.07},



    {-364.26,-24.39,-59.04},{-366.36,-24.42,-58.99},{-368.46,-24.42,-58.94},{-370.56,-24.42,-58.88},{-372.76,-24.41,-58.81},{-374.85,-24.27,-58.75},{-376.95,-24.13,-58.70},{-378.94,-24.39,-58.65},



    {-381.04,-24.41,-58.62},{-383.14,-24.41,-58.68},{-385.21,-24.41,-59.02},{-387.29,-24.41,-59.60},{-389.21,-24.41,-60.16},{-391.16,-24.41,-60.84},{-393.05,-24.41,-61.51},{-394.99,-24.41,-62.20},



    {-396.89,-24.41,-62.85},{-398.85,-24.41,-63.49},{-400.88,-24.35,-64.13},{-402.79,-24.27,-64.73},{-404.77,-24.25,-65.33},{-406.80,-24.16,-65.96},{-408.75,-24.07,-66.57},{-410.76,-24.12,-67.18},



    {-412.86,-24.22,-67.83},{-414.96,-24.29,-68.48},{-416.96,-24.33,-68.50},{-418.79,-24.39,-67.48},{-420.52,-24.41,-66.29},{-421.80,-24.41,-64.53},{-422.59,-24.41,-62.56},{-424.18,-24.41,-61.04},



    {-425.69,-24.41,-59.45},{-427.13,-24.41,-57.92},{-428.64,-24.41,-56.32},{-430.08,-24.41,-54.79},{-431.52,-24.41,-53.26},{-433.03,-24.42,-51.66},{-434.54,-24.41,-50.06},{-435.98,-24.36,-48.53},



    {-437.42,-24.34,-47.00},{-438.92,-24.28,-45.40},{-440.30,-24.27,-43.95},{-441.69,-24.27,-42.24},{-442.99,-24.21,-40.59},{-444.29,-24.12,-38.95},{-445.65,-24.11,-37.22},{-446.95,-24.25,-35.58},



    {-448.26,-24.27,-33.93},{-449.62,-24.27,-32.21},{-450.92,-24.27,-30.56},{-452.23,-24.27,-28.91},{-453.59,-24.30,-27.19},{-454.83,-24.51,-25.63},{-456.07,-24.73,-24.07},{-457.37,-24.30,-22.43},



    {-458.61,-24.12,-20.86},{-459.85,-24.29,-19.30},{-461.15,-24.37,-17.65},{-462.39,-24.42,-16.08},{-463.63,-24.41,-14.51},{-464.93,-24.41,-12.87},{-466.24,-24.41,-11.22},{-467.54,-24.41,-9.57},



    {-468.90,-24.36,-7.85},{-470.13,-24.09,-6.30},{-471.43,-24.05,-4.65},{-472.73,-24.20,-3.01},{-474.00,-23.98,-1.40},{-475.34,-23.57,0.29},{-476.57,-23.39,1.86},{-477.90,-23.64,3.58},



    {-479.09,-24.17,5.11},{-480.35,-24.55,6.73},{-481.64,-24.52,8.39},{-482.92,-24.42,10.05},{-484.25,-24.31,11.79},{-485.52,-24.23,13.46},{-486.73,-24.57,15.06},{-487.93,-24.74,16.65},



    {-489.18,-24.55,18.29},{-490.45,-24.34,19.99},{-491.66,-24.22,21.66},{-492.84,-24.10,23.35},{-494.01,-24.15,25.05},{-495.20,-23.93,26.79},{-496.31,-23.63,28.43},{-497.45,-23.72,30.15},



    {-498.61,-24.07,31.90},{-499.75,-24.42,33.67},{-500.86,-24.41,35.41},{-501.94,-24.41,37.10},{-503.08,-24.41,38.87},{-504.23,-24.41,40.63},{-505.37,-24.41,42.38},{-506.52,-24.41,44.14},



    {-507.65,-24.75,45.87},{-508.85,-25.00,47.70},{-509.99,-24.95,49.44},{-511.12,-24.57,51.16},{-512.31,-24.62,52.97},{-513.36,-25.30,54.56},{-514.51,-25.03,56.32},{-515.57,-24.41,57.93},



    {-516.72,-24.38,59.68},{-517.87,-24.51,61.43},{-519.02,-24.64,63.19},{-520.23,-24.72,65.02},{-521.38,-24.65,66.78},{-522.53,-24.66,68.53},{-523.68,-24.16,70.28},{-524.76,-23.74,71.93},



    {-525.88,-24.23,73.63},{-527.02,-24.45,75.37},{-528.23,-24.59,77.20},{-529.43,-24.86,79.03},{-530.58,-24.94,80.78},{-531.72,-24.78,82.53},{-532.87,-24.58,84.28},{-534.74,-24.57,85.23},



    {-536.39,-24.41,84.03},{-538.00,-24.43,82.68},{-539.73,-24.41,81.39},{-541.81,-24.41,81.66},{-543.83,-24.41,82.07},{-545.14,-24.41,83.83},{-546.38,-24.41,85.52},{-547.53,-24.41,87.28},



    {-548.59,-24.41,89.21},{-549.52,-24.41,91.09},{-550.44,-24.41,92.97},{-551.41,-24.41,94.95},{-552.34,-24.41,96.83},{-553.26,-24.41,98.72},{-554.23,-24.41,100.69},{-555.16,-24.41,102.58},



    {-556.08,-24.41,104.46},{-557.00,-24.41,106.30},{-557.93,-24.41,108.17},{-558.87,-24.41,110.05},{-559.81,-24.42,111.93},{-560.78,-24.72,113.88},{-561.72,-24.91,115.74},{-562.66,-24.70,117.59},



    {-563.58,-24.50,119.36},{-564.56,-24.42,121.22},{-565.59,-24.41,123.16},{-566.57,-24.41,125.02},{-567.56,-24.41,126.87},{-568.61,-24.46,128.81},{-569.55,-24.55,130.56},{-570.55,-24.59,132.41},



    {-571.54,-24.41,134.25},{-572.49,-24.18,136.00},{-573.48,-24.02,137.84},{-574.43,-23.86,139.59},{-575.47,-23.87,141.53},{-576.46,-24.00,143.37},{-577.45,-23.95,145.22},{-578.47,-23.92,147.17},



    {-579.50,-23.91,149.12},{-579.96,-23.90,151.12},{-579.34,-24.10,153.09},{-580.10,-24.28,155.04},{-581.10,-24.42,156.88},{-582.06,-24.41,158.64},{-583.01,-24.41,160.40},{-584.01,-24.41,162.24},



    {-585.02,-24.54,164.08},{-586.04,-24.72,165.90},{-587.10,-24.75,167.71},{-588.19,-24.93,169.50},{-589.31,-24.89,171.27},{-590.46,-24.51,173.08},{-591.57,-24.01,174.78},{-592.71,-24.40,176.50},



    {-593.88,-24.59,178.23},{-595.09,-24.94,180.03},{-596.31,-24.81,181.85},{-597.46,-24.40,183.52},{-598.64,-24.02,185.22},{-599.79,-24.93,186.86},{-601.03,-25.27,188.59},{-602.25,-24.88,190.24},



    {-603.50,-24.82,191.93},{-604.75,-24.54,193.53},{-606.12,-23.95,195.02},{-607.52,-23.57,196.41},{-608.94,-23.36,197.81},{-610.41,-23.90,199.20},{-612.06,-24.39,200.56},{-613.77,-24.41,201.95},



    {-615.40,-24.41,203.27},{-617.03,-24.32,204.58},{-618.58,-24.17,205.84},{-620.28,-24.23,207.21},{-621.99,-24.42,208.58},{-623.72,-24.41,209.94},{-625.39,-24.41,211.22},{-626.99,-24.41,212.41},



    {-628.69,-24.41,213.64},{-630.42,-24.41,214.82},{-632.11,-24.41,215.90},{-633.87,-24.41,216.98},{-635.59,-24.41,218.00},{-637.39,-24.41,219.01},{-639.28,-24.41,219.99},{-641.14,-24.41,220.91},



    {-643.01,-24.41,221.78},{-644.90,-24.41,222.62},{-646.86,-24.41,223.46},{-648.78,-24.41,224.21},{-650.74,-24.41,224.87},{-652.71,-24.41,225.49},{-654.70,-24.41,226.05},{-656.63,-24.41,226.57},



    {-658.64,-24.41,227.06},{-660.59,-24.41,227.51},{-662.61,-24.41,227.96},{-664.69,-24.42,228.44},{-666.77,-24.43,228.91},{-668.85,-24.42,229.38},{-670.86,-24.41,229.84},{-672.81,-24.41,230.30},



    {-674.75,-24.41,230.77},{-676.76,-24.41,231.27},{-678.76,-24.41,231.77},{-680.70,-24.41,232.27},{-682.69,-24.41,232.83},{-684.61,-24.41,233.38},{-686.59,-24.34,233.94},{-688.63,-24.19,234.52},



    {-690.55,-24.64,235.07},{-692.49,-25.22,235.62},{-694.50,-25.41,236.19},{-696.52,-25.43,236.77},{-698.52,-25.27,237.34},{-700.48,-24.87,237.92},{-702.36,-24.41,238.47},{-704.37,-24.16,239.06},



    {-706.47,-24.25,239.68},{-708.58,-24.41,240.30},{-710.59,-24.42,240.89},{-712.61,-24.41,241.48},{-714.52,-24.41,242.05},{-716.44,-24.41,242.61},{-718.46,-24.41,243.21},{-720.38,-24.41,243.77},



    {-722.40,-24.41,244.35},{-724.32,-24.41,244.89},{-726.25,-24.41,245.43},{-728.27,-24.41,245.99},{-730.20,-24.41,246.52},{-732.13,-24.41,247.06},{-734.15,-24.41,247.62},{-736.08,-24.41,248.15},



    {-738.10,-24.41,248.71},{-740.03,-24.41,249.25},{-741.96,-24.41,249.78},{-743.89,-24.41,250.32},{-745.91,-24.41,250.88},{-747.84,-24.41,251.41},{-749.76,-24.41,251.95},{-751.79,-24.41,252.51},



    {-753.71,-24.41,253.05},{-755.64,-24.41,253.59},{-757.66,-24.41,254.17},{-759.67,-24.41,254.77},{-761.69,-24.37,255.36},{-763.80,-24.40,255.98},{-765.71,-24.41,256.55},{-767.73,-24.41,257.14},



    {-769.65,-24.41,257.70},{-771.57,-24.41,258.27},{-773.58,-24.41,258.86},{-775.50,-24.41,259.42},{-777.52,-24.41,260.01},{-779.44,-24.41,260.57},{-781.36,-24.41,261.13},{-783.37,-24.41,261.74},



    {-785.47,-24.41,262.38},{-787.48,-24.41,263.00},{-789.38,-24.41,263.61},{-791.38,-24.41,264.27},{-793.43,-24.41,265.05},{-795.45,-24.41,265.94},{-797.33,-24.41,266.87},{-799.18,-24.41,267.87},



    {-800.95,-24.41,268.99},{-802.63,-24.41,270.26},{-804.27,-24.41,271.72},{-805.76,-24.41,273.20},{-807.20,-24.41,274.73},{-808.62,-24.41,276.41},{-809.97,-24.41,278.14},{-811.19,-24.41,279.76},



    {-812.43,-24.41,281.41},{-813.64,-24.41,283.01},{-814.85,-24.41,284.60},{-816.18,-24.41,286.26},{-817.62,-24.41,287.84},{-819.04,-24.41,289.25},{-820.50,-24.41,290.71},{-821.92,-24.41,292.12},



    {-823.39,-24.41,293.58},{-824.94,-24.41,295.04},{-826.53,-24.41,296.46},{-828.14,-24.41,297.86},{-829.72,-24.41,299.21},{-831.39,-24.41,300.63},{-832.99,-24.41,301.99},{-834.59,-24.41,303.35},



    {-836.19,-24.41,304.71},{-837.79,-24.41,306.08},{-839.40,-24.41,307.58},{-840.90,-24.41,309.19},{-842.14,-24.41,310.88},{-843.18,-24.41,312.70},{-844.10,-24.40,314.70},{-844.70,-24.34,316.71},



    {-845.07,-24.29,318.77},{-845.22,-24.22,320.97},{-845.29,-24.15,322.96},{-845.36,-24.18,325.16},{-845.43,-24.22,327.26},{-845.50,-24.25,329.36},{-845.55,-24.34,331.56},{-845.57,-24.42,333.55},



    {-845.57,-24.41,335.55},{-845.53,-24.41,337.65},{-845.47,-24.41,339.75},{-845.40,-24.41,341.85},{-845.33,-24.41,343.95},{-845.26,-24.41,345.95},{-845.19,-24.41,347.95},{-845.03,-24.41,350.14},



    {-844.84,-24.41,352.13},{-844.65,-24.41,354.12},{-844.45,-24.41,356.21},{-844.26,-24.41,358.21},{-844.06,-24.41,360.30},{-843.87,-24.41,362.29},{-843.65,-24.41,364.48},{-843.45,-24.41,366.47},



    {-843.23,-24.41,368.55},{-843.00,-24.41,370.64},{-842.77,-24.41,372.73},{-842.54,-24.41,374.72},{-842.31,-24.41,376.70},{-842.08,-24.34,378.78},{-841.83,-24.03,380.94},{-841.61,-23.75,382.91},



    {-841.37,-23.89,385.08},{-841.18,-24.65,387.02},{-841.02,-24.78,389.08},{-840.90,-24.53,391.26},{-840.79,-24.40,393.26},{-840.68,-24.41,395.36},{-840.57,-24.41,397.45},{-840.46,-24.41,399.55},



    {-840.35,-24.41,401.75},{-840.23,-24.41,403.94},{-840.07,-24.41,406.04},{-839.74,-24.41,408.11},{-839.34,-24.39,410.17},{-838.82,-24.36,412.21},{-838.14,-24.38,414.30},{-837.18,-24.41,416.16},



    {-835.97,-24.41,417.88},{-834.79,-24.41,419.49},{-833.60,-24.41,421.10},{-832.26,-24.41,422.84},{-830.94,-24.50,424.47},{-829.57,-24.68,426.18},{-828.19,-24.85,427.88},{-826.80,-24.76,429.58},



    {-825.42,-24.44,431.25},{-824.16,-24.12,432.77},{-822.77,-24.24,434.47},{-821.51,-24.38,436.02},{-820.26,-24.42,437.57},{-818.94,-24.41,439.21},{-817.68,-24.41,440.76},{-816.29,-24.41,442.47},



    {-814.90,-24.41,444.17},{-813.51,-24.41,445.88},{-812.18,-24.41,447.50},{-810.85,-24.41,449.13},{-809.52,-24.41,450.75},{-808.15,-24.41,452.35},{-806.59,-24.41,453.90},{-804.74,-24.41,455.07},



    {-802.74,-24.41,455.69},{-800.72,-24.41,456.26},{-798.61,-24.53,456.87},{-796.60,-24.70,457.44},{-794.59,-24.58,458.00},{-792.66,-24.41,458.54},{-790.65,-24.27,459.09},{-788.64,-24.01,459.65},



    {-786.62,-24.06,460.20},{-784.71,-24.35,460.71},{-782.59,-24.43,461.28},{-780.66,-24.41,461.79},{-778.63,-24.41,462.33},{-776.69,-24.41,462.85},{-774.76,-24.41,463.36},{-772.73,-24.41,463.90},



    {-770.60,-24.41,464.44},{-768.56,-24.41,464.94},{-766.52,-24.41,465.44},{-764.48,-24.41,465.94},{-762.44,-24.41,466.44},{-760.30,-24.41,466.96},{-758.27,-24.41,467.46},{-756.23,-24.41,467.96},



    {-754.09,-24.41,468.49},{-751.95,-24.41,469.01},{-749.91,-24.41,469.51},{-747.87,-24.41,470.01},{-745.84,-24.41,470.51},{-743.79,-24.41,470.97},{-741.63,-24.41,471.43},{-739.48,-24.41,471.87},



    {-737.52,-24.41,472.26},{-735.56,-24.41,472.65},{-733.39,-24.41,473.02},{-731.40,-24.41,473.29},{-729.32,-24.41,473.55},{-727.23,-24.41,473.78},{-725.14,-24.41,473.88},{-723.04,-24.41,473.91},



    {-720.94,-24.41,473.58},{-718.96,-24.41,473.26},{-716.78,-24.41,472.92},{-714.61,-24.41,472.57},{-712.44,-24.41,472.23},{-710.36,-24.41,471.90},{-708.29,-24.41,471.57},{-706.32,-24.41,471.25},



    {-704.34,-24.41,470.93},{-702.27,-24.41,470.57},{-700.31,-24.41,470.21},{-698.24,-24.41,469.81},{-696.20,-24.41,469.33},{-694.17,-24.41,468.81},{-692.23,-24.41,468.29},{-690.30,-24.41,467.77},



    {-688.27,-24.41,467.22},{-686.34,-24.41,466.70},{-684.32,-24.41,466.15},{-682.38,-24.41,465.63},{-680.45,-24.41,465.11},{-678.43,-24.41,464.55},{-676.40,-24.41,464.00},{-674.39,-24.41,463.40},



    {-674.22,-24.41,461.37},{-675.55,-24.41,459.75},{-676.87,-24.41,458.12},{-678.43,-24.41,456.58},{-680.32,-24.38,455.68},{-682.32,-24.20,455.09},{-684.35,-23.95,454.66},{-686.37,-23.50,454.41},



    {-688.13,-22.51,454.48},{-689.56,-21.14,454.87},{-691.03,-19.95,455.54},{-692.84,-19.74,456.36},{-694.30,-20.97,456.99},{-695.84,-22.27,457.61},{-697.42,-23.63,458.26},{-699.43,-23.91,459.09},



    {-701.46,-23.96,459.92},{-703.31,-23.90,460.68},{-705.35,-23.97,461.51},{-707.20,-24.10,462.25},{-709.25,-24.22,463.04},{-711.22,-24.32,463.77},{-713.20,-24.31,464.46},{-715.29,-24.17,465.13},



    {-717.40,-24.18,465.74},{-719.52,-24.17,466.36},{-721.53,-24.20,466.94},{-723.56,-24.30,467.45},{-725.73,-24.40,467.85},{-727.79,-24.42,468.13},{-729.86,-24.41,468.26},{-731.92,-24.41,468.24},



    {-734.03,-24.41,467.93},{-736.10,-24.41,467.40},{-738.08,-24.41,466.82},{-740.09,-24.41,466.33},{-742.16,-24.41,465.81},{-744.15,-24.41,465.25},{-746.20,-24.41,464.68},{-748.19,-24.41,464.12},



    {-750.18,-24.35,463.57},{-752.17,-24.26,463.02},{-754.10,-24.19,462.49},{-756.09,-24.29,461.91},{-758.09,-24.32,461.01},{-759.79,-24.35,459.78},{-761.23,-24.20,458.15},{-762.20,-23.93,456.20},



    {-762.76,-23.86,454.17},{-764.86,-24.00,453.54},{-766.86,-24.21,452.96},{-768.88,-24.37,452.41},{-770.92,-24.37,451.91},{-773.00,-24.45,451.63},{-775.20,-24.49,451.63},{-777.27,-24.37,451.92},



    {-779.29,-24.42,452.49},{-781.21,-24.41,453.54},{-782.73,-24.41,454.99},{-784.22,-24.41,456.47},{-785.79,-24.41,458.01},{-787.26,-24.20,459.47},{-788.74,-23.98,460.95},{-790.08,-24.32,462.39},



    {-791.34,-24.60,464.05},{-792.63,-24.62,465.83},{-793.79,-24.64,467.46},{-795.01,-24.58,469.29},{-796.12,-24.92,471.04},{-797.18,-24.94,472.84},{-798.26,-24.89,474.75},{-799.26,-24.65,476.58},



    {-800.24,-25.02,478.40},{-801.23,-25.11,480.24},{-802.20,-24.88,482.08},{-803.12,-24.67,483.84},{-804.07,-24.80,485.66},{-805.04,-24.90,487.48},{-806.04,-24.84,489.29},{-807.04,-24.66,491.09},



    {-808.04,-24.50,492.89},{-809.05,-24.26,494.68},{-810.06,-24.13,496.47},{-811.08,-24.26,498.26},{-812.14,-24.37,500.11},{-813.17,-24.42,501.90},{-814.20,-24.41,503.70},{-815.20,-24.41,505.43},



    {-816.24,-24.44,507.21},{-817.31,-24.33,509.05},{-818.38,-24.31,510.90},{-819.44,-24.47,512.72},{-820.54,-24.38,514.62},{-821.55,-24.28,516.35},{-822.65,-24.26,518.24},{-823.71,-23.79,520.08},



    {-824.76,-23.66,521.89},{-825.82,-23.84,523.69},{-826.84,-24.14,525.39},{-827.93,-24.21,527.18},{-829.07,-24.10,529.05},{-830.15,-24.01,530.85},{-831.16,-24.40,532.53},{-832.24,-24.41,534.33},



    {-833.36,-24.41,536.23},{-834.36,-24.41,537.96},{-835.41,-24.41,539.78},{-836.42,-24.41,541.51},{-837.42,-24.41,543.24},{-838.47,-24.32,545.04},{-839.50,-23.90,546.80},{-840.54,-23.52,548.60},



    {-841.48,-24.24,550.22},{-842.43,-25.28,551.86},{-843.51,-24.96,553.71},{-844.50,-24.61,555.42},{-845.50,-24.43,557.14},{-846.56,-24.41,558.96},{-847.66,-24.40,560.87},{-848.70,-24.33,562.68},



    {-849.75,-24.40,564.50},{-850.84,-24.59,566.40},{-851.88,-24.66,568.22},{-852.92,-24.48,570.03},{-853.91,-24.25,571.75},{-855.00,-24.45,573.64},{-856.07,-24.86,575.51},{-857.16,-24.73,577.40},



    {-858.15,-24.47,579.12},{-859.15,-24.41,580.85},{-860.21,-24.41,582.66},{-861.28,-24.38,584.47},{-862.34,-24.39,586.28},{-863.34,-24.76,587.97},{-864.45,-24.95,589.86},{-865.48,-24.97,591.57},



    {-866.66,-24.88,593.42},{-867.78,-24.66,595.06},{-869.08,-24.64,596.71},{-870.54,-24.80,598.35},{-871.99,-24.90,599.86},{-873.51,-24.70,601.27},{-875.05,-24.45,602.54},{-876.80,-24.41,603.69},



    {-878.59,-24.41,604.79},{-880.39,-24.41,605.88},{-882.27,-24.41,607.01},{-884.07,-24.41,608.10},{-885.89,-24.32,609.13},{-887.76,-24.19,610.07},{-889.58,-24.69,610.99},{-891.38,-25.29,611.89},



    {-893.22,-25.39,612.82},{-895.07,-24.78,613.75},{-896.83,-24.35,614.63},{-898.80,-24.40,615.60},{-900.78,-24.42,616.57},{-902.58,-24.41,617.44},{-904.48,-24.40,618.34},{-906.38,-24.42,619.22},



    {-908.29,-24.50,620.09},{-910.23,-24.40,620.87},{-912.20,-24.28,621.61},{-914.07,-24.20,622.29},{-916.14,-24.11,623.04},{-918.12,-24.17,623.74},{-920.09,-24.33,624.44},{-922.16,-24.30,625.17},



    {-924.23,-24.38,625.91},{-926.30,-24.41,626.64},{-928.27,-24.41,627.37},{-930.24,-24.41,628.10},{-932.30,-24.41,628.87},{-934.17,-24.41,629.58},{-936.05,-24.41,630.28},{-938.01,-24.41,631.02},



    {-939.89,-24.41,631.72},{-941.85,-24.41,632.46},{-943.72,-24.41,633.16},{-945.60,-24.41,633.87},{-947.56,-24.41,634.60},{-949.44,-24.41,635.31},{-951.31,-24.41,636.01},{-953.27,-24.41,636.75},



    {-955.15,-24.41,637.45},{-957.02,-24.41,638.15},{-958.89,-24.42,638.86},{-960.86,-24.41,639.60},{-962.92,-24.41,640.37},{-964.79,-24.41,641.07},{-966.75,-24.38,641.81},{-968.80,-24.19,642.58},



    {-970.77,-24.24,643.32},{-972.73,-24.23,644.05},{-974.66,-23.90,644.78},{-976.62,-23.84,645.51},{-978.41,-24.48,646.18},{-980.30,-24.92,646.90},{-982.17,-24.94,647.60},{-984.23,-24.83,648.35},



    {-986.22,-24.67,649.00},{-988.28,-24.44,649.30},{-990.44,-24.16,649.58},{-992.42,-24.04,649.84},{-994.59,-24.06,650.19},{-996.52,-24.49,650.51},{-998.57,-24.76,650.85},{-1000.74,-24.87,651.21},



    {-1002.81,-24.83,651.55},{-1004.89,-24.72,651.74},{-1006.89,-24.16,651.78},{-1008.83,-23.44,651.69},{-1010.87,-23.66,651.60},{-1012.90,-24.02,651.48},{-1014.94,-24.32,651.33},{-1017.06,-24.42,651.19},



    {-1019.19,-24.41,651.05},{-1021.32,-24.41,650.94},{-1023.39,-24.40,650.85},{-1025.42,-24.69,650.75},{-1027.48,-24.78,650.65},{-1029.61,-24.83,650.54},{-1031.64,-24.56,650.42},{-1033.61,-24.20,650.30},



    {-1035.80,-24.30,650.17},{-1037.99,-24.34,650.03},{-1039.99,-24.31,649.91},{-1042.08,-24.19,649.78},{-1044.17,-24.06,649.65},{-1046.19,-23.67,649.53},{-1048.16,-22.99,649.42},{-1050.16,-22.28,649.31},



    {-1052.06,-21.60,649.20},{-1054.04,-20.90,649.08},{-1055.92,-20.23,648.98},{-1057.78,-19.49,648.87},{-1059.69,-18.89,648.76},{-1061.66,-18.19,648.65},{-1063.58,-17.46,648.54},{-1065.52,-16.80,648.43},



    {-1067.49,-16.12,648.32},{-1069.37,-15.45,648.21},{-1071.35,-14.75,648.10},{-1073.33,-14.05,647.98},{-1075.22,-13.38,647.87},{-1077.19,-12.67,647.75},{-1079.07,-12.00,647.64},{-1081.05,-11.30,647.53},



    {-1082.93,-10.63,647.41},{-1084.84,-9.94,647.30},{-1086.83,-9.24,647.18},{-1088.71,-8.58,647.07},{-1090.61,-7.90,646.96},{-1092.62,-7.18,646.84},{-1094.59,-6.49,646.73},{-1096.57,-5.78,646.62},



    {-1098.46,-5.11,646.51},{-1100.44,-4.41,646.40},{-1102.32,-3.74,646.30},{-1104.20,-3.07,646.19},{-1106.18,-2.37,646.09},{-1108.06,-1.70,645.98},{-1109.94,-1.03,645.88},{-1111.96,-0.30,645.77},



    {-1113.85,0.36,645.67},{-1115.92,1.10,645.56},{-1117.84,1.97,645.46},{-1119.73,2.70,645.37},{-1121.83,2.78,645.27},{-1123.93,2.78,645.17},{-1126.02,2.78,645.08},{-1128.22,2.78,644.99},



    {-1130.22,2.78,644.91},{-1132.22,2.78,644.82},{-1134.32,2.78,644.74},{-1136.32,2.78,644.66},{-1138.32,2.78,644.57},{-1140.42,2.78,644.49},{-1142.42,2.78,644.41},{-1144.52,2.78,644.32},



    {-1146.52,2.78,644.24},{-1148.52,2.78,644.16},{-1150.62,2.78,644.08},{-1152.62,2.78,644.01},{-1154.61,2.78,643.95},{-1156.71,2.78,643.89},{-1158.91,2.78,643.85},{-1160.94,2.78,643.82},



    {-1163.01,2.78,643.80},{-1165.14,2.78,643.77},{-1167.20,2.78,643.75},{-1169.27,2.78,643.73},{-1171.32,2.87,643.72},{-1173.27,3.69,643.74},{-1175.13,4.44,643.76},{-1177.16,4.96,643.79},



    {-1179.29,4.99,643.81},{-1181.42,4.99,643.84},{-1183.55,4.99,643.87},{-1185.64,4.59,643.90},{-1187.74,4.28,643.94},{-1189.77,4.67,643.98},{-1191.76,5.08,644.01},{-1193.76,5.11,644.05},



    {-1195.96,5.11,644.09},{-1198.06,5.11,644.12},{-1200.16,5.11,644.16},{-1202.36,5.11,644.20},{-1204.46,5.11,644.24},{-1206.56,5.07,644.27},{-1208.56,4.99,644.30},{-1210.76,4.99,644.34},



    {-1212.96,4.99,644.38},{-1214.96,5.00,644.45},{-1217.05,5.09,644.56},{-1219.05,5.11,644.67},{-1221.05,5.11,644.78},{-1223.05,5.11,644.90},{-1225.04,5.11,645.01},{-1227.14,5.11,645.12},



    {-1229.24,5.02,645.23},{-1231.33,4.99,645.33},{-1233.43,4.99,645.43},{-1235.63,4.99,645.53},{-1237.82,4.99,645.63},{-1239.92,4.99,645.73},{-1242.02,4.99,645.83}



}



--[[EMBED_END]]

local function stripEFCollision()
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
                if n:find("barrier") or n:find("border") or n:find("tree") or n:find("leave") or pName:find("tree") or pName:find("leave") then
                    d.CanCollide = false
                elseif not d.CanCollide and (n:find("platform") or n:find("floor") or n:find("plunge") or n:find("bridge")) then
                    d.CanCollide = true
                end
            end
        end
    end
end

local function isEFQBuffActive()
    return (tick() - efLastQCastTime) < EF_Q_BUFF_DURATION
end

local function getEFToolBySlot(slotName)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            local s = t:FindFirstChild("abilitySlot") or t:FindFirstChild("slot") or t:FindFirstChild("Slot")
            if s and tostring(s.Value):lower() == slotName:lower() then return t end
        end
    end
    if char then
        for _, t in ipairs(char:GetChildren()) do
            local s = t:FindFirstChild("abilitySlot") or t:FindFirstChild("slot") or t:FindFirstChild("Slot")
            if s and tostring(s.Value):lower() == slotName:lower() then return t end
        end
    end
    return nil
end

local function isEFQReady()
    local t = getEFToolBySlot("q")
    if not t then return false end
    local cd = t:FindFirstChild("cooldown")
    return cd and cd.Value <= 0.05
end

local function isEFEReady()
    local t = getEFToolBySlot("e")
    if not t then return false end
    local cd = t:FindFirstChild("cooldown")
    local char = LocalPlayer.Character
    local busy = char and char:FindFirstChild("busyCasting")
    return cd and cd.Value <= 0.05 and (busy == nil or busy.Value == false)
end

local function getEFQCDRemaining()
    local t = getEFToolBySlot("q")
    local cd = t and t:FindFirstChild("cooldown")
    return cd and math.max(0, cd.Value) or 0
end

local function getEFECDRemaining()
    local t = getEFToolBySlot("e")
    local cd = t and t:FindFirstChild("cooldown")
    return cd and math.max(0, cd.Value) or 0
end

local function castEFQ()
    local t = getEFToolBySlot("q")
    if t and isEFQReady() then
        local le = t:FindFirstChild("localEvent")
        if le then
            pcall(function() le:Fire() end)
        else
            local ae = t:FindFirstChild("abilityEvent")
            if ae then pcall(function() ae:FireServer() end) end
        end
        if typeof(castSlot) == "function" then
            pcall(function() castSlot("q", t) end)
        end
        efLastQCastTime = tick()
        return true
    end
    return false
end

local function castEFE()
    local t = getEFToolBySlot("e")
    if t and isEFEReady() then
        local le = t:FindFirstChild("localEvent")
        if le then
            pcall(function() le:Fire() end)
        else
            local ae = t:FindFirstChild("abilityEvent")
            if ae then pcall(function() ae:FireServer() end) end
        end
        if typeof(castSlot) == "function" then
            pcall(function() castSlot("e", t) end)
        end
        return true
    end
    return false
end

local function getEFTargetCluster(myPos)
    local dung = Workspace:FindFirstChild("dungeon")
    if not dung then return nil end
    for _, rName in ipairs(EF_ROOM_ORDER) do
        local r = dung:FindFirstChild(rName)
        if r and r:FindFirstChild("enemyFolder") then
            local isBossZone = EF_BOSS_ROOMS[rName] or false
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

            -- Room 5 Ancient Tree Spawn Guard
            if rName == "room5" then
                if efTreeKilledThisRun then
                    continue
                end
                if #aliveMobs > 0 then
                    efTreeSpawnDetected = true
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
                    if efTreeHitsLanded > 0 then
                        efTreeKilledThisRun = true
                        continue
                    else
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
                if isBossZone or EF_BOSS_NAMES[aliveMobs[1].name] then
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
                    -- Connected Components Clustering (PACK_CLUSTER_THRESHOLD = 30)
                    local n = #aliveMobs
                    local adj = {}
                    for i = 1, n do adj[i] = {} end
                    for i = 1, n do
                        for j = i + 1, n do
                            local pA = aliveMobs[i].pos
                            local pB = aliveMobs[j].pos
                            local dx = pA.X - pB.X
                            local dz = pA.Z - pB.Z
                            if (dx * dx + dz * dz) <= (EF_PACK_CLUSTER_THRESHOLD * EF_PACK_CLUSTER_THRESHOLD) then
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

local function findClosestEFWaypointIndex(pos, points, startIdx, endIdx)
    local total = #points
    local s = math.max(1, startIdx or 1)
    local e = math.min(total, endIdx or total)
    local bestIdx = s
    local minD = 999999
    for i = s, e do
        local wp = points[i]
        if wp then
            local p = Vector3.new(wp.x or wp[1], wp.y or wp[2], wp.z or wp[3])
            local d = (p - pos).Magnitude
            if d < minD then
                minD = d
                bestIdx = i
            end
        end
    end
    return bestIdx, minD
end

local function execute1to1EnchantedForest(char, hrp, hum, myPos, waypoints)
    if efDeathRetryActive then return end
    local isDead = (hum and hum.Health <= 0) or (hrp and hrp.Position.Y < -80) or (hum and hum:GetState() == Enum.HumanoidStateType.Dead)
    if isDead then
        triggerEFDeathRetry(string.format("EF 1:1 isDead check (HP: %.1f, Y: %.1f)", (hum and hum.Health or -1), (hrp and hrp.Position.Y or 0)))
        return
    end
    if efIsCastingCombo then return end
    local now = tick()
    local totalWps = #waypoints
    if totalWps == 0 then return end

    -- Safe Collision Engine: run periodically every 3.5s
    if (now - efLastStripWallsTime) >= 3.5 then
        efLastStripWallsTime = now
        pcall(stripEFCollision)
    end

    -- Run-start variable reset (spawn area is X > 50)
    if myPos.X > 50 then
        efTreeKilledThisRun = false
        efTreeSpawnDetected = false
        efTreeHitsLanded = 0
        efShortcutActive = false
        efShortcutIdx = 1
        efRoom5ShortcutDone = false
    end

    local inRoom5Shortcut = efTreeKilledThisRun and not efRoom5ShortcutDone and myPos.Z < 504 and myPos.X < -630
    local target = getEFTargetCluster(myPos)

    -- If Room 6 mobs are visible and near doorway, finish shortcut immediately
    if not efRoom5ShortcutDone and target and target.room == "room6" and myPos.Z >= 480 then
        efRoom5ShortcutDone = true
        inRoom5Shortcut = false
        efShortcutActive = false
        efCurrentWpIndex = findClosestEFWaypointIndex(myPos, waypoints, 760, 810)
    end

    -- Highway Waypoint Index update (bypassed during straight shortcut)
    if not inRoom5Shortcut then
        local curWp = waypoints[efCurrentWpIndex]
        local curPos = curWp and Vector3.new(curWp.x or curWp[1], curWp.y or curWp[2], curWp.z or curWp[3]) or myPos
        local distToCurrent = (curPos - myPos).Magnitude
        if distToCurrent > 80 then
            efCurrentWpIndex = findClosestEFWaypointIndex(myPos, waypoints, 1, totalWps)
        else
            local searchStart = math.max(1, efCurrentWpIndex - 3)
            local searchEnd = math.min(totalWps, efCurrentWpIndex + 25)
            local bestIdx = efCurrentWpIndex
            local bestDist = 999999
            for i = searchStart, searchEnd do
                local wp = waypoints[i]
                if wp then
                    local p = Vector3.new(wp.x or wp[1], wp.y or wp[2], wp.z or wp[3])
                    local d = (p - myPos).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestIdx = i
                    end
                end
            end
            efCurrentWpIndex = bestIdx
        end

        curWp = waypoints[efCurrentWpIndex]
        curPos = curWp and Vector3.new(curWp.x or curWp[1], curWp.y or curWp[2], curWp.z or curWp[3]) or myPos
        if (curPos - myPos).Magnitude < 14 then
            efCurrentWpIndex = math.min(totalWps, efCurrentWpIndex + 1)
        end
    end

    -- Sync global display index
    mhcCurrentIndex = efCurrentWpIndex

    local lookaheadIdx = math.min(totalWps, efCurrentWpIndex + 5)
    local targetWp = waypoints[lookaheadIdx] or waypoints[efCurrentWpIndex]
    local targetPos = targetWp and Vector3.new(targetWp.x or targetWp[1], targetWp.y or targetWp[2], targetWp.z or targetWp[3]) or myPos

    if inRoom5Shortcut then
        -- Anti-stuck watchdog: hop over any lip or bump automatically
        if hum.MoveDirection.Magnitude > 0.1 and hrp.AssemblyLinearVelocity.Magnitude < 3 then
            hum.Jump = true
        end

        if not efShortcutActive then
            efShortcutActive = true
            local bestIdx = 1
            local bestDist = 999999
            for i, pt in ipairs(EF_SHORTCUT_POINTS) do
                local d = (pt - myPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestIdx = i
                end
            end
            efShortcutIdx = math.min(#EF_SHORTCUT_POINTS, bestIdx + 1)
        end

        local targetPt = EF_SHORTCUT_POINTS[efShortcutIdx]
        if (myPos - targetPt).Magnitude <= 14 then
            if efShortcutIdx < #EF_SHORTCUT_POINTS then
                efShortcutIdx = efShortcutIdx + 1
                targetPt = EF_SHORTCUT_POINTS[efShortcutIdx]
            else
                efRoom5ShortcutDone = true
                efShortcutActive = false
                efCurrentWpIndex = findClosestEFWaypointIndex(myPos, waypoints, 760, 810)
                mhcCurrentIndex = efCurrentWpIndex
            end
        end

        if not efRoom5ShortcutDone then
            hum.AutoRotate = true
            if isEFQReady() then castEFQ() end
            hum:MoveTo(targetPt)
            if (myPos - EF_SHORTCUT_POINTS[#EF_SHORTCUT_POINTS]).Magnitude <= 14 or myPos.Z >= 504 then
                efRoom5ShortcutDone = true
                efShortcutActive = false
                efCurrentWpIndex = findClosestEFWaypointIndex(myPos, waypoints, 760, 810)
                mhcCurrentIndex = efCurrentWpIndex
            end
        end
    elseif target then
        if target.isBoss then
            if target.isWaitingSpawn then
                hum:MoveTo(myPos)
                hum.AutoRotate = false
                local lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)
                if isEFQReady() then castEFQ() end
            else
                local bossDist = target.dist
                local isTree = (target.name == "Ancient Enchanted Tree")
                local strikeThreshold = isTree and 98 or 82

                -- Pre-buff Q on the run at 165 studs
                if bossDist <= 165 and isEFQReady() then
                    castEFQ()
                end

                if bossDist <= strikeThreshold then
                    hum:MoveTo(myPos)
                    hum.AutoRotate = false
                    local lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                    hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)
                    local eReady = isEFEReady()
                    local qBuff = isEFQBuffActive()
                    local qReady = isEFQReady()

                    if eReady then
                        if not qBuff and qReady then
                            castEFQ()
                            task.wait(0.12)
                            qBuff = isEFQBuffActive()
                        end
                        if qBuff then
                            efIsCastingCombo = true
                            lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                            hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)
                            castEFE()
                            efBossHitsLanded = efBossHitsLanded + 1
                            if isTree then
                                efTreeHitsLanded = efTreeHitsLanded + 1
                                if target.hum and target.hum.Health <= 0 then
                                    efTreeKilledThisRun = true
                                end
                            end
                            task.wait(0.6)
                            efIsCastingCombo = false
                        end
                    end
                else
                    hum.AutoRotate = true
                    if isTree then
                        local dir = (target.centerPos - myPos).Unit
                        local approachPos = target.centerPos - dir * 92
                        hum:MoveTo(approachPos)
                    else
                        hum:MoveTo(targetPos)
                    end
                end
            end
        else
            -- Normal Pack Logic (1:1 3-Zone Architecture)
            local minDist = target.minDist
            local backDist = target.backlineDist
            local wipeDist = (target.room == "room6") and 75 or 82

            -- ZONE 3: AoE WIPE ZONE (Room 6 uses 75 studs; other rooms use 82 studs)
            if backDist <= wipeDist then
                hum:MoveTo(myPos)
                hum.AutoRotate = false
                local lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)
                local eReady = isEFEReady()
                local qBuff = isEFQBuffActive()
                local qReady = isEFQReady()

                if eReady then
                    if not qBuff and qReady then
                        castEFQ()
                        task.wait(0.12)
                        qBuff = isEFQBuffActive()
                    end
                    if qBuff then
                        efIsCastingCombo = true
                        lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                        hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)
                        castEFE()
                        task.wait(0.5)
                        efIsCastingCombo = false
                    end
                end
            -- ZONE 2: SAFE STANDOFF GUARD (Stop at 85 studs if E is on CD or Q buff is not active and Q is on CD)
            elseif minDist <= 85 and ((not isEFEReady()) or (not isEFQBuffActive() and not isEFQReady())) then
                hum:MoveTo(myPos)
                hum.AutoRotate = false
                local lookPos = Vector3.new(target.centerPos.X, hrp.Position.Y, target.centerPos.Z)
                hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)
                local eCd = getEFECDRemaining()
                if isEFQReady() and (eCd <= 1.2 or isEFEReady()) then
                    castEFQ()
                end
            -- ZONE 1 & HIGHWAY ADVANCE: NEVER LEAVE RECORDED HIGHWAY WAYPOINTS!
            else
                hum.AutoRotate = true
                local eCd = getEFECDRemaining()
                if isEFQReady() and minDist <= 115 and (eCd <= 1.5 or isEFEReady()) then
                    castEFQ()
                end
                hum:MoveTo(targetPos)
            end
        end
    else
        -- ZONE 4: EMPTY HIGHWAY (> 150 studs or no mobs alive)
        hum.AutoRotate = true
        if isEFQReady() then
            castEFQ()
        end
        hum:MoveTo(targetPos)
    end
end

if LocalPlayer.Character then
    bindCarryDeathWatcher(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(newChar)
    bindCarryDeathWatcher(newChar)
    local slug, _ = getDungeonSlug()
    if slug == "enchanted_forest" then
        if isCarry and isDungeon() and isMatchUnlocked() and efCurrentWpIndex > 100 and not efDeathRetryActive then
            print(string.format("[Maki EF 💀] CharacterAdded mid-run respawn detected (WP %d)! Triggering retry...", efCurrentWpIndex))
            triggerEFDeathRetry(string.format("CharacterAdded mid-run respawn (WP %d)", efCurrentWpIndex))
            return
        end
        efRoom5ShortcutDone = false
        efShortcutActive = false
        efShortcutIdx = 1
        efIsCastingCombo = false
        pcall(stripEFCollision)
    end
end)


-- MHC Execution Loop (Levels 145+ Natural Speed & Direct Dungeon Activation)
local mhcCurrentIndex = 1
                        efCurrentWpIndex = 1
                        efTreeKilledThisRun = false
                        efTreeSpawnDetected = false
                        efTreeHitsLanded = 0
                        efShortcutActive = false
                        efShortcutIdx = 1
                        efRoom5ShortcutDone = false
                        efBossHitsLanded = 0
                        efIsCastingCombo = false
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

            -- ANY CAUSE OF DEATH CHECK (Only check during an active, unlocked match!)
            if isMatchUnlocked() and hrp and hum then
                local isDead = (hum.Health <= 0) or (hrp.Position.Y < -80) or (hum:GetState() == Enum.HumanoidStateType.Dead)
                if isDead then
                    local slug, _ = getDungeonSlug()
                    if slug == "enchanted_forest" then
                        triggerEFDeathRetry(string.format("MHC loop isDead check (HP: %.1f, Y: %.1f)", hum.Health, hrp.Position.Y))
                        task.wait(0.2)
                        continue
                    end
                end
            end

            if hrp and hum and hum.Health > 0 then
                if not isMatchUnlocked() then
                    lastMhcPosBeforeTick = nil
                    hum:MoveTo(hrp.Position)
                    task.wait(0.05)
                else
                local myPos = hrp.Position
                local now = os.clock()

                local slug, _ = getDungeonSlug()
                local fileName = string.format("dqr_highway_%s.json", slug)
                local raw = safeReadFile(fileName)
                if (not raw or #raw == 0) and slug == "enchanted_forest" then
                    pcall(function()
                        raw = game:HttpGet("https://raw.githubusercontent.com/MayyAlterrr/maki-suite/main/dqr_highway_enchanted_forest.json")
                        if raw and #raw > 0 then safeWriteFile(fileName, raw) end
                    end)
                end

                if raw and #raw > 0 then
                    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
                    local waypoints = (ok and parsed and (parsed.points or parsed)) or {}

                    -- Automatic fallback to embedded 1,015 waypoints for Enchanted Forest
                    if slug == "enchanted_forest" and (#waypoints < 1000) then
                        waypoints = EF_EMBEDDED_WAYPOINTS
                    end

                    if #waypoints > 0 then
                        if slug == "enchanted_forest" then
                            -- Level 175+ Mid-Run Death Spawn Guard: If deep in the dungeon (past Room 2, WP > 100) and suddenly back at the spawn platform, retry!
                            local efSpawnPos = Vector3.new(109.05, 7.84, -46.66)
                            if efCurrentWpIndex > 100 and (myPos - efSpawnPos).Magnitude < 25.0 and not efDeathRetryActive then
                                print(string.format("[Maki EF 💀] Carry respawned back at spawn from WP %d (DistToSpawn: %.1f)! Triggering retry...", efCurrentWpIndex, (myPos - efSpawnPos).Magnitude))
                                triggerEFDeathRetry(string.format("Mid-run respawn at spawn from WP %d", efCurrentWpIndex))
                                continue
                            end

                            -- Position jump handler: if position jumps by 28+ studs mid-run (e.g. dash/shortcut/sync), resync to closest WP instead of false retry!
                            if lastMhcPosBeforeTick and (myPos - lastMhcPosBeforeTick).Magnitude >= 28.0 then
                                local closestIdx, cDist = findClosestWaypointIndex(myPos, waypoints)
                                if closestIdx then
                                    efCurrentWpIndex = closestIdx
                                    print(string.format("[Maki EF 🛡️] Position jump (%.1fs) resynced to WP %d (Dist: %.1fs)", (myPos - lastMhcPosBeforeTick).Magnitude, closestIdx, cDist))
                                end
                            end
                            lastMhcPosBeforeTick = myPos

                            execute1to1EnchantedForest(char, hrp, hum, myPos, waypoints)
                        else
                            -- Standard MHC for other dungeons (Aquatic Temple, Orbital Outpost, Volcanic Chambers)
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
                                local heightDiff = math.abs(myPos.Y - targetGroup.center.Y)
                                local effectiveAoELimit = (heightDiff > 12.0) and 50.0 or 82.0

                                if targetGroup.farthestDist <= 110.0 and qReady then
                                    mhcLastQTime = now
                                    castSlot("q", qTool)
                                end

                                if targetGroup.farthestDist <= effectiveAoELimit then
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
                                if qReady and (now - mhcLastQTime) >= 1.5 then
                                    mhcLastQTime = now
                                    castSlot("q", qTool)
                                end

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

            -- Auto-liquidate Boss Raid items (+1 to +30)
            local isBossRaidItem = (itemName:find("^%+%d+") ~= nil or itemKey:find("raid"))
            if isBossRaidItem and not isEquipped then
                protected = false
            end

            if not protected then
                local idNum = tonumber(string.sub(itemKey, #keyPrefix + 1)) or tonumber(string.match(itemKey, "%d+"))
                if idNum then
                    table.insert(itemsToSell[category], idNum)
                    -- Anti-dupe key formatting required by official Ui.sellShop for raid items
                    local compositeKey = string.format("%d:%s", idNum, tostring(item.id or itemKey))
                    table.insert(itemsToSell[category], compositeKey)
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

-- ========================================================================
--  [MODULE 5B] DYNAMIC GOLD GAMEPASS BUYER ENGINE
--  Priority Order: 1. 2xGold -> 2. +1 Drops -> 3. VIP -> 4. Stat Reset
--  Queries live server price dynamically (never hardcodes fixed gold amount)
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
    return math.min(maxTier, 30)
end

local TargetGamepassOrder = {
    { id = "goldGamepass",      name = "2x Gold",           displayName = "x2 Gold" },
    { id = "extraItemGamepass",  name = "+1 Drops",          displayName = "+1 Item" },
    { id = "vip",               name = "VIP",               displayName = "VIP" },
    { id = "freeStatResets",    name = "Stat Reset",        displayName = "Free Resets" },
}

local ownedGamepassesCache = {}

local function getAccountGold()
    if getGoldAmountRemote then
        local ok, g = pcall(function() return getGoldAmountRemote:InvokeServer() end)
        if ok and tonumber(g) then return tonumber(g) end
    end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local gVal = ls and (ls:FindFirstChild("Gold") or ls:FindFirstChild("gold"))
    if gVal and tonumber(gVal.Value) then return tonumber(gVal.Value) end
    local gDirect = LocalPlayer:FindFirstChild("gold") or LocalPlayer:FindFirstChild("Gold")
    if gDirect and tonumber(gDirect.Value) then return tonumber(gDirect.Value) end
    return 0
end

local function isGamepassOwned(passId)
    if ownedGamepassesCache[passId] then return true end

    -- 1. Check direct bool value in LocalPlayer
    local pVal = LocalPlayer:FindFirstChild(passId)
    if pVal and (pVal:IsA("BoolValue") and pVal.Value == true) then
        ownedGamepassesCache[passId] = true
        return true
    end

    -- 2. Check gamepasses subfolder if exists
    local gFolder = LocalPlayer:FindFirstChild("gamepasses") or LocalPlayer:FindFirstChild("passes") or LocalPlayer:FindFirstChild("ownedGamepasses")
    if gFolder then
        local subVal = gFolder:FindFirstChild(passId)
        if subVal and (subVal:IsA("BoolValue") and subVal.Value == true) then
            ownedGamepassesCache[passId] = true
            return true
        end
    end

    -- 3. Check Shop UI confirmation
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        local sGui = pG:FindFirstChild("shopGui") or pG:FindFirstChild("ShopGui") or pG:FindFirstChild("Shop")
        if sGui then
            for _, d in ipairs(sGui:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local txt = d.Text:lower()
                    local dName = d.Name:lower()
                    if (dName:find(passId:lower()) or txt:find(passId:lower())) and (txt:find("owned") or txt:find("purchased")) then
                        ownedGamepassesCache[passId] = true
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function getLiveGamepassPrice(passId)
    if getGoldGamepassPriceRemote then
        local ok, res = pcall(function() return getGoldGamepassPriceRemote:InvokeServer(passId) end)
        if ok and type(res) == "table" and res.cost then
            return tonumber(res.cost), res.owned == true, res.level
        end
    end

    -- Fallback: inspect Shop GUI
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        local sGui = pG:FindFirstChild("shopGui") or pG:FindFirstChild("ShopGui") or pG:FindFirstChild("Shop")
        if sGui then
            for _, d in ipairs(sGui:GetDescendants()) do
                if d:IsA("TextLabel") and d.Visible then
                    local parent = d.Parent
                    local parentName = parent and parent.Name:lower() or ""
                    if parentName:find(passId:lower()) or (d.Name:lower():find("price") or d.Name:lower():find("cost")) then
                        local costNum = tonumber(d.Text:gsub("%D", ""))
                        if costNum and costNum > 1000000 then
                            return costNum, false, nil
                        end
                    end
                end
            end
        end
    end

    return 8400000000, false, nil
end

local function purchaseGamepassByRemote(passId)
    local remote = remotes and (remotes:FindFirstChild("requestGoldGamepassPurchase") or remotes:FindFirstChild("buyGamepass") or remotes:FindFirstChild("purchaseGamepass") or remotes:FindFirstChild("buyGamepassGold") or remotes:FindFirstChild("buyPass"))
    if not remote then return false, "No buy remote" end
    local ok, res = pcall(function()
        return remote:InvokeServer(passId)
    end)
    if ok and (res == true or res == "success" or res == nil) then
        return true
    end
    local ok2 = pcall(function()
        remote:FireServer(passId)
    end)
    return ok2
end

local function purchaseGamepassByShopUI(targetPass)
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if not pG then return false end

    local sGui = pG:FindFirstChild("shopGui") or pG:FindFirstChild("ShopGui") or pG:FindFirstChild("Shop")
    if not sGui then return false end

    for _, obj in ipairs(sGui:GetDescendants()) do
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local objName = obj.Name:lower()
            local objText = obj:IsA("TextButton") and obj.Text:lower() or ""
            local parentName = obj.Parent and obj.Parent.Name:lower() or ""

            local match = false
            if objName:find(targetPass.id:lower()) or parentName:find(targetPass.id:lower()) then match = true end
            if objText:find(targetPass.name:lower()) or parentName:find(targetPass.name:lower()) then match = true end
            if targetPass.displayName and objText:find(targetPass.displayName:lower()) then match = true end

            if match and obj.Visible then
                pcall(function()
                    for _, c in ipairs(getconnections(obj.Activated)) do c:Fire() end
                    for _, c in ipairs(getconnections(obj.MouseButton1Click)) do c:Fire() end
                end)
                return true
            end
        end
    end
    return false
end

local isBuyingGamepasses = false
local function executeSequentialGamepassBuyer()
    if isBuyingGamepasses or not isMainLobby() then return end
    isBuyingGamepasses = true

    task.spawn(function()
        local curGold = getAccountGold()

        for stepIndex, pass in ipairs(TargetGamepassOrder) do
            local liveCost, isServerOwned, reqLvl = getLiveGamepassPrice(pass.id)
            if isServerOwned then ownedGamepassesCache[pass.id] = true end

            if not isGamepassOwned(pass.id) then
                print(string.format("[Maki Gamepass Buyer 🛒] Step %d: %s (%s) | Server Price: %.2fB Gold (Req Lv: %s)...",
                    stepIndex, pass.name, pass.id, liveCost / 1000000000, tostring(reqLvl or "145")))

                if curGold < liveCost then
                    print(string.format("[Maki Gamepass Buyer ⏳] Need %.2fB gold for %s. Current Gold: %.2fB. Waiting for next sell cycle.",
                        liveCost / 1000000000, pass.name, curGold / 1000000000))
                    break
                end

                print(string.format("[Maki Gamepass Buyer 💎] Purchasing %s with %.2fB Gold (Price: %.2fB)!",
                    pass.name, curGold / 1000000000, liveCost / 1000000000))
                local purchased = purchaseGamepassByRemote(pass.id)
                if not purchased then
                    purchaseGamepassByShopUI(pass)
                end

                task.wait(1.5)
                ownedGamepassesCache[pass.id] = nil
                if isGamepassOwned(pass.id) then
                    print(string.format("[Maki Gamepass Buyer ✅] Successfully purchased & confirmed %s!", pass.name))
                    curGold = getAccountGold()
                else
                    print(string.format("[Maki Gamepass Buyer ⚠️] Purchase sent for %s. Re-checking next cycle.", pass.name))
                    break
                end
            else
                print(string.format("[Maki Gamepass Buyer 🟢] Step %d: %s is already OWNED!", stepIndex, pass.name))
            end
        end

        isBuyingGamepasses = false
    end)
end

local function carryCreateAndLaunch()
    if not isCarry or not isMainLobby() or isCreatingLobby then return end
    isCreatingLobby = true

    loadConfig()

    local bestLadder, curLvl, altName = getOptimalDungeonForAlts()
    local dName = bestLadder.dungeon
    local dDiff = bestLadder.diff
    local dReq  = bestLadder.req
    if bestLadder.slug == "enchanted_forest" then
        dReq = 175
    end

    Config.CurrentDungeon = dName
    Config.CurrentDiff    = dDiff
    saveConfig()

    -- Check if we are in Boss Raid mode (Level 130-144)
    if bestLadder.slug == "boss_raid" then
        local highestTier = getHighestUnlockedTier()
        Config.CurrentDungeon = "Boss Raids"
        Config.CurrentDiff = string.format("Tier %d", highestTier)
        saveConfig()

        print(string.format("[Maki Host] 👑 Creating Boss Raid Lobby: Tier %d (Private)...", highestTier))
        local ok, res = pcall(function()
            if createBossLobbyRemote then
                return createBossLobbyRemote:InvokeServer(highestTier, true, 0)
            end
            return false
        end)

        if ok and res == true then
            print("[Maki Host] ✅ Boss Raid Lobby Created! Whitelisting Alts...")
            if addPlayerToBossWhitelistRemote then
                for _, name in ipairs(Config.AltUsernames) do
                    pcall(function() addPlayerToBossWhitelistRemote:FireServer(name) end)
                    task.wait(0.01)
                end
            end
            if changeStartValueRemote then pcall(function() changeStartValueRemote:FireServer() end) end
            task.wait(0.2)
            if startBossRaidRemote then pcall(function() startBossRaidRemote:FireServer() end) end
            task.wait(3.0)
            isCreatingLobby = false
        else
            warn("[Maki Host] ❌ Boss Raid Lobby creation failed: " .. tostring(res))
            task.wait(2.0)
            isCreatingLobby = false
        end
        return
    end

    Config.HardcoreMode = true
    print(string.format("[Maki Host] 🏰 Creating Target Staging Lobby: %s (%s) [Lowest: %s Lv %d, Req: %d] | Hardcore: true...",
        dName, dDiff, altName, curLvl, dReq))

    local ok, res = pcall(function()
        return createLobbyRemote:InvokeServer(dName, dDiff, dReq, true, true, false)
    end)
    if not ok or res ~= true then
        pcall(function()
            local ok2, res2 = pcall(function()
                return createLobbyRemote:InvokeServer(dName, dDiff, true, true)
            end)
            if ok2 and res2 == true then
                ok = true
                res = true
            end
        end)
    end

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
-- ========================================================================
-- ========================================================================
--  [MODULE 5] MASTER PROGRESSION, AUTO-START & HARDCORE DEFEAT REPLAY
-- ========================================================================
local returnToLobbyTriggered = false
local lobbyVerificationActive = false

returnPartyToLobby = function()
    if returnToLobbyTriggered then return end
    returnToLobbyTriggered = true
    print("[Maki Progression] 🚀 Returning party to Main Lobby to restart dungeon...")

    pcall(function()
        if typeof(writefile) == "function" then
            writefile("maki_retry_flag.txt", "retry")
        end
    end)

    saveConfig()

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

local function areAllAltsInDungeon()
    loadConfig()
    local altList = Config.AltUsernames or {}
    if #altList == 0 then
        return true, 0, 0
    end

    local loadedCount = 0
    for _, altName in ipairs(altList) do
        local cleanName = tostring(altName):gsub("%s+", ""):lower()
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower() == cleanName then
                local char = p.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
                if hrp then
                    getLivePlayerLevel(p.Name)
                    loadedCount = loadedCount + 1
                end
                break
            end
        end
    end

    return (loadedCount >= #altList), loadedCount, #altList
end

local function triggerCarryStartBossRaid()
    if matchStartUnlockTime == 0 then
        matchStartUnlockTime = os.clock() + 3.8
        print("[Maki Staging 👑] Boss Raid Staging start triggered! Holding position for 3.8s countdown & barrier drop...")
    end
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        local bQ = pG:FindFirstChild("bossQueueGui")
        local sBtn = bQ and bQ:FindFirstChild("lobbyInfo") and bQ.lobbyInfo:FindFirstChild("startButton", true)
        if sBtn then
            pcall(function()
                for _, c in ipairs(getconnections(sBtn.Activated)) do c:Fire() end
                for _, c in ipairs(getconnections(sBtn.MouseButton1Click)) do c:Fire() end
                for _, c in ipairs(getconnections(sBtn.MouseButton1Down)) do c:Fire() end
            end)
        end
        for _, btn in ipairs(pG:GetDescendants()) do
            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                local bName = btn.Name:lower()
                local bText = btn:IsA("TextButton") and btn.Text:lower() or ""
                if bName:find("start") or bText:find("start") or bName:find("ready") or bText:find("ready") then
                    pcall(function()
                        for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                        for _, c in ipairs(getconnections(btn.MouseButton1Down)) do c:Fire() end
                    end)
                end
            end
        end
    end

    if startBossRaidRemote then pcall(function() startBossRaidRemote:FireServer() end) end
    if startDungeonRemote then pcall(function() startDungeonRemote:FireServer() end) end
    if changeStartValueRemote then pcall(function() changeStartValueRemote:FireServer() end) end
    executeInstantReadyUp()
end

local function triggerCarryStartDungeon()
    local engine = getCurrentDungeonEngine()
    if engine == "bossraid" then
        triggerCarryStartBossRaid()
        return
    end

    if matchStartUnlockTime == 0 then
        matchStartUnlockTime = os.clock() + 3.8
        lastMhcPosBeforeTick = nil
        print("[Maki Staging ⏳] Staging start triggered! Holding position for 3.8s countdown & barrier drop...")
    end
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        local sBtn1 = pG:FindFirstChild("startButton") and pG.startButton:FindFirstChild("TextButton", true)
        if sBtn1 then
            pcall(function()
                for _, c in ipairs(getconnections(sBtn1.Activated)) do c:Fire() end
                for _, c in ipairs(getconnections(sBtn1.MouseButton1Click)) do c:Fire() end
                for _, c in ipairs(getconnections(sBtn1.MouseButton1Down)) do c:Fire() end
            end)
        end
        local qG = pG:FindFirstChild("queueGui")
        local sBtn2 = qG and qG:FindFirstChild("lobbyInfo") and qG.lobbyInfo:FindFirstChild("startButton", true)
        if sBtn2 then
            pcall(function()
                for _, c in ipairs(getconnections(sBtn2.Activated)) do c:Fire() end
                for _, c in ipairs(getconnections(sBtn2.MouseButton1Click)) do c:Fire() end
                for _, c in ipairs(getconnections(sBtn2.MouseButton1Down)) do c:Fire() end
            end)
        end
        for _, btn in ipairs(pG:GetDescendants()) do
            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                local bName = btn.Name:lower()
                local bText = btn:IsA("TextButton") and btn.Text:lower() or ""
                if bName:find("start") or bText:find("start") or bName:find("ready") or bText:find("ready") then
                    pcall(function()
                        for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                        for _, c in ipairs(getconnections(btn.MouseButton1Down)) do c:Fire() end
                    end)
                end
            end
        end
    end

    if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
    if startDungeonRemote then pcall(function() startDungeonRemote:FireServer() end) end
    if changeStartValueRemote then pcall(function() changeStartValueRemote:FireServer() end) end
    executeInstantReadyUp()
end

-- Staging Room Auto-Start & Alt Synchronization Watcher Loop
local isStagingStarted = false
task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.3)
        if isDungeon() then
            local engine = getCurrentDungeonEngine()
            local prog = getDungeonProgress()
            local isPreStart = (prog == "active" or prog == "notstarted" or prog == "staging" or prog == "playersnotready" or prog:find("ready") or prog == "" or not prog)
            local pG = LocalPlayer:FindFirstChild("PlayerGui")
            local qG = pG and (pG:FindFirstChild("queueGui") or pG:FindFirstChild("bossQueueGui"))
            local sBtn = (pG and pG:FindFirstChild("startButton", true)) or (qG and qG:FindFirstChild("startButton", true))

            if isCarry then
                -- Auto-approve any pending join requests in staging
                if Config.AutoAcceptJoins and pG then
                    for _, c in ipairs(pG:GetChildren()) do
                        if c.Name == "joinRequestConfirm" then
                            instantAcceptAndDestroyPopup(c)
                        end
                    end
                    if respondJoinRequestRemote and Config.AltUsernames then
                        for _, altName in ipairs(Config.AltUsernames) do
                            if not Players:FindFirstChild(altName) then
                                pcall(function() respondJoinRequestRemote:FireServer(altName, true) end)
                            end
                        end
                    end
                end

                if not isStagingStarted and (engine == "bossraid" or (qG and qG.Enabled) or (sBtn and sBtn.Visible) or prog == "playersnotready" or prog:find("ready")) then
                    local allReady, loadedCount, totalAlts = areAllAltsInDungeon()
                    if allReady then
                        isStagingStarted = true
                        print(string.format("[Maki Staging] 👥 100%% of Alts loaded in %s Room! Starting Encounter & Readying Up...", engine == "bossraid" and "Boss Raid" or "Dungeon"))
                        triggerCarryStartDungeon()
                    else
                        print(string.format("[Maki Staging ⏳] Waiting for Alts to load (%d/%d loaded)...", loadedCount, totalAlts))
                    end
                end
            else
                -- Alt: Lock spawn and ready up instantly (1:1 with maki_boss_raid_v3.1.lua)
                if not altSpawnPosition then
                    lockAltSpawn()
                end
                executeInstantReadyUp()
            end
        else
            isStagingStarted = false
        end
    end
end)

-- ========================================================================
--  NEXT TIER / REPLAY ENGINE (1:1 MATCH WITH MAKI BOSS RAID V3.1)
-- ========================================================================
local function getCurrentRaidTier()
    local dObj = Workspace:FindFirstChild("dungeon")
    local tVal = dObj and (dObj:FindFirstChild("tier") or dObj:FindFirstChild("raidTier"))
    if tVal and tVal:IsA("IntValue") and tVal.Value > 0 then
        return tVal.Value
    end

    local dName = Workspace:FindFirstChild("dungeonName")
    if dName and dName:IsA("StringValue") then
        local tMatch = dName.Value:match("[Tt]ier%s*(%d+)")
        if tMatch and tonumber(tMatch) then
            return tonumber(tMatch)
        end
    end

    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        for _, desc in ipairs(pG:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible and desc.Text then
                local tMatch = desc.Text:match("[Tt]ier%s*(%d+)")
                if tMatch and tonumber(tMatch) then
                    return tonumber(tMatch)
                end
            end
        end
    end

    return Config.CurrentTier or 1
end

local function isRaidFinished()
    local prog = getDungeonProgress()
    if prog == "bosskilled" or prog == "victory" or prog == "complete" or prog == "dungeoncomplete" then
        return true
    end

    -- isRaidFinished heuristics are STRICTLY for Boss Raids! Never run on standard dungeons/MHC
    local engine = getCurrentDungeonEngine()
    if engine ~= "bossraid" then
        return false
    end

    if prog:find("won") or prog:find("win") then
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

local isProcessingReplay = false
local function handleNextTierAndReplay()
    if isProcessingReplay then return end
    isProcessingReplay = true

    task.spawn(function()
        local curTier = getCurrentRaidTier()
        print(string.format("[Maki Replay] ⚡ Boss Defeated in Tier %d! Checking Next Tier vs Replay...", curTier))

        executeUniversalAutoSell()

        task.wait(1.5)

        local startTime = os.clock()
        while _G.MAKI_MASTER_SUITE_RUNNING and isDungeon() and (os.clock() - startTime < 12.0) do
            local pG = LocalPlayer:FindFirstChild("PlayerGui")
            local nextTierClicked = false

            -- 1. If tier < 30 and AutoNextTier is enabled: Click Next Tier button ONLY (do not fire Replay)
            if Config.AutoNextTier and curTier < 30 and pG then
                for _, gui in ipairs(pG:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled then
                        for _, btn in ipairs(gui:GetDescendants()) do
                            if btn:IsA("GuiButton") and btn.Visible then
                                local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                                local bName = btn.Name:lower()
                                if (bText:find("next") or bName:find("nexttier") or bName:find("next_tier") or bName:find("upgradetier")) and not bText:find("prev") then
                                    pcall(function()
                                        for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                                        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                                        for _, c in ipairs(getconnections(btn.MouseButton1Down)) do c:Fire() end
                                    end)
                                    if upgradeKeyRemote then
                                        pcall(function() upgradeKeyRemote:FireServer() end)
                                    end
                                    nextTierClicked = true
                                    print(string.format("[Maki Boss Raid 🌟] Advancing to Next Tier from Tier %d!", curTier))
                                    break
                                end
                            end
                        end
                    end
                    if nextTierClicked then break end
                end
            end

            -- 2. If at Max Tier (>= 30) OR if Next Tier button is not present, loop REPLAY over and over!
            if not nextTierClicked then
                if replayRemote then
                    pcall(function() replayRemote:FireServer() end)
                    pcall(function() replayRemote:FireServer({ isHardcore = true, hardcore = true }) end)
                end
                if readyUpRemote then
                    pcall(function() readyUpRemote:FireServer() end)
                end

                if pG then
                    for _, gui in ipairs(pG:GetChildren()) do
                        if gui:IsA("ScreenGui") and gui.Enabled then
                            for _, btn in ipairs(gui:GetDescendants()) do
                                if btn:IsA("GuiButton") and btn.Visible then
                                    local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                                    local bName = btn.Name:lower()
                                    if bText:find("replay") or bText:find("retry") or bName:find("replay") or bName:find("retry") or bName:find("playagain") then
                                        pcall(function()
                                            for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                                            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                                            for _, c in ipairs(getconnections(btn.MouseButton1Down)) do c:Fire() end
                                        end)
                                        print(string.format("[Maki Boss Raid 🔄] Replaying Max Tier %d!", curTier))
                                    end
                                end
                            end
                        end
                    end
                end
            end

            task.wait(0.4)
        end

        -- Failsafe: if still in finished raid after 12s, return to Main Lobby so carry re-hosts immediately
        if isDungeon() and _G.MAKI_MASTER_SUITE_RUNNING and isRaidFinished() then
            print("[Maki Replay] 🔄 Replay timed out after 12s, returning to Main Lobby to re-host...")
            returnPartyToLobby()
        end

        isProcessingReplay = false
    end)
end

-- Master Match State, Victory/Defeat Auto-Retry & Lobby Watcher
task.spawn(function()
    while _G.MAKI_MASTER_SUITE_RUNNING do
        task.wait(0.8)
        if isDungeon() then
            lobbyVerificationActive = false
            local prog = getDungeonProgress()

            if not isCarry then
                if not altSpawnPosition then
                    lockAltSpawn()
                end
                local carryPlayer = getCarryPlayer()
                if not carryPlayer and not altLobbyExitTriggered then
                    exitAltToMainLobby()
                end
            end

            -- ================================================================
            --  VICTORY CONDITION
            -- ================================================================
            local engine = getCurrentDungeonEngine()
            local isFinished = false
            if engine == "bossraid" then
                isFinished = (prog == "bosskilled" or prog == "victory" or prog == "complete" or isRaidFinished())
            else
                isFinished = (prog == "bosskilled" or prog == "victory" or prog == "complete" or prog == "dungeoncomplete")
            end

            if isFinished then
                executeUniversalAutoSell()

                if isCarry then
                    task.wait(2.0)
                    local currentLadder, altLvl, altName = getOptimalDungeonForAlts()
                    local slug, rawName = getDungeonSlug()
                    local curDungeon = (rawName and #rawName > 0) and rawName or (Config.CurrentDungeon or "Pirate Island")
                    local curDiff = Config.CurrentDiff or "Nightmare"

                    -- Keep Config updated with reality
                    Config.CurrentDungeon = curDungeon
                    Config.CurrentDiff = curDiff

                    local isUpgraded = false
                    if slug == "enchanted_forest" or curDungeon:lower():find("enchanted") or (currentLadder and currentLadder.slug == "enchanted_forest") then
                        -- Level 175+ (Enchanted Forest) is the absolute FINAL dungeon on the ladder!
                        -- There is NO higher dungeon. NEVER promote or return to lobby from Enchanted Forest!
                        isUpgraded = false
                    elseif engine == "bossraid" or curDungeon == "Boss Raids" or curDungeon:lower():find("raid") then
                        -- In Boss Raids (Levels 130-144), stay in the raid room clicking Next Tier / Replay!
                        -- ONLY upgrade & return to lobby when alts reach Level 145+ (promoting to Orbital Outpost)
                        isUpgraded = (currentLadder.dungeon ~= "Boss Raids" and not currentLadder.dungeon:lower():find("raid"))
                    else
                        isUpgraded = (currentLadder.dungeon ~= curDungeon) or (currentLadder.diff ~= curDiff)
                    end

                    if isUpgraded and Config.AutoProgression then
                        print(string.format("[Maki Progression] 🎉 %s reached Level %d! Promoting from %s (%s) ➔ %s (%s)...",
                            altName, altLvl, curDungeon, curDiff, currentLadder.dungeon, currentLadder.diff))
                        returnPartyToLobby()
                    else
                        if engine == "bossraid" then
                            handleNextTierAndReplay()
                        else
                            print(string.format("[Maki Progression] ⚡ Replaying %s (%s) in 2.5s...", curDungeon, curDiff))
                            task.wait(2.5)
                            local data = collectDungeonData()
                            if replayRemote then
                                pcall(function() replayRemote:FireServer(data) end)
                                pcall(function() replayRemote:FireServer() end)
                            end
                            if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end

                            local pG = LocalPlayer:FindFirstChild("PlayerGui")
                            if pG then
                                for _, name in ipairs({"ReplayDungeonButton", "replayButton", "retryButton", "replay", "retry"}) do
                                    local btn = pG:FindFirstChild(name, true)
                                    if btn and btn:IsA("GuiButton") and btn.Visible then
                                        pcall(function()
                                            for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                                            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                                        end)
                                    end
                                end
                            end

                            matchStartUnlockTime = 0
                            currentWpIndex = 1
                            mhcCurrentIndex = 1
                            efCurrentWpIndex = 1
                            efTreeKilledThisRun = false
                            efTreeSpawnDetected = false
                            efTreeHitsLanded = 0
                            efShortcutActive = false
                            efShortcutIdx = 1
                            efRoom5ShortcutDone = false
                            efBossHitsLanded = 0
                            efIsCastingCombo = false
                        end
                    end
                else
                    task.wait(2.8)
                    executeInstantReadyUp()
                end
            end

            -- ================================================================
            --  HARDCORE DEFEAT / WIPE REPLAY HANDLER
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
                        efCurrentWpIndex = 1
                        efTreeKilledThisRun = false
                        efTreeSpawnDetected = false
                        efTreeHitsLanded = 0
                        efShortcutActive = false
                        efShortcutIdx = 1
                        efRoom5ShortcutDone = false
                        efBossHitsLanded = 0
                        efIsCastingCombo = false
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
            efDeathRetryActive = false
            
            isPlaybackActive = false
            matchStartUnlockTime = 0
            currentWpIndex = 1
            mhcCurrentIndex = 1
                        efCurrentWpIndex = 1
                        efTreeKilledThisRun = false
                        efTreeSpawnDetected = false
                        efTreeHitsLanded = 0
                        efShortcutActive = false
                        efShortcutIdx = 1
                        efRoom5ShortcutDone = false
                        efBossHitsLanded = 0
                        efIsCastingCombo = false
            isStagingStarted = false
            isProcessingReplay = false

            -- Execute Dynamic Sequential Gold Gamepass Buyer in Lobby
            executeSequentialGamepassBuyer()

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

--  [MODULE 9] ENHANCED MULTI-TAB GUI (DASHBOARD, ALTS, DISCORD)
-- ========================================================================
local function initMasterGUI()
    local pGuiRef = getGuiParent()
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
    mainActionBtn.BackgroundColor3 = isCarry and Color3.fromRGB(0, 160, 120) or Color3.fromRGB(140, 80, 220)
    mainActionBtn.Text = isCarry and "🚀 LAUNCH CARRY LADDER" or "🛡️ ALT STANDBY (Auto-Sync Active)"
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

-- addAltBtn handled above

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
end
task.spawn(initMasterGUI)

print("[Project Maki 👑] Master Progression Suite V4.0 (Aquatic Temple Direct Route Fixed) LOADED!")
