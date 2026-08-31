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

local AutoTab = undeltedhub.Window:Tab({ Title = "Autofarm" })

local handstandEnabled = undeltedhub.Toggles.AutoHandstand or false
local handstandTask = nil

local function startHandstand()
    if handstandTask then return end
    handstandEnabled = true
    undeltedhub.Toggles.AutoHandstand = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Handstand", Content = "Enabled", Duration = 2 })

    handstandTask = task.spawn(function()
        local player = game:GetService("Players").LocalPlayer
        while handstandEnabled do
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
    SafeNotify({ Title = "Auto Handstand", Content = "Disabled", Duration = 2 })
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
    SafeNotify({ Title = "Auto Rebirth", Content = "Enabled", Duration = 2 })

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
    SafeNotify({ Title = "Auto Rebirth", Content = "Disabled", Duration = 2 })
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
    SafeNotify({ Title = "Auto Situps", Content = "Enabled", Duration = 2 })

    situpsTask = task.spawn(function()
        local player = game:GetService("Players").LocalPlayer
        while situpsEnabled do
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
    SafeNotify({ Title = "Auto Situps", Content = "Disabled", Duration = 2 })
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
    SafeNotify({ Title = "Auto Pushups", Content = "Enabled", Duration = 2 })

    pushupsTask = task.spawn(function()
        local player = game:GetService("Players").LocalPlayer
        while pushupsEnabled do
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
    SafeNotify({ Title = "Auto Pushups", Content = "Disabled", Duration = 2 })
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
    SafeNotify({ Title = "Auto Weight", Content = "Enabled", Duration = 2 })

    weightTask = task.spawn(function()
        local player = game:GetService("Players").LocalPlayer
        while weightEnabled do
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
    SafeNotify({ Title = "Auto Weight", Content = "Disabled", Duration = 2 })
end

AutoTab:Toggle({
    Title = "Auto Weight",
    Value = weightEnabled,
    Callback = function(state)
        if state then startWeight() else stopWeight() end
    end
})

local killEnabled = undeltedhub.Toggles.AutoKill or false
local killTask = nil

local function getStrength(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local strength = leaderstats:FindFirstChild("Strength")
        if strength then
            return strength.Value
        end
    end
    return nil
end

local function startKill()
    if killTask then return end
    killEnabled = true
    undeltedhub.Toggles.AutoKill = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Kill", Content = "Enabled", Duration = 2 })

    killTask = task.spawn(function()
        local player = game:GetService("Players").LocalPlayer
        while killEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                local character = player.Character
                local myRoot = character and character:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    local localStrength = getStrength(player)
                    local backpack = player:FindFirstChild("Backpack")
                    
                    if character then
                        for _, tool in ipairs(character:GetChildren()) do
                            if tool:IsA("Tool") and tool.Name ~= "Punch" then
                                tool.Parent = backpack
                            end
                        end
                    end
                    
                    if character and not character:FindFirstChild("Punch") then
                        local punch = backpack and backpack:FindFirstChild("Punch")
                        if punch then
                            punch.Parent = character
                            task.wait(0.05)
                        end
                    end
                    
                    local closestTarget = nil
                    local shortestDistance = math.huge
                    for _, otherPlayer in ipairs(game:GetService("Players"):GetPlayers()) do
                        if otherPlayer ~= player then
                            local targetStrength = getStrength(otherPlayer)
                            if localStrength and targetStrength and targetStrength >= localStrength then
                                continue
                            end
                            local targetChar = otherPlayer.Character
                            if targetChar then
                                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                                local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
                                if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
                                    local dist = (myRoot.Position - targetRoot.Position).Magnitude
                                    if dist < shortestDistance then
                                        shortestDistance = dist
                                        closestTarget = otherPlayer
                                    end
                                end
                            end
                        end
                    end
                    if closestTarget then
                        local targetChar = closestTarget.Character
                        if targetChar then
                            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                            local punchTool = character:FindFirstChild("Punch")
                            if targetRoot and punchTool then
                                myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 2)
                                punchTool:Activate()
                            end
                        end
                    end
                end
            end
            task.wait(0.1)
        end
        killTask = nil
    end)
end

local function stopKill()
    killEnabled = false
    undeltedhub.Toggles.AutoKill = false
    if killTask then
        task.cancel(killTask)
        killTask = nil
    end
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Kill", Content = "Disabled", Duration = 2 })
end

AutoTab:Toggle({
    Title = "Auto Kill",
    Value = killEnabled,
    Callback = function(state)
        if state then startKill() else stopKill() end
    end
})

local oldDisable = undeltedhub.DisableAll or function() end
undeltedhub.DisableAll = function()
    if handstandEnabled then stopHandstand() end
    if rebirthEnabled then stopRebirth() end
    if situpsEnabled then stopSitups() end
    if pushupsEnabled then stopPushups() end
    if weightEnabled then stopWeight() end
    if killEnabled then stopKill() end
    oldDisable()
end