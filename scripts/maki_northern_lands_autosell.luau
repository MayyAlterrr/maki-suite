-- ========================================================================
--  MAKI STANDALONE NORTHERN LANDS AUTO-SELL COMPANION (v2.0)
--  • Zero Interference: Does NOT touch player movement, combat, or replay
--  • Auto-triggers 1.5s after Victory (Dungeon Finished)
--  • Manual "SELL NL JUNK NOW" button on screen
-- ========================================================================
if _G.NL_AUTOSELL_RUNNING then
    _G.NL_AUTOSELL_RUNNING = false
    task.wait(0.2)
end
_G.NL_AUTOSELL_RUNNING = true

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("remotes")
local reloadRemote = remotes:WaitForChild("reloadInvy")
local sellRemote = remotes:WaitForChild("sellItemEvent")

-- ========================================================================
--  FILTER: EXACT NORTHERN LANDS CUSTOM RULES
-- ========================================================================
local function shouldSellItem(catKey, key, item)
    local nameLower = string.lower(item.name or "")
    local rarityLower = string.lower(item.rarity or "")
    local upg = item.currentUpgrade or 0
    local isEq = (type(item.equipped) == "table" and (item.equipped.q or item.equipped.e)) or (item.equipped == true)

    -- 1. EQUIPPED LOCK: Anything equipped is 100% immune
    if isEq then return false, "EQUIPPED" end

    -- 2. UPGRADE LOCK: Anything upgraded (>0) is 100% immune
    if upg > 0 then return false, "UPGRADED" end

    -- 3. RARITY CEILING: All Legendaries & Ultimates are 100% immune (Mjolnir, Gungnir, Hofund, Laevateinn)
    if rarityLower == "legendary" or rarityLower == "ultimate" or rarityLower == "dev" then
        return false, "LEGENDARY_OR_ULTIMATE"
    end

    -- 4. VALUABLE BUFF SPELLS: Enhanced Inner Rage & Focus are 100% immune
    if nameLower:find("inner rage") or nameLower:find("inner focus") then
        return false, "PROTECTED_BUFF_SPELL"
    end

    -- 5. VALHALLA SET: Sell Common, Keep Uncommon/Rare/Epic
    if nameLower:find("valhalla") then
        if rarityLower == "common" then
            return true, "SELLABLE_COMMON_VALHALLA"
        end
        return false, "VALHALLA_ITEM"
    end

    -- 6. WEAPONS: Only keep Epic Frost Giant Greataxe and Epic Staff of the North
    if catKey == "weapon" then
        if rarityLower == "epic" then
            if nameLower:find("frost giant greataxe") or nameLower:find("staff of the north") then
                return false, "PROTECTED_TARGET_EPIC_WEAPON"
            end
            return true, "SELLABLE_NON_TARGET_EPIC_WEAPON"
        end
        -- All Common, Uncommon, and Rare weapons are sold
        return true, "SELLABLE_WEAPON_JUNK"
    end

    -- 7. ARMOR (Chests & Helmets):
    if catKey == "chest" or catKey == "helmet" then
        -- Keep Purple / Epic Jotunn Mage & Jotunn Warrior
        if rarityLower == "epic" and nameLower:find("jotunn") then
            if nameLower:find("mage") or nameLower:find("warrior") then
                return false, "EPIC_JOTUNN_MAGE_OR_WARRIOR"
            end
        end
        -- All other armor (Midgardian all tiers, Jotunn Guardian, Common/Uncommon/Rare Jotunn) -> SELL
        return true, "SELLABLE_ARMOR_JUNK"
    end

    -- 8. ABILITIES: Sell unequipped abilities even if purple/epic (except Inner Rage/Focus)
    if catKey == "ability" then
        return true, "SELLABLE_ABILITY_JUNK"
    end

    return false, "SAFETY_KEEP"
end

-- ========================================================================
--  EXECUTE AUTO-SELL
-- ========================================================================
local function runAutoSell()
    local ok, invy = pcall(function() return reloadRemote:InvokeServer() end)
    if not ok or type(invy) ~= "table" then return 0, 0 end

    local payload = {weapon = {}, ability = {}, chest = {}, helmet = {}}
    local soldCount, keptCount = 0, 0

    local function process(tbl, catKey)
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

    process(invy.weapons, "weapon")
    process(invy.abilities, "ability")
    process(invy.chests, "chest")
    process(invy.helmets, "helmet")

    if soldCount > 0 then
        sellRemote:FireServer(payload)
        print(string.format("[NL Auto-Sell 🗑️] Sold %d junk items | Protected %d items", soldCount, keptCount))
    else
        print(string.format("[NL Auto-Sell 🛡️] Inventory clean: 0 junk to sell | Protected %d items", keptCount))
    end
    return soldCount, keptCount
end

_G.NL_SELL_NOW = runAutoSell

-- ========================================================================
--  MINIMAL HUD NOTIFIER
-- ========================================================================
local guiParent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if typeof(gethui) == "function" then guiParent = gethui()
    elseif CoreGui then guiParent = CoreGui end
end)

local existing = guiParent:FindFirstChild("NL_AutoSell_HUD")
if existing then existing:Destroy() end

local screenGui = Instance.new("ScreenGui", guiParent)
screenGui.Name = "NL_AutoSell_HUD"

local btn = Instance.new("TextButton", screenGui)
btn.Size = UDim2.new(0, 180, 0, 32)
btn.Position = UDim2.new(0, 20, 0, 140)
btn.BackgroundColor3 = Color3.fromRGB(30, 85, 45)
btn.Text = "🗑️ SELL NL JUNK NOW"
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Font = Enum.Font.SourceSansBold
btn.TextSize = 13
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

btn.MouseButton1Click:Connect(function()
    btn.Text = "Scanning..."
    local sold, kept = runAutoSell()
    btn.Text = string.format("Sold %d junk!", sold)
    task.wait(2)
    btn.Text = "🗑️ SELL NL JUNK NOW"
end)

-- ========================================================================
--  VICTORY LISTENER (AUTOMATIC TRIGGER)
-- ========================================================================
task.spawn(function()
    local hasSoldThisRound = false
    while _G.NL_AUTOSELL_RUNNING do
        task.wait(0.5)
        local dung = Workspace:FindFirstChild("dungeon")
        local br = dung and dung:FindFirstChild("bossRoom")
        local df = br and br:FindFirstChild("dungeonFinished")

        if df and df:IsA("BoolValue") and df.Value == true then
            if not hasSoldThisRound then
                hasSoldThisRound = true
                -- Wait 1.5s for loot to settle in inventory
                task.wait(1.5)
                local sold, kept = runAutoSell()
                btn.Text = string.format("Victory: Sold %d!", sold)
            end
        else
            hasSoldThisRound = false
        end
    end
end)

print("[NL Auto-Sell] Companion v2.0 active! Automatically sells on Victory without touching replay.")
