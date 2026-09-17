-- ========================================================================
--  PROJECT MAKI: STANDALONE ANTI-ADMIN & INTRUDER EMERGENCY CRASH
-- ========================================================================
--  FUNCTION:
--    • Only activates inside private Dungeons (Dormant in Main Lobby).
--    • Checks if any player joining (or present) is NOT in your party whitelist.
--    • If an unwhitelisted player / admin enters the dungeon instance,
--      it immediately forces a hard Roblox client crash / disconnect.
-- ========================================================================

-- ========================================================================
--  [1] USER CONFIGURATION
-- ========================================================================
-- Add your Carry and Alt account usernames here (case-insensitive).
-- You can also leave this table empty if you have "dqr_party_config.json"
-- properly populated in your workspace.
local MANUAL_WHITELIST = {
    -- "YourCarryUsername",
    -- "YourAlt1",
    -- "YourAlt2",
}

-- If true, automatically loads CarryUsername & AltUsernames from dqr_party_config.json
local AUTO_LOAD_PARTY_CONFIG = true
local PARTY_CONFIG_FILE      = "dqr_party_config.json"

-- ========================================================================
--  [2] SERVICES & UTILITIES
-- ========================================================================
local Players     = game:GetService("Players")
local Workspace   = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local function safeReadFile(fileName)
    if typeof(readfile) == "function" then
        local ok, res = pcall(readfile, fileName)
        if ok and res and #res > 0 then return res end
    end
    return nil
end

-- ========================================================================
--  [3] WHITELIST REGISTRY
-- ========================================================================
local Whitelist = {}

local function addWhitelisted(name)
    if name and typeof(name) == "string" and #name > 0 then
        Whitelist[string.lower(name)] = true
    end
end

-- Always whitelist self
if LocalPlayer and LocalPlayer.Name then
    addWhitelisted(LocalPlayer.Name)
end

-- Add manual entries
for _, name in ipairs(MANUAL_WHITELIST) do
    addWhitelisted(name)
end

-- Load from dqr_party_config.json
if AUTO_LOAD_PARTY_CONFIG then
    local raw = safeReadFile(PARTY_CONFIG_FILE)
    if raw then
        local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and type(data) == "table" then
            if data.CarryUsername and #data.CarryUsername > 0 then
                addWhitelisted(data.CarryUsername)
            end
            if type(data.AltUsernames) == "table" then
                for _, alt in ipairs(data.AltUsernames) do
                    addWhitelisted(alt)
                end
            end
        end
    end
end

local function isWhitelisted(player)
    if not player then return true end
    local pName = string.lower(player.Name)
    return Whitelist[pName] == true
end

local function getWhitelistCount()
    local count = 0
    for _ in pairs(Whitelist) do count = count + 1 end
    return count
end

-- ========================================================================
--  [4] DUNGEON VS LOBBY DETECTION
-- ========================================================================
local function isMainLobby()
    -- Official Dungeon Quest Lobby Place IDs
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

-- ========================================================================
--  [5] EMERGENCY FORCE CRASH ENGINE
-- ========================================================================
local isCrashing = false

local function forceCrash(reason)
    if isCrashing then return end
    isCrashing = true

    print(string.format("[MAKI SECURITY] 🚨 %s - TRIGGERING IMMEDIATE CLIENT TERMINATION", tostring(reason)))

    -- 1. Native executor process termination / disconnect
    pcall(function() if typeof(shutdown) == "function" then shutdown() end end)
    pcall(function() if typeof(closegame) == "function" then closegame() end end)
    pcall(function() if typeof(os.exit) == "function" then os.exit() end end)
    pcall(function() game:Shutdown() end)

    -- 2. Instant Memory Bomb:
    -- Rapidly allocates 10MB blocks in a tight loop.
    -- Reaches process allocation ceiling in < 50ms, causing an immediate, silent C++ std::bad_alloc exit.
    task.spawn(function()
        local memoryBomb = {}
        while true do
            table.insert(memoryBomb, string.rep("\255", 10485760))
        end
    end)

    -- 3. Lock Luau main thread
    while true do end
end

-- ========================================================================
--  [6] INTRUSION SCANNER
-- ========================================================================
local function evaluatePlayer(player)
    if not isDungeon() then return end
    if not player or player == LocalPlayer then return end

    -- Verify if player is recognized
    if not isWhitelisted(player) then
        forceCrash(string.format("Intruder detected in private dungeon: '%s' (UserId: %d)", player.Name, player.UserId))
    end
end

-- Connect real-time join listener
Players.PlayerAdded:Connect(evaluatePlayer)

-- Watchdog loop
task.spawn(function()
    task.wait(1.0) -- Allow character & workspace hydration
    
    local inDungeonLast = false

    while true do
        task.wait(1.5)

        if isDungeon() then
            if not inDungeonLast then
                inDungeonLast = true
                print(string.format("[MAKI SECURITY] ✅ Dungeon detected. Active protection running. Whitelisted: %d accounts.", getWhitelistCount()))
            end

            -- Sweep all existing players in the server
            for _, player in ipairs(Players:GetPlayers()) do
                evaluatePlayer(player)
            end
        else
            if inDungeonLast then
                inDungeonLast = false
                print("[MAKI SECURITY] 💤 Main Lobby detected. Protection dormant.")
            end
        end
    end
end)

print(string.format("[MAKI SECURITY] Loaded Anti-Admin Watchdog. State: %s (Whitelisted: %d)", 
    isDungeon() and "ACTIVE (Dungeon)" or "DORMANT (Lobby)", 
    getWhitelistCount()))
