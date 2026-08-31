local WindUI = undeltedhub.WindUI

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

local AutoTab = undeltedhub.Window:Tab({ Title = "Auto" })

local autoFeatures = {
    Handstand = { enabled = false, task = nil, toggle = nil, stop = nil },
    Rebirth   = { enabled = false, task = nil, toggle = nil, stop = nil },
    Situps    = { enabled = false, task = nil, toggle = nil, stop = nil },
    Pushups   = { enabled = false, task = nil, toggle = nil, stop = nil },
    Weight    = { enabled = false, task = nil, toggle = nil, stop = nil },
}

local function stopFeature(name)
    local f = autoFeatures[name]
    if f.task then
        task.cancel(f.task)
        f.task = nil
    end
    f.enabled = false
    undeltedhub.Toggles["Auto" .. name] = false
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
end

local function startFeature(name, loopFunction)
    local f = autoFeatures[name]
    if f.task then return end

    for otherName, otherF in pairs(autoFeatures) do
        if otherName ~= name and otherF.enabled then
            otherF.stop()
            if otherF.toggle and otherF.toggle.SetValue then
                otherF.toggle:SetValue(false)
            end
        end
    end

    f.enabled = true
    undeltedhub.Toggles["Auto" .. name] = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    SafeNotify({ Title = "Auto " .. name, Content = "Enabled", Duration = 2 })
    f.task = task.spawn(loopFunction)
end

autoFeatures.Handstand.stop = function()
    stopFeature("Handstand")
end

autoFeatures.Rebirth.stop = function()
    stopFeature("Rebirth")
end

autoFeatures.Situps.stop = function()
    stopFeature("Situps")
end

autoFeatures.Pushups.stop = function()
    stopFeature("Pushups")
end

autoFeatures.Weight.stop = function()
    stopFeature("Weight")
end

local handstandToggle = AutoTab:Toggle({
    Title = "Auto Handstand",
    Value = undeltedhub.Toggles.AutoHandstand or false,
    Callback = function(state)
        if state then
            startFeature("Handstand", function()
                local player = game:GetService("Players").LocalPlayer
                while autoFeatures.Handstand.enabled do
                    if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                        local character = player.Character
                        local backpack = player:FindFirstChild("Backpack")
                        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                        if humanoid and humanoid.Health > 0 and backpack then
                            for _, tool in ipairs(character:GetChildren()) do
                                if tool:IsA("Tool") and tool.Name ~= "Handstands" then
                                    tool.Parent = backpack
                                end
                            end
                            local handstands = character:FindFirstChild("Handstands")
                            if not handstands then
                                handstands = backpack:FindFirstChild("Handstands")
                                if handstands then
                                    handstands.Parent = character
                                    task.wait(0.1)
                                end
                            end
                            if handstands and handstands.Parent == character then
                                handstands:Activate()
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        else
            autoFeatures.Handstand.stop()
        end
    end
})
autoFeatures.Handstand.toggle = handstandToggle

local rebirthToggle = AutoTab:Toggle({
    Title = "Auto Rebirth",
    Value = undeltedhub.Toggles.AutoRebirth or false,
    Callback = function(state)
        if state then
            startFeature("Rebirth", function()
                local replicatedStorage = game:GetService("ReplicatedStorage")
                while autoFeatures.Rebirth.enabled do
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
            end)
        else
            autoFeatures.Rebirth.stop()
        end
    end
})
autoFeatures.Rebirth.toggle = rebirthToggle

local situpsToggle = AutoTab:Toggle({
    Title = "Auto Situps",
    Value = undeltedhub.Toggles.AutoSitups or false,
    Callback = function(state)
        if state then
            startFeature("Situps", function()
                local player = game:GetService("Players").LocalPlayer
                while autoFeatures.Situps.enabled do
                    if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                        local character = player.Character
                        local backpack = player:FindFirstChild("Backpack")
                        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                        if humanoid and humanoid.Health > 0 and backpack then
                            for _, tool in ipairs(character:GetChildren()) do
                                if tool:IsA("Tool") and tool.Name ~= "Situps" then
                                    tool.Parent = backpack
                                end
                            end
                            task.wait(0.1)
                            local situpsInChar = character:FindFirstChild("Situps")
                            local situpsInBack = backpack:FindFirstChild("Situps")
                            if situpsInChar then
                                situpsInChar:Activate()
                            elseif situpsInBack then
                                situpsInBack.Parent = character
                                task.wait(0.1)
                                local newSitups = character:FindFirstChild("Situps")
                                if newSitups then
                                    newSitups:Activate()
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        else
            autoFeatures.Situps.stop()
        end
    end
})
autoFeatures.Situps.toggle = situpsToggle

local pushupsToggle = AutoTab:Toggle({
    Title = "Auto Pushups",
    Value = undeltedhub.Toggles.AutoPushups or false,
    Callback = function(state)
        if state then
            startFeature("Pushups", function()
                local player = game:GetService("Players").LocalPlayer
                while autoFeatures.Pushups.enabled do
                    if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                        local character = player.Character
                        local backpack = player:FindFirstChild("Backpack")
                        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                        if humanoid and humanoid.Health > 0 and backpack then
                            for _, tool in ipairs(character:GetChildren()) do
                                if tool:IsA("Tool") and tool.Name ~= "Pushups" then
                                    tool.Parent = backpack
                                end
                            end
                            task.wait(0.1)
                            local pushupsInChar = character:FindFirstChild("Pushups")
                            local pushupsInBack = backpack:FindFirstChild("Pushups")
                            if pushupsInChar then
                                pushupsInChar:Activate()
                            elseif pushupsInBack then
                                pushupsInBack.Parent = character
                                task.wait(0.1)
                                local newPushups = character:FindFirstChild("Pushups")
                                if newPushups then
                                    newPushups:Activate()
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        else
            autoFeatures.Pushups.stop()
        end
    end
})
autoFeatures.Pushups.toggle = pushupsToggle

local weightToggle = AutoTab:Toggle({
    Title = "Auto Weight",
    Value = undeltedhub.Toggles.AutoWeight or false,
    Callback = function(state)
        if state then
            startFeature("Weight", function()
                local player = game:GetService("Players").LocalPlayer
                while autoFeatures.Weight.enabled do
                    if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                        local character = player.Character
                        local backpack = player:FindFirstChild("Backpack")
                        if character and backpack then
                            local humanoid = character:FindFirstChildOfClass("Humanoid")
                            if humanoid and humanoid.Health > 0 then
                                local weight = character:FindFirstChild("Weight") or backpack:FindFirstChild("Weight")
                                if weight then
                                    if weight.Parent == backpack then
                                        weight.Parent = character
                                        task.wait(0.1)
                                    end
                                    if weight.Parent == character then
                                        weight:Activate()
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        else
            autoFeatures.Weight.stop()
        end
    end
})
autoFeatures.Weight.toggle = weightToggle

local oldDisable = undeltedhub.DisableAll or function() end
undeltedhub.DisableAll = function()
    for name, f in pairs(autoFeatures) do
        if f.enabled then
            f.stop()
            if f.toggle and f.toggle.SetValue then
                f.toggle:SetValue(false)
            end
        end
    end
    oldDisable()
end