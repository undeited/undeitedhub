local WindUI = undeitedhub.WindUI
local TeleportTab = undeitedhub.Window:Tab({ Title = "Teleport" })

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

local MAP_NAMES = {
    "House2", "BioLab", "Office3", "Hospital3", "Factory",
    "MilBase", "Bank2", "Hotel2", "Mansion2", "PoliceStation",
    "ResearchFacility", "Workplace", "Pier", "BeachResort", "Yacht"
}

local function getCurrentMap()
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj:FindFirstChild("CoinContainer") and obj:FindFirstChild("Spawns") then
            return obj
        end
    end
    for _, name in ipairs(MAP_NAMES) do
        local map = workspace:FindFirstChild(name)
        if map and map:IsA("Model") then
            return map
        end
    end
    return nil
end

local function getPartFromModel(model)
    if model:IsA("BasePart") then return model end
    local primary = model.PrimaryPart
    if primary then return primary end
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            return part
        end
    end
    return nil
end

local function GetSpawnPoints(folder)
    if not folder then return {} end
    local points = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BasePart") then
            table.insert(points, child)
        end
    end
    return points
end

local function TeleportToRandomSpawn(spawnFolder)
    local points = GetSpawnPoints(spawnFolder)
    if #points == 0 then
        return false, "No spawn points found"
    end
    local spawn = points[math.random(1, #points)]
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return false, "Local player not found" end
    local char = localPlayer.Character
    if not char then return false, "Character not found" end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false, "HumanoidRootPart not found" end
    root.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 2, 0))
    return true, "Teleported successfully"
end

local function TeleportToLobby()
    local lobby = workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("RegularLobby")
    if not lobby then
        SafeNotify({ Title = "Error", Content = "Lobby not found", Duration = 2 })
        return
    end
    local spawns = lobby:FindFirstChild("Spawns")
    if not spawns then
        SafeNotify({ Title = "Error", Content = "Spawns folder not found in lobby", Duration = 2 })
        return
    end
    local success, msg = TeleportToRandomSpawn(spawns)
    if success then
        SafeNotify({ Title = "Teleport", Content = "Teleported to lobby spawn", Duration = 2 })
    else
        SafeNotify({ Title = "Error", Content = msg, Duration = 2 })
    end
end

local function TeleportToCurrentMap()
    local map = nil
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("CoinContainer") then
            map = child
            break
        end
    end
    if not map then
        SafeNotify({ Title = "Error", Content = "Could not find current map", Duration = 2 })
        return
    end
    local spawns = map:FindFirstChild("Spawns")
    if not spawns then
        SafeNotify({ Title = "Error", Content = "Spawns folder not found in map", Duration = 2 })
        return
    end
    local success, msg = TeleportToRandomSpawn(spawns)
    if success then
        SafeNotify({ Title = "Teleport", Content = "Teleported to map spawn", Duration = 2 })
    else
        SafeNotify({ Title = "Error", Content = msg, Duration = 2 })
    end
end

TeleportTab:Button({
    Title = "Teleport to Lobby",
    Callback = TeleportToLobby
})

TeleportTab:Button({
    Title = "Teleport to Current Map",
    Callback = TeleportToCurrentMap
})

undeitedhub.DisableAll = function()
end