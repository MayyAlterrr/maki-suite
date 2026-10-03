-- Version 3.1: reapply own-gear hiding on every respawn and late gear load.
-- Standalone CLIENT script. In Studio: use a LocalScript in StarterPlayerScripts.
-- Run once per session. Re-running replaces this script's previous instance.
-- No objects are deleted. Collisions, touch/query settings, scripts and remotes
-- are untouched. Visual attack warnings may disappear. Gains are not guaranteed.
-- Custom armor/spell models are recognized only by the names below.
local CONFIG = {
    KeepOwnGearHidden = true, -- Reapply recognized armor/accessory hiding after respawn.
    -- Aggressive visual cleanup. These may also hide scenery and body parts.
    HideNeonParts = true, -- Any Neon-material part, regardless of its name.
    HideNonCollidableParts = true, -- Includes many attack meshes and decorations.
    HideAllWorldParts = false, -- Optional: hide ALL parts, including map/characters.
    -- HideAllWorldParts leaves terrain and screen UI; use for background accounts.
    -- None of these settings stop physics, animations or attack scripts.
    DisableEffects = true,
    DisableShadows = true,
    DisableExtraLights = true,
    DisablePostEffects = true,
    HideAccessoriesAndTools = true,
    HideNamedVisuals = true,
    HideDecalsAndTextures = true, -- Includes painted floor attack warnings.
    RemoveMeshTextures = true, -- SurfaceAppearance maps are left intact.
    RemoveClothingTextures = true,
    DisableHighlights = true,
    SimplifyAtmosphere = true,
    SimplifyWater = true,
    HideOverheadUI = false, -- true hides BillboardGui names/health/damage text.
    HideAllCharacters = false, -- true hides players AND humanoid-based enemies.
    -- Edit settings here, then rerun. Hidden characters still exist and move.
    -- Exact names, ignoring spaces, underscores, hyphens and capitalization.
    -- Remove a name if it hides something you want to see.
    VisualNames = {
        armor = true, armour = true, helmet = true, chestplate = true,
        weapon = true, weapons = true, pauldrons = true, shoulderarmor = true,
        vfx = true, effects = true, spelleffects = true, attackeffects = true,
    },
    BatchSize = 120,
    WorkBudgetMs = 2, -- Approximate processing budget per batch; not a hard limit.
}
local RunService = game:GetService("RunService")
assert(RunService:IsClient(), "Run Visual Performance on the client.")
if not game:IsLoaded() then game.Loaded:Wait() end
local Lighting = game:GetService("Lighting")
local LocalPlayer = game:GetService("Players").LocalPlayer
local KEY = "StandaloneVisualPerformance"
local previous = _G[KEY]
if type(previous) == "table" and type(previous.Stop) == "function" then
    previous.Stop()
end
local running = true
local records = {}
local rootConnections = {}
local controller = {}
_G[KEY] = controller
-- Animated effects keep locks. Static textures get one-time changes instead
-- of a separate property listener per texture. All changed values are restorable.
local function force(object, property, value, keepLocked)
    -- Do not allocate a restore record/listener for an already-correct static value.
    if keepLocked == false and object[property] == value then return end
    local record = records[object]
    if not record then
        record = {original = {}, connections = {}}
        records[object] = record
        record.connections[#record.connections + 1] = object.Destroying:Connect(function()
            for _, connection in ipairs(record.connections) do connection:Disconnect() end
            records[object] = nil
        end)
    end
    if record.original[property] ~= nil then
        if object[property] ~= value then object[property] = value end
        return
    end
    record.original[property] = object[property]
    object[property] = value
    if keepLocked ~= false then
        record.connections[#record.connections + 1] = object:GetPropertyChangedSignal(property):Connect(function()
            if running and object[property] ~= value then object[property] = value end
        end)
    end
end
local function visualContainer(object)
    local current = object
    while current and current ~= workspace and current ~= game do
        if CONFIG.HideAccessoriesAndTools and
            (current:IsA("Accessory") or current:IsA("Tool")) then return true end
        if CONFIG.HideAllCharacters and current:IsA("Model")
            and current:FindFirstChildOfClass("Humanoid") then return true end
        if CONFIG.HideNamedVisuals then
            local name = current.Name:lower():gsub("[%s_%-]", "")
            if CONFIG.VisualNames[name] then return true end
        end
        current = current.Parent
    end
    return false
end
-- Only lock Transparency on this player's recognized gear, not all attack parts.
-- This stops camera LocalTransparencyModifier resets from revealing the armor.
local function ownGear(object)
    if not CONFIG.KeepOwnGearHidden then return false end
    local character = LocalPlayer.Character
    if not character then return false end
    local current, recognized = object, false
    while current and current ~= character do
        if CONFIG.HideAccessoriesAndTools and
            (current:IsA("Accessory") or current:IsA("Tool")) then recognized = true end
        if CONFIG.HideNamedVisuals then
            local name = current.Name:lower():gsub("[%s_%-]", "")
            if CONFIG.VisualNames[name] then recognized = true end
        end
        current = current.Parent
    end
    return current == character and recognized
end

local enqueue
local function process(object)
    if not running or not object.Parent then return end
    if CONFIG.DisableEffects and object:IsA("ParticleEmitter") then
        force(object, "Enabled", false)
        force(object, "Rate", 0)
        -- Lifetime also handles scripts that call Emit() despite Enabled=false.
        force(object, "Lifetime", NumberRange.new(0))
        object:Clear()
    elseif CONFIG.DisableEffects and object:IsA("Trail") then
        force(object, "Enabled", false)
        object:Clear()
    elseif CONFIG.DisableEffects and (object:IsA("Beam") or object:IsA("Smoke")
        or object:IsA("Fire") or object:IsA("Sparkles")) then
        force(object, "Enabled", false)
    elseif CONFIG.DisableEffects and object:IsA("Explosion") then
        force(object, "Visible", false)
    elseif CONFIG.DisableExtraLights and object:IsA("Light") then
        force(object, "Enabled", false)
    elseif CONFIG.DisablePostEffects and object:IsA("PostEffect") then
        force(object, "Enabled", false)
    elseif CONFIG.DisableHighlights and object:IsA("Highlight") then
        force(object, "Enabled", false)
    elseif CONFIG.HideOverheadUI and object:IsA("BillboardGui") then
        force(object, "Enabled", false)
    elseif CONFIG.SimplifyAtmosphere and object:IsA("Atmosphere") then
        force(object, "Density", 0, false)
        force(object, "Haze", 0, false)
        force(object, "Glare", 0, false)
    elseif object:IsA("BasePart") and not object:IsA("Terrain") then
        local hide = CONFIG.HideAllWorldParts
            or (CONFIG.HideNeonParts and object.Material == Enum.Material.Neon)
            or (CONFIG.HideNonCollidableParts and object.CanCollide == false)
            or visualContainer(object)
        if hide then
            -- Avoid a listener on every moving/tweened attack part. The local
            -- modifier also survives ordinary Transparency animations.
            force(object, "LocalTransparencyModifier", 1, false)
        end
        if ownGear(object) then force(object, "Transparency", 1) end
        if CONFIG.RemoveMeshTextures and object:IsA("MeshPart") then
            force(object, "TextureID", "", false)
        end
    elseif CONFIG.RemoveMeshTextures and object:IsA("SpecialMesh") then
        force(object, "TextureId", "", false)
    elseif object:IsA("Decal") or object:IsA("Texture") then
        if CONFIG.HideDecalsAndTextures or visualContainer(object) then
            force(object, "Transparency", 1, false)
        end
    elseif CONFIG.RemoveClothingTextures and object:IsA("Shirt") then
        force(object, "ShirtTemplate", "", false)
    elseif CONFIG.RemoveClothingTextures and object:IsA("Pants") then
        force(object, "PantsTemplate", "", false)
    elseif CONFIG.RemoveClothingTextures and object:IsA("ShirtGraphic") then
        force(object, "Graphic", "", false)
    elseif CONFIG.HideAllCharacters and object:IsA("Humanoid") then
        -- Some characters receive their Humanoid after their body parts.
        for _, child in ipairs(object.Parent:GetDescendants()) do
            if child:IsA("BasePart") or child:IsA("Decal") or child:IsA("Texture") then
                enqueue(child)
            end
        end
    end
end
local errors = 0
local function safelyProcess(object)
    local ok, message = pcall(process, object)
    if not ok then
        errors = errors + 1
        if errors <= 3 then warn("[Visual Performance] " .. tostring(message)) end
    end
end
-- Deduplicated queue: a burst of spells creates one worker, not a task per part.
-- No periodic full-world scan and no always-running RenderStepped connection.
local queue, pending = {}, {}
local head, tail = 1, 0
local workerActive = false
local processed = 0
local function drain()
    while running and head <= tail do
        local started, count = os.clock(), 0
        repeat
            local object = queue[head]
            queue[head] = nil
            head = head + 1
            pending[object] = nil
            safelyProcess(object)
            processed = processed + 1
            count = count + 1
        until head > tail or count >= CONFIG.BatchSize
            or (os.clock() - started) * 1000 >= CONFIG.WorkBudgetMs
        if head <= tail then task.wait() end
    end
    if head > tail then
        table.clear(queue)
        head, tail = 1, 0
    end
    workerActive = false
end
local visualClasses = {
    ParticleEmitter = true, Trail = true, Beam = true, Smoke = true,
    Fire = true, Sparkles = true, Explosion = true, Highlight = true,
    Atmosphere = true, SpecialMesh = true, Decal = true, Texture = true,
    Shirt = true, Pants = true, ShirtGraphic = true,
}
enqueue = function(object)
    if not running or pending[object] then return end
    -- Attachments, welds, scripts, values and generic containers need no cleanup.
    if not (visualClasses[object.ClassName] or object:IsA("BasePart")
        or object:IsA("Light") or object:IsA("PostEffect")
        or (CONFIG.HideOverheadUI and object:IsA("BillboardGui"))
        or (CONFIG.HideAllCharacters and object:IsA("Humanoid"))) then return end
    pending[object] = true
    tail = tail + 1
    queue[tail] = object
    if not workerActive then
        workerActive = true
        task.defer(drain)
    end
end
-- Watch only the current character. Short delayed passes handle gear whose
-- name/properties are set after parenting; there is no permanent polling loop.
local characterConnections = {}
local characterGeneration = 0
local watchedCharacter
local function disconnectCharacter()
    characterGeneration = characterGeneration + 1
    watchedCharacter = nil
    for _, connection in ipairs(characterConnections) do connection:Disconnect() end
    table.clear(characterConnections)
end
local function bindCharacter(character)
    if not running or watchedCharacter == character then return end
    disconnectCharacter()
    watchedCharacter = character
    local generation = characterGeneration
    local function active()
        return running and generation == characterGeneration
            and LocalPlayer.Character == character
    end
    local function scan()
        if not active() then return end
        for _, object in ipairs(character:GetDescendants()) do enqueue(object) end
    end
    local scanScheduled = false
    characterConnections[#characterConnections + 1] = character.DescendantAdded:Connect(function(object)
        if not active() then return end
        enqueue(object)
        if not scanScheduled then
            scanScheduled = true
            task.delay(0.25, function()
                scanScheduled = false
                scan()
            end)
        end
    end)
    scan()
    for _, delaySeconds in ipairs({0.25, 1, 3, 8}) do task.delay(delaySeconds, scan) end
end

function controller.Stop()
    if not running then return end
    running = false
    disconnectCharacter()
    for _, connection in ipairs(rootConnections) do connection:Disconnect() end
    for _, record in pairs(records) do
        for _, connection in ipairs(record.connections) do connection:Disconnect() end
    end
    for object, record in pairs(records) do
        for property, value in pairs(record.original) do
            pcall(function() object[property] = value end)
        end
    end
    table.clear(records)
    table.clear(queue)
    table.clear(pending)
    head, tail = 1, 0
    if _G[KEY] == controller then _G[KEY] = nil end
    print("[Visual Performance v3.1] Stopped; saved properties restored.")
end
function controller.Status()
    local tracked = 0
    for _ in pairs(records) do tracked = tracked + 1 end
    local status = {
        Running = running, Queued = math.max(0, tail - head + 1),
        Processed = processed, TrackedObjects = tracked, Errors = errors,
    }
    print("[Visual Performance v3.1] Queued:", status.Queued,
        "Processed:", processed, "Tracked:", tracked, "Errors:", errors)
    return status
end
-- Connect before the initial scan; respawns/streamed-in objects are included.
for _, root in ipairs({workspace, Lighting}) do
    rootConnections[#rootConnections + 1] = root.DescendantAdded:Connect(enqueue)
end
if CONFIG.KeepOwnGearHidden then
    rootConnections[#rootConnections + 1] = LocalPlayer.CharacterAdded:Connect(bindCharacter)
    rootConnections[#rootConnections + 1] = LocalPlayer.CharacterRemoving:Connect(function(character)
        if watchedCharacter == character then disconnectCharacter() end
    end)
    if LocalPlayer.Character then bindCharacter(LocalPlayer.Character) end
end
if CONFIG.DisableShadows then force(Lighting, "GlobalShadows", false) end
if CONFIG.SimplifyWater then
    force(workspace.Terrain, "WaterWaveSize", 0, false)
    force(workspace.Terrain, "WaterWaveSpeed", 0, false)
    force(workspace.Terrain, "WaterReflectance", 0, false)
end
for _, root in ipairs({workspace, Lighting}) do
    for index, object in ipairs(root:GetDescendants()) do
        if not running then return end
        enqueue(object)
        if index % 500 == 0 then task.wait() end
    end
end
print("[Visual Performance v3.1] Active; initial cleanup finishes in batches.")
