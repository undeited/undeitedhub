local WindUI = undeitedhub.WindUI
local AutofarmTab = undeitedhub.Window:Tab({ Title = "Autofarm" })

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function SafeNotify(data)
    if type(data) ~= "table" then return end
    if WindUI and type(WindUI.Notify) == "function" then
        pcall(WindUI.Notify, WindUI, data)
    else
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = data.Title or "",
                Text = data.Content or "",
                Duration = data.Duration or 3,
            })
        end)
    end
end

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
                            SafeNotify({
                                Title = "Anti Teleport",
                                Content = "Teleport detected - restored position",
                                Duration = 1.5,
                            })
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
        SafeNotify({
            Title = "Anti Teleport",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if antiTeleportEnabled then
    startAntiTeleport()
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if antiTeleportEnabled then
        stopAntiTeleport()
    end
    antiTeleportEnabled = false
    undeitedhub.Toggles.antiTeleport = false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    oldDisable()
end