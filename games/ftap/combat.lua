local WindUI = undeitedhub.WindUI
local CombatTab = undeitedhub.Window:Tab({ Title = "Combat" })

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local targetPosition = nil

local silentAimEnabled = undeitedhub.Toggles.SilentAim or false
local AIM_DISTANCE = 30

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

local function checkGamepass()
    local success, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, 20837132)
    end)
    if success and owns then
        AIM_DISTANCE = 30
        SafeNotify({ Title = "Silent Aim", Content = "Farther Reach gamepass detected: Distance set to 30.", Duration = 3 })
    else
        AIM_DISTANCE = 28
        SafeNotify({ Title = "Silent Aim", Content = "Farther Reach gamepass not owned: Distance set to 28.", Duration = 3 })
    end
end

checkGamepass()

local function updateTarget()
    if not silentAimEnabled then
        targetPosition = nil
        return
    end

    local referencePos = UserInputService:GetMouseLocation()
    if not referencePos then return end

    local closestPart = nil
    local minScreenDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local targetPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    if targetPart then
                        local worldDist = (targetPart.Position - camera.CFrame.Position).Magnitude
                        if worldDist <= AIM_DISTANCE then
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

local oldNamecall
local hookActive = false

local function setupHook()
    if hookActive then return end
    if not pcall(function() return hookmetamethod end) then
        SafeNotify({ Title = "Silent Aim", Content = "Your executor does not support hookmetamethod.", Duration = 4 })
        return
    end

    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if silentAimEnabled and targetPosition and self == Workspace and method == "Raycast" then
            local args = { ... }
            if typeof(args[1]) == "Vector3" then
                local origin = args[1]
                local newDir = (targetPosition - origin).Unit * AIM_DISTANCE
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
    Value = silentAimEnabled,
    Callback = function(state)
        silentAimEnabled = state
        undeitedhub.Toggles.SilentAim = state
        if state and not hookActive then
            setupHook()
        end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Silent Aim", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    silentAimEnabled = false
    undeitedhub.Toggles.SilentAim = false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    oldDisable()
end

if silentAimEnabled then
    task.spawn(function()
        task.wait(0.5)
        setupHook()
    end)
end