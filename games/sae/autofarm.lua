local WindUI = undeitedhub.WindUI
local AutofarmTab = undeitedhub.Window:Tab({ Title = "Autofarm" })

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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

local autoTreadmillEnabled = undeitedhub.Toggles.autoTreadmill or false
local treadmillTask = nil
local cachedPlot = nil

local function getModelCenter(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model.Position end
    local bbox = model:FindFirstChild("BoundingBoxPart", true)
    if bbox and bbox:IsA("BasePart") then return bbox.Position end
    if model.PrimaryPart then return model.PrimaryPart.Position end
    local sum = Vector3.new(0, 0, 0)
    local count = 0
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            sum = sum + d.Position
            count = count + 1
        end
    end
    if count == 0 then return nil end
    return sum / count
end

local function getTreadmillSize(treadmill)
    if not treadmill then return nil end
    if treadmill:IsA("BasePart") then
        local s = treadmill.Size
        return math.max(s.X, s.Z)
    end
    local bbox = treadmill:FindFirstChild("BoundingBoxPart", true)
    if bbox and bbox:IsA("BasePart") then
        local s = bbox.Size
        return math.max(s.X, s.Z)
    end
    local ok, size = pcall(function() return treadmill:GetExtentsSize() end)
    if ok and size then
        return math.max(size.X, size.Z)
    end
    return nil
end

local function getTreadmillCenter(treadmill)
    if not treadmill then return nil end
    if treadmill:IsA("BasePart") then return treadmill.Position end

    local bbox = treadmill:FindFirstChild("BoundingBoxPart", true)
    if bbox and bbox:IsA("BasePart") then
        return bbox.Position
    end

    local meshParts = {}
    local topY = -math.huge
    local minX, maxX = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge
    for _, d in ipairs(treadmill:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = d.Name
            if n:find("Cube") or n:find("Treadmill") or n:find("Mesh") then
                table.insert(meshParts, d)
                if d.Position.Y > topY then topY = d.Position.Y end
                if d.Position.X < minX then minX = d.Position.X end
                if d.Position.X > maxX then maxX = d.Position.X end
                if d.Position.Z < minZ then minZ = d.Position.Z end
                if d.Position.Z > maxZ then maxZ = d.Position.Z end
            end
        end
    end
    if #meshParts > 0 then
        local cx = (minX + maxX) / 2
        local cz = (minZ + maxZ) / 2
        return Vector3.new(cx, topY, cz)
    end

    local root = treadmill:FindFirstChild("Root", true)
    if root and root:IsA("BasePart") then
        return root.Position
    end

    if treadmill.PrimaryPart then
        return treadmill.PrimaryPart.Position
    end

    return getModelCenter(treadmill)
end

local function plotHasLocalOwner(plot)
    local playerName = LocalPlayer.Name
    local displayName = LocalPlayer.DisplayName
    local userId = LocalPlayer.UserId
    local userIdStr = tostring(userId)

    local attr = plot:GetAttribute("Owner")
    if attr == playerName or attr == displayName or attr == userId or attr == userIdStr then
        return true
    end

    local attr2 = plot:GetAttribute("PlotOwner")
    if attr2 == playerName or attr2 == displayName or attr2 == userId or attr2 == userIdStr then
        return true
    end

    local plotSign = plot:FindFirstChild("PlotSign")
    if plotSign then
        local owners = plotSign:FindFirstChild("ThisPlotsOwners")
        if owners then
            for _, v in ipairs(owners:GetChildren()) do
                if v.Value == playerName or v.Value == displayName or v.Value == userId or v.Value == userIdStr then
                    return true
                end
            end
        end

        local ownerVal = plotSign:FindFirstChild("Owner") or plotSign:FindFirstChild("PlotOwner")
        if ownerVal then
            if ownerVal.Value == playerName or ownerVal.Value == displayName or ownerVal.Value == userId or ownerVal.Value == userIdStr then
                return true
            end
        end

        local sign = plotSign:FindFirstChild("Sign")
        if sign then
            local screen = sign:FindFirstChild("Screen")
            local sg = screen and (screen:FindFirstChild("SurfaceGui") or screen:FindFirstChildOfClass("SurfaceGui"))
            if sg then
                local frame = sg:FindFirstChild("Frame")
                if frame and frame.Visible then
                    local pdn = frame:FindFirstChild("PlayerDisplayName")
                    if pdn and (pdn.Text == displayName or pdn.Text == playerName) then
                        return true
                    end
                end
            end
        end
    end

    for _, desc in ipairs(plot:GetDescendants()) do
        if desc:IsA("ObjectValue") and desc.Value == LocalPlayer then
            return true
        end
        if desc:IsA("StringValue") then
            local val = desc.Value
            if val == playerName or val == displayName or val == userIdStr then
                local n = string.lower(desc.Name)
                if n:find("owner") or n:find("player") or n:find("user") or n:find("claim") or n:find("belong") then
                    return true
                end
            end
        end
        if desc:IsA("BoolValue") and desc.Value then
            if desc.Name == playerName or desc.Name == displayName then
                return true
            end
        end
    end

    return false
end

local function findLocalPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil, "no Plots folder" end

    for _, plot in ipairs(plots:GetChildren()) do
        if plotHasLocalOwner(plot) then
            return plot, "owner"
        end
    end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local nearest, nearestDist = nil, math.huge
        for _, plot in ipairs(plots:GetChildren()) do
            local center = getModelCenter(plot)
            if center then
                local d = (hrp.Position - center).Magnitude
                if d < nearestDist then
                    nearestDist = d
                    nearest = plot
                end
            end
        end
        if nearest and nearestDist < 300 then
            return nearest, "nearest (" .. math.floor(nearestDist) .. " studs)"
        end
    end

    return nil, "no owner match, no nearby plot"
end

local function findTreadmill(plotName)
    local renders = Workspace:FindFirstChild("__ClientTreadmillRenders")
    if not renders then return nil end

    local exact = renders:FindFirstChild("TreadmillRenderer_" .. plotName)
    if exact then return exact end

    local plotNumber = tonumber(string.match(plotName, "%d+"))
    if not plotNumber then return nil end

    for _, child in ipairs(renders:GetChildren()) do
        local childNumber = tonumber(string.match(child.Name, "(%d+)$"))
        if childNumber == plotNumber then
            return child
        end
    end

    return nil
end

local function resolveTreadmill()
    if not cachedPlot or not cachedPlot.Parent then
        cachedPlot = nil
        local plot = findLocalPlot()
        if plot then
            cachedPlot = plot
        end
    end
    if not cachedPlot then
        return nil, nil, "no plot"
    end

    local treadmill = findTreadmill(cachedPlot.Name)
    if not treadmill or not treadmill.Parent then
        return nil, nil, "no treadmill for plot " .. cachedPlot.Name
    end

    local center = getTreadmillCenter(treadmill)
    if not center then
        return nil, nil, "no treadmill center"
    end

    return treadmill, center, nil
end

local function teleportOnce()
    local char = LocalPlayer.Character
    if not char then return false, "no character" end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false, "no hrp/hum" end

    local treadmill, center, err = resolveTreadmill()
    if not center then return false, err end

    local target = center + Vector3.new(0, 3, 0)
    hrp.CFrame = CFrame.new(target)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero

    return true, center, treadmill
end

local function isCharacterSettled(hrp, hum)
    if not hrp or not hum or hum.Health <= 0 then return false end
    return hrp.AssemblyLinearVelocity.Magnitude < 3
        and hrp.AssemblyAngularVelocity.Magnitude < 3
end

local function startAutoTreadmill()
    if treadmillTask then return end
    autoTreadmillEnabled = true
    undeitedhub.Toggles.autoTreadmill = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    SafeNotify({
        Title = "Auto Treadmill",
        Content = "Searching for your plot...",
        Duration = 2,
    })

    treadmillTask = task.spawn(function()
        local anchored = false
        local anchorCenter = nil
        local anchorTreadmill = nil
        local leaveThreshold = 8
        local failureCount = 0
        local lastReason = ""
        local lastCharacter = nil
        local lastHealth = nil
        local needsSettle = false
        local settleStart = 0
        local settleLogged = false

        while autoTreadmillEnabled do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if char ~= lastCharacter then
                lastCharacter = char
                anchored = false
                anchorCenter = nil
                anchorTreadmill = nil
                failureCount = 0
                lastHealth = nil
                needsSettle = true
                settleStart = tick()
                settleLogged = false
            end

            if not hrp or not hum then
                anchored = false
                anchorCenter = nil
                anchorTreadmill = nil
                needsSettle = true
                settleStart = tick()
                settleLogged = false
                RunService.Heartbeat:Wait()
                continue
            end

            local health = hum.Health

            if health <= 0 then
                if lastHealth and lastHealth > 0 then
                    anchored = false
                    anchorCenter = nil
                    anchorTreadmill = nil
                end
                lastHealth = health
                needsSettle = true
                settleStart = tick()
                settleLogged = false
                RunService.Heartbeat:Wait()
                continue
            end

            lastHealth = health

            if needsSettle then
                local elapsed = tick() - settleStart
                local settled = isCharacterSettled(hrp, hum)

                if elapsed < 0.15 or not settled then
                    if elapsed > 3 then
                        needsSettle = false
                    else
                        if not settleLogged and elapsed > 0.3 then
                            settleLogged = true
                            SafeNotify({
                                Title = "Auto Treadmill",
                                Content = "Waiting for character to settle...",
                                Duration = 1.5,
                            })
                        end
                        RunService.Heartbeat:Wait()
                        continue
                    end
                end

                if needsSettle then
                    needsSettle = false
                    SafeNotify({
                        Title = "Auto Treadmill",
                        Content = "Respawned - re-anchoring...",
                        Duration = 2,
                    })
                end
            end

            if anchorTreadmill and not anchorTreadmill.Parent then
                anchored = false
                anchorCenter = nil
                anchorTreadmill = nil
            end

            if not anchored then
                local ok, result, center, treadmill = pcall(teleportOnce)
                if ok and result == true then
                    anchored = true
                    anchorCenter = center
                    anchorTreadmill = treadmill

                    local size = getTreadmillSize(treadmill)
                    if size and size > 0 then
                        leaveThreshold = math.max(6, size * 1.5)
                    else
                        leaveThreshold = 8
                    end

                    failureCount = 0
                    SafeNotify({
                        Title = "Auto Treadmill",
                        Content = "Active on plot " .. (cachedPlot and cachedPlot.Name or "?"),
                        Duration = 2,
                    })
                else
                    failureCount = failureCount + 1
                    lastReason = tostring(result or "error")
                    if failureCount == 30 then
                        SafeNotify({
                            Title = "Auto Treadmill",
                            Content = "Waiting: " .. lastReason,
                            Duration = 3,
                        })
                    end
                    if failureCount >= 60 then
                        cachedPlot = nil
                    end
                end
            else
                local dist = (hrp.Position - anchorCenter).Magnitude
                if dist > leaveThreshold then
                    anchored = false
                    anchorCenter = nil
                    anchorTreadmill = nil
                end
            end

            RunService.Heartbeat:Wait()
        end

        treadmillTask = nil
    end)
end

local function stopAutoTreadmill()
    autoTreadmillEnabled = false
    undeitedhub.Toggles.autoTreadmill = false
    if treadmillTask then
        task.cancel(treadmillTask)
        treadmillTask = nil
    end
    cachedPlot = nil
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

AutofarmTab:Toggle({
    Title = "Auto Treadmill",
    Value = autoTreadmillEnabled,
    Callback = function(state)
        if state then
            startAutoTreadmill()
        else
            stopAutoTreadmill()
            SafeNotify({
                Title = "Auto Treadmill",
                Content = "Disabled",
                Duration = 2,
            })
        end
    end
})

if autoTreadmillEnabled then
    startAutoTreadmill()
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoTreadmillEnabled then
        stopAutoTreadmill()
    end
    oldDisable()
end