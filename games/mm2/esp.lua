local WindUI = undeitedhub.WindUI
local config = undeitedhub.Config

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

local VisualTab = undeitedhub.Window:Tab({ Title = "Visual" })

local espEnabled = undeitedhub.Toggles.espEnabled or false
local espNamesEnabled = undeitedhub.Toggles.espNamesEnabled or false
local gunHighlightEnabled = undeitedhub.Toggles.gunHighlightEnabled or false
local coinHighlightEnabled = undeitedhub.Toggles.coinHighlightEnabled or false

local highlightMap = {}
local nameMap = {}
local gunHighlightMap = {}
local coinHighlightMap = {}

local roundTimer = workspace:FindFirstChild("RoundTimerPart")

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

local function ClearHighlights()
    for _, highlight in pairs(highlightMap) do
        if highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
        end
    end
    highlightMap = {}
end

local function ClearNames()
    for _, billboard in pairs(nameMap) do
        if billboard and billboard.Parent then
            pcall(billboard.Destroy, billboard)
        end
    end
    nameMap = {}
end

local function ClearGunHighlights()
    for _, highlight in pairs(gunHighlightMap) do
        if highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
        end
    end
    gunHighlightMap = {}
end

local function ClearCoinHighlights()
    for _, highlight in pairs(coinHighlightMap) do
        if highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
        end
    end
    coinHighlightMap = {}
end

local function ClearESP()
    ClearHighlights()
    ClearNames()
    ClearGunHighlights()
    ClearCoinHighlights()
end

local function CreateNameTag(player, character)
    if nameMap[player] then
        pcall(nameMap[player].Destroy, nameMap[player])
        nameMap[player] = nil
    end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end

    local displayName = player.DisplayName or player.Name

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 18)
    billboard.Adornee = head
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 1000

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = displayName
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = false
    label.TextSize = 13
    label.Font = Enum.Font.GothamSemibold
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3 = Color3.new(0, 0, 0)

    label.Parent = billboard
    billboard.Parent = character
    nameMap[player] = billboard
end

local function UpdateESP()
    if not espEnabled and not espNamesEnabled then
        ClearESP()
        return
    end

    if IsInLobby() or not IsRoundActive() then
        ClearESP()
        return
    end

    local localPlayer = game.Players.LocalPlayer
    local localChar = localPlayer and localPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local seen = {}

    for _, player in ipairs(game.Players:GetPlayers()) do
        if player == localPlayer then continue end
        if IsPlayerInLobby(player) then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        if espEnabled then
            local roleColor = GetPlayerRoleColor(player)
            local highlight = highlightMap[player]
            if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Name = "UndeitedSP"
                highlight.FillColor = roleColor
                highlight.FillTransparency = 0.5
                highlight.OutlineColor = roleColor
                highlight.OutlineTransparency = 0.2
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = character
                highlightMap[player] = highlight
            end
            highlight.Adornee = character
            highlight.FillColor = roleColor
            highlight.OutlineColor = roleColor
            highlight.Enabled = true
        end

        if espNamesEnabled then
            if not nameMap[player] then
                CreateNameTag(player, character)
            end
            local targetRoot = character:FindFirstChild("HumanoidRootPart")
            local billboard = nameMap[player]
            if billboard and localRoot and targetRoot then
                local dist = (targetRoot.Position - localRoot.Position).Magnitude
                billboard.Enabled = dist >= 50
            elseif billboard then
                billboard.Enabled = true
            end
        end

        seen[player] = true
    end

    if espEnabled then
        for player, highlight in pairs(highlightMap) do
            if not seen[player] and highlight and highlight.Parent then
                pcall(highlight.Destroy, highlight)
                highlightMap[player] = nil
            end
        end
    else
        ClearHighlights()
    end

    if espNamesEnabled then
        for player, billboard in pairs(nameMap) do
            if not seen[player] and billboard and billboard.Parent then
                pcall(billboard.Destroy, billboard)
                nameMap[player] = nil
            end
        end
    else
        ClearNames()
    end
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
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" then
            table.insert(gunDrops, obj)
        end
    end

    local newHighlightMap = {}
    for _, gd in ipairs(gunDrops) do
        if gd and gd.Parent then
            local highlight = Instance.new("Highlight")
            highlight.Adornee = gd
            highlight.FillColor = Color3.fromRGB(255, 255, 0)
            highlight.FillTransparency = 0.5
            highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
            highlight.OutlineTransparency = 0.2
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = gd
            table.insert(newHighlightMap, highlight)
        end
    end

    ClearGunHighlights()
    for _, highlight in ipairs(newHighlightMap) do
        gunHighlightMap[highlight] = true
    end
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

local function UpdateCoinHighlights()
    if not coinHighlightEnabled then
        ClearCoinHighlights()
        return
    end
    if IsInLobby() or not IsRoundActive() then
        ClearCoinHighlights()
        return
    end

    local coinParts = GetAllCoinParts()
    local newHighlightMap = {}
    for _, part in ipairs(coinParts) do
        if part and part.Parent then
            local highlight = Instance.new("Highlight")
            highlight.Adornee = part
            highlight.FillColor = Color3.fromRGB(255, 215, 0)
            highlight.FillTransparency = 0.5
            highlight.OutlineColor = Color3.fromRGB(255, 215, 0)
            highlight.OutlineTransparency = 0.2
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = part
            table.insert(newHighlightMap, highlight)
        end
    end

    ClearCoinHighlights()
    for _, highlight in ipairs(newHighlightMap) do
        coinHighlightMap[highlight] = true
    end
end

local function RefreshESP()
    pcall(UpdateESP)
    pcall(UpdateGunHighlights)
    pcall(UpdateCoinHighlights)
end

VisualTab:Toggle({
    Title = "ESP Highlight",
    Value = espEnabled,
    Callback = function(state)
        espEnabled = state
        undeitedhub.Toggles.espEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "ESP Highlight", Content = state and "Enabled" or "Disabled", Duration = 2 })
        if not espEnabled then ClearHighlights() end
        RefreshESP()
    end
})

VisualTab:Toggle({
    Title = "ESP Names",
    Value = espNamesEnabled,
    Callback = function(state)
        espNamesEnabled = state
        undeitedhub.Toggles.espNamesEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "ESP Names", Content = state and "Enabled" or "Disabled", Duration = 2 })
        if not espNamesEnabled then ClearNames() end
        RefreshESP()
    end
})

VisualTab:Toggle({
    Title = "Gun Highlight",
    Value = gunHighlightEnabled,
    Callback = function(state)
        gunHighlightEnabled = state
        undeitedhub.Toggles.gunHighlightEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Gun Highlight", Content = state and "Enabled" or "Disabled", Duration = 2 })
        if not gunHighlightEnabled then ClearGunHighlights() end
        RefreshESP()
    end
})

VisualTab:Toggle({
    Title = "Coin Highlight",
    Value = coinHighlightEnabled,
    Callback = function(state)
        coinHighlightEnabled = state
        undeitedhub.Toggles.coinHighlightEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Coin Highlight", Content = state and "Enabled" or "Disabled", Duration = 2 })
        if not coinHighlightEnabled then ClearCoinHighlights() end
        RefreshESP()
    end
})

local function ConnectPlayer(player)
    if not player then return end
    player.CharacterAdded:Connect(function()
        task.wait(0.2)
        RefreshESP()
    end)
    player.CharacterRemoving:Connect(function()
        RefreshESP()
    end)
end

for _, player in ipairs(game.Players:GetPlayers()) do
    ConnectPlayer(player)
end

game.Players.PlayerAdded:Connect(ConnectPlayer)

game.Players.PlayerRemoving:Connect(function(player)
    if highlightMap[player] then
        pcall(highlightMap[player].Destroy, highlightMap[player])
        highlightMap[player] = nil
    end
    if nameMap[player] then
        pcall(nameMap[player].Destroy, nameMap[player])
        nameMap[player] = nil
    end
end)

workspace.DescendantAdded:Connect(function(obj)
    if obj.Name == "GunDrop" and gunHighlightEnabled then
        RefreshESP()
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if obj.Name == "GunDrop" or obj.Name:find("Coin") then
        RefreshESP()
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(RefreshESP)
    end
end)

if roundTimer then
    roundTimer:GetAttributeChangedSignal("Time"):Connect(RefreshESP)
end

local replicatedStorage = game:GetService("ReplicatedStorage")
local remotes = replicatedStorage:FindFirstChild("Remotes")
local gameplay = remotes and remotes:FindFirstChild("Gameplay")
if gameplay then
    local roleSelect = gameplay:FindFirstChild("RoleSelect")
    if roleSelect and roleSelect:IsA("RemoteEvent") then
        roleSelect.OnClientEvent:Connect(function(role)
            pcall(function()
                local localPlayer = game.Players.LocalPlayer
                if localPlayer then
                    local normalized = normalizeRole(role)
                    undeitedhub.playerRoles = undeitedhub.playerRoles or {}
                    undeitedhub.playerRoles[localPlayer] = normalized
                    localPlayer:SetAttribute("Role", normalized)
                    RefreshESP()
                end
            end)
        end)
    end
    local roundStart = gameplay:FindFirstChild("RoundStart")
    if roundStart and roundStart:IsA("RemoteEvent") then
        roundStart.OnClientEvent:Connect(function(time, playerData)
            pcall(function()
                if type(playerData) ~= "table" then return end
                undeitedhub.playerRoles = undeitedhub.playerRoles or {}
                for playerName, data in pairs(playerData) do
                    local player = game.Players:FindFirstChild(playerName)
                    if player and data.Role then
                        local role = normalizeRole(data.Role)
                        undeitedhub.playerRoles[player] = role
                        player:SetAttribute("Role", role)
                    end
                end
                RefreshESP()
            end)
        end)
    end
end

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
            local current = undeitedhub.playerRoles and undeitedhub.playerRoles[player]
            if current ~= role then
                undeitedhub.playerRoles = undeitedhub.playerRoles or {}
                undeitedhub.playerRoles[player] = role
                player:SetAttribute("Role", role)
                changed = true
            end
        end
    end
    if changed then RefreshESP() end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(forceRoleScan)
    end
end)

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
        if GetPlayerRole(player) == "Sheriff" then
            return player
        end
    end
    return nil
end

undeitedhub.DisableAll = undeitedhub.DisableAll or function() end
local oldDisable = undeitedhub.DisableAll
undeitedhub.DisableAll = function()
    espEnabled = false
    espNamesEnabled = false
    gunHighlightEnabled = false
    coinHighlightEnabled = false
    undeitedhub.Toggles.espEnabled = false
    undeitedhub.Toggles.espNamesEnabled = false
    undeitedhub.Toggles.gunHighlightEnabled = false
    undeitedhub.Toggles.coinHighlightEnabled = false
    ClearESP()
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    oldDisable()
end

if espEnabled or espNamesEnabled or gunHighlightEnabled or coinHighlightEnabled then
    task.spawn(function()
        task.wait(0.5)
        RefreshESP()
    end)
end