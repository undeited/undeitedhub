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
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end
    local punch = char:FindFirstChild("Punch")
    if punch then return true end
    punch = backpack:FindFirstChild("Punch")
    if punch then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.Name ~= "Punch" then
                tool.Parent = backpack
            end
        end
        punch.Parent = char
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

local function getBossRoot(boss)
    if not boss or not boss.Parent then return nil end
    if boss:IsA("BasePart") then return boss end

    local pelvis = boss:FindFirstChild("pelvis", true)
    if pelvis and pelvis:IsA("BasePart") then return pelvis end

    local hrp = boss:FindFirstChild("HumanoidRootPart", true)
    if hrp and hrp:IsA("BasePart") then return hrp end

    local hitbox = boss:FindFirstChild("BossDamageHitbox", true)
    if hitbox and hitbox:IsA("BasePart") then return hitbox end

    if boss.PrimaryPart then return boss.PrimaryPart end

    for _, part in ipairs(boss:GetDescendants()) do
        if part:IsA("BasePart") then return part end
    end
    return nil
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
local lastTeleportTime = 0
local activePrompt = nil
local promptStartedAt = 0
local lastClickTime = 0

local TELEPORT_DISTANCE = 20
local ATTACK_RANGE = 8
local CHEST_RANGE = 6
local PUNCH_COOLDOWN = 0.1
local TELEPORT_COOLDOWN = 3
local CHEST_PROMPT_TIMEOUT = 1.5
local CLICK_COOLDOWN = 0.5

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

local function teleportNearBoss(bossRoot)
    local hrp = getHRP()
    if not hrp or not bossRoot then return end

    local bossPos = bossRoot.Position
    local hrpPos = hrp.Position
    local direction = (hrpPos - bossPos)
    direction = Vector3.new(direction.X, 0, direction.Z)
    if direction.Magnitude < 0.01 then
        direction = Vector3.new(0, 0, 1)
    end
    direction = direction.Unit

    local landingPos = bossPos + direction * TELEPORT_DISTANCE
    pcall(function()
        hrp.CFrame = CFrame.new(landingPos, bossPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function walkTowardsBoss(bossRoot)
    local hum = getHumanoid()
    local hrp = getHRP()
    if not hum or not hrp or not bossRoot then return end

    local bossPos = bossRoot.Position
    local hrpPos = hrp.Position
    local flatBoss = Vector3.new(bossPos.X, hrpPos.Y, bossPos.Z)
    local distance = (flatBoss - hrpPos).Magnitude

    if distance <= ATTACK_RANGE then
        pcall(function()
            hrp.CFrame = CFrame.new(hrpPos, Vector3.new(bossPos.X, hrpPos.Y, bossPos.Z))
        end)
        return
    end

    local direction = (flatBoss - hrpPos).Unit
    local moveCFrame = CFrame.new(hrpPos, hrpPos + direction)

    pcall(function()
        hrp.CFrame = moveCFrame
        hrp.AssemblyLinearVelocity = Vector3.new(direction.X * 25, hrp.AssemblyLinearVelocity.Y, direction.Z * 25)
    end)

    pcall(function()
        hum:Move(direction, false)
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
        return
    end

    local bossRoot = getBossRoot(boss)
    if not bossRoot or not bossRoot.Parent then
        currentBoss = nil
        return
    end

    if currentBoss ~= boss then
        currentBoss = boss
        lastTeleportTime = 0
    end

    local hrp = getHRP()
    if not hrp then return end

    local distance = (hrp.Position - bossRoot.Position).Magnitude
    local now = tick()

    if distance > TELEPORT_DISTANCE * 2 and now - lastTeleportTime >= TELEPORT_COOLDOWN then
        lastTeleportTime = now
        teleportNearBoss(bossRoot)
    else
        walkTowardsBoss(bossRoot)
    end

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
    lastTeleportTime = 0
    lastClickTime = 0
    currentBoss = nil
    currentChest = nil
    chestClaimed = false

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
        releaseE()
    end
    oldDisable()
end
