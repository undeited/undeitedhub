local WindUI = undeitedhub.WindUI
local AntisTab = undeitedhub.Window:Tab({ Title = "Antis" })

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

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
    Tuning.grabStruggleInterval = clamp(0.15 / (1 + pingFactor * 0.4), 0.08, 0.3)
    Tuning.blobmanPollInterval = clamp(0.05 / (1 + pingFactor * 0.4), 0.02, 0.15)

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

local function getWeldConnectedParts(weld)
    if not weld then return nil, nil end
    if weld:IsA("RigidConstraint") then
        local a0 = weld.Attachment0
        local a1 = weld.Attachment1
        if a0 and a1 then
            return a0.Parent, a1.Parent
        end
        return nil, nil
    else
        return weld.Part0, weld.Part1
    end
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
    end
})

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
    end
})

Players.PlayerAdded:Connect(function(plr)
    if plr == LocalPlayer then return end
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.2)
        if antiLagActive then attachLagWatcher(char) end
    end)
end)

local antiGrabActive = false
local antiGrabHeartbeat = nil
local antiGrabWorkspaceConn = nil
local antiGrabCharConn = nil
local lastStruggleFire = 0

local function isForeignWeld(weld)
    if not weld then return false end
    if not (weld:IsA("Weld")
        or weld:IsA("WeldConstraint")
        or weld:IsA("RigidConstraint")
        or weld:IsA("Motor6D")
        or weld:IsA("Snap")
        or weld:IsA("ManualWeld")) then
        return false
    end

    local p0, p1 = getWeldConnectedParts(weld)
    if not p0 or not p1 then return false end

    local char = LocalPlayer.Character
    if not char then return false end

    local aIsChar = p0:IsDescendantOf(char)
    local bIsChar = p1:IsDescendantOf(char)
    if not (aIsChar or bIsChar) then return false end

    local opposite = aIsChar and p1 or p0
    if opposite:IsDescendantOf(char) then return false end

    return true
end

local function breakWeld(weld)
    if not weld then return end
    pcall(function() weld:Destroy() end)
end

local function scrubCharacterWelds()
    local char = LocalPlayer.Character
    if not char then return 0 end
    local count = 0
    for _, d in ipairs(char:GetDescendants()) do
        if isForeignWeld(d) then
            breakWeld(d)
            count = count + 1
        end
    end
    return count
end

local function scrubWorkspaceWelds()
    local count = 0
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart") then
            for _, desc in ipairs(obj:GetDescendants()) do
                if isForeignWeld(desc) then
                    breakWeld(desc)
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function reclaimCharacterOwnership()
    local char = LocalPlayer.Character
    if not char then return 0 end
    local count = 0
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        pcall(function()
            local owner = hrp:GetNetworkOwner()
            if owner and owner ~= LocalPlayer then
                hrp:SetNetworkOwner(LocalPlayer)
                count = count + 1
            end
        end)
    end
    return count
end

local function undoRagdoll(hum, hrp)
    if not hum then return end

    local state = hum:GetState()
    local needsFix = false

    if state == Enum.HumanoidStateType.Physics
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Ragdoll then
        needsFix = true
    end
    if hum.PlatformStand then needsFix = true end
    if hum.Sit then needsFix = true end

    if needsFix then
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end

        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            hum.PlatformStand = false
            hum.Sit = false
            hum.AutoRotate = true
        end)
    end

    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        if track.Animation and track.Animation.AnimationId == "rbxassetid://7047322890" then
            pcall(function() track:Stop() end)
        end
    end
end

local function onGrabHeartbeat()
    if not antiGrabActive then return end
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return end

    local isGrabbed = false
    local state = hum:GetState()
    
    if hum.PlatformStand or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.Physics then
        isGrabbed = true
    end

    if isGrabbed then
        scrubCharacterWelds()
        undoRagdoll(hum, hrp)
        reclaimCharacterOwnership()

        local now = tick()
        if now - lastStruggleFire >= Tuning.grabStruggleInterval then
            lastStruggleFire = now
            local characterEvents = getCharacterEvents()
            if characterEvents then
                local struggle = characterEvents:FindFirstChild("Struggle")
                if struggle then
                    pcall(function() struggle:FireServer(LocalPlayer) end)
                end
                local ragdollRemote = characterEvents:FindFirstChild("RagdollRemote")
                if ragdollRemote then
                    pcall(function() ragdollRemote:FireServer(hrp, 0.00000000001) end)
                end
            end
        end
    end
end

local function onWorkspaceDescendantAdded(obj)
    if not antiGrabActive then return end
    if obj:IsA("Weld")
        or obj:IsA("WeldConstraint")
        or obj:IsA("RigidConstraint")
        or obj:IsA("Motor6D")
        or obj:IsA("Snap")
        or obj:IsA("ManualWeld") then
        if isForeignWeld(obj) then
            breakWeld(obj)
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then fireRecovery(char, hum) end
            end
        end
    end
end

local function onCharDescendantAdded(desc)
    if not antiGrabActive then return end

    if desc.Name == "PartOwner" then
        task.defer(function()
            if not antiGrabActive then return end
            if desc.Parent and desc.Value ~= "" then
                pcall(function() desc.Value = "" end)
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then fireRecovery(char, hum) end
                end
            end
        end)
        return
    end

    if desc:IsA("Weld")
        or desc:IsA("WeldConstraint")
        or desc:IsA("RigidConstraint")
        or desc:IsA("Motor6D")
        or desc:IsA("Snap")
        or desc:IsA("ManualWeld") then
        task.defer(function()
            if not antiGrabActive then return end
            if isForeignWeld(desc) then
                breakWeld(desc)
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then fireRecovery(char, hum) end
                end
            end
        end)
    end
end

local function attachAntiGrabToCharacter(character)
    if antiGrabCharConn then
        pcall(function() antiGrabCharConn:Disconnect() end)
        antiGrabCharConn = nil
    end
    if not antiGrabActive or not character then return end

    antiGrabCharConn = character.DescendantAdded:Connect(onCharDescendantAdded)

    for _, d in ipairs(character:GetChildren()) do
        local po = d:FindFirstChild("PartOwner")
        if po and po.Value ~= "" then
            pcall(function() po.Value = "" end)
        end
    end
end

local function ToggleAntiGrab(state)
    antiGrabActive = state

    if state then
        refreshTuning()

        if antiGrabHeartbeat then
            pcall(function() antiGrabHeartbeat:Disconnect() end)
            antiGrabHeartbeat = nil
        end
        antiGrabHeartbeat = RunService.Heartbeat:Connect(onGrabHeartbeat)

        if antiGrabWorkspaceConn then
            pcall(function() antiGrabWorkspaceConn:Disconnect() end)
            antiGrabWorkspaceConn = nil
        end
        antiGrabWorkspaceConn = Workspace.DescendantAdded:Connect(onWorkspaceDescendantAdded)

        local character = LocalPlayer.Character
        if character then
            attachAntiGrabToCharacter(character)
        end
    else
        if antiGrabHeartbeat then
            pcall(function() antiGrabHeartbeat:Disconnect() end)
            antiGrabHeartbeat = nil
        end
        if antiGrabWorkspaceConn then
            pcall(function() antiGrabWorkspaceConn:Disconnect() end)
            antiGrabWorkspaceConn = nil
        end
        if antiGrabCharConn then
            pcall(function() antiGrabCharConn:Disconnect() end)
            antiGrabCharConn = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Grab",
    Value = false,
    Callback = function(state)
        ToggleAntiGrab(state)
    end
})

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    if antiGrabActive then attachAntiGrabToCharacter(char) end
end)

local antiBlobmanActive = false
local antiBlobmanTask = nil
local antiBlobmanRootAttachment = nil
local antiBlobmanFakeValue = nil
local antiBlobmanCharacter = nil

local function cleanupAntiBlobman()
    if antiBlobmanRootAttachment then
        if antiBlobmanRootAttachment.Parent then
            if antiBlobmanCharacter and antiBlobmanCharacter.Parent then
                antiBlobmanRootAttachment.Parent = antiBlobmanCharacter
            else
                antiBlobmanRootAttachment:Destroy()
            end
        end
        antiBlobmanRootAttachment = nil
    end
    if antiBlobmanFakeValue then
        if antiBlobmanFakeValue.Parent then
            antiBlobmanFakeValue:Destroy()
        end
        antiBlobmanFakeValue = nil
    end
    antiBlobmanCharacter = nil
end

local function runAntiBlobman()
    while antiBlobmanActive do
        if not _G.UNDEITEDHUB_WINDOW_VISIBLE then
            task.wait(0.1)
            continue
        end

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not char or not hum or not hrp or hum.Health <= 0 then
            cleanupAntiBlobman()
            task.wait(0.1)
            continue
        end

        if antiBlobmanCharacter ~= char then
            cleanupAntiBlobman()
            antiBlobmanCharacter = char
        end

        if antiBlobmanRootAttachment and not antiBlobmanRootAttachment.Parent then
            antiBlobmanRootAttachment = nil
            if antiBlobmanFakeValue and antiBlobmanFakeValue.Parent then
                antiBlobmanFakeValue:Destroy()
            end
            antiBlobmanFakeValue = nil
        end

        if not antiBlobmanRootAttachment then
            local found = hrp:FindFirstChild("RootAttachment")
            if found and found:IsA("Attachment") then
                task.wait(0.5)
                if not antiBlobmanActive then
                    break
                end
                if not found.Parent then
                    task.wait()
                    continue
                end
                antiBlobmanRootAttachment = found
                found.Parent = ReplicatedStorage
                antiBlobmanFakeValue = Instance.new("BoolValue")
                antiBlobmanFakeValue.Name = "RootAttachment"
                antiBlobmanFakeValue.Parent = hrp
            end
        end

        if hrp.Massless then
            hrp.Massless = false
        end

        task.wait()
    end
    cleanupAntiBlobman()
end

local function ToggleAntiBlobman(state)
    antiBlobmanActive = state

    if state then
        if antiBlobmanTask then
            return
        end
        antiBlobmanTask = task.spawn(runAntiBlobman)
    else
        if antiBlobmanTask then
            task.cancel(antiBlobmanTask)
            antiBlobmanTask = nil
        end
        cleanupAntiBlobman()
    end
end

AntisTab:Toggle({
    Title = "Anti Blobman",
    Value = false,
    Callback = function(state)
        ToggleAntiBlobman(state)
    end
})

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
    Value = false,
    Callback = function(state)
        ToggleAntiVoid(state)
    end
})

local antiExplosionActive = false
local antiExplosionConn = nil
local antiExplosionHeartbeat = nil

local function onExplosionPartAdded(part)
    if not antiExplosionActive then return end
    if not part:IsA("BasePart") or part.Name ~= "Part" then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local distance = (part.Position - hrp.Position).Magnitude
    if distance > 20 then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hrp.Anchored = true
        task.wait(0.02)
        if not hum.SeatPart then hum.Sit = false end
        for _, limb in ipairs(getCharacterParts(char)) do
            limb.CanCollide = false
        end
        zeroVelocity(hrp)
        hrp.Anchored = false
    end
end

local function ToggleAntiExplosion(state)
    antiExplosionActive = state

    if state then
        if antiExplosionConn then antiExplosionConn:Disconnect() end
        antiExplosionConn = Workspace.ChildAdded:Connect(onExplosionPartAdded)
    else
        if antiExplosionConn then
            antiExplosionConn:Disconnect()
            antiExplosionConn = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Explosion",
    Value = false,
    Callback = function(state)
        ToggleAntiExplosion(state)
    end
})

local antiKickActive = false
local antiKickTask = nil
local antiKickShuriken = nil
local antiKickHighlight = nil

local function getPCLD(player)
    if not player then return nil end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "PlayerCharacterLocationDetector" and obj:IsA("BasePart") then
            local attribute = obj:GetAttribute("CurrentlyAssignedTo")
            if attribute == player.Name then
                return obj
            end
        end
    end
    return nil
end

local function createShuriken(targetPart)
    if not targetPart then return nil end
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    local spawnRemote = menuToys and menuToys:FindFirstChild("SpawnToyRemoteFunction")
    if not spawnRemote then return nil end

    local cframe = targetPart.CFrame + Vector3.new(0, 15, 0)
    local success, shuriken = pcall(function()
        return spawnRemote:InvokeServer("NinjaShuriken", cframe, Vector3.zero)
    end)

    if not success or not shuriken or not shuriken:IsA("Model") then
        return nil
    end

    local stickyPart = shuriken:WaitForChild("StickyPart", 1.5)
    local stickyWeld = stickyPart and stickyPart:WaitForChild("StickyWeld", 1.5)
    if not stickyPart or not stickyWeld then
        shuriken:Destroy()
        return nil
    end

    local grabEvent = ReplicatedStorage:FindFirstChild("PlayerEvents")
    grabEvent = grabEvent and grabEvent:FindFirstChild("StickyPartEvent")
    if grabEvent then
        pcall(function()
            grabEvent:FireServer(stickyPart, targetPart, CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(90), 0, 0))
        end)
    end

    return shuriken, stickyPart, stickyWeld
end

local function onAntiKickHeartbeat()
    if not antiKickActive then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    local hitbox = hrp:FindFirstChild("RagdollTouchedHitbox")
    if not hitbox then return end

    if antiKickShuriken and antiKickShuriken.Parent then
        local stickyWeld = antiKickShuriken:FindFirstChild("StickyPart")
        stickyWeld = stickyWeld and stickyWeld:FindFirstChild("StickyWeld")
        if stickyWeld and stickyWeld.Part1 == hitbox then
            return
        end
        antiKickShuriken:Destroy()
        antiKickShuriken = nil
    end

    local pcl = getPCLD(LocalPlayer)
    local targetPart = pcl or hrp

    local shuriken, stickyPart, stickyWeld = createShuriken(targetPart)
    if shuriken and stickyWeld and stickyWeld.Part1 == hitbox then
        antiKickShuriken = shuriken
        antiKickShuriken.Name = "ShurikenRSC"

        local highlight = Instance.new("Highlight")
        highlight.Name = "ShurHighlight"
        highlight.Adornee = shuriken
        highlight.Parent = shuriken
        highlight.FillColor = Color3.new(1, 0, 0)
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        antiKickHighlight = highlight

        for _, child in ipairs(shuriken:GetChildren()) do
            if child:IsA("BasePart") then
                child.CanCollide = false
                child.CanQuery = false
                child.Transparency = 0.9
            end
        end
    elseif shuriken then
        shuriken:Destroy()
    end
end

local function ToggleAntiKick(state)
    antiKickActive = state

    if state then
        if antiKickTask then return end
        antiKickTask = task.spawn(function()
            while antiKickActive do
                onAntiKickHeartbeat()
                task.wait(0.03)
            end
        end)
    else
        if antiKickTask then
            task.cancel(antiKickTask)
            antiKickTask = nil
        end
        if antiKickShuriken then
            antiKickShuriken:Destroy()
            antiKickShuriken = nil
        end
        if antiKickHighlight then
            antiKickHighlight:Destroy()
            antiKickHighlight = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Kick",
    Value = false,
    Callback = function(state)
        ToggleAntiKick(state)
    end
})

local antiSnowballActive = false
local antiSnowballConn = nil

local function onSnowballHit(child)
    if not antiSnowballActive then return end
    if not child:IsA("BasePart") or child.Name ~= "SnowRagdollPart" then return end

    local char = LocalPlayer.Character
    if not char then return end

    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
end

local function ToggleAntiSnowball(state)
    antiSnowballActive = state

    if state then
        if antiSnowballConn then antiSnowballConn:Disconnect() end
        antiSnowballConn = Workspace.DescendantAdded:Connect(onSnowballHit)
    else
        if antiSnowballConn then
            antiSnowballConn:Disconnect()
            antiSnowballConn = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Snowball",
    Value = false,
    Callback = function(state)
        ToggleAntiSnowball(state)
    end
})

local antiBananaActive = false
local antiBananaTask = nil

local function onAntiBananaHeartbeat()
    if not antiBananaActive then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    local rightLeg = char:FindFirstChild("Right Leg")
    if not rightLeg then return end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "HitboxPart" and obj:IsA("BasePart") then
            local banana = obj.Parent
            if banana and banana.Name == "FoodBanana" then
                local main = banana:FindFirstChild("Main")
                if main and (main.Position - rightLeg.Position).Magnitude < 5 then
                    main.CFrame = CFrame.new(0, -1000, 0)
                    banana:Destroy()
                end
            end
        end
    end
end

local function ToggleAntiBanana(state)
    antiBananaActive = state

    if state then
        if antiBananaTask then return end
        antiBananaTask = task.spawn(function()
            while antiBananaActive do
                onAntiBananaHeartbeat()
                task.wait(0.1)
            end
        end)
    else
        if antiBananaTask then
            task.cancel(antiBananaTask)
            antiBananaTask = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Banana",
    Value = false,
    Callback = function(state)
        ToggleAntiBanana(state)
    end
})

local antiPaintActive = false
local antiPaintConn = nil

local function disablePaintPart(part)
    if not antiPaintActive then return end
    if part:IsA("BasePart") and part.Name == "PaintPlayerPart" then
        part.CanTouch = false
    end
end

local function ToggleAntiPaint(state)
    antiPaintActive = state

    if state then
        for _, part in ipairs(Workspace:GetDescendants()) do
            disablePaintPart(part)
        end

        if antiPaintConn then antiPaintConn:Disconnect() end
        antiPaintConn = Workspace.DescendantAdded:Connect(disablePaintPart)
    else
        if antiPaintConn then
            antiPaintConn:Disconnect()
            antiPaintConn = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Paint",
    Value = false,
    Callback = function(state)
        ToggleAntiPaint(state)
    end
})

local antiPoisonActive = false
local antiPoisonConn = nil

local function disablePoisonPart(part)
    if not antiPoisonActive then return end
    if part:IsA("BasePart") and (part.Name == "PoisonHurtPart" or part.Name == "PaintPlayerPart") then
        part.CanTouch = false
    end
end

local function ToggleAntiPoison(state)
    antiPoisonActive = state

    if state then
        local hole = Workspace:FindFirstChild("Map")
        hole = hole and hole:FindFirstChild("Hole")
        if hole then
            local poisonBig = hole:FindFirstChild("PoisonBigHole")
            local poisonSmall = hole:FindFirstChild("PoisonSmallHole")
            if poisonBig then disablePoisonPart(poisonBig) end
            if poisonSmall then disablePoisonPart(poisonSmall) end
        end

        if antiPoisonConn then antiPoisonConn:Disconnect() end
        antiPoisonConn = Workspace.DescendantAdded:Connect(disablePoisonPart)
    else
        if antiPoisonConn then
            antiPoisonConn:Disconnect()
            antiPoisonConn = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Poison",
    Value = false,
    Callback = function(state)
        ToggleAntiPoison(state)
    end
})

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if antiFireActive then ToggleAntiFire(false) end
    if antiLagActive then ToggleAntiLag(false) end
    if antiGrabActive then ToggleAntiGrab(false) end
    if antiBlobmanActive then ToggleAntiBlobman(false) end
    if antiVoidActive then ToggleAntiVoid(false) end
    if antiExplosionActive then ToggleAntiExplosion(false) end
    if antiKickActive then ToggleAntiKick(false) end
    if antiSnowballActive then ToggleAntiSnowball(false) end
    if antiBananaActive then ToggleAntiBanana(false) end
    if antiPaintActive then ToggleAntiPaint(false) end
    if antiPoisonActive then ToggleAntiPoison(false) end
    oldDisable()
end
