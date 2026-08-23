local WindUI = bandithub.WindUI
local utils = bandithub.Utils
local config = bandithub.Config

local CombatTab = bandithub.Window:Tab({ Title = "Combat" })

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local targetPosition = nil

local silentAimConfig = {
    Enabled = bandithub.Toggles.SilentAim or false,
    TargetMode = bandithub.Toggles.SilentAimTargetMode or "cursor",
    Distance = 28,
}

task.spawn(function()
    local success, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, 20837132)
    end)
    if success and owns then
        silentAimConfig.Distance = 30
        WindUI:Notify({
            Title = "Silent Aim",
            Content = "Gamepass detected! Distance set to 30.",
            Duration = 3,
        })
    else
        silentAimConfig.Distance = 28
        WindUI:Notify({
            Title = "Silent Aim",
            Content = "No gamepass detected! Distance set to 28.",
            Duration = 3,
        })
    end
end)

local function updateTarget()
    if not silentAimConfig.Enabled then
        targetPosition = nil
        return
    end

    local referencePos
    if silentAimConfig.TargetMode == "cursor" then
        referencePos = UserInputService:GetMouseLocation()
    else
        referencePos = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    end

    if not referencePos then return end

    local closestPart = nil
    local minScreenDist = math.huge
    local distanceLimit = silentAimConfig.Distance

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local targetPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    if targetPart then
                        local worldDist = (targetPart.Position - camera.CFrame.Position).Magnitude
                        if worldDist <= distanceLimit then
                            local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                            if onScreen then
                                local screenVec = Vector2.new(screenPos.X, screenPos.Y)
                                local screenDist = (screenVec - referencePos).Magnitude
                                if screenDist < minScreenDist then
                                    minScreenDist = screenDist
                                    closestPart = targetPart
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    targetPosition = closestPart and closestPart.Position or nil
end

local oldNamecall = nil
local hookActive = false

local function setupHook()
    if hookActive then return end
    if not pcall(function() return hookmetamethod end) then
        WindUI:Notify({
            Title = "Silent Aim",
            Content = "Your executor does not support hookmetamethod.",
            Duration = 4,
        })
        return
    end

    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if silentAimConfig.Enabled and targetPosition and self == Workspace and method == "Raycast" then
            local args = { ... }
            if typeof(args[1]) == "Vector3" then
                local origin = args[1]
                local newDir = (targetPosition - origin).Unit * silentAimConfig.Distance
                args[2] = newDir
                return oldNamecall(self, unpack(args))
            end
        end
        return oldNamecall(self, ...)
    end))
    hookActive = true
end

local renderConnection = RunService.RenderStepped:Connect(updateTarget)

CombatTab:Toggle({
    Title = "Silent Aim",
    Value = silentAimConfig.Enabled,
    Callback = function(state)
        silentAimConfig.Enabled = state
        bandithub.Toggles.SilentAim = state
        if state and not hookActive then
            setupHook()
        end
        if bandithub.SaveSettings then bandithub.SaveSettings() end
        WindUI:Notify({
            Title = "Silent Aim",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

CombatTab:Dropdown({
    Title = "Target Mode",
    Values = { "cursor", "center" },
    Value = silentAimConfig.TargetMode,
    Callback = function(value)
        silentAimConfig.TargetMode = value
        bandithub.Toggles.SilentAimTargetMode = value
        if bandithub.SaveSettings then bandithub.SaveSettings() end
    end
})

bandithub.DisableAll = bandithub.DisableAll or function() end
local oldDisable = bandithub.DisableAll
bandithub.DisableAll = function()
    silentAimConfig.Enabled = false
    bandithub.Toggles.SilentAim = false
    if bandithub.SaveSettings then bandithub.SaveSettings() end
    oldDisable()
end