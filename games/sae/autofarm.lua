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

local function getCharacter()
    local char = LocalPlayer.Character
    if char
        and char:FindFirstChild("HumanoidRootPart")
        and char:FindFirstChildOfClass("Humanoid")
    then
        return char
    end
    return nil
end

local function plotMatchesLocal(plot)
    local playerName = LocalPlayer.Name
    local displayName = LocalPlayer.DisplayName

    local ownerAttr = plot:GetAttribute("Owner")
    if ownerAttr == playerName or ownerAttr == displayName then
        return true
    end

    local plotSign = plot:FindFirstChild("PlotSign")

    if plotSign then
        local owners = plotSign:FindFirstChild("ThisPlotsOwners")
        if owners then
            for _, person in ipairs(owners:GetChildren()) do
                if person.Value == playerName or person.Value == displayName then
                    return true
                end
            end
        end

        for _, child in ipairs(plotSign:GetChildren()) do
            if child:IsA("StringValue") then
                if child.Value == playerName or child.Value == displayName then
                    return true
                end
            end
        end
    end

    local sign = plot:FindFirstChild("Sign")
        or (plotSign and plotSign:FindFirstChild("Sign"))
    if sign then
        local screen = sign:FindFirstChild("Screen")
        local surfaceGui = screen and (
            screen:FindFirstChild("SurfaceGui")
            or screen:FindFirstChildOfClass("SurfaceGui")
        )
        if surfaceGui then
            local frame = surfaceGui:FindFirstChild("Frame")
            if frame and frame.Visible then
                local pdn = frame:FindFirstChild("PlayerDisplayName")
                if pdn and (pdn.Text == displayName or pdn.Text == playerName) then
                    return true
                end
            end
        end
    end

    return false
end

local function findLocalPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        if plotMatchesLocal(plot) then
            return plot
        end
    end
    return nil
end

local function findTreadmill(plotName)
    local renders = Workspace:FindFirstChild("__ClientTreadmillRenders")
    if not renders then return nil end

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

    if treadmill:IsA("BasePart") then
        return treadmill.Position
    end

    local bbox = treadmill:FindFirstChild("BoundingBoxPart", true)
    if bbox and bbox:IsA("BasePart") then
        return bbox.Position
    end

    local root = treadmill:FindFirstChild("Root", true)
    if root and root:IsA("BasePart") then
        return root.Position
    end

    if treadmill.PrimaryPart then
        return treadmill.PrimaryPart.Position
    end

    local sum = Vector3.new(0, 0, 0)
    local count = 0
    for _, desc in ipairs(treadmill:GetDescendants()) do
        if desc:IsA("BasePart") then
            sum = sum + desc.Position
            count = count + 1
        end
    end
    if count == 0 then return nil end
    return sum / count
end

local function teleportToTreadmill()
    local char = getCharacter()
    if not char then return end

    local hrp = char.HumanoidRootPart
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    local plot = findLocalPlot()
    if not plot then return end

    local treadmill = findTreadmill(plot.Name)
    if not treadmill then return end

    local center = getTreadmillCenter(treadmill)
    if not center then return end

    local targetPos = center + Vector3.new(0, 3, 0)

    if (hrp.Position - targetPos).Magnitude > 0.5 then
        hrp.CFrame = CFrame.new(targetPos)
    end

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero
end

local function startAutoTreadmill()
    if treadmillTask then return end
    autoTreadmillEnabled = true
    undeitedhub.Toggles.autoTreadmill = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    treadmillTask = task.spawn(function()
        while autoTreadmillEnabled do
            pcall(function()
                if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                    teleportToTreadmill()
                end
            end)
            task.wait(0.1)
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
        end
        SafeNotify({
            Title = "Auto Treadmill",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
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