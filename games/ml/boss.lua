local WindUI = undeitedhub.WindUI
local BossTab = undeitedhub.Window:Tab({ Title = "Boss" })

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local INTERACT_KEY = Enum.KeyCode.E
local holdingE = false

local function getPunchTool(player)
    local char = player.Character
    if char then
        local punch = char:FindFirstChild("Punch")
        if punch then return punch end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        return backpack:FindFirstChild("Punch")
    end
    return nil
end

local function equipPunch(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    local punch = char:FindFirstChild("Punch")
    if punch then return true end

    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end
    punch = backpack:FindFirstChild("Punch")
    if punch then
        pcall(function()
            hum:EquipTool(punch)
        end)
        task.wait(0.02)
        return true
    end
    return false
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local BOSS_COUNT = 6

local function getBossArena()
    local events = workspace:FindFirstChild("Events")
    if not events then return nil end
    return events:FindFirstChild("BossArena")
end

local function getBossAnchor(bossFolder)
    if not bossFolder or not bossFolder.Parent then return nil end

    local hitbox = bossFolder:FindFirstChild("BossDamageHitbox", true)
    if hitbox and hitbox:IsA("BasePart") then return hitbox end

    local boss = bossFolder:FindFirstChild("Boss")
    if not boss then return nil end

    local pelvis = boss:FindFirstChild("pelvis", true)
    if pelvis and pelvis:IsA("BasePart") then return pelvis end

    local hrp = boss:FindFirstChild("HumanoidRootPart", true)
    if hrp and hrp:IsA("BasePart") then return hrp end

    if boss.PrimaryPart then return boss.PrimaryPart end

    for _, part in ipairs(boss:GetDescendants()) do
        if part:IsA("BasePart") then return part end
    end
    return nil
end

local function getBossCenter(boss)
    if not boss then return nil end
    local sum = Vector3.zero
    local count = 0
    for _, d in ipairs(boss:GetDescendants()) do
        if d:IsA("BasePart") then
            sum = sum + d.Position
            count = count + 1
        end
    end
    if count == 0 then return nil end
    return sum / count
end

local function isBossAlive(bossFolder)
    if not bossFolder or not bossFolder.Parent then return false end
    local boss = bossFolder:FindFirstChild("Boss")
    if not boss then return false end

    local stats = bossFolder:FindFirstChild("stats")
    if stats then
        local health = stats:FindFirstChild("Health")
        if health and (health:IsA("NumberValue") or health:IsA("IntValue")) then
            return health.Value > 0
        end
    end

    local hum = boss:FindFirstChildOfClass("Humanoid")
    if hum then
        return hum.Health > 0
    end

    return true
end

local function getActiveBoss()
    local arena = getBossArena()
    if not arena then return nil end

    for i = 1, BOSS_COUNT do
        local bossFolder = arena:FindFirstChild("Boss" .. i)
        if bossFolder and isBossAlive(bossFolder) then
            local boss = bossFolder:FindFirstChild("Boss")
            if boss then
                return boss, bossFolder, i
            end
        end
    end
    return nil
end

local function getBossChest()
    local chest = workspace:FindFirstChild("BossChest")
    if chest then return chest end
    local events = workspace:FindFirstChild("Events")
    if events then
        local arena = events:FindFirstChild("BossArena")
        if arena then
            return arena:FindFirstChild("BossChest")
        end
    end
    return nil
end

local function findProximityPrompt(instance)
    if not instance then return nil end
    local direct = instance:FindFirstChildOfClass("ProximityPrompt")
    if direct then return direct end
    for _, d in ipairs(instance:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end
    return nil
end

local function findClickDetector(instance)
    if not instance then return nil end
    local direct = instance:FindFirstChildOfClass("ClickDetector")
    if direct then return direct end
    for _, d in ipairs(instance:GetDescendants()) do
        if d:IsA("ClickDetector") then return d end
    end
    return nil
end

local autoBossEnabled = undeitedhub.Toggles.autoBoss or false
local bossConnection = nil
local currentBoss = nil
local currentChest = nil
local chestClaimed = false
local lastPunchTime = 0
local activePrompt = nil
local promptStartedAt = 0
local lastClickTime = 0

local ORBIT_RADIUS = 3
local ORBIT_SPEED = 3
local PUNCH_COOLDOWN = 0.2
local CHEST_RANGE = 6
local CHEST_PROMPT_TIMEOUT = 1.5
local CLICK_COOLDOWN = 0.5

local orbitAngle = 0
local lastHeartbeat = 0
local savedCanCollide = nil

local function releaseE()
    if activePrompt then
        pcall(function()
            activePrompt:InputHoldEnd()
        end)
        activePrompt = nil
    end
    if holdingE then
        holdingE = false
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, INTERACT_KEY, false, game)
        end)
    end
end

local function holdE(prompt)
    if prompt then
        if activePrompt ~= prompt then
            releaseE()
            activePrompt = prompt
            promptStartedAt = tick()
            pcall(function()
                prompt:InputHoldBegin()
            end)
        end
    else
        if not holdingE then
            holdingE = true
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, INTERACT_KEY, false, game)
            end)
        end
    end
end

local function disablePlayerCollision()
    local hrp = getHRP()
    if not hrp then return end
    if savedCanCollide == nil then
        savedCanCollide = hrp.CanCollide
    end
    pcall(function()
        hrp.CanCollide = false
    end)
end

local function restorePlayerCollision()
    if savedCanCollide == nil then return end
    local hrp = getHRP()
    if hrp then
        pcall(function()
            hrp.CanCollide = savedCanCollide
        end)
    end
    savedCanCollide = nil
end

local function orbitBoss(anchor, boss)
    local hrp = getHRP()
    if not hrp or not anchor then return end

    local center = getBossCenter(boss) or anchor.Position

    local now = tick()
    local dt = now - lastHeartbeat
    lastHeartbeat = now
    if dt <= 0 or dt > 0.5 then
        dt = 1 / 60
    end

    orbitAngle = orbitAngle + ORBIT_SPEED * dt

    local orbitPos = Vector3.new(
        center.X + math.cos(orbitAngle) * ORBIT_RADIUS,
        anchor.Position.Y,
        center.Z + math.sin(orbitAngle) * ORBIT_RADIUS
    )

    pcall(function()
        hrp.CFrame = CFrame.new(orbitPos, Vector3.new(center.X, anchor.Position.Y, center.Z))
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function handleChest(chest)
    if not chest then return false end

    local hrp = getHRP()
    local chestPart = chest:FindFirstChild("Root")
        or chest:FindFirstChild("ChestCenterHandle")
        or chest:FindFirstChild("ChestOpenHandle")
    if not hrp or not chestPart then return true end

    local chestPos = chestPart.Position
    local distance = (hrp.Position - chestPos).Magnitude
    if distance > CHEST_RANGE then
        pcall(function()
            hrp.CFrame = CFrame.new(chestPos, chestPos + Vector3.new(0, 0, 1))
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    local prompt = findProximityPrompt(chest)
    if prompt then
        if activePrompt ~= prompt then
            releaseE()
            activePrompt = prompt
            promptStartedAt = tick()
            pcall(function()
                prompt:InputHoldBegin()
            end)
        end
        if tick() - promptStartedAt > CHEST_PROMPT_TIMEOUT then
            releaseE()
        end
        return true
    end

    local detector = findClickDetector(chest)
    if detector then
        local now = tick()
        if now - lastClickTime >= CLICK_COOLDOWN then
            lastClickTime = now
            pcall(function()
                if typeof(fireclickdetector) == "function" then
                    fireclickdetector(detector)
                elseif typeof(getconnections) == "function" then
                    for _, c in ipairs(getconnections(detector.MouseClick)) do
                        pcall(c.Fire, c)
                    end
                end
            end)
        end
        return true
    end

    holdE(nil)
    return true
end

local function onBossHeartbeat()
    if not autoBossEnabled then return end
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

    local hum = getHumanoid()
    if not hum or hum.Health <= 0 then
        currentBoss = nil
        currentChest = nil
        chestClaimed = false
        restorePlayerCollision()
        releaseE()
        return
    end

    local chest = getBossChest()
    if chest then
        if currentChest ~= chest then
            currentChest = chest
            chestClaimed = false
            releaseE()
        end

        if not chestClaimed then
            local stillThere = handleChest(chest)
            if stillThere then
                return
            end
        end
    else
        currentChest = nil
        chestClaimed = false
        releaseE()
    end

    local boss, bossFolder, index = getActiveBoss()
    if not boss then
        currentBoss = nil
        restorePlayerCollision()
        return
    end

    local anchor = getBossAnchor(bossFolder)
    if not anchor or not anchor.Parent then
        currentBoss = nil
        return
    end

    if currentBoss ~= boss then
        currentBoss = boss
        orbitAngle = 0
        lastHeartbeat = tick()
    end

    disablePlayerCollision()
    orbitBoss(anchor, boss)

    local now = tick()
    if now - lastPunchTime >= PUNCH_COOLDOWN then
        lastPunchTime = now
        if equipPunch(LocalPlayer) then
            local punch = getPunchTool(LocalPlayer)
            if punch and punch.Parent == LocalPlayer.Character then
                pcall(function()
                    punch:Activate()
                end)
            end
        end
    end
end

local function startAutoBoss()
    if bossConnection then return end
    autoBossEnabled = true
    undeitedhub.Toggles.autoBoss = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    lastPunchTime = 0
    lastClickTime = 0
    orbitAngle = 0
    lastHeartbeat = tick()
    currentBoss = nil
    currentChest = nil
    chestClaimed = false
    savedCanCollide = nil

    bossConnection = RunService.Heartbeat:Connect(onBossHeartbeat)
end

local function stopAutoBoss()
    autoBossEnabled = false
    undeitedhub.Toggles.autoBoss = false
    if bossConnection then
        bossConnection:Disconnect()
        bossConnection = nil
    end
    currentBoss = nil
    currentChest = nil
    chestClaimed = false
    restorePlayerCollision()
    releaseE()
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

BossTab:Toggle({
    Title = "Auto Boss Farm",
    Value = autoBossEnabled,
    Callback = function(state)
        if state then
            startAutoBoss()
        else
            stopAutoBoss()
        end
    end
})

if autoBossEnabled then
    startAutoBoss()
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoBossEnabled then
        autoBossEnabled = false
        undeitedhub.Toggles.autoBoss = false
        if bossConnection then
            bossConnection:Disconnect()
            bossConnection = nil
        end
        currentBoss = nil
        currentChest = nil
        chestClaimed = false
        restorePlayerCollision()
        releaseE()
    end
    oldDisable()
end
