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
local antiGrabSpawnTick = nil
local antiGrabCurrentPlot = nil
local antiGrabPlotScanTick = 0

local function destroyOcarina(ocarina)
    if not ocarina then return end
    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    local destroyToy = menuToys and menuToys:FindFirstChild("DestroyToy")
    if destroyToy then
        pcall(function() destroyToy:FireServer(ocarina) end)
    end
end

local function findCurrentPlot(plr)
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, home in pairs(plots:GetChildren()) do
        local plotSign = home:FindFirstChild("PlotSign")
        if plotSign then
            local owners = plotSign:FindFirstChild("ThisPlotsOwners")
            if owners then
                for _, person in pairs(owners:GetChildren()) do
                    if person.Value == plr.Name then
                        return home.Name
                    end
                end
            end
            local sign = plotSign:FindFirstChild("Sign")
            if sign then
                local screen = sign:FindFirstChild("Screen")
                local surfaceGui = screen and screen:FindFirstChild("SurfaceGui")
                local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
                if frame and frame.Visible then
                    local pdn = frame:FindFirstChild("PlayerDisplayName")
                    if pdn and pdn.Text == plr.DisplayName then
                        return home.Name
                    end
                end
            end
        end
    end
    return nil
end

local function isGrabbed(character)
    if not character then return false end
    for _, prt in pairs(character:GetChildren()) do
        local partOwner = prt:FindFirstChild("PartOwner")
        if partOwner and partOwner.Value ~= "" then
            return true, prt, partOwner
        end
    end
    return false, nil, nil
end

local function findOcarina(plr, plot)
    local toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
    local ocarina = toysFolder and toysFolder:FindFirstChild("InstrumentWoodwindOcarina")
    if ocarina then return ocarina end
    if plot then
        local plotItems = Workspace:FindFirstChild("PlotItems")
        local plotFolder = plotItems and plotItems:FindFirstChild(plot)
        ocarina = plotFolder and plotFolder:FindFirstChild("InstrumentWoodwindOcarina")
    end
    return ocarina
end

local function spawnOcarina(plr)
    local canSpawn = plr:FindFirstChild("CanSpawnToy")
    if not canSpawn or not canSpawn.Value then return false end
    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    local spawnToy = menuToys and menuToys:FindFirstChild("SpawnToyRemoteFunction")
    if not spawnToy then return false end
    task.spawn(function()
        pcall(function()
            spawnToy:InvokeServer(
                "InstrumentWoodwindOcarina",
                CFrame.new(1e5, 1e5, 1e5),
                Vector3.new(0, 0, 0)
            )
        end)
    end)
    return true
end

local function useOcarina(ocarina, character)
    local holdPart = ocarina:FindFirstChild("HoldPart")
    local holdRemote = holdPart and holdPart:FindFirstChild("HoldItemRemoteFunction")
    if not holdRemote then return false end
    pcall(function()
        holdRemote:InvokeServer(ocarina, character)
    end)
    return true
end

local function clearPartOwners(character)
    for _, prt in pairs(character:GetChildren()) do
        local partOwner = prt:FindFirstChild("PartOwner")
        if partOwner and partOwner.Value ~= "" then
            pcall(function() partOwner.Value = "" end)
        end
    end
end

local function fireRecovery(plr, character, hum)
    local characterEvents = ReplicatedStorage:FindFirstChild("CharacterEvents")
    if not characterEvents then return end

    local struggle = characterEvents:FindFirstChild("Struggle")
    if struggle then
        pcall(function() struggle:FireServer(plr) end)
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local ragdollRemote = characterEvents:FindFirstChild("RagdollRemote")
    if hrp and ragdollRemote then
        pcall(function() ragdollRemote:FireServer(hrp, 0.00000000001) end)
    end

    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        if track.Animation and track.Animation.AnimationId == "rbxassetid://7047322890" then
            track:Stop()
        end
    end
end

local function ToggleAntiGrab(state)
    antiGrabActive = state

    if state then
        antiGrabSpawnTick = nil
        antiGrabCurrentPlot = nil
        antiGrabPlotScanTick = 0

        antiGrabTask = task.spawn(function()
            local plr = LocalPlayer
            local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
            if not menuToys then return end
            local destroyToy = menuToys:FindFirstChild("DestroyToy")

            while antiGrabActive do
                pcall(function()
                    local character = plr.Character
                    if not character then return end

                    local hum = character:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health <= 0 then return end

                    local grabbed, grabbedPart, grabbedOwner = isGrabbed(character)

                    if not grabbed then
                        return
                    end

                    local now = tick()

                    if now - antiGrabPlotScanTick > 1.5 then
                        antiGrabPlotScanTick = now
                        antiGrabCurrentPlot = findCurrentPlot(plr)
                    end

                    local ocarina = findOcarina(plr, antiGrabCurrentPlot)

                    if ocarina then
                        local used = useOcarina(ocarina, character)
                        if used then
                            if destroyToy then
                                pcall(function() destroyToy:FireServer(ocarina) end)
                            end
                            antiGrabSpawnTick = nil
                            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                            hum.AutoRotate = true
                            if hum.Sit then
                                hum.Sit = false
                            end
                            clearPartOwners(character)
                        end
                    else
                        if not antiGrabSpawnTick then
                            local spawned = spawnOcarina(plr)
                            if spawned then
                                antiGrabSpawnTick = now
                            end
                        elseif now - antiGrabSpawnTick > 0.3 then
                            local toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                            if not toysFolder or not toysFolder:FindFirstChild("InstrumentWoodwindOcarina") then
                                antiGrabSpawnTick = nil
                            end
                        end
                    end

                    fireRecovery(plr, character, hum)
                end)

                if antiGrabActive and LocalPlayer.Character then
                    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
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
        antiGrabSpawnTick = nil
        antiGrabCurrentPlot = nil

        local toysFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        if toysFolder then
            local ocarina = toysFolder:FindFirstChild("InstrumentWoodwindOcarina")
            if ocarina then
                destroyOcarina(ocarina)
            end
        end
        local plot = antiGrabCurrentPlot
        if plot then
            local plotItems = Workspace:FindFirstChild("PlotItems")
            local plotFolder = plotItems and plotItems:FindFirstChild(plot)
            if plotFolder then
                local ocarina = plotFolder:FindFirstChild("InstrumentWoodwindOcarina")
                if ocarina then
                    destroyOcarina(ocarina)
                end
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