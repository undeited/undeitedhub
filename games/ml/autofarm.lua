local WindUI = undeitedhub.WindUI
local AutoTab = undeitedhub.Window:Tab({ Title = "Autofarm" })

local function getTool(player, toolName)
    local char = player.Character
    if char then
        local tool = char:FindFirstChild(toolName)
        if tool then return tool end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        return backpack:FindFirstChild(toolName)
    end
    return nil
end

local function equipTool(player, toolName)
    local char = player.Character
    if not char then return false end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end
    local tool = char:FindFirstChild(toolName)
    if tool then return true end
    tool = backpack:FindFirstChild(toolName)
    if tool then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and t.Name ~= toolName then
                t.Parent = backpack
            end
        end
        tool.Parent = char
        task.wait(0.02)
        return true
    end
    return false
end

local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function startAutoActivity(toggleName, toolName)
    local enabled = undeitedhub.Toggles[toggleName] or false
    local taskRef = nil
    local running = false

    local function activityLoop()
        local player = game:GetService("Players").LocalPlayer
        while running do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE and isAlive(player) then
                local character = player.Character
                local backpack = player:FindFirstChild("Backpack")
                if backpack then
                    if not equipTool(player, toolName) then
                        task.wait(0.2)
                        continue
                    end
                    local tool = getTool(player, toolName)
                    if tool and tool.Parent == character then
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
            end
            task.wait(0.1)
        end
        taskRef = nil
    end

    local function start()
        if running then return end
        running = true
        enabled = true
        undeitedhub.Toggles[toggleName] = true
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        taskRef = task.spawn(activityLoop)
    end

    local function stop()
        running = false
        enabled = false
        undeitedhub.Toggles[toggleName] = false
        if taskRef then
            task.cancel(taskRef)
            taskRef = nil
        end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    end

    AutoTab:Toggle({
        Title = "Auto " .. toolName,
        Value = enabled,
        Callback = function(state)
            if state then start() else stop() end
        end
    })

    if enabled then start() end

    return { start = start, stop = stop }
end

local handstand = startAutoActivity("AutoHandstand", "Handstands")
local situps = startAutoActivity("AutoSitups", "Situps")
local pushups = startAutoActivity("AutoPushups", "Pushups")
local weight = startAutoActivity("AutoWeight", "Weight")
local punch = startAutoActivity("AutoPunch", "Punch")

local rebirthEnabled = undeitedhub.Toggles.AutoRebirth or false
local rebirthTask = nil

local function startRebirth()
    if rebirthTask then return end
    rebirthEnabled = true
    undeitedhub.Toggles.AutoRebirth = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    rebirthTask = task.spawn(function()
        local replicatedStorage = game:GetService("ReplicatedStorage")
        while rebirthEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local remote = replicatedStorage:FindFirstChild("rEvents") and replicatedStorage.rEvents:FindFirstChild("rebirthRemote")
                if remote then
                    pcall(function()
                        remote:InvokeServer("rebirthRequest")
                    end)
                end
            end
            task.wait(0.1)
        end
        rebirthTask = nil
    end)
end

local function stopRebirth()
    rebirthEnabled = false
    undeitedhub.Toggles.AutoRebirth = false
    if rebirthTask then
        task.cancel(rebirthTask)
        rebirthTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

AutoTab:Toggle({
    Title = "Auto Rebirth",
    Value = rebirthEnabled,
    Callback = function(state)
        if state then startRebirth() else stopRebirth() end
    end
})

if rebirthEnabled then startRebirth() end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    punch.stop()
    handstand.stop()
    situps.stop()
    pushups.stop()
    weight.stop()
    if rebirthEnabled then stopRebirth() end
    oldDisable()
end