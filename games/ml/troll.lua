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

-- Helper to get player's strength
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

-- Helper to equip Punch tool (fast)
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
        task.wait(0.03) -- minimal wait for equip
        return true
    end
    return false
end

-- Auto Kill toggle
local killEnabled = undeltedhub.Toggles.AutoKill or false
local killTask = nil

local function startKill()
    if killTask then return end
    killEnabled = true
    undeltedhub.Toggles.AutoKill = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Kill", Content = "Enabled (MAX SPEED)", Duration = 2 })

    killTask = task.spawn(function()
        local localPlayer = game:GetService("Players").LocalPlayer
        local playerStrength = getStrength(localPlayer)

        while killEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                local character = localPlayer.Character
                local myRoot = character and character:FindFirstChild("HumanoidRootPart")
                if not myRoot then
                    task.wait(0.1)
                    continue
                end

                -- Equip punch once per cycle
                if not equipPunch(localPlayer) then
                    task.wait(0.1)
                    continue
                end

                local punchTool = character:FindFirstChild("Punch")
                if not punchTool then
                    task.wait(0.1)
                    continue
                end

                -- Gather valid targets (weaker only)
                local targets = {}
                for _, otherPlayer in ipairs(game:GetService("Players"):GetPlayers()) do
                    if otherPlayer ~= localPlayer then
                        local otherStrength = getStrength(otherPlayer)
                        if playerStrength and otherStrength and otherStrength >= playerStrength then
                            continue -- skip equal or stronger
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

                -- Process each target
                for _, target in ipairs(targets) do
                    if not killEnabled then break end

                    local targetRoot = target.root
                    local targetHum = target.hum
                    local targetPlayer = target.ply

                    -- Teleport directly onto target (slightly above)
                    local attackPos = targetRoot.Position + Vector3.new(0, 0.5, 0)
                    myRoot.CFrame = CFrame.new(attackPos, targetRoot.Position)

                    -- SPAM PUNCH until dead or strength changes
                    local punchCount = 0
                    local maxPunches = 15  -- safety limit
                    while killEnabled and targetHum.Health > 0 and punchCount < maxPunches do
                        -- Re-check strength (fast)
                        local otherStrength = getStrength(targetPlayer)
                        if otherStrength and playerStrength and otherStrength >= playerStrength then
                            break
                        end

                        -- Punch
                        pcall(function()
                            punchTool:Activate()
                        end)
                        punchCount = punchCount + 1

                        -- Minimal delay (just enough for game to process)
                        task.wait(0.02)
                    end

                    -- Immediate move to next target
                    task.wait(0.02)
                end
            end
            task.wait(0.05) -- main loop speed
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

-- Toggle
TrollTab:Toggle({
    Title = "Auto Kill (MAX SPEED)",
    Value = killEnabled,
    Callback = function(state)
        if state then startKill() else stopKill() end
    end
})

-- Auto-start on rejoin
if killEnabled then startKill() end

-- Disable on hub close
local oldDisable = undeltedhub.DisableAll or function() end
undeltedhub.DisableAll = function()
    if killEnabled then stopKill() end
    oldDisable()
end