local WindUI = undeitedhub.WindUI
local Math = undeitedhub.Math
local CombatTab = undeitedhub.Window:Tab({ Title = "Combat" })
local config = undeitedhub.Config
local function SafeNotify(data)
    if type(data) ~= "table" then return end
    if WindUI and type(WindUI.Notify) == "function" then pcall(WindUI.Notify, WindUI, data)
    else pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = data.Title or "", Text = data.Content or "", Duration = data.Duration or 3 }) end) end
end
local roundTimer = workspace:FindFirstChild("RoundTimerPart")
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
    if lobby:IsA("BasePart") then lobbyPos = lobby.Position
    elseif lobby.PrimaryPart then lobbyPos = lobby.PrimaryPart.Position
    else for _, part in ipairs(lobby:GetDescendants()) do if part:IsA("BasePart") then lobbyPos = part.Position break end end end
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
    if lobby:IsA("BasePart") then lobbyPos = lobby.Position
    elseif lobby.PrimaryPart then lobbyPos = lobby.PrimaryPart.Position
    else for _, part in ipairs(lobby:GetDescendants()) do if part:IsA("BasePart") then lobbyPos = part.Position break end end end
    if not lobbyPos then return false end
    return (rootPart.Position - lobbyPos).Magnitude < 50
end
local function IsRoundActive()
    if roundTimer then
        local time = roundTimer:GetAttribute("Time")
        if time ~= nil and time > 0 then return true end
    end
    if IsInLobby() then return false end
    local localPlayer = game.Players.LocalPlayer
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= localPlayer then
            if not IsPlayerInLobby(player) then
                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then return true end
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
    if char and char:FindFirstChild("Knife") then return true end
    local backpack = localPlayer:FindFirstChild("Backpack")
    if backpack and backpack:FindFirstChild("Knife") then return true end
    return false
end
local function PlayerHasTool(player, toolName)
    if not player then return false end
    local backpack = player:FindFirstChild("Backpack")
    if backpack and backpack:FindFirstChild(toolName) then return true end
    local character = player.Character
    if character and character:FindFirstChild(toolName) then return true end
    return false
end
local function GetPlayerKnife()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return nil end
    local char = localPlayer.Character
    if char then
        local knife = char:FindFirstChild("Knife")
        if knife and knife:IsA("Tool") then return knife end
    end
    local backpack = localPlayer:FindFirstChild("Backpack")
    if backpack then
        local knife = backpack:FindFirstChild("Knife")
        if knife and knife:IsA("Tool") then return knife end
    end
    return nil
end
local function GetPlayerGun()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return nil end
    local char = localPlayer.Character
    if char then
        local gun = char:FindFirstChild("Gun")
        if gun and gun:IsA("Tool") then return gun end
    end
    local backpack = localPlayer:FindFirstChild("Backpack")
    if backpack then
        local gun = backpack:FindFirstChild("Gun")
        if gun and gun:IsA("Tool") then return gun end
    end
    return nil
end
local function EquipGun()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return false end
    local gun = GetPlayerGun()
    if not gun then return false end
    local char = localPlayer.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    if gun.Parent == char then return true end
    if gun.Parent == localPlayer:FindFirstChild("Backpack") then
        humanoid:EquipTool(gun)
        task.wait(0.1)
        return true
    end
    return false
end
local function KillAll()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return end
    if not IsRoundActive() or not IsPlayerAlive() or IsInLobby() then return end
    local knife = GetPlayerKnife()
    if not knife then return end
    local handleTouched = knife:FindFirstChild("Events") and knife.Events:FindFirstChild("HandleTouched")
    if not handleTouched or not handleTouched:IsA("RemoteEvent") then return end
    for _, player in pairs(game.Players:GetPlayers()) do
        if player == localPlayer then continue end
        if IsPlayerInLobby(player) then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            handleTouched:FireServer(rootPart)
            task.wait(0.1)
        end
    end
end
undeitedhub.KillAll = KillAll
CombatTab:Button({ Title = "Kill All", Callback = function()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then SafeNotify({ Title = "Error", Content = "Local player not found", Duration = 2 }) return end
    if not IsRoundActive() or not IsPlayerAlive() or IsInLobby() then SafeNotify({ Title = "Kill All", Content = "Not alive or round inactive", Duration = 2 }) return end
    local knife = GetPlayerKnife()
    if not knife then SafeNotify({ Title = "Error", Content = "You are not the murderer (no knife found)", Duration = 2 }) return end
    local handleTouched = knife:FindFirstChild("Events") and knife.Events:FindFirstChild("HandleTouched")
    if not handleTouched or not handleTouched:IsA("RemoteEvent") then SafeNotify({ Title = "Error", Content = "HandleTouched remote not found", Duration = 2 }) return end
    local killed = 0
    for _, player in pairs(game.Players:GetPlayers()) do
        if player == localPlayer then continue end
        if IsPlayerInLobby(player) then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            handleTouched:FireServer(rootPart)
            killed = killed + 1
            task.wait(0.1)
        end
    end
    if killed > 0 then SafeNotify({ Title = "Kill All", Content = "Killed " .. killed .. " alive players!", Duration = 2 })
    else SafeNotify({ Title = "Kill All", Content = "No alive players to kill", Duration = 2 }) end
end })
local autoKillAllEnabled = undeitedhub.Toggles.autoKillAllEnabled or false
local lastAutoKillAllTime = 0
game:GetService("RunService").Heartbeat:Connect(function()
    if autoKillAllEnabled and _G.UNDEITEDHUB_WINDOW_VISIBLE then
        local now = tick()
        if now - lastAutoKillAllTime >= 0.5 then
            lastAutoKillAllTime = now
            pcall(KillAll)
        end
    end
end)
CombatTab:Toggle({ Title = "Auto Kill All", Value = autoKillAllEnabled, Callback = function(state) autoKillAllEnabled = state; undeitedhub.Toggles.autoKillAllEnabled = state; if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end; SafeNotify({ Title = "Auto Kill All", Content = autoKillAllEnabled and "Enabled" or "Disabled", Duration = 2 }); if autoKillAllEnabled then lastAutoKillAllTime = tick() end end })
local autoShootEnabled = undeitedhub.Toggles.autoShootEnabled or false
local lastShootTime = 0
local SHOOT_COOLDOWN = config.cooldowns.autoShoot or 0.3
local BULLET_SPEED = 1200
local PREDICTION_MULTIPLIER = 1.5
local murdererHistory = {}
local kalmanStates = {}
local function GetMurdererVelocity(murderer)
    local history = murdererHistory[murderer]
    if not history then return Vector3.new(0,0,0) end
    if #history.positions < 2 then return Vector3.new(0,0,0) end
    local avgVel = Vector3.new(0,0,0)
    local count = 0
    for i = #history.positions, 2, -1 do
        local dt = history.times[i] - history.times[i-1]
        if dt > 0 and dt < 0.3 then
            local vel = (history.positions[i] - history.positions[i-1]) / dt
            if vel.Magnitude < 500 then
                avgVel = avgVel + vel
                count = count + 1
            end
        end
    end
    if count == 0 then return Vector3.new(0,0,0) end
    return avgVel / count
end
local function UpdateMurdererHistory(murderer, pos)
    local history = murdererHistory[murderer]
    if not history then
        history = {positions = {}, times = {}}
        murdererHistory[murderer] = history
    end
    table.insert(history.positions, pos)
    table.insert(history.times, tick())
    if #history.positions > 3 then
        table.remove(history.positions, 1)
        table.remove(history.times, 1)
    end
end
local function GetShootRemote()
    local gun = GetPlayerGun()
    if not gun then return nil end
    local shootRemote = gun:FindFirstChild("Shoot")
    if shootRemote and shootRemote:IsA("RemoteEvent") then return shootRemote end
    return nil
end
local function ShootMurdererOnce()
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return false end
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return false end
    if not IsRoundActive() or not IsPlayerAlive() or IsInLobby() then
        SafeNotify({ Title = "Shoot Murderer", Content = "Not alive or round inactive", Duration = 2 })
        return false
    end
    if not EquipGun() then
        SafeNotify({ Title = "Shoot Murderer", Content = "Could not equip gun. Ensure you have a gun.", Duration = 2 })
        return false
    end
    local gun = GetPlayerGun()
    if not gun then SafeNotify({ Title = "Shoot Murderer", Content = "You don't have a gun!", Duration = 2 }) return false end
    local shootRemote = GetShootRemote()
    if not shootRemote then SafeNotify({ Title = "Shoot Murderer", Content = "Shoot remote not found", Duration = 2 }) return false end
    local murderer = undeitedhub.GetCurrentMurderer()
    if not murderer then SafeNotify({ Title = "Shoot Murderer", Content = "No alive murderer found", Duration = 2 }) return false end
    local murdererChar = murderer.Character
    if not murdererChar then SafeNotify({ Title = "Shoot Murderer", Content = "Murderer has no character", Duration = 2 }) return false end
    local rootPart = murdererChar:FindFirstChild("HumanoidRootPart")
    if not rootPart then SafeNotify({ Title = "Shoot Murderer", Content = "Murderer has no HumanoidRootPart", Duration = 2 }) return false end
    local char = localPlayer.Character
    if not char then return false end
    local originAttachment = char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart:FindFirstChild("GunRaycastAttachment")
    local originCFrame
    if originAttachment then originCFrame = originAttachment.WorldCFrame
    else originCFrame = char.HumanoidRootPart.CFrame end
    local currentPos = rootPart.Position
    UpdateMurdererHistory(murderer, currentPos)
    local velocity = GetMurdererVelocity(murderer)
    -- Use Kalman filter for smoother prediction
    local state = kalmanStates[murderer]
    if not state then
        state = { pos = currentPos, vel = velocity, accel = Vector3.new(0,0,0) }
        kalmanStates[murderer] = state
    else
        local dt = 0.05 -- assumed constant
        local predictedPos, predictedVel = Math.kalmanPredict(state.pos, state.vel, state.accel, dt)
        state.pos = Math.lerp(state.pos, currentPos, 0.7)
        state.vel = Math.lerp(state.vel, velocity, 0.3)
        state.accel = (velocity - state.vel) / dt
    end
    local predictedPos = state.pos + state.vel * 0.2 -- lead time
    local distance = (currentPos - originCFrame.Position).Magnitude
    local travelTime = distance / BULLET_SPEED
    local predictionTime = travelTime * PREDICTION_MULTIPLIER
    predictionTime = math.min(predictionTime, 0.5)
    predictedPos = currentPos + velocity * predictionTime
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {localPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local origin = originCFrame.Position
    local direction = (predictedPos - origin).Unit * (distance + 5)
    local rayResult = workspace:Raycast(origin, direction, raycastParams)
    local visible = false
    local blockedByInnocent = false
    if rayResult then
        local hitPart = rayResult.Instance
        if hitPart:IsDescendantOf(murdererChar) then visible = true
        else
            local playerHit = game.Players:GetPlayerFromCharacter(hitPart.Parent)
            if playerHit and playerHit ~= localPlayer and playerHit ~= murderer then
                local role = undeitedhub.GetPlayerRole and undeitedhub.GetPlayerRole(playerHit)
                if role == "Innocent" or role == nil then blockedByInnocent = true end
            end
        end
    end
    if not visible then
        if blockedByInnocent then SafeNotify({ Title = "Shoot Murderer", Content = "Shot blocked by an innocent player", Duration = 2 })
        else SafeNotify({ Title = "Shoot Murderer", Content = "Murderer is behind a wall", Duration = 2 }) end
        return false
    end
    local targetCFrame = CFrame.new(predictedPos)
    pcall(function() shootRemote:FireServer(originCFrame, targetCFrame) end)
    SafeNotify({ Title = "Shoot Murderer", Content = "Shot fired at " .. murderer.Name, Duration = 2 })
    return true
end
local function ShootAtMurderer()
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return end
    if not IsRoundActive() or not IsPlayerAlive() or IsInLobby() then return end
    if not EquipGun() then return end
    local gun = GetPlayerGun()
    if not gun then return end
    local shootRemote = GetShootRemote()
    if not shootRemote then return end
    local murderer = undeitedhub.GetCurrentMurderer()
    if not murderer then return end
    local murdererChar = murderer.Character
    if not murdererChar then return end
    local rootPart = murdererChar:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local char = localPlayer.Character
    if not char then return end
    local originAttachment = char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart:FindFirstChild("GunRaycastAttachment")
    local originCFrame
    if originAttachment then originCFrame = originAttachment.WorldCFrame
    else originCFrame = char.HumanoidRootPart.CFrame end
    local currentPos = rootPart.Position
    UpdateMurdererHistory(murderer, currentPos)
    local velocity = GetMurdererVelocity(murderer)
    local state = kalmanStates[murderer]
    if not state then
        state = { pos = currentPos, vel = velocity, accel = Vector3.new(0,0,0) }
        kalmanStates[murderer] = state
    else
        local dt = 0.05
        local predictedPos, predictedVel = Math.kalmanPredict(state.pos, state.vel, state.accel, dt)
        state.pos = Math.lerp(state.pos, currentPos, 0.7)
        state.vel = Math.lerp(state.vel, velocity, 0.3)
        state.accel = (velocity - state.vel) / dt
    end
    local predictedPos = state.pos + state.vel * 0.2
    local distance = (currentPos - originCFrame.Position).Magnitude
    local travelTime = distance / BULLET_SPEED
    local predictionTime = travelTime * PREDICTION_MULTIPLIER
    predictionTime = math.min(predictionTime, 0.5)
    predictedPos = currentPos + velocity * predictionTime
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {localPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local origin = originCFrame.Position
    local direction = (predictedPos - origin).Unit * (distance + 5)
    local rayResult = workspace:Raycast(origin, direction, raycastParams)
    local visible = false
    local blockedByInnocent = false
    if rayResult then
        local hitPart = rayResult.Instance
        if hitPart:IsDescendantOf(murdererChar) then visible = true
        else
            local playerHit = game.Players:GetPlayerFromCharacter(hitPart.Parent)
            if playerHit and playerHit ~= localPlayer and playerHit ~= murderer then
                local role = undeitedhub.GetPlayerRole and undeitedhub.GetPlayerRole(playerHit)
                if role == "Innocent" or role == nil then blockedByInnocent = true end
            end
        end
    end
    if not visible then return end
    local targetCFrame = CFrame.new(predictedPos)
    pcall(function() shootRemote:FireServer(originCFrame, targetCFrame) end)
end
game:GetService("RunService").Heartbeat:Connect(function()
    if autoShootEnabled and _G.UNDEITEDHUB_WINDOW_VISIBLE then
        local now = tick()
        if now - lastShootTime >= SHOOT_COOLDOWN then
            lastShootTime = now
            pcall(ShootAtMurderer)
        end
    end
end)
CombatTab:Button({ Title = "Shoot Murderer", Callback = function() pcall(ShootMurdererOnce) end })
CombatTab:Toggle({ Title = "Auto Shoot Murderer", Value = autoShootEnabled, Callback = function(state) autoShootEnabled = state; undeitedhub.Toggles.autoShootEnabled = state; if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end; SafeNotify({ Title = "Auto Shoot Murderer", Content = autoShootEnabled and "Enabled" or "Disabled", Duration = 2 }); if autoShootEnabled then lastShootTime = tick(); murdererHistory = {}; kalmanStates = {} end end })
local function GetAllGunDrops()
    local gunDrops = {}
    for _, obj in ipairs(workspace:GetDescendants()) do if obj.Name == "GunDrop" then table.insert(gunDrops, obj) end end
    return gunDrops
end
local function GetClosestGunDrop()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return nil end
    local character = localPlayer.Character
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    local pos = rootPart.Position
    local gunDrops = GetAllGunDrops()
    local closest = nil
    local closestDist = math.huge
    for _, gd in ipairs(gunDrops) do
        local gdPos
        if gd:IsA("BasePart") then gdPos = gd.Position
        elseif gd:IsA("Model") then
            local primary = gd.PrimaryPart
            if primary then gdPos = primary.Position
            else
                local parts = gd:GetDescendants()
                for _, part in ipairs(parts) do if part:IsA("BasePart") then gdPos = part.Position break end end
            end
        end
        if gdPos then
            local dist = (pos - gdPos).Magnitude
            if dist < closestDist then closestDist = dist; closest = gd end
        end
    end
    return closest
end
local isGrabbing = false
local function GrabGun(gunDrop, silent)
    if not gunDrop or isGrabbing then return end
    local function notify(title, content) if not silent then SafeNotify({ Title = title, Content = content, Duration = 2 }) end end
    if IsInLobby() then if not silent then notify("Grab Gun", "Cannot grab from lobby") end return end
    if IsLocalPlayerMurderer() then if not silent then notify("Grab Gun", "You are the murderer! Cannot grab a gun.") end return end
    if not IsRoundActive() or not IsPlayerAlive() then if not silent then notify("Grab Gun", "You are dead or round inactive") end return end
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then if not silent then notify("Error", "Local player not found") end return end
    local character = localPlayer.Character
    if not character then if not silent then notify("Error", "Character not found") end return end
    if PlayerHasTool(localPlayer, "Knife") then if not silent then notify("Grab Gun", "You are the murderer! Cannot get GunDrop.") end return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then if not silent then notify("Error", "HumanoidRootPart not found") end return end
    if localPlayer.Backpack and localPlayer.Backpack:FindFirstChild("Gun") then if not silent then notify("Grab Gun", "You already have a gun!") end return end
    if character:FindFirstChild("Gun") then if not silent then notify("Grab Gun", "You already have a gun!") end return end
    isGrabbing = true
    local collected = false
    local offset = Vector3.new(0, 1, 0)
    while true do
        if not gunDrop.Parent then if not silent then notify("Grab Gun", "GunDrop disappeared") end break end
        local targetPos = rootPart.Position + offset
        if gunDrop:IsA("BasePart") then gunDrop.Position = targetPos
        elseif gunDrop:IsA("Model") and gunDrop.PrimaryPart then gunDrop:SetPrimaryPartCFrame(CFrame.new(targetPos))
        else
            local parts = gunDrop:GetDescendants()
            for _, part in ipairs(parts) do if part:IsA("BasePart") then part.Position = targetPos break end end
        end
        task.wait(0.05)
        if localPlayer.Backpack and localPlayer.Backpack:FindFirstChild("Gun") then collected = true
        elseif character and character:FindFirstChild("Gun") then collected = true end
        if collected then break end
        if not gunDrop.Parent then break end
        if IsLocalPlayerMurderer() then break end
        if PlayerHasTool(localPlayer, "Knife") then break end
        if not IsRoundActive() or not IsPlayerAlive() then break end
    end
    isGrabbing = false
    if collected then
        if not silent then SafeNotify({ Title = "Grab Gun", Content = "Gun grabbed successfully!", Duration = 2 }) end
    else
        if not silent then SafeNotify({ Title = "Grab Gun", Content = "Failed to grab gun", Duration = 2 }) end
    end
end
local autoGrabGunEnabled = undeitedhub.Toggles.autoGrabGunEnabled or false
local gunDropAddedConnection = nil
local function AttemptAutoGrab()
    if not autoGrabGunEnabled or not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end
    if IsInLobby() or IsLocalPlayerMurderer() or not IsRoundActive() or not IsPlayerAlive() then return end
    if isGrabbing then return end
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return end
    if PlayerHasTool(localPlayer, "Knife") then return end
    if localPlayer.Backpack and localPlayer.Backpack:FindFirstChild("Gun") then return end
    if localPlayer.Character and localPlayer.Character:FindFirstChild("Gun") then return end
    local gd = GetClosestGunDrop()
    if gd then GrabGun(gd, true) end
end
local function ToggleAutoGrab(state)
    autoGrabGunEnabled = state
    undeitedhub.Toggles.autoGrabGunEnabled = state
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    if state then
        pcall(AttemptAutoGrab)
        if gunDropAddedConnection then gunDropAddedConnection:Disconnect(); gunDropAddedConnection = nil end
        gunDropAddedConnection = workspace.DescendantAdded:Connect(function(obj)
            if autoGrabGunEnabled and obj.Name == "GunDrop" and _G.UNDEITEDHUB_WINDOW_VISIBLE then pcall(AttemptAutoGrab) end
        end)
        SafeNotify({ Title = "Auto Grab Gun", Content = "Enabled", Duration = 2 })
    else
        if gunDropAddedConnection then gunDropAddedConnection:Disconnect(); gunDropAddedConnection = nil end
        SafeNotify({ Title = "Auto Grab Gun", Content = "Disabled", Duration = 2 })
    end
end
CombatTab:Toggle({ Title = "Auto Grab Gun", Value = autoGrabGunEnabled, Callback = function(state) ToggleAutoGrab(state) end })
CombatTab:Button({ Title = "Grab Gun", Callback = function()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then SafeNotify({ Title = "Error", Content = "Local player not found", Duration = 2 }) return end
    if IsInLobby() then SafeNotify({ Title = "Grab Gun", Content = "Cannot grab from lobby", Duration = 2 }) return end
    if IsLocalPlayerMurderer() then SafeNotify({ Title = "Grab Gun", Content = "You are the murderer! Cannot grab a gun.", Duration = 2 }) return end
    if not IsRoundActive() or not IsPlayerAlive() then SafeNotify({ Title = "Grab Gun", Content = "You are dead or round inactive", Duration = 2 }) return end
    if PlayerHasTool(localPlayer, "Knife") then SafeNotify({ Title = "Grab Gun", Content = "You are the murderer! Cannot get GunDrop.", Duration = 2 }) return end
    if localPlayer.Backpack and localPlayer.Backpack:FindFirstChild("Gun") then SafeNotify({ Title = "Grab Gun", Content = "You already have a gun!", Duration = 2 }) return end
    if localPlayer.Character and localPlayer.Character:FindFirstChild("Gun") then SafeNotify({ Title = "Grab Gun", Content = "You already have a gun!", Duration = 2 }) return end
    local gunDrop = GetClosestGunDrop()
    if not gunDrop then SafeNotify({ Title = "Grab Gun", Content = "No GunDrop found", Duration = 2 }) return end
    GrabGun(gunDrop, false)
end })
undeitedhub.DisableAll = function()
    autoKillAllEnabled = false
    undeitedhub.Toggles.autoKillAllEnabled = false
    autoShootEnabled = false
    undeitedhub.Toggles.autoShootEnabled = false
    autoGrabGunEnabled = false
    undeitedhub.Toggles.autoGrabGunEnabled = false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    if gunDropAddedConnection then gunDropAddedConnection:Disconnect(); gunDropAddedConnection = nil end
    murdererHistory = {}
    kalmanStates = {}
end