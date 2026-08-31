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

local TrollTab = undeltedhub.Window:Tab({ Title = "Troll" })

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

TrollTab:Toggle({
    Title = "Auto Kill",
    Value = killEnabled,
    Callback = function(state)
        if state then startKill() else stopKill() end
    end
})

local oldDisable = undeltedhub.DisableAll or function() end
undeltedhub.DisableAll = function()
    if killEnabled then stopKill() end
    oldDisable()
end