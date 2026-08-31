local WindUI = undeltedhub.WindUI
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
    local punch = character:FindFirstChild("Punch")
    if punch then return true end
    punch = backpack:FindFirstChild("Punch")
    if punch then
        punch.Parent = character
        task.wait(0.02)
        return true
    end
    return false
end

local killEnabled = undeltedhub.Toggles.AutoKill or false
local killTask = nil

local function startKill()
    if killTask then return end
    killEnabled = true
    undeltedhub.Toggles.AutoKill = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

    killTask = task.spawn(function()
        local localPlayer = game:GetService("Players").LocalPlayer
        local playerStrength = getStrength(localPlayer)
        local punchTool = nil

        while killEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                local character = localPlayer.Character
                local myRoot = character and character:FindFirstChild("HumanoidRootPart")
                if not myRoot then
                    task.wait()
                    continue
                end

                if not punchTool then
                    if equipPunch(localPlayer) then
                        punchTool = character:FindFirstChild("Punch")
                    else
                        task.wait()
                        continue
                    end
                end

                if not punchTool or not punchTool.Parent then
                    punchTool = nil
                    task.wait()
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
                                        root = targetRoot,
                                        hum = targetHum,
                                        ply = otherPlayer
                                    })
                                end
                            end
                        end
                    end
                end

                for _, target in ipairs(targets) do
                    if not killEnabled then break end
                    local targetRoot = target.root
                    local targetHum = target.hum
                    local targetPlayer = target.ply
                    local punchCount = 0
                    local maxPunches = 20

                    while killEnabled and targetHum.Health > 0 and punchCount < maxPunches do
                        local otherStrength = getStrength(targetPlayer)
                        if otherStrength and playerStrength and otherStrength >= playerStrength then
                            break
                        end
                        local targetPos = targetRoot.Position
                        local attackPos = targetPos + Vector3.new(0, 0.5, 0)
                        myRoot.CFrame = CFrame.new(attackPos, targetPos)
                        pcall(function()
                            punchTool:Activate()
                        end)
                        punchCount = punchCount + 1
                        task.wait()
                    end
                end
            end
            task.wait()
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
end

TrollTab:Toggle({
    Title = "Auto Kill",
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