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
    else
        AIM_DISTANCE = 28
    end
end

checkGamepass()

local frameCounter = 0
local cachedTargets = {}
local cachedTargetsDirty = true

local function markTargetsDirty()
    cachedTargetsDirty = true
end

local function rebuildTargetCache()
    cachedTargets = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local parts = {}
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            table.insert(parts, part)
                        end
                    end
                    if #parts > 0 then
                        table.insert(cachedTargets, parts)
                    end
                end
            end
        end
    end
    cachedTargetsDirty = false
end

local function updateTarget()
    if not silentAimEnabled then
        targetPosition = nil
        return
    end

    frameCounter = frameCounter + 1
    if frameCounter % 5 ~= 0 then return end

    if cachedTargetsDirty then
        rebuildTargetCache()
    end

    local referencePos = UserInputService:GetMouseLocation()
    if not referencePos then return end

    local cameraCFrame = camera.CFrame
    local cameraPos = cameraCFrame.Position
    local cameraLook = cameraCFrame.LookVector

    local closestPart = nil
    local minScreenDist = math.huge

    for _, parts in ipairs(cachedTargets) do
        for _, part in ipairs(parts) do
            if part.Parent then
                local partPos = part.Position
                local rel = partPos - cameraPos
                local worldDist = rel.Magnitude
                if worldDist <= AIM_DISTANCE then
                    if rel.Unit:Dot(cameraLook) > 0 then
                        local screenPos, onScreen = camera:WorldToViewportPoint(partPos)
                        if onScreen then
                            local dx = screenPos.X - referencePos.X
                            local dy = screenPos.Y - referencePos.Y
                            local screenDist = math.sqrt(dx * dx + dy * dy)
                            if screenDist < minScreenDist then
                                minScreenDist = screenDist
                                closestPart = part
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
                return oldNamecall(self, table.unpack(args))
            end
        end
        return oldNamecall(self, ...)
    end))
    hookActive = true
end

local renderConnection = RunService.RenderStepped:Connect(updateTarget)

Players.PlayerAdded:Connect(markTargetsDirty)
Players.PlayerRemoving:Connect(function(player)
    if player == localPlayer then return end
    markTargetsDirty()
end)

local function watchCharacter(player)
    if player == localPlayer then return end
    player.CharacterAdded:Connect(function()
        task.wait(0.2)
        markTargetsDirty()
    end)
    player.CharacterRemoving:Connect(markTargetsDirty)
end

for _, player in ipairs(Players:GetPlayers()) do
    watchCharacter(player)
end

CombatTab:Toggle({
    Title = "Silent Aim",
    Value = silentAimEnabled,
    Callback = function(state)
        silentAimEnabled = state
        undeitedhub.Toggles.SilentAim = state
        if state and not hookActive then
            setupHook()
        end
        if state then
            markTargetsDirty()
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
        markTargetsDirty()
    end)
end
