local WindUI = undeitedhub.WindUI
local AntisTab = undeitedhub.Window:Tab({ Title = "Antis" })

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local AGType = "Normal"

local antiFireActive = false
local antiLagActive = false
local antiGrabActive = false
local antiGrabEscaping = false
local antiGrabTeleportState = nil
local antiBlobmanActive = false
local antiVoidActive = false
local antiExplosionActive = false
local antiKickActive = false
local antiSnowballActive = false
local antiBananaActive = false
local antiPaintActive = false
local antiPoisonActive = false

local isHeld = LocalPlayer:FindFirstChild("IsHeld") or LocalPlayer:WaitForChild("IsHeld", 5)

local function findRemote(folder, name)
    if not folder then return nil end
    return folder:FindFirstChild(name)
end

local CharacterEvents = ReplicatedStorage:FindFirstChild("CharacterEvents")
local GrabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")
local PlayerEvents = ReplicatedStorage:FindFirstChild("PlayerEvents")
local MenuToys = ReplicatedStorage:FindFirstChild("MenuToys")

local Struggle = findRemote(CharacterEvents, "Struggle")
local RagdollRemote = findRemote(CharacterEvents, "RagdollRemote")
local SetNetworkOwner = findRemote(GrabEvents, "SetNetworkOwner")
local DestroyGrabLine = findRemote(GrabEvents, "DestroyGrabLine")
local StickyPartEvent = findRemote(PlayerEvents, "StickyPartEvent")
local SpawnToyRemote = findRemote(MenuToys, "SpawnToyRemoteFunction")
local DestroyToyRemote = findRemote(MenuToys, "DestroyToy")

local function GetChar(player)
    player = player or LocalPlayer
    if not player then return end
    local char = player.Character
    if not char or not char.Parent then return end
    local hrp = char:FindFirstChild("realHrp") or char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

local function ResetVelocity(part)
    if not part or not part:IsA("BasePart") then return end
    pcall(function()
        if part.AssemblyAngularVelocity ~= Vector3.zero then
            part.AssemblyAngularVelocity = Vector3.zero
        end
        if part.AssemblyLinearVelocity ~= Vector3.zero then
            part.AssemblyLinearVelocity = Vector3.zero
        end
        part.Velocity = Vector3.zero
        part.RotVelocity = Vector3.zero
    end)
end

local function Teleport(part, cframe, offset, reset)
    if not part or not part:IsA("BasePart") or not cframe then return false end
    local char = LocalPlayer.Character
    local isChar = char and part:IsDescendantOf(char)

    if typeof(cframe) == "CFrame" then
        if offset then cframe = cframe * offset end
    elseif typeof(cframe) == "Vector3" then
        if offset then cframe = cframe + offset.Position end
        cframe = CFrame.new(cframe)
    else
        return false
    end

    if isChar and (part.Name == "HumanoidRootPart" or part.Name == "Torso") and antiGrabEscaping then
        antiGrabTeleportState = cframe
    end

    if part.CFrame ~= cframe then part.CFrame = cframe end
    if reset ~= false then ResetVelocity(part) end
    return true
end

local LightPhysicalProperties = PhysicalProperties.new(0.01, 0.01, 0.01, 0.01, 0.01)

local function ToggleCollisions(char, canCollide, noRagdoll, lightPhys)
    if canCollide == nil then canCollide = false end
    local lp = lightPhys and LightPhysicalProperties or nil
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("BasePart") then
            local shouldCollide
            if canCollide then
                shouldCollide = child.Name == "Torso" or child.Name == "Head"
            else
                shouldCollide = false
            end
            if shouldCollide then
                if child.CanCollide ~= canCollide then child.CanCollide = canCollide end
            elseif not canCollide then
                if child.CanCollide ~= canCollide then child.CanCollide = canCollide end
                if not noRagdoll then
                    local rl = child:FindFirstChild("RagdollLimbPart")
                    if rl and rl.CanCollide then rl.CanCollide = false end
                end
            end
            if child.Name ~= "HumanoidRootPart" and child.CustomPhysicalProperties ~= lp then
                child.CustomPhysicalProperties = lp
            end
        end
    end
end

local LimbOffsets = {
    Head = CFrame.new(0, 1.5, 0),
    ["Left Arm"] = CFrame.new(-1.5, 0, 0),
    ["Right Arm"] = CFrame.new(1.5, 0, 0),
    ["Left Leg"] = CFrame.new(-0.5, -2, 0),
    ["Right Leg"] = CFrame.new(0.5, -2, 0),
    Torso = CFrame.new(),
}

local function RepositionLimbs(char, reset)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local torso = char:FindFirstChild("Torso")
    if not hrp or not torso then return end
    local neck = torso:FindFirstChild("Neck")
    if neck and neck.Enabled then return end
    local lv = hrp.CFrame.LookVector
    local v = Vector3.new(lv.X, 0, lv.Z)
    if v.Magnitude < 0.001 then return end
    local cframe = CFrame.lookAt(hrp.Position, hrp.Position + v.Unit)
    for k, off in pairs(LimbOffsets) do
        local p = char:FindFirstChild(k)
        if p and p:IsA("BasePart") then
            local cf = cframe * off
            if p.CFrame ~= cf then p.CFrame = cf end
            if reset then ResetVelocity(p) end
        end
    end
end

local function SNO(part, timeout, condition)
    local char, hrp, hum = GetChar()
    local head = char and char:FindFirstChild("Head")
    local ragdolled = hum and hum:FindFirstChild("Ragdolled")
    if not (head and ragdolled and hrp and hum and hum.Health > 0) then return false end
    if not part or not part:IsA("BasePart") or not part.Parent then return false end
    if not SetNetworkOwner then return false end

    local root = part.AssemblyRootPart or part
    if not root.Anchored and root.ReceiveAge == 0 then return true end

    timeout = timeout or 0.65
    local deadline = tick() + timeout
    local cf = CFrame.new(hrp.CFrame * CFrame.new(0, 1.593, 0).Position, part.Position)

    while tick() < deadline do
        if not part.Parent then return false end
        SetNetworkOwner:FireServer(part, cf)
        local r = part.AssemblyRootPart or part
        if not r.Anchored and r.ReceiveAge == 0 then return true end
        RunService.Heartbeat:Wait()
    end
    local r = part.AssemblyRootPart or part
    return not r.Anchored and r.ReceiveAge == 0
end

local function RNO(part)
    if DestroyGrabLine then DestroyGrabLine:FireServer(part) end
end

local function Grab(part, customCFrame)
    local char, hrp, hum = GetChar()
    if not hrp or not hum or hum.Health == 0 then return end
    if not part or not part.Parent or not part:IsA("BasePart") then return end
    local origin = (customCFrame or hrp.CFrame) * CFrame.new(0, 1.593, 0)
    local lookAt = CFrame.new(origin.Position, part.Position)
    if SetNetworkOwner then SetNetworkOwner:FireServer(part, lookAt) end
end

local function IsNetworkOwner(part)
    if not part or not part:IsA("BasePart") then return false end
    local root = part.AssemblyRootPart or part
    return not root.Anchored and root.ReceiveAge == 0
end

local function BreakLimb(player, mode)
    local isLocal = player == LocalPlayer
    local char, hrp, hum = GetChar(player)
    local ragdolled = hum and hum:FindFirstChild("Ragdolled")
    if not (hrp and hum and hum.Health > 0 and ragdolled) then return end

    local children = char:GetChildren()
    local hasLimb = false
    for _, child in ipairs(children) do
        if child:IsA("BasePart") then
            if (child.Name:find("Arm") and (mode == "Arms" or mode == "All"))
                or (child.Name:find("Leg") and (mode == "Legs" or mode == "All")) then
                hasLimb = true
                break
            end
        end
    end
    if not hasLimb then return end

    if isLocal and RagdollRemote then
        RagdollRemote:FireServer(hrp, 0.35)
        local deadline = tick() + 0.5
        while tick() < deadline and not ragdolled.Value do task.wait() end
    end

    if not ragdolled.Value then return end

    for _, child in ipairs(children) do
        if child:IsA("BasePart") then
            if (child.Name:find("Arm") and (mode == "Arms" or mode == "All"))
                or (child.Name:find("Leg") and (mode == "Legs" or mode == "All")) then
                Teleport(child, CFrame.new(0, -100000, 0))
            end
        end
    end

    task.wait(0.15)
    if not hrp.Parent then return end

    if isLocal then
        Grab(hrp)
        task.wait()
        for _, part in ipairs(children) do
            if part.Parent then ResetVelocity(part) end
        end
        if RagdollRemote then RagdollRemote:FireServer(hrp, 0) end
    end
end

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
    ResetVelocity(part)
end

local antiFireConnections = {}
local antiFireTask = nil
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
        if isFireInstance(obj) then neutralizeFire(obj) end
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
        pcall(buildFireBarrier)
        pcall(startFireWatchers)
        antiFireTask = task.spawn(function()
            while antiFireActive do
                if hkFirePart then
                    local char = LocalPlayer.Character
                    if char then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            pcall(function() hkFirePart.CFrame = hrp.CFrame end)
                        end
                    end
                end
                task.wait(0.05)
            end
            if hkFirePart then hkFirePart.CFrame = CFrame.new(0, -15, 0) end
        end)
    else
        if antiFireTask then
            task.cancel(antiFireTask)
            antiFireTask = nil
        end
        if hkFirePart then hkFirePart.CFrame = CFrame.new(0, -15, 0) end
        stopFireWatchers()
    end
end

AntisTab:Toggle({
    Title = "Anti Fire",
    Value = false,
    Callback = function(state) ToggleAntiFire(state) end,
})

local ShurikenLagWelds = setmetatable({}, { __mode = "k" })
local antiShurikenLagConn = nil

local function IsOutsideVoid(part)
    if not part or not part:IsA("BasePart") then return false end
    local pos = part.Position
    local N = 2147483648
    local T = 1e9
    return math.abs(math.abs(pos.X) - N) > T and math.abs(math.abs(pos.Z) - N) > T
end

local function ClearShurikenLagWeld(weld, restore)
    local data = ShurikenLagWelds[weld]
    if not data then return end
    for _, conn in ipairs(data.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    ShurikenLagWelds[weld] = nil
    if restore and not weld.Parent and data.Parent and data.Parent.Parent then
        weld.Parent = data.Parent
    end
end

local function HandleShurikenLagWeld(weld)
    if not antiLagActive or not weld:IsA("WeldConstraint") or weld.Name ~= "StickyWeld" then return end
    if ShurikenLagWelds[weld] then return end
    local data = { Parent = weld.Parent, Connections = {} }
    ShurikenLagWelds[weld] = data
    local function check()
        if not weld.Part0 or not weld.Part1 then return end
        local outside = IsOutsideVoid(weld.Part0) and IsOutsideVoid(weld.Part1)
        if not outside then
            if weld.Parent then
                data.Parent = weld.Parent
                weld.Parent = nil
            end
        elseif not weld.Parent and data.Parent and data.Parent.Parent then
            weld.Parent = data.Parent
        end
    end
    table.insert(data.Connections, weld:GetPropertyChangedSignal("Enabled"):Connect(check))
    table.insert(data.Connections, weld:GetPropertyChangedSignal("Part0"):Connect(check))
    table.insert(data.Connections, weld:GetPropertyChangedSignal("Part1"):Connect(check))
    table.insert(data.Connections, weld.Destroying:Connect(function()
        ClearShurikenLagWeld(weld, false)
    end))
    check()
end

local function SetAntiShurikenLag(state)
    if antiShurikenLagConn then
        antiShurikenLagConn:Disconnect()
        antiShurikenLagConn = nil
    end
    if state then
        antiShurikenLagConn = Workspace.DescendantAdded:Connect(HandleShurikenLagWeld)
        for _, weld in ipairs(Workspace:QueryDescendants("WeldConstraint#StickyWeld")) do
            HandleShurikenLagWeld(weld)
        end
    else
        local snapshot = {}
        for weld in pairs(ShurikenLagWelds) do
            table.insert(snapshot, weld)
        end
        for _, weld in ipairs(snapshot) do
            ClearShurikenLagWeld(weld, true)
        end
    end
end

local function ApplyAntiLag(state)
    local scriptsEnabled = not state
    pcall(function()
        LocalPlayer.PlayerScripts.CharacterAndBeamMove.Enabled = scriptsEnabled
    end)
    pcall(function()
        LocalPlayer.PlayerScripts.StickyPartsTouchDetection.Enabled = scriptsEnabled
    end)
    SetAntiShurikenLag(state)
    if state then
        task.delay(1.5, function()
            if not antiLagActive then return end
            for _, plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character
                if char then
                    for _, child in ipairs(char:GetChildren()) do
                        if child.Name == "GrabParts" then
                            pcall(function() child:Destroy() end)
                        end
                    end
                end
            end
        end)
    end
end

local function ToggleAntiLag(state)
    antiLagActive = state
    ApplyAntiLag(state)
end

AntisTab:Toggle({
    Title = "Anti Lag",
    Value = false,
    Callback = function(state) ToggleAntiLag(state) end,
})

local function runAntiGrab()
    if not isHeld then return end
    if not isHeld.Value or not antiGrabActive or antiGrabEscaping then return end

    if Struggle then Struggle:FireServer() end

    local char, hrp, hum = GetChar()
    local torso = char and char:FindFirstChild("Torso")
    local neck = torso and torso:FindFirstChild("Neck")
    if not (hum and torso) then return end

    hum.RequiresNeck = false
    hum.AutoRotate = false
    ResetVelocity(hrp or torso)

    local position = torso.Position
    local lv = torso.CFrame.LookVector
    local unit = Vector3.new(lv.X, 0, lv.Z).Unit

    antiGrabEscaping = true

    local isEscapesAnything = AGType == "Escapes Anything, but buggy"
    local isAntiKill = AGType == "Anti-Kill"
    local isNoRagdoll = AGType == "No Ragdoll"

    local function extraEscape()
        local c, h = GetChar()
        if not h or not hum or hum.Health == 0 then return end
        local tractor = SpawnToyRemote and SpawnToyRemote:InvokeServer("TractorGreen", Workspace.Waypoints.TudorHouse.CFrame, Vector3.zero)
        if not tractor then return end
        local vehicleSeat = tractor:WaitForChild("VehicleSeat", 1)
        if not vehicleSeat then
            DestroyToyRemote:FireServer(tractor)
            return
        end
        local done = false
        hum.Sit = false
        vehicleSeat:Sit(hum)
        local conn = vehicleSeat.ChildAdded:Connect(function(child)
            if child.Name == "SeatWeld" then
                child.Enabled = false
                done = true
                child:Destroy()
            end
        end)
        local start = tick()
        while not done and tick() - start < 0.7 do RunService.Heartbeat:Wait() end
        conn:Disconnect()
        hum.Sit = false
        if DestroyToyRemote then DestroyToyRemote:FireServer(tractor) end
    end

    if isEscapesAnything then task.spawn(extraEscape) end

    local lastExtraEscape = tick()
    local lastStruggle = tick()
    local lastRagdoll = 0
    local connection

    connection = RunService.RenderStepped:Connect(function(dt)
        local now = tick()
        if now - lastStruggle >= 0.0333 then
            if Struggle then Struggle:FireServer() end
            lastStruggle = now
        end
        if hrp and not isEscapesAnything and not isNoRagdoll and now - lastRagdoll >= 0.0333 then
            if RagdollRemote then
                RagdollRemote:FireServer(hrp, isAntiKill and 0.11 or 0)
            end
            lastRagdoll = now
        end
        if isEscapesAnything and now - lastExtraEscape > 2 then
            task.spawn(extraEscape)
            lastExtraEscape = now
        end

        local moveDir = hum.MoveDirection
        local walkSpeed = 16
        if moveDir.Magnitude > 0 then
            position = position + moveDir * walkSpeed * dt
        end
        if (workspace.CurrentCamera.CFrame.Position - workspace.CurrentCamera.Focus.Position).Magnitude < 1 then
            moveDir = workspace.CurrentCamera.CFrame.LookVector
        end
        local flat = Vector3.new(moveDir.X, 0, moveDir.Z)
        if flat.Magnitude > 0 then
            unit = unit:Lerp(flat.Unit, math.min(dt * 12, 1)).Unit
        end

        ResetVelocity(hrp or torso)

        if antiGrabTeleportState then
            position = antiGrabTeleportState.Position
            torso.CFrame = antiGrabTeleportState
            antiGrabTeleportState = nil
        else
            torso.CFrame = CFrame.lookAt(position, position + unit)
        end

        hum.Sit = isAntiKill

        if not neck or not neck.Enabled then
            ToggleCollisions(char, false)
            RepositionLimbs(char, true)
        end

        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
            if track.Animation and track.Animation.AnimationId == "rbxassetid://7047322890" then
                track:Stop()
            end
        end

        if hrp and hrp:FindFirstChild("Scream") then
            hrp.Scream.Playing = false
        end

        if not isHeld.Value or not antiGrabActive then
            antiGrabEscaping = false
            if isAntiKill then
                task.delay(0.1, function()
                    if not hum.SeatPart then
                        hum.Sit = false
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end)
            end
            hum.AutoRotate = true
            connection:Disconnect()
        end
    end)
end

if isHeld then
    isHeld:GetPropertyChangedSignal("Value"):Connect(runAntiGrab)
end

local function ToggleAntiGrab(state)
    antiGrabActive = state
    if not state then
        antiGrabEscaping = false
        antiGrabTeleportState = nil
    end
end

AntisTab:Toggle({
    Title = "Anti Grab",
    Value = false,
    Callback = function(state) ToggleAntiGrab(state) end,
})

pcall(function()
    AntisTab:Dropdown({
        Title = "Anti Grab Type",
        Values = { "Normal", "No Ragdoll", "Anti-Kill", "Escapes Anything, but buggy" },
        Value = "Normal",
        Callback = function(v) AGType = v end,
    })
end)

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
        if antiBlobmanFakeValue.Parent then antiBlobmanFakeValue:Destroy() end
        antiBlobmanFakeValue = nil
    end
    antiBlobmanCharacter = nil
end

local function runAntiBlobman()
    while antiBlobmanActive do
        local char, hrp, hum = GetChar()
        if not char or not hrp or not hum or hum.Health <= 0 then
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
                if not antiBlobmanActive then break end
                if not found.Parent then task.wait() continue end
                antiBlobmanRootAttachment = found
                found.Parent = ReplicatedStorage
                antiBlobmanFakeValue = Instance.new("BoolValue")
                antiBlobmanFakeValue.Name = "RootAttachment"
                antiBlobmanFakeValue.Parent = hrp
            end
        end
        if hrp.Massless then hrp.Massless = false end
        task.wait()
    end
    cleanupAntiBlobman()
end

local function ToggleAntiBlobman(state)
    antiBlobmanActive = state
    if state then
        if antiBlobmanTask then return end
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
    Callback = function(state) ToggleAntiBlobman(state) end,
})

local antiVoidTask = nil

local function runAntiVoid()
    while antiVoidActive do
        local char, hrp, hum = GetChar()
        if char and hrp and hum and hum.Health > 0 then
            local shouldTp = hrp.Position.Y >= 10000 or hrp.Position.Y <= -500
            if shouldTp then
                local safePlatform = Workspace:FindFirstChild("Safe Platform")
                if safePlatform then
                    shouldTp = (hrp.Position - safePlatform.Position).Magnitude >= 150
                end
            end
            if shouldTp then
                Teleport(hrp, CFrame.new(0, 15, 0))
            end
        end
        task.wait(0.03)
    end
end

local function ToggleAntiVoid(state)
    antiVoidActive = state
    if state then
        if antiVoidTask then return end
        antiVoidTask = task.spawn(runAntiVoid)
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
    Callback = function(state) ToggleAntiVoid(state) end,
})

local antiExplosionConn = nil

local function onExplosionPart(part)
    if not antiExplosionActive then return end
    if not part:IsA("BasePart") or part.Name ~= "Part" then return end
    local char, hrp, hum = GetChar()
    if not char or not hrp or not hum then return end
    if (part.Position - hrp.Position).Magnitude > 20 then return end
    hrp.Anchored = true
    task.wait(0.02)
    if not hum.SeatPart then hum.Sit = false end
    for _, v in ipairs(char:QueryDescendants("#RagdollLimbPart")) do
        v.CanCollide = false
    end
    ResetVelocity(hrp)
    hrp.Anchored = false
end

local function ToggleAntiExplosion(state)
    antiExplosionActive = state
    if state then
        if antiExplosionConn then antiExplosionConn:Disconnect() end
        antiExplosionConn = Workspace.ChildAdded:Connect(onExplosionPart)
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
    Callback = function(state) ToggleAntiExplosion(state) end,
})

local antiKickTask = nil
local antiKickShuriken = nil
local antiKickHighlight = nil
local AntiKickSettings = {
    Highlight = false,
    HighlightFill = Color3.new(1, 0, 0),
    HighlightOutl = Color3.new(1, 1, 1),
    HighlightFT = 0.5,
    HighlightOT = 0,
    Transparency = 0.9,
}

local function isWaitingPCLD(part)
    return part and part.Position == Vector3.zero
end

local function findPCLDForLocal()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name == "PlayerCharacterLocationDetector" and obj:IsA("BasePart") then
            local attr = obj:GetAttribute("CurrentlyAssignedTo")
            if attr == LocalPlayer.Name and not isWaitingPCLD(obj) then
                return obj
            end
        end
    end
    return nil
end

local function findPCLDWithTimeout()
    local deadline = os.clock() + 0.35
    repeat
        local pcl = findPCLDForLocal()
        if pcl and pcl.Parent and not isWaitingPCLD(pcl) then return pcl end
        task.wait(0.05)
    until not antiKickActive or os.clock() >= deadline
    return nil
end

local function spawnShurikenAt(targetPart)
    if not targetPart or not targetPart.Parent then return nil end
    if not SpawnToyRemote then return nil end
    
    -- Strip rotation and add +20 Z offset to bypass server distance check
    local hint = CFrame.new(targetPart.Position + Vector3.new(0, 15, 20))
    local rotPart = Workspace:FindFirstChild("RotateOrientPart")
    local rot = rotPart and rotPart.Rotation or Vector3.zero

    local foundToy = nil
    local connections = {}
    
    -- Listen for the new toy in the player's inventory or the plot items
    local function checkModel(child)
        if not foundToy and child.Name == "NinjaShuriken" and child:IsA("Model") then
            foundToy = child
        end
    end

    local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if inv then
        table.insert(connections, inv.ChildAdded:Connect(checkModel))
    end
    
    local plotItems = Workspace:FindFirstChild("PlotItems")
    if plotItems then
        table.insert(connections, plotItems.DescendantAdded:Connect(function(desc)
            if desc:IsA("Model") and desc.Name == "NinjaShuriken" then
                checkModel(desc)
            end
        end))
    end

    -- Fire the remote in the background (don't rely on its return value)
    task.spawn(function()
        pcall(function()
            SpawnToyRemote:InvokeServer("NinjaShuriken", hint, rot)
        end)
    end)

    -- Wait for the toy to appear in the workspace
    local timeout = tick() + 1.5
    while tick() < timeout and not foundToy do
        RunService.Heartbeat:Wait()
        if not antiKickActive then break end
    end

    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end

    if not foundToy or not foundToy.Parent then return nil end
    local shuriken = foundToy

    local stickyPart = shuriken:WaitForChild("StickyPart", 1.5)
    local stickyWeld = stickyPart and stickyPart:WaitForChild("StickyWeld", 1.5)
    if not stickyPart or not stickyWeld then
        pcall(function() shuriken:Destroy() end)
        return nil
    end
    if not SNO(stickyPart) then
        pcall(function() shuriken:Destroy() end)
        return nil
    end
    return shuriken, stickyPart, stickyWeld
end

local function applyShurikenVisuals(shuriken)
    if not shuriken or not shuriken.Parent then return end
    local highlight = shuriken:FindFirstChild("ShurHighlight")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "ShurHighlight"
        highlight.Adornee = shuriken
        highlight.Parent = shuriken
    end
    highlight.FillColor = AntiKickSettings.HighlightFill
    highlight.OutlineColor = AntiKickSettings.HighlightOutl
    highlight.FillTransparency = AntiKickSettings.HighlightFT
    highlight.OutlineTransparency = AntiKickSettings.HighlightOT
    highlight.Enabled = AntiKickSettings.Highlight
    antiKickHighlight = highlight
    for _, child in ipairs(shuriken:GetChildren()) do
        if child:IsA("BasePart") then
            if child.CanCollide then child.CanCollide = false end
            if child.CanQuery then child.CanQuery = false end
            if child.Transparency ~= AntiKickSettings.Transparency and (child:IsA("MeshPart") or child.Name == "Part") then
                child.Transparency = AntiKickSettings.Transparency
            end
        end
    end
end

local function destroyAntiKickShuriken()
    if antiKickShuriken and antiKickShuriken.Parent then
        pcall(function() antiKickShuriken:Destroy() end)
    end
    antiKickShuriken = nil
    if antiKickHighlight and antiKickHighlight.Parent then
        pcall(function() antiKickHighlight:Destroy() end)
    end
    antiKickHighlight = nil
end

local function antiKickStep()
    if not antiKickActive then return end
    local char, hrp, hum = GetChar()
    if not hrp or not hum or hum.Health <= 0 then return end
    local hitbox = hrp:FindFirstChild("RagdollTouchedHitbox")
    if not hitbox then return end

    local inPlot = LocalPlayer:FindFirstChild("InPlot")
    local inOwnedPlot = LocalPlayer:FindFirstChild("InOwnedPlot")
    if inPlot and inPlot.Value and inOwnedPlot and not inOwnedPlot.Value then
        while antiKickActive and inPlot.Value and not inOwnedPlot.Value do task.wait(0.1) end
        if not antiKickActive then return end
    end

    if antiKickShuriken then
        if antiKickShuriken.Parent and antiKickShuriken.Name == "ShurikenRSC" then
            local sp = antiKickShuriken:FindFirstChild("StickyPart")
            local sw = sp and sp:FindFirstChild("StickyWeld")
            if sw and sw.Part1 == hitbox then
                applyShurikenVisuals(antiKickShuriken)
                return
            end
        end
        destroyAntiKickShuriken()
    end

    local shuriken, stickyPart, stickyWeld = spawnShurikenAt(findPCLDWithTimeout())
    if not shuriken then shuriken, stickyPart, stickyWeld = spawnShurikenAt(hrp) end
    if not shuriken then return end

    shuriken.Name = "ShurikenRSC"
    antiKickShuriken = shuriken

    task.spawn(function()
        local touchInterest = stickyPart:WaitForChild("TouchInterest", 2.5)
        if touchInterest then touchInterest:Destroy() end
    end)

    if StickyPartEvent then
        pcall(function()
            StickyPartEvent:FireServer(stickyPart, hitbox, CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(90), 0, 0))
        end)
    end

    local deadline = tick() + 0.5
    local welded = false
    while antiKickActive and tick() < deadline do
        if stickyWeld.Part1 == hitbox then welded = true break end
        if not stickyWeld.Parent or not hitbox.Parent then break end
        if not hum or not hum.Parent or hum.Health <= 0 then break end
        RunService.Heartbeat:Wait()
    end

    if not antiKickActive or not shuriken.Parent or not welded or not stickyWeld.Parent or stickyWeld.Part1 ~= hitbox then
        destroyAntiKickShuriken()
        return
    end

    applyShurikenVisuals(shuriken)
end

local function ToggleAntiKick(state)
    antiKickActive = state
    if state then
        if antiKickTask then return end
        antiKickTask = task.spawn(function()
            while antiKickActive do
                antiKickStep()
                task.wait(0.03)
            end
        end)
    else
        if antiKickTask then
            task.cancel(antiKickTask)
            antiKickTask = nil
        end
        destroyAntiKickShuriken()
    end
end

AntisTab:Toggle({
    Title = "Anti Kick",
    Value = false,
    Callback = function(state) ToggleAntiKick(state) end,
})

local antiSnowballTask = nil

local function runAntiSnowball()
    task.wait(0.5)
    while antiSnowballActive do
        task.wait(0.03)
        if not antiSnowballActive then return end

        if antiBananaActive then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Right Leg") then
                while antiSnowballActive do
                    task.wait()
                    local c = LocalPlayer.Character
                    if c and c:FindFirstChild("Right Leg") then continue end
                    break
                end
                if not antiSnowballActive then return end
            end
        end

        local char, hrp, hum = GetChar()
        local weldHRP = char and char:FindFirstChild("WeldHRP")
        if weldHRP and hrp and hum and hum.Health > 0 then
            if RagdollRemote then RagdollRemote:FireServer(hrp, 0.5) end
            if not hum.SeatPart then hum.Sit = false end
            hum.AutoRotate = true
            if weldHRP.Enabled then
                pcall(function() ContextActionService:UnbindAction("JumpRemover") end)
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                RepositionLimbs(char)
                ToggleCollisions(char, false, false, true)
            end
        end
    end
end

local function ToggleAntiSnowball(state)
    antiSnowballActive = state
    if state then
        if antiSnowballTask then return end
        antiSnowballTask = task.spawn(runAntiSnowball)
    else
        if antiSnowballTask then
            task.cancel(antiSnowballTask)
            antiSnowballTask = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Snowball",
    Value = false,
    Callback = function(state) ToggleAntiSnowball(state) end,
})

local antiBananaTask = nil

local function runAntiBanana()
    task.wait(2)
    while antiBananaActive do
        task.wait(0.03)
        if not antiBananaActive then return end
        local char, hrp, hum = GetChar()
        local rightLeg = char and char:FindFirstChild("Right Leg")
        if rightLeg and hrp and hum and hum.Health > 0 and IsNetworkOwner(hrp) then
            hum.Sit = false
            hum.HipHeight = 2
            BreakLimb(LocalPlayer, "Legs")
            local conn = nil
            conn = hum:GetPropertyChangedSignal("HipHeight"):Connect(function()
                if not antiBananaActive then
                    if conn then conn:Disconnect() end
                    return
                end
                hum.HipHeight = 2
            end)
            local start = tick()
            while antiBananaActive and tick() - start < 0.75 do
                if not rightLeg.Parent or hum.Health == 0 then break end
                task.wait()
            end
            if conn then conn:Disconnect() end
        elseif hum and hum.Health == 0 then
            LocalPlayer.CharacterAdded:Wait()
            task.wait(0.5)
        end
    end
end

local function ToggleAntiBanana(state)
    antiBananaActive = state
    if state then
        if antiBananaTask then return end
        antiBananaTask = task.spawn(runAntiBanana)
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
    Callback = function(state) ToggleAntiBanana(state) end,
})

local antiPaintConn = nil
local paintConnections = {}

local function handlePaintPart(part)
    if not antiPaintActive then return end
    if not part:IsA("BasePart") or part.Name ~= "PaintPlayerPart" then return end
    part.CanTouch = false
    if paintConnections[part] then
        paintConnections[part]:Disconnect()
    end
    paintConnections[part] = part:GetPropertyChangedSignal("CanTouch"):Connect(function()
        if not antiPaintActive then return end
        if part.CanTouch then part.CanTouch = false end
    end)
end

local function ToggleAntiPaint(state)
    antiPaintActive = state
    if state then
        for _, part in ipairs(Workspace:QueryDescendants("BasePart#PaintPlayerPart")) do
            handlePaintPart(part)
        end
        if antiPaintConn then antiPaintConn:Disconnect() end
        antiPaintConn = Workspace.DescendantAdded:Connect(handlePaintPart)
    else
        if antiPaintConn then
            antiPaintConn:Disconnect()
            antiPaintConn = nil
        end
        for part, conn in pairs(paintConnections) do
            pcall(function() conn:Disconnect() end)
            paintConnections[part] = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Paint",
    Value = false,
    Callback = function(state) ToggleAntiPaint(state) end,
})

local function ToggleAntiPoison(state)
    local map = Workspace:FindFirstChild("Map")
    local hole = map and map:FindFirstChild("Hole")
    local poisonBig = hole and hole:FindFirstChild("PoisonBigHole")
    local poisonSmall = hole and hole:FindFirstChild("PoisonSmallHole")
    for _, v in ipairs({ poisonBig, poisonSmall }) do
        if v then
            local poisonHurt = v:FindFirstChild("PoisonHurtPart")
            local paintPlayer = v:FindFirstChild("PaintPlayerPart")
            if poisonHurt then poisonHurt.CanTouch = not state end
            if paintPlayer then paintPlayer.CanTouch = not state end
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Poison",
    Value = false,
    Callback = function(state) ToggleAntiPoison(state) end,
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
    oldDisable()
end
