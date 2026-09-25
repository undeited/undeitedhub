local WindUI = undeitedhub.WindUI

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Stats = game:GetService("Stats")

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

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local Tuning = {
    lastUpdate = 0,
    refreshInterval = 2,
    ping = 0,
    pingFactor = 0,
    playerFactor = 0,
    players = 1,
}

local function readPing()
    local ok, ping = pcall(function()
        if Stats and Stats.Network and Stats.Network.ServerStatsItem then
            local item = Stats.Network.ServerStatsItem["Data Ping"]
            if item then return item:GetValue() / 1000 end
        end
        return 0
    end)
    if not ok or type(ping) ~= "number" or ping ~= ping then return 0 end
    return ping
end

local function refreshTuning()
    local now = tick()
    if Tuning.lastUpdate > 0 and now - Tuning.lastUpdate < Tuning.refreshInterval then return end
    Tuning.lastUpdate = now

    local ping = readPing()
    local players = math.max(1, #Players:GetPlayers())

    local pingFactor = clamp(ping / 0.2, 0, 2)
    local playerFactor = clamp((players - 1) / 12, 0, 2)

    Tuning.ping = ping
    Tuning.pingFactor = pingFactor
    Tuning.playerFactor = playerFactor
    Tuning.players = players

    Tuning.minRefreshInterval = clamp(0.5 * (1 + playerFactor * 0.4) * (1 + pingFactor * 0.2), 0.15, 1.0)

    Tuning.loopInterval = clamp(0.15 * (1 + playerFactor * 0.7) * (1 + pingFactor * 0.3), 0.08, 0.6)

    Tuning.maxHighlightRefresh = clamp(0.2 * (1 + playerFactor * 0.5), 0.15, 0.6)
end

refreshTuning()

local VisualTab = undeitedhub.Window:Tab({ Title = "Visual" })

local espEnabled = undeitedhub.Toggles.espEnabled or false
local highlightMap = {}
local ESP_COLOR = Color3.fromRGB(255, 0, 0)
local espLoopTask = nil

local lastRefreshAt = 0
local pendingRefresh = false

local playerConnections = setmetatable({}, { __mode = "k" })

local function ClearHighlights()
    for _, highlight in pairs(highlightMap) do
        if highlight and highlight.Parent then
            pcall(function() highlight:Destroy() end)
        end
    end
    highlightMap = {}
end

local function removeHighlight(player)
    local highlight = highlightMap[player]
    if highlight then
        if highlight.Parent then
            pcall(function() highlight:Destroy() end)
        end
        highlightMap[player] = nil
    end
end

local function getValidCharacter(player)
    local character = player.Character
    if not character or not character.Parent then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    return character
end

local function createHighlight(character)
    local highlight = Instance.new("Highlight")
    highlight.Name = "UndeitedSP"
    highlight.FillColor = ESP_COLOR
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = ESP_COLOR
    highlight.OutlineTransparency = 0.2
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = character
    highlight.Parent = character
    return highlight
end

local function UpdateESP()
    if not espEnabled then
        ClearHighlights()
        return
    end

    local seen = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local character = getValidCharacter(player)
        if not character then
            removeHighlight(player)
            continue
        end

        local highlight = highlightMap[player]
        if not highlight or not highlight.Parent then
            if highlight then
                pcall(function() highlight:Destroy() end)
            end
            highlight = createHighlight(character)
            highlightMap[player] = highlight
        end

        if highlight.Adornee ~= character then
            highlight.Adornee = character
        end

        seen[player] = true
    end

    for player in pairs(highlightMap) do
        if not seen[player] then
            removeHighlight(player)
        end
    end
end

local function scheduleRefresh()
    if pendingRefresh then return end
    pendingRefresh = true
    refreshTuning()
    local now = tick()
    local delay = math.max(0, Tuning.minRefreshInterval - (now - lastRefreshAt))
    task.delay(delay, function()
        pendingRefresh = false
        lastRefreshAt = tick()
        pcall(UpdateESP)
    end)
end

local function startESPLoop()
    if espLoopTask then return end
    espLoopTask = task.spawn(function()
        while espEnabled do
            refreshTuning()

            local now = tick()
            if now - lastRefreshAt >= Tuning.minRefreshInterval then
                lastRefreshAt = now
                local ok, err = pcall(UpdateESP)
                if not ok then
                    SafeNotify({ Title = "Player Highlight", Content = "Update error: " .. tostring(err):sub(1, 80), Duration = 3 })
                end
            end

            task.wait(Tuning.loopInterval)
        end
        espLoopTask = nil
    end)
end

local function watchPlayer(player)
    if not player or player == LocalPlayer then return end
    if playerConnections[player] then return end

    local charAdded = player.CharacterAdded:Connect(function()
        task.wait(0.2)
        if espEnabled then scheduleRefresh() end
    end)

    local charRemoving = player.CharacterRemoving:Connect(function()
        if espEnabled then
            removeHighlight(player)
            scheduleRefresh()
        end
    end)

    playerConnections[player] = { charAdded, charRemoving }
end

local function unwatchPlayer(player)
    local conns = playerConnections[player]
    if conns then
        for _, c in ipairs(conns) do
            pcall(function() c:Disconnect() end)
        end
        playerConnections[player] = nil
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
        if not espEnabled then
            ClearHighlights()
        else
            refreshTuning()
            startESPLoop()
            scheduleRefresh()
        end
    end
})

for _, player in ipairs(Players:GetPlayers()) do
    watchPlayer(player)
end

Players.PlayerAdded:Connect(function(player)
    watchPlayer(player)
    if espEnabled then scheduleRefresh() end
end)

Players.PlayerRemoving:Connect(function(player)
    unwatchPlayer(player)
    removeHighlight(player)
end)

undeitedhub.DisableAll = undeitedhub.DisableAll or function() end
local oldDisable = undeitedhub.DisableAll
undeitedhub.DisableAll = function()
    espEnabled = false
    undeitedhub.Toggles.espEnabled = false
    ClearHighlights()
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    oldDisable()
end

if espEnabled then
    startESPLoop()
    scheduleRefresh()
end
