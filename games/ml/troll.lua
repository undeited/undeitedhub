local WindUI = undeitedhub.WindUI
local TrollTab = undeitedhub.Window:Tab({ Title = "Troll" })

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

local function getPunchTool(player)
    local char = player.Character
    if char then
        local punch = char:FindFirstChild("Punch")
        if punch then return punch end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        return backpack:FindFirstChild("Punch")
    end
    return nil
end

local function equipPunch(player)
    local char = player.Character
    if not char then return false end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end
    local punch = char:FindFirstChild("Punch")
    if punch then return true end
    punch = backpack:FindFirstChild("Punch")
    if punch then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.Name ~= "Punch" then
                tool.Parent = backpack
            end
        end
        punch.Parent = char
        task.wait(0.02)
        return true
    end
    return false
end

local killEnabled = undeitedhub.Toggles.AutoKill or false
local killTask = nil

local function startKill()
    if killTask then return end
    killEnabled = true
    undeitedhub.Toggles.AutoKill = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    killTask = task.spawn(function()
        local localPlayer = game:GetService("Players").LocalPlayer
        local playerStrength = getStrength(localPlayer)

        while killEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local character = localPlayer.Character
                local myRoot = character and character:FindFirstChild("HumanoidRootPart")
                if not myRoot then
                    task.wait()
                    continue
                end

                if not equipPunch(localPlayer) then
                    task.wait()
                    continue
                end

                local punchTool = getPunchTool(localPlayer)
                if not punchTool then
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

                    while killEnabled and targetHum and targetHum.Health > 0 do
                        local otherStrength = getStrength(targetPlayer)
                        if otherStrength and playerStrength and otherStrength >= playerStrength then
                            break
                        end

                        local currentPunch = getPunchTool(localPlayer)
                        if not currentPunch then
                            if not equipPunch(localPlayer) then
                                break
                            end
                            currentPunch = getPunchTool(localPlayer)
                            if not currentPunch then
                                break
                            end
                            punchTool = currentPunch
                        end

                        if not targetRoot or not targetRoot.Parent then
                            break
                        end

                        local targetPos = targetRoot.Position
                        local attackPos = targetPos + Vector3.new(0, 0.5, 0)
                        myRoot.CFrame = CFrame.new(attackPos, targetPos)

                        pcall(function()
                            punchTool:Activate()
                        end)
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
    undeitedhub.Toggles.AutoKill = false
    if killTask then
        task.cancel(killTask)
        killTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

TrollTab:Toggle({
    Title = "Auto Kill",
    Value = killEnabled,
    Callback = function(state)
        if state then startKill() else stopKill() end
    end
})

if killEnabled then startKill() end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if killEnabled then stopKill() end
    oldDisable()
end