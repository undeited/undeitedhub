local WindUI = undeitedhub.WindUI
local utils = undeitedhub.Utils

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

local MiscTab = undeitedhub.Window:Tab({
    Title = "Misc"
})

local function SendChatMessage(message)
    local success, result = pcall(function()
        local TextChatService = game:GetService("TextChatService")
        local generalChatChannel = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")
        generalChatChannel:SendAsync(message)
        return true
    end)
    if not success then
        SafeNotify({ Title = "Error", Content = "Failed to send chat message", Duration = 2 })
    end
end

MiscTab:Button({
    Title = "Expose Murderer",
    Callback = function()
        local murderer = undeitedhub.GetCurrentMurderer()
        if murderer then
            SendChatMessage("Murderer is " .. murderer.Name)
            SafeNotify({ Title = "Expose", Content = "Murderer exposed in chat", Duration = 2 })
        else
            SafeNotify({ Title = "Expose", Content = "No murderer found", Duration = 2 })
        end
    end
})

MiscTab:Button({
    Title = "Expose Sheriff",
    Callback = function()
        local sheriff = undeitedhub.GetCurrentSheriff()
        if sheriff then
            SendChatMessage("Sheriff is " .. sheriff.Name)
            SafeNotify({ Title = "Expose", Content = "Sheriff exposed in chat", Duration = 2 })
        else
            SafeNotify({ Title = "Expose", Content = "No sheriff found", Duration = 2 })
        end
    end
})

local function TeleportToPlayer(target)
    if not target then
        SafeNotify({ Title = "Error", Content = "Target not found", Duration = 2 })
        return
    end
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then
        SafeNotify({ Title = "Error", Content = "Local player not found", Duration = 2 })
        return
    end
    local targetCharacter = target.Character
    if not targetCharacter then
        SafeNotify({ Title = "Error", Content = "Target has no character", Duration = 2 })
        return
    end
    local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
    if not targetRoot then
        SafeNotify({ Title = "Error", Content = "Target has no HumanoidRootPart", Duration = 2 })
        return
    end
    local localCharacter = localPlayer.Character
    if not localCharacter then
        SafeNotify({ Title = "Error", Content = "Your character not found", Duration = 2 })
        return
    end
    local localRoot = localCharacter:FindFirstChild("HumanoidRootPart")
    if not localRoot then
        SafeNotify({ Title = "Error", Content = "Your HumanoidRootPart not found", Duration = 2 })
        return
    end
    localRoot.CFrame = targetRoot.CFrame
    SafeNotify({ Title = "Misc", Content = "Teleported to " .. target.Name, Duration = 2 })
end

MiscTab:Button({
    Title = "Teleport to Murderer",
    Callback = function()
        TeleportToPlayer(undeitedhub.GetCurrentMurderer())
    end
})

MiscTab:Button({
    Title = "Teleport to Sheriff",
    Callback = function()
        TeleportToPlayer(undeitedhub.GetCurrentSheriff())
    end
})

MiscTab:Button({
    Title = "Server Hop",
    Callback = function()
        local placeId = game.PlaceId
        if not placeId then
            SafeNotify({ Title = "Error", Content = "Could not get PlaceId", Duration = 2 })
            return
        end

        local HttpService = game:GetService("HttpService")
        local TeleportService = game:GetService("TeleportService")
        local currentJobId = game.JobId

        local candidates = {}
        local cursor = ""
        local maxPages = 10
        local pageCount = 0
        local minPlayers = 6

        local function fetchPage(cursor)
            local url = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
                placeId,
                cursor
            )
            local success, result = pcall(function()
                return game:HttpGet(url)
            end)
            if not success then
                return nil, result
            end
            local decoded
            local ok, err = pcall(function()
                decoded = HttpService:JSONDecode(result)
            end)
            if not ok or not decoded or not decoded.data then
                return nil, result
            end
            return decoded, nil
        end

        while pageCount < maxPages do
            local data, err = fetchPage(cursor)
            if not data then
                break
            end
            for _, server in ipairs(data.data) do
                if server.id ~= currentJobId and server.playing < server.maxPlayers then
                    table.insert(candidates, {
                        id = server.id,
                        playing = server.playing,
                        maxPlayers = server.maxPlayers
                    })
                end
            end
            cursor = data.nextPageCursor or ""
            if cursor == "" then break end
            pageCount = pageCount + 1
            task.wait(0.1)
        end

        if #candidates == 0 then
            SafeNotify({ Title = "Server Hop", Content = "No available servers found", Duration = 2 })
            return
        end

        table.sort(candidates, function(a, b)
            return a.playing > b.playing
        end)

        local targetServers = {}
        local fallbackServers = {}

        for _, server in ipairs(candidates) do
            if server.playing >= minPlayers then
                table.insert(targetServers, server.id)
            else
                table.insert(fallbackServers, server.id)
            end
        end

        if #targetServers == 0 then
            SafeNotify({ Title = "Server Hop", Content = "No servers with " .. minPlayers .. "+ players, trying any...", Duration = 2 })
            targetServers = fallbackServers
            if #targetServers == 0 then
                SafeNotify({ Title = "Server Hop", Content = "No suitable servers found", Duration = 2 })
                return
            end
        end

        local maxAttempts = #targetServers
        local attempts = 0

        while attempts < maxAttempts do
            attempts = attempts + 1
            local targetServer = targetServers[attempts]
            local success, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, targetServer, game.Players.LocalPlayer)
            end)
            if success then
                SafeNotify({ Title = "Server Hop", Content = "Teleporting to new server...", Duration = 2 })
                return
            else
                local errStr = tostring(err)
                if errStr:find("772") or string.lower(errStr):find("full") then
                    SafeNotify({ Title = "Server Hop", Content = "Server full, trying another... (" .. attempts .. "/" .. maxAttempts .. ")", Duration = 2 })
                    task.wait(0.5)
                else
                    SafeNotify({ Title = "Error", Content = "Failed to teleport: " .. errStr, Duration = 3 })
                    return
                end
            end
        end

        SafeNotify({ Title = "Server Hop", Content = "All attempts failed. Trying fallback teleport...", Duration = 2 })
        local success, err = pcall(function()
            TeleportService:Teleport(placeId)
        end)
        if success then
            SafeNotify({ Title = "Server Hop", Content = "Teleporting via fallback...", Duration = 2 })
        else
            SafeNotify({ Title = "Error", Content = "Fallback failed: " .. tostring(err), Duration = 3 })
        end
    end
})

MiscTab:Button({
    Title = "Rejoin Server",
    Callback = function()
        local placeId = game.PlaceId
        local jobId = game.JobId
        if not placeId or not jobId then
            SafeNotify({ Title = "Error", Content = "Could not get PlaceId or JobId", Duration = 2 })
            return
        end
        local TeleportService = game:GetService("TeleportService")
        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, jobId, game.Players.LocalPlayer)
        end)
        if success then
            SafeNotify({ Title = "Rejoin", Content = "Rejoining server...", Duration = 2 })
        else
            SafeNotify({ Title = "Error", Content = "Failed to rejoin: " .. tostring(err), Duration = 3 })
        end
    end
})

local antiFlingEnabled = undeitedhub.Toggles.antiFlingEnabled or false
local antiFlingHeartbeat = nil

local lastSafePosition = nil
local positionHistory = {}
local flingDetected = false
local recoveryMode = false
local recoveryStartTime = 0
local flingStartTime = 0
local lastNotificationTime = 0

local function CleanBodyMovers(character)
    if not character then return end
    for _, child in ipairs(character:GetDescendants()) do
        if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") or 
           child:IsA("BodyForce") or child:IsA("BodyGyro") or 
           child:IsA("BodyPosition") or child:IsA("BodyThrust") then
            child:Destroy()
        end
    end
end

local function CleanWeldsAndConstraints(character)
    if not character then return end
    for _, child in ipairs(character:GetDescendants()) do
        if child:IsA("Weld") or child:IsA("WeldConstraint") or 
           child:IsA("Motor6D") or child:IsA("Snap") or child:IsA("RopeConstraint") then
            local part0 = child.Part0
            local part1 = child.Part1
            local shouldRemove = false
            if part0 and not part0:IsDescendantOf(character) then shouldRemove = true end
            if part1 and not part1:IsDescendantOf(character) then shouldRemove = true end
            if shouldRemove then
                child:Destroy()
            end
        end
    end
end

local function FreezeCharacter(humanoid, freeze)
    if not humanoid then return end
    humanoid.PlatformStand = freeze
    if freeze then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    else
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
    end
end

local function StrongAntiFling()
    if not antiFlingEnabled or not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end
    if _G.UNDEITEDHUB_AUTOFARM_MOVING then return end

    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return end

    local character = localPlayer.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local currentPos = root.Position
    local currentVel = root.Velocity
    local speed = currentVel.Magnitude

    local state = humanoid:GetState()
    local isJumpingOrFalling = (state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall)

    if isJumpingOrFalling then
        local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)
        local vertVel = math.abs(currentVel.Y)
        if horizontalVel.Magnitude < 30 and vertVel > 10 then
            lastSafePosition = currentPos
            positionHistory = {}
            flingDetected = false
            recoveryMode = false
            return
        end
    end

    table.insert(positionHistory, currentPos)
    if #positionHistory > 5 then table.remove(positionHistory, 1) end

    local isStable = speed < 50 and not recoveryMode

    if isStable and not flingDetected then
        lastSafePosition = currentPos
        CleanBodyMovers(character)
        CleanWeldsAndConstraints(character)
        FreezeCharacter(humanoid, false)
        return
    end

    local velocityThreshold = 100
    local displacementThreshold = 15
    local flingTriggered = false

    if speed > velocityThreshold then
        flingTriggered = true
    elseif lastSafePosition and (currentPos - lastSafePosition).Magnitude > displacementThreshold then
        flingTriggered = true
    else
        if #positionHistory >= 3 then
            local avgSpeed = 0
            for i = 2, #positionHistory do
                avgSpeed = avgSpeed + (positionHistory[i] - positionHistory[i-1]).Magnitude
            end
            avgSpeed = avgSpeed / (#positionHistory - 1)
            if avgSpeed > 25 then
                flingTriggered = true
            end
        end
    end

    if flingTriggered then
        if not flingDetected then
            flingDetected = true
            flingStartTime = tick()
            recoveryMode = true
            recoveryStartTime = tick()
            if tick() - lastNotificationTime > 2 then
                lastNotificationTime = tick()
                WindUI:Notify({ Title = "Anti Fling", Content = "Fling detected! Freezing and neutralizing.", Duration = 2 })
            end
        end

        FreezeCharacter(humanoid, true)

        root.Velocity = Vector3.new(0, 0, 0)
        root.RotVelocity = Vector3.new(0, 0, 0)
        if lastSafePosition then
            root.CFrame = CFrame.new(lastSafePosition + Vector3.new(0, 0.5, 0))
        end
        CleanBodyMovers(character)
        CleanWeldsAndConstraints(character)
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part ~= root then
                part.Velocity = Vector3.new(0, 0, 0)
                part.RotVelocity = Vector3.new(0, 0, 0)
            end
        end
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)

        return
    end

    if flingDetected and speed < 50 and (lastSafePosition and (currentPos - lastSafePosition).Magnitude < 5) then
        flingDetected = false
        recoveryMode = false
        lastSafePosition = currentPos
        positionHistory = {}
        FreezeCharacter(humanoid, false)
        if tick() - lastNotificationTime > 2 then
            lastNotificationTime = tick()
            WindUI:Notify({ Title = "Anti Fling", Content = "Recovered from fling.", Duration = 2 })
        end
        return
    end

    if recoveryMode and tick() - recoveryStartTime > 2 then
        if lastSafePosition then
            root.CFrame = CFrame.new(lastSafePosition + Vector3.new(0, 0.5, 0))
            root.Velocity = Vector3.new(0, 0, 0)
            root.RotVelocity = Vector3.new(0, 0, 0)
            CleanBodyMovers(character)
            CleanWeldsAndConstraints(character)
            recoveryMode = false
            flingDetected = false
            positionHistory = {}
            FreezeCharacter(humanoid, false)
            if tick() - lastNotificationTime > 2 then
                lastNotificationTime = tick()
                WindUI:Notify({ Title = "Anti Fling", Content = "Forced recovery from fling.", Duration = 2 })
            end
        end
    end
end

local function SetupAntiFling()
    if antiFlingHeartbeat then
        antiFlingHeartbeat:Disconnect()
        antiFlingHeartbeat = nil
    end
    if antiFlingEnabled then
        flingDetected = false
        recoveryMode = false
        lastSafePosition = nil
        positionHistory = {}
        lastNotificationTime = 0
        antiFlingHeartbeat = game:GetService("RunService").Heartbeat:Connect(StrongAntiFling)
    end
end

MiscTab:Toggle({
    Title = "Anti Fling",
    Value = antiFlingEnabled,
    Callback = function(state)
        antiFlingEnabled = state
        undeitedhub.Toggles.antiFlingEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        WindUI:Notify({
            Title = "Anti Fling",
            Content = antiFlingEnabled and "Enabled" or "Disabled",
            Duration = 2,
        })
        SetupAntiFling()
    end
})

SetupAntiFling()

local noclipEnabled = undeitedhub.Toggles.noclipEnabled or false
local noclipLoopTask = nil

local function KeepOnFloor(character)
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local origin = root.Position
    local direction = Vector3.new(0, -50, 0)
    local result = workspace:Raycast(origin, direction, raycastParams)

    if result then
        local floorY = result.Position.Y
        local currentY = root.Position.Y
        local offset = 1.5
        if currentY < floorY + offset then
            local newPos = Vector3.new(root.Position.X, floorY + offset, root.Position.Z)
            root.CFrame = CFrame.new(newPos)
            root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
        end
    else
    end
end

local function SetNoclipCollision(state)
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

local function StartNoclipLoop()
    if noclipLoopTask then return end
    noclipLoopTask = task.spawn(function()
        while noclipEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local localPlayer = game.Players.LocalPlayer
                local character = localPlayer and localPlayer.Character
                if character then
                    for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            pcall(function()
                                part.CanCollide = false
                            end)
                        end
                    end
                    pcall(KeepOnFloor, character)
                end
            end
            task.wait(0.08)
        end
        noclipLoopTask = nil
    end)
end

local function StopNoclipLoop()
    if noclipLoopTask then
        task.cancel(noclipLoopTask)
        noclipLoopTask = nil
    end
    local localPlayer = game.Players.LocalPlayer
    local character = localPlayer and localPlayer.Character
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.CanCollide = true
                end)
            end
        end
    end
end

local function ToggleNoclip(state)
    noclipEnabled = state
    undeitedhub.Toggles.noclipEnabled = state
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    if state then
        StartNoclipLoop()
        WindUI:Notify({ Title = "Noclip", Content = "Enabled", Duration = 2 })
    else
        StopNoclipLoop()
        WindUI:Notify({ Title = "Noclip", Content = "Disabled", Duration = 2 })
    end
end

MiscTab:Toggle({
    Title = "Noclip",
    Value = noclipEnabled,
    Callback = function(state)
        ToggleNoclip(state)
    end
})

undeitedhub.DisableAll = function()
    antiFlingEnabled = false
    undeitedhub.Toggles.antiFlingEnabled = false
    if antiFlingHeartbeat then
        antiFlingHeartbeat:Disconnect()
        antiFlingHeartbeat = nil
    end
    flingDetected = false
    recoveryMode = false
    lastSafePosition = nil
    positionHistory = {}
    local localPlayer = game.Players.LocalPlayer
    if localPlayer and localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
    end

    if noclipEnabled then
        StopNoclipLoop()
        noclipEnabled = false
        undeitedhub.Toggles.noclipEnabled = false
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end
