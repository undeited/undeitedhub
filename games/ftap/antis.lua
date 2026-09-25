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
    partCount = 0,
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

local function readPartCount()
    local char = LocalPlayer.Character
    if not char then return 0 end
    local count = 0
    for _ in ipairs(char:GetDescendants()) do count = count + 1 end
    return count
end

local function refreshTuning()
    local now = tick()
    if Tuning.lastUpdate > 0 and now - Tuning.lastUpdate < Tuning.refreshInterval then return end
    Tuning.lastUpdate = now

    local ping = readPing()
    local players = math.max(1, #Players:GetPlayers())
    local gravity = Workspace.Gravity or 196.2
    local partCount = readPartCount()

    local pingFactor = clamp(ping / 0.2, 0, 2)
    local playerFactor = clamp((players - 1) / 12, 0, 2)

    Tuning.ping = ping
    Tuning.pingFactor = pingFactor
    Tuning.players = players
    Tuning.gravity = gravity
    Tuning.partCount = partCount

    Tuning.fireTickRate = clamp(0.05 / (1 + pingFactor * 0.3), 0.02, 0.15)
    Tuning.fireScanDivisor = math.max(2, math.floor(5 + playerFactor * 4))
    Tuning.firePartSweepRate = clamp(0.5 / (1 + playerFactor * 0.5), 0.15, 1.0)

    Tuning.lagSweepInterval = clamp(0.25 * (1 + playerFactor * 0.5) * (1 + pingFactor * 0.4), 0.1, 1.0)

    Tuning.grabPollInterval = clamp(0.04 / (1 + pingFactor * 0.5), 0.015, 0.1)

    Tuning.blobmanPollInterval = clamp(0.03 / (1 + pingFactor * 0.5), 0.01, 0.08)

    local gravityFactor = clamp(gravity / 196.2, 0.25, 3)
    Tuning.voidThreshold = clamp(80 * gravityFactor, 40, 250)
    Tuning.voidPredictTime = clamp(0.35 * (1 + pingFactor * 0.5), 0.2, 0.8)
    Tuning.voidCooldown = clamp(0.4 * (1 + pingFactor * 0.5), 0.25, 1.0)
    Tuning.voidSafeUpdateInterval = clamp(0.5 * (1 + pingFactor * 0.25), 0.25, 1.0)

    Tuning.explodeNearInterval = clamp(0.02 / (1 + pingFactor * 0.6), 0.008, 0.05)
    Tuning.explodeFarInterval = clamp(0.1 * (1 + playerFactor * 0.3), 0.05, 0.3)
    Tuning.explodeBuffer = clamp(6 * (1 + pingFactor * 0.6), 4, 20)
    Tuning.explodeLookahead = clamp(0.5 * (1 + pingFactor * 0.75), 0.3, 1.5)
    Tuning.explodeDetectionCooldown = clamp(2 + playerFactor, 1.5, 5)
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
    for _, prt in ipairs(character:GetDescendants()) do
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
    if obj:IsA("Fire") or obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
        local n = string.lower(obj.Name)
        for _, needle in ipairs(FIRE_NAMES) do
            if n:find(needle) then return true end
        end
    end
    if obj:IsA("BasePart") then
        local n = string.lower(obj.Name)
        for _, needle in ipairs(FIRE_NAMES) do
            if n:find(needle) then return true end
        end
    end
    return false
end

local function neutralizeFire(obj)
    if not obj then return end
    pcall(function() obj.Enabled = false end)
    if obj:IsA("BasePart") then
        pcall(function()
            obj.CanTouch = false
            obj.CanQuery = false
        end)
        pcall(function()
            local fire = obj:FindFirstChildOfClass("Fire")
            if fire then fire.Enabled = false end
        end)
        for _, d in ipairs(obj:GetDescendants()) do
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

local function startFireWatchers()
    for _, conn in ipairs(antiFireConnections) do
        pcall(function() conn:Disconnect() end)
    end
    antiFireConnections = {}

    for _, folder in ipairs(Workspace:GetChildren()) do
        for _, obj in ipairs(folder:GetDescendants()) do
            if isFireInstance(obj) then
                neutralizeFire(obj)
            end
        end
    end

    table.insert(antiFireConnections, Workspace.DescendantAdded:Connect(function(obj)
        if not antiFireActive then return end
        if isFireInstance(obj) then
            neutralizeFire(obj)
        end
    end))
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
            local scanTick = 0
            while antiFireActive do
                refreshTuning()

                pcall(function()
                    if hkFirePart and LocalPlayer.Character then
                        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hkFirePart.CFrame = hrp.CFrame
                        end
                    end
                end)

                scanTick = scanTick + 1
                if scanTick % Tuning.fireScanDivisor == 0 then
                    pcall(function()
                        for _, obj in ipairs(Workspace:GetDescendants()) do
                            if isFireInstance(obj) then
                                neutralizeFire(obj)
                            end
                        end
                    end)
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
    Beam = true,
    GrabLine = true,
    LinePart = true,
}

local function sweepLagSources()
    local cleared = 0

    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if LAG_CLASS_NAMES[d.ClassName] then
                    pcall(function() d:Destroy() end)
                    cleared = cleared + 1
                elseif d:IsA("BasePart") and LAG_PART_NAMES[d.Name] then
                    if plr ~= LocalPlayer then
                        pcall(function() d:Destroy() end)
                        cleared = cleared + 1
                    end
                end
            end
        end
    end

    return cleared
end

local function ApplyAntiLag(state)
    if state then
        pcall(function()
            LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = true
        end)
        pcall(sweepLagSources)
    else
        pcall(function()
            LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = false
        end)
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

                pcall(function()
                    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

                    local char = LocalPlayer.Character
                    if not char then return end

                    for _, d in ipairs(char:GetDescendants()) do
                        if LAG_CLASS_NAMES[d.ClassName] then
                            pcall(function() d:Destroy() end)
                        end
                    end

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
                end)
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

    for _, d in ipairs(character:GetDescendants()) do
        if d.Name == "PartOwner" and d.Value ~= "" then
            handleGrabIndicator(character, d)
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

                    pcall(function()
                        local char = LocalPlayer.Character
                        if not char then return end
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if not hum or hum.Health <= 0 then return end

                        local cleared = clearPartOwnersDeep(char)
                        if cleared then
                            fireRecovery(char, hum)
                        end
                    end)
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

if LocalPlayer.CharacterAdded then
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.2)
        if antiGrabActive then attachAntiGrabToCharacter(char) end
    end)
end

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

                pcall(function()
                    local character = LocalPlayer.Character
                    if not character then return end
                    local hum = character:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health <= 0 then return end

                    local broken = breakBlobmanWeldsOn(character)
                    local clearedOwners = clearPartOwnersDeep(character)

                    if broken > 0 or clearedOwners then
                        fireRecovery(character, hum)
                    end
                end)
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

    for _, child in ipairs(character:GetDescendants()) do
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

                pcall(function()
                    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

                    local character = LocalPlayer.Character
                    if not character then return end
                    local hum = character:FindFirstChildOfClass("Humanoid")
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if not hum or not hrp or hum.Health <= 0 then return end

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
                end)
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

local DEFAULT_BOMB_RADIUS = 17.5

local antiExplodeActive = false
local antiExplodeTask = nil
local detectedRadius = DEFAULT_BOMB_RADIUS
local detectedPositionParts = { "Body", "PositionPart", "Main", "Part", "VisualBody" }
local lastDetection = 0
local toyFolderConnections = {}

local function looksLikeBomb(model)
    if not model or not model:IsA("Model") then return false end
    return model:FindFirstChild("MissileScript") ~= nil
end

local function getToyFolders()
    local folders = {}
    for _, child in ipairs(Workspace:GetChildren()) do
        if child.Name:find("SpawnedInToys") then
            table.insert(folders, child)
        end
    end
    return folders
end

local function getMissileRadiusConstant(missileScript)
    if not missileScript then return nil end
    if type(debug) ~= "table" or type(debug.getconstants) ~= "function" then
        return nil
    end

    local ok, constants = pcall(debug.getconstants, missileScript)
    if not ok or type(constants) ~= "table" then return nil end

    local candidates = {}
    for _, v in ipairs(constants) do
        if type(v) == "number" and v >= 5 and v <= 50 then
            local rounded = math.floor(v * 10) / 10
            if math.abs(rounded - v) < 0.01 then
                table.insert(candidates, v)
            end
        end
    end

    if #candidates == 0 then return nil end
    table.sort(candidates)
    return candidates[1]
end

local function detectBombSettings()
    for _, folder in ipairs(getToyFolders()) do
        for _, toy in ipairs(folder:GetChildren()) do
            if looksLikeBomb(toy) then
                local parts = {}
                for _, candidate in ipairs({ "Body", "PositionPart", "Main", "Part", "VisualBody" }) do
                    if toy:FindFirstChild(candidate) then
                        table.insert(parts, candidate)
                    end
                end
                if #parts > 0 then
                    detectedPositionParts = parts
                end

                local missileScript = toy:FindFirstChild("MissileScript")
                local radius = getMissileRadiusConstant(missileScript)
                if radius then
                    detectedRadius = radius
                end

                return true
            end
        end
    end
    return false
end

local function getAllBombs()
    local bombs = {}
    for _, folder in ipairs(getToyFolders()) do
        for _, toy in ipairs(folder:GetChildren()) do
            if looksLikeBomb(toy) then
                table.insert(bombs, toy)
            end
        end
    end
    return bombs
end

local function getBombBodyPart(bomb)
    if not bomb then return nil end
    for _, name in ipairs(detectedPositionParts) do
        local part = bomb:FindFirstChild(name)
        if part and part:IsA("BasePart") then return part end
    end
    if bomb.PrimaryPart then return bomb.PrimaryPart end
    for _, part in ipairs(bomb:GetDescendants()) do
        if part:IsA("BasePart") then return part end
    end
    return nil
end

local function getBombPosition(bomb)
    local body = getBombBodyPart(bomb)
    return body and body.Position
end

local function destroyBomb(bomb)
    if not bomb then return end
    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    local destroyToy = menuToys and menuToys:FindFirstChild("DestroyToy")
    if destroyToy then
        pcall(function() destroyToy:FireServer(bomb) end)
    end
    pcall(function() bomb:Destroy() end)
end

local function isBombThreat(bomb, hrp)
    local body = getBombBodyPart(bomb)
    if not body then return false end
    local pos = body.Position
    local dist = (pos - hrp.Position).Magnitude
    if dist <= detectedRadius + Tuning.explodeBuffer then
        return true
    end

    local vel = body.AssemblyLinearVelocity
    if vel.Magnitude < 5 then return false end

    local rel = hrp.Position - pos
    local dir = vel.Unit
    local forward = rel:Dot(dir)
    if forward <= 0 then return false end

    local perpendicular = (rel - dir * forward).Magnitude
    if perpendicular > detectedRadius + Tuning.explodeBuffer then return false end

    local timeToImpact = forward / vel.Magnitude
    if timeToImpact < Tuning.explodeLookahead then
        return true
    end

    return false
end

local function attachBombWatcher(folder)
    local conn = folder.ChildAdded:Connect(function(toy)
        if not antiExplodeActive then return end
        if not looksLikeBomb(toy) then return end
        task.defer(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            task.wait(0.05)
            if toy.Parent and isBombThreat(toy, hrp) then
                destroyBomb(toy)
            end
        end)
    end)
    table.insert(toyFolderConnections, conn)
end

local function stopBombWatchers()
    for _, conn in ipairs(toyFolderConnections) do
        pcall(function() conn:Disconnect() end)
    end
    toyFolderConnections = {}
end

local function ToggleAntiExplode(state)
    antiExplodeActive = state

    if state then
        refreshTuning()
        if antiExplodeTask then return end

        lastDetection = 0
        detectedRadius = DEFAULT_BOMB_RADIUS
        detectedPositionParts = { "Body", "PositionPart", "Main", "Part", "VisualBody" }

        stopBombWatchers()
        for _, folder in ipairs(getToyFolders()) do
            attachBombWatcher(folder)
        end

        toyFolderConnections[#toyFolderConnections + 1] = Workspace.ChildAdded:Connect(function(child)
            if not antiExplodeActive then return end
            if child.Name:find("SpawnedInToys") then
                attachBombWatcher(child)
            end
        end)

        antiExplodeTask = task.spawn(function()
            while antiExplodeActive do
                refreshTuning()

                pcall(function()
                    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

                    local now = tick()
                    if now - lastDetection > Tuning.explodeDetectionCooldown then
                        lastDetection = now
                        pcall(detectBombSettings)
                    end

                    local char = LocalPlayer.Character
                    if not char then return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if not hrp or not hum or hum.Health <= 0 then return end

                    local bombs = getAllBombs()
                    local nearestDist = math.huge

                    for _, bomb in ipairs(bombs) do
                        if bomb.Parent then
                            local pos = getBombPosition(bomb)
                            if pos then
                                local d = (pos - hrp.Position).Magnitude
                                if d < nearestDist then nearestDist = d end
                                if isBombThreat(bomb, hrp) then
                                    destroyBomb(bomb)
                                end
                            end
                        end
                    end

                    if nearestDist < (detectedRadius + Tuning.explodeBuffer) * 3 then
                        task.wait(Tuning.explodeNearInterval)
                    else
                        task.wait(Tuning.explodeFarInterval)
                    end
                end)
            end
            antiExplodeTask = nil
        end)
    else
        if antiExplodeTask then
            task.cancel(antiExplodeTask)
            antiExplodeTask = nil
        end
        stopBombWatchers()
    end
end

AntisTab:Toggle({
    Title = "Anti Explode",
    Value = antiExplodeActive,
    Callback = function(state)
        ToggleAntiExplode(state)
        undeitedhub.Toggles.antiExplode = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Explode", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

if undeitedhub.Toggles.antiExplode then
    ToggleAntiExplode(true)
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if antiFireActive then ToggleAntiFire(false) end
    if antiLagActive then ToggleAntiLag(false) end
    if antiGrabActive then ToggleAntiGrab(false) end
    if antiBlobmanActive then ToggleAntiBlobman(false) end
    if antiVoidActive then ToggleAntiVoid(false) end
    if antiExplodeActive then ToggleAntiExplode(false) end
    oldDisable()
end
