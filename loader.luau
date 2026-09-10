-- ================================================================
--  PROJECT MAKI: UNIVERSAL LOADER
--  Auto-detects which place you are in and loads the correct script
--  Main Lobby (77649408247578)   -> Lobby Manager (creates dungeon)
--  Enchanted Forest (85776757589518) -> EF Master Farm Engine
-- ================================================================

local GITHUB_BASE = "https://raw.githubusercontent.com/MayyAlterrr/maki-suite/main/"
local cacheBuster = "?t=" .. tostring(os.time())

local PlaceId = game.PlaceId

-- ===================== PLACE ID ROUTING =====================
if PlaceId == 77649408247578 then
    -- Main Lobby: Load Lobby Manager
    print("[Maki Loader] Detected: Main Lobby -> Loading Lobby Manager...")
    loadstring(game:HttpGet(GITHUB_BASE .. "scripts/maki_lobby_manager.luau" .. cacheBuster))()

elseif PlaceId == 85776757589518 then
    -- Enchanted Forest Nightmare: Load Farm Engine
    print("[Maki Loader] Detected: Enchanted Forest -> Loading EF Master Farm Engine...")
    loadstring(game:HttpGet(GITHUB_BASE .. "scripts/maki_enchanted_forest_master.luau" .. cacheBuster))()

else
    -- Unknown place
    print(string.format("[Maki Loader] Unknown PlaceId: %d - No script assigned for this place yet.", PlaceId))
end
