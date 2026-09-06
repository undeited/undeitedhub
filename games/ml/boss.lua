local WindUI = undeitedhub.WindUI
local BossTab = undeitedhub.Window:Tab({ Title = "Boss" })

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

local function resetVelocity(part)
    if not part then return end
    pcall(function()
        part.Velocity = Vector3.new(0,0,0)
        part.RotVelocity = Vector3.new(0,0,0)
        part.AssemblyLinearVelocity = Vector3.new(0,0,0)
        part.AssemblyAngularVelocity = Vector3.new(0,0,0)
    end)
end

local function getBoss()
    local boss = workspace:FindFirstChild("Events")
    if boss then
        boss = boss:FindFirstChild("BossArena")
        if boss then
            boss = boss:FindFirstChild("Boss1")
            if boss then
                boss = boss:FindFirstChild("Boss")
                if boss and boss:IsA("Model") then
                    return boss
                end
            end
        end
    end
    return nil
end

local function isAlive(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local autoBossFarmEnabled = undeitedhub.Toggles.autoBossFarm or false
local bossTask = nil

local function startBossFarm()
    if bossTask then return end
    autoBossFarmEnabled = true
    undeitedhub.Toggles.autoBossFarm = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Autofarm Boss", Content = "Enabled", Duration = 2 })

    bossTask = task.spawn(function()
        local localPlayer = game.Players.LocalPlayer
        while autoBossFarmEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local character = localPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if not character or not humanoid or humanoid.Health <= 0 then
                    task.wait(0.5)
                    continue
                end

                if not equipPunch(localPlayer) then
                    task.wait(0.2)
                    continue
                end

                local punch = getPunchTool(localPlayer)
                if not punch then
                    task.wait(0.2)
                    continue
                end

                local boss = getBoss()
                if not boss or not isAlive(boss) then
                    task.wait(0.5)
                    continue
                end

                local root = character:FindFirstChild("HumanoidRootPart")
                if not root then
                    task.wait(0.2)
                    continue
                end

                local bossRoot = boss:FindFirstChild("HumanoidRootPart") or boss:FindFirstChild("Torso") or boss:FindFirstChildWhichIsA("BasePart")
                if not bossRoot then
                    task.wait(0.5)
                    continue
                end

                resetVelocity(root)
                root.CFrame = bossRoot.CFrame + Vector3.new(0, 1, 0)
                resetVelocity(root)

                while autoBossFarmEnabled and isAlive(boss) do
                    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then break end
                    local localChar = localPlayer.Character
                    local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
                    if not localChar or not localHum or localHum.Health <= 0 then break end

                    if not equipPunch(localPlayer) then break end
                    local currentPunch = getPunchTool(localPlayer)
                    if not currentPunch then break end

                    resetVelocity(root)
                    root.CFrame = bossRoot.CFrame + Vector3.new(0, 1, 0)
                    resetVelocity(root)
                    pcall(function()
                        currentPunch:Activate()
                    end)
                    task.wait(0.1)
                    resetVelocity(root)
                end
            else
                task.wait(0.5)
            end
        end
        bossTask = nil
    end)
end

local function stopBossFarm()
    autoBossFarmEnabled = false
    undeitedhub.Toggles.autoBossFarm = false
    if bossTask then
        task.cancel(bossTask)
        bossTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Autofarm Boss", Content = "Disabled", Duration = 2 })
end

BossTab:Toggle({
    Title = "Autofarm Boss",
    Value = autoBossFarmEnabled,
    Callback = function(state)
        if state then startBossFarm() else stopBossFarm() end
    end
})

if autoBossFarmEnabled then startBossFarm() end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoBossFarmEnabled then stopBossFarm() end
    oldDisable()
end