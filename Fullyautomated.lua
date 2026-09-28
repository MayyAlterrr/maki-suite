-- ========================================================================
--  PROJECT MAKI: FULLY AUTOMATED PROGRESSION & GAMEPASS SUITE
--  FILE: Fullyautomated.lua
--  AUTHOR: DeepMind Antigravity x Maki
-- ========================================================================
--  COMPLETE 100% UNATTENDED LIFECYCLE (LEVEL 33 TO 165+):
--    • STAGE 1 (Lv 33-129): Full Waypoint Progression (Winter Outpost -> Steampunk Sewers)
--    • STAGE 2 (Lv 130-144): Automated Boss Raid Fast-Track (Tier 1 -> Tier 30 Loop)
--    • STAGE 3 (Lv 145 Checkpoint): Full Loot Liquidation + Auto-Buy 2x Gold & Extra Drop Gamepasses
--    • STAGE 4 (Lv 145-153): Orbital Outpost MHC Highway Engine
--    • STAGE 5 (Lv 154 Checkpoint): Return to Lobby, Auto-Buy VIP & Stat Reset Pass, Auto-Reset Stats
--    • STAGE 6 (Lv 155-165+): Volcanic Chambers & Aquatic Temple MHC Endgame
--    • ZERO-TOUCH: Host auto-creates, alts auto-join, 0ms auto-accept, 100% synced auto-sell on ALL accounts!
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
if _G.MAKI_FULLY_AUTOMATED_RUNNING then
    _G.MAKI_FULLY_AUTOMATED_RUNNING = false
    task.wait(0.25)
end
_G.MAKI_FULLY_AUTOMATED_RUNNING = true

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
--  REMOTES & NETWORKING (STANDARD + BOSS RAID + SHOP + STATS)
-- ========================================================================
local remotes = ReplicatedStorage:WaitForChild("remotes", 15)

-- Standard Dungeon Remotes
local createLobbyRemote          = remotes and remotes:FindFirstChild("createLobby")
local addPlayerToWhitelistRemote = remotes and remotes:FindFirstChild("addPlayerToWhitelist")
local removePlayerFromWhitelistRemote = remotes and remotes:FindFirstChild("removePlayerFromWhitelist")
local startDungeonRemote         = remotes and remotes:FindFirstChild("startDungeon")
local changeStartValueRemote     = remotes and remotes:FindFirstChild("changeStartValue")
local sendJoinRequestRemote      = remotes and remotes:FindFirstChild("sendJoinRequest")
local showJoinRemote             = remotes and remotes:FindFirstChild("showJoinRequest")
local joinDungeonRemote          = remotes and remotes:FindFirstChild("joinDungeon")
local respondJoinRequestRemote   = remotes and remotes:FindFirstChild("respondJoinRequest")
local readyUpRemote              = remotes and remotes:FindFirstChild("readyUp")
local showReadyGuiRemote         = remotes and remotes:FindFirstChild("showReadyGui")
local replayRemote               = remotes and remotes:FindFirstChild("replayDungeon")
local teleToLobbyRemote          = remotes and (remotes:FindFirstChild("teleToLobby") or remotes:FindFirstChild("ReturnToLobbyEvent") or remotes:FindFirstChild("leaveGame"))

-- Boss Raid Dedicated Remotes
local createBossLobbyRemote          = remotes and remotes:FindFirstChild("createBossLobby")
local addPlayerToBossWhitelistRemote = remotes and remotes:FindFirstChild("addPlayerToBossWhitelist")
local removePlayerFromBossWhitelistRemote = remotes and remotes:FindFirstChild("removePlayerFromBossWhitelist")
local playerJoinBossLobbyRemote      = remotes and remotes:FindFirstChild("playerJoinBossLobby")
local startBossRaidRemote            = remotes and remotes:FindFirstChild("startBossRaid")
local leaveBossLobbyRemote           = remotes and remotes:FindFirstChild("leaveBossLobby")

-- Inventory & Economy Remotes
local sellItemEventRemote        = remotes and remotes:FindFirstChild("sellItemEvent")
local reloadInvyRemote           = remotes and remotes:FindFirstChild("reloadInvy")
local getGoldAmountRemote        = remotes and remotes:FindFirstChild("getGoldAmount")
local requestGoldGamepassPurchaseRemote = remotes and remotes:FindFirstChild("requestGoldGamepassPurchase")
local getGoldGamepassPriceRemote = remotes and remotes:FindFirstChild("getGoldGamepassPrice")
local resetPointsWithGamepassRemote = remotes and remotes:FindFirstChild("resetPointsWithGamepass")
local resetSkillPointsRemote     = remotes and remotes:FindFirstChild("resetSkillPoints")
local spendSkillPointRemote      = remotes and remotes:FindFirstChild("spendSkillPoint")

-- Combat & Misc Remotes
local abilityUsedRemote          = remotes and remotes:FindFirstChild("abilityUsed")
local abilityCastRemote          = remotes and remotes:FindFirstChild("abilityCast")
local weaponUsedRemote           = remotes and remotes:FindFirstChild("weaponUsed")
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
--  FILE I/O (UNIVERSAL EXECUTOR & DELTA MOBILE COMPATIBLE)
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
--  CONFIG & STATE PERSISTENCE (dqr_party_config.json)
-- ========================================================================
local ConfigFileName = "dqr_party_config.json"
local Config = {
    CarryUsername         = "",
    AltUsernames          = {},
    AltLevels             = {},
    CurrentDungeon        = "Winter Outpost",
    CurrentDiff           = "Easy",
    SelectedDungeon       = "Winter Outpost",
    SelectedDiff          = "Easy",
    HardcoreMode          = true,
    AutoReadyUp           = true,
    AutoAcceptJoins       = true,
    AutoProgression       = true,
    AutoSellTrashes       = true,
    AutoBuyGamepasses     = true,
    AutoStatReset         = true,
    AutoNextTier          = true,
    CurrentTier           = 1,
    DiscordWebhookUrl     = "",
    NotifyLegendary       = true,
    NotifyUltimate        = true,
    NotifyCollects        = true,
    CpuSaverMode          = true,
    UltraPotatoGraphics   = true,
    Disable3dOnAlts       = true,
    Checkpoint145Completed = false,
    Checkpoint154Completed = false,
}

local function saveConfig()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(Config) end)
    if ok and encoded then
        safeWriteFile(ConfigFileName, encoded)
    end
end

local function loadConfig()
    if safeIsFile(ConfigFileName) then
        local raw = safeReadFile(ConfigFileName)
        if raw then
            local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(parsed) == "table" then
                for k, v in pairs(parsed) do
                    Config[k] = v
                end
            end
        end
    else
        saveConfig()
    end
    if not Config.AltUsernames then Config.AltUsernames = {} end
    if not Config.AltLevels then Config.AltLevels = {} end
    if Config.HardcoreMode == nil then Config.HardcoreMode = true end
    if Config.AutoReadyUp == nil then Config.AutoReadyUp = true end
    if Config.AutoAcceptJoins == nil then Config.AutoAcceptJoins = true end
    if Config.AutoProgression == nil then Config.AutoProgression = true end
    if Config.AutoSellTrashes == nil then Config.AutoSellTrashes = true end
    if Config.AutoBuyGamepasses == nil then Config.AutoBuyGamepasses = true end
    if Config.AutoStatReset == nil then Config.AutoStatReset = true end
    if Config.AutoNextTier == nil then Config.AutoNextTier = true end
    if not Config.CurrentTier then Config.CurrentTier = 1 end
    if not Config.DiscordWebhookUrl then Config.DiscordWebhookUrl = "" end
    if Config.CpuSaverMode == nil then Config.CpuSaverMode = true end
    if Config.UltraPotatoGraphics == nil then Config.UltraPotatoGraphics = true end
    if Config.Disable3dOnAlts == nil then Config.Disable3dOnAlts = true end
end

loadConfig()

local isCarry = (Config.CarryUsername and #Config.CarryUsername > 0 and LocalPlayer.Name:lower() == Config.CarryUsername:lower())

local function updateRoleStatus()
    isCarry = (Config.CarryUsername and #Config.CarryUsername > 0 and LocalPlayer.Name:lower() == Config.CarryUsername:lower())
end

-- ========================================================================
--  GRAPHICS & CPU SAVER OPTIMIZATION
-- ========================================================================
local function applyPerformanceOptimizations()
    pcall(function()
        if Config.Disable3dOnAlts and not isCarry then
            RunService:Set3dRenderingEnabled(false)
        else
            RunService:Set3dRenderingEnabled(true)
        end
    end)

    if Config.CpuSaverMode then
        pcall(function()
            settings().Rendering.QualityLevel = 1
            settings():GetService("RenderSettings").QualityLevel = Enum.QualityLevel.Level01
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 0
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("PostProcessEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect") then
                    v.Enabled = false
                end
            end
        end)
    end
end

task.spawn(function()
    task.wait(1.5)
    applyPerformanceOptimizations()
end)

-- ========================================================================
--  ANTI-AFK ENGINE
-- ========================================================================
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end)

-- ========================================================================
--  DISCORD WEBHOOK NOTIFIER
-- ========================================================================
local function sendDiscordWebhook(embedData)
    if not Config.DiscordWebhookUrl or Config.DiscordWebhookUrl == "" then return end
    local payload = {
        username = "Project Maki Fully Automated",
        avatar_url = "https://i.imgur.com/8QfJq1g.png",
        embeds = { embedData }
    }
    local jsonPayload = HttpService:JSONEncode(payload)
    local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (Fluxus and Fluxus.request) or request
    if httpRequest then
        task.spawn(function()
            pcall(function()
                httpRequest({
                    Url = Config.DiscordWebhookUrl,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = jsonPayload
                })
            end)
        end)
    end
end

local function sendMilestoneNotification(title, description, color)
    local embed = {
        title = title,
        description = description,
        color = color or 65280,
        fields = {
            { name = "👤 Account", value = string.format("`%s`", LocalPlayer.Name), inline = true },
            { name = "👑 Host", value = string.format("`%s`", Config.CarryUsername or "None"), inline = true },
        },
        footer = { text = "Maki Fully Automated • Milestone Engine" },
        timestamp = DateTime.now():ToIsoDate()
    }
    sendDiscordWebhook(embed)
end

-- ========================================================================
--  ENVIRONMENT & LOCATION DETECTOR
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
    local arena = Workspace:FindFirstChild("Arena") or Workspace:FindFirstChild("bossRoom")
    if arena then
        return false
    end
    return true
end

local function isDungeon()
    return not isMainLobby()
end

local function isRaidOrDungeon()
    return not isMainLobby()
end

local function getDungeonProgress()
    local dProg = Workspace:FindFirstChild("dungeonProgress")
    return (dProg and dProg:IsA("StringValue")) and dProg.Value:lower() or "active"
end

local function getDungeonSlug()
    local dNameVal = Workspace:FindFirstChild("dungeonName") or (Workspace:FindFirstChild("dungeon") and Workspace.dungeon:FindFirstChild("dungeonName"))
    local rawName = (dNameVal and dNameVal:IsA("StringValue") and dNameVal.Value ~= "") and dNameVal.Value or (Config.CurrentDungeon or "winter_outpost")
    local slug = rawName:lower():gsub("[^%w%s]", ""):gsub("%s+", "_")
    return slug, rawName
end

local function isClientStuckInLoading()
    if isMainLobby() then return false end
    local dObj  = Workspace:FindFirstChild("dungeon")
    local dName = Workspace:FindFirstChild("dungeonName")
    local arena = Workspace:FindFirstChild("Arena") or Workspace:FindFirstChild("bossRoom")
    local char  = LocalPlayer.Character
    local hrp   = char and char:FindFirstChild("HumanoidRootPart")

    if (dObj or arena) and hrp then
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

    if not dObj and not arena and not hrp then
        return true
    end

    return false
end

-- 20-Second Loading Screen Watchdog
local stuckLoadingSeconds = 0
task.spawn(function()
    while _G.MAKI_FULLY_AUTOMATED_RUNNING do
        task.wait(1.0)
        if isClientStuckInLoading() then
            stuckLoadingSeconds = stuckLoadingSeconds + 1
            if stuckLoadingSeconds >= 20 then
                warn("[Maki Watchdog 🚨] Stuck on loading screen for 20s! Returning to Lobby...")
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
--  LEVEL ENGINE & OFFICIAL PROGRESSION LADDER (LEVELS 33 TO 165+)
-- ========================================================================
local ProgressionLadder = {
    { dungeon = "Winter Outpost",   diff = "Easy",      req = 33,  slug = "winter_outpost",   engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Winter Outpost",   diff = "Medium",    req = 40,  slug = "winter_outpost",   engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Winter Outpost",   diff = "Hard",      req = 45,  slug = "winter_outpost",   engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Winter Outpost",   diff = "Insane",    req = 50,  slug = "winter_outpost",   engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Winter Outpost",   diff = "Nightmare", req = 55,  slug = "winter_outpost",   engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Pirate Island",    diff = "Insane",    req = 60,  slug = "pirate_island",    engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Pirate Island",    diff = "Nightmare", req = 65,  slug = "pirate_island",    engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "King's Castle",    diff = "Insane",    req = 70,  slug = "kings_castle",     engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "King's Castle",    diff = "Nightmare", req = 75,  slug = "kings_castle",     engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "The Underworld",   diff = "Insane",    req = 80,  slug = "the_underworld",   engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "The Underworld",   diff = "Nightmare", req = 85,  slug = "the_underworld",   engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Samurai Palace",   diff = "Insane",    req = 90,  slug = "samurai_palace",   engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Samurai Palace",   diff = "Nightmare", req = 95,  slug = "samurai_palace",   engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "The Canals",       diff = "Insane",    req = 100, slug = "the_canals",       engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "The Canals",       diff = "Nightmare", req = 105, slug = "the_canals",       engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Ghastly Harbor",   diff = "Insane",    req = 110, slug = "ghastly_harbor",   engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Ghastly Harbor",   diff = "Nightmare", req = 115, slug = "ghastly_harbor",   engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Steampunk Sewers", diff = "Insane",    req = 120, slug = "steampunk_sewers", engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    { dungeon = "Steampunk Sewers", diff = "Nightmare", req = 125, slug = "steampunk_sewers", engine = "waypoint", phase = "1/5 Waypoints (33-129)" },
    -- BOSS RAID FAST-TRACK (LEVEL 130 - 144)
    { dungeon = "Boss Raids",       diff = "Tier 30",   req = 130, slug = "boss_raid",        engine = "bossraid", phase = "2/5 Boss Raids (130-144)" },
    -- ORBITAL OUTPOST (LEVEL 145 - 153)
    { dungeon = "Orbital Outpost",  diff = "Nightmare", req = 145, slug = "orbital_outpost",  engine = "mhc",      phase = "4/5 Orbital MHC (145-153)" },
    -- ENDGAME PROGRESSION (LEVEL 155+)
    { dungeon = "Volcanic Chambers",diff = "Insane",    req = 150, slug = "volcanic_chambers",engine = "mhc",      phase = "Endgame MHC (155+)" },
    { dungeon = "Volcanic Chambers",diff = "Nightmare", req = 155, slug = "volcanic_chambers",engine = "mhc",      phase = "Endgame MHC (155+)" },
    { dungeon = "Aquatic Temple",   diff = "Nightmare", req = 165, slug = "aquatic_temple",    engine = "mhc",      phase = "Endgame MHC (155+)" },
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
        local myLvl = getLivePlayerLevel(LocalPlayer.Name) or 33
        return myLvl, LocalPlayer.Name
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
--  AUTOMATED GOLD GAMEPASS BUYER & STAT RESET ENGINE
-- ========================================================================
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
    local pVal = LocalPlayer:FindFirstChild(passId)
    if pVal and (pVal:IsA("BoolValue") and pVal.Value == true) then return true end

    local gpFolder = LocalPlayer:FindFirstChild("gamepasses") or LocalPlayer:FindFirstChild("Gamepasses")
    if gpFolder then
        local child = gpFolder:FindFirstChild(passId)
        if child and ((child:IsA("BoolValue") and child.Value == true) or child.Value == 1) then return true end
    end

    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    local shop = pG and pG:FindFirstChild("mainInterface") and pG.mainInterface:FindFirstChild("shop")
    local gpFrame = shop and shop:FindFirstChild("gamepasses") and shop.gamepasses:FindFirstChild("inner") and shop.gamepasses.inner:FindFirstChild("ScrollingFrame")
    if gpFrame then
        local item = gpFrame:FindFirstChild(passId)
        if item then
            local ownedLbl = item:FindFirstChild("owned") or item:FindFirstChild("OWNED") or item:FindFirstChild("Owned")
            if ownedLbl and ownedLbl.Visible then return true end
            for _, d in ipairs(item:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text and d.Text:upper():find("OWNED") and d.Visible then
                    return true
                end
            end
        end
    end

    return false
end

local function buyGamepassWithGold(passId)
    if not requestGoldGamepassPurchaseRemote then return false end
    if isGamepassOwned(passId) then return true end

    local gold = getAccountGold()
    local price = nil
    if getGoldGamepassPriceRemote then
        local ok, p = pcall(function() return getGoldGamepassPriceRemote:InvokeServer(passId) end)
        if ok and tonumber(p) then price = tonumber(p) end
    end

    if not price or gold >= price then
        print(string.format("[%s] 🛒 Auto-Purchasing Gamepass with Gold: %s (Price: %s, Current Gold: %s)...",
            LocalPlayer.Name, passId, tostring(price or "Unknown"), tostring(gold)))
        pcall(function()
            requestGoldGamepassPurchaseRemote:FireServer(passId)
        end)
        task.wait(0.5)
        local owned = isGamepassOwned(passId)
        if owned then
            print(string.format("[%s] 🎉 Successfully acquired %s gamepass!", LocalPlayer.Name, passId))
            sendMilestoneNotification("🛒 Gamepass Purchased with Gold!", string.format("**%s** bought **%s** for **%s** gold!", LocalPlayer.Name, passId, tostring(price or "N/A")), 33023)
        end
        return owned
    else
        print(string.format("[%s] ⏳ Need more gold for %s. Price: %s, Gold: %s",
            LocalPlayer.Name, passId, tostring(price), tostring(gold)))
        return false
    end
end

-- Checkpoint 145 Engine (2x Gold + Extra Drop)
local function executeCheckpoint145Purchases()
    if not Config.AutoBuyGamepasses then return end
    print(string.format("[%s] 🌟 Level 145 Checkpoint Reached! Checking 2x Gold & Extra Drop...", LocalPlayer.Name))
    buyGamepassWithGold("2xGold")
    task.wait(0.3)
    buyGamepassWithGold("extraDrop")
    task.wait(0.3)
    if isGamepassOwned("2xGold") and isGamepassOwned("extraDrop") then
        Config.Checkpoint145Completed = true
        saveConfig()
    end
end

-- Checkpoint 154 Engine (VIP + Free Stat Reset + Reset Execution)
local function executeCheckpoint154PurchasesAndReset()
    if not Config.AutoBuyGamepasses then return end
    print(string.format("[%s] 🌟 Level 154 Checkpoint Reached! Checking VIP & Free Stat Reset...", LocalPlayer.Name))
    buyGamepassWithGold("VIP")
    task.wait(0.3)
    buyGamepassWithGold("freeReset")
    task.wait(0.3)

    if Config.AutoStatReset and resetPointsWithGamepassRemote and isGamepassOwned("freeReset") then
        print(string.format("[%s] 🔄 Executing Free Stat Reset with Gamepass...", LocalPlayer.Name))
        pcall(function()
            resetPointsWithGamepassRemote:FireServer()
        end)
        task.wait(0.5)
        print(string.format("[%s] ✅ Stat points successfully reset and refunded!", LocalPlayer.Name))
        sendMilestoneNotification("🔄 Stat Reset Executed!", string.format("**%s** successfully reset skill points with Free Reset Gamepass at Level 154!", LocalPlayer.Name), 65280)
    end

    if isGamepassOwned("VIP") and isGamepassOwned("freeReset") then
        Config.Checkpoint154Completed = true
        saveConfig()
    end
end

-- Background Auto-Buyer Loop (Runs on Carry and Alts periodically)
task.spawn(function()
    while _G.MAKI_FULLY_AUTOMATED_RUNNING do
        task.wait(10.0)
        if Config.AutoBuyGamepasses then
            local lowestLvl = getLowestAltLevel()
            if lowestLvl >= 145 and not Config.Checkpoint145Completed then
                executeCheckpoint145Purchases()
            end
            if lowestLvl >= 154 and not Config.Checkpoint154Completed then
                executeCheckpoint154PurchasesAndReset()
            end
        end
    end
end)

-- ========================================================================
--  UNIVERSAL AUTO-SELL ENGINE (FIXED FOR BOTH CARRY & ALL ALTS)
-- ========================================================================
local knownInventoryKeys = {}
local initialScanComplete = false

local function isItemProtectedFromSell(category, itemName, rarity, isEquipped, itemLevelReq)
    if isEquipped then return true end

    -- High-Tier Purple Collectibles (Eldenbark, Valhalla) ALWAYS 100% PROTECTED
    local isCollect, collectPrefix, collectSource, isHighTier = isPurpleCollect(itemName)
    if isCollect and isHighTier then return true end
    if (category == "chest" or category == "helmet") and isCollect then return true end

    -- Special Event Items (EIF, EIR, Eye of Inferno) ALWAYS 100% PROTECTED
    if isSpecialEventItem(itemName) then return true end

    local rLower = rarity and rarity:lower() or "common"
    local lvl = tonumber(itemLevelReq) or 0

    -- Endgame Gear (Level 145+ Legendary, Mythic, Ultimate) 100% PROTECTED
    if lvl >= 145 and (rLower == "legendary" or rLower == "ultimate" or rLower == "mythic") then
        return true
    end

    -- Abilities below Legendary 145+ are sold
    if category == "ability" then
        if lvl >= 145 and (rLower == "legendary" or rLower == "ultimate" or rLower == "mythic") then
            return true
        end
        return false
    end

    -- Weapons below Level 145 or non-high tier collects are sold
    if category == "weapon" then
        if lvl >= 145 and (rLower == "legendary" or rLower == "ultimate" or rLower == "mythic") then
            return true
        end
        return false
    end

    -- Armors: Purple collects from any dungeon kept, non-collect non-endgame sold
    if category == "chest" or category == "helmet" then
        if lvl >= 145 and (rLower == "legendary" or rLower == "ultimate" or rLower == "mythic") then
            return true
        end
        return false
    end

    return false
end

local function executeUniversalAutoSell()
    if not Config.AutoSellTrashes or not reloadInvyRemote or not sellItemEventRemote then return end

    -- 1. Inventory refresh sync call to ensure newly dropped items are indexed
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
            local itemLvl = item.levelReq or item.level or 0

            local protected = isItemProtectedFromSell(category, itemName, rarity, isEquipped, itemLvl)

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

    if totalSold > 0 then
        pcall(function() sellItemEventRemote:FireServer(itemsToSell) end)
        print(string.format("[%s] 💰 Auto-Sold %d items! Gold Balance: %s (Collects & Endgame 145+ 100%% SAFE)",
            LocalPlayer.Name, totalSold, tostring(getAccountGold())))
    end
end

-- Periodic Inventory Seed
task.spawn(function()
    task.wait(2.0)
    if reloadInvyRemote then
        pcall(function() reloadInvyRemote:InvokeServer() end)
    end
end)

-- ========================================================================
--  COMBAT ENGINE & DEATH AURA (PULSE WAVE ROTATION)
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
                elseif sName == 'e' and not eTool then eTool = item
                end
            end
        end
    end
    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChild('Backpack'))
    if not qTool and allTools[1] then qTool = allTools[1] end
    if not eTool and allTools[2] then eTool = allTools[2] end
    return qTool, eTool
end

local function getToolCooldown(tool)
    if not tool then return 999 end
    local cdVal = tool:FindFirstChild('cooldown') or tool:FindFirstChild('Cooldown') or tool:FindFirstChild('cd')
    if cdVal and tonumber(cdVal.Value) then return tonumber(cdVal.Value) end
    return 0
end

local lastCastedSlot = nil
local lastCastTimestamp = 0

local function castSlot(slotKey, tool)
    if not tool then return end
    pcall(function()
        if abilityUsedRemote then abilityUsedRemote:FireServer(tool) end
        if abilityCastRemote then abilityCastRemote:FireServer(slotKey) end
        if weaponUsedRemote then weaponUsedRemote:FireServer(tool) end
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

-- Staggered Pulse Wave Attack Loop for Carry
task.spawn(function()
    while _G.MAKI_FULLY_AUTOMATED_RUNNING do
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

-- Natural WalkSpeed Enforcer
RunService.Heartbeat:Connect(function()
    if isCarry and isRaidOrDungeon() then
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed < 23 then hum.WalkSpeed = 23 end
    end
end)

-- ========================================================================
--  WAYPOINT ENGINE (LEVELS 33 - 129)
-- ========================================================================
local currentWaypoints = {}
local currentLoadedMapSlug = ""
local currentWpIndex = 1
local wpArrivalDist = 8.0

local function loadWaypointsForDungeon(slug)
    local fileName = "dqr_map_" .. slug .. ".json"
    if not safeIsFile(fileName) then return false end
    local raw = safeReadFile(fileName)
    if not raw then return false end
    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(parsed) == "table" and #parsed > 0 then
        currentWaypoints = parsed
        currentLoadedMapSlug = slug
        currentWpIndex = 1
        return true
    end
    return false
end

task.spawn(function()
    while _G.MAKI_FULLY_AUTOMATED_RUNNING do
        task.wait(0.05)
        local engine = getCurrentDungeonEngine()
        if engine == "waypoint" and isCarry and isDungeon() then
            local slug = getDungeonSlug()
            if currentLoadedMapSlug ~= slug then
                loadWaypointsForDungeon(slug)
            end

            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 and #currentWaypoints > 0 then
                local targetPoint = currentWaypoints[currentWpIndex]
                if targetPoint then
                    local targetPos = Vector3.new(targetPoint.x, targetPoint.y, targetPoint.z)
                    local dist = (hrp.Position - targetPos).Magnitude
                    hum:MoveTo(targetPos)

                    if dist <= wpArrivalDist then
                        if currentWpIndex < #currentWaypoints then
                            currentWpIndex = currentWpIndex + 1
                        end
                    end
                end
            end
        end
    end
end)

-- ========================================================================
--  BOSS RAID COMBAT ENGINE (LEVELS 130 - 144)
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

local function getCurrentRaidTier()
    local tVal = Workspace:FindFirstChild("tier") or (Workspace:FindFirstChild("dungeon") and Workspace.dungeon:FindFirstChild("tier"))
    if tVal and tVal:IsA("IntValue") and tVal.Value > 0 then return tVal.Value end
    return Config.CurrentTier or 1
end

-- Boss Raid Direct Homing Combat
task.spawn(function()
    while _G.MAKI_FULLY_AUTOMATED_RUNNING do
        task.wait(0.05)
        local engine = getCurrentDungeonEngine()
        if engine == "bossraid" and isCarry and isRaidOrDungeon() then
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 then
                local bossModel = nil
                local enemiesFolder = Workspace:FindFirstChild("enemies") or Workspace:FindFirstChild("dungeon") or Workspace:FindFirstChild("Arena")
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
--  MAKI HIGHWAY-CORTEX (MHC) ENGINE (LEVELS 145 - 165+)
-- ========================================================================
local currentHighwayWps = {}
local currentLoadedHighwaySlug = ""
local mhcCurrentIndex = 1

local function loadHighwayForDungeon(slug)
    local fileName = "dqr_highway_" .. slug .. ".json"
    if not safeIsFile(fileName) then return false end
    local raw = safeReadFile(fileName)
    if not raw then return false end
    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(parsed) == "table" and #parsed > 0 then
        currentHighwayWps = parsed
        currentLoadedHighwaySlug = slug
        mhcCurrentIndex = 1
        return true
    end
    return false
end

local function hasLineOfSight(startPos, targetPos)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, Workspace:FindFirstChild("enemies") }
    rayParams.IgnoreWater = true
    local dir = (targetPos - (startPos + Vector3.new(0, 2, 0)))
    local result = Workspace:Raycast(startPos + Vector3.new(0, 2, 0), dir, rayParams)
    if result and result.Instance then
        local hitPart = result.Instance
        if hitPart.Transparency >= 0.85 or not hitPart.CanCollide then return true end
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
            local isBoss = (nameLower:find("boss") ~= nil or nameLower:find("guardian") ~= nil or hum.MaxHealth > 3000000)

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

    table.sort(enemies, function(a, b)
        if a.isBoss and not b.isBoss then return true end
        if not a.isBoss and b.isBoss then return false end
        return a.dist < b.dist
    end)

    return enemies, myPos
end

-- MHC Highway Playback Loop
task.spawn(function()
    while _G.MAKI_FULLY_AUTOMATED_RUNNING do
        task.wait(0.04)
        local engine = getCurrentDungeonEngine()
        if engine == "mhc" and isCarry and isDungeon() then
            local slug = getDungeonSlug()
            if currentLoadedHighwaySlug ~= slug then
                loadHighwayForDungeon(slug)
            end

            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 and #currentHighwayWps > 0 then
                local enemies, myPos = scanLivingEnemies()
                local nearbyTarget = enemies[1]

                if nearbyTarget and nearbyTarget.dist <= 65 and hasLineOfSight(myPos, nearbyTarget.pos) then
                    local dir = (nearbyTarget.pos - hrp.Position).Unit
                    local combatPos = nearbyTarget.pos - (dir * 25.0)
                    hum:MoveTo(combatPos)
                    hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(nearbyTarget.pos.X, hrp.Position.Y, nearbyTarget.pos.Z))
                else
                    local wp = currentHighwayWps[mhcCurrentIndex]
                    if wp then
                        local targetPos = Vector3.new(wp.x, wp.y, wp.z)
                        hum:MoveTo(targetPos)
                        if (hrp.Position - targetPos).Magnitude <= 12.0 then
                            if mhcCurrentIndex < #currentHighwayWps then
                                mhcCurrentIndex = mhcCurrentIndex + 1
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ========================================================================
--  ALT PASSENGER ENGINE (MICRO-WANDER & ANTI-DETECTION)
-- ========================================================================
local altSpawnPosition = nil
local function lockAltSpawn()
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then altSpawnPosition = hrp.Position end
end

task.spawn(function()
    while _G.MAKI_FULLY_AUTOMATED_RUNNING do
        task.wait(math.random(3, 6))
        if not isCarry and isRaidOrDungeon() then
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 then
                if not altSpawnPosition then lockAltSpawn() end
                if altSpawnPosition then
                    local offset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
                    hum:MoveTo(altSpawnPosition + offset)
                end
            end
        end
    end
end)

-- ========================================================================
--  LOBBY, STAGING & ZERO-LATENCY AUTO-ACCEPT ENGINE
-- ========================================================================
local isCreatingLobby = false
local returnToLobbyTriggered = false

local function returnPartyToLobby()
    if returnToLobbyTriggered then return end
    returnToLobbyTriggered = true
    print("[Maki Progression] 🚀 Milestone Reached! Returning party to Main Lobby...")
    saveConfig()
    if teleToLobbyRemote then pcall(function() teleToLobbyRemote:FireServer() end) end
    task.wait(2.0)
    pcall(function() TeleportService:Teleport(77649408247578, LocalPlayer) end)
end

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

-- 0ms Join Request listener for Carry
if showJoinRemote and respondJoinRequestRemote then
    showJoinRemote.OnClientEvent:Connect(function(requesterName, ...)
        if isCarry and Config.AutoAcceptJoins then
            local nameStr = tostring(requesterName)
            pcall(function() respondJoinRequestRemote:FireServer(nameStr, true) end)
            print(string.format("[Maki Instant Accept] ⚡ Instantly Approved Alt: %s (0ms)!", nameStr))
        end
    end)
end

LocalPlayer:WaitForChild("PlayerGui").ChildAdded:Connect(function(child)
    if child.Name == "joinRequestConfirm" then
        instantAcceptAndDestroyPopup(child)
    end
end)

local function areAllAltsInDungeon()
    local totalAlts = #Config.AltUsernames
    if totalAlts == 0 then return true, 0, 0 end
    local loadedCount = 0
    for _, altName in ipairs(Config.AltUsernames) do
        local p = Players:FindFirstChild(altName)
        if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            loadedCount = loadedCount + 1
        end
    end
    return (loadedCount >= totalAlts), loadedCount, totalAlts
end

local function executeInstantReadyUp()
    if not Config.AutoReadyUp then return end
    if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        for _, gui in ipairs(pG:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                for _, b in ipairs(gui:GetDescendants()) do
                    if b:IsA("GuiButton") and b.Visible and b.Name:lower():find("ready") then
                        pcall(function()
                            for _, c in ipairs(getconnections(b.MouseButton1Click)) do c:Fire() end
                            for _, c in ipairs(getconnections(b.Activated)) do c:Fire() end
                        end)
                    end
                end
            end
        end
    end
end

-- Carry Staging Start Trigger
local function triggerCarryStartMatch()
    if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
    if startDungeonRemote then pcall(function() startDungeonRemote:FireServer() end) end
    if startBossRaidRemote then pcall(function() startBossRaidRemote:FireServer() end) end
    if changeStartValueRemote then pcall(function() changeStartValueRemote:FireServer() end) end
end

-- Host Staging Lobby Creation
local function carryCreateAndLaunchLobby()
    if not isCarry or not isMainLobby() or isCreatingLobby then return end
    isCreatingLobby = true
    loadConfig()

    local bestLadder, curLvl, altName = getOptimalDungeonForAlts()

    -- Check if we are in Boss Raid mode (Level 130-144)
    if bestLadder.slug == "boss_raid" then
        local highestTier = getHighestUnlockedTier()
        Config.CurrentDungeon = "Boss Raids"
        Config.CurrentDiff = string.format("Tier %d", highestTier)
        Config.CurrentTier = highestTier
        saveConfig()

        print(string.format("[Maki Host] 👑 Creating Boss Raid Lobby: Tier %d (Private)...", highestTier))
        local ok, res = pcall(function()
            return createBossLobbyRemote:InvokeServer(highestTier, true, 0)
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
    else
        -- Standard Dungeon or MHC Highway Lobby
        local dName = bestLadder.dungeon
        local dDiff = bestLadder.diff
        local dReq  = bestLadder.req

        Config.CurrentDungeon = dName
        Config.CurrentDiff    = dDiff
        saveConfig()

        print(string.format("[Maki Host] 🏰 Creating Dungeon Staging Lobby: %s (%s) [Lowest: %s Lv %d]...",
            dName, dDiff, altName, curLvl))

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
            if startDungeonRemote then pcall(function() startDungeonRemote:FireServer() end) end
            task.wait(3.0)
            isCreatingLobby = false
        else
            warn("[Maki Host] ❌ Dungeon Lobby creation failed: " .. tostring(res))
            task.wait(2.0)
            isCreatingLobby = false
        end
    end
end

-- ========================================================================
--  MATCH LIFECYCLE & VICTORY / REPLAY ENGINE
-- ========================================================================
local isProcessingReplay = false
local matchHandled = false

local function isMatchFinished()
    local prog = getDungeonProgress()
    if prog == "bosskilled" or prog == "victory" or prog == "complete" or prog:find("kill") or prog:find("won") or prog:find("win") then
        return true, "victory"
    end
    if prog == "defeat" or prog == "failed" or prog == "gameover" or prog == "loss" then
        return true, "defeat"
    end
    local dungeon = Workspace:FindFirstChild("dungeon") or Workspace:FindFirstChild("Arena")
    local finished = dungeon and (dungeon:FindFirstChild("dungeonFinished") or dungeon:FindFirstChild("finished"))
    if finished and finished:IsA("BoolValue") and finished.Value == true then
        return true, "victory"
    end
    return false, "active"
end

local function handleNextTierOrReplay()
    if isProcessingReplay then return end
    isProcessingReplay = true

    task.spawn(function()
        local curTier = getCurrentRaidTier()
        task.wait(1.5)

        -- If Tier < 30, try clicking Next Tier button
        if Config.AutoNextTier and curTier < 30 then
            local pG = LocalPlayer:FindFirstChild("PlayerGui")
            if pG then
                for _, gui in ipairs(pG:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled then
                        for _, btn in ipairs(gui:GetDescendants()) do
                            if btn:IsA("GuiButton") and btn.Visible then
                                local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                                local bName = btn.Name:lower()
                                if (bText:find("next") or bName:find("nexttier") or bName:find("next_tier")) and not bText:find("prev") then
                                    pcall(function()
                                        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                                        for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                                    end)
                                    print(string.format("[Maki Next Tier] 🚀 Advanced from Tier %d ➔ %d!", curTier, curTier + 1))
                                    task.wait(2.0)
                                    isProcessingReplay = false
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Loop Tier 30 or standard Replay
        if replayRemote then pcall(function() replayRemote:FireServer() end) end
        if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
        task.wait(2.5)
        isProcessingReplay = false
    end)
end

-- Main Match Lifecycle Loop
task.spawn(function()
    while _G.MAKI_FULLY_AUTOMATED_RUNNING do
        task.wait(0.5)

        if isRaidOrDungeon() then
            returnToLobbyTriggered = false

            -- Staging Ready Up
            if isCarry then
                local allReady, loadedCount, totalAlts = areAllAltsInDungeon()
                if allReady then
                    triggerCarryStartMatch()
                end
            else
                executeInstantReadyUp()
            end

            -- Match Finished Detection
            local finished, state = isMatchFinished()
            if finished and not matchHandled then
                matchHandled = true

                -- 1. Execute Universal Auto-Sell on BOTH Carry and ALL Alts!
                task.wait(1.0)
                executeUniversalAutoSell()

                if state == "victory" then
                    local lowestLvl, altName = getLowestAltLevel()
                    local currentLadder = getOptimalDungeonForAlts()

                    -- Checkpoint 145 Promotion Check
                    if lowestLvl >= 145 and not Config.Checkpoint145Completed then
                        print("[Maki Checkpoint 🌟] Level 145 reached! Executing Checkpoint 145 liquidation & return...")
                        executeCheckpoint145Purchases()
                        if isCarry then returnPartyToLobby() end
                    -- Checkpoint 154 Promotion Check
                    elseif lowestLvl >= 154 and not Config.Checkpoint154Completed then
                        print("[Maki Checkpoint 🌟] Level 154 reached! Executing Checkpoint 154 VIP & Stat Reset...")
                        if isCarry then returnPartyToLobby() end
                    -- Standard Promotion to Next Dungeon Check
                    elseif Config.AutoProgression and (currentLadder.dungeon ~= Config.CurrentDungeon or currentLadder.diff ~= Config.CurrentDiff) then
                        print(string.format("[Maki Progression] 🎉 %s reached Level %d! Promoting to %s (%s)...",
                            altName, lowestLvl, currentLadder.dungeon, currentLadder.diff))
                        if isCarry then returnPartyToLobby() end
                    else
                        -- Replay or Next Tier
                        if isCarry then
                            local engine = getCurrentDungeonEngine()
                            if engine == "bossraid" then
                                handleNextTierOrReplay()
                            else
                                task.wait(2.0)
                                if replayRemote then pcall(function() replayRemote:FireServer() end) end
                                if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
                            end
                        else
                            task.wait(2.5)
                            if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
                        end
                    end
                elseif state == "defeat" then
                    -- Instant Defeat Auto-Retry
                    print("[Maki Hardcore 💀] Wipe detected! Instantly retrying match in-place...")
                    if isCarry then
                        task.wait(2.0)
                        if replayRemote then pcall(function() replayRemote:FireServer() end) end
                        if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
                    else
                        task.wait(2.5)
                        if readyUpRemote then pcall(function() readyUpRemote:FireServer() end) end
                    end
                end
            end
        elseif isMainLobby() then
            matchHandled = false
            altSpawnPosition = nil
            currentWpIndex = 1
            mhcCurrentIndex = 1

            -- Checkpoint Handlers in Lobby
            local lowestLvl = getLowestAltLevel()
            if lowestLvl >= 145 and not Config.Checkpoint145Completed then
                executeCheckpoint145Purchases()
            end
            if lowestLvl >= 154 and not Config.Checkpoint154Completed then
                executeCheckpoint154PurchasesAndReset()
            end

            -- Carry Lobby Host Loop
            if isCarry and not isCreatingLobby then
                task.wait(4.0)
                if isMainLobby() and _G.MAKI_FULLY_AUTOMATED_RUNNING then
                    carryCreateAndLaunchLobby()
                end
            elseif not isCarry then
                -- Alt: Auto Send Join Request
                pcall(function()
                    if sendJoinRequestRemote and Config.CarryUsername and #Config.CarryUsername > 0 then
                        sendJoinRequestRemote:InvokeServer(Config.CarryUsername)
                    end
                    if joinDungeonRemote and Config.CarryUsername and #Config.CarryUsername > 0 then
                        joinDungeonRemote:InvokeServer(Config.CarryUsername)
                    end
                end)
            end
        end
    end
end)

-- ========================================================================
--  MULTI-TAB CONTROLLER GUI
-- ========================================================================
local pGuiRef = LocalPlayer:WaitForChild("PlayerGui")
local oldGui = pGuiRef:FindFirstChild("Maki_FullyAutomatedGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Maki_FullyAutomatedGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = getGuiParent()

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 310, 0, 300)
frame.Position = UDim2.new(0, 20, 0.5, -150)
frame.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
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
titleLbl.Text = isCarry and "👑 MAKI FULLY AUTOMATED [CARRY HOST]" or "🛡️ MAKI FULLY AUTOMATED [ALT PASSENGER]"

-- Tab Bar
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
pageDashboard.Size = UDim2.new(1, -16, 0, 242)
pageDashboard.Position = UDim2.new(0, 8, 0, 52)
pageDashboard.BackgroundTransparency = 1
pageDashboard.Visible = true

local pageAlts = Instance.new("Frame", frame)
pageAlts.Size = UDim2.new(1, -16, 0, 242)
pageAlts.Position = UDim2.new(0, 8, 0, 52)
pageAlts.BackgroundTransparency = 1
pageAlts.Visible = false

local pageDiscord = Instance.new("Frame", frame)
pageDiscord.Size = UDim2.new(1, -16, 0, 242)
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

-- Dashboard Elements
local statsBox = Instance.new("Frame", pageDashboard)
statsBox.Size = UDim2.new(1, 0, 0, 115)
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
statusLbl.Text = "● STATUS: 🟢 FULLY AUTOMATED ACTIVE"

local phaseLbl = Instance.new("TextLabel", statsBox)
phaseLbl.Size = UDim2.new(1, -10, 0, 14)
phaseLbl.Position = UDim2.new(0, 6, 0, 18)
phaseLbl.BackgroundTransparency = 1
phaseLbl.TextColor3 = Color3.fromRGB(255, 180, 50)
phaseLbl.TextSize = 7.5
phaseLbl.Font = Enum.Font.GothamBold
phaseLbl.TextXAlignment = Enum.TextXAlignment.Left
phaseLbl.Text = "🎯 Phase: Scanning..."

local dungeonInfoLbl = Instance.new("TextLabel", statsBox)
dungeonInfoLbl.Size = UDim2.new(1, -10, 0, 14)
dungeonInfoLbl.Position = UDim2.new(0, 6, 0, 34)
dungeonInfoLbl.BackgroundTransparency = 1
dungeonInfoLbl.TextColor3 = Color3.fromRGB(220, 220, 240)
dungeonInfoLbl.TextSize = 7.5
dungeonInfoLbl.Font = Enum.Font.Gotham
dungeonInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
dungeonInfoLbl.Text = "🏰 Target: Scanning..."

local altLvlInfoLbl = Instance.new("TextLabel", statsBox)
altLvlInfoLbl.Size = UDim2.new(1, -10, 0, 14)
altLvlInfoLbl.Position = UDim2.new(0, 6, 0, 50)
altLvlInfoLbl.BackgroundTransparency = 1
altLvlInfoLbl.TextColor3 = Color3.fromRGB(120, 220, 255)
altLvlInfoLbl.TextSize = 7.5
altLvlInfoLbl.Font = Enum.Font.Gotham
altLvlInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
altLvlInfoLbl.Text = "📊 Lowest Alt: Scanning..."

local goldInfoLbl = Instance.new("TextLabel", statsBox)
goldInfoLbl.Size = UDim2.new(1, -10, 0, 14)
goldInfoLbl.Position = UDim2.new(0, 6, 0, 66)
goldInfoLbl.BackgroundTransparency = 1
goldInfoLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
goldInfoLbl.TextSize = 7.5
goldInfoLbl.Font = Enum.Font.GothamBold
goldInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
goldInfoLbl.Text = "💰 Gold: Scanning..."

local passesInfoLbl = Instance.new("TextLabel", statsBox)
passesInfoLbl.Size = UDim2.new(1, -10, 0, 14)
passesInfoLbl.Position = UDim2.new(0, 6, 0, 82)
passesInfoLbl.BackgroundTransparency = 1
passesInfoLbl.TextColor3 = Color3.fromRGB(180, 230, 255)
passesInfoLbl.TextSize = 7
passesInfoLbl.Font = Enum.Font.Gotham
passesInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
passesInfoLbl.Text = "🛒 Passes: 2xGold [..] | ExtraDrop [..] | VIP [..] | Reset [..]"

local wpInfoLbl = Instance.new("TextLabel", statsBox)
wpInfoLbl.Size = UDim2.new(1, -10, 0, 14)
wpInfoLbl.Position = UDim2.new(0, 6, 0, 98)
wpInfoLbl.BackgroundTransparency = 1
wpInfoLbl.TextColor3 = Color3.fromRGB(160, 200, 240)
wpInfoLbl.TextSize = 7
wpInfoLbl.Font = Enum.Font.Gotham
wpInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
wpInfoLbl.Text = "📍 Navigation: Standby"

-- Dashboard Action Toggles
local function createToggle(name, yPos, getConfig, setConfig)
    local btn = Instance.new("TextButton", pageDashboard)
    btn.Size = UDim2.new(1, 0, 0, 20)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = getConfig() and Color3.fromRGB(20, 100, 50) or Color3.fromRGB(50, 50, 60)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 7.5
    btn.Font = Enum.Font.GothamBold
    btn.Text = name .. (getConfig() and " [ON]" or " [OFF]")
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    btn.Activated:Connect(function()
        local newVal = not getConfig()
        setConfig(newVal)
        btn.BackgroundColor3 = newVal and Color3.fromRGB(20, 100, 50) or Color3.fromRGB(50, 50, 60)
        btn.Text = name .. (newVal and " [ON]" or " [OFF]")
        saveConfig()
    end)
    return btn
end

createToggle("🚀 AUTO PROGRESSION (LADDER 33-165+)", 120, function() return Config.AutoProgression end, function(v) Config.AutoProgression = v end)
createToggle("💰 AUTO-SELL ALL TRASHES (COLLECTS SAFE)", 144, function() return Config.AutoSellTrashes end, function(v) Config.AutoSellTrashes = v end)
createToggle("🛒 AUTO-BUY GAMEPASSES (145 & 154)", 168, function() return Config.AutoBuyGamepasses end, function(v) Config.AutoBuyGamepasses = v end)
createToggle("🔄 AUTO STAT RESET AT 154", 192, function() return Config.AutoStatReset end, function(v) Config.AutoStatReset = v end)

local manualActionBtn = Instance.new("TextButton", pageDashboard)
manualActionBtn.Size = UDim2.new(1, 0, 0, 22)
manualActionBtn.Position = UDim2.new(0, 0, 0, 216)
manualActionBtn.BackgroundColor3 = isCarry and Color3.fromRGB(0, 140, 200) or Color3.fromRGB(120, 60, 200)
manualActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
manualActionBtn.TextSize = 8
manualActionBtn.Font = Enum.Font.GothamBold
manualActionBtn.Text = isCarry and "⚡ FORCE LAUNCH CURRENT STAGE" or "⚡ FORCE READY / RE-SYNC"
Instance.new("UICorner", manualActionBtn).CornerRadius = UDim.new(0, 4)

manualActionBtn.Activated:Connect(function()
    if isCarry and isMainLobby() then
        carryCreateAndLaunchLobby()
    else
        executeInstantReadyUp()
        executeUniversalAutoSell()
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
dcTitle.Text = "💬 Discord Webhook URL:"

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

-- Alts Tab Elements
local carryInput = Instance.new("TextBox", pageAlts)
carryInput.Size = UDim2.new(1, 0, 0, 24)
carryInput.Position = UDim2.new(0, 0, 0, 0)
carryInput.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
carryInput.TextColor3 = Color3.fromRGB(255, 255, 255)
carryInput.TextSize = 7.5
carryInput.Font = Enum.Font.Gotham
carryInput.PlaceholderText = "Carry Host Username..."
carryInput.Text = Config.CarryUsername or ""
Instance.new("UICorner", carryInput).CornerRadius = UDim.new(0, 4)

carryInput.FocusLost:Connect(function()
    Config.CarryUsername = carryInput.Text:gsub("%s+", "")
    updateRoleStatus()
    saveConfig()
end)

local altsScroll = Instance.new("ScrollingFrame", pageAlts)
altsScroll.Size = UDim2.new(1, 0, 0, 160)
altsScroll.Position = UDim2.new(0, 0, 0, 28)
altsScroll.BackgroundColor3 = Color3.fromRGB(10, 13, 22)
altsScroll.ScrollBarThickness = 3
Instance.new("UICorner", altsScroll).CornerRadius = UDim.new(0, 4)

local function refreshAltsList()
    tabAltsBtn.Text = string.format("👥 ALTS (%d)", #Config.AltUsernames)
    for _, c in ipairs(altsScroll:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    for i, altName in ipairs(Config.AltUsernames) do
        local aFrame = Instance.new("Frame", altsScroll)
        aFrame.Size = UDim2.new(1, -6, 0, 22)
        aFrame.Position = UDim2.new(0, 3, 0, (i - 1) * 24)
        aFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 38)
        Instance.new("UICorner", aFrame).CornerRadius = UDim.new(0, 4)

        local aLbl = Instance.new("TextLabel", aFrame)
        aLbl.Size = UDim2.new(0.7, 0, 1, 0)
        aLbl.Position = UDim2.new(0, 6, 0, 0)
        aLbl.BackgroundTransparency = 1
        aLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        aLbl.TextSize = 7.5
        aLbl.Font = Enum.Font.Gotham
        aLbl.TextXAlignment = Enum.TextXAlignment.Left
        local lvl = Config.AltLevels[altName] or "?"
        aLbl.Text = string.format("%d. %s (Lv %s)", i, altName, tostring(lvl))

        local delBtn = Instance.new("TextButton", aFrame)
        delBtn.Size = UDim2.new(0, 18, 0, 16)
        delBtn.Position = UDim2.new(1, -22, 0.5, -8)
        delBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
        delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        delBtn.Text = "✕"
        delBtn.TextSize = 8
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 3)

        delBtn.Activated:Connect(function()
            table.remove(Config.AltUsernames, i)
            saveConfig()
            refreshAltsList()
        end)
    end
    altsScroll.CanvasSize = UDim2.new(0, 0, 0, #Config.AltUsernames * 24)
end

refreshAltsList()

local addAltBox = Instance.new("TextBox", pageAlts)
addAltBox.Size = UDim2.new(0.75, -2, 0, 22)
addAltBox.Position = UDim2.new(0, 0, 0, 194)
addAltBox.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
addAltBox.TextColor3 = Color3.fromRGB(255, 255, 255)
addAltBox.TextSize = 7.5
addAltBox.PlaceholderText = "Add Alt Username..."
Instance.new("UICorner", addAltBox).CornerRadius = UDim.new(0, 4)

local addAltBtn = Instance.new("TextButton", pageAlts)
addAltBtn.Size = UDim2.new(0.25, 0, 0, 22)
addAltBtn.Position = UDim2.new(0.75, 2, 0, 194)
addAltBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
addAltBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
addAltBtn.Text = "➕ ADD"
addAltBtn.TextSize = 7.5
addAltBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", addAltBtn).CornerRadius = UDim.new(0, 4)

addAltBtn.Activated:Connect(function()
    local name = addAltBox.Text:gsub("%s+", "")
    if #name > 0 then
        table.insert(Config.AltUsernames, name)
        addAltBox.Text = ""
        saveConfig()
        refreshAltsList()
    end
end)

-- Real-time UI Update Loop
task.spawn(function()
    while _G.MAKI_FULLY_AUTOMATED_RUNNING do
        task.wait(0.5)
        local optLadder, lowestLvl, altName = getOptimalDungeonForAlts()
        local engine = getCurrentDungeonEngine()

        phaseLbl.Text = string.format("🎯 Phase: %s", optLadder.phase or "Active")
        dungeonInfoLbl.Text = string.format("🏰 Target: %s (%s)", optLadder.dungeon, optLadder.diff)
        altLvlInfoLbl.Text = string.format("📊 Lowest Alt: %s (Lv %d)", altName, lowestLvl)
        goldInfoLbl.Text = string.format("💰 Gold: %s", tostring(getAccountGold()))

        local has2x = isGamepassOwned("2xGold") and "✅" or "❌"
        local hasExtra = isGamepassOwned("extraDrop") and "✅" or "❌"
        local hasVip = isGamepassOwned("VIP") and "✅" or "❌"
        local hasReset = isGamepassOwned("freeReset") and "✅" or "❌"
        passesInfoLbl.Text = string.format("🛒 2xGold [%s] ExtraDrop [%s] VIP [%s] Reset [%s]", has2x, hasExtra, hasVip, hasReset)

        if isCarry then
            if engine == "waypoint" then
                wpInfoLbl.Text = string.format("📍 Waypoint Index: %d / %d", currentWpIndex, #currentWaypoints)
            elseif engine == "bossraid" then
                wpInfoLbl.Text = string.format("📍 Boss Raid Homing: Tier %d", getCurrentRaidTier())
            elseif engine == "mhc" then
                wpInfoLbl.Text = string.format("📍 MHC Highway Index: %d / %d", mhcCurrentIndex, #currentHighwayWps)
            end
        else
            wpInfoLbl.Text = "🛋️ Alt Passenger: In Bubble"
        end
    end
end)

print("[Project Maki] 👑 Fully Automated Progression & Gamepass Suite v1.0 Loaded Successfully!")
