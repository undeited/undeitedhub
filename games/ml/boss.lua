local WindUI = undeitedhub.WindUI
local BossTab = undeitedhub.Window:Tab({ Title = "Boss" })

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local INTERACT_KEY = Enum.KeyCode.E
local holdingE = false

local function releaseE()
    if holdingE then
        holdingE = false
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, INTERACT_KEY, false, game)
        end)
    end
end

local function holdE()
    if not holdingE then
        holdingE = true
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, INTERACT_KEY, false, game)
        end)
    end
end

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

local function resetVelocity(part)
    if not part then return end
    pcall(function()
        part.Velocity = Vector3.zero
        part.RotVelocity = Vector3.zero
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end)
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

local function getChestRuntime(chest)
    if not chest or not chest.Parent then return nil end
    return chest:FindFirstChild("bossRewardsRuntime")
end

local function isChestClaimed(chest)
    if not chest or not chest.Parent then return true end
    local runtime = getChestRuntime(chest)
    if not runtime then return true end
    if runtime:IsA("Script") or runtime:IsA("LocalScript") then
        if runtime.Disabled then return true end
    end
    return false
end

local autoBossEnabled = undeitedhub.Toggles.autoBoss or false
local bossConnection = nil

local currentBossRoot = nil
local currentBossIndex = nil
local lastBossPos = nil
local lastPunchTime = 0

local trackedChest = nil
local chestClaimed = false

local FOLLOW_OFFSET = Vector3.new(0, 0.5, 0)
local CHEST_OFFSET = Vector3.new(0, 3, 0)
local PUNCH_COOLDOWN = 0.1

local function onBossHeartbeat()
    if not autoBossEnabled then return end
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

    local hum = getHumanoid()
    if not hum or hum.Health <= 0 then
        releaseE()
        currentBossRoot = nil
        currentBossIndex = nil
        lastBossPos = nil
        trackedChest = nil
        chestClaimed = false
        return
    end

    local chest = getBossChest()

    if chest then
        if trackedChest ~= chest then
            trackedChest = chest
            chestClaimed = false
        end

        if not chestClaimed then
            if isChestClaimed(chest) then
                chestClaimed = true
                releaseE()
            else
                local chestPart = chest:FindFirstChild("Root")
                    or chest:FindFirstChild("ChestCenterHandle")
                    or chest:FindFirstChild("ChestOpenHandle")
                if chestPart then
                    local hrp = getHRP()
                    if hrp then
                        local chestPos = chestPart.Position
                        pcall(function()
                            hrp.CFrame = CFrame.new(chestPos + CHEST_OFFSET, chestPos)
                        end)
                        resetVelocity(hrp)
                    end
                    holdE()
                end
                return
            end
        end
    else
        trackedChest = nil
        chestClaimed = false
        releaseE()
    end

    local boss, _, index = getActiveBoss()
    if not boss then
        if currentBossIndex then
            currentBossRoot = nil
            currentBossIndex = nil
            lastBossPos = nil
        end
        return
    end

    local bossRoot = getBossRoot(boss)
    if not bossRoot or not bossRoot.Parent then
        currentBossRoot = nil
        lastBossPos = nil
        return
    end

    if currentBossRoot ~= bossRoot or currentBossIndex ~= index then
        currentBossRoot = bossRoot
        currentBossIndex = index
        lastBossPos = bossRoot.Position
    end

    local bossPos = bossRoot.Position
    lastBossPos = bossPos

    local hrp = getHRP()
    if hrp then
        pcall(function()
            hrp.CFrame = CFrame.new(bossPos + FOLLOW_OFFSET, bossPos)
        end)
        resetVelocity(hrp)
    end

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
    currentBossRoot = nil
    currentBossIndex = nil
    lastBossPos = nil
    trackedChest = nil
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
    currentBossRoot = nil
    currentBossIndex = nil
    lastBossPos = nil
    trackedChest = nil
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
        currentBossRoot = nil
        currentBossIndex = nil
        lastBossPos = nil
        trackedChest = nil
        chestClaimed = false
        releaseE()
    end
    oldDisable()
end
