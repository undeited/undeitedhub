local WindUI = undeitedhub.WindUI
local AutoTab = undeitedhub.Window:Tab({ Title = "Autofarm" })

local function getTool(player, toolName)
    local char = player.Character
    if char then
        local tool = char:FindFirstChild(toolName)
        if tool then return tool end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        return backpack:FindFirstChild(toolName)
    end
    return nil
end

local function equipTool(player, toolName)
    local char = player.Character
    if not char then return false end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end
    local tool = char:FindFirstChild(toolName)
    if tool then return true end
    tool = backpack:FindFirstChild(toolName)
    if tool then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and t.Name ~= toolName then
                t.Parent = backpack
            end
        end
        tool.Parent = char
        task.wait(0.02)
        return true
    end
    return false
end

local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
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

local function getNearestNPC(character)
    if not character then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local pos = root.Position
    local best = nil
    local bestDist = math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local npcRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
                if npcRoot then
                    local dist = (npcRoot.Position - pos).Magnitude
                    if dist < bestDist then
                        local name = obj.Name:lower()
                        if name:find("dummy") or name:find("training") or name:find("punch") or name:find("bag") or name:find("target") then
                            best = obj
                            bestDist = dist
                        end
                    end
                end
            end
        end
    end
    return best
end

local autoPunchEnabled = undeitedhub.Toggles.AutoPunch or false
local autoPunchTask = nil

local function startAutoPunch()
    if autoPunchTask then return end
    autoPunchEnabled = true
    undeitedhub.Toggles.AutoPunch = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    autoPunchTask = task.spawn(function()
        local localPlayer = game:GetService("Players").LocalPlayer
        while autoPunchEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local character = localPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if not character or not humanoid or humanoid.Health <= 0 then
                    task.wait(0.5)
                    continue
                end

                if not equipTool(localPlayer, "Punch") then
                    task.wait(0.2)
                    continue
                end

                local punch = getTool(localPlayer, "Punch")
                if not punch then
                    task.wait(0.2)
                    continue
                end

                local root = character:FindFirstChild("HumanoidRootPart")
                if not root then
                    task.wait(0.2)
                    continue
                end

                local npc = getNearestNPC(character)
                if not npc then
                    task.wait(0.5)
                    continue
                end

                local npcRoot = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
                if not npcRoot then
                    task.wait(0.5)
                    continue
                end

                local npcHum = npc:FindFirstChildOfClass("Humanoid")
                if not npcHum or npcHum.Health <= 0 then
                    task.wait(0.2)
                    continue
                end

                resetVelocity(root)
                root.CFrame = CFrame.new(npcRoot.Position + Vector3.new(0, 0.5, 0), npcRoot.Position)
                resetVelocity(root)

                while autoPunchEnabled and npcHum and npcHum.Health > 0 do
                    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then break end
                    local localChar = localPlayer.Character
                    local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
                    if not localChar or not localHum or localHum.Health <= 0 then
                        break
                    end
                    if not equipTool(localPlayer, "Punch") then
                        break
                    end
                    local currentPunch = getTool(localPlayer, "Punch")
                    if not currentPunch then
                        break
                    end
                    resetVelocity(root)
                    root.CFrame = CFrame.new(npcRoot.Position + Vector3.new(0, 0.5, 0), npcRoot.Position)
                    resetVelocity(root)
                    pcall(function()
                        currentPunch:Activate()
                    end)
                    task.wait(0.1)
                    resetVelocity(root)
                end
            end
            task.wait(0.1)
        end
        autoPunchTask = nil
    end)
end

local function stopAutoPunch()
    autoPunchEnabled = false
    undeitedhub.Toggles.AutoPunch = false
    if autoPunchTask then
        task.cancel(autoPunchTask)
        autoPunchTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

AutoTab:Toggle({
    Title = "Auto Punch",
    Value = autoPunchEnabled,
    Callback = function(state)
        if state then startAutoPunch() else stopAutoPunch() end
    end
})

if autoPunchEnabled then startAutoPunch() end

local function startAutoActivity(toggleName, toolName)
    local enabled = undeitedhub.Toggles[toggleName] or false
    local taskRef = nil
    local running = false

    local function activityLoop()
        local player = game:GetService("Players").LocalPlayer
        while running do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE and isAlive(player) then
                local character = player.Character
                local backpack = player:FindFirstChild("Backpack")
                if backpack then
                    if not equipTool(player, toolName) then
                        task.wait(0.2)
                        continue
                    end
                    local tool = getTool(player, toolName)
                    if tool and tool.Parent == character then
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
            end
            task.wait(0.1)
        end
        taskRef = nil
    end

    local function start()
        if running then return end
        running = true
        enabled = true
        undeitedhub.Toggles[toggleName] = true
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        taskRef = task.spawn(activityLoop)
    end

    local function stop()
        running = false
        enabled = false
        undeitedhub.Toggles[toggleName] = false
        if taskRef then
            task.cancel(taskRef)
            taskRef = nil
        end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    end

    AutoTab:Toggle({
        Title = "Auto " .. toolName,
        Value = enabled,
        Callback = function(state)
            if state then start() else stop() end
        end
    })

    if enabled then start() end

    return { start = start, stop = stop }
end

local handstand = startAutoActivity("AutoHandstand", "Handstands")
local situps = startAutoActivity("AutoSitups", "Situps")
local pushups = startAutoActivity("AutoPushups", "Pushups")
local weight = startAutoActivity("AutoWeight", "Weight")

local rebirthEnabled = undeitedhub.Toggles.AutoRebirth or false
local rebirthTask = nil

local function startRebirth()
    if rebirthTask then return end
    rebirthEnabled = true
    undeitedhub.Toggles.AutoRebirth = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    rebirthTask = task.spawn(function()
        local replicatedStorage = game:GetService("ReplicatedStorage")
        while rebirthEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
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
    undeitedhub.Toggles.AutoRebirth = false
    if rebirthTask then
        task.cancel(rebirthTask)
        rebirthTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

AutoTab:Toggle({
    Title = "Auto Rebirth",
    Value = rebirthEnabled,
    Callback = function(state)
        if state then startRebirth() else stopRebirth() end
    end
})

if rebirthEnabled then startRebirth() end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    stopAutoPunch()
    handstand.stop()
    situps.stop()
    pushups.stop()
    weight.stop()
    if rebirthEnabled then stopRebirth() end
    oldDisable()
end