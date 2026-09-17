-- ========================================================================
--  PROJECT MAKI: STANDALONE ANTI-ADMIN & INTRUDER EMERGENCY KICK
--  VERSION: 2.1 (PERSISTENT UI + CLEAN KICK EDITION)
-- ========================================================================
--  FEATURES:
--    • Sleek, draggable in-game GUI to view, add, and remove accounts.
--    • Automatically saves accounts to "maki_anti_admin_accounts.json"
--      so it permanently remembers your accounts across runs & teleports.
--    • Standalone: Zero connection to dqr_party_config.json.
--    • Live Status: Shows DORMANT (in Lobby) vs ARMED (in Dungeon).
--    • Instant Safe Kick (<50ms) if an unwhitelisted player/admin enters.
-- ========================================================================

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local UserInputService  = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer

local SAVE_FILE_NAME    = "maki_anti_admin_accounts.json"

-- Prevent duplicate instances of this script
if _G.MAKI_ANTI_ADMIN_RUNNING then
    _G.MAKI_ANTI_ADMIN_RUNNING = false
    task.wait(0.2)
end
_G.MAKI_ANTI_ADMIN_RUNNING = true

-- Safely locate GUI container
local function getGuiParent()
    if typeof(gethui) == "function" then
        return gethui()
    elseif CoreGui then
        return CoreGui
    else
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

-- ========================================================================
--  [1] PERSISTENT DATA ENGINE
-- ========================================================================
local AllowedAccounts = {}

local function safeReadFile(fileName)
    if typeof(readfile) == "function" then
        local ok, res = pcall(readfile, fileName)
        if ok and res and #res > 0 then return res end
    end
    return nil
end

local function safeWriteFile(fileName, content)
    if typeof(writefile) == "function" then
        return pcall(writefile, fileName, content)
    end
    return false
end

local function saveAccountsToDisk()
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(AllowedAccounts)
    end)
    if ok and encoded then
        safeWriteFile(SAVE_FILE_NAME, encoded)
    end
end

local function loadAccountsFromDisk()
    local raw = safeReadFile(SAVE_FILE_NAME)
    if raw then
        local ok, parsed = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if ok and type(parsed) == "table" then
            AllowedAccounts = parsed
            return
        end
    end
    AllowedAccounts = {}
end

loadAccountsFromDisk()

-- Helper functions for accounts list
local function isAccountListed(name)
    if not name or #name == 0 then return false end
    local lower = string.lower(name)
    for _, acc in ipairs(AllowedAccounts) do
        if string.lower(acc) == lower then
            return true
        end
    end
    return false
end

local function addAccount(name)
    local trimmed = name and name:match("^%s*(.-)%s*$")
    if not trimmed or #trimmed == 0 then return false end
    if isAccountListed(trimmed) then return false end
    table.insert(AllowedAccounts, trimmed)
    saveAccountsToDisk()
    return true
end

local function removeAccount(name)
    local lower = string.lower(name)
    for idx, acc in ipairs(AllowedAccounts) do
        if string.lower(acc) == lower then
            table.remove(AllowedAccounts, idx)
            saveAccountsToDisk()
            return true
        end
    end
    return false
end

-- Always ensure current client is whitelisted
local function isWhitelisted(player)
    if not player then return true end
    if player == LocalPlayer then return true end
    return isAccountListed(player.Name)
end

-- ========================================================================
--  [2] DUNGEON VS LOBBY DETECTION
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

-- ========================================================================
--  [3] EMERGENCY KICK ENGINE
-- ========================================================================
local isKicked = false

local function emergencyKick(reason)
    if isKicked then return end
    isKicked = true

    print(string.format("[MAKI SECURITY] 🚨 %s - DISCONNECTING CLIENT", tostring(reason)))

    local message = string.format(
        "\n[MAKI SECURITY GUARD]\n\nSecurity Alert: Unauthorized user entered private dungeon.\n%s\n\nDisconnected to protect your account.",
        tostring(reason)
    )

    -- Immediately disconnect player from server
    pcall(function()
        LocalPlayer:Kick(message)
    end)
end

-- ========================================================================
--  [4] INTRUSION SCANNER
-- ========================================================================
local function evaluatePlayer(player)
    if not isDungeon() then return end
    if not player or player == LocalPlayer then return end

    if not isWhitelisted(player) then
        emergencyKick(string.format("Unwhitelisted player entered dungeon: '%s' (UserId: %d)", player.Name, player.UserId))
    end
end

Players.PlayerAdded:Connect(evaluatePlayer)

-- Continuous sweep loop
task.spawn(function()
    task.wait(1.0)
    while _G.MAKI_ANTI_ADMIN_RUNNING do
        task.wait(1.5)
        if isDungeon() then
            for _, player in ipairs(Players:GetPlayers()) do
                evaluatePlayer(player)
            end
        end
    end
end)

-- ========================================================================
--  [5] MODERN GRAPHICAL USER INTERFACE
-- ========================================================================
local parent = getGuiParent()
local existingGui = parent:FindFirstChild("MakiAntiAdminGui")
if existingGui then existingGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MakiAntiAdminGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parent

-- Draggable Main Window Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 370)
MainFrame.Position = UDim2.new(0, 40, 0, 180)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(50, 58, 75)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Make MainFrame Draggable
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = Color3.fromRGB(25, 29, 38)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -70, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🛡️ MAKI ANTI-ADMIN GUARD"
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
TitleLabel.TextSize = 13
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Minimize Button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 24, 0, 24)
MinBtn.Position = UDim2.new(1, -56, 0, 6)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 60)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
MinBtn.TextSize = 13
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

-- Close / Hide Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -28, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(75, 25, 30)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
CloseBtn.TextSize = 12
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Status Card
local StatusCard = Instance.new("Frame")
StatusCard.Size = UDim2.new(1, -24, 0, 36)
StatusCard.Position = UDim2.new(0, 12, 0, 46)
StatusCard.BackgroundColor3 = Color3.fromRGB(25, 29, 38)
StatusCard.BorderSizePixel = 0
StatusCard.Parent = MainFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 8)
StatusCorner.Parent = StatusCard

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 10, 0, 10)
StatusDot.Position = UDim2.new(0, 12, 0.5, -5)
StatusDot.BackgroundColor3 = Color3.fromRGB(255, 185, 40)
StatusDot.BorderSizePixel = 0
StatusDot.Parent = StatusCard

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = StatusDot

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -34, 1, 0)
StatusLabel.Position = UDim2.new(0, 30, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Detecting..."
StatusLabel.TextColor3 = Color3.fromRGB(210, 215, 225)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusCard

-- Input Row (TextBox + Add Button)
local InputFrame = Instance.new("Frame")
InputFrame.Size = UDim2.new(1, -24, 0, 34)
InputFrame.Position = UDim2.new(0, 12, 0, 90)
InputFrame.BackgroundTransparency = 1
InputFrame.Parent = MainFrame

local NameBox = Instance.new("TextBox")
NameBox.Size = UDim2.new(1, -64, 1, 0)
NameBox.Position = UDim2.new(0, 0, 0, 0)
NameBox.BackgroundColor3 = Color3.fromRGB(28, 32, 43)
NameBox.BorderSizePixel = 0
NameBox.PlaceholderText = "Type username to allow..."
NameBox.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
NameBox.Text = ""
NameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
NameBox.TextSize = 12
NameBox.Font = Enum.Font.Gotham
NameBox.ClearTextOnFocus = false
NameBox.Parent = InputFrame

local BoxCorner = Instance.new("UICorner")
BoxCorner.CornerRadius = UDim.new(0, 6)
BoxCorner.Parent = NameBox

local BoxPadding = Instance.new("UIPadding")
BoxPadding.PaddingLeft = UDim.new(0, 10)
BoxPadding.Parent = NameBox

local AddBtn = Instance.new("TextButton")
AddBtn.Size = UDim2.new(0, 56, 1, 0)
AddBtn.Position = UDim2.new(1, -56, 0, 0)
AddBtn.BackgroundColor3 = Color3.fromRGB(35, 120, 75)
AddBtn.BorderSizePixel = 0
AddBtn.Text = "+ Add"
AddBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AddBtn.TextSize = 12
AddBtn.Font = Enum.Font.GothamBold
AddBtn.Parent = InputFrame

local AddCorner = Instance.new("UICorner")
AddCorner.CornerRadius = UDim.new(0, 6)
AddCorner.Parent = AddBtn

-- Section Header
local SectionLabel = Instance.new("TextLabel")
SectionLabel.Size = UDim2.new(1, -24, 0, 20)
SectionLabel.Position = UDim2.new(0, 12, 0, 130)
SectionLabel.BackgroundTransparency = 1
SectionLabel.Text = "ALLOWED ACCOUNTS (SAVED)"
SectionLabel.TextColor3 = Color3.fromRGB(140, 148, 165)
SectionLabel.TextSize = 11
SectionLabel.Font = Enum.Font.GothamBold
SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
SectionLabel.Parent = MainFrame

-- Scroll Frame for Account List
local ScrollList = Instance.new("ScrollingFrame")
ScrollList.Size = UDim2.new(1, -24, 0, 198)
ScrollList.Position = UDim2.new(0, 12, 0, 154)
ScrollList.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
ScrollList.BorderSizePixel = 0
ScrollList.ScrollBarThickness = 4
ScrollList.ScrollBarImageColor3 = Color3.fromRGB(60, 70, 90)
ScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollList.Parent = MainFrame

local ScrollCorner = Instance.new("UICorner")
ScrollCorner.CornerRadius = UDim.new(0, 8)
ScrollCorner.Parent = ScrollList

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 6)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ScrollList

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 6)
ListPadding.PaddingBottom = UDim.new(0, 6)
ListPadding.PaddingLeft = UDim.new(0, 6)
ListPadding.PaddingRight = UDim.new(0, 6)
ListPadding.Parent = ScrollList

-- Refresh UI Accounts List
local function refreshAccountListUI()
    for _, child in ipairs(ScrollList:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local totalHeight = 0
    local rowHeight = 28
    local rowSpacing = 6

    for idx, accName in ipairs(AllowedAccounts) do
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, rowHeight)
        Row.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
        Row.BorderSizePixel = 0
        Row.Parent = ScrollList

        local RowCorner = Instance.new("UICorner")
        RowCorner.CornerRadius = UDim.new(0, 6)
        RowCorner.Parent = Row

        local AccLabel = Instance.new("TextLabel")
        AccLabel.Size = UDim2.new(1, -36, 1, 0)
        AccLabel.Position = UDim2.new(0, 10, 0, 0)
        AccLabel.BackgroundTransparency = 1
        AccLabel.Text = string.format("%d. %s", idx, accName)
        AccLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
        AccLabel.TextSize = 12
        AccLabel.Font = Enum.Font.GothamMedium
        AccLabel.TextXAlignment = Enum.TextXAlignment.Left
        AccLabel.Parent = Row

        local DelBtn = Instance.new("TextButton")
        DelBtn.Size = UDim2.new(0, 22, 0, 22)
        DelBtn.Position = UDim2.new(1, -26, 0.5, -11)
        DelBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 35)
        DelBtn.BorderSizePixel = 0
        DelBtn.Text = "✕"
        DelBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
        DelBtn.TextSize = 11
        DelBtn.Font = Enum.Font.GothamBold
        DelBtn.Parent = Row

        local DelCorner = Instance.new("UICorner")
        DelCorner.CornerRadius = UDim.new(0, 5)
        DelCorner.Parent = DelBtn

        DelBtn.MouseButton1Click:Connect(function()
            removeAccount(accName)
            refreshAccountListUI()
        end)

        totalHeight = totalHeight + rowHeight + rowSpacing
    end

    ScrollList.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 10)
    SectionLabel.Text = string.format("ALLOWED ACCOUNTS (%d SAVED)", #AllowedAccounts)
end

-- Add Button Click Handler
local function handleAddAccount()
    local text = NameBox.Text
    if addAccount(text) then
        NameBox.Text = ""
        refreshAccountListUI()
    end
end

AddBtn.MouseButton1Click:Connect(handleAddAccount)
NameBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        handleAddAccount()
    end
end)

-- Minimize & Restore Controls
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame.Size = UDim2.new(0, 320, 0, 36)
        MinBtn.Text = "+"
        StatusCard.Visible = false
        InputFrame.Visible = false
        SectionLabel.Visible = false
        ScrollList.Visible = false
    else
        MainFrame.Size = UDim2.new(0, 320, 0, 370)
        MinBtn.Text = "—"
        StatusCard.Visible = true
        InputFrame.Visible = true
        SectionLabel.Visible = true
        ScrollList.Visible = true
    end
end)

-- Hide / Re-open floating badge
local FloatingBadge = Instance.new("TextButton")
FloatingBadge.Size = UDim2.new(0, 36, 0, 36)
FloatingBadge.Position = UDim2.new(0, 40, 0, 140)
FloatingBadge.BackgroundColor3 = Color3.fromRGB(25, 29, 38)
FloatingBadge.Text = "🛡️"
FloatingBadge.TextSize = 18
FloatingBadge.Visible = false
FloatingBadge.Parent = ScreenGui

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(1, 0)
BadgeCorner.Parent = FloatingBadge

local BadgeStroke = Instance.new("UIStroke")
BadgeStroke.Color = Color3.fromRGB(50, 58, 75)
BadgeStroke.Thickness = 1.5
BadgeStroke.Parent = FloatingBadge

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatingBadge.Visible = true
end)

FloatingBadge.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    FloatingBadge.Visible = false
end)

-- Initial UI Population
refreshAccountListUI()

-- Live Status Update Loop
task.spawn(function()
    while _G.MAKI_ANTI_ADMIN_RUNNING and ScreenGui and ScreenGui.Parent do
        if isDungeon() then
            StatusDot.BackgroundColor3 = Color3.fromRGB(40, 210, 100)
            StatusLabel.Text = "Status: 🟢 ARMED (Dungeon Active)"
            StatusLabel.TextColor3 = Color3.fromRGB(160, 255, 180)
        else
            StatusDot.BackgroundColor3 = Color3.fromRGB(240, 180, 40)
            StatusLabel.Text = "Status: 🟡 DORMANT (Main Lobby)"
            StatusLabel.TextColor3 = Color3.fromRGB(240, 210, 130)
        end
        task.wait(1.0)
    end
end)

print("[MAKI SECURITY] Maki Anti-Admin UI initialized successfully with persistent storage.")
