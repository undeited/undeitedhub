local WindUI = undeitedhub.WindUI
local AutofarmTab = undeitedhub.Window:Tab({ Title = "Autofarm" })

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getTool(player, toolName)
    local char = player.Character
    if char then
        local tool = char:FindFirstChild(toolName)
        if tool then return tool end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        return backpack:FindFirstChild(toolName)
    end
    return nil
end

local function equipTool(player, toolName)
    local char = player.Character
    if not char then return false end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end
    local tool = char:FindFirstChild(toolName)
    if tool then return true end
    tool = backpack:FindFirstChild(toolName)
    if tool then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and t.Name ~= toolName then
                t.Parent = backpack
            end
        end
        tool.Parent = char
        task.wait(0.02)
        return true
    end
    return false
end

local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function startAutoActivity(toggleName, toolName)
    local enabled = undeitedhub.Toggles[toggleName] or false
    local taskRef = nil
    local running = false

    local function activityLoop()
        local player = LocalPlayer
        while running do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE and isAlive(player) then
                local character = player.Character
                local backpack = player:FindFirstChild("Backpack")
                if backpack then
                    if not equipTool(player, toolName) then
                        task.wait(0.2)
                        continue
                    end
                    local tool = getTool(player, toolName)
                    if tool and tool.Parent == character then
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
            end
            task.wait(0.1)
        end
        taskRef = nil
    end

    local function start()
        if running then return end
        running = true
        enabled = true
        undeitedhub.Toggles[toggleName] = true
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        taskRef = task.spawn(activityLoop)
    end

    local function stop()
        running = false
        enabled = false
        undeitedhub.Toggles[toggleName] = false
        if taskRef then
            task.cancel(taskRef)
            taskRef = nil
        end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    end

    AutofarmTab:Toggle({
        Title = "Auto " .. toolName,
        Value = enabled,
        Callback = function(state)
            if state then start() else stop() end
        end
    })

    if enabled then start() end

    return { start = start, stop = stop }
end

local handstand = startAutoActivity("AutoHandstand", "Handstands")
local situps    = startAutoActivity("AutoSitups", "Situps")
local pushups   = startAutoActivity("AutoPushups", "Pushups")
local weight    = startAutoActivity("AutoWeight", "Weight")
local punch     = startAutoActivity("AutoPunch", "Punch")

local rebirthEnabled = undeitedhub.Toggles.AutoRebirth or false
local rebirthTask = nil

local function startRebirth()
    if rebirthTask then return end
    rebirthEnabled = true
    undeitedhub.Toggles.AutoRebirth = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    rebirthTask = task.spawn(function()
        while rebirthEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local remote = ReplicatedStorage:FindFirstChild("rEvents")
                    and ReplicatedStorage.rEvents:FindFirstChild("rebirthRemote")
                if remote then
                    pcall(function()
                        remote:InvokeServer("rebirthRequest")
                    end)
                end
            end
            task.wait(0.1)
        end
        rebirthTask = nil
    end)
end

local function stopRebirth()
    rebirthEnabled = false
    undeitedhub.Toggles.AutoRebirth = false
    if rebirthTask then
        task.cancel(rebirthTask)
        rebirthTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

AutofarmTab:Toggle({
    Title = "Auto Rebirth",
    Value = rebirthEnabled,
    Callback = function(state)
        if state then startRebirth() else stopRebirth() end
    end
})

if rebirthEnabled then startRebirth() end

local antiTeleportEnabled = undeitedhub.Toggles.antiTeleport or false
local antiTeleportTask = nil
local lastSafeCFrame = nil
local lastTeleportRestore = 0
local TELEPORT_DETECT_THRESHOLD = 40
local TELEPORT_RESTORE_COOLDOWN = 0.75
local TELEPORT_SAMPLE_INTERVAL = 0.1
local respawnGraceUntil = 0
local lastKnownHealth = 100

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function resetTracking(graceSeconds)
    lastSafeCFrame = nil
    if graceSeconds then
        respawnGraceUntil = tick() + graceSeconds
    end
end

local function startAntiTeleport()
    if antiTeleportTask then return end
    antiTeleportEnabled = true
    undeitedhub.Toggles.antiTeleport = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    resetTracking(2)
    lastKnownHealth = 100

    antiTeleportTask = task.spawn(function()
        while antiTeleportEnabled do
            pcall(function()
                if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end
                if tick() < respawnGraceUntil then return end

                local hum = getHumanoid()
                if not hum then
                    resetTracking(2)
                    return
                end

                local health = hum.Health
                if health <= 0 then
                    lastKnownHealth = 0
                    lastSafeCFrame = nil
                    return
                end

                if lastKnownHealth <= 0 and health > 0 then
                    lastKnownHealth = health
                    resetTracking(2)
                    return
                end
                lastKnownHealth = health

                local hrp = getHRP()
                if not hrp then return end

                if lastSafeCFrame then
                    local dist = (hrp.Position - lastSafeCFrame.Position).Magnitude
                    if dist > TELEPORT_DETECT_THRESHOLD then
                        local now = tick()
                        if now - lastTeleportRestore > TELEPORT_RESTORE_COOLDOWN then
                            lastTeleportRestore = now
                            hrp.CFrame = lastSafeCFrame
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            hrp.AssemblyAngularVelocity = Vector3.zero
                            hrp.Velocity = Vector3.zero
                            hrp.RotVelocity = Vector3.zero
                        end
                    else
                        lastSafeCFrame = hrp.CFrame
                    end
                else
                    lastSafeCFrame = hrp.CFrame
                end
            end)
            task.wait(TELEPORT_SAMPLE_INTERVAL)
        end
        antiTeleportTask = nil
    end)
end

local function stopAntiTeleport()
    antiTeleportEnabled = false
    undeitedhub.Toggles.antiTeleport = false
    if antiTeleportTask then
        task.cancel(antiTeleportTask)
        antiTeleportTask = nil
    end
    lastSafeCFrame = nil
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

AutofarmTab:Toggle({
    Title = "Anti Teleport",
    Value = antiTeleportEnabled,
    Callback = function(state)
        if state then
            startAntiTeleport()
        else
            stopAntiTeleport()
        end
    end
})

if antiTeleportEnabled then
    startAntiTeleport()
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if punch then punch.stop() end
    if handstand then handstand.stop() end
    if situps then situps.stop() end
    if pushups then pushups.stop() end
    if weight then weight.stop() end

    if rebirthEnabled then stopRebirth() end
    if antiTeleportEnabled then stopAntiTeleport() end

    undeitedhub.Toggles.AutoHandstand = false
    undeitedhub.Toggles.AutoSitups = false
    undeitedhub.Toggles.AutoPushups = false
    undeitedhub.Toggles.AutoWeight = false
    undeitedhub.Toggles.AutoPunch = false
    undeitedhub.Toggles.AutoRebirth = false
    undeitedhub.Toggles.antiTeleport = false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    oldDisable()
end
