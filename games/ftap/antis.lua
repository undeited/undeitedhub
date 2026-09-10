local WindUI = undeitedhub.WindUI
local AntisTab = undeitedhub.Window:Tab({ Title = "Antis" })

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local antiGrabActive = false
local antiGrabTask = nil

local function clearAntiGrabModel(model)
    if not model then return end
    local destroyRemote = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
    if destroyRemote then
        pcall(function() destroyRemote:FireServer(model) end)
    end
end

local function ToggleAntiGrab(state)
    antiGrabActive = state

    if state then
        antiGrabTask = task.spawn(function()
            local ocarinaSpawnTick = nil
            local currentPlot = nil

            while antiGrabActive do
                pcall(function()
                    local plr = LocalPlayer

                    currentPlot = nil
                    local plots = Workspace:FindFirstChild("Plots")
                    if plots then
                        for _, home in pairs(plots:GetChildren()) do
                            local sign = home:FindFirstChild("PlotSign")
                            if sign then
                                local owners = sign:FindFirstChild("ThisPlotsOwners")
                                if owners then
                                    for _, person in pairs(owners:GetChildren()) do
                                        if person.Value == plr.Name then
                                            currentPlot = home.Name
                                        end
                                    end
                                end
                                local subSign = sign:FindFirstChild("Sign")
                                if subSign then
                                    local screen = subSign:FindFirstChild("Screen")
                                    local surfaceGui = screen and screen:FindFirstChild("SurfaceGui")
                                    local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
                                    local playerDisplayName = frame and frame:FindFirstChild("PlayerDisplayName")
                                    if frame and frame.Visible and playerDisplayName and playerDisplayName.Text == plr.DisplayName then
                                        currentPlot = home.Name
                                    end
                                end
                            end
                        end
                    end

                    local myToysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    local ocarina = myToysFolder and myToysFolder:FindFirstChild("InstrumentWoodwindOcarina")
                    if not ocarina and currentPlot then
                        local plotItems = Workspace:FindFirstChild("PlotItems")
                        local plotFolder = plotItems and plotItems:FindFirstChild(currentPlot)
                        ocarina = plotFolder and plotFolder:FindFirstChild("InstrumentWoodwindOcarina")
                    end

                    if ocarina then
                        local character = plr.Character
                        if character then
                            for _, prt in pairs(character:GetChildren()) do
                                local partOwner = prt:FindFirstChild("PartOwner")
                                if partOwner and partOwner.Value ~= "" then
                                    local holdPart = ocarina:FindFirstChild("HoldPart")
                                    local holdRemote = holdPart and holdPart:FindFirstChild("HoldItemRemoteFunction")
                                    if holdRemote then
                                        task.spawn(function()
                                            pcall(function()
                                                holdRemote:InvokeServer(ocarina, character)
                                            end)
                                        end)
                                        clearAntiGrabModel(ocarina)
                                        local hum = character:FindFirstChild("Humanoid")
                                        if hum then
                                            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                                            hum.AutoRotate = true
                                            if hum.Sit then
                                                hum.Sit = false
                                            end
                                        end
                                        pcall(function()
                                            partOwner.Value = ""
                                        end)
                                    end
                                end
                            end
                        end
                    else
                        local character = plr.Character
                        local canSpawn = plr:FindFirstChild("CanSpawnToy")
                        if character and canSpawn and canSpawn.Value and not ocarinaSpawnTick then
                            ocarinaSpawnTick = tick()
                            task.spawn(function()
                                pcall(function()
                                    ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer(
                                        "InstrumentWoodwindOcarina",
                                        CFrame.new(1e5, 1e5, 1e5),
                                        Vector3.new(0, 0, 0)
                                    )
                                end)
                            end)
                        elseif ocarinaSpawnTick and tick() - ocarinaSpawnTick > 1 then
                            local toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                            if toysFolder and not toysFolder:FindFirstChild("InstrumentWoodwindOcarina") then
                                ocarinaSpawnTick = nil
                            end
                        end
                    end

                    local character = plr.Character
                    local grabbed = false
                    if character then
                        for _, prt in pairs(character:GetChildren()) do
                            local partOwner = prt:FindFirstChild("PartOwner")
                            if partOwner and partOwner.Value ~= "" then
                                grabbed = true
                            end
                        end
                    end

                    if grabbed then
                        local characterEvents = ReplicatedStorage:FindFirstChild("CharacterEvents")
                        local struggle = characterEvents and characterEvents:FindFirstChild("Struggle")
                        if struggle then
                            pcall(function() struggle:FireServer(plr) end)
                        end
                        local hum = character and character:FindFirstChild("Humanoid")
                        local hrp = character and character:FindFirstChild("HumanoidRootPart")
                        if hum and hrp then
                            local ragdollRemote = characterEvents and characterEvents:FindFirstChild("RagdollRemote")
                            if ragdollRemote then
                                pcall(function() ragdollRemote:FireServer(hrp, 0.00000000001) end)
                            end
                            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                                if track.Animation and track.Animation.AnimationId == "rbxassetid://7047322890" then
                                    track:Stop()
                                end
                            end
                        end
                    end
                end)

                if antiGrabActive and LocalPlayer.Character then
                    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
                    if hum then
                        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                            if track.Animation and track.Animation.AnimationId == "rbxassetid://7047322890" then
                                track:Stop()
                            end
                        end
                    end
                end

                task.wait()
            end
        end)
    else
        if antiGrabTask then
            task.cancel(antiGrabTask)
            antiGrabTask = nil
        end
        local toysFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        if toysFolder then
            local ocarina = toysFolder:FindFirstChild("InstrumentWoodwindOcarina")
            if ocarina then
                clearAntiGrabModel(ocarina)
            end
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
    oldDisable()
end