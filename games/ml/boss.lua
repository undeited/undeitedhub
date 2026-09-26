local WindUI = undeitedhub.WindUI
local BossTab = undeitedhub.Window:Tab({ Title = "Boss" })

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

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

    local hrp = boss:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp end

    local hum = boss:FindFirstChildOfClass("Humanoid")
    if hum and hum.RootPart then return hum.RootPart end

    if boss.PrimaryPart then return boss.PrimaryPart end

    for _, part in ipairs(boss:GetDescendants()) do
        if part:IsA("BasePart") then return part end
    end
    return nil
end

local function isBossAlive(boss)
    if not boss or not boss.Parent then return false end
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
        if bossFolder then
            local boss = bossFolder:FindFirstChild("Boss")
            if isBossAlive(boss) then
                return boss, bossFolder, i
            end
        end
    end
    return nil
end

local autoBossEnabled = undeitedhub.Toggles.autoBoss or false
local bossConnection = nil
local currentBoss = nil
local lastPunchTime = 0

local TELEPORT_DISTANCE = 20
local ATTACK_RANGE = 8
local PUNCH_COOLDOWN = 0.1
local TELEPORT_COOLDOWN = 3

local lastTeleportTime = 0

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

local function onBossHeartbeat()
    if not autoBossEnabled then return end
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

    local hum = getHumanoid()
    if not hum or hum.Health <= 0 then
        currentBoss = nil
        return
    end

    local boss, _, index = getActiveBoss()
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
    currentBoss = nil

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
    end
    oldDisable()
end
