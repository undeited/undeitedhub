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

local BOSS_NAMES = {"Boss1", "Boss2", "Boss3", "Boss4", "Boss5"}

local function getAliveBosses()
    local arena = workspace:FindFirstChild("Events") and workspace.Events:FindFirstChild("BossArena")
    if not arena then return {} end
    local alive = {}
    for _, name in ipairs(BOSS_NAMES) do
        local bossModel = arena:FindFirstChild(name)
        if bossModel then
            local boss = bossModel:FindFirstChild("Boss")
            if boss and boss:IsA("Model") then
                local hum = boss:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local root = boss:FindFirstChild("HumanoidRootPart") or boss:FindFirstChildWhichIsA("BasePart")
                    if root then
                        table.insert(alive, {model = boss, root = root, hum = hum})
                    end
                end
            end
        end
    end
    return alive
end

local function getBossSpawnTimer()
    local bossSpawn = workspace:FindFirstChild("Events") and workspace.Events:FindFirstChild("BossArena") and workspace.Events.BossArena:FindFirstChild("BossSpawn")
    if not bossSpawn then return nil end
    local info = bossSpawn:FindFirstChild("bossInfoRuntime")
    if not info then return nil end
    local content = info:FindFirstChild("Content")
    if not content then return nil end
    local desc = content:FindFirstChild("Description")
    if not desc or not desc:IsA("TextLabel") then return nil end
    local text = desc.Text or ""
    local num = text:match("%d+")
    if num then
        return tonumber(num)
    end
    return nil
end

local function getClosestBoss(character)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local pos = root.Position
    local alive = getAliveBosses()
    local best = nil
    local bestDist = math.huge
    for _, bossData in ipairs(alive) do
        local dist = (bossData.root.Position - pos).Magnitude
        if dist < bestDist then
            bestDist = dist
            best = bossData
        end
    end
    return best
end

local bossFarmEnabled = undeitedhub.Toggles.bossFarm or false
local bossTask = nil

local function startBossFarm()
    if bossTask then return end
    bossFarmEnabled = true
    undeitedhub.Toggles.bossFarm = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Farm Boss", Content = "Enabled", Duration = 2 })

    bossTask = task.spawn(function()
        local localPlayer = game:GetService("Players").LocalPlayer
        while bossFarmEnabled do
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

                local bossData = getClosestBoss(character)
                if not bossData then
                    local timer = getBossSpawnTimer()
                    if timer and timer > 0 then
                        SafeNotify({ Title = "Boss", Content = "Waiting " .. timer .. "s for boss spawn", Duration = 2 })
                        task.wait(math.min(timer, 60))
                    else
                        task.wait(0.5)
                    end
                    continue
                end

                local boss = bossData.model
                local bossRoot = bossData.root
                local bossHum = bossData.hum

                local myRoot = character:FindFirstChild("HumanoidRootPart")
                if not myRoot then
                    task.wait(0.2)
                    continue
                end

                resetVelocity(myRoot)
                myRoot.CFrame = bossRoot.CFrame + Vector3.new(0, 1, 0)
                resetVelocity(myRoot)

                while bossFarmEnabled and bossHum and bossHum.Health > 0 do
                    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then break end
                    local localChar = localPlayer.Character
                    local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
                    if not localChar or not localHum or localHum.Health <= 0 then break end

                    if not equipPunch(localPlayer) then break end
                    local currentPunch = getPunchTool(localPlayer)
                    if not currentPunch then break end

                    resetVelocity(myRoot)
                    myRoot.CFrame = bossRoot.CFrame + Vector3.new(0, 1, 0)
                    resetVelocity(myRoot)
                    pcall(function()
                        currentPunch:Activate()
                    end)
                    task.wait(0.1)
                    resetVelocity(myRoot)
                end
            else
                task.wait(0.5)
            end
        end
        bossTask = nil
    end)
end

local function stopBossFarm()
    bossFarmEnabled = false
    undeitedhub.Toggles.bossFarm = false
    if bossTask then
        task.cancel(bossTask)
        bossTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Farm Boss", Content = "Disabled", Duration = 2 })
end

BossTab:Toggle({
    Title = "Auto Farm Boss",
    Value = bossFarmEnabled,
    Callback = function(state)
        if state then startBossFarm() else stopBossFarm() end
    end
})

if bossFarmEnabled then startBossFarm() end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if bossFarmEnabled then stopBossFarm() end
    oldDisable()
end
