local WindUI = undeitedhub.WindUI
local AntiTab = undeitedhub.Window:Tab({ Title = "Anti Kick" })

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
    if not char then return false end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local pos = rootPart.Position - Vector3.new(0, 0.5, 0)
    local cframe = CFrame.new(pos)
    local args = {
        [1] = "NinjaShuriken",
        [2] = cframe,
        [3] = Vector3.new(0, 0, 0)
    }
    local spawnFunc = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("SpawnToyRemoteFunction")
    if spawnFunc then
        local success, result = pcall(function()
            return spawnFunc:InvokeServer(unpack(args))
        end)
        if success then
            return true
        end
    end
    return false
end

local function attachShuriken(shuriken)
    if not shuriken then return false end
    local sticky = getStickyPart(shuriken)
    if not sticky then return false end
    local char = localPlayer.Character
    if not char then return false end
    local attachPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChildWhichIsA("BasePart")
    if not attachPart then return false end
    local relCFrame = CFrame.new(0, -0.5, 0)
    local args = {
        [1] = sticky,
        [2] = attachPart,
        [3] = relCFrame
    }
    local event = ReplicatedStorage:FindFirstChild("PlayerEvents") and ReplicatedStorage.PlayerEvents:FindFirstChild("StickyPartEvent")
    if event then
        pcall(function()
            event:FireServer(unpack(args))
        end)
        return true
    end
    return false
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
        spawnShuriken()
        task.wait(0.2)
        shuriken = getNinjaShuriken()
    end
    if shuriken then
        if not isShurikenAttached(shuriken) then
            attachShuriken(shuriken)
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