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
local gunHighlightEnabled = undeitedhub.Toggles.gunHighlightEnabled or false
local coinHighlightEnabled = undeitedhub.Toggles.coinHighlightEnabled or false

local highlightMap = {}
local gunHighlightMap = {}
local coinHighlightMap = {}
local adornmentMap = {}

local lastRefreshAt = 0
local pendingRefresh = false
local MIN_REFRESH_INTERVAL = 0.4

local dirtyPlayers = true
local dirtyGuns = true
local dirtyCoins = true

local roundTimer = workspace:FindFirstChild("RoundTimerPart")

local cachedMapModel = nil
local cachedCoinContainer = nil

local trackedGunDrops = setmetatable({}, { __mode = "k" })

local invisibleThreshold = 0.5

local function computeInvisibleThreshold()
    local values = {}

    for _, player in ipairs(game.Players:GetPlayers()) do
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    local t = math.max(part.Transparency, part.LocalTransparencyModifier or 0)
                    table.insert(values, t)
                end
            end
        end
    end

    if #values < 2 then
        return 0.5
    end

    table.sort(values)

    local maxGap = 0
    local gapMid = 0.5
    for i = 2, #values do
        local gap = values[i] - values[i - 1]
        if gap > maxGap then
            maxGap = gap
            gapMid = (values[i] + values[i - 1]) / 2
        end
    end

    if maxGap < 0.1 then
        local sum = 0
        for _, v in ipairs(values) do sum = sum + v end
        local mean = sum / #values
        if mean > 0.5 then
            return mean * 0.75
        end
        return 0.5
    end

    if gapMid < 0.15 then
        return 0.5
    end

    return gapMid
end

task.spawn(function()
    while true do
        local ok, result = pcall(computeInvisibleThreshold)
        if ok and type(result) == "number" then
            invisibleThreshold = result
        end
        task.wait(3)
    end
end)

local function markPlayersDirty() dirtyPlayers = true end
local function markGunsDirty() dirtyGuns = true end
local function markCoinsDirty() dirtyCoins = true end

local function scheduleRefresh()
    if pendingRefresh then return end
    pendingRefresh = true
    local now = tick()
    local delay = math.max(0, MIN_REFRESH_INTERVAL - (now - lastRefreshAt))
    task.delay(delay, function()
        pendingRefresh = false
        lastRefreshAt = tick()
        if dirtyPlayers then
            dirtyPlayers = false
            pcall(function() if UpdateESP then UpdateESP() end end)
        end
        if dirtyGuns then
            dirtyGuns = false
            pcall(function() if UpdateGunHighlights then UpdateGunHighlights() end end)
        end
        if dirtyCoins then
            dirtyCoins = false
            pcall(function() if UpdateCoinHighlights then UpdateCoinHighlights() end end)
        end
    end)
end

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

local function isCharacterInvisible(character)
    if not character then return false end
    local total = 0
    local hidden = 0
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            total = total + 1
            local t = part.Transparency
            local ltm = part.LocalTransparencyModifier or 0
            if t >= invisibleThreshold or ltm >= invisibleThreshold then
                hidden = hidden + 1
            end
        end
    end
    if total == 0 then return false end
    return hidden == total
end

local function removeAdornment(player)
    local adorn = adornmentMap[player]
    if adorn then
        pcall(adorn.Destroy, adorn)
        adornmentMap[player] = nil
    end
end

local function updateAdornment(player, character, roleColor)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local adorn = adornmentMap[player]

    if not hrp then
        removeAdornment(player)
        return
    end

    if adorn and adorn.Parent ~= hrp then
        pcall(adorn.Destroy, adorn)
        adornmentMap[player] = nil
        adorn = nil
    end

    local invisible = isCharacterInvisible(character)

    if invisible then
        if not adorn then
            adorn = Instance.new("BoxHandleAdornment")
            adorn.Name = "UndeitedSPAdorn"
            adorn.Size = Vector3.new(3, 6, 3)
            adorn.AlwaysOnTop = true
            adorn.ZIndex = 5
            adorn.Transparency = 0.35
            adorn.Adornee = hrp
            adorn.Parent = hrp
            adornmentMap[player] = adorn
        end
        adorn.Color3 = roleColor
        adorn.Adornee = hrp
    else
        if adorn then
            pcall(adorn.Destroy, adorn)
            adornmentMap[player] = nil
        end
    end
end

local function ClearHighlights()
    for _, highlight in pairs(highlightMap) do
        if highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
        end
    end
    highlightMap = {}

    for player in pairs(adornmentMap) do
        removeAdornment(player)
    end
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
    ClearGunHighlights()
    ClearCoinHighlights()
end

function UpdateESP()
    if not espEnabled then
        ClearHighlights()
        return
    end

    if IsInLobby() or not IsRoundActive() then
        ClearHighlights()
        return
    end

    local localPlayer = game.Players.LocalPlayer
    local seen = {}

    for _, player in ipairs(game.Players:GetPlayers()) do
        if player == localPlayer then continue end
        if IsPlayerInLobby(player) then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

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

        updateAdornment(player, character, roleColor)

        seen[player] = true
    end

    for player, highlight in pairs(highlightMap) do
        if not seen[player] and highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
            highlightMap[player] = nil
        end
    end

    for player in pairs(adornmentMap) do
        if not seen[player] then
            removeAdornment(player)
        end
    end
end

local function getCoinContainer()
    if cachedMapModel and cachedMapModel.Parent and cachedCoinContainer and cachedCoinContainer.Parent then
        return cachedCoinContainer
    end

    cachedMapModel = nil
    cachedCoinContainer = nil

    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") then
            local container = child:FindFirstChild("CoinContainer") or child:FindFirstChild("CoinAreas")
            if container then
                cachedMapModel = child
                cachedCoinContainer = container
                return container
            end
        end
    end

    return nil
end

local function getTrackedGunDrops()
    local list = {}
    for gd in pairs(trackedGunDrops) do
        if gd and gd.Parent then
            table.insert(list, gd)
        else
            trackedGunDrops[gd] = nil
        end
    end
    return list
end

function UpdateGunHighlights()
    if not gunHighlightEnabled then
        ClearGunHighlights()
        return
    end
    if IsInLobby() or not IsRoundActive() then
        ClearGunHighlights()
        return
    end

    local gunDrops = getTrackedGunDrops()
    local seen = {}
    for _, gd in ipairs(gunDrops) do
        if gd and gd.Parent then
            seen[gd] = true
            local highlight = gunHighlightMap[gd]
            if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Adornee = gd
                highlight.FillColor = Color3.fromRGB(255, 255, 0)
                highlight.FillTransparency = 0.5
                highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
                highlight.OutlineTransparency = 0.2
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = gd
                gunHighlightMap[gd] = highlight
            end
            highlight.Adornee = gd
            highlight.Enabled = true
        end
    end

    for gd, highlight in pairs(gunHighlightMap) do
        if not seen[gd] or not gd.Parent then
            if highlight and highlight.Parent then
                pcall(highlight.Destroy, highlight)
            end
            gunHighlightMap[gd] = nil
        end
    end
end

local function GetAllCoinParts()
    local container = getCoinContainer()
    if not container then return {} end
    local parts = {}
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("BasePart") then
            table.insert(parts, obj)
        end
    end
    return parts
end

function UpdateCoinHighlights()
    if not coinHighlightEnabled then
        ClearCoinHighlights()
        return
    end
    if IsInLobby() or not IsRoundActive() then
        ClearCoinHighlights()
        return
    end

    local coinParts = GetAllCoinParts()
    local seen = {}
    for _, part in ipairs(coinParts) do
        if part and part.Parent then
            seen[part] = true
            local highlight = coinHighlightMap[part]
            if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Adornee = part
                highlight.FillColor = Color3.fromRGB(255, 215, 0)
                highlight.FillTransparency = 0.5
                highlight.OutlineColor = Color3.fromRGB(255, 215, 0)
                highlight.OutlineTransparency = 0.2
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = part
                coinHighlightMap[part] = highlight
            end
            highlight.Adornee = part
            highlight.Enabled = true
        end
    end

    for part, highlight in pairs(coinHighlightMap) do
        if not seen[part] or not part.Parent then
            if highlight and highlight.Parent then
                pcall(highlight.Destroy, highlight)
            end
            coinHighlightMap[part] = nil
        end
    end
end

VisualTab:Toggle({
    Title = "Player Highlight",
    Value = espEnabled,
    Callback = function(state)
        espEnabled = state
        undeitedhub.Toggles.espEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Player Highlight", Content = state and "Enabled" or "Disabled", Duration = 2 })
        if not espEnabled then ClearHighlights() end
        markPlayersDirty()
        scheduleRefresh()
    end
})

VisualTab:Toggle({
    Title = "Gun Drop Highlight",
    Value = gunHighlightEnabled,
    Callback = function(state)
        gunHighlightEnabled = state
        undeitedhub.Toggles.gunHighlightEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Gun Drop Highlight", Content = state and "Enabled" or "Disabled", Duration = 2 })
        if not gunHighlightEnabled then ClearGunHighlights() end
        markGunsDirty()
        scheduleRefresh()
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
        markCoinsDirty()
        scheduleRefresh()
    end
})

local function ConnectPlayer(player)
    if not player then return end
    player.CharacterAdded:Connect(function()
        task.wait(0.2)
        markPlayersDirty()
        scheduleRefresh()
    end)
    player.CharacterRemoving:Connect(function()
        markPlayersDirty()
        scheduleRefresh()
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
    removeAdornment(player)
end)

workspace.DescendantAdded:Connect(function(obj)
    if obj.Name == "GunDrop" then
        trackedGunDrops[obj] = true
        if gunHighlightEnabled then
            markGunsDirty()
            scheduleRefresh()
        end
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if obj.Name == "GunDrop" then
        trackedGunDrops[obj] = nil
        if gunHighlightEnabled then
            markGunsDirty()
            scheduleRefresh()
        end
    end
end)

if roundTimer then
    roundTimer:GetAttributeChangedSignal("Time"):Connect(function()
        markPlayersDirty()
        markGunsDirty()
        markCoinsDirty()
        scheduleRefresh()
    end)
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
                    markPlayersDirty()
                    scheduleRefresh()
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
                markPlayersDirty()
                markGunsDirty()
                markCoinsDirty()
                scheduleRefresh()
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
    if changed then
        markPlayersDirty()
        scheduleRefresh()
    end
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

task.spawn(function()
    while true do
        task.wait(0.5)
        if dirtyPlayers or dirtyGuns or dirtyCoins then
            scheduleRefresh()
        end
    end
end)

undeitedhub.DisableAll = undeitedhub.DisableAll or function() end
local oldDisable = undeitedhub.DisableAll
undeitedhub.DisableAll = function()
    espEnabled = false
    gunHighlightEnabled = false
    coinHighlightEnabled = false
    undeitedhub.Toggles.espEnabled = false
    undeitedhub.Toggles.gunHighlightEnabled = false
    undeitedhub.Toggles.coinHighlightEnabled = false
    ClearESP()
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    oldDisable()
end

if espEnabled or gunHighlightEnabled or coinHighlightEnabled then
    markPlayersDirty()
    markGunsDirty()
    markCoinsDirty()
    scheduleRefresh()
end
