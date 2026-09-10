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
local antiKickCharFixConnection = nil
local antiKickRespawnConnection = nil
local antiKickPhysicsTask = nil
local AntiKickToy = "NinjaShuriken"

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

local function neutralizeToy(toy)
    if not toy then return end
    for _, obj in ipairs(toy:GetDescendants()) do
        if obj:IsA("BasePart") then
            pcall(function()
                obj.CanTouch = false
                obj.CanCollide = false
                obj.CanQuery = false
                obj.Massless = true
                obj.AssemblyLinearVelocity = Vector3.zero
                obj.AssemblyAngularVelocity = Vector3.zero
                obj.Velocity = Vector3.zero
                obj.RotVelocity = Vector3.zero
            end)
        end
        if obj:IsA("BodyVelocity") or obj:IsA("BodyAngularVelocity") or obj:IsA("BodyForce") or obj:IsA("BodyThrust") or obj:IsA("LinearVelocity") or obj:IsA("AngularVelocity") or obj:IsA("VectorForce") then
            pcall(function() obj:Destroy() end)
        end
    end
end

local function ClearAntiKickToy()
    local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    local destroyrem = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
    if inv and destroyrem then
        for _, v in pairs(inv:GetChildren()) do
            if v.Name == "AntiKick" or v.Name == AntiKickToy then
                pcall(function() destroyrem:FireServer(v) end)
            end
        end
    end
end

local function ToggleAntiKick(enable)
    antiKickActive = enable

    if enable then
        fixAntiKickCharacter(LocalPlayer.Character)

        if antiKickCharFixConnection then antiKickCharFixConnection:Disconnect() end
        antiKickCharFixConnection = LocalPlayer.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            fixAntiKickCharacter(char)
        end)

        if antiKickRespawnConnection then antiKickRespawnConnection:Disconnect() end
        antiKickRespawnConnection = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            if antiKickActive then
                ClearAntiKickToy()
            end
        end)

        if antiKickPhysicsTask then antiKickPhysicsTask = nil end
        antiKickPhysicsTask = task.spawn(function()
            while antiKickActive do
                pcall(function()
                    local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                    if inv then
                        for _, toy in pairs(inv:GetChildren()) do
                            if toy.Name == "AntiKick" or toy.Name == AntiKickToy then
                                for _, obj in ipairs(toy:GetDescendants()) do
                                    if obj:IsA("BasePart") then
                                        obj.Massless = true
                                        obj.AssemblyLinearVelocity = Vector3.zero
                                        obj.AssemblyAngularVelocity = Vector3.zero
                                        obj.Velocity = Vector3.zero
                                        obj.RotVelocity = Vector3.zero
                                    end
                                end
                            end
                        end
                    end
                end)
                RunService.Heartbeat:Wait()
            end
        end)

        antiKickTask = task.spawn(function()
            local plr = LocalPlayer
            local setOwner = ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
            local stickyEvent = ReplicatedStorage:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
            local spawnRemote = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction
            local destroyrem = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
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
                if not Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                    return false
                end
                for _, v in pairs(Workspace.Plots:GetChildren()) do
                    local sign = v:FindFirstChild("PlotSign")
                    local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                    if owners then
                        for _, b in pairs(owners:GetChildren()) do
                            if b.Value == plr.Name then
                                local folder = Workspace.PlotItems:FindFirstChild(v.Name)
                                if folder then return true, folder end
                            end
                        end
                    end
                end
                return false
            end

            local function StickToy(toy)
                if not toy or not toy:FindFirstChild("StickyPart") then return end
                local currentHRP = getHRP()
                if not currentHRP then return end

                neutralizeToy(toy)

                if toy:FindFirstChild("SoundPart") then
                    if not toy.SoundPart:FindFirstChild("PartOwner") or toy.SoundPart.PartOwner.Value ~= plr.Name then
                        setOwner:FireServer(toy.SoundPart, toy.SoundPart.CFrame)
                    end
                end
                local firePart = currentHRP:FindFirstChild("FirePlayerPart") or currentHRP:WaitForChild("FirePlayerPart", 5)
                if firePart then
                    stickyEvent:FireServer(toy.StickyPart, firePart, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)))
                end

                neutralizeToy(toy)

                if toy:FindFirstChild("Handle") then
                    local handle = toy.Handle
                    if not handle:FindFirstChild("Highlight") then
                        local high = Instance.new("Highlight", handle)
                        high.FillColor = Color3.fromRGB(0, 255, 255)
                    end
                end
            end

            local function SpawnToy(name)
                local t = tick()
                while not canSpawn.Value do
                    if not antiKickActive or tick() - t > 5 then return nil end
                    task.wait(0.1)
                end
                local currentHRP = getHRP()
                if currentHRP then
                    task.spawn(function()
                        pcall(function()
                            spawnRemote:InvokeServer(name, currentHRP.CFrame * CFrame.new(0, 12, 20), Vector3.new(0, 0, 0))
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

            while antiKickActive do
                task.wait(0.005)
                if not plr.Character or not plr.Character:FindFirstChild("Humanoid") or plr.Character.Humanoid.Health <= 0 then
                    task.wait(0.5)
                    ClearAntiKickToy()
                    return
                end
                local inv = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                local toy = inv and inv:FindFirstChild(AntiKickToy)

                if Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                    local boolik, house = CheckForHome()
                    if boolik and house and Workspace.Plots:FindFirstChild(house.Name) then
                        local sign = Workspace.Plots[house.Name]:FindFirstChild("PlotSign")
                        if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                            toy = SpawnToy(AntiKickToy)
                            if toy == nil then return end
                            toy.Name = "AntiKick"
                            StickToy(toy)
                        end
                    end
                end

                if not toy then
                    if Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then return end
                    toy = SpawnToy(AntiKickToy)
                    if toy == nil then return end
                    toy.Name = "AntiKick"
                    if not toy then return end
                    neutralizeToy(toy)
                end

                repeat
                    if toy and toy:FindFirstChild("StickyPart") and toy.StickyPart.CanTouch == true then
                        StickToy(toy)
                        toy.Name = "AntiKick"
                    end
                    neutralizeToy(toy)
                    task.wait(0.3)
                until not toy or not antiKickActive or not toy:FindFirstChild("StickyPart") or toy.StickyPart.CanTouch == false
                    or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart")
                    or not toy:FindFirstChild("StickyPart")
                    or (plr.Character.HumanoidRootPart.Position - toy.StickyPart.Position).Magnitude >= 20

                if not toy or not toy:FindFirstChild("StickyPart") or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or (plr.Character.HumanoidRootPart.Position - toy.StickyPart.Position).Magnitude >= 20 then
                    ClearAntiKickToy()
                end

                pcall(function()
                    repeat
                        task.wait(0.05)
                    until not antiKickActive or not plr.Character or not plr.Character:FindFirstChild("Humanoid") or not toy or not toy:FindFirstChild("StickyPart") or not toy.StickyPart:FindFirstChild("StickyWeld") or not toy.StickyPart.StickyWeld.Part1
                    if not toy or not toy:FindFirstChild("StickyPart") or (plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health <= 0) or not toy["StickyPart"]:FindFirstChild("StickyWeld").Part1 then
                        ClearAntiKickToy()
                    end
                end)
            end
            ClearAntiKickToy()
        end)
    else
        antiKickActive = false
        if antiKickTask then
            task.cancel(antiKickTask)
            antiKickTask = nil
        end
        if antiKickPhysicsTask then
            antiKickPhysicsTask = nil
        end
        if antiKickCharFixConnection then
            antiKickCharFixConnection:Disconnect()
            antiKickCharFixConnection = nil
        end
        if antiKickRespawnConnection then
            antiKickRespawnConnection:Disconnect()
            antiKickRespawnConnection = nil
        end
        fixAntiKickCharacter(LocalPlayer.Character)
        ClearAntiKickToy()
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