-- ========================================================================
--  MAKI STANDALONE NORTHERN LANDS AUTO-SELL & TROPHY NOTIFIER (v2.1)
--  • Zero Interference: Does NOT touch movement, combat, or replay
--  • Auto-triggers 1.5s after Victory (Dungeon Finished)
--  • Discord Webhook: 100% Silent UNLESS an Ultimate, Legendary, or Purple Valhalla drops!
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
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("remotes")
local reloadRemote = remotes:WaitForChild("reloadInvy")
local sellRemote = remotes:WaitForChild("sellItemEvent")

-- ========================================================================
--  WEBHOOK CONFIGURATION (READ SAFELY FROM LOCAL DISK)
-- ========================================================================
local function getWebhookUrl()
    if _G.NL_WEBHOOK_URL and _G.NL_WEBHOOK_URL ~= "" then
        return _G.NL_WEBHOOK_URL
    end
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        if isfile("nl_webhook.txt") then
            local content = readfile("nl_webhook.txt")
            if content and content:find("http") then
                return content:match("^%s*(.-)%s*$") -- trim whitespace
            end
        end
    end
    return nil
end

local function sendDiscordWebhook(payload)
    local url = getWebhookUrl()
    if not url or url == "" then return end

    local jsonBody = HttpService:JSONEncode(payload)
    local httpFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

    if httpFunc then
        pcall(function()
            httpFunc({
                Url = url,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonBody
            })
        end)
    else
        pcall(function()
            HttpService:PostAsync(url, jsonBody, Enum.HttpContentType.ApplicationJson)
        end)
    end
end

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
--  INVENTORY BASELINE TRACKER (ENSURES NO DUPLICATE NOTIFICATIONS)
-- ========================================================================
local knownItemIds = {}

local function recordCurrentInventoryBaseline(invy)
    if type(invy) ~= "table" then return end
    for catKey, tbl in pairs(invy) do
        if type(tbl) == "table" then
            for k, _ in pairs(tbl) do
                local idNum = tonumber(string.match(k, "%d+"))
                if idNum then
                    knownItemIds[idNum] = true
                end
            end
        end
    end
end

-- Initialize baseline on load
task.spawn(function()
    local ok, invy = pcall(function() return reloadRemote:InvokeServer() end)
    if ok and type(invy) == "table" then
        recordCurrentInventoryBaseline(invy)
        print(string.format("[NL Auto-Sell] Initialized inventory baseline (%d known items).", (function()
            local c = 0; for _ in pairs(knownItemIds) do c = c + 1 end return c
        end)()))
    end
end)

-- ========================================================================
--  TROPHY DROP NOTIFIER (ULTIMATE, LEGENDARY, & PURPLE VALHALLA ONLY)
-- ========================================================================
local function checkAndNotifyTrophyDrops(invy)
    if type(invy) ~= "table" then return end
    local trophyEmbeds = {}
    local hasUltimate = false

    local function inspectCategory(tbl, catName)
        if type(tbl) ~= "table" then return end
        for k, item in pairs(tbl) do
            local idNum = tonumber(string.match(k, "%d+"))
            -- Only inspect items that are brand-new drops from this round!
            if idNum and not knownItemIds[idNum] then
                local name = item.name or "Unknown Item"
                local nameLower = string.lower(name)
                local rarity = item.rarity or "Common"
                local rarityLower = string.lower(rarity)

                local isTrophy = false
                local trophyTier = ""
                local embedColor = 0xFFFFFF

                -- 1. ULTIMATE DROPS (Any)
                if rarityLower == "ultimate" then
                    isTrophy = true
                    hasUltimate = true
                    trophyTier = "🌟 ULTIMATE DROP"
                    embedColor = 16711765 -- Vibrant Crimson / Red

                -- 2. LEGENDARY WEAPONS OR SPELLS
                elseif rarityLower == "legendary" and (catName == "Weapons" or catName == "Abilities") then
                    isTrophy = true
                    trophyTier = "👑 LEGENDARY DROP"
                    embedColor = 16766720 -- Gold

                -- 3. ONLY PURPLE / EPIC VALHALLA
                elseif nameLower:find("valhalla") and rarityLower == "epic" then
                    isTrophy = true
                    trophyTier = "🛡️ PURPLE VALHALLA DROP"
                    embedColor = 10181046 -- Royal Purple
                end

                if isTrophy then
                    table.insert(trophyEmbeds, {
                        title = string.format("%s: %s", trophyTier, name),
                        description = string.format("A holy grail item dropped in **Northern Lands** and is safely locked in your inventory!"),
                        color = embedColor,
                        fields = {
                            {name = "Item Name", value = string.format("**%s**", name), inline = true},
                            {name = "Category", value = catName, inline = true},
                            {name = "Rarity", value = string.upper(rarity), inline = true},
                            {name = "Player", value = LocalPlayer.Name, inline = true},
                            {name = "Account Level", value = tostring(LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Level") and LocalPlayer.leaderstats.Level.Value or "N/A"), inline = true}
                        },
                        footer = {text = "Maki Auto-Sell & Trophy Notifier • Northern Lands"},
                        timestamp = DateTime.now():ToIsoDate()
                    })
                end
            end
        end
    end

    inspectCategory(invy.weapons, "Weapons")
    inspectCategory(invy.abilities, "Abilities")
    inspectCategory(invy.chests, "Armor (Chest)")
    inspectCategory(invy.helmets, "Armor (Helmet)")

    -- If any trophies dropped, send the webhook!
    if #trophyEmbeds > 0 then
        local payload = {
            content = hasUltimate and "@everyone 🚨 **ULTIMATE DROP DETECTED IN NORTHERN LANDS!** 🚨" or "🏆 **Rare Trophy Loot Dropped!**",
            embeds = trophyEmbeds
        }
        sendDiscordWebhook(payload)
        print(string.format("[NL Drop Notifier 🎯] Webhook sent for %d trophy drops!", #trophyEmbeds))
    end

    -- Update known inventory baseline
    recordCurrentInventoryBaseline(invy)
end

-- ========================================================================
--  EXECUTE AUTO-SELL
-- ========================================================================
local function runAutoSell()
    local ok, invy = pcall(function() return reloadRemote:InvokeServer() end)
    if not ok or type(invy) ~= "table" then return 0, 0 end

    -- 1. Check for trophy drops before selling anything
    checkAndNotifyTrophyDrops(invy)

    -- 2. Build sell batch payload
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

print("[NL Auto-Sell] Companion v2.1 active with Trophy Discord Webhook Notifier!")
