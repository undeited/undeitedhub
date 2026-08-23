local WindUI = bandithub.WindUI
local utils = bandithub.Utils
local config = bandithub.Config

local CombatTab = bandithub.Window:Tab({ Title = "Combat" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local aero = ReplicatedStorage:FindFirstChild("Aero")
local aeroRemoteServices = aero and aero:FindFirstChild("AeroRemoteServices")
local gameService = aeroRemoteServices and aeroRemoteServices:FindFirstChild("GameService")
local AttackStart = gameService and gameService:FindFirstChild("WeaponAttackStart")
local AnimComplete = gameService and gameService:FindFirstChild("WeaponAnimComplete")

local remotesExist = AttackStart and AnimComplete

if not remotesExist then
    CombatTab:Label({
        Title = "Combat features are not available in this game.",
    })
    pcall(function()
        CombatTab:Section({
            Title = "Unavailable",
            Description = "This game does not support auto-swing or other combat features.",
        })
    end)
else
    local autoSwingEnabled = bandithub.Toggles.AutoSwing or false
    local lastSwingTime = 0
    local SWING_COOLDOWN = 0.1

    local function SwingWeapon()
        AttackStart:FireServer()
        AnimComplete:FireServer()
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
end

bandithub.DisableAll = bandithub.DisableAll or function() end
local oldDisable = bandithub.DisableAll
bandithub.DisableAll = function()
    if remotesExist then
        autoSwingEnabled = false
        bandithub.Toggles.AutoSwing = false
        if bandithub.SaveSettings then bandithub.SaveSettings() end
    end
    oldDisable()
end