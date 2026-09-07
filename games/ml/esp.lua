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
local espNamesEnabled = undeitedhub.Toggles.espNamesEnabled or false
local highlightMap = {}
local nameMap = {}
local ESP_COLOR = Color3.fromRGB(255, 0, 0)

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

local function ClearESP()
    ClearHighlights()
    ClearNames()
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

    local localPlayer = game.Players.LocalPlayer
    local localChar = localPlayer and localPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local seen = {}

    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character.Parent then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                if espEnabled then
                    local highlight = highlightMap[player]
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "UndeitedSP"
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
                end

                if espNamesEnabled then
                    if not nameMap[player] then
                        CreateNameTag(player, player.Character)
                    end
                    local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
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
        end
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
                Title = "ESP Highlight",
                Content = espEnabled and "Enabled" or "Disabled",
                Duration = 2,
            })
            if not espEnabled then
                ClearHighlights()
            end
            RefreshESP()
        end)
    end
})

VisualTab:Toggle({
    Title = "ESP Names",
    Value = espNamesEnabled,
    Callback = function(state)
        pcall(function()
            espNamesEnabled = state
            undeitedhub.Toggles.espNamesEnabled = state
            if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
            SafeNotify({
                Title = "ESP Names",
                Content = espNamesEnabled and "Enabled" or "Disabled",
                Duration = 2,
            })
            if not espNamesEnabled then
                ClearNames()
            end
            RefreshESP()
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
    if highlightMap[player] then
        pcall(highlightMap[player].Destroy, highlightMap[player])
        highlightMap[player] = nil
    end
    if nameMap[player] then
        pcall(nameMap[player].Destroy, nameMap[player])
        nameMap[player] = nil
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(UpdateESP)
    end
end)

undeitedhub.DisableAll = undeitedhub.DisableAll or function() end
local oldDisable = undeitedhub.DisableAll
undeitedhub.DisableAll = function()
    espEnabled = false
    espNamesEnabled = false
    undeitedhub.Toggles.espEnabled = false
    undeitedhub.Toggles.espNamesEnabled = false
    ClearESP()
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    oldDisable()
end