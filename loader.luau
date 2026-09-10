-- ================================================================
--  PROJECT MAKI: UNIVERSAL MULTI-DUNGEON LOADER
--  Auto-detects place and dungeon to load the dedicated engine:
--  - Main Lobby (77649408247578) -> Lobby Manager
--  - Dungeon Place (85776757589518):
--      * "Northern Lands" -> NL Master Farm Engine (APF Evasion & Combat)
--      * "Enchanted Forest" -> EF Master Farm Engine
-- ================================================================

local GITHUB_BASE = "https://raw.githubusercontent.com/MayyAlterrr/maki-suite/main/"
local cacheBuster = "?t=" .. tostring(os.time())

local PlaceId = game.PlaceId

if PlaceId == 77649408247578 then
    -- Main Lobby: Load Lobby Manager
    print("[Maki Loader] Detected: Main Lobby -> Loading Lobby Manager...")
    loadstring(game:HttpGet(GITHUB_BASE .. "scripts/maki_lobby_manager.luau" .. cacheBuster))()

elseif PlaceId == 85776757589518 then
    -- Dungeon Match Detected: Identify Dungeon Name
    local dNameVal = workspace:WaitForChild("dungeonName", 8)
    local dungeonName = dNameVal and dNameVal.Value or ""

    if dungeonName == "Northern Lands" then
        print("[Maki Loader] Detected: Northern Lands -> Loading NL Master Farm Engine...")
        loadstring(game:HttpGet(GITHUB_BASE .. "scripts/maki_northern_lands_master.luau" .. cacheBuster))()
    elseif dungeonName == "Enchanted Forest" then
        print("[Maki Loader] Detected: Enchanted Forest -> Loading EF Master Farm Engine...")
        loadstring(game:HttpGet(GITHUB_BASE .. "scripts/maki_enchanted_forest_master.luau" .. cacheBuster))()
    else
        -- Fallback: check map or children
        print(string.format("[Maki Loader] Unknown Dungeon '%s' - checking room indicators...", dungeonName))
        local d = workspace:FindFirstChild("dungeon")
        if d and d:FindFirstChild("room7") then
            print("[Maki Loader] Found 7 rooms layout -> Loading NL Master Farm Engine...")
            loadstring(game:HttpGet(GITHUB_BASE .. "scripts/maki_northern_lands_master.luau" .. cacheBuster))()
        else
            print("[Maki Loader] Defaulting to EF Master Farm Engine...")
            loadstring(game:HttpGet(GITHUB_BASE .. "scripts/maki_enchanted_forest_master.luau" .. cacheBuster))()
        end
    end
else
    print(string.format("[Maki Loader] Unknown PlaceId: %d", PlaceId))
end
