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

local function resetAllVelocity(character)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Velocity = Vector3.new(0,0,0)
                part.RotVelocity = Vector3.new(0,0,0)
                part.AssemblyLinearVelocity = Vector3.new(0,0,0)
                part.AssemblyAngularVelocity = Vector3.new(0,0,0)
            end)
        end
    end
end

local function freezeCharacter(humanoid, freeze)
    if not humanoid then return end
    humanoid.PlatformStand = freeze
    humanoid.AutoRotate = not freeze
    if freeze then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    else
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
    end
end

local function resetCharacter()
    local player = game.Players.LocalPlayer
    if not player then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        freezeCharacter(hum, false)
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
    resetAllVelocity(char)
end

local function getRandomTargetPart(character)
    if not character then return nil end
    local parts = {}
    local root = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    local upperTorso = character:FindFirstChild("UpperTorso")
    local lowerTorso = character:FindFirstChild("LowerTorso")
    local torso = character:FindFirstChild("Torso")
    if root then table.insert(parts, root) end
    if head then table.insert(parts, head) end
    if upperTorso then table.insert(parts, upperTorso) end
    if lowerTorso then table.insert(parts, lowerTorso) end
    if torso then table.insert(parts, torso) end
    if #parts == 0 then return nil end
    return parts[math.random(1, #parts)]
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
        while killEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local character = localPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if not character or not humanoid or humanoid.Health <= 0 then
                    task.wait(0.5)
                    continue
                end

                local myStrength = getStrength(localPlayer)
                if not myStrength then
                    task.wait(0.5)
                    continue
                end

                if not equipPunch(localPlayer) then
                    task.wait(0.2)
                    continue
                end

                local punchTool = getPunchTool(localPlayer)
                if not punchTool then
                    task.wait(0.2)
                    continue
                end

                local myRoot = character:FindFirstChild("HumanoidRootPart")
                if not myRoot then
                    task.wait(0.2)
                    continue
                end

                local targets = {}
                for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
                    if otherPlayer ~= localPlayer then
                        local otherStrength = getStrength(otherPlayer)
                        if otherStrength and otherStrength < myStrength then
                            local targetChar = otherPlayer.Character
                            if targetChar then
                                local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
                                if targetHum and targetHum.Health > 0 then
                                    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                                    if targetRoot then
                                        table.insert(targets, {
                                            root = targetRoot,
                                            hum = targetHum,
                                            ply = otherPlayer,
                                            strength = otherStrength,
                                            char = targetChar
                                        })
                                    end
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
                    local targetChar = target.char

                    while killEnabled and targetHum and targetHum.Health > 0 and targetRoot and targetRoot.Parent do
                        local currentTargetStrength = getStrength(targetPlayer)
                        if not currentTargetStrength or currentTargetStrength >= myStrength then
                            break
                        end

                        local localChar = localPlayer.Character
                        local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
                        if not localChar or not localHum or localHum.Health <= 0 then
                            break
                        end

                        if not equipPunch(localPlayer) then
                            break
                        end
                        local currentPunch = getPunchTool(localPlayer)
                        if not currentPunch then
                            break
                        end

                        local targetPart = getRandomTargetPart(targetChar)
                        if not targetPart then
                            targetPart = targetRoot
                        end
                        local targetPos = targetPart.Position
                        local attackPos = targetPos + Vector3.new(0, 1.5, 0)

                        freezeCharacter(localHum, true)
                        resetAllVelocity(localChar)

                        local newCFrame = CFrame.new(attackPos, targetPos)
                        localChar:PivotTo(newCFrame)
                        resetAllVelocity(localChar)

                        task.wait(0.05)
                        freezeCharacter(localHum, false)
                        resetAllVelocity(localChar)

                        pcall(function()
                            currentPunch:Activate()
                        end)

                        resetAllVelocity(localChar)
                        task.wait(0.1)
                    end
                end
            end
            task.wait(0.1)
        end
        resetCharacter()
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
    resetCharacter()
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