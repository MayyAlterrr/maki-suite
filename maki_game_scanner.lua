-- ========================================================================
--  PROJECT MAKI: COMPLETE GAME, SHOP & BOSS RAID SCANNER (TIER 1 - 30)
--  FILE: maki_game_scanner.lua
--  AUTHOR: DeepMind Antigravity x Maki
-- ========================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local getGuiParent = function()
    if typeof(gethui) == "function" then
        return gethui()
    elseif CoreGui then
        return CoreGui
    else
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

local remotes = ReplicatedStorage:WaitForChild("remotes", 10)
local reloadInvyRemote = remotes and remotes:FindFirstChild("reloadInvy")
local sellItemEventRemote = remotes and remotes:FindFirstChild("sellItemEvent")
local getPriceRemote = remotes and remotes:FindFirstChild("getGoldGamepassPrice")
local buyPassRemote = remotes and remotes:FindFirstChild("requestGoldGamepassPurchase")

local ScanData = {
    player = LocalPlayer.Name,
    userId = LocalPlayer.UserId,
    level = 0,
    gold = 0,
    gems = 0,
    placeId = game.PlaceId,
    inventory = {
        total = 0,
        weapons = 0,
        abilities = 0,
        chests = 0,
        helmets = 0,
        keys = 0,
    },
    tierCounts = {},
    bossRaidItemsList = {},
    gamepasses = {
        { id = "goldGamepass",      name = "2x Gold",     price = 0, owned = false, reqLevel = 145 },
        { id = "extraItemGamepass",  name = "+1 Drops",    price = 0, owned = false, reqLevel = 145 },
        { id = "vip",               name = "VIP",         price = 0, owned = false, reqLevel = 145 },
        { id = "freeStatResets",    name = "Stat Reset",  price = 0, owned = false, reqLevel = 145 },
    }
}

local function runFullScan()
    -- 1. Refresh Leaderstats
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    ScanData.level = (ls and ls:FindFirstChild("Level")) and ls.Level.Value or 0
    ScanData.gold = (ls and ls:FindFirstChild("Gold")) and ls.Gold.Value or 0
    ScanData.gems = (ls and ls:FindFirstChild("Gems")) and ls.Gems.Value or 0

    -- 2. Scan Gamepasses
    for _, gp in ipairs(ScanData.gamepasses) do
        local pVal = LocalPlayer:FindFirstChild(gp.id)
        if pVal and pVal:IsA("BoolValue") and pVal.Value == true then
            gp.owned = true
        else
            gp.owned = false
        end

        if getPriceRemote then
            local ok, res = pcall(function() return getPriceRemote:InvokeServer(gp.id) end)
            if ok and type(res) == "table" then
                gp.price = res.cost or gp.price
                if res.owned == true then gp.owned = true end
                if res.level then gp.reqLevel = res.level end
            end
        end
    end

    -- 3. Scan Inventory & Boss Raid Items (Tiers 1 - 30)
    ScanData.tierCounts = {}
    ScanData.bossRaidItemsList = {}
    ScanData.inventory = { total = 0, weapons = 0, abilities = 0, chests = 0, helmets = 0, keys = 0 }

    if reloadInvyRemote then
        local ok, inv = pcall(function() return reloadInvyRemote:InvokeServer() end)
        if ok and type(inv) == "table" then
            for catKey, catTbl in pairs(inv) do
                if type(catTbl) == "table" then
                    local count = 0
                    for itemKey, item in pairs(catTbl) do
                        count = count + 1
                        ScanData.inventory.total = ScanData.inventory.total + 1

                        if type(item) == "table" then
                            local name = tostring(item.name or item.displayName or itemKey)
                            local tierMatch = name:match("%+%s*(%d+)")
                            local isRaidReq = (tonumber(item.levelReq) == 130)
                            local isRaidKey = name:lower():find("raid") ~= nil

                            if tierMatch or isRaidReq or isRaidKey then
                                local tierNum = tonumber(tierMatch) or (isRaidReq and 130 or 0)
                                ScanData.tierCounts[tierNum] = (ScanData.tierCounts[tierNum] or 0) + 1

                                table.insert(ScanData.bossRaidItemsList, {
                                    category = catKey,
                                    key = tostring(itemKey),
                                    name = name,
                                    tier = tierNum,
                                    rarity = item.rarity or "common",
                                    levelReq = item.levelReq or 0,
                                    sellPrice = item.sellPrice or 0,
                                    equipped = (item.equipped == true) or (type(item.equipped) == "table" and (item.equipped.q or item.equipped.e)),
                                    uniqueId = item.UniqueItemID or item.uniqueItemId or "none"
                                })
                            end
                        end
                    end
                    if ScanData.inventory[catKey] ~= nil then
                        ScanData.inventory[catKey] = count
                    end
                end
            end
        end
    end

    return ScanData
end

-- ========================================================================
--  AUTO-SELL LOGIC (DISCOVERED ENGINE: itemNum:UniqueItemID)
-- ========================================================================
local function sellAllBossRaidItems()
    if not reloadInvyRemote or not sellItemEventRemote then return 0 end
    local ok, inv = pcall(function() return reloadInvyRemote:InvokeServer() end)
    if not ok or type(inv) ~= "table" then return 0 end

    local payload = { weapon = {}, ability = {}, chest = {}, helmet = {} }
    local soldCount = 0

    local function scanCat(catKey, tbl)
        if type(tbl) ~= "table" then return end
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                local isEquipped = (v.equipped == true) or (type(v.equipped) == "table" and (v.equipped.q or v.equipped.e))
                if not isEquipped then
                    local name = tostring(v.name or v.displayName or k)
                    local isRaidTier = name:match("%+%s*%d+") ~= nil
                    local isRaidReq  = (tonumber(v.levelReq) == 130)
                    local isRaidKey  = name:lower():find("raid") ~= nil

                    if isRaidTier or isRaidReq or isRaidKey then
                        local idNum = tonumber(string.match(tostring(k), "%d+"))
                        if idNum then
                            local uid = v.UniqueItemID or v.uniqueItemId or "none"
                            table.insert(payload[catKey], tostring(idNum) .. ":" .. tostring(uid))
                            soldCount = soldCount + 1
                        end
                    end
                end
            end
        end
    end

    scanCat("weapon", inv.weapons)
    scanCat("ability", inv.abilities)
    scanCat("chest", inv.chests)
    scanCat("helmet", inv.helmets)

    if soldCount > 0 then
        sellItemEventRemote:FireServer(payload)
        task.wait(0.5)
        runFullScan()
    end

    return soldCount
end

-- ========================================================================
--  GUI DASHBOARD
-- ========================================================================
local existingGui = getGuiParent():FindFirstChild("MakiGameScannerGui")
if existingGui then existingGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MakiGameScannerGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = getGuiParent()

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 480, 0, 480)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -240)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(1, -70, 1, 0)
titleLbl.Position = UDim2.new(0, 12, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🔍 MAKI GAME, SHOP & RAID SCANNER (TIER 1-30)"
titleLbl.TextColor3 = Color3.fromRGB(0, 220, 180)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 12
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 28, 0, 24)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.Activated:Connect(function() screenGui:Destroy() end)

local scroll = Instance.new("ScrollingFrame", mainFrame)
scroll.Size = UDim2.new(1, -20, 1, -100)
scroll.Position = UDim2.new(0, 10, 0, 42)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new(0, 0, 0, 620)

local logText = Instance.new("TextLabel", scroll)
logText.Size = UDim2.new(1, -10, 1, 0)
logText.Position = UDim2.new(0, 5, 0, 0)
logText.BackgroundTransparency = 1
logText.TextColor3 = Color3.fromRGB(220, 220, 230)
logText.Font = Enum.Font.Code
logText.TextSize = 11
logText.TextXAlignment = Enum.TextXAlignment.Left
logText.TextYAlignment = Enum.TextYAlignment.Top

local function updateDisplay()
    local data = runFullScan()
    local lines = {}
    table.insert(lines, "==========================================================")
    table.insert(lines, string.format("👤 PLAYER: %s | Lv: %d | Gold: %s | Gems: %d", data.player, data.level, tostring(data.gold), data.gems))
    table.insert(lines, string.format("🌍 PLACE ID: %d | JOB: %s", data.placeId, game.JobId:sub(1, 8) .. "..."))
    table.insert(lines, "==========================================================")
    table.insert(lines, "📦 INVENTORY SUMMARY:")
    table.insert(lines, string.format("   • Total Items: %d / 300", data.inventory.total))
    table.insert(lines, string.format("   • Weapons: %d | Abilities: %d | Chests: %d | Helmets: %d", 
        data.inventory.weapons, data.inventory.abilities, data.inventory.chests, data.inventory.helmets))
    table.insert(lines, "")
    table.insert(lines, "⚔️ BOSS RAID ITEMS BREAKDOWN (TIERS 1 - 30):")
    table.insert(lines, string.format("   • Total Raid Items Found: %d", #data.bossRaidItemsList))
    
    local tierKeys = {}
    for t in pairs(data.tierCounts) do table.insert(tierKeys, t) end
    table.sort(tierKeys, function(a, b) return tonumber(a) < tonumber(b) end)
    for _, t in ipairs(tierKeys) do
        table.insert(lines, string.format("   • Tier %s Items: %d items", tostring(t), data.tierCounts[t]))
    end

    if #data.bossRaidItemsList > 0 then
        table.insert(lines, "   Sample Raid Drops:")
        for i = 1, math.min(4, #data.bossRaidItemsList) do
            local item = data.bossRaidItemsList[i]
            table.insert(lines, string.format("     [%d] %s (%s, Lv %d, Sell: %s Gold)", 
                i, item.name, item.rarity:upper(), item.levelReq, tostring(item.sellPrice)))
        end
    end

    table.insert(lines, "")
    table.insert(lines, "🛒 GAMEPASS SHOP STATUS (GOLD PURCHASES):")
    for idx, gp in ipairs(data.gamepasses) do
        local status = gp.owned and "✅ [OWNED]" or (data.gold >= gp.price and "🟢 [AFFORDABLE]" or "🔴 [LOCKED/NEED GOLD]")
        table.insert(lines, string.format("   %d. %s (%s): %s Gold | Req Lv %d | %s",
            idx, gp.name, gp.id, tostring(gp.price), gp.reqLevel, status))
    end
    table.insert(lines, "==========================================================")

    logText.Text = table.concat(lines, "\n")
end

-- Action Buttons at bottom
local bottomBar = Instance.new("Frame", mainFrame)
bottomBar.Size = UDim2.new(1, -20, 0, 48)
bottomBar.Position = UDim2.new(0, 10, 1, -54)
bottomBar.BackgroundTransparency = 1

local rescanBtn = Instance.new("TextButton", bottomBar)
rescanBtn.Size = UDim2.new(0.31, 0, 0, 36)
rescanBtn.Position = UDim2.new(0, 0, 0, 6)
rescanBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 160)
rescanBtn.Text = "🔄 RE-SCAN"
rescanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rescanBtn.Font = Enum.Font.GothamBold
rescanBtn.TextSize = 10
Instance.new("UICorner", rescanBtn).CornerRadius = UDim.new(0, 4)
rescanBtn.Activated:Connect(function()
    rescanBtn.Text = "Scanning..."
    updateDisplay()
    rescanBtn.Text = "🔄 RE-SCAN"
end)

local sellBtn = Instance.new("TextButton", bottomBar)
sellBtn.Size = UDim2.new(0.35, 0, 0, 36)
sellBtn.Position = UDim2.new(0.33, 0, 0, 6)
sellBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 20)
sellBtn.Text = "🗑️ SELL RAID ITEMS"
sellBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sellBtn.Font = Enum.Font.GothamBold
sellBtn.TextSize = 10
Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 4)
sellBtn.Activated:Connect(function()
    sellBtn.Text = "Selling..."
    local count = sellAllBossRaidItems()
    sellBtn.Text = string.format("Sold %d!", count)
    updateDisplay()
    task.wait(1.5)
    sellBtn.Text = "🗑️ SELL RAID ITEMS"
end)

local copyBtn = Instance.new("TextButton", bottomBar)
copyBtn.Size = UDim2.new(0.31, 0, 0, 36)
copyBtn.Position = UDim2.new(0.69, 0, 0, 6)
copyBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 70)
copyBtn.Text = "📋 COPY REPORT"
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 10
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 4)
copyBtn.Activated:Connect(function()
    if typeof(setclipboard) == "function" then
        setclipboard(logText.Text)
        copyBtn.Text = "COPIED!"
        task.wait(1.5)
        copyBtn.Text = "📋 COPY REPORT"
    end
end)

-- Initial run
updateDisplay()
print("[MAKI SCANNER] Full Scanner UI Initialized Successfully!")
