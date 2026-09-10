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
local room5ShortcutDone = false

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

local Q_BUFF_DURATION = 4.0 -- User specified: Q passive buff (+80% damage and sprint) lasts 4.0s

local function isQBuffActive()
    return (tick() - lastQCastTime) < Q_BUFF_DURATION
end

local function smoothMoveTo(hum, targetPos)
    hum.AutoRotate = true
    hum:MoveTo(targetPos)
end

-- ========================================================================
-- 1. LOAD HIGHWAY WAYPOINTS (814 Points from Spawn to Dragon)
--    Tier 1: Local readfile (PC - fastest, no download)
--    Tier 2: GitHub HttpGet (Mobile/Cloud with internet)
--    Tier 3: Embedded inline (always works, zero dependencies)
-- ========================================================================
local GITHUB_PATH_URL = "https://raw.githubusercontent.com/MayyAlterrr/maki-suite/main/paths/dqr_highway_enchanted_forest.json"
local waypoints = {}

local function parseWaypoints(raw)
    local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and parsed and parsed.points then
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

-- Tier 2: Fallback to GitHub (Mobile/Cloud)
if #waypoints == 0 then
    pcall(function()
        print("[EF Master] Tier 2 (GitHub): Fetching highway waypoints...")
        local raw = game:HttpGet(GITHUB_PATH_URL)
        parseWaypoints(raw)
        if #waypoints > 0 then
            print(string.format("[EF Master] Tier 2 (GitHub): Loaded %d waypoints", #waypoints))
            pcall(function()
                if typeof(writefile) == "function" then
                    writefile("dqr_highway_enchanted_forest.json", raw)
                    print("[EF Master] Path cached locally for next run.")
                end
            end)
        end
    end)
end

-- Tier 3: Embedded inline (always works, zero dependencies)
-- AUTO-GENERATED: do not edit by hand
if #waypoints == 0 then
    print("[EF Master] Tier 3 (Embedded): Loading inline waypoints...")
    local EMBEDDED = --[[EMBED_START]]
{
    {113.79,7.84,-57.94},{111.73,7.84,-57.87},{109.07,7.91,-57.76},{106.55,7.86,-57.58},{103.89,7.85,-57.34},{101.39,8.05,-56.98},{99.57,6.95,-56.71},{97.07,7.04,-56.35},
    {94.45,6.40,-55.96},{91.82,6.34,-55.57},{89.35,5.24,-55.21},{86.72,4.92,-54.82},{84.21,5.05,-54.46},{81.71,5.02,-54.09},{79.13,5.02,-53.78},{76.48,5.02,-53.49},
    {73.89,5.02,-53.22},{71.31,5.02,-52.94},{68.72,5.02,-52.65},{66.08,5.03,-52.34},{63.49,5.14,-52.04},{60.85,5.08,-51.74},{58.27,5.04,-51.44},{55.68,5.04,-51.15},
    {53.10,5.04,-50.85},{50.52,5.04,-50.57},{47.86,5.01,-50.30},{45.27,5.01,-50.09},{42.68,5.04,-49.90},{40.03,5.19,-49.71},{37.45,4.94,-49.53},{34.89,4.55,-49.36},
    {32.31,4.71,-49.21},{29.79,4.99,-49.09},{27.19,4.99,-48.98},{24.60,4.99,-48.86},{21.93,4.99,-48.72},{19.34,5.11,-48.59},{16.75,5.21,-48.45},{14.09,4.97,-48.31},
    {11.49,4.99,-48.22},{8.89,4.99,-48.16},{6.25,4.72,-48.10},{3.37,4.36,-48.04},{0.81,4.68,-47.99},{-1.78,5.00,-47.96},{-4.37,5.20,-47.93},{-7.06,5.09,-47.91},
    {-9.66,4.99,-47.89},{-12.26,4.99,-47.87},{-14.86,4.99,-47.84},{-17.46,4.99,-47.81},{-20.05,5.20,-47.78},{-22.74,5.25,-47.74},{-25.32,4.99,-47.71},{-27.92,5.04,-47.67},
    {-30.52,5.10,-47.62},{-33.12,4.92,-47.56},{-35.72,4.69,-47.51},{-38.41,5.24,-47.45},{-41.01,4.72,-47.39},{-43.60,4.92,-47.33},{-46.20,4.99,-47.25},{-48.80,4.99,-47.17},
    {-51.49,4.99,-47.09},{-53.89,4.99,-47.01},{-56.59,4.99,-46.93},{-59.19,5.08,-46.85},{-61.79,5.18,-46.77},{-64.39,4.96,-46.69},{-67.08,4.99,-46.61},{-69.58,4.99,-46.54},
    {-72.18,4.99,-46.47},{-74.88,4.99,-46.40},{-77.38,4.99,-46.33},{-80.08,5.00,-46.26},{-82.68,5.17,-46.21},{-85.28,5.17,-46.18},{-87.98,4.98,-46.20},{-90.57,4.99,-46.26},
    {-93.17,4.99,-46.32},{-95.77,4.99,-46.42},{-98.37,4.99,-46.51},{-101.07,4.99,-46.61},{-103.57,5.02,-46.71},{-106.26,5.26,-46.81},{-108.86,4.99,-46.90},{-111.45,4.99,-47.00},
    {-114.05,5.00,-47.10},{-116.75,5.07,-47.20},{-118.96,5.12,-47.28},{-121.33,5.34,-47.37},{-124.02,5.19,-47.47},{-126.51,4.99,-47.56},{-129.20,4.99,-47.66},{-131.80,4.99,-47.76},
    {-134.40,4.99,-47.86},{-137.00,4.99,-47.97},{-139.70,4.99,-48.10},{-142.29,4.99,-48.22},{-144.89,4.99,-48.34},{-147.49,4.99,-48.46},{-149.98,4.99,-48.57},{-152.58,4.99,-48.69},
    {-155.18,4.99,-48.81},{-157.77,4.99,-48.93},{-160.37,5.18,-49.05},{-163.06,4.96,-49.18},{-165.65,4.93,-49.30},{-168.25,4.88,-49.42},{-170.84,4.82,-49.54},{-173.43,4.78,-49.66},
    {-176.11,4.83,-49.78},{-178.69,4.74,-49.90},{-181.27,5.00,-50.01},{-183.86,4.99,-50.13},{-186.46,4.99,-50.24},{-189.04,4.69,-50.34},{-191.71,4.38,-50.43},{-194.29,4.16,-50.52},
    {-196.83,4.53,-50.61},{-199.40,4.90,-50.70},{-202.00,4.90,-50.79},{-204.70,4.97,-50.89},{-207.28,4.73,-50.98},{-209.88,4.59,-51.07},{-212.46,4.33,-51.16},{-215.05,4.21,-51.25},
    {-217.63,4.39,-51.34},{-220.22,4.55,-51.43},{-222.91,4.38,-51.51},{-225.50,4.33,-51.60},{-228.07,4.72,-51.68},{-230.66,4.79,-51.77},{-233.36,4.93,-51.85},{-235.95,4.93,-51.94},
    {-238.48,4.30,-52.02},{-241.05,4.37,-52.11},{-243.58,4.76,-52.19},{-246.28,4.99,-52.28},{-248.88,4.98,-52.36},{-251.10,4.99,-52.43},{-253.70,4.99,-52.52},{-256.29,4.86,-52.59},
    {-258.96,4.81,-52.68},{-261.32,3.78,-52.75},{-263.63,2.64,-52.82},{-266.23,0.86,-52.90},{-268.79,0.38,-52.97},{-271.37,-0.11,-53.05},{-273.06,-2.03,-53.10},{-275.72,-2.14,-53.19},
    {-278.30,-2.72,-53.29},{-280.01,-4.19,-53.36},{-282.58,-4.52,-53.48},{-285.17,-5.42,-53.58},{-286.96,-6.68,-53.65},{-289.55,-6.88,-53.75},{-292.14,-7.27,-53.86},{-293.87,-9.18,-53.92},
    {-296.46,-9.28,-54.02},{-299.11,-9.48,-54.12},{-300.84,-11.09,-54.19},{-303.43,-11.80,-54.31},{-305.99,-13.30,-54.46},{-308.59,-14.03,-54.60},{-311.18,-14.26,-54.74},{-312.89,-16.05,-54.84},
    {-315.55,-16.38,-55.00},{-318.13,-16.59,-55.16},{-320.92,-18.68,-55.34},{-323.51,-18.83,-55.50},{-326.10,-19.02,-55.67},{-328.78,-20.02,-55.84},{-331.37,-21.46,-56.01},{-333.95,-22.79,-56.21},
    {-336.53,-23.67,-56.44},{-339.11,-23.92,-56.71},{-341.79,-23.98,-57.02},{-344.35,-23.67,-57.31},{-346.80,-23.09,-57.59},{-349.37,-22.70,-57.89},{-351.94,-22.51,-58.18},{-354.62,-22.65,-58.47},
    {-357.11,-22.83,-58.63},{-359.69,-23.63,-58.71},{-362.24,-24.08,-58.80},{-364.82,-24.41,-58.88},{-367.42,-24.42,-58.97},{-370.11,-24.42,-59.07},{-372.71,-24.41,-59.20},{-375.30,-24.21,-59.36},
    {-377.89,-24.24,-59.54},{-380.48,-24.42,-59.74},{-383.06,-24.41,-60.04},{-385.63,-24.41,-60.43},{-388.29,-24.41,-60.88},{-390.85,-24.41,-61.33},{-393.41,-24.41,-61.78},{-395.97,-24.41,-62.26},
    {-398.52,-24.41,-62.78},{-401.16,-24.37,-63.33},{-403.60,-24.28,-63.84},{-406.25,-24.24,-64.40},{-408.35,-24.16,-64.84},{-410.58,-24.19,-64.92},{-413.01,-24.31,-64.35},{-415.37,-24.39,-63.53},
    {-417.85,-24.41,-62.46},{-420.21,-24.41,-61.38},{-422.58,-24.41,-60.30},{-425.03,-24.41,-59.17},{-427.27,-24.41,-58.07},{-429.43,-24.41,-56.63},{-431.64,-24.41,-55.07},{-433.76,-24.53,-53.57},
    {-435.82,-24.46,-51.98},{-437.73,-24.32,-50.22},{-439.62,-24.27,-48.30},{-441.43,-24.25,-46.44},{-443.23,-24.03,-44.58},{-445.00,-24.04,-42.69},{-446.81,-24.27,-40.71},{-448.56,-24.27,-38.78},
    {-450.29,-24.36,-36.85},{-452.02,-24.42,-34.90},{-453.74,-24.41,-32.95},{-455.52,-24.41,-30.92},{-457.23,-24.41,-28.96},{-458.85,-24.37,-27.07},{-460.57,-24.15,-24.99},{-462.18,-24.52,-22.97},
    {-463.79,-24.60,-20.93},{-465.40,-24.42,-18.90},{-467.07,-24.41,-16.78},{-468.60,-24.41,-14.85},{-470.21,-24.41,-12.81},{-471.78,-24.39,-10.74},{-473.36,-24.05,-8.61},{-474.85,-24.19,-6.49},
    {-476.31,-24.46,-4.37},{-477.77,-24.03,-2.27},{-479.28,-24.22,-0.10},{-480.76,-24.43,2.03},{-482.28,-24.41,4.23},{-483.71,-24.41,6.32},{-485.21,-24.41,8.52},{-486.64,-24.21,10.67},
    {-488.06,-24.09,12.82},{-489.47,-24.50,14.96},{-490.93,-24.68,17.18},{-492.34,-24.43,19.34},{-493.79,-24.26,21.58},{-495.21,-24.33,23.76},{-496.61,-24.10,25.92},{-498.02,-23.85,28.09},
    {-499.47,-24.15,30.30},{-500.85,-24.40,32.40},{-502.27,-24.42,34.55},{-503.69,-24.41,36.72},{-505.12,-24.41,38.90},{-506.55,-24.41,41.07},{-508.03,-24.41,43.33},{-509.46,-24.43,45.50},
    {-510.88,-24.56,47.67},{-512.30,-24.41,49.83},{-513.72,-24.42,51.99},{-515.16,-24.70,54.22},{-516.55,-24.31,56.39},{-517.96,-24.46,58.56},{-519.38,-24.64,60.73},{-520.81,-24.76,62.90},
    {-522.24,-24.77,65.07},{-523.72,-24.83,67.32},{-525.10,-24.35,69.43},{-526.51,-24.05,71.58},{-527.91,-24.41,73.74},{-529.33,-24.43,75.92},{-530.77,-24.70,78.19},{-532.16,-24.76,80.38},
    {-533.55,-24.59,82.57},{-534.94,-24.52,84.76},{-536.32,-24.72,86.95},{-537.71,-24.89,89.14},{-539.15,-25.16,91.41},{-540.48,-25.40,93.50},{-541.88,-24.90,95.73},{-543.29,-25.09,97.99},
    {-544.59,-25.18,100.09},{-545.94,-24.70,102.25},{-547.36,-24.57,104.54},{-548.69,-25.12,106.70},{-550.02,-25.16,108.92},{-551.34,-24.82,111.12},{-552.66,-24.38,113.32},{-553.98,-23.98,115.53},
    {-555.32,-24.65,117.76},{-556.63,-25.08,119.95},{-558.00,-24.76,122.23},{-559.33,-24.47,124.45},{-560.67,-24.41,126.68},{-562.01,-24.41,128.91},{-563.39,-24.62,131.22},{-564.73,-24.74,133.44},
    {-566.05,-25.04,135.65},{-567.39,-25.31,137.87},{-568.71,-25.19,140.08},{-570.04,-24.92,142.29},{-571.40,-24.41,144.56},{-572.72,-24.03,146.77},{-574.06,-24.07,148.98},{-575.35,-24.81,151.12},
    {-576.59,-25.42,153.18},{-577.91,-25.07,155.36},{-579.22,-24.55,157.54},{-580.56,-24.41,159.77},{-581.90,-24.41,161.99},{-583.20,-24.41,164.13},{-584.49,-24.48,166.27},{-585.85,-24.59,168.48},
    {-587.22,-24.83,170.68},{-588.64,-25.02,172.95},{-589.92,-24.29,175.00},{-591.28,-24.42,177.17},{-592.64,-24.76,179.36},{-594.01,-24.70,181.55},{-595.39,-24.44,183.75},{-596.81,-24.32,186.03},
    {-598.15,-24.89,188.16},{-599.51,-24.92,190.35},{-600.89,-24.55,192.52},{-602.34,-24.53,194.66},{-603.88,-24.17,196.84},{-605.39,-24.02,198.94},{-606.91,-23.90,201.04},{-608.46,-24.28,203.09},
    {-610.09,-24.42,205.10},{-611.86,-24.41,207.14},{-613.56,-24.41,209.10},{-615.27,-24.41,211.06},{-616.99,-24.39,213.02},{-618.68,-24.16,214.94},{-620.36,-23.59,216.85},{-622.06,-23.85,218.78},
    {-623.76,-24.27,220.70},{-625.66,-23.92,222.64},{-627.50,-23.38,224.40},{-629.33,-23.98,226.11},{-631.30,-24.20,227.87},{-633.39,-24.43,229.38},{-635.63,-24.46,230.67},{-637.94,-24.41,231.87},
    {-640.31,-24.41,233.08},{-642.68,-24.41,234.14},{-645.15,-24.41,234.95},{-647.62,-24.41,235.75},{-650.16,-24.41,236.58},{-652.63,-24.41,237.39},{-655.10,-24.41,238.20},{-657.55,-24.19,238.97},
    {-660.07,-23.64,239.69},{-662.63,-23.67,240.42},{-665.05,-23.91,241.11},{-667.57,-24.42,241.77},{-670.09,-24.38,242.41},{-672.61,-24.14,242.98},{-675.14,-24.35,243.51},{-677.75,-24.41,244.06},
    {-680.30,-24.41,244.58},{-682.85,-24.41,245.09},{-685.46,-24.41,245.61},{-688.02,-24.41,246.06},{-690.59,-24.41,246.45},{-693.16,-24.41,246.85},{-696.20,-24.41,247.32},{-698.87,-24.41,247.73},
    {-701.44,-24.41,248.12},{-704.01,-24.41,248.50},{-706.58,-24.41,248.88},{-709.26,-24.41,249.25},{-711.84,-24.41,249.58},{-714.42,-24.41,249.92},{-716.99,-24.41,250.26},{-719.57,-24.41,250.60},
    {-722.25,-24.41,250.95},{-724.73,-24.41,251.27},{-727.41,-24.41,251.63},{-729.98,-24.41,251.98},{-732.56,-24.41,252.34},{-735.13,-24.41,252.70},{-737.81,-24.41,253.08},{-740.29,-24.41,253.42},
    {-742.96,-24.41,253.80},{-745.53,-24.41,254.17},{-748.01,-24.41,254.55},{-750.57,-24.41,254.97},{-753.23,-24.41,255.42},{-755.69,-24.41,255.88},{-758.18,-24.41,256.63},{-760.65,-24.41,257.71},
    {-762.96,-24.41,258.90},{-765.24,-24.41,260.15},{-767.48,-24.41,261.47},{-769.65,-24.41,262.91},{-771.90,-24.41,264.40},{-774.06,-24.41,265.84},{-776.23,-24.41,267.28},{-778.40,-24.41,268.71},
    {-780.57,-24.41,270.14},{-782.75,-24.41,271.56},{-785.00,-24.41,273.04},{-787.18,-24.41,274.47},{-789.34,-24.41,275.91},{-791.49,-24.41,277.38},{-793.62,-24.41,278.87},{-795.82,-24.41,280.43},
    {-797.94,-24.41,281.94},{-799.88,-24.41,283.34},{-801.73,-24.41,284.88},{-803.64,-24.41,286.64},{-805.64,-24.41,288.59},{-807.16,-24.41,290.60},{-808.52,-24.41,292.82},{-809.92,-24.41,295.09},
    {-811.28,-24.41,297.30},{-812.64,-24.41,299.51},{-814.03,-24.41,301.79},{-815.62,-24.41,304.42},{-816.96,-24.41,306.65},{-818.28,-24.41,308.89},{-819.64,-24.41,311.23},{-820.92,-24.41,313.49},
    {-822.18,-24.41,315.76},{-823.39,-24.41,318.06},{-824.58,-24.41,320.37},{-825.73,-24.41,322.70},{-826.84,-24.41,325.17},{-827.88,-24.41,327.55},{-828.85,-24.41,329.96},{-829.80,-24.41,332.38},
    {-830.75,-24.41,334.80},{-831.69,-24.41,337.22},{-832.68,-24.41,339.74},{-833.55,-24.41,341.97},{-834.54,-24.41,344.48},{-835.45,-24.41,346.81},{-836.43,-24.41,349.33},{-837.33,-24.41,351.66},
    {-838.16,-24.41,354.12},{-838.95,-24.41,356.60},{-839.28,-24.41,359.17},{-839.48,-24.41,361.77},{-839.67,-24.41,364.36},{-839.87,-24.41,367.05},{-840.09,-24.41,369.64},{-840.37,-24.41,372.23},
    {-840.64,-24.41,374.81},{-840.91,-24.41,377.40},{-841.15,-24.32,379.98},{-841.35,-23.88,382.63},{-841.44,-23.92,385.21},{-841.42,-24.74,387.68},{-841.28,-24.62,390.26},{-840.96,-24.39,392.83},
    {-840.32,-24.41,395.45},{-839.58,-24.41,397.94},{-838.80,-24.41,400.42},{-837.78,-24.41,402.44},{-836.36,-24.41,404.70},{-834.96,-24.41,406.89},{-833.54,-24.41,409.06},{-832.05,-24.41,411.19},
    {-830.75,-24.41,412.94},{-829.13,-24.41,415.10},{-827.54,-24.36,417.15},{-825.91,-24.16,419.16},{-824.26,-24.12,421.17},{-822.56,-24.33,423.26},{-820.94,-24.33,425.29},{-819.35,-24.12,427.32},
    {-817.74,-24.17,429.37},{-816.14,-24.37,431.41},{-814.55,-24.41,433.46},{-812.91,-24.41,435.60},{-811.33,-24.41,437.67},{-809.74,-24.41,439.73},{-808.17,-24.41,441.80},{-806.59,-24.41,443.87},
    {-804.96,-24.41,446.02},{-803.40,-24.41,448.10},{-801.84,-24.41,450.18},{-800.27,-24.41,452.26},{-798.77,-24.54,454.25},{-797.22,-24.72,456.32},{-795.66,-24.65,458.39},{-794.08,-24.34,460.43},
    {-792.37,-24.51,462.38},{-790.44,-24.57,464.25},{-788.33,-24.35,465.74},{-786.00,-24.36,466.90},{-783.60,-24.41,467.89},{-781.19,-24.41,468.88},{-778.70,-24.41,469.92},{-776.30,-24.41,470.91},
    {-773.84,-24.41,471.75},{-771.36,-24.41,472.54},{-768.88,-24.41,473.32},{-766.39,-24.41,474.07},{-763.77,-24.41,474.72},{-761.22,-24.41,475.20},{-758.65,-24.41,475.60},{-756.08,-24.41,476.00},
    {-753.41,-24.41,476.40},{-750.84,-24.41,476.77},{-748.26,-24.41,477.15},{-745.69,-24.41,477.53},{-743.12,-24.41,477.89},{-740.52,-24.41,478.01},{-737.82,-24.41,477.88},{-735.24,-24.41,477.62},
    {-732.66,-24.41,477.29},{-730.09,-24.41,476.91},{-726.85,-24.41,476.27},{-724.23,-24.41,475.64},{-721.80,-24.41,475.06},{-719.17,-24.41,474.42},{-716.64,-24.41,473.81},{-714.12,-24.41,473.20},
    {-711.59,-24.41,472.59},{-708.97,-24.41,471.93},{-706.45,-24.41,471.29},{-703.93,-24.41,470.64},{-701.41,-24.41,470.00},{-698.89,-24.41,469.36},{-696.28,-24.41,468.70},{-693.76,-24.41,468.06},
    {-691.14,-24.41,467.40},{-688.72,-24.41,466.78},{-686.10,-24.41,466.12},{-683.68,-24.41,465.51},{-681.06,-24.41,464.84},{-678.55,-24.41,464.18},{-676.04,-24.41,463.50},{-673.53,-24.41,462.82},
    {-671.55,-24.41,462.27},{-671.17,-24.41,459.75},{-670.81,-24.41,457.08},{-670.95,-24.41,454.49},{-671.71,-24.41,452.01},{-672.86,-24.17,449.59},{-673.89,-23.76,447.75},{-676.28,-23.77,448.52},
    {-678.68,-23.78,449.28},{-681.07,-23.79,450.05},{-683.47,-23.81,450.82},{-685.86,-23.82,451.59},{-688.26,-23.83,452.35},{-690.65,-23.84,453.12},{-693.05,-23.85,453.89},{-695.44,-23.86,454.66},
    {-697.84,-23.87,455.42},{-700.23,-23.88,456.19},{-702.63,-23.90,456.96},{-705.02,-23.91,457.73},{-707.42,-23.92,458.49},{-709.81,-23.93,459.26},{-712.21,-23.94,460.03},{-714.60,-23.95,460.80},
    {-716.99,-23.96,461.56},{-719.39,-23.98,462.33},{-721.78,-23.99,463.10},{-724.18,-24.00,463.86},{-726.57,-24.01,464.63},{-728.97,-24.02,465.40},{-731.36,-24.03,466.17},{-733.76,-24.04,466.93},
    {-736.15,-24.05,467.70},{-738.55,-24.07,468.47},{-740.94,-24.08,469.24},{-743.34,-24.09,470.00},{-745.73,-24.10,470.77},{-748.13,-24.11,471.54},{-750.52,-24.12,472.31},{-752.92,-24.13,473.07},
    {-755.31,-24.15,473.84},{-757.70,-24.16,474.61},{-760.10,-24.17,475.37},{-762.49,-24.18,476.14},{-764.89,-24.19,476.91},{-767.28,-24.20,477.68},{-769.68,-24.21,478.44},{-772.07,-24.22,479.21},
    {-774.47,-24.24,479.98},{-776.86,-24.25,480.75},{-779.26,-24.26,481.51},{-781.65,-24.27,482.28},{-784.05,-24.28,483.05},{-786.44,-24.29,483.82},{-788.84,-24.30,484.58},{-791.23,-24.31,485.35},
    {-793.63,-24.33,486.12},{-796.02,-24.34,486.88},{-798.41,-24.35,487.65},{-800.81,-24.36,488.42},{-803.20,-24.37,489.19},{-805.60,-24.38,489.95},{-807.99,-24.39,490.72},{-810.39,-24.41,491.49},
    {-812.78,-24.42,492.26},{-815.18,-24.43,493.02},{-817.57,-24.44,493.79},{-819.97,-24.45,494.56},{-822.36,-24.46,495.33},{-824.76,-24.47,496.09},{-827.15,-24.48,496.86},{-829.55,-24.50,497.63},
    {-831.94,-24.51,498.40},{-834.34,-24.52,499.16},{-836.73,-24.53,499.93},{-837.09,-24.55,502.41},{-837.48,-24.54,505.08},{-837.89,-24.43,507.64},{-838.34,-24.41,510.20},{-838.83,-24.41,512.86},
    {-839.33,-24.41,515.31},{-839.89,-24.41,517.95},{-840.42,-24.41,520.39},{-840.99,-24.41,523.03},{-841.56,-24.41,525.57},{-842.15,-24.41,528.10},{-842.78,-24.41,530.62},{-843.47,-24.41,533.23},
    {-844.13,-24.41,535.75},{-844.79,-24.41,538.26},{-845.45,-24.41,540.78},{-846.11,-24.41,543.29},{-846.78,-24.41,545.81},{-847.41,-24.46,548.23},{-848.07,-24.45,550.74},{-848.73,-24.41,553.25},
    {-849.43,-24.41,555.86},{-850.32,-24.48,558.30},{-851.29,-24.76,560.69},{-852.27,-24.79,563.10},{-853.29,-24.81,565.60},{-854.27,-24.83,568.01},{-855.24,-24.56,570.39},{-856.21,-24.33,572.78},
    {-857.19,-24.74,575.15},{-858.27,-24.57,577.61},{-859.33,-24.42,579.98},{-860.39,-24.41,582.36},{-861.47,-24.37,584.72},{-862.58,-24.52,587.05},{-863.96,-24.94,589.21},{-865.71,-24.98,591.13},
    {-867.59,-24.91,593.06},{-869.56,-24.86,594.72},{-871.69,-25.01,596.20},{-873.89,-25.03,597.71},{-876.03,-24.65,599.12},{-878.23,-24.41,600.48},{-880.49,-24.41,601.78},{-882.74,-24.41,603.07},
    {-885.05,-24.41,604.40},{-887.31,-24.38,605.70},{-889.13,-24.26,606.75},{-891.47,-24.36,608.09},{-893.70,-24.52,609.38},{-895.93,-24.18,610.66},{-898.18,-24.23,611.95},{-900.48,-24.41,613.15},
    {-902.79,-24.39,614.33},{-905.20,-24.30,615.56},{-907.51,-24.20,616.74},{-909.80,-24.58,617.91},{-912.11,-24.54,619.09},{-914.43,-24.39,620.26},{-916.75,-24.32,621.42},{-919.16,-24.41,622.62},
    {-921.49,-24.34,623.78},{-923.84,-24.38,624.90},{-926.20,-24.41,625.99},{-928.58,-24.41,627.04},{-931.05,-24.41,628.11},{-933.35,-24.41,629.10},{-935.84,-24.41,630.14},{-938.25,-24.41,631.12},
    {-940.68,-24.41,632.05},{-943.20,-24.41,633.01},{-945.54,-24.41,633.90},{-948.07,-24.41,634.83},{-950.53,-24.41,635.67},{-953.00,-24.41,636.47},{-955.49,-24.41,637.23},{-957.99,-24.43,637.94},
    {-960.59,-24.46,638.65},{-963.10,-24.29,639.28},{-965.72,-24.37,639.93},{-968.34,-24.36,640.57},{-970.87,-24.25,641.19},{-973.39,-24.24,641.81},{-975.87,-24.05,642.43},{-978.14,-24.29,642.98},
    {-980.51,-25.46,643.57},{-983.12,-25.32,644.21},{-985.63,-25.11,644.83},{-988.09,-24.30,645.44},{-990.51,-23.92,646.02},{-993.05,-24.13,646.54},{-995.61,-24.00,646.91},{-998.26,-24.12,647.23},
    {-1000.79,-24.53,647.50},{-1003.37,-24.30,647.73},{-1005.96,-24.31,647.93},{-1008.55,-24.37,648.13},{-1011.07,-24.32,648.31},{-1013.66,-24.42,648.44},{-1016.26,-24.41,648.57},{-1018.92,-24.41,648.70},
    {-1021.52,-24.39,648.83},{-1024.11,-24.32,648.96},{-1026.66,-25.08,649.07},{-1029.23,-25.06,649.09},{-1031.75,-24.46,649.09},{-1034.32,-24.13,649.10},{-1036.91,-24.37,649.10},{-1039.58,-24.35,649.11},
    {-1042.17,-24.14,649.11},{-1044.75,-23.97,649.12},{-1047.28,-23.21,649.12},{-1049.74,-22.33,649.12},{-1052.22,-21.45,649.13},{-1054.67,-20.58,649.13},{-1057.23,-19.57,649.14},{-1059.73,-18.78,649.14},
    {-1062.18,-17.92,649.15},{-1064.71,-16.94,649.15},{-1067.23,-16.12,649.16},{-1069.69,-15.25,649.16},{-1072.14,-14.38,649.17},{-1074.59,-13.51,649.17},{-1077.11,-12.62,649.18},{-1079.56,-11.75,649.18},
    {-1082.00,-10.87,649.19},{-1084.48,-9.99,649.19},{-1087.01,-9.10,649.20},{-1089.46,-8.23,649.20},{-1091.97,-7.31,649.21},{-1094.49,-6.45,649.21},{-1096.94,-5.58,649.22},{-1099.40,-4.70,649.22},
    {-1101.85,-3.83,649.23},{-1104.36,-2.88,649.23},{-1106.86,-1.70,649.23},{-1109.38,-1.15,649.24},{-1111.86,-0.26,649.24},{-1114.37,0.68,649.25},{-1116.84,1.51,649.25},{-1119.42,2.74,649.26},
    {-1122.01,2.78,649.26},{-1124.68,2.78,649.27},{-1127.28,2.78,649.27},{-1129.95,2.78,649.28},{-1132.48,2.78,649.28},{-1135.14,2.78,649.29},{-1137.74,2.78,649.29},{-1140.34,2.78,649.30},
    {-1143.01,2.78,649.30},{-1145.61,2.78,649.31},{-1148.21,2.78,649.31},{-1150.81,2.78,649.32},{-1153.47,2.78,649.32},{-1156.07,2.78,649.33},{-1158.67,2.78,649.33},{-1161.34,2.78,649.34},
    {-1163.94,2.78,649.34},{-1166.54,2.78,649.35},{-1169.14,2.79,649.35},{-1171.58,3.63,649.35},{-1174.10,4.37,649.36},{-1177.24,4.95,649.36},{-1179.84,4.99,649.34},{-1182.54,4.99,649.32},
    {-1185.14,5.00,649.29},{-1187.72,5.17,649.27},{-1190.28,5.50,649.24},{-1192.85,5.14,649.22},{-1195.41,5.38,649.19},{-1198.10,5.10,649.20},{-1200.70,5.11,649.22},{-1203.29,5.11,649.25},
    {-1205.89,5.01,649.28},{-1208.49,4.99,649.29},{-1211.09,4.99,649.26},{-1213.79,4.99,649.21},{-1216.39,5.00,649.15},{-1218.99,5.10,649.10},{-1221.59,5.11,649.04},{-1224.39,5.11,648.99},
    {-1226.99,5.10,648.93},{-1229.59,4.99,648.88},{-1232.19,4.96,648.83},{-1234.79,4.99,648.77},{-1237.48,4.99,648.72},{-1240.08,4.99,648.66},{-1242.68,4.99,648.61},{-1245.38,4.99,648.55},
    {-1247.88,5.00,648.50},{-1250.55,5.27,648.44},{-1253.13,5.61,648.39},{-1255.14,5.26,648.38},{-1257.18,4.66,648.44},{-1258.62,3.01,648.51}
}
--[[EMBED_END]]
    if EMBEDDED then
        for _, pt in ipairs(EMBEDDED) do
            table.insert(waypoints, Vector3.new(pt[1], pt[2], pt[3]))
        end
        print(string.format("[EF Master] Tier 3 (Embedded): Loaded %d waypoints", #waypoints))
    end
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
                            local backlineMob = nil

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
                                    backlineMob = mob
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
                                closestMob = closestMob,
                                backlineMob = backlineMob
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
            room5ShortcutDone = false
        end

        local inRoom5Shortcut = treeKilledThisRun and not room5ShortcutDone and myPos.Z < 504 and myPos.X < -630
        local target = getTargetCluster(myPos)

        -- If we can already see Room 6 mobs and are near the doorway, finish shortcut immediately!
        if target and target.room == "room6" and myPos.Z >= 480 then
            room5ShortcutDone = true
            inRoom5Shortcut = false
            shortcutActive = false
            currentWpIndex = findClosestWaypointIndex(myPos, 615, 630)
        end

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
                    room5ShortcutDone = true
                    shortcutActive = false
                    currentWpIndex = findClosestWaypointIndex(myPos, 615, 630)
                    print(string.format("[EF Master] Room 5 bump bypass complete! Resumed at highway wp %d", currentWpIndex))
                end
            end

            if not room5ShortcutDone then
                phaseLabel.Text = string.format("Phase: Bypass Bump (%d/%d)", shortcutIdx, #SHORTCUT_POINTS)
                statusLabel.Text = string.format("Status: Skirting Bump to Room 6 (%.0f studs)", (targetPt - myPos).Magnitude)
                statusLabel.TextColor3 = Color3.fromRGB(0, 255, 200)

                hum.AutoRotate = true
                if isQReady() then
                    castQ()
                end
                smoothMoveTo(hum, targetPt)

                if (myPos - SHORTCUT_POINTS[#SHORTCUT_POINTS]).Magnitude <= 14 or myPos.Z >= 504 then
                    room5ShortcutDone = true
                    shortcutActive = false
                    currentWpIndex = findClosestWaypointIndex(myPos, 615, 630)
                    print(string.format("[EF Master] Room 5 bump bypass complete! Resumed at highway wp %d", currentWpIndex))
                end
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

                        local eReady = isEReady()
                        local qBuff = isQBuffActive()
                        local qReady = isQReady()

                        if eReady then
                            -- Guarantee Q buff is active before striking boss
                            if not qBuff and qReady then
                                castQ()
                                task.wait(0.12)
                                qBuff = isQBuffActive()
                            end

                            if qBuff then
                                isCastingCombo = true
                                statusLabel.Text = "Status: Striking Boss with Q Buff + E!"
                                statusLabel.TextColor3 = Color3.fromRGB(255, 60, 180)

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
                                statusLabel.Text = string.format("Status: Boss in range, waiting Q buff (%.1fs)", qCd)
                                statusLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
                            end
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

                -- ZONE 3: AoE WIPE ZONE (Backline is <= 65 studs)
                -- 65 studs guarantees that even on deep 9-mob packs (like Room 6 tunnel), 100% of mobs are inside E's blast radius
                if backDist <= 65 then
                    hum:MoveTo(myPos)
                    hum.AutoRotate = false

                    -- Shift-lock aim: for spread-out packs (spread > 18 studs), aim deeper towards backline so E penetrates all 9 mobs
                    local aimPos = target.centerPos
                    if target.backlineMob and (target.backlineDist - target.minDist > 18) then
                        aimPos = target.centerPos:Lerp(target.backlineMob.pos, 0.45)
                    end
                    local lookPos = Vector3.new(aimPos.X, hrp.Position.Y, aimPos.Z)
                    hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)

                    local eReady = isEReady()
                    local qBuff = isQBuffActive()
                    local qReady = isQReady()

                    if eReady then
                        -- If buff not active but Q ready, pop Q first to guarantee 1-shot!
                        if not qBuff and qReady then
                            castQ()
                            task.wait(0.12)
                            qBuff = isQBuffActive()
                        end

                        if qBuff then
                            isCastingCombo = true
                            statusLabel.Text = string.format("Status: Wiping Pack with Q Buff (%d mobs)!", target.count)
                            statusLabel.TextColor3 = Color3.fromRGB(255, 80, 200)

                            -- Re-aim at penetration aimPos
                            lookPos = Vector3.new(aimPos.X, hrp.Position.Y, aimPos.Z)
                            hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)

                            -- Detonate E
                            castE()
                            task.wait(0.5)
                            isCastingCombo = false
                        else
                            -- E is ready, but Q buff is expired/inactive and Q is on cooldown!
                            -- HOLD FIRE! Do not waste E without the +80% damage buff!
                            statusLabel.Text = string.format("Status: In Range, Waiting Q Buff for 1-Shot (%.1fs)", qCd)
                            statusLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
                        end
                    else
                        statusLabel.Text = string.format("Status: Wipe stance (E CD: %.1fs)", eCd)
                        statusLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
                    end

                -- ZONE 2: SAFE STANDOFF GUARD (Stop at 75 studs if E is on CD or Q buff is not active and Q is on CD)
                elseif minDist <= 75 and ((not isEReady()) or (not isQBuffActive() and not isQReady())) then
                    hum:MoveTo(myPos)
                    hum.AutoRotate = false
                    local aimPos = target.centerPos
                    if target.backlineMob and (target.backlineDist - target.minDist > 18) then
                        aimPos = target.centerPos:Lerp(target.backlineMob.pos, 0.45)
                    end
                    local lookPos = Vector3.new(aimPos.X, hrp.Position.Y, aimPos.Z)
                    hrp.CFrame = CFrame.lookAt(hrp.Position, lookPos)

                    -- Pre-buff Q before breaking standoff so we start sprinting with buff already active!
                    if isQReady() and (eCd <= 1.2 or isEReady()) then
                        castQ()
                        statusLabel.Text = "Status: Pre-Buffing Q in Standoff!"
                        statusLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
                    else
                        local waitReason = not isEReady() and string.format("E CD: %.1fs", eCd) or string.format("Q CD: %.1fs", qCd)
                        statusLabel.Text = string.format("Status: Safe Standoff (%s)", waitReason)
                        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
                    end

                -- ZONE 1 & HIGHWAY ADVANCE: NEVER LEAVE RECORDED HIGHWAY WAYPOINTS!
                else
                    hum.AutoRotate = true

                    -- Pre-buff Q on the run when approaching pack (minDist <= 115) and E is ready or almost ready
                    if isQReady() and minDist <= 115 and (eCd <= 1.5 or isEReady()) then
                        castQ()
                        statusLabel.Text = "Status: Sprint Buff Q Activated!"
                        statusLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
                    end

                    local lookaheadIdx = math.min(totalWps, currentWpIndex + 5)
                    local targetWp = waypoints[lookaheadIdx] or waypoints[currentWpIndex]
                    if targetWp then
                        smoothMoveTo(hum, targetWp)
                        if minDist <= 75 then
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
        room5ShortcutDone = false
        shortcutActive = false
        shortcutIdx = 1
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
            room5ShortcutDone = false
            bossHitsLanded = 0
            startTime = tick()
            isCastingCombo = false
            isReplaying = false

            print("[EF Master v1.3] State reset for new run. Ready to farm!")
        end
    end
end)

print("[EF Master v1.3] Enchanted Forest Nightmare Master Auto-Farm Loaded Successfully!")
