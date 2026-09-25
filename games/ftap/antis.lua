local WindUI = undeitedhub.WindUI
local AntisTab = undeitedhub.Window:Tab({ Title = "Antis" })

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

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

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local Tuning = {
    lastUpdate = 0,
    refreshInterval = 2,
    ping = 0,
    pingFactor = 0,
    players = 1,
    gravity = 196.2,
}

local function readPing()
    local ok, ping = pcall(function()
        if Stats and Stats.Network and Stats.Network.ServerStatsItem then
            local item = Stats.Network.ServerStatsItem["Data Ping"]
            if item then return item:GetValue() / 1000 end
        end
        return 0
    end)
    if not ok or type(ping) ~= "number" or ping ~= ping then return 0 end
    return ping
end

local function refreshTuning()
    local now = tick()
    if Tuning.lastUpdate > 0 and now - Tuning.lastUpdate < Tuning.refreshInterval then return end
    Tuning.lastUpdate = now

    local ping = readPing()
    local players = math.max(1, #Players:GetPlayers())
    local gravity = Workspace.Gravity or 196.2

    local pingFactor = clamp(ping / 0.2, 0, 2)
    local playerFactor = clamp((players - 1) / 12, 0, 2)

    Tuning.ping = ping
    Tuning.pingFactor = pingFactor
    Tuning.players = players
    Tuning.gravity = gravity

    Tuning.fireTickRate = clamp(0.05 / (1 + pingFactor * 0.3), 0.02, 0.15)
    Tuning.lagSweepInterval = clamp(0.5 * (1 + playerFactor * 0.4) * (1 + pingFactor * 0.3), 0.25, 1.5)
    Tuning.grabPollInterval = clamp(0.1 / (1 + pingFactor * 0.4), 0.05, 0.25)
    Tuning.blobmanPollInterval = clamp(0.08 / (1 + pingFactor * 0.4), 0.04, 0.2)

    local gravityFactor = clamp(gravity / 196.2, 0.25, 3)
    Tuning.voidThreshold = clamp(80 * gravityFactor, 40, 250)
    Tuning.voidPredictTime = clamp(0.35 * (1 + pingFactor * 0.5), 0.2, 0.8)
    Tuning.voidCooldown = clamp(0.4 * (1 + pingFactor * 0.5), 0.25, 1.0)
    Tuning.voidSafeUpdateInterval = clamp(0.5 * (1 + pingFactor * 0.25), 0.25, 1.0)
end

refreshTuning()

local function getCharacterParts(character)
    if not character then return {} end
    local list = {}
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("BasePart") then
            table.insert(list, d)
        end
    end
    return list
end

local function zeroVelocity(part)
    if not part then return end
    pcall(function()
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
        part.Velocity = Vector3.zero
        part.RotVelocity = Vector3.zero
    end)
end

local function getCharacterEvents()
    return ReplicatedStorage:FindFirstChild("CharacterEvents")
end

local function fireRecovery(character, hum)
    if not character or not hum then return end
    local characterEvents = getCharacterEvents()
    if characterEvents then
        local struggle = characterEvents:FindFirstChild("Struggle")
        if struggle then
            pcall(function() struggle:FireServer(LocalPlayer) end)
        end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        local ragdollRemote = characterEvents:FindFirstChild("RagdollRemote")
        if hrp and ragdollRemote then
            pcall(function() ragdollRemote:FireServer(hrp, 0.00000000001) end)
        end
    end

    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        if track.Animation and track.Animation.AnimationId == "rbxassetid://7047322890" then
            pcall(function() track:Stop() end)
        end
    end

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        hum.AutoRotate = true
        if hum.Sit then hum.Sit = false end
        hum.PlatformStand = false
    end)
end

local function clearPartOwnersDeep(character)
    if not character then return false end
    local found = false
    for _, prt in ipairs(character:GetChildren()) do
        local partOwner = prt:FindFirstChild("PartOwner")
        if partOwner and partOwner.Value ~= "" then
            found = true
            pcall(function() partOwner.Value = "" end)
        end
    end
    return found
end

local function isBlobmanPart(part)
    if not part then return false end
    local current = part
    while current do
        if current.Name == "CreatureBlobman" then return true end
        current = current.Parent
    end
    return false
end

local function isBlobmanWeld(child)
    if not (child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("RigidConstraint") or child:IsA("Motor6D")) then
        return false
    end
    local p0 = child.Part0
    local p1 = child.Part1
    if not p0 or not p1 then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local aIsChar = p0:IsDescendantOf(char)
    local bIsChar = p1:IsDescendantOf(char)
    if not (aIsChar or bIsChar) then return false end
    local opposite = aIsChar and p1 or p0
    return isBlobmanPart(opposite)
end

local function breakBlobmanWeldsOn(character)
    if not character then return 0 end
    local count = 0
    for _, child in ipairs(character:GetDescendants()) do
        if isBlobmanWeld(child) then
            pcall(function() child:Destroy() end)
            count = count + 1
        end
    end
    return count
end

local antiFireActive = false
local antiFireTask = nil
local antiFireConnections = {}
local hkFirePart = nil

local FIRE_NAMES = { "fire", "flame", "burn", "inferno", "ignite" }

local function isFireInstance(obj)
    if not obj then return false end
    local class = obj.ClassName
    if class == "Fire" or class == "ParticleEmitter" or class == "Trail" then
        local n = string.lower(obj.Name)
        for _, needle in ipairs(FIRE_NAMES) do
            if n:find(needle, 1, true) then return true end
        end
        return false
    end
    if class == "Part" or class == "MeshPart" or class == "UnionOperation" or class == "TrussPart" then
        local n = string.lower(obj.Name)
        for _, needle in ipairs(FIRE_NAMES) do
            if n:find(needle, 1, true) then return true end
        end
    end
    return false
end

local function neutralizeFire(obj)
    if not obj then return end
    if obj:IsA("Fire") or obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
        pcall(function() obj.Enabled = false end)
        return
    end
    if obj:IsA("BasePart") then
        pcall(function()
            obj.CanTouch = false
            obj.CanQuery = false
        end)
        for _, d in ipairs(obj:GetChildren()) do
            if d:IsA("Fire") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
                pcall(function() d.Enabled = false end)
            end
        end
    end
end

local function buildFireBarrier()
    local plot = Workspace:FindFirstChild("Plots")
    if not plot then return end
    local plot5 = plot:FindFirstChild("Plot5")
    if not plot5 then return end
    local barrier = plot5:FindFirstChild("Barrier")
    if not barrier then return end

    if barrier:FindFirstChild("AntiFirePart") then
        hkFirePart = barrier:FindFirstChild("AntiFirePart")
    else
        hkFirePart = barrier:FindFirstChild("PlotBarrier")
    end
    if not hkFirePart then return end

    hkFirePart.CanCollide = true
    hkFirePart.CanQuery = true
    hkFirePart.Name = "AntiFirePart"

    if not hkFirePart.Parent:FindFirstChild("FalseBorder") then
        local h2 = hkFirePart:Clone()
        h2.Name = "FalseBorder"
        h2.Parent = hkFirePart.Parent
    end

    hkFirePart.Size = Vector3.new(1, 1, 1)
    for _, prt in pairs(hkFirePart:GetChildren()) do
        prt:Destroy()
    end
    hkFirePart.CanQuery = false
    hkFirePart.CanCollide = false
end

local function scanFireTargets()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return end
    for _, plot in ipairs(plots:GetChildren()) do
        for _, obj in ipairs(plot:GetDescendants()) do
            if isFireInstance(obj) then
                neutralizeFire(obj)
            end
        end
    end
end

local function startFireWatchers()
    for _, conn in ipairs(antiFireConnections) do
        pcall(function() conn:Disconnect() end)
    end
    antiFireConnections = {}

    table.insert(antiFireConnections, Workspace.DescendantAdded:Connect(function(obj)
        if not antiFireActive then return end
        if isFireInstance(obj) then
            neutralizeFire(obj)
        end
    end))

    scanFireTargets()
end

local function stopFireWatchers()
    for _, conn in ipairs(antiFireConnections) do
        pcall(function() conn:Disconnect() end)
    end
    antiFireConnections = {}
end

local function ToggleAntiFire(state)
    antiFireActive = state
    if state then
        refreshTuning()
        pcall(buildFireBarrier)
        pcall(startFireWatchers)

        antiFireTask = task.spawn(function()
            while antiFireActive do
                refreshTuning()

                if hkFirePart then
                    local char = LocalPlayer.Character
                    if char then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            pcall(function() hkFirePart.CFrame = hrp.CFrame end)
                        end
                    end
                end

                task.wait(Tuning.fireTickRate)
            end
            if hkFirePart then
                hkFirePart.CFrame = CFrame.new(0, -15, 0)
            end
        end)
    else
        if antiFireTask then
            task.cancel(antiFireTask)
            antiFireTask = nil
        end
        if hkFirePart then
            hkFirePart.CFrame = CFrame.new(0, -15, 0)
        end
        stopFireWatchers()
    end
end

AntisTab:Toggle({
    Title = "Anti Fire",
    Value = false,
    Callback = function(state)
        ToggleAntiFire(state)
        undeitedhub.Toggles.antiFire = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Fire", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

if undeitedhub.Toggles.antiFire then
    ToggleAntiFire(true)
end

local antiLagActive = false
local antiLagTask = nil
local antiLagConnections = {}

local LAG_CLASS_NAMES = {
    Beam = true,
    ParticleEmitter = true,
    Trail = true,
    Smoke = true,
    Fire = true,
    Sparkles = true,
}

local LAG_PART_NAMES = {
    GrabParts = true,
    GrabPart = true,
    GrabLine = true,
    LinePart = true,
}

local function handleLagInstance(desc)
    if not antiLagActive then return end
    if LAG_CLASS_NAMES[desc.ClassName] then
        pcall(function() desc:Destroy() end)
    elseif LAG_PART_NAMES[desc.Name] then
        pcall(function() desc:Destroy() end)
    end
end

local function attachLagWatcher(character)
    if not character then return end
    if character == LocalPlayer.Character then return end
    local conn = character.DescendantAdded:Connect(handleLagInstance)
    table.insert(antiLagConnections, conn)
end

local function sweepLocalCharacter()
    local char = LocalPlayer.Character
    if not char then return end
    for _, d in ipairs(char:GetChildren()) do
        if LAG_CLASS_NAMES[d.ClassName] then
            pcall(function() d:Destroy() end)
        end
    end
    for _, d in ipairs(char:GetChildren()) do
        if d:IsA("BasePart") and LAG_PART_NAMES[d.Name] then
            pcall(function() d:Destroy() end)
        end
    end
end

local function ApplyAntiLag(state)
    if state then
        pcall(function()
            LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = true
        end)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                attachLagWatcher(plr.Character)
            end
        end
    else
        pcall(function()
            LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = false
        end)
        for _, conn in ipairs(antiLagConnections) do
            pcall(function() conn:Disconnect() end)
        end
        antiLagConnections = {}
    end
end

local function ToggleAntiLag(state)
    antiLagActive = state
    ApplyAntiLag(state)

    if state then
        if antiLagTask then return end
        antiLagTask = task.spawn(function()
            while antiLagActive do
                refreshTuning()

                if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                    pcall(sweepLocalCharacter)

                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= LocalPlayer then
                            local pchar = plr.Character
                            if pchar then
                                local grabParts = pchar:FindFirstChild("GrabParts")
                                if grabParts then
                                    pcall(function() grabParts:Destroy() end)
                                end
                            end
                        end
                    end
                end

                task.wait(Tuning.lagSweepInterval)
            end
            antiLagTask = nil
        end)
    else
        if antiLagTask then
            task.cancel(antiLagTask)
            antiLagTask = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Lag",
    Value = false,
    Callback = function(state)
        ToggleAntiLag(state)
        undeitedhub.Toggles.antiLag = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Lag", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

Players.PlayerAdded:Connect(function(plr)
    if plr == LocalPlayer then return end
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.2)
        if antiLagActive then attachLagWatcher(char) end
    end)
end)

if undeitedhub.Toggles.antiLag then
    ToggleAntiLag(true)
end

local antiGrabActive = false
local antiGrabTask = nil
local antiGrabConnections = {}

local function handleGrabIndicator(character, partOwner)
    if not partOwner or partOwner.Value == "" then return end
    pcall(function() partOwner.Value = "" end)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then
        fireRecovery(character, hum)
    end
end

local function attachAntiGrabToCharacter(character)
    for _, conn in ipairs(antiGrabConnections) do
        pcall(function() conn:Disconnect() end)
    end
    antiGrabConnections = {}

    if not antiGrabActive or not character then return end

    table.insert(antiGrabConnections, character.DescendantAdded:Connect(function(desc)
        if not antiGrabActive then return end
        if desc.Name == "PartOwner" then
            task.defer(function()
                if desc.Parent and desc.Value ~= "" then
                    handleGrabIndicator(character, desc)
                end
            end)
        end
    end))

    for _, d in ipairs(character:GetChildren()) do
        local po = d:FindFirstChild("PartOwner")
        if po and po.Value ~= "" then
            handleGrabIndicator(character, po)
        end
    end
end

local function ToggleAntiGrab(state)
    antiGrabActive = state

    if state then
        refreshTuning()
        local character = LocalPlayer.Character
        if character then
            attachAntiGrabToCharacter(character)
        end

        if not antiGrabTask then
            antiGrabTask = task.spawn(function()
                while antiGrabActive do
                    refreshTuning()

                    if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                        local char = LocalPlayer.Character
                        if char then
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            if hum and hum.Health > 0 then
                                local cleared = clearPartOwnersDeep(char)
                                if cleared then
                                    fireRecovery(char, hum)
                                end
                            end
                        end
                    end

                    task.wait(Tuning.grabPollInterval)
                end
                antiGrabTask = nil
            end)
        end
    else
        if antiGrabTask then
            task.cancel(antiGrabTask)
            antiGrabTask = nil
        end
        for _, conn in ipairs(antiGrabConnections) do
            pcall(function() conn:Disconnect() end)
        end
        antiGrabConnections = {}
    end
end

AntisTab:Toggle({
    Title = "Anti Grab",
    Value = false,
    Callback = function(state)
        ToggleAntiGrab(state)
        undeitedhub.Toggles.antiGrab = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Grab", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    if antiGrabActive then attachAntiGrabToCharacter(char) end
end)

if undeitedhub.Toggles.antiGrab then
    ToggleAntiGrab(true)
end

local antiBlobmanActive = false
local antiBlobmanTask = nil
local antiBlobmanConnections = {}

local function attachAntiBlobmanToCharacter(character)
    for _, conn in ipairs(antiBlobmanConnections) do
        pcall(function() conn:Disconnect() end)
    end
    antiBlobmanConnections = {}

    if not antiBlobmanActive or not character then return end

    table.insert(antiBlobmanConnections, character.DescendantAdded:Connect(function(desc)
        if not antiBlobmanActive then return end
        if isBlobmanWeld(desc) then
            pcall(function() desc:Destroy() end)
            local hum = character:FindFirstChildOfClass("Humanoid")
            if hum then fireRecovery(character, hum) end
        end
    end))
end

local function ToggleAntiBlobman(state)
    antiBlobmanActive = state

    if state then
        refreshTuning()
        local character = LocalPlayer.Character
        if character then
            attachAntiBlobmanToCharacter(character)
        end

        if antiBlobmanTask then return end
        antiBlobmanTask = task.spawn(function()
            while antiBlobmanActive do
                refreshTuning()

                if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                    local character = LocalPlayer.Character
                    if character then
                        local hum = character:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            local broken = breakBlobmanWeldsOn(character)
                            local clearedOwners = clearPartOwnersDeep(character)

                            if broken > 0 or clearedOwners then
                                fireRecovery(character, hum)
                            end
                        end
                    end
                end

                task.wait(Tuning.blobmanPollInterval)
            end
            antiBlobmanTask = nil
        end)
    else
        if antiBlobmanTask then
            task.cancel(antiBlobmanTask)
            antiBlobmanTask = nil
        end
        for _, conn in ipairs(antiBlobmanConnections) do
            pcall(function() conn:Disconnect() end)
        end
        antiBlobmanConnections = {}
    end
end

AntisTab:Toggle({
    Title = "Anti Blobman",
    Value = antiBlobmanActive,
    Callback = function(state)
        ToggleAntiBlobman(state)
        undeitedhub.Toggles.antiBlobman = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Blobman", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    if antiBlobmanActive then attachAntiBlobmanToCharacter(char) end
end)

if undeitedhub.Toggles.antiBlobman then
    ToggleAntiBlobman(true)
end

local ANTI_VOID_OFFSET = Vector3.new(0, 3, 0)

local antiVoidActive = false
local antiVoidTask = nil
local lastVoidRestore = 0
local lastSafeCFrame = nil
local lastSafeUpdate = 0

local function getDeathBarrierHeight()
    local h = Workspace.FallenPartsDestroyHeight
    if type(h) == "number" and h == h and h ~= math.huge and h ~= -math.huge then
        return h
    end
    return -500
end

local function findBestSpawn()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local origin = (hrp and lastSafeCFrame) and lastSafeCFrame.Position or (hrp and hrp.Position)

    local candidates = {}
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") and (obj.Name == "SpawnLocation" or obj.Name:find("Spawn")) then
            table.insert(candidates, obj)
        elseif obj:IsA("Model") and (obj.Name:find("Lobby") or obj.Name:find("RegularLobby")) then
            local spawns = obj:FindFirstChild("Spawns")
            if spawns then
                for _, sp in ipairs(spawns:GetChildren()) do
                    if sp:IsA("BasePart") then table.insert(candidates, sp) end
                end
            end
        end
    end

    if #candidates == 0 then
        local s = Workspace:FindFirstChild("SpawnLocation")
        if s and s:IsA("BasePart") then return s.CFrame + ANTI_VOID_OFFSET end
        return nil
    end

    if not origin then
        return candidates[1].CFrame + ANTI_VOID_OFFSET
    end

    local best, bestDist = candidates[1], math.huge
    for _, c in ipairs(candidates) do
        local d = (c.Position - origin).Magnitude
        if d < bestDist then
            bestDist = d
            best = c
        end
    end
    return best.CFrame + ANTI_VOID_OFFSET
end

local function restoreCharacterState(character, hum, hrp, targetCFrame)
    if not character or not hum or not hrp then return end

    for _, part in ipairs(getCharacterParts(character)) do
        zeroVelocity(part)
    end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") or
           child:IsA("BodyForce") or child:IsA("BodyGyro") or
           child:IsA("BodyPosition") or child:IsA("BodyThrust") then
            pcall(function() child:Destroy() end)
        end
    end

    pcall(function()
        if targetCFrame then
            character:PivotTo(targetCFrame)
        else
            hrp.CFrame = CFrame.new(hrp.Position + ANTI_VOID_OFFSET)
        end
    end)

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        hum.AutoRotate = true
        if hum.Sit then hum.Sit = false end
        hum.PlatformStand = false
    end)

    fireRecovery(character, hum)
end

local function ToggleAntiVoid(state)
    antiVoidActive = state

    if state then
        refreshTuning()
        if antiVoidTask then return end

        antiVoidTask = task.spawn(function()
            while antiVoidActive do
                refreshTuning()

                if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                    local character = LocalPlayer.Character
                    if character then
                        local hum = character:FindFirstChildOfClass("Humanoid")
                        local hrp = character:FindFirstChild("HumanoidRootPart")
                        if hum and hrp and hum.Health > 0 then
                            local barrierY = getDeathBarrierHeight()
                            local thresholdY = barrierY + Tuning.voidThreshold

                            local now = tick()
                            local pos = hrp.Position
                            local vel = hrp.AssemblyLinearVelocity

                            if now - lastSafeUpdate > Tuning.voidSafeUpdateInterval and pos.Y > thresholdY + 40 then
                                lastSafeCFrame = hrp.CFrame
                                lastSafeUpdate = now
                            end

                            local trigger = false
                            if pos.Y <= thresholdY then
                                trigger = true
                            end

                            if not trigger and vel.Y < -100 then
                                local predictedY = pos.Y + vel.Y * Tuning.voidPredictTime
                                if predictedY <= thresholdY then
                                    trigger = true
                                end
                            end

                            if trigger then
                                if now - lastVoidRestore > Tuning.voidCooldown then
                                    lastVoidRestore = now

                                    local target = findBestSpawn() or lastSafeCFrame
                                    restoreCharacterState(character, hum, hrp, target)

                                    SafeNotify({
                                        Title = "Anti Void",
                                        Content = "Pulled you back from the void",
                                        Duration = 1.5,
                                    })
                                end
                            end
                        end
                    end
                end
                RunService.Heartbeat:Wait()
            end
            antiVoidTask = nil
        end)
    else
        if antiVoidTask then
            task.cancel(antiVoidTask)
            antiVoidTask = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Void",
    Value = antiVoidActive,
    Callback = function(state)
        ToggleAntiVoid(state)
        undeitedhub.Toggles.antiVoid = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Void", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

if undeitedhub.Toggles.antiVoid then
    ToggleAntiVoid(true)
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if antiFireActive then ToggleAntiFire(false) end
    if antiLagActive then ToggleAntiLag(false) end
    if antiGrabActive then ToggleAntiGrab(false) end
    if antiBlobmanActive then ToggleAntiBlobman(false) end
    if antiVoidActive then ToggleAntiVoid(false) end
    oldDisable()
end
