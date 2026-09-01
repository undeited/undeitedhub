local WindUI = undeitedhub and undeitedhub.WindUI
local utils = undeitedhub and undeitedhub.Utils
local config = undeitedhub and undeitedhub.Config

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

local VisualTab = undeitedhub and undeitedhub.Window and undeitedhub.Window:Tab({ Title = "Visual" })
if not VisualTab then return end

local espEnabled = undeitedhub.Toggles.espEnabled or false
local highlightInstances = {}
local gunHighlightEnabled = undeitedhub.Toggles.gunHighlightEnabled or false
local gunHighlightInstances = {}
local coinHighlightEnabled = undeitedhub.Toggles.coinHighlightEnabled or false
local coinHighlightMap = {}
local coinHighlightLastUpdate = 0

undeitedhub.playerRoles = undeitedhub.playerRoles or {}

local roundTimer = workspace:FindFirstChild("RoundTimerPart")
local shouldShowESP = false

local function IsInLobby()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return true end
    if roundTimer then
        local time = roundTimer:GetAttribute("Time")
        if time ~= nil and time > 0 then
            return false
        end
    end
    local character = localPlayer.Character
    if not character then return true end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return true end
    local lobby = workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("RegularLobby")
    if not lobby then return false end
    local lobbyPos
    if lobby:IsA("BasePart") then
        lobbyPos = lobby.Position
    elseif lobby.PrimaryPart then
        lobbyPos = lobby.PrimaryPart.Position
    else
        for _, part in ipairs(lobby:GetDescendants()) do
            if part:IsA("BasePart") then
                lobbyPos = part.Position
                break
            end
        end
    end
    if not lobbyPos then return false end
    return (rootPart.Position - lobbyPos).Magnitude < 75
end

local function IsPlayerInLobby(player)
    if not player then return false end
    local character = player.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    local lobby = workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("RegularLobby")
    if not lobby then return false end
    local lobbyPos
    if lobby:IsA("BasePart") then
        lobbyPos = lobby.Position
    elseif lobby.PrimaryPart then
        lobbyPos = lobby.PrimaryPart.Position
    else
        for _, part in ipairs(lobby:GetDescendants()) do
            if part:IsA("BasePart") then
                lobbyPos = part.Position
                break
            end
        end
    end
    if not lobbyPos then return false end
    return (rootPart.Position - lobbyPos).Magnitude < 75
end

local function IsRoundActive()
    if not roundTimer then
        return not IsInLobby()
    end
    local time = roundTimer:GetAttribute("Time")
    if time == nil then return not IsInLobby() end
    return time > 0
end

local function normalizeRole(role)
    if type(role) == "table" then
        role = role.Role or role.Name or tostring(role)
    end
    if type(role) ~= "string" then return "Innocent" end
    local lower = string.lower(role)
    if lower == "murderer" or lower == "killer" then
        return "Murderer"
    elseif lower == "sheriff" or lower == "hero" or lower == "sheriff (hero)" then
        return "Sheriff"
    else
        return "Innocent"
    end
end

local function playerHasToolPattern(player, pattern)
    if not player then return false end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and string.lower(tool.Name):find(pattern) then
                return true
            end
        end
    end
    local character = player.Character
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") and string.lower(tool.Name):find(pattern) then
                return true
            end
        end
    end
    return false
end

local function detectRoleFromTools(player)
    if playerHasToolPattern(player, "knife") or playerHasToolPattern(player, "murderer") then
        return "Murderer"
    elseif playerHasToolPattern(player, "gun") or playerHasToolPattern(player, "sheriff") or playerHasToolPattern(player, "revolver") then
        return "Sheriff"
    else
        return "Innocent"
    end
end

local function GetPlayerRole(player)
    if not player then return "Innocent" end
    if undeitedhub.playerRoles and undeitedhub.playerRoles[player] then
        return normalizeRole(undeitedhub.playerRoles[player])
    end
    local role = player:GetAttribute("Role")
    if role then
        return normalizeRole(role)
    end
    local char = player.Character
    if char then
        local roleVal = char:FindFirstChild("Role") or char:FindFirstChild("PlayerRole")
        if roleVal and roleVal:IsA("StringValue") then
            return normalizeRole(roleVal.Value)
        end
    end
    return detectRoleFromTools(player)
end

local function GetPlayerRoleColor(player)
    if not config or not config.colors then return Color3.new(1, 1, 1) end
    if undeitedhub.GetCurrentMurderer and undeitedhub.GetCurrentMurderer() == player then
        return config.colors.murderer or Color3.fromRGB(255, 0, 0)
    end
    if undeitedhub.GetCurrentSheriff and undeitedhub.GetCurrentSheriff() == player then
        return config.colors.sheriff or Color3.fromRGB(0, 100, 255)
    end
    local role = GetPlayerRole(player)
    if role == "Murderer" then
        return config.colors.murderer or Color3.fromRGB(255, 0, 0)
    elseif role == "Sheriff" then
        return config.colors.sheriff or Color3.fromRGB(0, 100, 255)
    else
        return config.colors.innocent or Color3.fromRGB(0, 255, 0)
    end
end

local function ClearESP()
    for _, highlight in pairs(highlightInstances) do
        if highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
        end
    end
    highlightInstances = {}
end

local function UpdateESP()
    if not espEnabled then
        ClearESP()
        return
    end
    if IsInLobby() or not IsRoundActive() then
        ClearESP()
        return
    end
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return end
    local playersToHighlight = {}
    for _, player in pairs(game.Players:GetPlayers()) do
        if player == localPlayer then continue end
        if IsPlayerInLobby(player) then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        playersToHighlight[player] = true
    end
    for player, highlight in pairs(highlightInstances) do
        if not playersToHighlight[player] then
            if highlight and highlight.Parent then
                pcall(highlight.Destroy, highlight)
            end
            highlightInstances[player] = nil
        end
    end
    for player, _ in pairs(playersToHighlight) do
        local roleColor = GetPlayerRoleColor(player)
        if roleColor then
            local highlight = highlightInstances[player]
            if highlight then
                pcall(function()
                    highlight.FillColor = roleColor
                    highlight.OutlineColor = roleColor
                end)
            else
                pcall(function()
                    highlight = Instance.new("Highlight")
                    highlight.Adornee = player.Character
                    highlight.FillColor = roleColor
                    highlight.FillTransparency = 0.5
                    highlight.OutlineColor = roleColor
                    highlight.OutlineTransparency = 0.2
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = player.Character
                    highlightInstances[player] = highlight
                end)
            end
        end
    end
end

local function ClearGunHighlights()
    for _, highlight in pairs(gunHighlightInstances) do
        if highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
        end
    end
    gunHighlightInstances = {}
end

local function UpdateGunHighlights()
    if not gunHighlightEnabled then
        ClearGunHighlights()
        return
    end
    if IsInLobby() or not IsRoundActive() then
        ClearGunHighlights()
        return
    end
    local gunDrops = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" then
            table.insert(gunDrops, obj)
        end
    end
    local newHighlightList = {}
    for _, gd in ipairs(gunDrops) do
        if gd and gd.Parent then
            pcall(function()
                local highlight = Instance.new("Highlight")
                highlight.Adornee = gd
                highlight.FillColor = Color3.fromRGB(255, 255, 0)
                highlight.FillTransparency = 0.5
                highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
                highlight.OutlineTransparency = 0.2
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = gd
                table.insert(newHighlightList, highlight)
            end)
        end
    end
    for _, highlight in pairs(gunHighlightInstances) do
        if highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
        end
    end
    gunHighlightInstances = newHighlightList
end

local function GetAllCoinParts()
    local parts = {}
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") then
            local container = child:FindFirstChild("CoinContainer") or child:FindFirstChild("CoinAreas")
            if container then
                for _, obj in ipairs(container:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        table.insert(parts, obj)
                    end
                end
            end
        end
    end
    return parts
end

local function ClearCoinHighlights()
    for part, highlight in pairs(coinHighlightMap) do
        if highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
        end
    end
    coinHighlightMap = {}
end

local function UpdateCoinHighlights()
    if not coinHighlightEnabled then
        ClearCoinHighlights()
        return
    end
    if IsInLobby() or not IsRoundActive() then
        ClearCoinHighlights()
        return
    end
    local currentParts = GetAllCoinParts()
    local currentSet = {}
    for _, part in ipairs(currentParts) do
        currentSet[part] = true
    end
    for part, highlight in pairs(coinHighlightMap) do
        if not currentSet[part] or not part.Parent then
            if highlight and highlight.Parent then
                pcall(highlight.Destroy, highlight)
            end
            coinHighlightMap[part] = nil
        end
    end
    for _, part in ipairs(currentParts) do
        if not coinHighlightMap[part] then
            pcall(function()
                local highlight = Instance.new("Highlight")
                highlight.Adornee = part
                highlight.FillColor = Color3.fromRGB(255, 215, 0)
                highlight.FillTransparency = 0.5
                highlight.OutlineColor = Color3.fromRGB(255, 215, 0)
                highlight.OutlineTransparency = 0.2
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = part
                coinHighlightMap[part] = highlight
            end)
        end
    end
end

local replicatedStorage = game:GetService("ReplicatedStorage")
local remotes = replicatedStorage:FindFirstChild("Remotes")
local gameplay = remotes and remotes:FindFirstChild("Gameplay")

if gameplay then
    local roleSelect = gameplay:FindFirstChild("RoleSelect")
    if roleSelect and roleSelect:IsA("RemoteEvent") then
        roleSelect.OnClientEvent:Connect(function(role, ...)
            pcall(function()
                local localPlayer = game.Players.LocalPlayer
                if localPlayer then
                    local normalized = normalizeRole(role)
                    undeitedhub.playerRoles[localPlayer] = normalized
                    localPlayer:SetAttribute("Role", normalized)
                    UpdateESP()
                end
            end)
        end)
    end
    local roundStart = gameplay:FindFirstChild("RoundStart")
    if roundStart and roundStart:IsA("RemoteEvent") then
        roundStart.OnClientEvent:Connect(function(time, playerData)
            pcall(function()
                if type(playerData) ~= "table" then return end
                for playerName, data in pairs(playerData) do
                    local player = game.Players:FindFirstChild(playerName)
                    if player and data.Role then
                        local role = normalizeRole(data.Role)
                        undeitedhub.playerRoles[player] = role
                        player:SetAttribute("Role", role)
                    end
                end
                UpdateESP()
            end)
        end)
    end
    local playerDataChanged = gameplay:FindFirstChild("PlayerDataChanged")
    if playerDataChanged and playerDataChanged:IsA("RemoteEvent") then
        playerDataChanged.OnClientEvent:Connect(function(data)
            pcall(function() updateRolesFromData(data) end)
        end)
    end
    local roleData = gameplay:FindFirstChild("RoleData")
    if roleData and roleData:IsA("RemoteEvent") then
        roleData.OnClientEvent:Connect(function(data)
            pcall(function() updateRolesFromData(data) end)
        end)
    end
end

local function updateRolesFromData(data)
    if type(data) ~= "table" then return end
    for playerName, role in pairs(data) do
        local player = game.Players:FindFirstChild(playerName)
        if player then
            local normalized = normalizeRole(role)
            undeitedhub.playerRoles[player] = normalized
            if type(normalized) == "string" then
                player:SetAttribute("Role", normalized)
            end
        end
    end
    UpdateESP()
end

workspace.DescendantAdded:Connect(function(obj)
    if obj.Name == "GunDrop" and gunHighlightEnabled and not IsInLobby() and IsRoundActive() then
        UpdateGunHighlights()
    end
end)
workspace.DescendantRemoving:Connect(function(obj)
    if obj.Name == "GunDrop" and not IsInLobby() and IsRoundActive() then
        pcall(UpdateESP)
    end
end)

local function forceRoleScan()
    if IsInLobby() or not IsRoundActive() then return end
    local changed = false
    for _, player in pairs(game.Players:GetPlayers()) do
        if IsPlayerInLobby(player) then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        local role = detectRoleFromTools(player)
        if role ~= "Innocent" then
            local current = undeitedhub.playerRoles[player]
            if current ~= role then
                undeitedhub.playerRoles[player] = role
                player:SetAttribute("Role", role)
                changed = true
            end
        end
    end
    if changed then
        UpdateESP()
    end
end

undeitedhub.ForceRoleScan = forceRoleScan

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(forceRoleScan)
    end
end)

local function setupToolListener(player)
    if not player then return end
    local function onCharacterAdded(char)
        if not char then return end
        local function onDescendantAdded(desc)
            if desc:IsA("Tool") and string.lower(desc.Name):find("gun") then
                pcall(function()
                    UpdateESP()
                    forceRoleScan()
                end)
            end
        end
        char.DescendantAdded:Connect(onDescendantAdded)
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            backpack.DescendantAdded:Connect(function(desc)
                if desc:IsA("Tool") and string.lower(desc.Name):find("gun") then
                    pcall(function()
                        UpdateESP()
                        forceRoleScan()
                    end)
                end
            end)
        end
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") and string.lower(child.Name):find("gun") then
                pcall(function()
                    UpdateESP()
                    forceRoleScan()
                end)
                break
            end
        end
    end
    if player.Character then
        onCharacterAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)
end

for _, player in ipairs(game.Players:GetPlayers()) do
    setupToolListener(player)
end
game.Players.PlayerAdded:Connect(setupToolListener)

local function refreshRoundState()
    pcall(function()
        local inLobby = IsInLobby()
        local active = IsRoundActive()
        if not inLobby and active then
            if not shouldShowESP then
                shouldShowESP = true
                undeitedhub.playerRoles = {}
                UpdateESP()
                UpdateGunHighlights()
                UpdateCoinHighlights()
            end
        else
            if shouldShowESP then
                shouldShowESP = false
                ClearESP()
                ClearGunHighlights()
                ClearCoinHighlights()
                undeitedhub.playerRoles = {}
            end
        end
    end)
end

if roundTimer then
    roundTimer:GetAttributeChangedSignal("Time"):Connect(refreshRoundState)
end

game:GetService("RunService").Heartbeat:Connect(function()
    pcall(refreshRoundState)
    if coinHighlightEnabled and not IsInLobby() and IsRoundActive() then
        local now = tick()
        if now - coinHighlightLastUpdate > 2 then
            coinHighlightLastUpdate = now
            pcall(UpdateCoinHighlights)
        end
    end
end)

game.Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        pcall(forceRoleScan)
    end)
    player:GetAttributeChangedSignal("Role"):Connect(function()
        pcall(UpdateESP)
    end)
end)

game.Players.PlayerRemoving:Connect(function(player)
    if highlightInstances[player] then
        pcall(function()
            highlightInstances[player]:Destroy()
            highlightInstances[player] = nil
        end)
    end
    undeitedhub.playerRoles[player] = nil
end)

VisualTab:Toggle({
    Title = "Player Highlight",
    Value = espEnabled,
    Callback = function(state)
        pcall(function()
            espEnabled = state
            undeitedhub.Toggles.espEnabled = state
            if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
            SafeNotify({
                Title = "Player Highlight",
                Content = espEnabled and "Enabled" or "Disabled",
                Duration = 2,
            })
            if not espEnabled then
                ClearESP()
            else
                UpdateESP()
            end
        end)
    end
})

VisualTab:Toggle({
    Title = "Gun Highlight",
    Value = gunHighlightEnabled,
    Callback = function(state)
        pcall(function()
            gunHighlightEnabled = state
            undeitedhub.Toggles.gunHighlightEnabled = state
            if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
            SafeNotify({
                Title = "Gun Highlight",
                Content = gunHighlightEnabled and "Enabled" or "Disabled",
                Duration = 2,
            })
            if not gunHighlightEnabled then
                ClearGunHighlights()
            else
                UpdateGunHighlights()
            end
        end)
    end
})

VisualTab:Toggle({
    Title = "Coin Highlight",
    Value = coinHighlightEnabled,
    Callback = function(state)
        pcall(function()
            coinHighlightEnabled = state
            undeitedhub.Toggles.coinHighlightEnabled = state
            if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
            SafeNotify({
                Title = "Coin Highlight",
                Content = coinHighlightEnabled and "Enabled" or "Disabled",
                Duration = 2,
            })
            if not coinHighlightEnabled then
                ClearCoinHighlights()
            else
                UpdateCoinHighlights()
            end
        end)
    end
})

undeitedhub.GetCurrentMurderer = function()
    for _, player in pairs(game.Players:GetPlayers()) do
        if player == game.Players.LocalPlayer then continue end
        if IsPlayerInLobby(player) then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        if GetPlayerRole(player) == "Murderer" then
            return player
        end
    end
    return nil
end

undeitedhub.GetCurrentSheriff = function()
    for _, player in pairs(game.Players:GetPlayers()) do
        if player == game.Players.LocalPlayer then continue end
        if IsPlayerInLobby(player) then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        local hasGun = character:FindFirstChild("Gun") or player.Backpack:FindFirstChild("Gun")
        if hasGun then
            return player
        end
    end
    return nil
end

undeitedhub.DisableAll = function()
    pcall(function()
        espEnabled = false
        gunHighlightEnabled = false
        coinHighlightEnabled = false
        undeitedhub.Toggles.espEnabled = false
        undeitedhub.Toggles.gunHighlightEnabled = false
        undeitedhub.Toggles.coinHighlightEnabled = false
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        ClearESP()
        ClearGunHighlights()
        ClearCoinHighlights()
    end)
end

if espEnabled then
    task.spawn(function()
        task.wait(0.5)
        refreshRoundState()
        UpdateESP()
    end)
end