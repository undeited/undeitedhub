local WindUI = undeltedhub.WindUI
local AutoTab = undeltedhub.Window:Tab({ Title = "Autofarm" })

local function equipTool(player, toolName)
    local char = player.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end

    local tool = char:FindFirstChild(toolName)
    if tool and humanoid.ActiveTool == tool then
        return true
    end

    if tool then
        humanoid:EquipTool(tool)
        task.wait(0.05)
        if humanoid.ActiveTool == tool then
            return true
        end
    end

    tool = backpack:FindFirstChild(toolName)
    if tool then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and t ~= tool then
                t.Parent = backpack
            end
        end
        tool.Parent = char
        task.wait(0.05)
        humanoid:EquipTool(tool)
        task.wait(0.05)
        if humanoid.ActiveTool == tool then
            return true
        end
    end
    return false
end

local handstandEnabled = undeltedhub.Toggles.AutoHandstand or false
local handstandTask = nil

local function startHandstand()
    if handstandTask then return end
    handstandEnabled = true
    undeltedhub.Toggles.AutoHandstand = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

    handstandTask = task.spawn(function()
        local player = game:GetService("Players").LocalPlayer
        while handstandEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                if equipTool(player, "Handstands") then
                    local char = player.Character
                    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                    local tool = humanoid and humanoid.ActiveTool
                    if tool and tool.Name == "Handstands" then
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
            end
            task.wait(0.1)
        end
        handstandTask = nil
    end)
end

local function stopHandstand()
    handstandEnabled = false
    undeltedhub.Toggles.AutoHandstand = false
    if handstandTask then
        task.cancel(handstandTask)
        handstandTask = nil
    end
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
end

AutoTab:Toggle({
    Title = "Auto Handstand",
    Value = handstandEnabled,
    Callback = function(state)
        if state then startHandstand() else stopHandstand() end
    end
})

local rebirthEnabled = undeltedhub.Toggles.AutoRebirth or false
local rebirthTask = nil

local function startRebirth()
    if rebirthTask then return end
    rebirthEnabled = true
    undeltedhub.Toggles.AutoRebirth = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

    rebirthTask = task.spawn(function()
        local replicatedStorage = game:GetService("ReplicatedStorage")
        while rebirthEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE then
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
    undeltedhub.Toggles.AutoRebirth = false
    if rebirthTask then
        task.cancel(rebirthTask)
        rebirthTask = nil
    end
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
end

AutoTab:Toggle({
    Title = "Auto Rebirth",
    Value = rebirthEnabled,
    Callback = function(state)
        if state then startRebirth() else stopRebirth() end
    end
})

local situpsEnabled = undeltedhub.Toggles.AutoSitups or false
local situpsTask = nil

local function startSitups()
    if situpsTask then return end
    situpsEnabled = true
    undeltedhub.Toggles.AutoSitups = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

    situpsTask = task.spawn(function()
        local player = game:GetService("Players").LocalPlayer
        while situpsEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                if equipTool(player, "Situps") then
                    local char = player.Character
                    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                    local tool = humanoid and humanoid.ActiveTool
                    if tool and tool.Name == "Situps" then
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
            end
            task.wait(0.1)
        end
        situpsTask = nil
    end)
end

local function stopSitups()
    situpsEnabled = false
    undeltedhub.Toggles.AutoSitups = false
    if situpsTask then
        task.cancel(situpsTask)
        situpsTask = nil
    end
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
end

AutoTab:Toggle({
    Title = "Auto Situps",
    Value = situpsEnabled,
    Callback = function(state)
        if state then startSitups() else stopSitups() end
    end
})

local pushupsEnabled = undeltedhub.Toggles.AutoPushups or false
local pushupsTask = nil

local function startPushups()
    if pushupsTask then return end
    pushupsEnabled = true
    undeltedhub.Toggles.AutoPushups = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

    pushupsTask = task.spawn(function()
        local player = game:GetService("Players").LocalPlayer
        while pushupsEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                if equipTool(player, "Pushups") then
                    local char = player.Character
                    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                    local tool = humanoid and humanoid.ActiveTool
                    if tool and tool.Name == "Pushups" then
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
            end
            task.wait(0.1)
        end
        pushupsTask = nil
    end)
end

local function stopPushups()
    pushupsEnabled = false
    undeltedhub.Toggles.AutoPushups = false
    if pushupsTask then
        task.cancel(pushupsTask)
        pushupsTask = nil
    end
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
end

AutoTab:Toggle({
    Title = "Auto Pushups",
    Value = pushupsEnabled,
    Callback = function(state)
        if state then startPushups() else stopPushups() end
    end
})

local weightEnabled = undeltedhub.Toggles.AutoWeight or false
local weightTask = nil

local function startWeight()
    if weightTask then return end
    weightEnabled = true
    undeltedhub.Toggles.AutoWeight = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

    weightTask = task.spawn(function()
        local player = game:GetService("Players").LocalPlayer
        while weightEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                if equipTool(player, "Weight") then
                    local char = player.Character
                    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                    local tool = humanoid and humanoid.ActiveTool
                    if tool and tool.Name == "Weight" then
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
            end
            task.wait(0.1)
        end
        weightTask = nil
    end)
end

local function stopWeight()
    weightEnabled = false
    undeltedhub.Toggles.AutoWeight = false
    if weightTask then
        task.cancel(weightTask)
        weightTask = nil
    end
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
end

AutoTab:Toggle({
    Title = "Auto Weight",
    Value = weightEnabled,
    Callback = function(state)
        if state then startWeight() else stopWeight() end
    end
})

if handstandEnabled then startHandstand() end
if rebirthEnabled then startRebirth() end
if situpsEnabled then startSitups() end
if pushupsEnabled then startPushups() end
if weightEnabled then startWeight() end

local oldDisable = undeltedhub.DisableAll or function() end
undeltedhub.DisableAll = function()
    if handstandEnabled then stopHandstand() end
    if rebirthEnabled then stopRebirth() end
    if situpsEnabled then stopSitups() end
    if pushupsEnabled then stopPushups() end
    if weightEnabled then stopWeight() end
    oldDisable()
end