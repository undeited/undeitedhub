local WindUI = undeitedhub.WindUI
local AntiTab = undeitedhub.Window:Tab({ Title = "Antis" })

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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local antiKickEnabled = undeitedhub.Toggles.antiKick or false
local antiBurnEnabled = undeitedhub.Toggles.antiBurn or false
local antiExplosionEnabled = undeitedhub.Toggles.antiExplosion or false

local checkTask = nil
local burnConnections = {}
local explosionConnections = {}

local function getPlayerToysFolder()
    return Workspace:FindFirstChild(localPlayer.Name .. "SpawnedInToys")
end

local function getNinjaShuriken()
    local folder = getPlayerToysFolder()
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child.Name == "NinjaShuriken" and child:IsA("Model") then
                return child
            end
        end
    end
    return nil
end

local function getStickyPart(shuriken)
    if shuriken then
        for _, part in ipairs(shuriken:GetDescendants()) do
            if part.Name == "StickyPart" and part:IsA("BasePart") then
                return part
            end
        end
    end
    return nil
end

local function isShurikenAttached(shuriken)
    if not shuriken then return false end
    local sticky = getStickyPart(shuriken)
    if not sticky then return false end
    for _, weld in ipairs(sticky:GetChildren()) do
        if weld:IsA("Weld") or weld:IsA("WeldConstraint") then
            if weld.Part1 and weld.Part1:IsDescendantOf(localPlayer.Character) then
                return true
            end
        end
    end
    return false
end

local function spawnShuriken()
    local char = localPlayer.Character
    if not char then return false, "No character" end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false, "No root part" end

    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    if not menuToys then return false, "MenuToys not found" end
    local spawnRemote = menuToys:FindFirstChild("SpawnToyRemoteFunction")
    if not spawnRemote then return false, "SpawnToyRemoteFunction not found" end

    local pos = rootPart.Position - Vector3.new(0, 0.5, 0)
    local cframe = CFrame.new(pos)
    local args = {
        [1] = "NinjaShuriken",
        [2] = cframe,
        [3] = Vector3.new(0, 0, 0)
    }

    local success, result = pcall(function()
        return spawnRemote:InvokeServer(unpack(args))
    end)

    if success then
        return true, "Spawned (result: " .. tostring(result) .. ")"
    else
        return false, "Invoke error: " .. tostring(result)
    end
end

local function attachShuriken(shuriken)
    if not shuriken then return false, "No shuriken" end
    local sticky = getStickyPart(shuriken)
    if not sticky then return false, "No StickyPart" end
    local char = localPlayer.Character
    if not char then return false, "No character" end
    local attachPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChildWhichIsA("BasePart")
    if not attachPart then return false, "No attach part" end

    local playerEvents = ReplicatedStorage:FindFirstChild("PlayerEvents")
    if not playerEvents then return false, "PlayerEvents not found" end
    local stickyEvent = playerEvents:FindFirstChild("StickyPartEvent")
    if not stickyEvent then return false, "StickyPartEvent not found" end

    local relCFrame = CFrame.new(0, -0.5, 0)
    local args = {
        [1] = sticky,
        [2] = attachPart,
        [3] = relCFrame
    }
    pcall(function()
        stickyEvent:FireServer(unpack(args))
    end)
    return true, "Attach fired"
end

local function ensureShuriken()
    if not antiKickEnabled then return end
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end
    local char = localPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local shuriken = getNinjaShuriken()
    if not shuriken then
        local success, msg = spawnShuriken()
        if success then
            task.wait(0.5)
            shuriken = getNinjaShuriken()
            if shuriken then
                attachShuriken(shuriken)
            end
        end
    else
        if not isShurikenAttached(shuriken) then
            attachShuriken(shuriken)
        end
    end
end

local extinguishPart = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Hole") and Workspace.Map.Hole:FindFirstChild("PoisonBigHole") and Workspace.Map.Hole.PoisonBigHole:FindFirstChild("ExtinguishPart")

local function setupAntiBurn(player)
    if not player or player ~= localPlayer then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local firePart = rootPart:FindFirstChild("FirePlayerPart")
    if not firePart then return end
    local canBurn = firePart:FindFirstChild("CanBurn")
    if not canBurn then return end

    if burnConnections[player] then
        burnConnections[player]:Disconnect()
        burnConnections[player] = nil
    end

    local connection = canBurn.Changed:Connect(function()
        if antiBurnEnabled and canBurn.Value and extinguishPart then
            task.spawn(function()
                while antiBurnEnabled and canBurn.Value do
                    if firetouchinterest and type(firetouchinterest) == "function" then
                        pcall(function()
                            firetouchinterest(firePart, extinguishPart, 0)
                            task.wait()
                            firetouchinterest(firePart, extinguishPart, 1)
                        end)
                    else
                        pcall(function()
                            local origPos = extinguishPart.Position
                            extinguishPart.CFrame = firePart.CFrame * CFrame.new(math.random(-1,1), math.random(-1,1), math.random(-1,1))
                            task.wait(0.05)
                            extinguishPart.Position = origPos
                        end)
                    end
                    task.wait(0.1)
                end
            end)
        end
    end)

    burnConnections[player] = connection
end

local function setupAntiExplosion(player)
    if not player or player ~= localPlayer then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local ragdolled = humanoid:FindFirstChild("Ragdolled")
    if not ragdolled then return end

    if explosionConnections[player] then
        explosionConnections[player]:Disconnect()
        explosionConnections[player] = nil
    end

    local connection = ragdolled.Changed:Connect(function()
        if antiExplosionEnabled and ragdolled.Value then
            pcall(function()
                rootPart.Anchored = true
                rootPart.Velocity = Vector3.new(0,0,0)
                task.wait(0.1)
                rootPart.Anchored = false
            end)
        end
    end)

    explosionConnections[player] = connection
end

local function ensureAnti()
    if antiKickEnabled then
        pcall(ensureShuriken)
    end
    if antiBurnEnabled then
        pcall(setupAntiBurn, localPlayer)
    end
    if antiExplosionEnabled then
        pcall(setupAntiExplosion, localPlayer)
    end
end

local function startAnti()
    if checkTask then return end
    antiKickEnabled = undeitedhub.Toggles.antiKick or false
    antiBurnEnabled = undeitedhub.Toggles.antiBurn or false
    antiExplosionEnabled = undeitedhub.Toggles.antiExplosion or false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    checkTask = task.spawn(function()
        while antiKickEnabled or antiBurnEnabled or antiExplosionEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(ensureAnti)
            end
            task.wait(1)
        end
        checkTask = nil
    end)
end

local function stopAnti()
    antiKickEnabled = false
    antiBurnEnabled = false
    antiExplosionEnabled = false
    undeitedhub.Toggles.antiKick = false
    undeitedhub.Toggles.antiBurn = false
    undeitedhub.Toggles.antiExplosion = false
    if checkTask then
        task.cancel(checkTask)
        checkTask = nil
    end
    for _, conn in pairs(burnConnections) do
        pcall(conn.Disconnect, conn)
    end
    burnConnections = {}
    for _, conn in pairs(explosionConnections) do
        pcall(conn.Disconnect, conn)
    end
    explosionConnections = {}
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Anti", Content = "All disabled", Duration = 2 })
end

AntiTab:Toggle({
    Title = "Anti Kick",
    Value = antiKickEnabled,
    Callback = function(state)
        antiKickEnabled = state
        undeitedhub.Toggles.antiKick = state
        if state then startAnti() else stopAnti() end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Kick", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

AntiTab:Toggle({
    Title = "Anti Burn",
    Value = antiBurnEnabled,
    Callback = function(state)
        antiBurnEnabled = state
        undeitedhub.Toggles.antiBurn = state
        if state then startAnti() else stopAnti() end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Burn", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

AntiTab:Toggle({
    Title = "Anti Explosion",
    Value = antiExplosionEnabled,
    Callback = function(state)
        antiExplosionEnabled = state
        undeitedhub.Toggles.antiExplosion = state
        if state then startAnti() else stopAnti() end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Explosion", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

if antiKickEnabled or antiBurnEnabled or antiExplosionEnabled then
    startAnti()
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    stopAnti()
    oldDisable()
end
