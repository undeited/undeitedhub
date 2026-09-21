local WindUI = undeitedhub.WindUI

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
local highlightMap = {}
local ESP_COLOR = Color3.fromRGB(255, 0, 0)

local espLoopTask = nil

local function ClearHighlights()
    for _, highlight in pairs(highlightMap) do
        if highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
        end
    end
    highlightMap = {}
end

local function UpdateESP()
    if not espEnabled then
        ClearHighlights()
        return
    end

    local localPlayer = game.Players.LocalPlayer
    local seen = {}

    for _, player in ipairs(game.Players:GetPlayers()) do
        if player == localPlayer then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local highlight = highlightMap[player]
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "UndeitedSP"
            highlight.FillColor = ESP_COLOR
            highlight.FillTransparency = 0.5
            highlight.OutlineColor = ESP_COLOR
            highlight.OutlineTransparency = 0.2
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = character
            highlightMap[player] = highlight
        end
        highlight.Adornee = character
        highlight.Enabled = true

        seen[player] = true
    end

    for player, highlight in pairs(highlightMap) do
        if not seen[player] and highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
            highlightMap[player] = nil
        end
    end
end

local function startESPLoop()
    if espLoopTask then return end
    espLoopTask = task.spawn(function()
        while espEnabled do
            pcall(UpdateESP)
            task.wait(0.5)
        end
        espLoopTask = nil
    end)
end

VisualTab:Toggle({
    Title = "Player Highlight",
    Value = espEnabled,
    Callback = function(state)
        espEnabled = state
        undeitedhub.Toggles.espEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Player Highlight", Content = state and "Enabled" or "Disabled", Duration = 2 })
        if state then
            startESPLoop()
            pcall(UpdateESP)
        else
            ClearHighlights()
        end
    end
})

local function ConnectPlayer(player)
    if not player then return end
    player.CharacterAdded:Connect(function()
        if espEnabled then
            task.wait(0.2)
            pcall(UpdateESP)
        end
    end)
    player.CharacterRemoving:Connect(function()
        if espEnabled then
            pcall(UpdateESP)
        end
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
    task.spawn(function()
        task.wait(0.5)
        startESPLoop()
        pcall(UpdateESP)
    end)
end
