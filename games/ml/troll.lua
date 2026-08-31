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

local function equipPunch(player)
    local character = player.Character
    if not character then return false end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end

    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") and tool.Name ~= "Punch" then
            tool.Parent = backpack
        end
    end

    local punch = character:FindFirstChild("Punch")
    if not punch then
        punch = backpack:FindFirstChild("Punch")
        if punch then
            punch.Parent = character
            task.wait(0.05)
        end
    end
    return punch ~= nil
end

local killEnabled = undeltedhub.Toggles.AutoKill or false
local killTask = nil

local function startKill()
    if killTask then return end
    killEnabled = true
    undeltedhub.Toggles.AutoKill = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Kill", Content = "Enabled", Duration = 2 })

    killTask = task.spawn(function()
        local localPlayer = game:GetService("Players").LocalPlayer
        local playerStrength = getStrength(localPlayer)

        while killEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                local character = localPlayer.Character
                local myRoot = character and character:FindFirstChild("HumanoidRootPart")
                if not myRoot then
                    task.wait(0.5)
                    continue
                end

                if not equipPunch(localPlayer) then
                    task.wait(0.5)
                    continue
                end

                local punchTool = character:FindFirstChild("Punch")
                if not punchTool then
                    task.wait(0.5)
                    continue
                end

                local targets = {}
                for _, otherPlayer in ipairs(game:GetService("Players"):GetPlayers()) do
                    if otherPlayer ~= localPlayer then
                        local otherStrength = getStrength(otherPlayer)
                        if playerStrength and otherStrength and otherStrength >= playerStrength then
                            continue
                        end
                        local targetChar = otherPlayer.Character
                        if targetChar then
                            local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
                            if targetHum and targetHum.Health > 0 then
                                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                                if targetRoot then
                                    table.insert(targets, {
                                        player = otherPlayer,
                                        root = targetRoot,
                                        humanoid = targetHum
                                    })
                                end
                            end
                        end
                    end
                end

                for _, target in ipairs(targets) do
                    if not killEnabled then break end
                    local targetRoot = target.root
                    local targetHum = target.humanoid
                    local targetPlayer = target.player

                    local punchCount = 0
                    local maxPunches = 10
                    local angle = 0
                    local radius = 3.0

                    while killEnabled and targetHum.Health > 0 and punchCount < maxPunches do
                        local otherStrength = getStrength(targetPlayer)
                        if otherStrength and playerStrength and otherStrength >= playerStrength then
                            break
                        end

                        local targetPos = targetRoot.Position

                        angle = angle + 0.6
                        local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                        local attackPos = targetPos + offset + Vector3.new(0, 1, 0)

                        myRoot.CFrame = CFrame.new(attackPos, targetPos)

                        pcall(function()
                            punchTool:Activate()
                        end)
                        punchCount = punchCount + 1

                        task.wait(0.15)
                    end

                    task.wait(0.1)
                end
            end
            task.wait(0.2)
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
    Title = "Auto Kill (Orbit)",
    Value = killEnabled,
    Callback = function(state)
        if state then startKill() else stopKill() end
    end
})

if killEnabled then startKill() end

local oldDisable = undeltedhub.DisableAll or function() end
undeltedhub.DisableAll = function()
    if killEnabled then stopKill() end
    oldDisable()
end