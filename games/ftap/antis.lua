local WindUI = undeltedhub.WindUI
local config = undeltedhub.Config
local Toggles = undeltedhub.Toggles

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

local AntisTab = undeltedhub.Window:Tab({ Title = "Antis" })

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local R = ReplicatedStorage

local function waitFor(parent, name, recursive, timeout)
    timeout = timeout or 10
    local start = tick()
    local result
    while not result and tick() - start < timeout do
        result = recursive and parent:FindFirstChild(name, true) or parent:FindFirstChild(name)
        if not result then task.wait(0.1) end
    end
    return result
end

local function sno(part)
    if not part or not part.Parent then return end
    pcall(function()
        local grabEvents = R:FindFirstChild("GrabEvents")
        local setOwner = grabEvents and grabEvents:FindFirstChild("SetNetworkOwner")
        if setOwner then setOwner:FireServer(part, part.CFrame) end
    end)
end

local antiGrabV1Active = false
local antiGrabV1Task = nil
AntisTab:Toggle({
    Title = "Anti Grab V1",
    Value = Toggles.antiGrabV1 or false,
    Callback = function(state)
        antiGrabV1Active = state
        Toggles.antiGrabV1 = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            antiGrabV1Task = task.spawn(function()
                while antiGrabV1Active do
                    pcall(function()
                        local isHeld = LocalPlayer:FindFirstChild("IsHeld")
                        if isHeld and isHeld.Value then
                            local char = LocalPlayer.Character
                            if char then
                                local hum = char:FindFirstChild("Humanoid")
                                local hrp = char:FindFirstChild("HumanoidRootPart")
                                if hum and hrp then
                                    R.CharacterEvents.Struggle:FireServer(LocalPlayer)
                                    R.CharacterEvents.RagdollRemote:FireServer(hrp, 0.00000000001)
                                    if hum.Sit then hum.Sit = false end
                                end
                            end
                        end
                    end)
                    task.wait(0.05)
                end
            end)
        else
            if antiGrabV1Task then task.cancel(antiGrabV1Task); antiGrabV1Task = nil end
        end
    end
})

local antiGrabV2Active = false
local antiGrabV2Task = nil
AntisTab:Toggle({
    Title = "Anti Grab V2 (Ocarina)",
    Value = Toggles.antiGrabV2 or false,
    Callback = function(state)
        antiGrabV2Active = state
        Toggles.antiGrabV2 = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            antiGrabV2Task = task.spawn(function()
                local hkAGSt = nil
                local hkAGModel = nil
                local hkPlot = nil
                while antiGrabV2Active do
                    pcall(function()
                        local plr = LocalPlayer
                        for _, home in pairs(Workspace.Plots:GetChildren()) do
                            local sign = home:FindFirstChild("PlotSign")
                            if sign then
                                for _, person in pairs(sign:GetChildren()) do
                                    if person.Name == "ThisPlotsOwners" then
                                        for _, owner in pairs(person:GetChildren()) do
                                            if owner.Value == plr.Name then hkPlot = home.Name end
                                        end
                                    end
                                    if person.Name == "Sign" and person:IsA("BasePart") then
                                        local gui = person:FindFirstChild("Screen") and person.Screen:FindFirstChild("SurfaceGui")
                                        if gui and gui.Frame.Visible and gui.Frame.PlayerDisplayName.Text == plr.DisplayName then
                                            hkPlot = home.Name
                                        end
                                    end
                                end
                            end
                        end

                        local toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                        hkAGModel = toysFolder and toysFolder:FindFirstChild("InstrumentWoodwindOcarina")
                        if not hkAGModel and hkPlot then
                            local plotItems = Workspace:FindFirstChild("PlotItems")
                            if plotItems then
                                local plotFolder = plotItems:FindFirstChild(hkPlot)
                                if plotFolder then
                                    hkAGModel = plotFolder:FindFirstChild("InstrumentWoodwindOcarina")
                                end
                            end
                        end

                        if hkAGModel then
                            if plr.Character then
                                for _, part in pairs(plr.Character:GetChildren()) do
                                    if part:FindFirstChild("PartOwner") and part.PartOwner.Value ~= "" then
                                        if hkAGModel:FindFirstChild("HoldPart") and hkAGModel.HoldPart:FindFirstChild("HoldItemRemoteFunction") then
                                            task.spawn(function()
                                                hkAGModel.HoldPart.HoldItemRemoteFunction:InvokeServer(hkAGModel, plr.Character)
                                            end)
                                            R.MenuToys.DestroyToy:FireServer(hkAGModel)
                                            if plr.Character:FindFirstChild("Humanoid") then
                                                plr.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                                                plr.Character.Humanoid.AutoRotate = true
                                            end
                                            part.PartOwner.Value = ""
                                            if plr.Character.Humanoid.Sit then plr.Character.Humanoid.Sit = false end
                                        end
                                    end
                                end
                            end
                        else
                            if plr.Character and plr:FindFirstChild("CanSpawnToy") and plr.CanSpawnToy.Value and not hkAGSt then
                                hkAGSt = tick()
                                task.spawn(function()
                                    R.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                                        "InstrumentWoodwindOcarina",
                                        CFrame.new(1e5, 1e5, 1e5),
                                        Vector3.new(0,0,0)
                                    )
                                end)
                            elseif hkAGSt and tick() - hkAGSt > 1 then
                                hkAGSt = nil
                            end
                        end

                        local grabbed = false
                        if plr.Character then
                            for _, part in pairs(plr.Character:GetChildren()) do
                                if part:FindFirstChild("PartOwner") and part.PartOwner.Value ~= "" then grabbed = true end
                            end
                        end
                        if grabbed then
                            R.CharacterEvents.Struggle:FireServer(plr)
                            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                                R.CharacterEvents.RagdollRemote:FireServer(plr.Character.HumanoidRootPart, 0.00000000001)
                            end
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        else
            if antiGrabV2Task then task.cancel(antiGrabV2Task); antiGrabV2Task = nil end
        end
    end
})

local gucciActive = false
local gucciTask = nil
local checkGucciSeatTask = nil
local gucciRunId = 0

local function toy_spawn_gucci(name, cframe, vector)
    local ToySpawn = R.MenuToys.SpawnToyRemoteFunction
    local InPlot = LocalPlayer:FindFirstChild("InPlot")
    local InOwnedPlot = LocalPlayer:FindFirstChild("InOwnedPlot")
    local CanSpawn = LocalPlayer:FindFirstChild("CanSpawnToy")
    while InPlot and InPlot.Value and not InOwnedPlot.Value and not CanSpawn.Value do
        task.wait(0.01)
    end
    task.spawn(function()
        ToySpawn:InvokeServer(name, cframe, vector or Vector3.new())
    end)
    local BackPack = Workspace:FindFirstChild(LocalPlayer.Name .. 'SpawnedInToys')
    local SpawnedToy
    BackPack.ChildAdded:Once(function(toy)
        if toy.Name == name and toy:IsA("Model") then SpawnedToy = toy end
    end)
    local time = tick()
    while not SpawnedToy do
        if tick() - time < 2 then task.wait(0.01) else return false end
    end
    return SpawnedToy
end

local function GucciAntiGrab()
    if not gucciActive then return end
    gucciRunId = gucciRunId + 1
    local MyId = gucciRunId
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")
    hum.Sit = true
    task.wait(0.02)
    hum.Sit = false
    task.wait(0.02)

    task.spawn(function()
        local time = tick()
        while tick() - time < 0.8 do
            for _, v in pairs(char:GetChildren()) do
                if v:IsA('BasePart') then v.Velocity = Vector3.new() end
            end
            task.wait(0.01)
        end
    end)

    local autoGucciT = true
    local sitJumpT = false
    local Blob, BHead
    task.spawn(function()
        while not Blob and MyId == gucciRunId do task.wait(0.01) end
        if MyId ~= gucciRunId then return end
        BHead = Blob:FindFirstChild("Head")
        local HitBox = Blob:FindFirstChild("GrabbableHitbox")
        while MyId == gucciRunId and BHead and (not BHead:FindFirstChild("PartOwner") or BHead.PartOwner.Value ~= LocalPlayer.Name) do
            if HitBox then
                R.GrabEvents.SetNetworkOwner:FireServer(HitBox, HitBox.CFrame)
            end
            task.wait(0.01)
        end
    end)

    local hrp = char:WaitForChild("HumanoidRootPart")
    Blob = toy_spawn_gucci("CreatureBlobman", hrp.CFrame * CFrame.new(0,0,-5), Vector3.new(0,-15.716,0))
    if not Blob then return end
    local Seat = Blob:FindFirstChild("VehicleSeat")

    task.defer(function()
        if not char or not hum then return end
        local startTime = tick()
        while autoGucciT and MyId == gucciRunId and tick() - startTime < 0.3 do
            if Blob and Blob.Parent then
                if Seat and Seat.Parent and Seat.Occupant ~= hum then
                    Seat:Sit(hum)
                end
            end
            task.wait(0.03)
            if char and hum and hum.Parent then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            task.wait(0.03)
        end
        autoGucciT = false
        sitJumpT = false
    end)

    sitJumpT = true
    task.defer(function()
        while sitJumpT and MyId == gucciRunId do
            if char and hrp and hrp.Parent then
                R.CharacterEvents.RagdollRemote:FireServer(hrp, 0.095)
            end
            task.wait(0.01)
        end
    end)

    task.wait(0.4)
    if MyId ~= gucciRunId then return end
    hum.Sit = false
    Blob.Name = "Gucci"
    local BackPack = Workspace:FindFirstChild(LocalPlayer.Name .. 'SpawnedInToys')
    local index
    for i, v in pairs(BackPack:GetChildren()) do
        if v.Name == "Gucci" then index = i; break end
    end
    for _, v in pairs(Blob:GetChildren()) do
        if v:IsA("BasePart") then v.CanCollide = false; v.CanTouch = false; v.CanQuery = false end
    end
    task.defer(function()
        while MyId == gucciRunId and Blob and BHead do
            BHead.CFrame = CFrame.new(BHead.Position.X, 1e5, BHead.Position.Z)
            task.wait(0.01)
        end
    end)
end

AntisTab:Toggle({
    Title = "Gucci Anti Grab",
    Value = Toggles.gucciAntiGrab or false,
    Callback = function(state)
        gucciActive = state
        Toggles.gucciAntiGrab = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if gucciTask then task.cancel(gucciTask); gucciTask = nil end
        if checkGucciSeatTask then task.cancel(checkGucciSeatTask); checkGucciSeatTask = nil end

        if not state then
            local BackPack = Workspace:FindFirstChild(LocalPlayer.Name .. 'SpawnedInToys')
            if BackPack then
                for _, v in pairs(BackPack:GetChildren()) do
                    if v.Name == "Gucci" or v.Name == "CreatureBlobman" then
                        pcall(function() R.MenuToys.DestroyToy:FireServer(v) end)
                    end
                end
            end
            return
        end

        gucciTask = task.spawn(function()
            while gucciActive do
                local BackPack = Workspace:FindFirstChild(LocalPlayer.Name .. 'SpawnedInToys')
                local gucci = BackPack and BackPack:FindFirstChild("Gucci")
                if not gucci then
                    GucciAntiGrab()
                end
                task.wait(0.5)
            end
        end)

        checkGucciSeatTask = task.spawn(function()
            while gucciActive do
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChild("Humanoid")
                if hum and hum.SeatPart then
                    local seatParent = hum.SeatPart.Parent
                    if seatParent and (seatParent.Name == "Gucci" or seatParent.Name == "CreatureBlobman") then
                        local isOurGucci = false
                        local BackPack = Workspace:FindFirstChild(LocalPlayer.Name .. 'SpawnedInToys')
                        if BackPack then
                            for _, v in pairs(BackPack:GetChildren()) do
                                if v == seatParent then isOurGucci = true; break end
                            end
                        end
                        if isOurGucci then
                            pcall(function() R.MenuToys.DestroyToy:FireServer(seatParent) end)
                            task.wait(0.2)
                            if gucciActive then GucciAntiGrab() end
                        end
                    end
                end
                task.wait(0.3)
            end
        end)
    end
})

local antiOwnershipActive = false
local antiOwnershipTask = nil
AntisTab:Toggle({
    Title = "Anti Ownership",
    Value = Toggles.antiOwnership or false,
    Callback = function(state)
        antiOwnershipActive = state
        Toggles.antiOwnership = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            antiOwnershipTask = task.spawn(function()
                local Struggle = R.CharacterEvents.Struggle
                while antiOwnershipActive do
                    pcall(function()
                        local character = LocalPlayer.Character
                        if character and character:FindFirstChild("Head") then
                            local head = character.Head
                            if head:FindFirstChild("PartOwner") then
                                Struggle:FireServer(LocalPlayer)
                                for _, part in pairs(character:GetChildren()) do
                                    if part:IsA("BasePart") then part.Anchored = true end
                                end
                                local isHeld = LocalPlayer:FindFirstChild("IsHeld")
                                while isHeld and isHeld.Value and antiOwnershipActive do task.wait() end
                                for _, part in pairs(character:GetChildren()) do
                                    if part:IsA("BasePart") then part.Anchored = false end
                                end
                            end
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        else
            if antiOwnershipTask then task.cancel(antiOwnershipTask); antiOwnershipTask = nil end
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetChildren()) do
                    if part:IsA("BasePart") then part.Anchored = false end
                end
            end
        end
    end
})

local paintPartsBackup = {}
local paintConnections = {}
AntisTab:Toggle({
    Title = "Anti Paint",
    Value = Toggles.antiPaint or false,
    Callback = function(state)
        if state then
            pcall(function()
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then
                        local clone = obj:Clone()
                        clone.Archivable = true
                        paintPartsBackup[obj:GetDebugId()] = {clone = clone, parent = obj.Parent}
                        obj:Destroy()
                    end
                end
            end)
            table.insert(paintConnections, Workspace.DescendantAdded:Connect(function(obj)
                if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then
                    task.defer(function()
                        if obj and obj.Parent then
                            local clone = obj:Clone()
                            clone.Archivable = true
                            paintPartsBackup[obj:GetDebugId()] = {clone = clone, parent = obj.Parent}
                            obj:Destroy()
                        end
                    end)
                end
            end))
            local char = Workspace:FindFirstChild(LocalPlayer.Name)
            if char then
                for _, v in pairs(char:GetChildren()) do
                    if v:IsA("Part") or v:IsA("BasePart") then
                        v.CanTouch = false; v.CanQuery = false
                    end
                end
            end
        else
            for _, data in pairs(paintPartsBackup) do
                if data.clone and data.parent then
                    data.clone.Parent = data.parent
                end
            end
            paintPartsBackup = {}
            for _, conn in ipairs(paintConnections) do
                if conn.Connected then conn:Disconnect() end
            end
            paintConnections = {}
            local char = Workspace:FindFirstChild(LocalPlayer.Name)
            if char then
                for _, v in pairs(char:GetChildren()) do
                    if v:IsA("Part") or v:IsA("BasePart") then
                        v.CanTouch = true; v.CanQuery = true
                    end
                end
            end
        end
        Toggles.antiPaint = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    end
})

local antiFireActive = false
local antiFireTask = nil
local hkFirePart = nil
AntisTab:Toggle({
    Title = "Anti Fire",
    Value = Toggles.antiFire or false,
    Callback = function(state)
        antiFireActive = state
        Toggles.antiFire = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            pcall(function()
                if Workspace.Plots and Workspace.Plots.Plot5 and Workspace.Plots.Plot5.Barrier then
                    local barrier = Workspace.Plots.Plot5.Barrier
                    if barrier:FindFirstChild("AntiFirePart") then
                        hkFirePart = barrier.AntiFirePart
                    else
                        hkFirePart = barrier:FindFirstChild("PlotBarrier")
                    end
                    if hkFirePart then
                        hkFirePart.CanCollide = true
                        hkFirePart.CanQuery = true
                        hkFirePart.Name = "AntiFirePart"
                        local h2 = hkFirePart:Clone()
                        h2.Name = "FalseBorder"
                        h2.Parent = hkFirePart.Parent
                        hkFirePart.Size = Vector3.new(1,1,1)
                        for _, prt in pairs(hkFirePart:GetChildren()) do prt:Destroy() end
                        hkFirePart.CanQuery = false
                        hkFirePart.CanCollide = false
                    end
                end
            end)
            antiFireTask = task.spawn(function()
                while antiFireActive do
                    pcall(function()
                        if hkFirePart then
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                hkFirePart.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame
                            end
                            hkFirePart.CanCollide = not hkFirePart.CanCollide
                            hkFirePart.CanCollide = not hkFirePart.CanCollide
                        end
                    end)
                    task.wait()
                end
                if hkFirePart then hkFirePart.CFrame = CFrame.new(0, -15, 0) end
            end)
        else
            if antiFireTask then task.cancel(antiFireTask); antiFireTask = nil end
            if hkFirePart then hkFirePart.CFrame = CFrame.new(0, -15, 0) end
        end
    end
})

local antiExplosionActive = false
local antiExplosionConnection = nil
AntisTab:Toggle({
    Title = "Anti Explosion",
    Value = Toggles.antiExplosion or false,
    Callback = function(state)
        antiExplosionActive = state
        Toggles.antiExplosion = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:WaitForChild("HumanoidRootPart")
            antiExplosionConnection = Workspace.ChildAdded:Connect(function(model)
                if model.Name == "Part" and antiExplosionActive then
                    pcall(function()
                        if (model.Position - hrp.Position).Magnitude <= 20 then
                            hrp.Anchored = true
                            task.wait(0.01)
                            local rightArm = char:FindFirstChild("Right Arm")
                            if rightArm then
                                local ragdollPart = rightArm:FindFirstChild("RagdollLimbPart")
                                if ragdollPart then
                                    while ragdollPart.CanCollide and antiExplosionActive do task.wait(0.001) end
                                end
                            end
                            if antiExplosionActive then hrp.Anchored = false end
                        end
                    end)
                end
            end)
        else
            if antiExplosionConnection then antiExplosionConnection:Disconnect(); antiExplosionConnection = nil end
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Anchored = false end
            end
        end
    end
})

local antiVoidActive = false
local antiVoidConnection = nil
local function StartAntiVoid()
    local VOID_THRESHOLD = -50
    local SAFE_HEIGHT = 100
    antiVoidConnection = RunService.Heartbeat:Connect(function()
        if not antiVoidActive then return end
        local char = LocalPlayer.Character
        if char and char.PrimaryPart then
            local pos = char.PrimaryPart.Position
            if pos.Y < VOID_THRESHOLD then
                local safePos = Vector3.new(pos.X, pos.Y + SAFE_HEIGHT, pos.Z)
                char:SetPrimaryPartCFrame(CFrame.new(safePos))
                char.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end)
end
AntisTab:Toggle({
    Title = "Anti Void",
    Value = Toggles.antiVoid or false,
    Callback = function(state)
        antiVoidActive = state
        Toggles.antiVoid = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
        if state then
            StartAntiVoid()
        else
            if antiVoidConnection then antiVoidConnection:Disconnect(); antiVoidConnection = nil end
        end
    end
})

local hkABlob = false
AntisTab:Toggle({
    Title = "Anti Blob",
    Value = Toggles.antiBlob or false,
    Callback = function(state)
        hkABlob = state
        Toggles.antiBlob = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
        task.spawn(function()
            while hkABlob do
                if LocalPlayer.Character then
                    if not LocalPlayer.Character:FindFirstChild("TruePositionPart") then
                        local tp = Instance.new("Part")
                        tp.Parent = LocalPlayer.Character
                        tp.Name = "TruePositionPart"
                        tp.Anchored = true
                        tp.CFrame = CFrame.new(0, -100, 0)
                    end
                    for _, prt in pairs(LocalPlayer.Character:GetChildren()) do
                        if prt:IsA("BasePart") and prt.Massless then prt.Massless = false end
                        if prt.Name == "HumanoidRootPart" and LocalPlayer.Character.HumanoidRootPart:FindFirstChild("RootAttachment") then
                            task.wait()
                            task.wait()
                            task.wait()
                            task.wait()
                            task.wait()
                            task.wait()
                            task.wait()
                            task.wait()
                            task.wait()
                            task.wait()
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and
                                LocalPlayer.Character.HumanoidRootPart:FindFirstChild("RootAttachment") and
                                LocalPlayer.Character:FindFirstChild("TruePositionPart") then
                                LocalPlayer.Character.HumanoidRootPart.RootAttachment.Parent = LocalPlayer.Character.TruePositionPart
                            end
                        end
                    end
                end
                task.wait()
            end
        end)
        if not state and LocalPlayer.Character then
            if LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character:FindFirstChild("TruePositionPart") then
                if LocalPlayer.Character.TruePositionPart:FindFirstChild("RootAttachment") then
                    LocalPlayer.Character.TruePositionPart.RootAttachment.Parent = LocalPlayer.Character.HumanoidRootPart
                end
            end
        end
    end
})

local antiSnowballActive = false
local antiSnowballTask = nil
AntisTab:Toggle({
    Title = "Anti Snowball",
    Value = Toggles.antiSnowball or false,
    Callback = function(state)
        antiSnowballActive = state
        Toggles.antiSnowball = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
        if state then
            antiSnowballTask = task.spawn(function()
                while antiSnowballActive do
                    pcall(function()
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            R.CharacterEvents.RagdollRemote:FireServer(hrp, 0.5)
                        end
                    end)
                    task.wait(0.05)
                end
            end)
        else
            if antiSnowballTask then task.cancel(antiSnowballTask); antiSnowballTask = nil end
        end
    end
})

local AntiRagBlob = false
local RagdolledSit = false
local ARCons = {}
local function ApplyAntiRagdoll(char)
    if not char or not AntiRagBlob then return end
    local hum = char:WaitForChild("Humanoid", 5)
    local HRP = char:WaitForChild("HumanoidRootPart", 5)
    if not hum or not HRP then return end

    if ARCons.ARSeat then ARCons.ARSeat:Disconnect() end
    ARCons.ARSeat = hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
        if hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" and not RagdolledSit then
            RagdolledSit = true
            local Seat = hum.SeatPart
            while not hum.Sit do task.wait() end
            R.CharacterEvents.RagdollRemote:FireServer(HRP, 3)
            local ragdolledVal = hum:FindFirstChild("Ragdolled")
            while ragdolledVal and not ragdolledVal.Value and not hum.Sit do task.wait() end
            task.wait(0.4)
            hum.Sit = false
            Seat:Sit(hum)
            task.delay(0.25, function()
                while hum and hum.SeatPart do
                    R.CharacterEvents.RagdollRemote:FireServer(HRP, 1)
                    task.wait(0.05)
                end
                RagdolledSit = false
            end)
        end
    end)
end
AntisTab:Toggle({
    Title = "Anti Ragdoll (on Blob)",
    Value = Toggles.antiRagdollBlob or false,
    Callback = function(state)
        AntiRagBlob = state
        Toggles.antiRagdollBlob = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
        RagdolledSit = false
        if ARCons.ARChar then ARCons.ARChar:Disconnect() end
        if ARCons.ARSeat then ARCons.ARSeat:Disconnect() end
        if state then
            ApplyAntiRagdoll(LocalPlayer.Character)
            ARCons.ARChar = LocalPlayer.CharacterAdded:Connect(ApplyAntiRagdoll)
        end
    end
})

local ocnAntiLagOn = false
AntisTab:Toggle({
    Title = "Anti Lag",
    Value = Toggles.antiLag or false,
    Callback = function(state)
        ocnAntiLagOn = state
        Toggles.antiLag = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
        if state then
            pcall(function()
                if LocalPlayer.PlayerScripts and LocalPlayer.PlayerScripts:FindFirstChild("CharacterAndBeamMove") then
                    LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = true
                end
                for _, plr in pairs(Players:GetPlayers()) do
                    if plr.Character and plr.Character:FindFirstChild("GrabParts") then
                        plr.Character.GrabParts:Destroy()
                    end
                end
            end)
        else
            pcall(function()
                if LocalPlayer.PlayerScripts and LocalPlayer.PlayerScripts:FindFirstChild("CharacterAndBeamMove") then
                    LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = false
                end
            end)
        end
    end
})

AntisTab:Toggle({
    Title = "Oat Anti-Kick",
    Value = Toggles.oatAntiKick or false,
    Callback = function(state)
        Toggles.oatAntiKick = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
        local hkExpectDeath = false
        local hkSalmonList = {}
        hkSalmonList[LocalPlayer.UserId] = true

        local function hkApplySalmon(char)
            if not char then return end
            local newHum = char:WaitForChild("Humanoid", 5)
            if not newHum then return end
            if hkSalmonList[LocalPlayer.UserId] and not hkExpectDeath then
                hkExpectDeath = true
                newHum:ChangeState(Enum.HumanoidStateType.Dead)
            else
                hkExpectDeath = false
            end
        end

        LocalPlayer.CharacterAdded:Connect(function(char) hkApplySalmon(char) end)
        hkSalmonList[LocalPlayer.UserId] = state and true or nil
        if state then
            hkExpectDeath = false
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 end
        end
    end
})

AntisTab:Button({
    Title = "Delete Legs",
    Callback = function()
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            if char:FindFirstChild("Left Leg") and char:FindFirstChild("Right Leg") then
                local ll = char:FindFirstChild("Left Leg")
                local rl = char:FindFirstChild("Right Leg")
                local void = Workspace.FallenPartsDestroyHeight
                local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                if not torso then return end
                local pos = torso.CFrame
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                if not hrp or not hum then return end
                Workspace.FallenPartsDestroyHeight = -100
                R.CharacterEvents.RagdollRemote:FireServer(hrp, 2)
                task.wait(0.5)
                rl.CFrame = CFrame.new(0, -10000, 0)
                ll.CFrame = CFrame.new(0, -10000, 0)
                task.wait(0.3)
                torso.CFrame = CFrame.new(0, -9970, 0)
                task.wait(0.5)
                torso.CFrame = pos
                task.wait(0.5)
                Workspace.FallenPartsDestroyHeight = void
                task.spawn(function()
                    if not char:FindFirstChild("Left Leg") and not char:FindFirstChild("Right Leg") then
                        while char and char.Parent and hum and hum.Health > 0 do
                            pcall(function()
                                local controls = LocalPlayer.PlayerGui:FindFirstChild("ControlsGui")
                                if controls and controls:FindFirstChild("PCFrame") and controls.PCFrame:FindFirstChild("Stand") then
                                    if controls.PCFrame.Stand.Visible == false then
                                        hum.HipHeight = 2
                                    else
                                        hum.HipHeight = 0
                                    end
                                end
                            end)
                            task.wait()
                        end
                    end
                end)
            end
        end)
    end
})

local shurikenAntiKickActive = false
local shurikenAntiKickTask = nil
local shurikenCharFixConnection = nil
local shurikenRespawnConnection = nil
local ShurikenToyList = {
    ["Shuriken"] = "NinjaShuriken",
    ["Pickaxe"] = "ToolPickaxe",
    ["Kunai"] = "NinjaKunai",
    ["Cleaver"] = "ToolCleaver",
}
local ShurikenDropdownValues = {}
for shortName in pairs(ShurikenToyList) do table.insert(ShurikenDropdownValues, shortName) end
table.sort(ShurikenDropdownValues)
local SelectedShurikenToy = ShurikenToyList["Shuriken"]
AntisTab:Dropdown({
    Title = "Select Anti Kick Toy",
    Values = ShurikenDropdownValues,
    Value = "Shuriken",
    Callback = function(value)
        SelectedShurikenToy = ShurikenToyList[value]
    end
})

local function fixShurikenCharacter(char)
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hum and hrp then
        hum.AutoRotate = true; hum.Sit = false
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CanCollide = true; hrp.CanTouch = true; hrp.CanQuery = true
        for _, part in pairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = true; part.CanTouch = true; part.CanQuery = true
                part.Velocity = Vector3.zero
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end
end

local function ClearKunai()
    local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    local destroyrem = R.MenuToys and R.MenuToys:FindFirstChild("DestroyToy")
    if inv and destroyrem then
        for _, v in pairs(inv:GetChildren()) do
            if v.Name == "AntiKick" or v.Name == SelectedShurikenToy then
                pcall(function() destroyrem:FireServer(v) end)
            end
        end
    end
end

AntisTab:Toggle({
    Title = "Shuriken Anti Kick",
    Value = Toggles.shurikenAntiKick or false,
    Callback = function(state)
        shurikenAntiKickActive = state
        Toggles.shurikenAntiKick = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            fixShurikenCharacter(LocalPlayer.Character)
            if shurikenCharFixConnection then shurikenCharFixConnection:Disconnect() end
            shurikenCharFixConnection = LocalPlayer.CharacterAdded:Connect(function(char)
                task.wait(0.5); fixShurikenCharacter(char)
            end)
            if shurikenRespawnConnection then shurikenRespawnConnection:Disconnect() end
            shurikenRespawnConnection = LocalPlayer.CharacterAdded:Connect(function()
                task.wait(1)
                if shurikenAntiKickActive then ClearKunai() end
            end)

            shurikenAntiKickTask = task.spawn(function()
                local plr = LocalPlayer
                local setOwner = R.GrabEvents.SetNetworkOwner
                local stickyEvent = R.PlayerEvents.StickyPartEvent
                local spawnRemote = R.MenuToys.SpawnToyRemoteFunction
                local destroyrem = R.MenuToys.DestroyToy
                local canSpawn = plr:WaitForChild("CanSpawnToy")

                local function getHRP()
                    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                        return plr.Character.HumanoidRootPart
                    else
                        local character = plr.CharacterAdded:Wait()
                        return character:WaitForChild("HumanoidRootPart")
                    end
                end

                local function CheckForHome()
                    if not Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then return false end
                    for _, plot in pairs(Workspace.Plots:GetChildren()) do
                        local sign = plot:FindFirstChild("PlotSign")
                        local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                        if owners then
                            for _, owner in pairs(owners:GetChildren()) do
                                if owner.Value == plr.Name then
                                    local folder = Workspace.PlotItems:FindFirstChild(plot.Name)
                                    if folder then return true, folder end
                                end
                            end
                        end
                    end
                    return false
                end

                local function StickKunai(kunai)
                    if not kunai or not kunai:FindFirstChild("StickyPart") then return end
                    local currentHRP = getHRP()
                    if not currentHRP then return end
                    if kunai:FindFirstChild("SoundPart") then
                        if not kunai.SoundPart:FindFirstChild("PartOwner") or kunai.SoundPart.PartOwner.Value ~= plr.Name then
                            setOwner:FireServer(kunai.SoundPart, kunai.SoundPart.CFrame)
                        end
                    end
                    local firePart = currentHRP:FindFirstChild("FirePlayerPart") or currentHRP:WaitForChild("FirePlayerPart", 5)
                    if firePart then
                        stickyEvent:FireServer(kunai.StickyPart, firePart, CFrame.new(0,0,0) * CFrame.Angles(0, math.rad(90), math.rad(90)))
                    end
                    for _, obj in pairs(kunai:GetChildren()) do
                        if obj:IsA("BasePart") then
                            obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false; obj.Transparency = 0.8
                        end
                    end
                    if kunai:FindFirstChild("Handle") then
                        local handle = kunai.Handle
                        if not handle:FindFirstChild("Highlight") then
                            local high = Instance.new("Highlight", handle)
                            high.FillColor = Color3.fromRGB(0,255,255)
                        end
                    end
                end

                local function SpawnToy(name)
                    local t = tick()
                    while not canSpawn.Value do
                        if not shurikenAntiKickActive or tick() - t > 5 then return nil end
                        task.wait(0.1)
                    end
                    local currentHRP = getHRP()
                    if currentHRP then
                        task.spawn(function()
                            pcall(function()
                                spawnRemote:InvokeServer(name, currentHRP.CFrame * CFrame.new(0,12,20), Vector3.new(0,0,0))
                            end)
                        end)
                    end
                    local boolik, house = CheckForHome()
                    local inv = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    if boolik and house then
                        return house:WaitForChild(name, 2)
                    elseif not Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) and inv then
                        return inv:WaitForChild(name, 2)
                    end
                    return nil
                end

                while shurikenAntiKickActive do
                    task.wait(0.005)
                    if not plr.Character or not plr.Character:FindFirstChild("Humanoid") or plr.Character.Humanoid.Health <= 0 then
                        task.wait(0.5); ClearKunai(); return
                    end
                    local inv = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    local kunai = inv and inv:FindFirstChild(SelectedShurikenToy)

                    if Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                        local boolik, house = CheckForHome()
                        if boolik and house and Workspace.Plots:FindFirstChild(house.Name) then
                            local sign = Workspace.Plots[house.Name]:FindFirstChild("PlotSign")
                            if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                                kunai = SpawnToy(SelectedShurikenToy)
                                if kunai == nil then return end
                                kunai.Name = "AntiKick"
                                StickKunai(kunai)
                            end
                        end
                    end

                    if not kunai then
                        if Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then return end
                        kunai = SpawnToy(SelectedShurikenToy)
                        if kunai == nil then return end
                        kunai.Name = "AntiKick"
                        if not kunai then return end
                    end

                    repeat
                        if kunai and kunai:FindFirstChild("StickyPart") and kunai.StickyPart.CanTouch == true then
                            StickKunai(kunai)
                            kunai.Name = "AntiKick"
                        end
                        task.wait(0.3)
                    until not kunai or not shurikenAntiKickActive or not kunai:FindFirstChild("StickyPart") or kunai.StickyPart.CanTouch == false
                        or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart")
                        or not kunai:FindFirstChild("StickyPart")
                        or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20

                    if not kunai or not kunai:FindFirstChild("StickyPart") or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20 then
                        ClearKunai()
                    end

                    pcall(function()
                        repeat
                            task.wait(0.05)
                        until not shurikenAntiKickActive or not plr.Character or not plr.Character:FindFirstChild("Humanoid") or not kunai or not kunai:FindFirstChild("StickyPart") or not kunai.StickyPart:FindFirstChild("StickyWeld") or not kunai.StickyPart.StickyWeld.Part1
                        if not kunai or not kunai:FindFirstChild("StickyPart") or (plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health <= 0) or not kunai.StickyPart:FindFirstChild("StickyWeld").Part1 then
                            ClearKunai()
                        end
                    end)
                end
                ClearKunai()
            end)
        else
            shurikenAntiKickActive = false
            if shurikenAntiKickTask then task.cancel(shurikenAntiKickTask); shurikenAntiKickTask = nil end
            if shurikenCharFixConnection then shurikenCharFixConnection:Disconnect(); shurikenCharFixConnection = nil end
            if shurikenRespawnConnection then shurikenRespawnConnection:Disconnect(); shurikenRespawnConnection = nil end
            fixShurikenCharacter(LocalPlayer.Character)
            ClearKunai()
        end
    end
})

local pencilAntiKickActive = false
local pencilAntiKickTask = nil
local pencilRespawnConnection = nil

local function spawnPencil()
    local spawnFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if not spawnFolder then return end
    local pencil = spawnFolder:FindFirstChild("ToolPencil")
    if pencil then return pencil end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            R.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                "ToolPencil",
                CFrame.new(LocalPlayer.Character.HumanoidRootPart.CFrame.Position) + Vector3.new(0,0,15),
                Vector3.new(0,0,0)
            )
        end)
    end
    return nil
end

local function fixPencil()
    pcall(function()
        local playerName = LocalPlayer.Name
        local spawnFolder = Workspace:FindFirstChild(playerName .. "SpawnedInToys")
        if not spawnFolder then return end
        local pencil = spawnFolder:FindFirstChild("ToolPencil")
        if not pencil then
            pencil = spawnPencil()
            if not pencil then return end
        end
        local char = LocalPlayer.Character
        if not char then return end
        local torso = char:FindFirstChild("Torso")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not torso or not root then return end
        local stickyPart = pencil:FindFirstChild("StickyPart")
        local soundPart = pencil:FindFirstChild("SoundPart")
        if stickyPart and stickyPart:FindFirstChild("StickyWeld") then
            local weld = stickyPart.StickyWeld
            if weld.Part1 ~= torso then
                local dist = (soundPart and soundPart.Position or Vector3.zero) - root.Position
                if dist.Magnitude > 20 then
                    pcall(function() R.MenuToys.DestroyToy:FireServer(pencil) end)
                else
                    pcall(function()
                        R.PlayerEvents.StickyPartEvent:FireServer(
                            stickyPart,
                            torso,
                            CFrame.new(0, -1, 0) * CFrame.Angles(0, math.pi, 0)
                        )
                    end)
                end
                for _, prt in pairs(pencil:GetChildren()) do
                    if prt:IsA("BasePart") then
                        prt.CanQuery = false; prt.CanCollide = false; prt.CanTouch = false
                    end
                end
            end
        end
    end)
end

AntisTab:Toggle({
    Title = "Anti Kick (Pencil)",
    Value = Toggles.pencilAntiKick or false,
    Callback = function(state)
        pencilAntiKickActive = state
        Toggles.pencilAntiKick = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            if pencilRespawnConnection then pencilRespawnConnection:Disconnect() end
            pencilRespawnConnection = LocalPlayer.CharacterAdded:Connect(function()
                task.wait(1)
                if pencilAntiKickActive then fixPencil() end
            end)
            pencilAntiKickTask = task.spawn(function()
                while pencilAntiKickActive do
                    fixPencil()
                    task.wait(0.5)
                end
            end)
        else
            pencilAntiKickActive = false
            if pencilAntiKickTask then task.cancel(pencilAntiKickTask); pencilAntiKickTask = nil end
            if pencilRespawnConnection then pencilRespawnConnection:Disconnect(); pencilRespawnConnection = nil end
            local spawnFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            if spawnFolder then
                local pencil = spawnFolder:FindFirstChild("ToolPencil")
                if pencil then pcall(function() R.MenuToys.DestroyToy:FireServer(pencil) end) end
            end
        end
    end
})

local AntiKickItemActive = false
local MyPCLD = nil
local pcldConn = nil
local charFixConnectionItem = nil
local ToyList = {
    ["Japanese Lantern"] = "JapaneseLantern",
    ["Spray Can"] = "SprayCanWD",
    ["Spooky Candle"] = "SpookyCandle1",
}
local ToyDropdownValues = {}
for shortName in pairs(ToyList) do table.insert(ToyDropdownValues, shortName) end
table.sort(ToyDropdownValues)
local SelectedToy = ToyList["Spooky Candle"]
AntisTab:Dropdown({
    Title = "Anti Kick Item",
    Values = ToyDropdownValues,
    Value = "Spooky Candle",
    Callback = function(value)
        SelectedToy = ToyList[value]
    end
})

local function GetMagnitude(Part1, Part2)
    return (Part1.Position - Part2.Position).Magnitude
end

local function FWD(parent, part, timeOffset)
    return parent:FindFirstChild(part) or parent:WaitForChild(part, timeOffset or 1)
end

local function CheckNetworkOwnerOnPart(Part)
    local po = Part:FindFirstChild("PartOwner")
    return po and po.Value == LocalPlayer.Name
end

local function sno2(part)
    pcall(function()
        local grabEvents = R:FindFirstChild("GrabEvents")
        local setNetOwner = grabEvents and grabEvents:FindFirstChild("SetNetworkOwner")
        if setNetOwner then setNetOwner:FireServer(part, part.CFrame) end
    end)
end

local function CheckForHome()
    local plotItems = Workspace:FindFirstChild("PlotItems")
    local plots = Workspace:FindFirstChild("Plots")
    if plots and plotItems then
        for i = 1, 5 do
            local Plot = plots:FindFirstChild("Plot" .. i)
            if Plot then
                local sign = Plot:FindFirstChild("PlotSign")
                local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                if owners then
                    for _, v in pairs(owners:GetChildren()) do
                        if v.Value == LocalPlayer.Name then
                            return plotItems:FindFirstChild("Plot" .. i)
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function SpawnToyItem(ToyName)
    local InPlot = LocalPlayer:FindFirstChild("InPlot")
    local InOwnedPlot = LocalPlayer:FindFirstChild("InOwnedPlot")
    local CanSpawnToy = LocalPlayer:FindFirstChild("CanSpawnToy")
    local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if InPlot and InPlot.Value and InOwnedPlot and not InOwnedPlot.Value then
        InPlot:GetPropertyChangedSignal("Value"):Wait()
    end
    if CanSpawnToy and not CanSpawnToy.Value then
        CanSpawnToy:GetPropertyChangedSignal("Value"):Wait()
    end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local SpawnCF = (MyPCLD or hrp).CFrame * CFrame.new(0,14,20)
    local Container = (InOwnedPlot and InOwnedPlot.Value) and CheckForHome() or inv
    if not Container then return nil end
    local spawnedObject = nil
    local connection
    connection = Container.ChildAdded:Connect(function(child)
        if child.Name == ToyName then spawnedObject = child end
    end)
    task.spawn(function()
        pcall(function()
            local menuToys = R:FindFirstChild("MenuToys")
            local spawnRemote = menuToys and menuToys:FindFirstChild("SpawnToyRemoteFunction")
            if spawnRemote then spawnRemote:InvokeServer(ToyName, SpawnCF, Vector3.zero) end
        end)
    end)
    local start = tick()
    repeat task.wait() until spawnedObject or (tick() - start) > 2.5
    if connection then connection:Disconnect() end
    return spawnedObject
end

local function FindPCLD(hrp)
    if pcldConn then pcldConn:Disconnect() end
    MyPCLD = nil
    pcldConn = RunService.Heartbeat:Connect(function()
        if MyPCLD or not hrp or not hrp.Parent then
            if pcldConn then pcldConn:Disconnect(); pcldConn = nil end
            return
        end
        for _, v in pairs(Workspace:GetChildren()) do
            if v.Name == "PlayerCharacterLocationDetector" and v:IsA("BasePart") then
                if GetMagnitude(v, hrp) <= 2 then
                    MyPCLD = v
                    break
                end
            end
        end
    end)
end

local function fixCharacterItem(char)
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hum and hrp then
        hum.AutoRotate = true; hum.Sit = false
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CanCollide = true; hrp.CanTouch = true; hrp.CanQuery = true
        for _, part in pairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = true; part.CanTouch = true; part.CanQuery = true
                part.Velocity = Vector3.zero
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end
end

AntisTab:Toggle({
    Title = "Anti Kick (Item)",
    Value = Toggles.antiKickItem or false,
    Callback = function(state)
        AntiKickItemActive = state
        Toggles.antiKickItem = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            fixCharacterItem(LocalPlayer.Character)
            if charFixConnectionItem then charFixConnectionItem:Disconnect() end
            charFixConnectionItem = LocalPlayer.CharacterAdded:Connect(function(char)
                task.wait(0.5); fixCharacterItem(char)
            end)

            task.spawn(function()
                local Item, SoundPart
                while AntiKickItemActive and task.wait() do
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChild("Humanoid")
                    local inPlot = LocalPlayer:FindFirstChild("InPlot")
                    local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                    local destroyToy = R.MenuToys and R.MenuToys:FindFirstChild("DestroyToy")

                    if not hrp or not hum or hum.Health <= 0 or not inv then continue end
                    if inPlot and inPlot.Value then continue end

                    if not MyPCLD and not pcldConn then
                        FindPCLD(hrp)
                    end

                    Item = inv:FindFirstChild("AntiKickItem")
                    SoundPart = Item and Item:FindFirstChild("Hitbox")

                    if not Item or not SoundPart then
                        for _, v in pairs(inv:GetChildren()) do
                            if v.Name == "AntiKickItem" then
                                pcall(function() destroyToy:FireServer(v) end)
                            end
                        end
                        Item = SpawnToyItem(SelectedToy)
                        if not Item then continue end
                        SoundPart = Item and FWD(Item, "Hitbox", 0.5)
                        if SoundPart then sno2(SoundPart) end
                        for _, v in pairs(Item:GetChildren()) do
                            if v:IsA("BasePart") then
                                v.CanCollide = false; v.Transparency = 0.8; v.Color = Color3.fromRGB(0,255,255)
                            end
                        end
                        Item.Name = "AntiKickItem"
                    end

                    if SoundPart and not CheckNetworkOwnerOnPart(SoundPart) then
                        sno2(SoundPart)
                    end

                    local targetPart = MyPCLD or hrp:FindFirstChild("FirePlayerPart") or hrp

                    if SoundPart and targetPart then
                        SoundPart.CFrame = targetPart.CFrame
                        SoundPart.AssemblyLinearVelocity = Vector3.zero
                        SoundPart.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end)
        else
            if pcldConn then pcldConn:Disconnect(); pcldConn = nil end
            if charFixConnectionItem then charFixConnectionItem:Disconnect(); charFixConnectionItem = nil end
            MyPCLD = nil
            fixCharacterItem(LocalPlayer.Character)
            task.spawn(function()
                local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                local destroyToy = R.MenuToys and R.MenuToys:FindFirstChild("DestroyToy")
                if inv and destroyToy then
                    for _, v in pairs(inv:GetChildren()) do
                        if v.Name == "AntiKickItem" then
                            pcall(function() destroyToy:FireServer(v) end)
                        end
                    end
                end
            end)
        end
    end
})

local defenseEnabled = false
local defenseConnection = nil
local defenseMode = "Fling"
local crazyline = false
local crazylineTask = nil
local GrabEvents = R:WaitForChild("GrabEvents")
local SetNetworkOwner = GrabEvents:WaitForChild("SetNetworkOwner")
local DestroyGrabLine = GrabEvents:FindFirstChild("DestroyGrabLine")
local CreateGrabEvent = GrabEvents:FindFirstChild("CreateGrabLine")
local Debris2 = game:GetService("Debris")

local function getAttacker()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Head") then return nil end
    local owner = char.Head:FindFirstChild("PartOwner")
    if not owner or not owner:IsA("StringValue") then return nil end
    return Players:FindFirstChild(owner.Value)
end

local function performFling(attacker)
    if not attacker or not attacker.Character then return end
    local root = attacker.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    pcall(function()
        SetNetworkOwner:FireServer(root, root.CFrame)
        if DestroyGrabLine then DestroyGrabLine:FireServer(root) end
        local away = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Unit
        away = Vector3.new(away.X, 0, away.Z) * 90000
        local bv = Instance.new("BodyVelocity")
        bv.Name = "RinneganFling"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = away
        bv.P = 12500
        bv.Parent = root
        Debris2:AddItem(bv, 0.01)
    end)
end

local function performKill(attacker)
    if not attacker or not attacker.Character then return end
    local root = attacker.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    pcall(function()
        SetNetworkOwner:FireServer(root, root.CFrame)
        if DestroyGrabLine then DestroyGrabLine:FireServer(root) end
        local away = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Unit
        away = Vector3.new(away.X, 0, away.Z) * 99999999999999
        local bv = Instance.new("BodyVelocity")
        bv.Name = "RinneganFling"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = away
        bv.P = 12500
        bv.Parent = root
        Debris2:AddItem(bv, 0.01)
    end)
end

local function performHeaven(attacker)
    if not attacker or not attacker.Character then return end
    local root = attacker.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    pcall(function()
        SetNetworkOwner:FireServer(root, root.CFrame)
        if DestroyGrabLine then DestroyGrabLine:FireServer(root) end
        root.CFrame = CFrame.new(0, 200, 0)
        local bv = Instance.new("BodyVelocity")
        bv.Name = "RinneganHeaven"
        bv.MaxForce = Vector3.new(0, math.huge, 0)
        bv.Velocity = Vector3.new(0, 200, 0)
        bv.P = 12500
        bv.Parent = root
        Debris2:AddItem(bv, 0.01)
    end)
end

local function performKick(attacker)
    if not attacker or not attacker.Character then return end
    local root = attacker.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    pcall(function()
        SetNetworkOwner:FireServer(root, root.CFrame)
        if DestroyGrabLine then DestroyGrabLine:FireServer(root) end
        root.CFrame = CFrame.new(0, 999999999999, 0)
        local bv = Instance.new("BodyVelocity")
        bv.Name = "RinneganHeaven"
        bv.MaxForce = Vector3.new(0, math.huge, 0)
        bv.Velocity = Vector3.new(0, 99999999999999, 0)
        bv.P = 12500
        bv.Parent = root
        Debris2:AddItem(bv, 0.01)
    end)
end

local function performRagdoll(attacker)
    if not attacker or not attacker.Character then return end
    local root = attacker.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    pcall(function()
        SetNetworkOwner:FireServer(root, root.CFrame)
        if DestroyGrabLine then DestroyGrabLine:FireServer(root) end
        local bv = Instance.new("BodyVelocity")
        bv.Name = "RinneganSpy"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, -20, 0)
        bv.P = 12500
        bv.Parent = root
        Debris2:AddItem(bv, 0.01)
    end)
end

local function performHell(attacker)
    if not attacker or not attacker.Character then return end
    local root = attacker.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    pcall(function()
        SetNetworkOwner:FireServer(root, root.CFrame)
        if DestroyGrabLine then DestroyGrabLine:FireServer(root) end
        for _, part in ipairs(attacker.Character:GetDescendants()) do
            if part:IsA("BasePart") and not part.Anchored then part.CanCollide = false end
        end
        local bv = Instance.new("BodyVelocity")
        bv.Name = "RinneganSpy"
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, -100000000, 0)
        bv.P = 12500
        bv.Parent = root
        local noclipConnection
        noclipConnection = RunService.Heartbeat:Connect(function()
            if not attacker.Character or not attacker.Character.Parent then
                noclipConnection:Disconnect()
                return
            end
            for _, part in ipairs(attacker.Character:GetDescendants()) do
                if part:IsA("BasePart") and not part.Anchored then part.CanCollide = false end
            end
        end)
        task.delay(0.01, function() if noclipConnection then noclipConnection:Disconnect() end end)
        Debris2:AddItem(bv, 0.01)
    end)
end

local function performChina(attacker)
    if not attacker or not attacker.Character then return end
    local root = attacker.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    pcall(function()
        SetNetworkOwner:FireServer(root, root.CFrame)
        if DestroyGrabLine then DestroyGrabLine:FireServer(root) end
        root.CFrame = CFrame.new(591, 153, -101)
    end)
end

local function performSpamGrabLines(attacker)
    while crazyline do
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local head = char:FindFirstChild("Head")
                if head then
                    local owner = head:FindFirstChild("PartOwner")
                    if owner and owner:IsA("StringValue") then
                        local attacker = Players:FindFirstChild(owner.Value)
                        if attacker and attacker.Character then
                            local attackerHead = attacker.Character:FindFirstChild("Head")
                            local attackerHRP = attacker.Character:FindFirstChild("HumanoidRootPart")
                            if attackerHead and attackerHRP then
                                for i = 1, 10 do
                                    pcall(function() CreateGrabEvent:FireServer(attackerHead, attackerHead.CFrame) end)
                                end
                                for i = 1, 10 do
                                    pcall(function() CreateGrabEvent:FireServer(attackerHRP, attackerHRP.CFrame) end)
                                end
                            end
                        end
                    end
                end
            end
        end)
        task.wait(0.01)
    end
end

local function startDefense()
    if defenseConnection then return end
    defenseConnection = RunService.Heartbeat:Connect(function()
        if not defenseEnabled then return end
        local attacker = getAttacker()
        if not attacker then return end
        if defenseMode == "Fling" then performFling(attacker)
        elseif defenseMode == "Kill" then performKill(attacker)
        elseif defenseMode == "Send to Heaven" then performHeaven(attacker)
        elseif defenseMode == "Kick" then performKick(attacker)
        elseif defenseMode == "Ragdoll" then performRagdoll(attacker)
        elseif defenseMode == "Hell" then performHell(attacker)
        elseif defenseMode == "China" then performChina(attacker)
        elseif defenseMode == "GrabLine" then
            if not crazylineTask then
                crazyline = true
                crazylineTask = task.spawn(performSpamGrabLines)
            end
        end
    end)
end

local function stopDefense()
    if defenseConnection then defenseConnection:Disconnect(); defenseConnection = nil end
    crazyline = false
    if crazylineTask then task.cancel(crazylineTask); crazylineTask = nil end
    for _, plr in pairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BodyVelocity") and (obj.Name == "RinneganFling" or obj.Name == "RinneganHeaven" or obj.Name == "RinneganSpy") then
                    obj:Destroy()
                end
            end
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    if defenseEnabled then task.wait(1); startDefense() end
end)

AntisTab:Toggle({
    Title = "Counter Attacks",
    Value = Toggles.counterAttacks or false,
    Callback = function(state)
        defenseEnabled = state
        Toggles.counterAttacks = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
        if state then startDefense() else stopDefense() end
    end
})

AntisTab:Dropdown({
    Title = "Attack Mode",
    Values = {"Fling","Kill","Send to Heaven","Kick","Ragdoll","Hell","China","GrabLine"},
    Value = "Fling",
    Callback = function(value) defenseMode = value end
})

local ocnKakuConn = nil
local ocnKakuAng = 0
AntisTab:Toggle({
    Title = "Anti Blobman Kill",
    Value = Toggles.antiBlobmanKill or false,
    Callback = function(state)
        if state then
            ocnKakuConn = RunService.RenderStepped:Connect(function(dt)
                pcall(function()
                    local c = LocalPlayer.Character
                    local root = c and c:FindFirstChild("HumanoidRootPart")
                    if root then
                        ocnKakuAng = ocnKakuAng + dt * 9999
                        local rad = math.rad(ocnKakuAng)
                        root.CFrame = CFrame.new(math.cos(rad) * 50000, -100000, math.sin(rad) * 50000)
                    end
                end)
            end)
        else
            if ocnKakuConn then ocnKakuConn:Disconnect(); ocnKakuConn = nil end
            ocnKakuAng = 0
        end
        Toggles.antiBlobmanKill = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    end
})

local ocnGroovConn = nil
local ocnGroovPos = nil
AntisTab:Toggle({
    Title = "Pos Lock",
    Value = Toggles.posLock or false,
    Callback = function(state)
        if state then
            pcall(function()
                local c = LocalPlayer.Character
                local root = c and c:FindFirstChild("HumanoidRootPart")
                if root then ocnGroovPos = root.CFrame end
                ocnGroovConn = RunService.RenderStepped:Connect(function()
                    local c2 = LocalPlayer.Character
                    local root2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                    if root2 and ocnGroovPos then
                        local assembly = root2.AssemblyRootPart or root2
                        assembly.AssemblyLinearVelocity = Vector3.zero
                        assembly.AssemblyAngularVelocity = Vector3.zero
                        local offset = assembly.CFrame:ToObjectSpace(root2.CFrame)
                        assembly.CFrame = ocnGroovPos * offset:Inverse()
                    end
                end)
            end)
        else
            if ocnGroovConn then ocnGroovConn:Disconnect(); ocnGroovConn = nil end
            pcall(function()
                local c2 = LocalPlayer.Character
                local root2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                if root2 then
                    local assembly = root2.AssemblyRootPart or root2
                    assembly.AssemblyLinearVelocity = Vector3.zero
                    assembly.AssemblyAngularVelocity = Vector3.zero
                end
            end)
            ocnGroovPos = nil
        end
        Toggles.posLock = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    end
})

local ocnStasisConn = nil
AntisTab:Toggle({
    Title = "Anti Loop Kill",
    Value = Toggles.antiLoopKill or false,
    Callback = function(state)
        if state then
            ocnStasisConn = RunService.RenderStepped:Connect(function()
                pcall(function()
                    local c = LocalPlayer.Character
                    local root = c and c:FindFirstChild("HumanoidRootPart")
                    if root then root.CFrame = CFrame.new(280, -4, 465) end
                end)
            end)
        else
            if ocnStasisConn then ocnStasisConn:Disconnect(); ocnStasisConn = nil end
        end
        Toggles.antiLoopKill = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    end
})

local ocnTornadoConn = nil
local ocnTornadoAng = 0
AntisTab:Toggle({
    Title = "Loop Tp (Op)",
    Value = Toggles.loopTpOp or false,
    Callback = function(state)
        if state then
            ocnTornadoConn = RunService.RenderStepped:Connect(function(dt)
                pcall(function()
                    local c = LocalPlayer.Character
                    local root = c and c:FindFirstChild("HumanoidRootPart")
                    if root then
                        ocnTornadoAng = ocnTornadoAng + dt * 50000
                        local rad = math.rad(ocnTornadoAng)
                        root.CFrame = CFrame.new(math.cos(rad) * 10000, 0, math.sin(rad) * 10000)
                    end
                end)
            end)
        else
            if ocnTornadoConn then ocnTornadoConn:Disconnect(); ocnTornadoConn = nil end
            ocnTornadoAng = 0
        end
        Toggles.loopTpOp = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    end
})

local ocnManiacConn = nil
AntisTab:Toggle({
    Title = "Loop Tp",
    Value = Toggles.loopTp or false,
    Callback = function(state)
        if state then
            ocnManiacConn = RunService.RenderStepped:Connect(function()
                pcall(function()
                    local c = LocalPlayer.Character
                    local root = c and c:FindFirstChild("HumanoidRootPart")
                    if root then
                        local ms = 2000
                        root.CFrame = CFrame.new(
                            math.random(-ms, ms),
                            math.random(-50, 500),
                            math.random(-ms, ms)
                        )
                    end
                end)
            end)
        else
            if ocnManiacConn then ocnManiacConn:Disconnect(); ocnManiacConn = nil end
        end
        Toggles.loopTp = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    end
})

local oldDisable = undeltedhub.DisableAll or function() end
undeltedhub.DisableAll = function()
    if antiGrabV1Active then
        antiGrabV1Active = false
        if antiGrabV1Task then task.cancel(antiGrabV1Task); antiGrabV1Task = nil end
    end
    if antiGrabV2Active then
        antiGrabV2Active = false
        if antiGrabV2Task then task.cancel(antiGrabV2Task); antiGrabV2Task = nil end
    end
    if gucciActive then
        gucciActive = false
        if gucciTask then task.cancel(gucciTask); gucciTask = nil end
        if checkGucciSeatTask then task.cancel(checkGucciSeatTask); checkGucciSeatTask = nil end
    end
    if antiOwnershipActive then
        antiOwnershipActive = false
        if antiOwnershipTask then task.cancel(antiOwnershipTask); antiOwnershipTask = nil end
    end
    if antiFireActive then
        antiFireActive = false
        if antiFireTask then task.cancel(antiFireTask); antiFireTask = nil end
        if hkFirePart then hkFirePart.CFrame = CFrame.new(0,-15,0) end
    end
    if antiExplosionActive then
        antiExplosionActive = false
        if antiExplosionConnection then antiExplosionConnection:Disconnect(); antiExplosionConnection = nil end
    end
    if antiVoidActive then
        antiVoidActive = false
        if antiVoidConnection then antiVoidConnection:Disconnect(); antiVoidConnection = nil end
    end
    if hkABlob then
        hkABlob = false
    end
    if antiSnowballActive then
        antiSnowballActive = false
        if antiSnowballTask then task.cancel(antiSnowballTask); antiSnowballTask = nil end
    end
    if AntiRagBlob then
        AntiRagBlob = false
        if ARCons.ARChar then ARCons.ARChar:Disconnect() end
        if ARCons.ARSeat then ARCons.ARSeat:Disconnect() end
    end
    if ocnAntiLagOn then
        ocnAntiLagOn = false
        pcall(function()
            if LocalPlayer.PlayerScripts and LocalPlayer.PlayerScripts:FindFirstChild("CharacterAndBeamMove") then
                LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = false
            end
        end)
    end
    if shurikenAntiKickActive then
        shurikenAntiKickActive = false
        if shurikenAntiKickTask then task.cancel(shurikenAntiKickTask); shurikenAntiKickTask = nil end
        if shurikenCharFixConnection then shurikenCharFixConnection:Disconnect() end
        if shurikenRespawnConnection then shurikenRespawnConnection:Disconnect() end
        ClearKunai()
    end
    if pencilAntiKickActive then
        pencilAntiKickActive = false
        if pencilAntiKickTask then task.cancel(pencilAntiKickTask); pencilAntiKickTask = nil end
        if pencilRespawnConnection then pencilRespawnConnection:Disconnect() end
    end
    if AntiKickItemActive then
        AntiKickItemActive = false
        if pcldConn then pcldConn:Disconnect(); pcldConn = nil end
        if charFixConnectionItem then charFixConnectionItem:Disconnect(); charFixConnectionItem = nil end
        MyPCLD = nil
    end
    if defenseEnabled then
        defenseEnabled = false
        stopDefense()
    end
    if ocnKakuConn then ocnKakuConn:Disconnect(); ocnKakuConn = nil end
    if ocnGroovConn then ocnGroovConn:Disconnect(); ocnGroovConn = nil end
    if ocnStasisConn then ocnStasisConn:Disconnect(); ocnStasisConn = nil end
    if ocnTornadoConn then ocnTornadoConn:Disconnect(); ocnTornadoConn = nil end
    if ocnManiacConn then ocnManiacConn:Disconnect(); ocnManiacConn = nil end

    if paintConnections then
        for _, conn in ipairs(paintConnections) do
            if conn.Connected then conn:Disconnect() end
        end
        paintConnections = {}
        for _, data in pairs(paintPartsBackup) do
            if data.clone and data.parent then data.clone.Parent = data.parent end
        end
        paintPartsBackup = {}
    end

    oldDisable()
end

SafeNotify({ Title = "Antis", Content = "Loaded", Duration = 2 })