local WindUI = undeltedhub.WindUI
local utils = undeltedhub.Utils
local config = undeltedhub.Config

local CombatTab = undeltedhub.Window:Tab({ Title = "Combat" })

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local targetPosition = nil

local silentAimConfig = {
    Enabled = undeltedhub.Toggles.SilentAim or false,
    TargetMode = undeltedhub.Toggles.SilentAimTargetMode or "center",
    TargetPlayer = undeltedhub.Toggles.SilentAimTargetPlayer or "None",
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
            Content = "Gamepass not owned. Distance set to 28.",
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

    local targetPlayer = nil
    if silentAimConfig.TargetPlayer ~= "None" then
        targetPlayer = Players:FindFirstChild(silentAimConfig.TargetPlayer)
        if not targetPlayer then
            silentAimConfig.TargetPlayer = "None"
            undeltedhub.Toggles.SilentAimTargetPlayer = "None"
            if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
            refreshTargetDropdown()
            return
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        if targetPlayer and player ~= targetPlayer then continue end
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
        undeltedhub.Toggles.SilentAim = state
        if state and not hookActive then
            setupHook()
        end
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
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
        undeltedhub.Toggles.SilentAimTargetMode = value
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    end
})

local targetDropdown = nil

local function getPlayerNames()
    local names = { "None" }
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            table.insert(names, player.Name)
        end
    end
    return names
end

local function refreshTargetDropdown()
    if targetDropdown then
        pcall(function() targetDropdown:Destroy() end)
        targetDropdown = nil
    end

    local names = getPlayerNames()
    local current = silentAimConfig.TargetPlayer
    local valid = false
    for _, name in ipairs(names) do
        if name == current then
            valid = true
            break
        end
    end
    if not valid then
        current = "None"
        silentAimConfig.TargetPlayer = "None"
        undeltedhub.Toggles.SilentAimTargetPlayer = "None"
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    end

    targetDropdown = CombatTab:Dropdown({
        Title = "Target Player",
        Values = names,
        Value = current,
        Callback = function(value)
            silentAimConfig.TargetPlayer = value
            undeltedhub.Toggles.SilentAimTargetPlayer = value
            if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
        end
    })
end

refreshTargetDropdown()

Players.PlayerAdded:Connect(function()
    task.wait(0.2)
    refreshTargetDropdown()
end)

Players.PlayerRemoving:Connect(function(player)
    if silentAimConfig.TargetPlayer == player.Name then
        silentAimConfig.TargetPlayer = "None"
        undeltedhub.Toggles.SilentAimTargetPlayer = "None"
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    end
    refreshTargetDropdown()
end)

undeltedhub.DisableAll = undeltedhub.DisableAll or function() end
local oldDisable = undeltedhub.DisableAll
undeltedhub.DisableAll = function()
    silentAimConfig.Enabled = false
    undeltedhub.Toggles.SilentAim = false
    if targetDropdown then
        pcall(function() targetDropdown:Destroy() end)
        targetDropdown = nil
    end
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    oldDisable()
end
