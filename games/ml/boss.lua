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

local function clearMachineInUse()
    local m = LocalPlayer:FindFirstChild("machineInUse")
    if not m then return end
    pcall(function()
        if m:IsA("StringValue") then
            m.Value = ""
        elseif m:IsA("BoolValue") then
            m.Value = false
        elseif m:IsA("ObjectValue") then
            m.Value = nil
        elseif m:IsA("IntValue") or m:IsA("NumberValue") then
            m.Value = 0
        end
    end)
end

local function getBodyMovementScript(character)
    if not character then return nil end
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("LocalScript") and d.Name == "bodyMovementScript" then
            return d
        end
    end
    return nil
end

local function setBodyMovementEnabled(enabled)
    local char = LocalPlayer.Character
    local script = getBodyMovementScript(char)
    if script then
        pcall(function() script.Disabled = not enabled end)
    end
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

local function getChestHandle(chest)
    if not chest then return nil end
    local part = chest:FindFirstChild("Root")
        or chest:FindFirstChild("ChestCenterHandle")
        or chest:FindFirstChild("ChestOpenHandle")
    if part and part:IsA("BasePart") then
        return part
    end
    for _, d in ipairs(chest:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

local function isChestVisible(chest)
    local part = getChestHandle(chest)
    if not part or not part.Parent then return false end
    if part.Transparency >= 1 then return false end
    local ltm = part.LocalTransparencyModifier
    if ltm and ltm >= 1 then return false end
    for _, desc in ipairs(chest:GetChildren()) do
        if desc:IsA("Model") then
            for _, d in ipairs(desc:GetDescendants()) do
                if d:IsA("BasePart") then
                    local dT = d.Transparency
                    local dL = d.LocalTransparencyModifier or 0
                    if dT < 1 and dL < 1 then return true end
                end
            end
        end
    end
    return true
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

local ORBIT_RADIUS = 2.5
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

local function getBossAimPoint(anchor, boss)
    local anchorPos = anchor.Position

    local head = boss:FindFirstChild("head", true)
    if head and head:IsA("BasePart") then
        return anchorPos:Lerp(head.Position, 0.5)
    end

    local spineUpper = boss:FindFirstChild("spine_upper", true)
    if spineUpper and spineUpper:IsA("BasePart") then
        return anchorPos:Lerp(spineUpper.Position, 0.5)
    end

    return anchorPos
end

local function syncCameraToAim(orbitPos, aimPoint)
    local cam = workspace.CurrentCamera
    if not cam then return end
    pcall(function()
        cam.CFrame = CFrame.lookAt(orbitPos + Vector3.new(0, 1.5, 0), aimPoint)
    end)
end

local function orbitBoss(anchor, boss)
    local hrp = getHRP()
    if not hrp or not anchor then return end

    local anchorPos = anchor.Position
    local center = getBossCenter(boss) or anchorPos
    local aimPoint = getBossAimPoint(anchor, boss)

    local now = tick()
    local dt = now - lastHeartbeat
    lastHeartbeat = now
    if dt <= 0 or dt > 0.5 then
        dt = 1 / 60
    end

    orbitAngle = orbitAngle + ORBIT_SPEED * dt

    local orbitPos = Vector3.new(
        center.X + math.cos(orbitAngle) * ORBIT_RADIUS,
        anchorPos.Y,
        center.Z + math.sin(orbitAngle) * ORBIT_RADIUS
    )

    local flatDX = orbitPos.X - aimPoint.X
    local flatDZ = orbitPos.Z - aimPoint.Z
    local flatDist = math.sqrt(flatDX * flatDX + flatDZ * flatDZ)

    local aimCFrame
    if flatDist < 0.05 then
        aimCFrame = CFrame.new(orbitPos) * CFrame.Angles(0, orbitAngle + math.pi, 0)
    else
        aimCFrame = CFrame.lookAt(orbitPos, aimPoint)
    end

    pcall(function()
        hrp.CFrame = aimCFrame
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    syncCameraToAim(orbitPos, aimPoint)
end

local function performPunch(anchor, boss)
    local hrp = getHRP()
    if not hrp or not anchor then return end

    local anchorPos = anchor.Position
    local aimPoint = getBossAimPoint(anchor, boss)

    local punchPos = anchorPos + Vector3.new(0, 1.5, 0)

    pcall(function()
        hrp.CFrame = CFrame.lookAt(punchPos, aimPoint)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    syncCameraToAim(punchPos, aimPoint)

    if equipPunch(LocalPlayer) then
        local punch = getPunchTool(LocalPlayer)
        if punch and punch.Parent == LocalPlayer.Character then
            pcall(function()
                punch:Activate()
            end)
        end
    end
end

local function handleChest(chest)
    if not chest then return false end
    if not isChestVisible(chest) then return true end

    local hrp = getHRP()
    local chestPart = getChestHandle(chest)
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

    clearMachineInUse()

    local chest = getBossChest()
    if chest then
        if currentChest ~= chest then
            currentChest = chest
            chestClaimed = false
            releaseE()
        end

        if not chestClaimed and isChestVisible(chest) then
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
        performPunch(anchor, boss)
    end
end

local function startAutoBoss()
    if bossConnection then return end
    autoBossEnabled = true
    undeitedhub.Toggles.autoBoss = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    setBodyMovementEnabled(false)

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
    setBodyMovementEnabled(true)
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

local autoHalloweenEnabled = undeitedhub.Toggles.autoHalloweenBoss or false
local halloweenConnection = nil
local halloweenReaper = nil
local halloweenOrbitAngle = 0
local halloweenLastHeartbeat = 0
local halloweenLastPunch = 0
local halloweenSavedCanCollide = nil

local HALLOWEEN_ORBIT_SPEED = 3
local HALLOWEEN_PUNCH_COOLDOWN = 0.2
local HALLOWEEN_ORBIT_BUFFER = 4

local function parseDisplayNumber(str)
    if type(str) ~= "string" then return 0 end
    local num = str:match("([%d%.]+)")
    if not num then return 0 end
    local n = tonumber(num) or 0
    if str:find("K") then n = n * 1000
    elseif str:find("M") then n = n * 1000000
    elseif str:find("B") then n = n * 1000000000 end
    return n
end

local function getGrimReaper()
    return workspace:FindFirstChild("Grim Reaper")
end

local function isGrimReaperAlive(reaper)
    if not reaper or not reaper.Parent then return false end
    local billboard = reaper:FindFirstChild("halloweenBossHealth")
    if billboard and billboard:IsA("BillboardGui") then
        if not billboard.Enabled then return false end
        local bar = billboard:FindFirstChild("Bar")
        local healthLabel = bar and bar:FindFirstChild("Health")
        if healthLabel and healthLabel:IsA("TextLabel") then
            local text = healthLabel.Text or ""
            local curStr = text:match("([%d%.]+%a*)%s*/")
            if curStr then
                return parseDisplayNumber(curStr) > 0
            end
        end
    end
    return true
end

local function getGrimReaperAnchor(reaper)
    if not reaper then return nil end
    local hitbox = reaper:FindFirstChild("BossDamageHitbox")
    if hitbox and hitbox:IsA("BasePart") then return hitbox end
    local root = reaper:FindFirstChild("RootPart")
    if root and root:IsA("BasePart") then return root end
    if reaper.PrimaryPart then return reaper.PrimaryPart end
    for _, d in ipairs(reaper:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

local function getGrimReaperCenter(reaper)
    if not reaper then return nil end
    local root = reaper:FindFirstChild("RootPart")
    if root and root:IsA("BasePart") then return root.Position end
    local prim = reaper.PrimaryPart
    if prim then return prim.Position end
    return getBossCenter(reaper)
end

local function disableHalloweenCollision()
    local hrp = getHRP()
    if not hrp then return end
    if halloweenSavedCanCollide == nil then
        halloweenSavedCanCollide = hrp.CanCollide
    end
    pcall(function()
        hrp.CanCollide = false
    end)
end

local function restoreHalloweenCollision()
    if halloweenSavedCanCollide == nil then return end
    local hrp = getHRP()
    if hrp then
        pcall(function()
            hrp.CanCollide = halloweenSavedCanCollide
        end)
    end
    halloweenSavedCanCollide = nil
end

local function orbitHalloween(anchor, reaper)
    local hrp = getHRP()
    if not hrp or not anchor then return end

    local anchorPos = anchor.Position
    local center = getGrimReaperCenter(reaper) or anchorPos
    local aimPoint = anchorPos

    local now = tick()
    local dt = now - halloweenLastHeartbeat
    halloweenLastHeartbeat = now
    if dt <= 0 or dt > 0.5 then
        dt = 1 / 60
    end

    halloweenOrbitAngle = halloweenOrbitAngle + HALLOWEEN_ORBIT_SPEED * dt

    local radius = math.max(anchor.Size.Magnitude / 2 + HALLOWEEN_ORBIT_BUFFER, 8)
    local orbitPos = Vector3.new(
        center.X + math.cos(halloweenOrbitAngle) * radius,
        anchorPos.Y + 2,
        center.Z + math.sin(halloweenOrbitAngle) * radius
    )

    local aimCFrame = CFrame.lookAt(orbitPos, aimPoint)
    pcall(function()
        hrp.CFrame = aimCFrame
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    syncCameraToAim(orbitPos, aimPoint)
end

local function performHalloweenPunch(anchor, reaper)
    local hrp = getHRP()
    if not hrp or not anchor then return end

    local anchorPos = anchor.Position
    local aimPoint = anchorPos

    local dir = hrp.Position - anchorPos
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 0.1 then
        dir = Vector3.new(1, 0, 0)
    end
    dir = dir.Unit

    local punchPos = anchorPos + dir * 6 + Vector3.new(0, 2, 0)

    pcall(function()
        hrp.CFrame = CFrame.lookAt(punchPos, aimPoint)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    syncCameraToAim(punchPos, aimPoint)

    if equipPunch(LocalPlayer) then
        local punch = getPunchTool(LocalPlayer)
        if punch and punch.Parent == LocalPlayer.Character then
            pcall(function()
                punch:Activate()
            end)
        end
    end
end

local function onHalloweenHeartbeat()
    if not autoHalloweenEnabled then return end
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

    local hum = getHumanoid()
    if not hum or hum.Health <= 0 then
        halloweenReaper = nil
        restoreHalloweenCollision()
        return
    end

    clearMachineInUse()

    local reaper = getGrimReaper()
    if not reaper or not isGrimReaperAlive(reaper) then
        halloweenReaper = nil
        restoreHalloweenCollision()
        return
    end

    local anchor = getGrimReaperAnchor(reaper)
    if not anchor or not anchor.Parent then
        halloweenReaper = nil
        return
    end

    if halloweenReaper ~= reaper then
        halloweenReaper = reaper
        halloweenOrbitAngle = 0
        halloweenLastHeartbeat = tick()
    end

    disableHalloweenCollision()
    orbitHalloween(anchor, reaper)

    local now = tick()
    if now - halloweenLastPunch >= HALLOWEEN_PUNCH_COOLDOWN then
        halloweenLastPunch = now
        performHalloweenPunch(anchor, reaper)
    end
end

local function startAutoHalloween()
    if halloweenConnection then return end
    autoHalloweenEnabled = true
    undeitedhub.Toggles.autoHalloweenBoss = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    setBodyMovementEnabled(false)

    halloweenReaper = nil
    halloweenOrbitAngle = 0
    halloweenLastHeartbeat = tick()
    halloweenLastPunch = 0
    halloweenSavedCanCollide = nil

    halloweenConnection = RunService.Heartbeat:Connect(onHalloweenHeartbeat)
end

local function stopAutoHalloween()
    autoHalloweenEnabled = false
    undeitedhub.Toggles.autoHalloweenBoss = false
    if halloweenConnection then
        halloweenConnection:Disconnect()
        halloweenConnection = nil
    end
    halloweenReaper = nil
    restoreHalloweenCollision()
    setBodyMovementEnabled(true)
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

BossTab:Toggle({
    Title = "Auto Halloween Boss Farm",
    Value = autoHalloweenEnabled,
    Callback = function(state)
        if state then
            startAutoHalloween()
        else
            stopAutoHalloween()
        end
    end
})

if autoHalloweenEnabled then
    startAutoHalloween()
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
        setBodyMovementEnabled(true)
    end
    if autoHalloweenEnabled then
        autoHalloweenEnabled = false
        undeitedhub.Toggles.autoHalloweenBoss = false
        if halloweenConnection then
            halloweenConnection:Disconnect()
            halloweenConnection = nil
        end
        halloweenReaper = nil
        restoreHalloweenCollision()
        setBodyMovementEnabled(true)
    end
    oldDisable()
end
