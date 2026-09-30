-- ========================================================================
--  STANDALONE NORTHERN LANDS AUTO-SELL COMPANION (ZERO-INTERFERENCE)
-- ========================================================================
if _G.NL_AUTOSELL_RUNNING then
    _G.NL_AUTOSELL_RUNNING = false
    task.wait(0.2)
end
_G.NL_AUTOSELL_RUNNING = true

-- Toggle for farming Northern Lands Insane gear (Default: false)
if _G.NL_FARM_INSANE == nil then
    _G.NL_FARM_INSANE = false
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("remotes")
local reloadRemote = remotes:WaitForChild("reloadInvy")
local sellRemote = remotes:WaitForChild("sellItemEvent")

-- ========================================================================
--  NORTHERN LANDS (INSANE) ITEM DEFINITIONS (LEVEL 180)
-- ========================================================================
local NL_INSANE_WEAPONS = {
    ["norse blade"] = true,
    ["northern runic blade"] = true,
    ["viking hatchets"] = true,
    ["northern spellstaff"] = true,
    ["viking shield"] = true,
    ["ice spellblade"] = true,
}

local function isNLInsaneWeapon(nameLower, item)
    for wepName in pairs(NL_INSANE_WEAPONS) do
        if nameLower:find(wepName, 1, true) then
            return true
        end
    end
    local lvl = item and (item.levelReq or item.levelRequirement or item.level)
    if lvl == 180 and not nameLower:find("jotunn") and not nameLower:find("valhalla") then
        return true
    end
    return false
end

local function isNLInsaneArmor(nameLower, item)
    if nameLower:find("midgardian", 1, true) then
        return true
    end
    local lvl = item and (item.levelReq or item.levelRequirement or item.level)
    if lvl == 180 and not nameLower:find("jotunn") and not nameLower:find("valhalla") then
        return true
    end
    return false
end

local function getNLInsaneAbilityType(nameLower)
    if nameLower:find("frost cone", 1, true) then
        return "warrior"
    elseif nameLower:find("flame strike", 1, true) then
        return "mage"
    end
    return nil
end

-- ========================================================================
--  FILTER: NORTHERN LANDS SELL RULES (WEAPONS, CHESTS, HELMETS)
-- ========================================================================
local function shouldSellItem(catKey, key, item)
    local nameLower = string.lower(item.name or "")
    local rarityLower = string.lower(item.rarity or "")
    local upg = item.currentUpgrade or 0
    local isEq = (type(item.equipped) == "table" and (item.equipped.q or item.equipped.e)) or (item.equipped == true)

    -- 1. EQUIPPED: 100% immune
    if isEq then return false, "EQUIPPED" end

    -- 2. UPGRADED: >0 upgrades 100% immune
    if upg > 0 then return false, "UPGRADED" end

    -- 3. RARITY CEILING: All Legendaries, Ultimates, Mythics & Dev items 100% immune
    if rarityLower == "legendary" or rarityLower == "ultimate" or rarityLower == "mythic" or rarityLower == "dev" then
        return false, "LEGENDARY_OR_ULTIMATE"
    end

    -- 4. BUFF SPELLS: Enhanced Inner Rage & Focus 100% immune
    if nameLower:find("inner rage") or nameLower:find("inner focus") then
        return false, "PROTECTED_BUFF_SPELL"
    end

    -- 5. VALHALLA SET: ANY Valhalla piece 100% immune (any rarity)
    if nameLower:find("valhalla") then
        return false, "VALHALLA_ITEM"
    end

    -- 6. WEAPONS:
    if catKey == "weapon" then
        -- Toggle ON: NL Insane Farming Mode
        if _G.NL_FARM_INSANE and isNLInsaneWeapon(nameLower, item) then
            if rarityLower == "rare" or rarityLower == "epic" then
                return false, "NL_INSANE_WEAPON_RARE_OR_EPIC_KEEP"
            else
                return true, "NL_INSANE_WEAPON_COMMON_UNCOMMON_SELL"
            end
        end

        -- Default Weapon Rule: Keep ANY Purple/Epic weapon, sell Common/Uncommon/Rare
        if rarityLower == "epic" then
            return false, "EPIC_WEAPON"
        end
        return true, "SELLABLE_WEAPON_JUNK"
    end

    -- 7. ARMOR (Chests & Helmets):
    if catKey == "chest" or catKey == "helmet" then
        -- Toggle ON: NL Insane Farming Mode (Keep Blue/Rare & Purple/Epic Midgardian sets)
        if _G.NL_FARM_INSANE and isNLInsaneArmor(nameLower, item) then
            if rarityLower == "rare" or rarityLower == "epic" then
                return false, "NL_INSANE_ARMOR_RARE_OR_EPIC_KEEP"
            else
                return true, "NL_INSANE_ARMOR_COMMON_UNCOMMON_SELL"
            end
        end

        -- Default Armor Rule: Keep Purple/Epic Jotunn Mage & Jotunn Warrior
        if rarityLower == "epic" and nameLower:find("jotunn") then
            if nameLower:find("mage") or nameLower:find("warrior") then
                return false, "EPIC_JOTUNN_MAGE_OR_WARRIOR"
            end
        end

        -- All other armor (Midgardian when toggle OFF, Jotunn Guardian, Common/Uncommon/Rare Jotunn) -> SELL
        return true, "SELLABLE_ARMOR_JUNK"
    end

    -- 8. ABILITIES: (Fallback if called directly; abilities are state-counted in runAutoSell)
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
    if not ok or type(invy) ~= "table" then return 0, 0, 0, 0 end

    local payload = {weapon = {}, ability = {}, chest = {}, helmet = {}}
    local soldCount, keptCount = 0, 0

    -- Generic processor for weapons, chests, helmets
    local function processGeneric(tbl, catKey)
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

    processGeneric(invy.weapons, "weapon")
    processGeneric(invy.chests, "chest")
    processGeneric(invy.helmets, "helmet")

    -- Abilities processor: Quota tracking for NL Insane (Max 5 Warrior Frost Cone & 5 Mage Flame Strike)
    local warriorCount = 0
    local mageCount = 0

    -- Pass 1: Count pre-protected (equipped or upgraded) NL Insane abilities towards quota
    for k, v in pairs(invy.abilities or {}) do
        local nameLower = string.lower(v.name or "")
        local upg = v.currentUpgrade or 0
        local isEq = (type(v.equipped) == "table" and (v.equipped.q or v.equipped.e)) or (v.equipped == true)
        local abType = getNLInsaneAbilityType(nameLower)

        if abType and (isEq or upg > 0) then
            if abType == "warrior" then
                warriorCount = warriorCount + 1
            elseif abType == "mage" then
                mageCount = mageCount + 1
            end
        end
    end

    -- Pass 2: Evaluate abilities
    for k, v in pairs(invy.abilities or {}) do
        local nameLower = string.lower(v.name or "")
        local rarityLower = string.lower(v.rarity or "")
        local upg = v.currentUpgrade or 0
        local isEq = (type(v.equipped) == "table" and (v.equipped.q or v.equipped.e)) or (v.equipped == true)
        local idNum = tonumber(string.match(k, "%d+"))

        -- 100% Immune categories
        if isEq or upg > 0 then
            keptCount = keptCount + 1
        elseif rarityLower == "legendary" or rarityLower == "ultimate" or rarityLower == "mythic" or rarityLower == "dev" then
            keptCount = keptCount + 1
        elseif nameLower:find("inner rage") or nameLower:find("inner focus") or nameLower:find("valhalla") then
            keptCount = keptCount + 1
        else
            local abType = getNLInsaneAbilityType(nameLower)
            if _G.NL_FARM_INSANE and abType then
                if abType == "warrior" then
                    if warriorCount < 5 then
                        warriorCount = warriorCount + 1
                        keptCount = keptCount + 1
                    else
                        -- 6th, 7th, ... sold
                        soldCount = soldCount + 1
                        if idNum then table.insert(payload.ability, idNum) end
                    end
                elseif abType == "mage" then
                    if mageCount < 5 then
                        mageCount = mageCount + 1
                        keptCount = keptCount + 1
                    else
                        -- 6th, 7th, ... sold
                        soldCount = soldCount + 1
                        if idNum then table.insert(payload.ability, idNum) end
                    end
                end
            else
                -- Not farming NL Insane or not an NL Insane ability -> sell
                soldCount = soldCount + 1
                if idNum then table.insert(payload.ability, idNum) end
            end
        end
    end

    if soldCount > 0 then
        sellRemote:FireServer(payload)
        if _G.NL_FARM_INSANE then
            print(string.format("[NL Auto-Sell 🗑️] Sold %d junk | Protected %d items [NL Insane Spells: Warrior %d/5, Mage %d/5]", soldCount, keptCount, warriorCount, mageCount))
        else
            print(string.format("[NL Auto-Sell 🗑️] Sold %d junk items | Protected %d items", soldCount, keptCount))
        end
    else
        if _G.NL_FARM_INSANE then
            print(string.format("[NL Auto-Sell 🛡️] Clean inventory: 0 junk sold | Protected %d items [NL Insane Spells: Warrior %d/5, Mage %d/5]", keptCount, warriorCount, mageCount))
        else
            print(string.format("[NL Auto-Sell 🛡️] Clean inventory: 0 junk to sell | Protected %d items", keptCount))
        end
    end
    return soldCount, keptCount, warriorCount, mageCount
end

_G.NL_SELL_NOW = runAutoSell

-- ========================================================================
--  HUD & INTERACTIVE TOGGLE GUI (DRAGGABLE)
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
screenGui.ResetOnSpawn = false

-- Draggable Main Container Frame
local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 240, 0, 106)
mainFrame.Position = UDim2.new(0, 20, 0, 140)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = Color3.fromRGB(45, 52, 68)
stroke.Thickness = 1.2

-- Title Header
local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.Size = UDim2.new(1, -16, 0, 22)
titleLabel.Position = UDim2.new(0, 10, 0, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚡ MAKI NL AUTO-SELL"
titleLabel.TextColor3 = Color3.fromRGB(150, 180, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 11
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Toggle Button for Farming NL Insane
local toggleBtn = Instance.new("TextButton", mainFrame)
toggleBtn.Name = "ToggleFarmInsaneBtn"
toggleBtn.Size = UDim2.new(1, -16, 0, 30)
toggleBtn.Position = UDim2.new(0, 8, 0, 32)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 11
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

local function updateToggleBtnUI()
    if _G.NL_FARM_INSANE then
        toggleBtn.Text = "⚔️ FARM NL INSANE: [ON]"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(22, 110, 80)
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        toggleBtn.Text = "🌾 FARM NL INSANE: [OFF]"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 55)
        toggleBtn.TextColor3 = Color3.fromRGB(190, 190, 190)
    end
end
updateToggleBtnUI()

toggleBtn.MouseButton1Click:Connect(function()
    _G.NL_FARM_INSANE = not _G.NL_FARM_INSANE
    updateToggleBtnUI()
    print(string.format("[NL Auto-Sell] Farm NL Insane is now %s! %s",
        _G.NL_FARM_INSANE and "ENABLED" or "DISABLED",
        _G.NL_FARM_INSANE and "(Keeping Rare/Epic Midgardian & Weapons, and 5 Warrior/Mage Spells)" or "(Default NL rules)"))
end)

-- Manual Sell Button
local sellBtn = Instance.new("TextButton", mainFrame)
sellBtn.Name = "ManualSellBtn"
sellBtn.Size = UDim2.new(1, -16, 0, 30)
sellBtn.Position = UDim2.new(0, 8, 0, 68)
sellBtn.BackgroundColor3 = Color3.fromRGB(30, 85, 45)
sellBtn.Text = "🗑️ SELL NL JUNK NOW"
sellBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sellBtn.Font = Enum.Font.GothamBold
sellBtn.TextSize = 11
Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 6)

sellBtn.MouseButton1Click:Connect(function()
    sellBtn.Text = "Scanning..."
    local sold, kept, wSpells, mSpells = runAutoSell()
    sellBtn.Text = string.format("Sold %d junk!", sold)
    task.wait(2)
    sellBtn.Text = "🗑️ SELL NL JUNK NOW"
end)

-- Smooth Dragging Implementation
local isDragging, dragStart, startPos = false, nil, nil

mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
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
                local sold, kept, wSpells, mSpells = runAutoSell()
                sellBtn.Text = string.format("Victory: Sold %d!", sold)
                task.wait(3)
                sellBtn.Text = "🗑️ SELL NL JUNK NOW"
            end
        else
            hasSoldThisRound = false
        end
    end
end)

print("[NL Auto-Sell] Companion active! Draggable HUD loaded. Auto-sells on Victory without touching replay.")
