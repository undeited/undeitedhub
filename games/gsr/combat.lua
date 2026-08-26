local WindUI = undeltedhub.WindUI
local utils = undeltedhub.Utils
local config = undeltedhub.Config

local CombatTab = undeltedhub.Window:Tab({ Title = "Combat" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AeroServices = ReplicatedStorage:WaitForChild("Aero"):WaitForChild("AeroRemoteServices"):WaitForChild("GameService")
local AttackStart = AeroServices:WaitForChild("WeaponAttackStart")
local AnimComplete = AeroServices:WaitForChild("WeaponAnimComplete")

local autoSwingEnabled = undeltedhub.Toggles.AutoSwing or false
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
    if autoSwingEnabled and _G.UNDELTEDHUB_WINDOW_VISIBLE then
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
        undeltedhub.Toggles.AutoSwing = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
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

undeltedhub.DisableAll = undeltedhub.DisableAll or function() end
local oldDisable = undeltedhub.DisableAll
undeltedhub.DisableAll = function()
    autoSwingEnabled = false
    undeltedhub.Toggles.AutoSwing = false
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    oldDisable()
end