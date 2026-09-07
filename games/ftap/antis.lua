local WindUI = undeitedhub.WindUI
local AntiTab = undeitedhub.Window:Tab({ Title = "Antis" })

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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer

local antiKickEnabled = undeitedhub.Toggles.antiKick or false
local checkTask = nil

local function getPlayerToysFolder()
    return Workspace:FindFirstChild(localPlayer.Name .. "SpawnedInToys")
end

local function getNinjaShuriken()
    local folder = getPlayerToysFolder()
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child.Name == "NinjaShuriken" and child:IsA("Model") then
                return child
            end
        end
    end
    return nil
end

local function getStickyPart(shuriken)
    if shuriken then
        for _, part in ipairs(shuriken:GetDescendants()) do
            if part.Name == "StickyPart" and part:IsA("BasePart") then
                return part
            end
        end
    end
    return nil
end

local function isShurikenAttached(shuriken)
    if not shuriken then return false end
    local sticky = getStickyPart(shuriken)
    if not sticky then return false end
    for _, weld in ipairs(sticky:GetChildren()) do
        if weld:IsA("Weld") or weld:IsA("WeldConstraint") then
            if weld.Part1 and weld.Part1:IsDescendantOf(localPlayer.Character) then
                return true
            end
        end
    end
    return false
end

local function spawnShuriken()
    local char = localPlayer.Character
    if not char then return false, "No character" end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false, "No root part" end

    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    if not menuToys then return false, "MenuToys not found" end
    local spawnRemote = menuToys:FindFirstChild("SpawnToyRemoteFunction")
    if not spawnRemote then return false, "SpawnToyRemoteFunction not found" end

    -- Use absolute position (world space) directly under the player
    local pos = rootPart.Position - Vector3.new(0, 0.5, 0)
    local cframe = CFrame.new(pos)
    local args = {
        [1] = "NinjaShuriken",
        [2] = cframe,
        [3] = Vector3.new(0, 0, 0)
    }

    local success, result = pcall(function()
        return spawnRemote:InvokeServer(unpack(args))
    end)

    if success then
        return true, "Spawned (result: " .. tostring(result) .. ")"
    else
        return false, "Invoke error: " .. tostring(result)
    end
end

local function attachShuriken(shuriken)
    if not shuriken then return false, "No shuriken" end
    local sticky = getStickyPart(shuriken)
    if not sticky then return false, "No StickyPart" end
    local char = localPlayer.Character
    if not char then return false, "No character" end
    local attachPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChildWhichIsA("BasePart")
    if not attachPart then return false, "No attach part" end

    local playerEvents = ReplicatedStorage:FindFirstChild("PlayerEvents")
    if not playerEvents then return false, "PlayerEvents not found" end
    local stickyEvent = playerEvents:FindFirstChild("StickyPartEvent")
    if not stickyEvent then return false, "StickyPartEvent not found" end

    local relCFrame = CFrame.new(0, -0.5, 0)
    local args = {
        [1] = sticky,
        [2] = attachPart,
        [3] = relCFrame
    }
    pcall(function()
        stickyEvent:FireServer(unpack(args))
    end)
    return true, "Attach fired"
end

local function ensureShuriken()
    if not antiKickEnabled then return end
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end
    local char = localPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local shuriken = getNinjaShuriken()
    if not shuriken then
        local success, msg = spawnShuriken()
        if success then
            SafeNotify({ Title = "Anti Kick", Content = "Shuriken spawned", Duration = 2 })
            task.wait(0.5)
            shuriken = getNinjaShuriken()
            if shuriken then
                attachShuriken(shuriken)
            else
                SafeNotify({ Title = "Anti Kick", Content = "Spawned but not found in folder", Duration = 3 })
            end
        else
            SafeNotify({ Title = "Anti Kick", Content = "Spawn failed: " .. msg, Duration = 4 })
        end
    else
        if not isShurikenAttached(shuriken) then
            local ok, msg = attachShuriken(shuriken)
            if not ok then
                SafeNotify({ Title = "Anti Kick", Content = "Attach failed: " .. msg, Duration = 3 })
            end
        end
    end
end

local function startAntiKick()
    if checkTask then return end
    antiKickEnabled = true
    undeitedhub.Toggles.antiKick = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Anti Kick", Content = "Enabled", Duration = 2 })

    checkTask = task.spawn(function()
        while antiKickEnabled do
            pcall(ensureShuriken)
            task.wait(1)
        end
        checkTask = nil
    end)
end

local function stopAntiKick()
    antiKickEnabled = false
    undeitedhub.Toggles.antiKick = false
    if checkTask then
        task.cancel(checkTask)
        checkTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Anti Kick", Content = "Disabled", Duration = 2 })
end

AntiTab:Toggle({
    Title = "Anti Kick",
    Value = antiKickEnabled,
    Callback = function(state)
        if state then startAntiKick() else stopAntiKick() end
    end
})

if antiKickEnabled then startAntiKick() end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if antiKickEnabled then stopAntiKick() end
    oldDisable()
end