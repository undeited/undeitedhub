local WindUI = undeitedhub.WindUI
local CombatTab = undeitedhub.Window:Tab({ Title = "Combat" })

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

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

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local Tuning = {
    lastUpdate = 0,
    refreshInterval = 2,
    ping = 0,
    pingFactor = 0,
    playerFactor = 0,
    players = 1,
}

local function readPing()
    local ok, ping = pcall(function()
        if Stats and Stats.Network and Stats.Network.ServerStatsItem then
            local item = Stats.Network.ServerStatsItem["Data Ping"]
            if item then return item:GetValue() / 1000 end
        end
        return 0
    end)
    if not ok or type(ping) ~= "number" or ping ~= ping then return 0 end
    return ping
end

local function refreshTuning()
    local now = tick()
    if Tuning.lastUpdate > 0 and now - Tuning.lastUpdate < Tuning.refreshInterval then return end
    Tuning.lastUpdate = now

    local ping = readPing()
    local players = math.max(1, #Players:GetPlayers())

    local pingFactor = clamp(ping / 0.2, 0, 2)
    local playerFactor = clamp((players - 1) / 12, 0, 2)

    Tuning.ping = ping
    Tuning.pingFactor = pingFactor
    Tuning.playerFactor = playerFactor
    Tuning.players = players

    Tuning.aimDistance = clamp(30 * (1 + playerFactor * 0.4), 25, 80)
    Tuning.cacheRebuildFrames = math.max(2, math.floor(5 - playerFactor * 2))
    Tuning.maxCandidatesToCheck = math.max(3, math.floor(5 + playerFactor * 3))
    Tuning.minLosDot = clamp(0.1 + pingFactor * 0.1, 0.05, 0.4)
end

refreshTuning()

local silentAimEnabled = undeitedhub.Toggles.SilentAim or false
local targetPosition = nil
local checkingLOS = false

local frameCounter = 0
local cachedTargets = {}
local cachedTargetsDirty = true

local function markTargetsDirty()
    cachedTargetsDirty = true
end

local function rebuildTargetCache()
    cachedTargets = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
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
                        table.insert(cachedTargets, {
                            parts = parts,
                            character = char,
                            player = player,
                        })
                    end
                end
            end
        end
    end
    cachedTargetsDirty = false
end

local function raycastNoHook(origin, direction, params)
    checkingLOS = true
    local ok, result = pcall(function()
        return Workspace:Raycast(origin, direction, params)
    end)
    checkingLOS = false
    if not ok then return nil end
    return result
end

local function hasLineOfSight(origin, targetPos, targetCharacter)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filter = {}
    if LocalPlayer.Character then
        table.insert(filter, LocalPlayer.Character)
    end
    if targetCharacter then
        table.insert(filter, targetCharacter)
    end
    params.FilterDescendantsInstances = filter
    params.IgnoreWater = true

    local direction = targetPos - origin
    local result = raycastNoHook(origin, direction, params)
    return result == nil
end

local function getLosOrigin()
    local char = LocalPlayer.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head.Position end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp.Position end
    return nil
end

local function updateTarget()
    if not silentAimEnabled then
        targetPosition = nil
        return
    end

    frameCounter = frameCounter + 1
    if frameCounter % Tuning.cacheRebuildFrames ~= 0 then return end

    if cachedTargetsDirty then
        rebuildTargetCache()
    end

    local origin = getLosOrigin()
    if not origin then
        targetPosition = nil
        return
    end

    local cam = Workspace.CurrentCamera
    if not cam then
        targetPosition = nil
        return
    end

    local referencePos = UserInputService:GetMouseLocation()
    if not referencePos then return end

    local cameraPos = cam.CFrame.Position
    local cameraLook = cam.CFrame.LookVector

    local candidates = {}

    for _, entry in ipairs(cachedTargets) do
        for _, part in ipairs(entry.parts) do
            if part.Parent then
                local partPos = part.Position
                local rel = partPos - cameraPos
                local worldDist = rel.Magnitude
                if worldDist <= Tuning.aimDistance then
                    if rel.Unit:Dot(cameraLook) > 0 then
                        local screenPos, onScreen = cam:WorldToViewportPoint(partPos)
                        if onScreen then
                            local dx = screenPos.X - referencePos.X
                            local dy = screenPos.Y - referencePos.Y
                            local screenDist = math.sqrt(dx * dx + dy * dy)
                            table.insert(candidates, {
                                part = part,
                                pos = partPos,
                                screenDist = screenDist,
                                character = entry.character,
                            })
                        end
                    end
                end
            end
        end
    end

    if #candidates == 0 then
        targetPosition = nil
        return
    end

    table.sort(candidates, function(a, b)
        return a.screenDist < b.screenDist
    end)

    local maxCheck = math.min(#candidates, Tuning.maxCandidatesToCheck)
    for i = 1, maxCheck do
        local candidate = candidates[i]
        if hasLineOfSight(origin, candidate.pos, candidate.character) then
            targetPosition = candidate.pos
            return
        end
    end

    targetPosition = nil
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
        if silentAimEnabled and targetPosition and not checkingLOS and self == Workspace and method == "Raycast" then
            local args = { ... }
            if typeof(args[1]) == "Vector3" then
                local origin = args[1]
                local newDir = (targetPosition - origin).Unit * Tuning.aimDistance
                args[2] = newDir
                return oldNamecall(self, table.unpack(args))
            end
        end
        return oldNamecall(self, ...)
    end))
    hookActive = true
end

local renderConnection = RunService.RenderStepped:Connect(function()
    pcall(updateTarget)
end)

Players.PlayerAdded:Connect(markTargetsDirty)
Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then return end
    markTargetsDirty()
end)

local function watchCharacter(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function()
        task.wait(0.2)
        markTargetsDirty()
    end)
    player.CharacterRemoving:Connect(markTargetsDirty)
end

for _, player in ipairs(Players:GetPlayers()) do
    watchCharacter(player)
end

Players.PlayerAdded:Connect(watchCharacter)

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
            refreshTuning()
            markTargetsDirty()
        else
            targetPosition = nil
        end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Silent Aim", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    silentAimEnabled = false
    targetPosition = nil
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
