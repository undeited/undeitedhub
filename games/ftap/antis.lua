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

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if antiFireActive then
        ToggleAntiFire(false)
    end
    if antiLagActive then
        antiLagActive = false
        ApplyAntiLag(false)
    end
    oldDisable()
end