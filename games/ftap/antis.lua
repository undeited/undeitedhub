local WindUI = undeitedhub.WindUI
local AntisTab = undeitedhub.Window:Tab({ Title = "Antis" })

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

local antiFireActive = false
local antiFireTask = nil
local hkFirePart = nil

local function ToggleAntiFire(state)
    antiFireActive = state
    if state then
        pcall(function()
            if Workspace.Plots and Workspace.Plots.Plot5 and Workspace.Plots.Plot5.Barrier then
                if Workspace.Plots.Plot5.Barrier:FindFirstChild("AntiFirePart") then
                    hkFirePart = Workspace.Plots.Plot5.Barrier:FindFirstChild("AntiFirePart")
                else
                    hkFirePart = Workspace.Plots.Plot5.Barrier:FindFirstChild("PlotBarrier")
                end
                if hkFirePart then
                    hkFirePart.CanCollide = true
                    hkFirePart.CanQuery = true
                    hkFirePart.Name = "AntiFirePart"
                    local h2 = hkFirePart:Clone()
                    h2.Name = "FalseBorder"
                    h2.Parent = hkFirePart.Parent
                    hkFirePart.Size = Vector3.new(1, 1, 1)
                    for _, prt in pairs(hkFirePart:GetChildren()) do
                        prt:Destroy()
                    end
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
                task.wait(0.1)
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
    end
end

AntisTab:Toggle({
    Title = "Anti Fire",
    Value = false,
    Callback = function(state)
        ToggleAntiFire(state)
        undeitedhub.Toggles.antiFire = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Anti Fire",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiFire then
    ToggleAntiFire(true)
end

local antiLagActive = false

local function ApplyAntiLag(state)
    if state then
        pcall(function()
            LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = true
            for _, plr in pairs(Players:GetPlayers()) do
                if plr.Character and plr.Character:FindFirstChild("GrabParts") then
                    plr.Character.GrabParts:Destroy()
                end
            end
        end)
    else
        pcall(function()
            LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = false
        end)
    end
end

AntisTab:Toggle({
    Title = "Anti Lag",
    Value = false,
    Callback = function(state)
        antiLagActive = state
        ApplyAntiLag(state)
        undeitedhub.Toggles.antiLag = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Anti Lag",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiLag then
    antiLagActive = true
    ApplyAntiLag(true)
end

local antiGrabActive = false
local antiGrabConn = nil

local GRAB_ANIM_IDS = {
    ["rbxassetid://7047322890"] = true,
    ["http://www.roblox.com/asset/?id=7047322890"] = true,
}

local function getCharacterEvents()
    return ReplicatedStorage:FindFirstChild("CharacterEvents")
end

local function getGrabEvents()
    return ReplicatedStorage:FindFirstChild("GrabEvents")
end

local function isGrabSource(part)
    if not part then return false end
    local current = part
    while current do
        local name = current.Name
        if name == "CreatureBlobman" or name == "LeftDetector" or name == "RightDetector" then
            return true
        end
        current = current.Parent
    end
    return false
end

local function findExternalConstraints(character)
    local constraints = {}
    for _, child in ipairs(character:GetDescendants()) do
        local class = child.ClassName
        if class == "Weld" or class == "WeldConstraint" or class == "RigidConstraint"
            or class == "Motor6D" or class == "Snap" or class == "RopeConstraint"
            or class == "BallSocketConstraint" or class == "HingeConstraint" then
            local p0 = child.Part0 or child.Attachment0 and child.Attachment0.Parent
            local p1 = child.Part1 or child.Attachment1 and child.Attachment1.Parent
            local outside = nil
            if p0 and p1 then
                if p0:IsDescendantOf(character) and not p1:IsDescendantOf(character) then
                    outside = p1
                elseif p1:IsDescendantOf(character) and not p0:IsDescendantOf(character) then
                    outside = p0
                end
                if outside and isGrabSource(outside) then
                    table.insert(constraints, child)
                end
            end
        end
    end
    return constraints
end

local function isGrabbedNow(character, hum)
    if not character or not hum then return false end
    if hum.PlatformStand then return true end
    if hum:GetState() == Enum.HumanoidStateType.Physics then return true end
    if hum:GetState() == Enum.HumanoidStateType.Ragdoll then return true end
    if hum.Sit then return true end

    for _, child in ipairs(character:GetDescendants()) do
        local partOwner = child:FindFirstChild("PartOwner")
        if partOwner and partOwner.Value ~= "" then
            return true
        end
    end

    return false
end

local function breakExternalConstraints(character)
    local constraints = findExternalConstraints(character)
    for _, constraint in ipairs(constraints) do
        pcall(function() constraint:Destroy() end)
    end
    return #constraints
end

local function clearPartOwners(character)
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

local function reclaimOwnership(hrp)
    local GE = getGrabEvents()
    if not GE then return end
    local setNet = GE:FindFirstChild("SetNetworkOwner")
    if not setNet then return end
    pcall(function()
        setNet:FireServer(hrp, hrp.CFrame)
    end)
end

local function fireStruggle()
    local characterEvents = getCharacterEvents()
    if not characterEvents then return end
    local struggle = characterEvents:FindFirstChild("Struggle")
    if struggle then
        pcall(function() struggle:FireServer(LocalPlayer) end)
    end
end

local function fireRagdollReset(hrp)
    local characterEvents = getCharacterEvents()
    if not characterEvents then return end
    local ragdollRemote = characterEvents:FindFirstChild("RagdollRemote")
    if ragdollRemote and hrp then
        pcall(function() ragdollRemote:FireServer(hrp, 0.00000000001) end)
    end
end

local function stopGrabAnimations(hum)
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        local anim = track.Animation
        if anim and GRAB_ANIM_IDS[anim.AnimationId] then
            pcall(function() track:Stop(0) end)
            pcall(function() track:Destroy() end)
        end
    end
end

local function resetHumanoidState(hum)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    end)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
    pcall(function()
        if hum:GetState() == Enum.HumanoidStateType.Physics then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        elseif hum:GetState() == Enum.HumanoidStateType.Ragdoll then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
    pcall(function()
        hum.PlatformStand = false
        hum.AutoRotate = true
        if hum.Sit then hum.Sit = false end
    end)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
    end)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
    end)
end

local function ToggleAntiGrab(state)
    antiGrabActive = state

    if state then
        if antiGrabConn then return end

        local strugglingThisFrame = false

        antiGrabConn = RunService.Heartbeat:Connect(function()
            if not antiGrabActive then return end
            if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

            local character = LocalPlayer.Character
            if not character then return end
            local hum = character:FindFirstChildOfClass("Humanoid")
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hum or not hrp or hum.Health <= 0 then return end

            local grabbed = isGrabbedNow(character, hum)
            if not grabbed then
                strugglingThisFrame = false
                return
            end

            local broken = breakExternalConstraints(character)
            local cleared = clearPartOwners(character)

            if broken > 0 or cleared or grabbed then
                if not strugglingThisFrame then
                    strugglingThisFrame = true
                    fireStruggle()
                    fireRagdollReset(hrp)
                    reclaimOwnership(hrp)
                else
                    fireStruggle()
                end

                stopGrabAnimations(hum)
                resetHumanoidState(hum)
            end
        end)
    else
        if antiGrabConn then
            antiGrabConn:Disconnect()
            antiGrabConn = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Grab",
    Value = false,
    Callback = function(state)
        ToggleAntiGrab(state)
        undeitedhub.Toggles.antiGrab = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Anti Grab",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiGrab then
    ToggleAntiGrab(true)
end

local antiBlobmanActive = false
local antiBlobmanTask = nil

local function isBlobmanPart(part)
    if not part then return false end
    local current = part
    while current do
        if current.Name == "CreatureBlobman" then return true end
        current = current.Parent
    end
    return false
end

local function findBlobmanWelds(character)
    local welds = {}
    for _, child in ipairs(character:GetDescendants()) do
        if child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("RigidConstraint") or child:IsA("Motor6D") then
            local p0 = child.Part0
            local p1 = child.Part1
            local opposite = nil
            if p0 and p1 then
                if p0:IsDescendantOf(character) then
                    opposite = p1
                elseif p1:IsDescendantOf(character) then
                    opposite = p0
                end
                if opposite and isBlobmanPart(opposite) then
                    table.insert(welds, child)
                end
            end
        end
    end
    return welds
end

local function breakBlobmanWelds(character)
    local welds = findBlobmanWelds(character)
    for _, weld in ipairs(welds) do
        pcall(function() weld:Destroy() end)
    end
    return #welds
end

local function ToggleAntiBlobman(state)
    antiBlobmanActive = state

    if state then
        if antiBlobmanTask then return end

        antiBlobmanTask = task.spawn(function()
            while antiBlobmanActive do
                pcall(function()
                    local character = LocalPlayer.Character
                    if not character then return end
                    local hum = character:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health <= 0 then return end

                    local broken = breakBlobmanWelds(character)
                    local clearedOwners = clearPartOwners(character)

                    if broken > 0 or clearedOwners then
                        fireStruggle()
                        local hrp = character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            fireRagdollReset(hrp)
                        end
                        stopGrabAnimations(hum)
                        resetHumanoidState(hum)
                    end
                end)
                task.wait(0.03)
            end
            antiBlobmanTask = nil
        end)
    else
        if antiBlobmanTask then
            task.cancel(antiBlobmanTask)
            antiBlobmanTask = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Blobman",
    Value = antiBlobmanActive,
    Callback = function(state)
        ToggleAntiBlobman(state)
        undeitedhub.Toggles.antiBlobman = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Anti Blobman",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiBlobman then
    ToggleAntiBlobman(true)
end

local ANTI_VOID_THRESHOLD = 50
local ANTI_VOID_OFFSET = Vector3.new(0, 3, 0)
local ANTI_VOID_RESTORE_COOLDOWN = 0.5

local antiVoidActive = false
local antiVoidTask = nil
local lastVoidRestore = 0

local function getDeathBarrierHeight()
    local h = Workspace.FallenPartsDestroyHeight
    if type(h) == "number" and h == h and h ~= math.huge and h ~= -math.huge then
        return h
    end
    return -500
end

local function getRespawnTarget()
    local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
    if spawnLocation and spawnLocation:IsA("BasePart") then
        return spawnLocation.CFrame + ANTI_VOID_OFFSET
    end

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                return hrp.CFrame + ANTI_VOID_OFFSET
            end
        end
    end

    return nil
end

local function restoreCharacterState(character, hum, hrp, targetCFrame)
    if not character or not hum or not hrp then return end

    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end)

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
                part.Velocity = Vector3.zero
                part.RotVelocity = Vector3.zero
            end)
        end
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

    stopGrabAnimations(hum)

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

local function ToggleAntiVoid(state)
    antiVoidActive = state

    if state then
        if antiVoidTask then return end

        antiVoidTask = task.spawn(function()
            while antiVoidActive do
                pcall(function()
                    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

                    local character = LocalPlayer.Character
                    if not character then return end
                    local hum = character:FindFirstChildOfClass("Humanoid")
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if not hum or not hrp or hum.Health <= 0 then return end

                    local barrierHeight = getDeathBarrierHeight()
                    local thresholdY = barrierHeight + ANTI_VOID_THRESHOLD

                    if hrp.Position.Y <= thresholdY then
                        local now = tick()
                        if now - lastVoidRestore > ANTI_VOID_RESTORE_COOLDOWN then
                            lastVoidRestore = now

                            local target = getRespawnTarget()
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
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Anti Void",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiVoid then
    ToggleAntiVoid(true)
end

local ANTI_EXPLODE_BUFFER = 5
local ANTI_EXPLODE_CHECK_INTERVAL = 0.03
local ANTI_EXPLODE_DETECTION_COOLDOWN = 2
local DEFAULT_BOMB_RADIUS = 17.5

local antiExplodeActive = false
local antiExplodeTask = nil
local detectedBombName = nil
local detectedRadius = DEFAULT_BOMB_RADIUS
local detectedPositionParts = { "Body", "PositionPart", "Main", "Part", "VisualBody" }
local lastDetection = 0

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
                detectedBombName = toy.Name

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

local function getBombPosition(bomb)
    if not bomb then return nil end
    for _, name in ipairs(detectedPositionParts) do
        local part = bomb:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            return part.Position
        end
    end
    if bomb.PrimaryPart then
        return bomb.PrimaryPart.Position
    end
    for _, part in ipairs(bomb:GetDescendants()) do
        if part:IsA("BasePart") then
            return part.Position
        end
    end
    return nil
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

local function ToggleAntiExplode(state)
    antiExplodeActive = state

    if state then
        if antiExplodeTask then return end

        lastDetection = 0
        detectedBombName = nil
        detectedRadius = DEFAULT_BOMB_RADIUS
        detectedPositionParts = { "Body", "PositionPart", "Main", "Part", "VisualBody" }

        antiExplodeTask = task.spawn(function()
            while antiExplodeActive do
                pcall(function()
                    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

                    local now = tick()
                    if now - lastDetection > ANTI_EXPLODE_DETECTION_COOLDOWN then
                        lastDetection = now
                        pcall(detectBombSettings)
                    end

                    local char = LocalPlayer.Character
                    if not char then return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if not hrp or not hum or hum.Health <= 0 then return end

                    local threshold = detectedRadius + ANTI_EXPLODE_BUFFER
                    local bombs = getAllBombs()
                    for _, bomb in ipairs(bombs) do
                        if bomb.Parent then
                            local pos = getBombPosition(bomb)
                            if pos then
                                local dist = (pos - hrp.Position).Magnitude
                                if dist <= threshold then
                                    destroyBomb(bomb)
                                end
                            end
                        end
                    end
                end)
                task.wait(ANTI_EXPLODE_CHECK_INTERVAL)
            end
            antiExplodeTask = nil
        end)
    else
        if antiExplodeTask then
            task.cancel(antiExplodeTask)
            antiExplodeTask = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Explode",
    Value = antiExplodeActive,
    Callback = function(state)
        ToggleAntiExplode(state)
        undeitedhub.Toggles.antiExplode = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Anti Explode",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiExplode then
    ToggleAntiExplode(true)
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if antiFireActive then
        ToggleAntiFire(false)
    end
    if antiLagActive then
        antiLagActive = false
        ApplyAntiLag(false)
    end
    if antiGrabActive then
        ToggleAntiGrab(false)
    end
    if antiBlobmanActive then
        ToggleAntiBlobman(false)
    end
    if antiVoidActive then
        ToggleAntiVoid(false)
    end
    if antiExplodeActive then
        ToggleAntiExplode(false)
    end
    oldDisable()
end
