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

local function findLocalPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local plotSign = plot:FindFirstChild("PlotSign")
        if plotSign then
            local owners = plotSign:FindFirstChild("ThisPlotsOwners")
            if owners then
                for _, person in ipairs(owners:GetChildren()) do
                    if person.Value == LocalPlayer.Name then
                        return plot
                    end
                end
            end

            local owner = plotSign:FindFirstChild("Owner")
            if owner and owner.Value == LocalPlayer.Name then
                return plot
            end

            local sign = plotSign:FindFirstChild("Sign")
            if sign then
                local screen = sign:FindFirstChild("Screen")
                local surfaceGui = screen and screen:FindFirstChild("SurfaceGui")
                local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
                if frame and frame.Visible then
                    local pdn = frame:FindFirstChild("PlayerDisplayName")
                    if pdn and pdn.Text == LocalPlayer.DisplayName then
                        return plot
                    end
                end
            end
        end
    end
    return nil
end

local function findTreadmill(plotName)
    local renders = Workspace:FindFirstChild("__ClientTreadmillRenders")
    if not renders then return nil end

    local exact = renders:FindFirstChild(plotName)
    if exact then return exact end

    for _, child in ipairs(renders:GetChildren()) do
        if string.find(child.Name, plotName, 1, true) then
            return child
        end
    end

    local plotNumber = string.match(plotName, "%d+")
    if plotNumber then
        for _, child in ipairs(renders:GetChildren()) do
            if child.Name == plotNumber
                or string.find(child.Name, plotNumber, 1, true)
            then
                return child
            end
        end
    end

    return nil
end

local function getTreadmillCenter(treadmill)
    if not treadmill then return nil end
    if treadmill:IsA("BasePart") then
        return treadmill.Position
    end
    if treadmill.PrimaryPart then
        return treadmill.PrimaryPart.Position
    end

    local parts = {}
    for _, desc in ipairs(treadmill:GetDescendants()) do
        if desc:IsA("BasePart") then
            table.insert(parts, desc)
        end
    end
    if #parts == 0 then return nil end

    local sum = Vector3.new(0, 0, 0)
    for _, p in ipairs(parts) do
        sum = sum + p.Position
    end
    return sum / #parts
end

local function startAutoTreadmill()
    if treadmillTask then return end
    autoTreadmillEnabled = true
    undeitedhub.Toggles.autoTreadmill = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    treadmillTask = task.spawn(function()
        while autoTreadmillEnabled do
            pcall(function()
                if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

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

                hrp.CFrame = CFrame.new(center + Vector3.new(0, 3, 0))
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.Velocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
            end)
            task.wait(0.15)
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