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

local antiBlobmanActive = false
local antiBlobmanTask = nil

local function ToggleAntiBlobman(state)
    antiBlobmanActive = state
    if state then
        antiBlobmanTask = task.spawn(function()
            while antiBlobmanActive do
                pcall(function()
                    local char = LocalPlayer.Character
                    if char then
                        if not char:FindFirstChild("TruePositionPart") then
                            local tp = Instance.new("Part")
                            tp.Parent = char
                            tp.Name = "TruePositionPart"
                            tp.Anchored = true
                            tp.CFrame = CFrame.new(0, -100, 0)
                        end
                        for _, prt in pairs(char:GetChildren()) do
                            if prt:IsA("BasePart") and prt.Massless then
                                prt.Massless = false
                            end
                            if prt.Name == "HumanoidRootPart" and char.HumanoidRootPart:FindFirstChild("RootAttachment") then
                                for _ = 1, 10 do task.wait() end
                                if char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart:FindFirstChild("RootAttachment") and char:FindFirstChild("TruePositionPart") then
                                    char.HumanoidRootPart.RootAttachment.Parent = char.TruePositionPart
                                end
                            end
                        end
                    end
                end)
                task.wait()
            end
        end)
    else
        antiBlobmanActive = false
        if antiBlobmanTask then
            task.cancel(antiBlobmanTask)
            antiBlobmanTask = nil
        end
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("TruePositionPart") then
            if char.TruePositionPart:FindFirstChild("RootAttachment") then
                char.TruePositionPart.RootAttachment.Parent = char.HumanoidRootPart
            end
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Blobman",
    Value = false,
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

local antiLagActive = false
local ocnAutoLagEnabled = false
local ocnAutoLagActive = false
local ocnFpsThreshold = 30
local ocnFpsFrames = 0
local ocnLastFpsCheck = tick()
local ocnAutoLagStartDelay = tick()

local function ApplyAntiLag(state)
    ocnAutoLagActive = state
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

AntisTab:Toggle({
    Title = "Auto Anti Lag",
    Value = false,
    Callback = function(state)
        ocnAutoLagEnabled = state
        if state then
            ocnLastFpsCheck = tick()
            ocnFpsFrames = 0
            ocnAutoLagStartDelay = tick()
        end
        undeitedhub.Toggles.autoAntiLag = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Auto Anti Lag",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

AntisTab:Slider({
    Title = "Auto Anti Lag FPS Threshold",
    Value = {
        Min = 10,
        Max = 120,
        Default = 30,
    },
    Callback = function(value)
        ocnFpsThreshold = value
        undeitedhub.Toggles.antiLagFPS = value
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
    end
})

if undeitedhub.Toggles.antiLagFPS then
    ocnFpsThreshold = undeitedhub.Toggles.antiLagFPS
end

if undeitedhub.Toggles.autoAntiLag then
    ocnAutoLagEnabled = true
    ocnLastFpsCheck = tick()
    ocnFpsFrames = 0
    ocnAutoLagStartDelay = tick()
end

task.spawn(function()
    while task.wait() do
        if ocnAutoLagEnabled then
            if tick() - ocnAutoLagStartDelay < 5 then
                task.wait()
            else
                ocnFpsFrames = ocnFpsFrames + 1
                local now = tick()
                if now - ocnLastFpsCheck >= 1 then
                    local fps = ocnFpsFrames / (now - ocnLastFpsCheck)
                    ocnFpsFrames = 0
                    ocnLastFpsCheck = now
                    if fps <= ocnFpsThreshold and not ocnAutoLagActive then
                        ApplyAntiLag(true)
                    elseif fps > ocnFpsThreshold and ocnAutoLagActive then
                        ApplyAntiLag(false)
                    end
                end
            end
        end
        task.wait()
    end
end)

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if antiFireActive then
        ToggleAntiFire(false)
    end
    if antiBlobmanActive then
        ToggleAntiBlobman(false)
    end
    if antiLagActive or ocnAutoLagActive then
        antiLagActive = false
        ApplyAntiLag(false)
    end
    ocnAutoLagEnabled = false
    oldDisable()
end
