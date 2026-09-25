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
local antiGrabTask = nil

local function getCharacterEvents()
    return ReplicatedStorage:FindFirstChild("CharacterEvents")
end

local function fireRecovery(character, hum)
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
        hum.AutoRotate = true
        if hum.Sit then hum.Sit = false end
        hum.PlatformStand = false
    end)
end

local function clearPartOwnersDeep(character)
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

local function ToggleAntiGrab(state)
    antiGrabActive = state

    if state then
        if antiGrabTask then return end

        antiGrabTask = task.spawn(function()
            while antiGrabActive do
                pcall(function()
                    local character = LocalPlayer.Character
                    if not character then return end
                    local hum = character:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health <= 0 then return end

                    local grabbed = clearPartOwnersDeep(character)
                    if grabbed then
                        fireRecovery(character, hum)
                    end
                end)
                task.wait(0.05)
            end
            antiGrabTask = nil
        end)
    else
        if antiGrabTask then
            task.cancel(antiGrabTask)
            antiGrabTask = nil
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
                    local clearedOwners = clearPartOwnersDeep(character)

                    if broken > 0 or clearedOwners then
                        fireRecovery(character, hum)
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

    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        if track.Animation and (track.Animation.AnimationId == "rbxassetid://7047322890") then
            pcall(function() track:Stop() end)
        end
    end

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
    oldDisable()
end
