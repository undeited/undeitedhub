local WindUI = undeitedhub.WindUI
local AutofarmTab = undeitedhub.Window:Tab({ Title = "Autofarm" })
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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

local function IsInLobby()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return false end
    local character = localPlayer.Character
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
    return (rootPart.Position - lobbyPos).Magnitude < 50
end

local function IsPlayerInLobby(player)
    if not player then return false end
    local char = player.Character
    if not char then return false end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
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
    return (rootPart.Position - lobbyPos).Magnitude < 50
end

local function IsRoundActive()
    local roundTimer = workspace:FindFirstChild("RoundTimerPart")
    if roundTimer then
        local time = roundTimer:GetAttribute("Time")
        if time ~= nil and time > 0 then
            return true
        end
    end
    if IsInLobby() then
        return false
    end
    local localPlayer = game.Players.LocalPlayer
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= localPlayer then
            if not IsPlayerInLobby(player) then
                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function IsPlayerAlive()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return false end
    local character = localPlayer.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    return humanoid.Health > 0
end

local function IsLocalPlayerMurderer()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return false end
    local char = localPlayer.Character
    if char and char:FindFirstChild("Knife") then
        return true
    end
    local backpack = localPlayer:FindFirstChild("Backpack")
    if backpack and backpack:FindFirstChild("Knife") then
        return true
    end
    return false
end

local function GetCoinCount()
    local ok, result = pcall(function()
        local player = game.Players.LocalPlayer
        if not player then return 0 end
        local gui = player:FindFirstChild("PlayerGui")
        if not gui then return 0 end
        local main = gui:FindFirstChild("MainGUI")
        if not main then return 0 end
        local gameFrame = main:FindFirstChild("Game")
        if not gameFrame then return 0 end
        local coinBags = gameFrame:FindFirstChild("CoinBags")
        if not coinBags then return 0 end
        local containerScript = coinBags:FindFirstChild("CoinBagContainerScript")
        if not containerScript then return 0 end
        local container = containerScript:FindFirstChild("Container")
        if not container then return 0 end

        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Frame") and child.Visible then
                local currencyFrame = child:FindFirstChild("CurrencyFrame")
                if currencyFrame then
                    local icon = currencyFrame:FindFirstChild("Icon")
                    if icon then
                        local coinsText = icon:FindFirstChild("Coins")
                        if coinsText and coinsText:IsA("TextLabel") then
                            local num = tonumber(coinsText.Text)
                            if num then return num end
                        end
                    end
                end
            end
        end
        return 0
    end)

    if ok then
        return result or 0
    end
    return 0
end

local function GetCurrentMap()
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("CoinContainer") then
            return child
        end
    end
    return nil
end

local function GetAllActiveCoinServers()
    local coins = {}
    local map = GetCurrentMap()
    if map then
        local coinContainer = map:FindFirstChild("CoinContainer") or map:FindFirstChild("CoinContainerServer")
        if coinContainer then
            for _, child in ipairs(coinContainer:GetChildren()) do
                if (child.Name:lower():find("coin") or child.Name:match("Coin_Server")) and child:FindFirstChild("TouchInterest") then
                    table.insert(coins, child)
                end
            end
        end
    end

    if #coins == 0 then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj:FindFirstChild("TouchInterest") then
                local pName = obj.Name:lower()
                if pName:find("coin") or pName:find("coin_server") or pName:find("coinbag") then
                    table.insert(coins, obj)
                end
            elseif obj:IsA("Model") and obj:FindFirstChild("TouchInterest") then
                local ok = false
                for _, d in ipairs(obj:GetDescendants()) do
                    if d:IsA("BasePart") then ok = true; break end
                end
                if ok then table.insert(coins, obj) end
            end
        end
    end

    return coins
end

local function GetCoinPosition(coin)
    if not coin then return nil end
    if coin:IsA("BasePart") then
        return coin.Position
    end
    if coin.PrimaryPart then
        return coin.PrimaryPart.Position
    end
    for _, part in ipairs(coin:GetDescendants()) do
        if part:IsA("BasePart") then
            return part.Position
        end
    end
    return nil
end

local function GetNearestCoin(coins, position)
    local nearest = nil
    local nearestDist = math.huge
    for _, coin in ipairs(coins) do
        local pos = GetCoinPosition(coin)
        if pos then
            local dist = (pos - position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = coin
            end
        end
    end
    return nearest
end

local function SetNoclip(state)
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return end
    local character = localPlayer.Character
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.CanCollide = not state
            end)
        end
    end
end

local function TeleportToLobby()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return false end
    local char = localPlayer.Character
    if not char then return false end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local lobby = workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("RegularLobby")
    if not lobby then return false end

    local spawns = lobby:FindFirstChild("Spawns")
    if not spawns then return false end

    local spawnPoints = {}
    for _, child in ipairs(spawns:GetChildren()) do
        if child:IsA("BasePart") then
            table.insert(spawnPoints, child)
        end
    end

    if #spawnPoints == 0 then return false end

    local spawn = spawnPoints[math.random(1, #spawnPoints)]
    rootPart.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 2, 0))
    return true
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local Gameplay = Remotes and Remotes:FindFirstChild("Gameplay")
local CoinCollected = Gameplay and Gameplay:FindFirstChild("CoinCollected")
local CoinsStarted = Gameplay and Gameplay:FindFirstChild("CoinsStarted")

local bagFull = false
local bagCapacity = 40
local currentBagCount = 0
local refreshNeeded = true
local coinCollectedConnection = nil
local coinsStartedConnection = nil
local waitingForRoundStart = true
local killAfterFullEnabled = undeitedhub.Toggles.killAfterFullEnabled or false
local killAfterFullCooldown = false
local autoTeleportToLobbyEnabled = undeitedhub.Toggles.autoTeleportToLobbyEnabled or false
local lastTeleportTime = 0
local TELEPORT_COOLDOWN = 5

local function GetAutofarmSettings()
    local mode = undeitedhub.Toggles.autofarmPickupMode or "Tween"
    local speed = undeitedhub.Toggles.autofarmSpeed or 16
    return mode, speed
end

_G.UNDEITEDHUB_AUTOFARM_MOVING = false

local function onCoinCollected(bagName, newCount, maxCount, data)
    currentBagCount = newCount
    bagCapacity = maxCount
    if newCount >= maxCount then
        bagFull = true
        if collectRunning then
            SafeNotify({ Title = "Autofarm", Content = "Bag full! Pausing...", Duration = 2 })
        end

        if autoTeleportToLobbyEnabled and not IsInLobby() then
            local now = tick()
            if now - lastTeleportTime >= TELEPORT_COOLDOWN then
                lastTeleportTime = now
                local success = TeleportToLobby()
                if success then
                    SafeNotify({ Title = "Autofarm", Content = "Teleported to lobby", Duration = 2 })
                else
                    SafeNotify({ Title = "Autofarm", Content = "Failed to teleport to lobby", Duration = 2 })
                end
            end
        end

        if killAfterFullEnabled and not killAfterFullCooldown then
            killAfterFullCooldown = true
            task.spawn(function()
                if IsLocalPlayerMurderer() then
                    pcall(function()
                        if undeitedhub.KillAll then
                            undeitedhub.KillAll()
                        end
                    end)
                    task.wait(1)
                    bagFull = false
                    refreshNeeded = true
                    killAfterFullCooldown = false
                    if collectRunning then
                        SafeNotify({ Title = "Autofarm", Content = "Bag reset after kill all", Duration = 2 })
                    end
                else
                    bagFull = false
                    refreshNeeded = true
                    killAfterFullCooldown = false
                    if collectRunning then
                        SafeNotify({ Title = "Autofarm", Content = "Bag full but not murderer, continuing", Duration = 2 })
                    end
                end
            end)
        end
    else
        bagFull = false
    end
    refreshNeeded = true
end

local function onCoinsStarted(playerData)
    bagFull = false
    refreshNeeded = true
    currentBagCount = 0
    waitingForRoundStart = false
    killAfterFullCooldown = false
    if currentTween then
        pcall(currentTween.Cancel, currentTween)
        currentTween = nil
    end
    currentTarget = nil
end

local autoCollectEnabled = undeitedhub.Toggles.autoCollectEnabled or false
local collectTask = nil
local collectRunning = false
local currentTween = nil
local currentTarget = nil
local monitorConnection = nil
local healthChangedConnection = nil
local characterRemovingConnection = nil
local characterAddedConnection = nil

local function MonitorCoin()
    if not currentTarget then return end
    if not currentTarget:FindFirstChild("TouchInterest") then
        if currentTween then
            pcall(currentTween.Cancel, currentTween)
            currentTween = nil
        end
        currentTarget = nil
        refreshNeeded = true
    end

    local onMap = GetCurrentMap() ~= nil
    if (not onMap) or IsInLobby() or not IsRoundActive() or not IsPlayerAlive() then
        if currentTween then
            pcall(currentTween.Cancel, currentTween)
            currentTween = nil
        end
        currentTarget = nil
    end
end

local function StartMonitoring()
    if monitorConnection then return end
    monitorConnection = RunService.Heartbeat:Connect(function()
        if collectRunning and _G.UNDEITEDHUB_WINDOW_VISIBLE then
            pcall(MonitorCoin)
        end
    end)
end

local function StopMonitoring()
    if monitorConnection then
        monitorConnection:Disconnect()
        monitorConnection = nil
    end
end

local function CollectCoins()
    if GetCurrentMap() == nil or IsInLobby() or not IsRoundActive() or not IsPlayerAlive() or waitingForRoundStart then
        return
    end

    local coinCount = GetCoinCount()
    if coinCount >= 40 then
        bagFull = true
    end

    if bagFull then
        task.wait(0.5)
        return
    end

    local coinServers = GetAllActiveCoinServers()
    if refreshNeeded then
        coinServers = GetAllActiveCoinServers()
        refreshNeeded = false
    end

    if #coinServers == 0 then
        task.wait(0.5)
        return
    end

    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return end
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local nearestCoin = GetNearestCoin(coinServers, root.Position)
    if not nearestCoin then return end

    local targetCoin = nearestCoin

    if currentTarget == targetCoin and targetCoin:FindFirstChild("TouchInterest") then
        return
    end
    if currentTween then
        pcall(currentTween.Cancel, currentTween)
        currentTween = nil
    end

    if not targetCoin:FindFirstChild("TouchInterest") and not targetCoin:IsA("Part") then
        return
    end

    currentTarget = targetCoin

    local coinPos = GetCoinPosition(targetCoin)
    if not coinPos then
        currentTarget = nil
        return
    end

    local offset = Vector3.new(0, 0.5, 0)
    local targetPos = coinPos + offset

    local dist = (targetPos - root.Position).Magnitude
    local _, configuredSpeed = GetAutofarmSettings()
    local speed = configuredSpeed or 16
    local duration = math.max(0.3, dist / speed)
    duration = duration * (0.9 + math.random() * 0.2)

    local originalRotation = root.CFrame - root.Position
    local targetCFrame = CFrame.new(targetPos) * originalRotation

    humanoid.PlatformStand = true
    humanoid.Sit = true
    humanoid.AutoRotate = false
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

    root.Velocity = Vector3.new(0, 0, 0)
    root.RotVelocity = Vector3.new(0, 0, 0)

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Velocity = Vector3.new(0, 0, 0)
                part.RotVelocity = Vector3.new(0, 0, 0)
                part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end)
        end
    end

    local camera = workspace.CurrentCamera
    local originalSubject = camera and camera.CameraSubject
    if camera then
        camera.CameraSubject = nil
    end

    _G.UNDEITEDHUB_AUTOFARM_MOVING = true

    local tweenInfo = TweenInfo.new(
        duration,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.InOut
    )

    local success, err = pcall(function()
        currentTween = TweenService:Create(root, tweenInfo, { CFrame = targetCFrame })
        currentTween:Play()

        while currentTween and currentTween.PlaybackState ~= Enum.PlaybackState.Completed do
            if not collectRunning or IsInLobby() or not IsRoundActive() or not IsPlayerAlive() or waitingForRoundStart or not _G.UNDEITEDHUB_WINDOW_VISIBLE then
                currentTween:Cancel()
                break
            end
            task.wait(0.05)
        end
    end)

    _G.UNDEITEDHUB_AUTOFARM_MOVING = false

    if camera and originalSubject then
        camera.CameraSubject = originalSubject
    end

    if not success then
        pcall(function()
            root.CFrame = targetCFrame
        end)
        _G.UNDEITEDHUB_AUTOFARM_MOVING = false
    end

    humanoid.PlatformStand = false
    humanoid.Sit = false
    humanoid.AutoRotate = true
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.Velocity = Vector3.new(0, 0, 0)
                part.RotVelocity = Vector3.new(0, 0, 0)
                part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end)
        end
    end

    currentTween = nil
    currentTarget = nil

    local newCount = GetCoinCount()
    if newCount >= 40 then
        bagFull = true
    end

    task.wait(0.15 + math.random() * 0.15)
end

local function StartAutoCollect()
    if collectRunning then return end

    collectRunning = true
    autoCollectEnabled = true
    undeitedhub.Toggles.autoCollectEnabled = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    waitingForRoundStart = true

    SetNoclip(true)

    local localPlayer = game.Players.LocalPlayer
    if localPlayer and localPlayer.Character then
        local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        end
    end

    bagFull = false
    refreshNeeded = true
    currentBagCount = 0
    killAfterFullCooldown = false

    local initialCoinCount = GetCoinCount()
    if initialCoinCount >= 40 then
        bagFull = true
        SafeNotify({ Title = "Autofarm", Content = "Bag already full, pausing collection", Duration = 2 })
    end

    if CoinCollected and CoinCollected:IsA("RemoteEvent") then
        if coinCollectedConnection then coinCollectedConnection:Disconnect() end
        coinCollectedConnection = CoinCollected.OnClientEvent:Connect(onCoinCollected)
    else
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local rem = rs:FindFirstChild("Remotes") or rs:FindFirstChild("RemoteEvents")
            if rem then
                local cc = rem:FindFirstChild("CoinCollected")
                if cc and cc:IsA("RemoteEvent") then
                    CoinCollected = cc
                    if coinCollectedConnection then coinCollectedConnection:Disconnect() end
                    coinCollectedConnection = CoinCollected.OnClientEvent:Connect(onCoinCollected)
                end
            end
        end)
    end

    if CoinsStarted and CoinsStarted:IsA("RemoteEvent") then
        if coinsStartedConnection then coinsStartedConnection:Disconnect() end
        coinsStartedConnection = CoinsStarted.OnClientEvent:Connect(onCoinsStarted)
    else
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local rem = rs:FindFirstChild("Remotes") or rs:FindFirstChild("RemoteEvents")
            if rem then
                local cs = rem:FindFirstChild("CoinsStarted")
                if cs and cs:IsA("RemoteEvent") then
                    CoinsStarted = cs
                    if coinsStartedConnection then coinsStartedConnection:Disconnect() end
                    coinsStartedConnection = CoinsStarted.OnClientEvent:Connect(onCoinsStarted)
                end
            end
        end)
    end

    local function cancelTweenAndTarget()
        if currentTween then
            pcall(currentTween.Cancel, currentTween)
            currentTween = nil
        end
        currentTarget = nil
        _G.UNDEITEDHUB_AUTOFARM_MOVING = false
        local camera = workspace.CurrentCamera
        local char = localPlayer.Character
        if camera and char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                camera.CameraSubject = hum
            end
        end
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = false
                hum.Sit = false
                hum.AutoRotate = true
            end
        end
    end

    local function onCharacterAdded(newChar)
        bagFull = false
        refreshNeeded = true
        currentBagCount = 0
        killAfterFullCooldown = false
        cancelTweenAndTarget()

        local humanoid = newChar:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
        end

        if healthChangedConnection then healthChangedConnection:Disconnect() end
        if characterRemovingConnection then characterRemovingConnection:Disconnect() end

        if humanoid then
            healthChangedConnection = humanoid.HealthChanged:Connect(function(health)
                if health <= 0 then
                    cancelTweenAndTarget()
                end
            end)
        end

        characterRemovingConnection = newChar.AncestryChanged:Connect(function()
            if not newChar.Parent then
                cancelTweenAndTarget()
            end
        end)
    end

    if localPlayer and localPlayer.Character then
        onCharacterAdded(localPlayer.Character)
    end

    if characterAddedConnection then characterAddedConnection:Disconnect() end
    characterAddedConnection = localPlayer.CharacterAdded:Connect(onCharacterAdded)

    StartMonitoring()

    SafeNotify({ Title = "Autofarm", Content = "Enabled", Duration = 2 })

    collectTask = task.spawn(function()
        while collectRunning do
            while collectRunning and (IsInLobby() or not IsRoundActive() or not IsPlayerAlive() or waitingForRoundStart or not _G.UNDEITEDHUB_WINDOW_VISIBLE) do
                if collectRunning and not IsInLobby() and IsRoundActive() and IsPlayerAlive() and _G.UNDEITEDHUB_WINDOW_VISIBLE then
                    waitingForRoundStart = false
                end
                task.wait(0.5)
            end

            if not collectRunning then break end

            while collectRunning and not IsInLobby() and IsRoundActive() and IsPlayerAlive() and not waitingForRoundStart and _G.UNDEITEDHUB_WINDOW_VISIBLE do
                pcall(CollectCoins)
                if not currentTarget then
                    task.wait(0.2 + math.random() * 0.3)
                else
                    task.wait(0.1)
                end
            end
        end
    end)
end

local function StopAutoCollect()
    collectRunning = false
    autoCollectEnabled = false
    undeitedhub.Toggles.autoCollectEnabled = false

    if collectTask then
        task.cancel(collectTask)
        collectTask = nil
    end

    if currentTween then
        pcall(currentTween.Cancel, currentTween)
        currentTween = nil
    end
    currentTarget = nil
    _G.UNDEITEDHUB_AUTOFARM_MOVING = false

    local camera = workspace.CurrentCamera
    local localPlayer = game.Players.LocalPlayer
    if camera and localPlayer and localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            camera.CameraSubject = hum
        end
    end

    bagFull = false
    refreshNeeded = true
    currentBagCount = 0
    killAfterFullCooldown = false

    SetNoclip(false)

    if localPlayer and localPlayer.Character then
        local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
            humanoid.PlatformStand = false
            humanoid.Sit = false
            humanoid.AutoRotate = true
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
        for _, part in ipairs(localPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.Velocity = Vector3.new(0, 0, 0)
                    part.RotVelocity = Vector3.new(0, 0, 0)
                    part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end)
            end
        end
    end

    if coinCollectedConnection then
        coinCollectedConnection:Disconnect()
        coinCollectedConnection = nil
    end
    if coinsStartedConnection then
        coinsStartedConnection:Disconnect()
        coinsStartedConnection = nil
    end
    if healthChangedConnection then
        healthChangedConnection:Disconnect()
        healthChangedConnection = nil
    end
    if characterRemovingConnection then
        characterRemovingConnection:Disconnect()
        characterRemovingConnection = nil
    end
    if characterAddedConnection then
        characterAddedConnection:Disconnect()
        characterAddedConnection = nil
    end

    StopMonitoring()

    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Autofarm", Content = "Disabled", Duration = 2 })
end

AutofarmTab:Toggle({
    Title = "Auto Collect Coins",
    Value = autoCollectEnabled,
    Callback = function(state)
        if state then StartAutoCollect() else StopAutoCollect() end
    end
})

AutofarmTab:Toggle({
    Title = "Auto Kill All when Bag Full",
    Value = killAfterFullEnabled,
    Callback = function(state)
        killAfterFullEnabled = state
        undeitedhub.Toggles.killAfterFullEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({
            Title = "Auto Kill All when Bag Full",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

AutofarmTab:Toggle({
    Title = "Auto Teleport to Lobby when Bag Full",
    Value = autoTeleportToLobbyEnabled,
    Callback = function(state)
        autoTeleportToLobbyEnabled = state
        undeitedhub.Toggles.autoTeleportToLobbyEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({
            Title = "Auto Teleport to Lobby",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
        if state then
            lastTeleportTime = tick()
        end
    end
})

local disableKillBricksEnabled = undeitedhub.Toggles.disableKillBricksEnabled or false
local killBrickConnections = {}
local killBrickAddedConnection = nil

local function DisableKillBrick(part)
    if part:IsA("BasePart") and (part.Name == "KillBrick" or string.find(part.Name, "KillBrick")) then
        pcall(function()
            part.CanTouch = false
            part.CanCollide = false
        end)
    end
end

local function ScanAndDisableKillBricks()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name == "KillBrick" or string.find(obj.Name, "KillBrick")) then
            DisableKillBrick(obj)
        end
    end
end

local function SetupKillBrickDisable()
    for _, conn in ipairs(killBrickConnections) do
        conn:Disconnect()
    end
    killBrickConnections = {}
    if killBrickAddedConnection then
        killBrickAddedConnection:Disconnect()
        killBrickAddedConnection = nil
    end

    if not disableKillBricksEnabled then
        return
    end

    ScanAndDisableKillBricks()

    killBrickAddedConnection = workspace.DescendantAdded:Connect(function(obj)
        if disableKillBricksEnabled and obj:IsA("BasePart") and (obj.Name == "KillBrick" or string.find(obj.Name, "KillBrick")) then
            DisableKillBrick(obj)
        end
    end)
    table.insert(killBrickConnections, killBrickAddedConnection)

    local function onCharacterAdded(char)
        local function checkParts()
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and (part.Name == "KillBrick" or string.find(part.Name, "KillBrick")) then
                    DisableKillBrick(part)
                end
            end
        end
        checkParts()
        local partConn = char.DescendantAdded:Connect(function(obj)
            if disableKillBricksEnabled and obj:IsA("BasePart") and (obj.Name == "KillBrick" or string.find(obj.Name, "KillBrick")) then
                DisableKillBrick(obj)
            end
        end)
        table.insert(killBrickConnections, partConn)
    end

    for _, player in ipairs(game.Players:GetPlayers()) do
        if player.Character then
            onCharacterAdded(player.Character)
        end
        local addedConn = player.CharacterAdded:Connect(function(char)
            task.wait(0.1)
            onCharacterAdded(char)
        end)
        table.insert(killBrickConnections, addedConn)
    end
end

AutofarmTab:Toggle({
    Title = "Disable Kill Bricks",
    Value = disableKillBricksEnabled,
    Callback = function(state)
        disableKillBricksEnabled = state
        undeitedhub.Toggles.disableKillBricksEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({
            Title = "Disable Kill Bricks",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
        SetupKillBrickDisable()
        if state then
            ScanAndDisableKillBricks()
        end
    end
})

SetupKillBrickDisable()

local oldDisable = undeitedhub.DisableAll
undeitedhub.DisableAll = function()
    StopAutoCollect()
    killAfterFullEnabled = false
    undeitedhub.Toggles.killAfterFullEnabled = false
    autoTeleportToLobbyEnabled = false
    undeitedhub.Toggles.autoTeleportToLobbyEnabled = false
    disableKillBricksEnabled = false
    undeitedhub.Toggles.disableKillBricksEnabled = false
    for _, conn in ipairs(killBrickConnections) do
        conn:Disconnect()
    end
    killBrickConnections = {}
    if killBrickAddedConnection then
        killBrickAddedConnection:Disconnect()
        killBrickAddedConnection = nil
    end
    _G.UNDEITEDHUB_AUTOFARM_MOVING = false
    local camera = workspace.CurrentCamera
    local localPlayer = game.Players.LocalPlayer
    if camera and localPlayer and localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            camera.CameraSubject = hum
        end
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    if oldDisable then oldDisable() end
end
