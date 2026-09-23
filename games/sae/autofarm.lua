local WindUI = undeitedhub.WindUI
local AutofarmTab = undeitedhub.Window:Tab({ Title = "Autofarm" })

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
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

local LEAVE_THRESHOLD = 8
local CHECK_INTERVAL = 0.25

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

local function getTreadmillCenter(treadmill)
    if not treadmill then return nil end
    if treadmill:IsA("BasePart") then return treadmill.Position end

    local bbox = treadmill:FindFirstChild("BoundingBoxPart", true)
    if bbox and bbox:IsA("BasePart") then return bbox.Position end

    local root = treadmill:FindFirstChild("Root", true)
    if root and root:IsA("BasePart") then return root.Position end

    if treadmill.PrimaryPart then return treadmill.PrimaryPart.Position end

    return getModelCenter(treadmill)
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
    if not treadmill then
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

    local _, center, err = resolveTreadmill()
    if not center then return false, err end

    local target = center + Vector3.new(0, 3, 0)
    hrp.CFrame = CFrame.new(target)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero

    return true, "ok", center
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
        local failureCount = 0
        local lastReason = ""

        while autoTreadmillEnabled do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if not hrp or not hum or hum.Health <= 0 then
                anchored = false
                anchorCenter = nil
                task.wait(CHECK_INTERVAL)
                continue
            end

            if not anchored then
                local ok, result, center = pcall(teleportOnce)
                if ok and result == true then
                    anchored = true
                    anchorCenter = center
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
                if dist > LEAVE_THRESHOLD then
                    anchored = false
                    anchorCenter = nil
                end
            end

            task.wait(CHECK_INTERVAL)
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