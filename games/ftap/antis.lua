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

if undeitedhub.Toggles.shurikenAntiKick ~= nil and undeitedhub.Toggles.antiKick == nil then
    undeitedhub.Toggles.antiKick = undeitedhub.Toggles.shurikenAntiKick
    undeitedhub.Toggles.shurikenAntiKick = nil
    if undeitedhub.SaveSettings then
        undeitedhub.SaveSettings()
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
                    hkFirePart = Workspace.Plots.Plot5.Barrier.AntiFirePart
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
                task.wait()
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

local antiKickActive = false
local antiKickTask = nil
local antiKickPhysicsTask = nil
local antiKickCharConnection = nil
local antiKickRespawnConnection = nil
local AntiKickToyInternal = "NinjaShuriken"

local function fixAntiKickCharacter(char)
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hum and hrp then
        hum.AutoRotate = true
        hum.Sit = false
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CanCollide = true
        hrp.CanTouch = true
        hrp.CanQuery = true
        for _, part in pairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
                part.CanTouch = true
                part.CanQuery = true
                part.Velocity = Vector3.zero
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end
end

local function findAntiKickToy()
    local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if not inv then return nil, nil end
    local toy = inv:FindFirstChild(AntiKickToyInternal) or inv:FindFirstChild("AntiKick")
    return toy, inv
end

local function neutralizeToy(toy)
    if not toy then return end
    for _, obj in ipairs(toy:GetDescendants()) do
        if obj:IsA("BasePart") then
            pcall(function()
                obj.CanQuery = false
                obj.CanCollide = false
                obj.Massless = true
                obj.AssemblyLinearVelocity = Vector3.zero
                obj.AssemblyAngularVelocity = Vector3.zero
                obj.Velocity = Vector3.zero
                obj.RotVelocity = Vector3.zero
            end)
        end
        if obj:IsA("BodyVelocity") or obj:IsA("BodyAngularVelocity") or obj:IsA("BodyForce") or obj:IsA("BodyThrust")
            or obj:IsA("BodyPosition") or obj:IsA("BodyGyro")
            or obj:IsA("LinearVelocity") or obj:IsA("AngularVelocity") or obj:IsA("VectorForce")
            or obj:IsA("AlignPosition") or obj:IsA("AlignOrientation") then
            pcall(function() obj:Destroy() end)
        end
    end
end

local function clearAntiKickToys()
    local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    local destroyrem = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
    if inv and destroyrem then
        for _, v in pairs(inv:GetChildren()) do
            if v.Name == "AntiKick" or v.Name == AntiKickToyInternal then
                pcall(function() destroyrem:FireServer(v) end)
            end
        end
    end
end

local function StickToy(toy)
    if not toy then return false end
    local stickyPart = toy:FindFirstChild("StickyPart")
    if not stickyPart then return false end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local firePart = hrp:FindFirstChild("FirePlayerPart")
    if not firePart then return false end

    neutralizeToy(toy)

    local grabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")
    local setNet = grabEvents and grabEvents:FindFirstChild("SetNetworkOwner")
    local playerEvents = ReplicatedStorage:FindFirstChild("PlayerEvents")
    local stickyEvent = playerEvents and playerEvents:FindFirstChild("StickyPartEvent")

    local soundPart = toy:FindFirstChild("SoundPart")
    if soundPart and setNet then
        local owner = soundPart:FindFirstChild("PartOwner")
        if not owner or owner.Value ~= LocalPlayer.Name then
            pcall(function()
                setNet:FireServer(soundPart, soundPart.CFrame)
            end)
        end
    end

    if stickyEvent then
        pcall(function()
            stickyEvent:FireServer(stickyPart, firePart, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)))
        end)
    else
        return false
    end

    task.wait(0.1)
    neutralizeToy(toy)

    local handle = toy:FindFirstChild("Handle")
    if handle and not handle:FindFirstChild("AntiKickHL") then
        local hl = Instance.new("Highlight")
        hl.Name = "AntiKickHL"
        hl.FillColor = Color3.fromRGB(0, 255, 255)
        hl.OutlineColor = Color3.fromRGB(0, 255, 255)
        hl.FillTransparency = 0.5
        hl.Parent = handle
    end

    return true
end

local function ToggleAntiKick(state)
    antiKickActive = state

    if state then
        fixAntiKickCharacter(LocalPlayer.Character)

        if antiKickCharConnection then antiKickCharConnection:Disconnect() end
        antiKickCharConnection = LocalPlayer.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            fixAntiKickCharacter(char)
        end)

        if antiKickRespawnConnection then antiKickRespawnConnection:Disconnect() end
        antiKickRespawnConnection = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            if antiKickActive then
                clearAntiKickToys()
            end
        end)

        antiKickPhysicsTask = task.spawn(function()
            while antiKickActive do
                pcall(function()
                    local toy = findAntiKickToy()
                    if toy then
                        neutralizeToy(toy)
                    end
                end)
                RunService.Heartbeat:Wait()
            end
        end)

        antiKickTask = task.spawn(function()
            local plr = LocalPlayer
            local grabEvents = ReplicatedStorage:WaitForChild("GrabEvents")
            local setNet = grabEvents:WaitForChild("SetNetworkOwner")
            local spawnRemote = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
            local canSpawn = plr:WaitForChild("CanSpawnToy")

            local function getHRP()
                local character = plr.Character
                if character then
                    return character:FindFirstChild("HumanoidRootPart")
                end
                return nil
            end

            while antiKickActive do
                task.wait(0.1)

                if not plr.Character or not plr.Character:FindFirstChild("Humanoid") or plr.Character.Humanoid.Health <= 0 then
                    clearAntiKickToys()
                    task.wait(0.5)
                    continue
                end

                local toy = findAntiKickToy()

                local needsStick = false
                if toy then
                    local stickyPart = toy:FindFirstChild("StickyPart")
                    if stickyPart then
                        local weld = stickyPart:FindFirstChild("StickyWeld")
                        if not weld or not weld.Part1 then
                            needsStick = true
                        end
                    end
                end

                if not toy then
                    local t = tick()
                    while not canSpawn.Value do
                        if not antiKickActive or tick() - t > 5 then break end
                        task.wait(0.1)
                    end
                    if not canSpawn.Value then continue end

                    local hrp = getHRP()
                    if not hrp then continue end

                    task.spawn(function()
                        pcall(function()
                            spawnRemote:InvokeServer(AntiKickToyInternal, hrp.CFrame * CFrame.new(0, 12, 20), Vector3.zero)
                        end)
                    end)

                    local waitStart = tick()
                    repeat
                        task.wait(0.05)
                        toy = findAntiKickToy()
                    until toy or tick() - waitStart > 3

                    if not toy then continue end
                    needsStick = true
                end

                if needsStick and toy then
                    pcall(function() StickToy(toy) end)
                    task.wait(0.3)
                end
            end

            clearAntiKickToys()
        end)
    else
        if antiKickTask then
            task.cancel(antiKickTask)
            antiKickTask = nil
        end
        if antiKickPhysicsTask then
            task.cancel(antiKickPhysicsTask)
            antiKickPhysicsTask = nil
        end
        if antiKickCharConnection then
            antiKickCharConnection:Disconnect()
            antiKickCharConnection = nil
        end
        if antiKickRespawnConnection then
            antiKickRespawnConnection:Disconnect()
            antiKickRespawnConnection = nil
        end
        fixAntiKickCharacter(LocalPlayer.Character)
        clearAntiKickToys()
    end
end

AntisTab:Toggle({
    Title = "Anti Kick",
    Value = false,
    Callback = function(state)
        ToggleAntiKick(state)
        undeitedhub.Toggles.antiKick = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Anti Kick",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiKick then
    ToggleAntiKick(true)
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
    if antiKickActive then
        ToggleAntiKick(false)
    end
    oldDisable()
end