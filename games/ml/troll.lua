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
    local char = player.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end

    local toolName = "Punch"
    local tool = char:FindFirstChild(toolName)
    if tool and humanoid.ActiveTool == tool then
        return true, tool
    end

    if tool then
        humanoid:EquipTool(tool)
        for _ = 1, 3 do
            task.wait(0.03)
            if humanoid.ActiveTool == tool then
                return true, tool
            end
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
        for _ = 1, 3 do
            task.wait(0.03)
            if humanoid.ActiveTool == tool then
                return true, tool
            end
        end
    end
    return false, nil
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

        while killEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                local character = localPlayer.Character
                local myRoot = character and character:FindFirstChild("HumanoidRootPart")
                if not myRoot then
                    task.wait()
                    continue
                end

                local success, punchTool = equipPunch(localPlayer)
                if not success or not punchTool then
                    task.wait()
                    continue
                end

                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if not humanoid or humanoid.ActiveTool ~= punchTool then
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

                        if humanoid.ActiveTool ~= punchTool then
                            local success2, newTool = equipPunch(localPlayer)
                            if not success2 then break end
                            punchTool = newTool
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
    Title = "Auto Kill (MAX SPEED)",
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