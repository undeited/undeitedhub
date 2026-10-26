local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local WindUI = undeitedhub.WindUI

local FarmTab = undeitedhub.Window:Tab({ Title = "Auto Farm" })

local function getPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        for _, part in ipairs(obj:GetDescendants()) do
            if part:IsA("BasePart") then return part.Position end
        end
    end
    return nil
end

local function createOrbitToggle(targetName, targetPath, defaultRadius, defaultSpeed)
    local orbitEnabled = undeitedhub.Toggles["orbit_" .. targetName] or false
    local orbitHeartbeatConn = nil
    local isOrbiting = false
    local orbitAngle = 0
    local orbitRadius = defaultRadius or 8
    local orbitSpeed = defaultSpeed or 2.0
    local originalWalkSpeed = 16
    local originalJumpPower = 50

    local function getTargetPosition()
        return targetPath()
    end

    local function orbitPlayer(deltaTime)
        if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end
        local character = LocalPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart then return end

        local centerPos = getTargetPosition()
        if not centerPos then return end

        orbitAngle = orbitAngle + orbitSpeed * deltaTime
        local offsetX = math.cos(orbitAngle) * orbitRadius
        local offsetZ = math.sin(orbitAngle) * orbitRadius
        local newPos = centerPos + Vector3.new(offsetX, 0, offsetZ)

        rootPart.CFrame = CFrame.new(newPos, centerPos)

        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end

    local function startOrbit()
        if isOrbiting then return end
        isOrbiting = true
        orbitEnabled = true
        undeitedhub.Toggles["orbit_" .. targetName] = true

        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                originalWalkSpeed = humanoid.WalkSpeed
                originalJumpPower = humanoid.JumpPower
            end
        end

        orbitAngle = 0
        orbitHeartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
            if isOrbiting then
                pcall(orbitPlayer, deltaTime)
            end
        end)

        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        pcall(WindUI.Notify, WindUI, { Title = "Orbit around " .. targetName, Content = "Enabled", Duration = 2 })
    end

    local function stopOrbit()
        isOrbiting = false
        orbitEnabled = false
        undeitedhub.Toggles["orbit_" .. targetName] = false

        if orbitHeartbeatConn then
            orbitHeartbeatConn:Disconnect()
            orbitHeartbeatConn = nil
        end

        local anyOrbitActive = false
        for key, val in pairs(undeitedhub.Toggles) do
            if string.find(key, "orbit_") and val then
                anyOrbitActive = true
                break
            end
        end
        if not anyOrbitActive then
            local character = LocalPlayer.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = originalWalkSpeed
                    humanoid.JumpPower = originalJumpPower
                end
            end
        end

        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        pcall(WindUI.Notify, WindUI, { Title = "Orbit around " .. targetName, Content = "Disabled", Duration = 2 })
    end

    pcall(function()
        FarmTab:Toggle({
            Title = "Orbit around " .. targetName,
            Value = orbitEnabled,
            Callback = function(state)
                if state then startOrbit() else stopOrbit() end
            end
        })
    end)

    return stopOrbit
end

local function getDemonKingPosition()
    local npc = Workspace:FindFirstChild("NPC")
    if not npc then return nil end
    local demonKing = npc:FindFirstChild("DemonKing")
    if not demonKing then return nil end
    local demonKingModel = demonKing:FindFirstChild("DemonKing")
    if demonKingModel then
        local pos = getPosition(demonKingModel)
        if pos then return pos end
    end
    return getPosition(demonKing)
end

local function getBorockPosition()
    local npc = Workspace:FindFirstChild("NPC")
    if not npc then return nil end
    local boss = npc:FindFirstChild("Boss")
    if not boss then return nil end
    local borock = boss:FindFirstChild("Borock")
    if borock then
        return getPosition(borock)
    end
    return nil
end

local stopOrbitDemonKing = createOrbitToggle("Demon King", getDemonKingPosition, 8, 2.0)
local stopOrbitBorock = createOrbitToggle("Borock", getBorockPosition, 8, 2.0)

undeitedhub.DisableAll = undeitedhub.DisableAll or function() end
local oldDisable = undeitedhub.DisableAll
undeitedhub.DisableAll = function()
    stopOrbitDemonKing()
    stopOrbitBorock()
    oldDisable()
end
