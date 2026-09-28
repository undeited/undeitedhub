local WindUI = undeitedhub.WindUI
local CombatTab = undeitedhub.Window:Tab({ Title = "Combat" })
local config = undeitedhub.Config
local MathUtils = undeitedhub.MathUtils

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

local function GetRoundTimer()
    return workspace:FindFirstChild("RoundTimerPart")
end

local function GetRoundTime()
    local rt = GetRoundTimer()
    if not rt then return -1 end
    local t = rt:GetAttribute("Time")
    if type(t) ~= "number" then return -1 end
    return t
end

local function LoadMapNames()
    if undeitedhub.MM2Maps then return undeitedhub.MM2Maps end

    local baseUrl = undeitedhub.BASE_URL or "https://raw.githubusercontent.com/undeited/undeitedhub/main/"
    local url = baseUrl .. "games/mm2/maps.json"

    local ok, result = pcall(function()
        local raw
        if game and type(game.HttpGet) == "function" then
            raw = game:HttpGet(url)
        elseif game and type(game.HttpGetAsync) == "function" then
            raw = game:HttpGetAsync(url)
        else
            error("no http")
        end
        return game:GetService("HttpService"):JSONDecode(raw)
    end)

    local out = {}
    if ok and type(result) == "table" then
        local list = result.maps or result
        if type(list) == "table" then
            for _, v in ipairs(list) do
                if type(v) == "string" then
                    table.insert(out, v)
                end
            end
        end
    end

    undeitedhub.MM2Maps = out
    return out
end

local MAP_NAMES = LoadMapNames()

local function GetCurrentMap()
    for _, name in ipairs(MAP_NAMES) do
        local map = workspace:FindFirstChild(name)
        if map then
            return map
        end
    end
    return nil
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
    local time = GetRoundTime()
    if time > 0 then return true end
    if time == -1 then
        if IsInLobby() then return false end
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
    if gun.Parent == char then
        return true
    end
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

CombatTab:Button({
    Title = "Kill All",
    Callback = function()
        local localPlayer = game.Players.LocalPlayer
        if not localPlayer then
            SafeNotify({ Title = "Error", Content = "Local player not found", Duration = 2 })
            return
        end
        if not IsRoundActive() or not IsPlayerAlive() or IsInLobby() then
            SafeNotify({ Title = "Kill All", Content = "Not alive or round inactive", Duration = 2 })
            return
        end
        local knife = GetPlayerKnife()
        if not knife then
            SafeNotify({ Title = "Error", Content = "You are not the murderer (no knife found)", Duration = 2 })
            return
        end
        local handleTouched = knife:FindFirstChild("Events") and knife.Events:FindFirstChild("HandleTouched")
        if not handleTouched or not handleTouched:IsA("RemoteEvent") then
            SafeNotify({ Title = "Error", Content = "HandleTouched remote not found", Duration = 2 })
            return
        end
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
        if killed > 0 then
            SafeNotify({ Title = "Kill All", Content = "Killed " .. killed .. " alive players!", Duration = 2 })
        else
            SafeNotify({ Title = "Kill All", Content = "No alive players to kill", Duration = 2 })
        end
    end
})

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

CombatTab:Toggle({
    Title = "Auto Kill All",
    Value = autoKillAllEnabled,
    Callback = function(state)
        autoKillAllEnabled = state
        undeitedhub.Toggles.autoKillAllEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({
            Title = "Auto Kill All",
            Content = autoKillAllEnabled and "Enabled" or "Disabled",
            Duration = 2,
        })
        if autoKillAllEnabled then
            lastAutoKillAllTime = tick()
        end
    end
})

local autoShootEnabled = undeitedhub.Toggles.autoShootEnabled or false
local lastShootTime = 0
local BULLET_SPEED = 1200

local pingHistory = {}

local function GetPingRaw()
    local ping = 0
    pcall(function()
        local stats = game:GetService("Stats")
        if stats and stats.Network and stats.Network.ServerStatsItem then
            local item = stats.Network.ServerStatsItem["Data Ping"]
            if item then
                ping = item:GetValue() / 1000
            end
        end
    end)
    return ping
end

local function GetSmoothedPing()
    local raw = GetPingRaw()
    if raw < 0 then raw = 0 end
    table.insert(pingHistory, raw)
    if #pingHistory > 20 then table.remove(pingHistory, 1) end
    local sum = 0
    for _, v in ipairs(pingHistory) do sum = sum + v end
    local avg = sum / #pingHistory
    if avg > 0.5 then avg = 0.5 end
    return avg
end

local function GetPlayerCount()
    return #game.Players:GetPlayers()
end

local function AutoTuneConfig()
    local ping = GetSmoothedPing()
    local players = GetPlayerCount()

    local iterations = 4
    if ping > 0.05 then iterations = 5 end
    if ping > 0.1 then iterations = 6 end
    if ping > 0.18 then iterations = 7 end
    if ping > 0.3 then iterations = 8 end

    local maxPrediction = 10
    if ping > 0.05 then maxPrediction = 12 end
    if ping > 0.12 then maxPrediction = 15 end
    if ping > 0.2 then maxPrediction = 18 end
    if ping > 0.3 then maxPrediction = 22 end

    local cooldown = config.cooldowns.autoShoot or 0.3
    if players > 8 then
        cooldown = math.max(cooldown, 0.35)
    end
    if players > 12 then
        cooldown = math.max(cooldown, 0.45)
    end
    if ping > 0.25 then
        cooldown = math.max(cooldown, 0.4)
    end

    return iterations, maxPrediction, cooldown
end

local function AutoTuneHistory()
    return 6
end

local murdererHistory = {}

local function GetMurdererVelocity(murderer)
    local history = murdererHistory[murderer]
    if not history then return Vector3.new(0, 0, 0), 0 end
    if MathUtils.SmoothVelocity then
        local v = MathUtils.SmoothVelocity(history, AutoTuneHistory())
        return v, v.Magnitude
    end
    return Vector3.new(0, 0, 0), 0
end

local function UpdateMurdererHistory(murderer, pos)
    local history = murdererHistory[murderer]
    if not history then
        history = {}
        murdererHistory[murderer] = history
    end
    table.insert(history, { pos = pos, time = tick() })
    local maxHistory = AutoTuneHistory()
    while #history > maxHistory do
        table.remove(history, 1)
    end
end

local function ComputePredictedPosition(origin, targetPos, velocity, speed)
    local iterations, maxPrediction = AutoTuneConfig()
    local ping = GetSmoothedPing()
    local gravity = Vector3.new(0, -workspace.Gravity, 0)

    local dynamicMax = maxPrediction
    if speed > 15 then dynamicMax = dynamicMax + 2 end
    if speed > 25 then dynamicMax = dynamicMax + 4 end
    if speed > 40 then dynamicMax = dynamicMax + 6 end

    local distance = (targetPos - origin).Magnitude
    if distance > 80 then dynamicMax = dynamicMax + 3 end
    if distance > 150 then dynamicMax = dynamicMax + 6 end

    local predicted = nil

    if MathUtils.PredictLinearIntercept then
        local intercept = MathUtils.PredictLinearIntercept(origin, targetPos, velocity, BULLET_SPEED)
        if intercept then
            predicted = intercept
            local travelTime = 0
            if MathUtils.SolveTravelTime then
                travelTime = MathUtils.SolveTravelTime(origin, targetPos, velocity, BULLET_SPEED) or 0
            end
            local totalTime = travelTime + ping
            predicted = predicted + gravity * 0.5 * (totalTime * totalTime)
        end
    end

    if not predicted and MathUtils.PredictPositionIterative then
        predicted = MathUtils.PredictPositionIterative(
            origin,
            targetPos,
            velocity,
            BULLET_SPEED,
            gravity,
            iterations
        )
        if ping > 0 then
            predicted = predicted + gravity * 0.5 * (ping * ping)
        end
    end

    if not predicted then
        predicted = MathUtils.PredictPosition(origin, targetPos, velocity, BULLET_SPEED, gravity)
        if ping > 0 then
            predicted = predicted + gravity * 0.5 * (ping * ping)
        end
    end

    if MathUtils.ClampMagnitude then
        predicted = MathUtils.ClampMagnitude(predicted - targetPos, dynamicMax) + targetPos
    end

    return predicted
end

local function GetShootRemote()
    local gun = GetPlayerGun()
    if not gun then return nil end
    local shoot = gun:FindFirstChild("Shoot")
    if shoot and shoot:IsA("RemoteEvent") then
        return shoot
    end
    for _, child in ipairs(gun:GetChildren()) do
        if child:IsA("RemoteEvent") then
            return child
        end
    end
    return nil
end

local function GetGunRaycastAttachment()
    local gun = GetPlayerGun()
    if not gun then return nil end
    local att = gun:FindFirstChild("GunRaycastAttachment", true)
    if att and att:IsA("Attachment") then
        return att
    end
    return nil
end

local function GetGunOriginCFrame()
    local att = GetGunRaycastAttachment()
    if att then
        local ok, cf = pcall(function() return att.WorldCFrame end)
        if ok and cf then return cf end
    end

    local localPlayer = game.Players.LocalPlayer
    local char = localPlayer and localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.CFrame end

    local camera = workspace.CurrentCamera
    if camera then return camera.CFrame end

    return nil
end

local function CheckLineOfSight(origin, targetPos, murdererChar, localPlayer, murderer)
    local map = GetCurrentMap()

    local includeList = {}
    if map then
        table.insert(includeList, map)
    end
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char and char.Parent then
                table.insert(includeList, char)
            end
        end
    end

    if #includeList == 0 then
        return true, false
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = includeList
    raycastParams.IgnoreWater = true

    local direction = targetPos - origin
    local rayResult = workspace:Raycast(origin, direction, raycastParams)

    if not rayResult then
        return true, false
    end

    local hitPart = rayResult.Instance

    if hitPart:IsDescendantOf(murdererChar) then
        return true, false
    end

    if map and hitPart:IsDescendantOf(map) then
        return false, false
    end

    local playerHit = game.Players:GetPlayerFromCharacter(hitPart.Parent)
    if playerHit and playerHit ~= localPlayer then
        return false, true
    end

    return false, false
end

local function FireShootRemote(shootRemote, originCFrame, targetPos)
    if not shootRemote or not originCFrame then return end
    pcall(function()
        shootRemote:FireServer(originCFrame.Position, targetPos)
    end)
end

local function BuildShotContext()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return nil, "no localplayer" end
    if not IsRoundActive() then return nil, "round inactive" end
    if not IsPlayerAlive() then return nil, "dead" end
    if IsInLobby() then return nil, "in lobby" end

    if not EquipGun() then return nil, "cannot equip gun" end
    local gun = GetPlayerGun()
    if not gun then return nil, "no gun" end
    local shootRemote = GetShootRemote()
    if not shootRemote then return nil, "no shoot remote" end

    local murderer = undeitedhub.GetCurrentMurderer()
    if not murderer then return nil, "no murderer" end
    local murdererChar = murderer.Character
    if not murdererChar then return nil, "murderer no character" end
    local rootPart = murdererChar:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil, "murderer no HRP" end

    local originCFrame = GetGunOriginCFrame()
    if not originCFrame then return nil, "no origin" end

    local currentPos = rootPart.Position
    UpdateMurdererHistory(murderer, currentPos)
    local velocity, speed = GetMurdererVelocity(murderer)

    local predictedPos = ComputePredictedPosition(originCFrame.Position, currentPos, velocity, speed)

    return {
        localPlayer = localPlayer,
        murderer = murderer,
        murdererChar = murdererChar,
        rootPart = rootPart,
        originCFrame = originCFrame,
        shootRemote = shootRemote,
        currentPos = currentPos,
        predictedPos = predictedPos,
        velocity = velocity,
        speed = speed,
        gun = gun,
    }
end

local function ResolveTargetPos(ctx)
    local origin = ctx.originCFrame.Position
    local candidates = {
        ctx.predictedPos,
        ctx.currentPos,
        ctx.rootPart.Position + Vector3.new(0, 1, 0),
    }

    local lastBlockedByInnocent = false
    local anyBlocked = false

    for _, pos in ipairs(candidates) do
        local visible, blockedByInnocent = CheckLineOfSight(origin, pos, ctx.murdererChar, ctx.localPlayer, ctx.murderer)
        if visible then
            return pos, false, false
        end
        anyBlocked = true
        lastBlockedByInnocent = blockedByInnocent
    end

    return nil, anyBlocked, lastBlockedByInnocent
end

local function ShootMurdererOnce()
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return false end
    local ctx, err = BuildShotContext()
    if not ctx then
        SafeNotify({ Title = "Shoot Murderer", Content = "Cannot shoot: " .. tostring(err), Duration = 2 })
        return false
    end

    local targetPos, blocked, blockedByInnocent = ResolveTargetPos(ctx)
    if blocked then
        if blockedByInnocent then
            SafeNotify({ Title = "Shoot Murderer", Content = "Blocked: another player in the way", Duration = 2 })
        else
            SafeNotify({ Title = "Shoot Murderer", Content = "Blocked: wall in the way", Duration = 2 })
        end
        return false
    end

    FireShootRemote(ctx.shootRemote, ctx.originCFrame, targetPos)
    SafeNotify({ Title = "Shoot Murderer", Content = "Shot fired at " .. ctx.murderer.Name, Duration = 2 })
    return true
end

local function ShootAtMurderer()
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end
    local ctx = BuildShotContext()
    if not ctx then return end
    local targetPos, blocked = ResolveTargetPos(ctx)
    if blocked then return end
    FireShootRemote(ctx.shootRemote, ctx.originCFrame, targetPos)
end

game:GetService("RunService").Heartbeat:Connect(function()
    if autoShootEnabled and _G.UNDEITEDHUB_WINDOW_VISIBLE then
        local now = tick()
        local _, _, cooldown = AutoTuneConfig()
        if now - lastShootTime >= cooldown then
            lastShootTime = now
            pcall(ShootAtMurderer)
        end
    end
end)

CombatTab:Button({
    Title = "Shoot Murderer",
    Callback = function()
        pcall(ShootMurdererOnce)
    end
})

CombatTab:Toggle({
    Title = "Auto Shoot Murderer",
    Value = autoShootEnabled,
    Callback = function(state)
        autoShootEnabled = state
        undeitedhub.Toggles.autoShootEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({
            Title = "Auto Shoot Murderer",
            Content = autoShootEnabled and "Enabled" or "Disabled",
            Duration = 2,
        })
        if autoShootEnabled then
            lastShootTime = tick()
            murdererHistory = {}
            pingHistory = {}
        end
    end
})

local function GetAllGunDrops()
    local gunDrops = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" then
            table.insert(gunDrops, obj)
        end
    end
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
        if gd:IsA("BasePart") then
            gdPos = gd.Position
        elseif gd:IsA("Model") then
            local primary = gd.PrimaryPart
            if primary then
                gdPos = primary.Position
            else
                local parts = gd:GetDescendants()
                for _, part in ipairs(parts) do
                    if part:IsA("BasePart") then
                        gdPos = part.Position
                        break
                    end
                end
            end
        end
        if gdPos then
            local dist = (pos - gdPos).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = gd
            end
        end
    end
    return closest
end

local isGrabbing = false

local function GrabGun(gunDrop, silent)
    if not gunDrop or isGrabbing then return end
    local function notify(title, content)
        if not silent then
            SafeNotify({ Title = title, Content = content, Duration = 2 })
        end
    end
    if IsInLobby() then
        if not silent then notify("Grab Gun", "Cannot grab from lobby") end
        return
    end
    if IsLocalPlayerMurderer() then
        if not silent then notify("Grab Gun", "You are the murderer! Cannot grab a gun.") end
        return
    end
    if not IsRoundActive() or not IsPlayerAlive() then
        if not silent then notify("Grab Gun", "You are dead or round inactive") end
        return
    end
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then
        if not silent then notify("Error", "Local player not found") end
        return
    end
    local character = localPlayer.Character
    if not character then
        if not silent then notify("Error", "Character not found") end
        return
    end
    if PlayerHasTool(localPlayer, "Knife") then
        if not silent then notify("Grab Gun", "You are the murderer! Cannot get GunDrop.") end
        return
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        if not silent then notify("Error", "HumanoidRootPart not found") end
        return
    end
    if localPlayer.Backpack and localPlayer.Backpack:FindFirstChild("Gun") then
        if not silent then notify("Grab Gun", "You already have a gun!") end
        return
    end
    if character:FindFirstChild("Gun") then
        if not silent then notify("Grab Gun", "You already have a gun!") end
        return
    end
    isGrabbing = true
    local collected = false
    local offset = Vector3.new(0, 1, 0)
    while true do
        if not gunDrop.Parent then
            if not silent then notify("Grab Gun", "GunDrop disappeared") end
            break
        end
        local targetPos = rootPart.Position + offset
        if gunDrop:IsA("BasePart") then
            gunDrop.Position = targetPos
        elseif gunDrop:IsA("Model") and gunDrop.PrimaryPart then
            gunDrop:SetPrimaryPartCFrame(CFrame.new(targetPos))
        else
            local parts = gunDrop:GetDescendants()
            for _, part in ipairs(parts) do
                if part:IsA("BasePart") then
                    part.Position = targetPos
                    break
                end
            end
        end
        task.wait(0.05)
        if localPlayer.Backpack and localPlayer.Backpack:FindFirstChild("Gun") then
            collected = true
        elseif character and character:FindFirstChild("Gun") then
            collected = true
        end
        if collected then
            break
        end
        if not gunDrop.Parent then
            break
        end
        if IsLocalPlayerMurderer() then
            break
        end
        if PlayerHasTool(localPlayer, "Knife") then
            break
        end
        if not IsRoundActive() or not IsPlayerAlive() then
            break
        end
    end
    isGrabbing = false
    if collected then
        if not silent then
            SafeNotify({ Title = "Grab Gun", Content = "Gun grabbed successfully!", Duration = 2 })
        end
    else
        if not silent then
            SafeNotify({ Title = "Grab Gun", Content = "Failed to grab gun", Duration = 2 })
        end
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
    if gd then
        GrabGun(gd, true)
    end
end

local function ToggleAutoGrab(state)
    autoGrabGunEnabled = state
    undeitedhub.Toggles.autoGrabGunEnabled = state
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    if state then
        pcall(AttemptAutoGrab)
        if gunDropAddedConnection then
            gunDropAddedConnection:Disconnect()
            gunDropAddedConnection = nil
        end
        gunDropAddedConnection = workspace.DescendantAdded:Connect(function(obj)
            if autoGrabGunEnabled and obj.Name == "GunDrop" and _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(AttemptAutoGrab)
            end
        end)
        SafeNotify({ Title = "Auto Grab Gun", Content = "Enabled", Duration = 2 })
    else
        if gunDropAddedConnection then
            gunDropAddedConnection:Disconnect()
            gunDropAddedConnection = nil
        end
        SafeNotify({ Title = "Auto Grab Gun", Content = "Disabled", Duration = 2 })
    end
end

CombatTab:Toggle({
    Title = "Auto Grab Gun",
    Value = autoGrabGunEnabled,
    Callback = function(state)
        ToggleAutoGrab(state)
    end
})

CombatTab:Button({
    Title = "Grab Gun",
    Callback = function()
        local localPlayer = game.Players.LocalPlayer
        if not localPlayer then
            SafeNotify({ Title = "Error", Content = "Local player not found", Duration = 2 })
            return
        end
        if IsInLobby() then
            SafeNotify({ Title = "Grab Gun", Content = "Cannot grab from lobby", Duration = 2 })
            return
        end
        if IsLocalPlayerMurderer() then
            SafeNotify({ Title = "Grab Gun", Content = "You are the murderer! Cannot grab a gun.", Duration = 2 })
            return
        end
        if not IsRoundActive() or not IsPlayerAlive() then
            SafeNotify({ Title = "Grab Gun", Content = "You are dead or round inactive", Duration = 2 })
            return
        end
        if PlayerHasTool(localPlayer, "Knife") then
            SafeNotify({ Title = "Grab Gun", Content = "You are the murderer! Cannot get GunDrop.", Duration = 2 })
            return
        end
        if localPlayer.Backpack and localPlayer.Backpack:FindFirstChild("Gun") then
            SafeNotify({ Title = "Grab Gun", Content = "You already have a gun!", Duration = 2 })
            return
        end
        if localPlayer.Character and localPlayer.Character:FindFirstChild("Gun") then
            SafeNotify({ Title = "Grab Gun", Content = "You already have a gun!", Duration = 2 })
            return
        end
        local gunDrop = GetClosestGunDrop()
        if not gunDrop then
            SafeNotify({ Title = "Grab Gun", Content = "No GunDrop found", Duration = 2 })
            return
        end
        GrabGun(gunDrop, false)
    end
})

undeitedhub.DisableAll = function()
    autoKillAllEnabled = false
    undeitedhub.Toggles.autoKillAllEnabled = false
    autoShootEnabled = false
    undeitedhub.Toggles.autoShootEnabled = false
    autoGrabGunEnabled = false
    undeitedhub.Toggles.autoGrabGunEnabled = false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    if gunDropAddedConnection then
        gunDropAddedConnection:Disconnect()
        gunDropAddedConnection = nil
    end
    murdererHistory = {}
    pingHistory = {}
end
