local WindUI = undeitedhub.WindUI

local CombatTab = undeitedhub.Window:Tab({ Title = "Combat" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AeroServices = ReplicatedStorage:WaitForChild("Aero"):WaitForChild("AeroRemoteServices"):WaitForChild("GameService")
local AttackStart = AeroServices:WaitForChild("WeaponAttackStart")
local AnimComplete = AeroServices:WaitForChild("WeaponAnimComplete")

local autoSwingEnabled = undeitedhub.Toggles.AutoSwing or false
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
    if autoSwingEnabled and _G.UNDEITEDHUB_WINDOW_VISIBLE then
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
        undeitedhub.Toggles.AutoSwing = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
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

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    autoSwingEnabled = false
    undeitedhub.Toggles.AutoSwing = false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    oldDisable()
end