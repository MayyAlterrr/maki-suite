-- ========================================================================
--  PROJECT MAKI: ALTSHIT WITCHYOYSTER
--  VERSION: 1.0 (AUTONOMOUS SWARM & ANTI-BOT DUNGEON COMPANION)
-- ========================================================================
--  FEATURES:
--    • Main Lobby:
--        - Automatically and continuously spams join requests to "WitchyOyster".
--        - Automatically readies up when in party / queueGui.
--    • Inside Dungeon:
--        - Anti-Bot Wandering: Randomly moves around the dungeon with raycast
--          ground verification (never falls off edges or into the void).
--        - Formation Awareness: Loosely stays within range of WitchyOyster
--          when nearby so alts look like real team members.
--        - Realistic Anti-Bot Jitter: Random jumps, smooth look directions,
--          and natural idle pauses.
--        - Ability & Combat Simulation: Periodically casts Q and E spells
--          and swings weapon to simulate active gameplay.
--        - Anti-AFK Engine: VirtualUser controller capture prevents 20-min kick.
--    • Host Exit Watchdog:
--        - Instant PlayerRemoving detection when WitchyOyster leaves the game.
--        - Polling monitor that detects when WitchyOyster teleports back to lobby.
--        - Automatically executes return to lobby for all alts!
--        - Automatically resumes join spam once landed in the lobby!
--    • Compact Cyber-Violet HUD:
--        - Live status, target host box, moves/casts counters, minimize & hide.
-- ========================================================================

local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local TeleportService     = game:GetService("TeleportService")
local VirtualUser         = game:GetService("VirtualUser")
local UserInputService    = game:GetService("UserInputService")
local CoreGui             = game:GetService("CoreGui")
local HttpService         = game:GetService("HttpService")
local LocalPlayer         = Players.LocalPlayer

local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

-- Anti-Duplicate Instance Management
if _G.ALTSHIT_WITCHYOYSTER_RUNNING then
    _G.ALTSHIT_WITCHYOYSTER_RUNNING = false
    task.wait(0.25)
end
_G.ALTSHIT_WITCHYOYSTER_RUNNING = true

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
--  [1] CONFIGURATION & STATE
-- ========================================================================
local TARGET_HOST = "WitchyOyster"
local AutomationEnabled = true
local isReturningToLobby = false
local hostSeenInDungeon = false
local dungeonEntryTime = 0
local totalMoves = 0
local totalCasts = 0

-- Anti-AFK Prevention
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ========================================================================
--  [2] REMOTES & NETWORKING
-- ========================================================================
local remotes = ReplicatedStorage:WaitForChild("remotes", 15)
local sendJoinRequestRemote = remotes and remotes:FindFirstChild("sendJoinRequest")
local joinDungeonRemote     = remotes and remotes:FindFirstChild("joinDungeon")
local readyUpRemote         = remotes and remotes:FindFirstChild("readyUp")
local abilityUsedRemote     = remotes and remotes:FindFirstChild("abilityUsed")
local abilityCastRemote     = remotes and remotes:FindFirstChild("abilityCast")
local weaponUsedRemote      = remotes and remotes:FindFirstChild("weaponUsed")
local teleToLobbyRemote     = remotes and (remotes:FindFirstChild("teleToLobby") or remotes:FindFirstChild("ReturnToLobbyEvent") or remotes:FindFirstChild("leaveGame"))

-- ========================================================================
--  [3] ENVIRONMENT HELPERS
-- ========================================================================
local function isDungeon()
    local dName = Workspace:FindFirstChild("dungeonName")
    if dName and dName:IsA("StringValue") and #dName.Value > 0 then
        return true
    end
    local dObj = Workspace:FindFirstChild("dungeon")
    if dObj then
        return true
    end
    local dProg = Workspace:FindFirstChild("dungeonProgress")
    if dProg and dProg:IsA("StringValue") and #dProg.Value > 0 then
        return true
    end
    return false
end

local function isMainLobby()
    return not isDungeon()
end

local function getHostPlayer()
    local lowerTarget = TARGET_HOST:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == lowerTarget or (p.DisplayName and p.DisplayName:lower() == lowerTarget) then
            return p
        end
    end
    return nil
end

-- ========================================================================
--  [4] RETURN TO LOBBY ENGINE
-- ========================================================================
local function returnToLobby()
    if isReturningToLobby then return end
    isReturningToLobby = true
    print(string.format("[AltShit] 🚪 Host '%s' left dungeon! Returning all alts to lobby...", TARGET_HOST))

    -- 1. Click ReturnToLobbyButton in PlayerGui
    local pG = LocalPlayer:FindFirstChild("PlayerGui")
    if pG then
        for _, d in ipairs(pG:GetDescendants()) do
            if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Visible then
                local text = (d:IsA("TextButton") and d.Text:lower()) or ""
                local name = d.Name:lower()
                if text:find("lobby") or text:find("return") or name:find("lobby") or name:find("return") then
                    pcall(function()
                        for _, c in ipairs(getconnections(d.Activated)) do c:Fire() end
                        for _, c in ipairs(getconnections(d.MouseButton1Click)) do c:Fire() end
                    end)
                end
            end
        end
    end

    -- 2. Fire Remotes
    if teleToLobbyRemote then
        pcall(function() teleToLobbyRemote:FireServer() end)
    end
    local rLobby = remotes and (remotes:FindFirstChild("ReturnToLobbyEvent") or remotes:FindFirstChild("teleToLobby") or remotes:FindFirstChild("leaveGame"))
    if rLobby and rLobby ~= teleToLobbyRemote then
        pcall(function() rLobby:FireServer() end)
    end

    -- 3. TeleportService fallback
    task.wait(1.5)
    pcall(function() TeleportService:Teleport(77649408247578, LocalPlayer) end)
end

-- Instant PlayerRemoving Watchdog
Players.PlayerRemoving:Connect(function(player)
    if isDungeon() and (player.Name:lower() == TARGET_HOST:lower() or (player.DisplayName and player.DisplayName:lower() == TARGET_HOST:lower())) then
        print(string.format("[AltShit] 🚨 Host '%s' left the server! Returning to lobby immediately...", player.Name))
        returnToLobby()
    end
end)

-- ========================================================================
--  [5] ABILITY & COMBAT SIMULATION
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
                elseif sName == 'e' and not eTool then eTool = item end
            end
        end
    end
    scan(LocalPlayer:FindFirstChild('Backpack'))
    scan(LocalPlayer.Character)
    if not qTool and #allTools >= 1 then qTool = allTools[1] end
    if not eTool and #allTools >= 2 then eTool = allTools[2] end
    return qTool, eTool
end

local function castSlot(slotKey, tool)
    if not tool then return end
    totalCasts = totalCasts + 1
    task.spawn(function()
        local le = tool:FindFirstChild('localEvent')
        if le and le:IsA('BindableEvent') then pcall(function() le:Fire() end) end
        local se = tool:FindFirstChild('spellEvent')
        if se and se:IsA('RemoteEvent') then pcall(function() se:FireServer() end) end
        local ev = tool:FindFirstChild('abilityEvent')
        if ev and ev:IsA('RemoteEvent') then pcall(function() ev:FireServer() end) end
        if abilityUsedRemote then pcall(function() abilityUsedRemote:FireServer(slotKey, tool) end) end
        if abilityCastRemote then pcall(function() abilityCastRemote:FireServer(slotKey) end) end
        pcall(function() tool:Activate() end)
        if VirtualInputManager then
            local key = (slotKey == 'q' and Enum.KeyCode.Q) or (slotKey == 'e' and Enum.KeyCode.E) or Enum.KeyCode.Q
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, key, false, game)
                task.wait(0.02)
                VirtualInputManager:SendKeyEvent(false, key, false, game)
            end)
        end
    end)
end

local function performRandomCombatAction()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local qTool, eTool = getAbilityTools()
    local choice = math.random(1, 3)

    if choice == 1 and qTool then
        castSlot('q', qTool)
    elseif choice == 2 and eTool then
        castSlot('e', eTool)
    else
        if weaponUsedRemote then
            pcall(function() weaponUsedRemote:FireServer() end)
        end
        local equippedTool = char:FindFirstChildOfClass("Tool")
        if equippedTool then
            pcall(function() equippedTool:Activate() end)
        elseif qTool then
            castSlot('q', qTool)
        end
    end
end

-- ========================================================================
--  [6] RAYCAST-SAFE RANDOM WANDERING
-- ========================================================================
local function isGroundSafe(targetPos)
    local rayOrigin = targetPos + Vector3.new(0, 10, 0)
    local rayDirection = Vector3.new(0, -35, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if result and result.Position then
        return true, result.Position
    end
    return false, targetPos
end

local function getRandomMoveTarget(centerPos, minRadius, maxRadius)
    for _ = 1, 8 do
        local angle = math.random() * math.pi * 2
        local dist = math.random(minRadius, maxRadius)
        local testPos = centerPos + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
        local safe, groundPos = isGroundSafe(testPos)
        if safe then
            return groundPos
        end
    end
    return centerPos
end

-- ========================================================================
--  [7] BACKGROUND AUTOMATION THREADS
-- ========================================================================

-- Thread A: Lobby Join Spammer & Dungeon Host Watcher
task.spawn(function()
    while _G.ALTSHIT_WITCHYOYSTER_RUNNING do
        if not AutomationEnabled then
            task.wait(1.0)
        elseif isMainLobby() then
            -- Reset dungeon states
            isReturningToLobby = false
            hostSeenInDungeon = false
            dungeonEntryTime = 0

            -- Continuous spam request to host
            pcall(function()
                if sendJoinRequestRemote then
                    sendJoinRequestRemote:InvokeServer(TARGET_HOST)
                end
                if joinDungeonRemote then
                    joinDungeonRemote:InvokeServer(TARGET_HOST)
                end
            end)

            -- Auto-ready up if placed in party
            local pG = LocalPlayer:FindFirstChild("PlayerGui")
            local qG = pG and pG:FindFirstChild("queueGui")
            if qG and readyUpRemote then
                pcall(function() readyUpRemote:FireServer() end)
            end

            task.wait(0.35)
        else
            -- Inside Dungeon Mode
            if dungeonEntryTime == 0 then
                dungeonEntryTime = os.clock()
                print(string.format("[AltShit] ⚔️ Entered dungeon! Target Host: %s", TARGET_HOST))
            end

            local hostPlr = getHostPlayer()
            if hostPlr then
                hostSeenInDungeon = true
            end

            -- Watchdog: Check if host left dungeon
            local elapsed = os.clock() - dungeonEntryTime
            if hostSeenInDungeon and not hostPlr and not isReturningToLobby then
                print(string.format("[AltShit] 🚪 Host '%s' was seen but is now gone! Initiating return to lobby...", TARGET_HOST))
                returnToLobby()
            elseif elapsed > 20 and not hostSeenInDungeon and not isReturningToLobby then
                print(string.format("[AltShit] ⚠️ Host '%s' not found after 20s grace period! Returning to lobby...", TARGET_HOST))
                returnToLobby()
            end

            task.wait(1.0)
        end
    end
end)

-- Thread B: Dungeon Anti-Bot Random Wandering & Spell Casting
task.spawn(function()
    local lastCombatAction = 0

    while _G.ALTSHIT_WITCHYOYSTER_RUNNING do
        if isDungeon() and not isReturningToLobby and AutomationEnabled then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")

            if hum and hrp and hum.Health > 0 then
                local hostPlr = getHostPlayer()
                local hostChar = hostPlr and hostPlr.Character
                local hostHrp = hostChar and hostChar:FindFirstChild("HumanoidRootPart")

                local anchorPos = hrp.Position
                local minR, maxR = 8, 20

                if hostHrp then
                    local distToHost = (hrp.Position - hostHrp.Position).Magnitude
                    if distToHost > 60 then
                        -- Catch up towards host if too far
                        anchorPos = hostHrp.Position
                        minR, maxR = 10, 25
                    elseif distToHost < 8 then
                        -- Maintain natural spacing
                        anchorPos = hrp.Position
                        minR, maxR = 12, 22
                    else
                        anchorPos = hostHrp.Position
                        minR, maxR = 10, 25
                    end
                end

                local targetPos = getRandomMoveTarget(anchorPos, minR, maxR)
                hum:MoveTo(targetPos)
                totalMoves = totalMoves + 1

                -- 25% chance of occasional human-like jump
                if math.random(1, 4) == 1 then
                    task.delay(math.random(3, 8) / 10, function()
                        if hum and hum.Health > 0 then
                            hum.Jump = true
                        end
                    end)
                end

                -- Move duration with active combat casting
                local moveDuration = math.random(18, 35) / 10
                local t0 = os.clock()
                while (os.clock() - t0) < moveDuration and hum.Health > 0 and isDungeon() and not isReturningToLobby do
                    task.wait(0.15)
                    if os.clock() - lastCombatAction > math.random(25, 45) / 10 then
                        lastCombatAction = os.clock()
                        performRandomCombatAction()
                    end
                end

                -- Brief natural pause/idle
                task.wait(math.random(4, 10) / 10)
            else
                task.wait(1.0)
            end
        else
            task.wait(1.0)
        end
    end
end)

-- ========================================================================
--  [8] GRAPHICAL USER INTERFACE
-- ========================================================================
local parent = getGuiParent()
local existingGui = parent:FindFirstChild("AltShitWitchyOysterGui")
if existingGui then existingGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AltShitWitchyOysterGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parent

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 310, 0, 250)
MainFrame.Position = UDim2.new(1, -330, 0, 120)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(115, 75, 175)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 34)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = 10
TitleBar.Active = true
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, -70, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚡ ALTSHIT: WITCHYOYSTER"
TitleLabel.TextColor3 = Color3.fromRGB(230, 215, 255)
TitleLabel.TextSize = 12
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 11
TitleLabel.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Name = "MinBtn"
MinBtn.Size = UDim2.new(0, 24, 0, 22)
MinBtn.Position = UDim2.new(1, -54, 0, 6)
MinBtn.BackgroundColor3 = Color3.fromRGB(45, 38, 62)
MinBtn.BorderSizePixel = 0
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(200, 190, 230)
MinBtn.TextSize = 12
MinBtn.Font = Enum.Font.GothamBold
MinBtn.ZIndex = 20
MinBtn.Active = true
MinBtn.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 5)
MinCorner.Parent = MinBtn

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 24, 0, 22)
CloseBtn.Position = UDim2.new(1, -26, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(75, 25, 35)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 120, 130)
CloseBtn.TextSize = 11
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.ZIndex = 20
CloseBtn.Active = true
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseBtn

-- Draggable handler (TitleBar only)
local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local relX = input.Position.X - TitleBar.AbsolutePosition.X
        if relX > TitleBar.AbsoluteSize.X - 60 then return end
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

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging and startPos and dragStart then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Content Area
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -16, 1, -42)
Content.Position = UDim2.new(0, 8, 0, 38)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

-- [1] Host Config Card
local HostCard = Instance.new("Frame")
HostCard.Size = UDim2.new(1, 0, 0, 50)
HostCard.BackgroundColor3 = Color3.fromRGB(27, 24, 38)
HostCard.BorderSizePixel = 0
HostCard.Parent = Content

local HostCorner = Instance.new("UICorner")
HostCorner.CornerRadius = UDim.new(0, 6)
HostCorner.Parent = HostCard

local HostHeader = Instance.new("TextLabel")
HostHeader.Size = UDim2.new(1, -12, 0, 14)
HostHeader.Position = UDim2.new(0, 8, 0, 4)
HostHeader.BackgroundTransparency = 1
HostHeader.Text = "TARGET HOST:"
HostHeader.TextColor3 = Color3.fromRGB(160, 145, 190)
HostHeader.TextSize = 10
HostHeader.Font = Enum.Font.GothamBold
HostHeader.TextXAlignment = Enum.TextXAlignment.Left
HostHeader.Parent = HostCard

local HostBox = Instance.new("TextBox")
HostBox.Size = UDim2.new(1, -16, 0, 24)
HostBox.Position = UDim2.new(0, 8, 0, 20)
HostBox.BackgroundColor3 = Color3.fromRGB(36, 32, 50)
HostBox.BorderSizePixel = 0
HostBox.Text = TARGET_HOST
HostBox.TextColor3 = Color3.fromRGB(255, 230, 160)
HostBox.TextSize = 11
HostBox.Font = Enum.Font.GothamBold
HostBox.ClearTextOnFocus = false
HostBox.Parent = HostCard

local HostBoxCorner = Instance.new("UICorner")
HostBoxCorner.CornerRadius = UDim.new(0, 4)
HostBoxCorner.Parent = HostBox

HostBox.FocusLost:Connect(function()
    local text = HostBox.Text:match("^%s*(.-)%s*$")
    if text and #text > 0 then
        TARGET_HOST = text
        print("[AltShit] 🎯 Target host updated to: " .. TARGET_HOST)
    end
end)

-- [2] Live Status Card
local StatusCard = Instance.new("Frame")
StatusCard.Size = UDim2.new(1, 0, 0, 84)
StatusCard.Position = UDim2.new(0, 0, 0, 56)
StatusCard.BackgroundColor3 = Color3.fromRGB(27, 24, 38)
StatusCard.BorderSizePixel = 0
StatusCard.Parent = Content

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusCard

local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size = UDim2.new(1, -16, 0, 24)
StatusLbl.Position = UDim2.new(0, 8, 0, 6)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "Status: Initializing..."
StatusLbl.TextColor3 = Color3.fromRGB(220, 210, 245)
StatusLbl.TextSize = 11
StatusLbl.Font = Enum.Font.GothamBold
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.TextWrapped = true
StatusLbl.Parent = StatusCard

local HostStatusLbl = Instance.new("TextLabel")
HostStatusLbl.Size = UDim2.new(1, -16, 0, 20)
HostStatusLbl.Position = UDim2.new(0, 8, 0, 32)
HostStatusLbl.BackgroundTransparency = 1
HostStatusLbl.Text = "Host: Searching..."
HostStatusLbl.TextColor3 = Color3.fromRGB(180, 170, 210)
HostStatusLbl.TextSize = 10
HostStatusLbl.Font = Enum.Font.GothamMedium
HostStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
HostStatusLbl.Parent = StatusCard

local MetricsLbl = Instance.new("TextLabel")
MetricsLbl.Size = UDim2.new(1, -16, 0, 20)
MetricsLbl.Position = UDim2.new(0, 8, 0, 56)
MetricsLbl.BackgroundTransparency = 1
MetricsLbl.Text = "Anti-Bot: Moves: 0 | Casts: 0"
MetricsLbl.TextColor3 = Color3.fromRGB(150, 230, 180)
MetricsLbl.TextSize = 10
MetricsLbl.Font = Enum.Font.GothamMedium
MetricsLbl.TextXAlignment = Enum.TextXAlignment.Left
MetricsLbl.Parent = StatusCard

-- [3] Action Controls
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0.58, -4, 0, 30)
ToggleBtn.Position = UDim2.new(0, 0, 0, 146)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 80)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "⚡ ACTIVE"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 11
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = Content

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleBtn

local ForceLobbyBtn = Instance.new("TextButton")
ForceLobbyBtn.Size = UDim2.new(0.42, 0, 0, 30)
ForceLobbyBtn.Position = UDim2.new(0.58, 0, 0, 146)
ForceLobbyBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 50)
ForceLobbyBtn.BorderSizePixel = 0
ForceLobbyBtn.Text = "🚪 To Lobby"
ForceLobbyBtn.TextColor3 = Color3.fromRGB(255, 180, 190)
ForceLobbyBtn.TextSize = 10
ForceLobbyBtn.Font = Enum.Font.GothamBold
ForceLobbyBtn.Parent = Content

local ForceCorner = Instance.new("UICorner")
ForceCorner.CornerRadius = UDim.new(0, 6)
ForceCorner.Parent = ForceLobbyBtn

-- Helper: Event debouncer
local function bindClick(btn, callback)
    btn.Active = true
    local lastClick = 0
    local function debounced(...)
        local now = os.clock()
        if now - lastClick < 0.25 then return end
        lastClick = now
        callback(...)
    end
    btn.MouseButton1Click:Connect(debounced)
    pcall(function()
        if btn.Activated then btn.Activated:Connect(debounced) end
    end)
end

bindClick(ToggleBtn, function()
    AutomationEnabled = not AutomationEnabled
    ToggleBtn.BackgroundColor3 = AutomationEnabled and Color3.fromRGB(40, 130, 80) or Color3.fromRGB(70, 70, 85)
    ToggleBtn.Text = AutomationEnabled and "⚡ ACTIVE" or "⏸️ PAUSED"
end)

bindClick(ForceLobbyBtn, function()
    returnToLobby()
end)

-- Minimize & Floating Badge
local isMin = false
bindClick(MinBtn, function()
    isMin = not isMin
    if isMin then
        MainFrame.Size = UDim2.new(0, 310, 0, 34)
        Content.Visible = false
        MinBtn.Text = "+"
        MinBtn.TextColor3 = Color3.fromRGB(150, 255, 170)
    else
        MainFrame.Size = UDim2.new(0, 310, 0, 250)
        Content.Visible = true
        MinBtn.Text = "—"
        MinBtn.TextColor3 = Color3.fromRGB(200, 190, 230)
    end
end)

local FloatingBadge = Instance.new("TextButton")
FloatingBadge.Name = "FloatingBadge"
FloatingBadge.Size = UDim2.new(0, 36, 0, 36)
FloatingBadge.Position = UDim2.new(1, -48, 0, 120)
FloatingBadge.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
FloatingBadge.BorderSizePixel = 0
FloatingBadge.Text = "⚡"
FloatingBadge.TextSize = 18
FloatingBadge.Visible = false
FloatingBadge.Active = true
FloatingBadge.ZIndex = 100
FloatingBadge.Parent = ScreenGui

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(1, 0)
BadgeCorner.Parent = FloatingBadge

local BadgeStroke = Instance.new("UIStroke")
BadgeStroke.Color = Color3.fromRGB(130, 90, 200)
BadgeStroke.Thickness = 1.5
BadgeStroke.Parent = FloatingBadge

bindClick(CloseBtn, function()
    MainFrame.Visible = false
    FloatingBadge.Visible = true
end)

bindClick(FloatingBadge, function()
    MainFrame.Visible = true
    FloatingBadge.Visible = false
end)

-- GUI Live Monitor Loop
task.spawn(function()
    while _G.ALTSHIT_WITCHYOYSTER_RUNNING and ScreenGui and ScreenGui.Parent do
        local hostPlr = getHostPlayer()
        if hostPlr then
            HostStatusLbl.Text = string.format("Host: %s (Online ✅)", hostPlr.Name)
            HostStatusLbl.TextColor3 = Color3.fromRGB(140, 255, 170)
        else
            HostStatusLbl.Text = string.format("Host: %s (Not in Server ❌)", TARGET_HOST)
            HostStatusLbl.TextColor3 = Color3.fromRGB(255, 140, 140)
        end

        MetricsLbl.Text = string.format("Anti-Bot: Moves: %d | Casts: %d", totalMoves, totalCasts)

        if not AutomationEnabled then
            StatusLbl.Text = "Status: ⏸️ Automation Paused"
            StatusLbl.TextColor3 = Color3.fromRGB(240, 200, 100)
        elseif isReturningToLobby then
            StatusLbl.Text = "Status: 🚪 Host Left! Returning to Lobby..."
            StatusLbl.TextColor3 = Color3.fromRGB(255, 120, 130)
        elseif isMainLobby() then
            StatusLbl.Text = "Status: 🏰 Lobby: Auto-Spamming Join..."
            StatusLbl.TextColor3 = Color3.fromRGB(100, 210, 255)
        else
            StatusLbl.Text = "Status: ⚔️ Dungeon: Anti-Bot Active"
            StatusLbl.TextColor3 = Color3.fromRGB(160, 245, 180)
        end

        task.wait(0.5)
    end
end)

print(string.format("[ALTSHIT WITCHYOYSTER v1.0] Running on %s. Target Host: %s. Lobby join & Anti-bot active!", 
    LocalPlayer.Name, TARGET_HOST))
