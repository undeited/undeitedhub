local WindUI = bandithub.WindUI

if not bandithub.Window or type(bandithub.Window.Tab) ~= "function" then
    error("bandithub.Window is not available or missing Tab method")
end

local CombatTab = bandithub.Window:Tab({ Title = "Combat" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AeroServices = ReplicatedStorage:WaitForChild("Aero"):WaitForChild("AeroRemoteServices"):WaitForChild("GameService")
local AttackStart = AeroServices:WaitForChild("WeaponAttackStart")
local AnimComplete = AeroServices:WaitForChild("WeaponAnimComplete")

local autoSwingEnabled = bandithub.Toggles.AutoSwing or false
local lastSwingTime = 0
local SWING_COOLDOWN = 0.1

local function SwingWeapon()
    AttackStart:FireServer()
    AnimComplete:FireServer()
    if typeof(getNil) == "function" then
        pcall(function()
            getNil("Event", "BindableEvent"):Fire()
        end)
    end
end

game:GetService("RunService").Heartbeat:Connect(function()
    if autoSwingEnabled and _G.BANDITHUB_WINDOW_VISIBLE then
        local now = tick()
        if now - lastSwingTime >= SWING_COOLDOWN then
            lastSwingTime = now
            pcall(SwingWeapon)
        end
    end
end)

CombatTab:Toggle({
    Title = "Auto Swing",
    Value = autoSwingEnabled,
    Callback = function(state)
        autoSwingEnabled = state
        bandithub.Toggles.AutoSwing = state
        if bandithub.SaveSettings then bandithub.SaveSettings() end
        WindUI:Notify({
            Title = "Auto Swing",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
        if state then
            lastSwingTime = tick()
        end
    end
})

bandithub.DisableAll = bandithub.DisableAll or function() end
local oldDisable = bandithub.DisableAll
bandithub.DisableAll = function()
    autoSwingEnabled = false
    bandithub.Toggles.AutoSwing = false
    if bandithub.SaveSettings then bandithub.SaveSettings() end
    oldDisable()
end
