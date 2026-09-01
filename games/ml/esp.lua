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

local function ClearESP()
    for _, highlight in pairs(highlightMap) do
        if highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
        end
    end
    highlightMap = {}
end

local function UpdateESP()
    if not espEnabled or not _G.UNDEITEDHUB_WINDOW_VISIBLE then
        ClearESP()
        return
    end

    local localPlayer = game.Players.LocalPlayer
    local seen = {}

    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character.Parent then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local highlight = highlightMap[player]
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "UndeltedESP"
                    highlight.FillColor = ESP_COLOR
                    highlight.FillTransparency = 0.5
                    highlight.OutlineColor = ESP_COLOR
                    highlight.OutlineTransparency = 0.2
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = player.Character
                    highlightMap[player] = highlight
                end
                highlight.Adornee = player.Character
                highlight.Enabled = true
                seen[player] = true
            end
        end
    end

    for player, highlight in pairs(highlightMap) do
        if not seen[player] and highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
            highlightMap[player] = nil
        end
    end
end

local function RefreshESP()
    pcall(UpdateESP)
end

VisualTab:Toggle({
    Title = "ESP Highlight",
    Value = espEnabled,
    Callback = function(state)
        pcall(function()
            espEnabled = state
            undeitedhub.Toggles.espEnabled = state
            if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
            SafeNotify({
                Title = "ESP",
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
    local highlight = highlightMap[player]
    if highlight and highlight.Parent then
        pcall(highlight.Destroy, highlight)
    end
    highlightMap[player] = nil
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(UpdateESP)
    end
end)

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    espEnabled = false
    undeitedhub.Toggles.espEnabled = false
    ClearESP()
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    oldDisable()
end