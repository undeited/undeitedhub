local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local WindUI = undeltedhub.WindUI
local utils = undeltedhub.Utils
local config = undeltedhub.Config

local FarmTab = undeltedhub.Window:Tab({ Title = "Auto Farm" })

local function getPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        for _, part in ipairs(obj:GetDescendants()) do
            if part:IsA("BasePart") then return part.Position end
        end
    end
    return nil
end

local autoFarmEnabled = undeltedhub.Toggles.autoFarmEnabled or false
local loopTask = nil
local childAddedConn = nil
local isRunning = false

local function refreshPairs()
    local scene = Workspace:FindFirstChild("Scene")
    local beach = scene and scene:FindFirstChild("Beach")
    local beachballs = beach and beach:FindFirstChild("Beachballs")
    local goalsFolder = beach and beach:FindFirstChild("Goals")
    local balls, goals = {}, {}
    if beachballs then
        for _, child in ipairs(beachballs:GetChildren()) do
            if string.find(string.lower(child.Name), "ball") then table.insert(balls, child) end
        end
    end
    if goalsFolder then
        for _, child in ipairs(goalsFolder:GetChildren()) do
            if string.find(string.lower(child.Name), "goal") then table.insert(goals, child) end
        end
    end
    table.sort(balls, function(a,b) return a.Name < b.Name end)
    table.sort(goals, function(a,b) return a.Name < b.Name end)
    local pairs = {}
    local count = math.min(#balls, #goals)
    for i=1,count do table.insert(pairs, { ball=balls[i], goal=goals[i] }) end
    return pairs
end

local function RideAndScore(ball, goalPos)
    if not ball or not goalPos then return false end
    local character = LocalPlayer.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    local ballPos = getPosition(ball)
    if not ballPos then return false end
    if (ballPos - goalPos).Magnitude < 2 then return true end
    local tweenInfo1 = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween1 = TweenService:Create(rootPart, tweenInfo1, { CFrame = CFrame.new(ballPos) })
    tween1:Play()
    tween1.Completed:Wait()
    local tweenInfo2 = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    if ball:IsA("BasePart") then
        local tweenBall = TweenService:Create(ball, tweenInfo2, { CFrame = CFrame.new(goalPos) })
        local tweenPlayer = TweenService:Create(rootPart, tweenInfo2, { CFrame = CFrame.new(goalPos) })
        tweenBall:Play()
        tweenPlayer:Play()
        tweenBall.Completed:Wait()
    else
        if ball.PrimaryPart then
            local tweenBall = TweenService:Create(ball.PrimaryPart, tweenInfo2, { CFrame = CFrame.new(goalPos) })
            local tweenPlayer = TweenService:Create(rootPart, tweenInfo2, { CFrame = CFrame.new(goalPos) })
            tweenBall:Play()
            tweenPlayer:Play()
            tweenBall.Completed:Wait()
        else
            for _, part in ipairs(ball:GetDescendants()) do
                if part:IsA("BasePart") then part.CFrame = CFrame.new(goalPos) end
            end
            local tweenPlayer = TweenService:Create(rootPart, tweenInfo2, { CFrame = CFrame.new(goalPos) })
            tweenPlayer:Play()
            tweenPlayer.Completed:Wait()
        end
    end
    return true
end

local function ScoreAll()
    for _, pair in ipairs(refreshPairs()) do
        if pair.ball and pair.goal then
            local goalPos = getPosition(pair.goal)
            if goalPos then RideAndScore(pair.ball, goalPos) end
        end
    end
end

local function ScoreBallByObject(ball)
    for _, pair in ipairs(refreshPairs()) do
        if pair.ball == ball then
            local goalPos = getPosition(pair.goal)
            if goalPos then task.wait(0.3); RideAndScore(ball, goalPos) end
            break
        end
    end
end

local function startAutoFarm()
    if isRunning then return end
    isRunning = true
    autoFarmEnabled = true
    undeltedhub.Toggles.autoFarmEnabled = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    pcall(ScoreAll)
    loopTask = task.spawn(function()
        while isRunning do
            if not _G.UNDELTEDHUB_WINDOW_VISIBLE then
                task.wait(1)
                continue
            end
            pcall(ScoreAll)
            task.wait(1)
        end
    end)
    local beachballs = Workspace:FindFirstChild("Scene") and Workspace.Scene:FindFirstChild("Beach") and Workspace.Scene.Beach:FindFirstChild("Beachballs")
    if beachballs then
        childAddedConn = beachballs.ChildAdded:Connect(function(child)
            if isRunning and _G.UNDELTEDHUB_WINDOW_VISIBLE and string.find(string.lower(child.Name), "ball") then
                ScoreBallByObject(child)
            end
        end)
    end
    pcall(WindUI.Notify, WindUI, { Title = "Auto Farm", Content = "Enabled", Duration = 2 })
end

local function stopAutoFarm()
    isRunning = false
    autoFarmEnabled = false
    undeltedhub.Toggles.autoFarmEnabled = false
    if loopTask then task.cancel(loopTask); loopTask = nil end
    if childAddedConn then childAddedConn:Disconnect(); childAddedConn = nil end
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    pcall(WindUI.Notify, WindUI, { Title = "Auto Farm", Content = "Disabled", Duration = 2 })
end

pcall(function()
    FarmTab:Toggle({
        Title = "Auto Score Balls",
        Value = autoFarmEnabled,
        Callback = function(state)
            if state then startAutoFarm() else stopAutoFarm() end
        end
    })
end)

local function createOrbitToggle(targetName, targetPath, defaultRadius, defaultSpeed)
    local orbitEnabled = undeltedhub.Toggles["orbit_" .. targetName] or false
    local orbitHeartbeatConn = nil
    local isOrbiting = false
    local orbitAngle = 0
    local orbitRadius = defaultRadius or 8
    local orbitSpeed = defaultSpeed or 2.0
    local originalWalkSpeed = 16
    local originalJumpPower = 50

    local function getTargetPosition()
        return targetPath()
    end

    local function orbitPlayer(deltaTime)
        if not _G.UNDELTEDHUB_WINDOW_VISIBLE then return end
        local character = LocalPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart then return end

        local centerPos = getTargetPosition()
        if not centerPos then return end

        orbitAngle = orbitAngle + orbitSpeed * deltaTime
        local offsetX = math.cos(orbitAngle) * orbitRadius
        local offsetZ = math.sin(orbitAngle) * orbitRadius
        local newPos = centerPos + Vector3.new(offsetX, 0, offsetZ)

        rootPart.CFrame = CFrame.new(newPos, centerPos)

        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end

    local function startOrbit()
        if isOrbiting then return end
        isOrbiting = true
        orbitEnabled = true
        undeltedhub.Toggles["orbit_" .. targetName] = true

        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                originalWalkSpeed = humanoid.WalkSpeed
                originalJumpPower = humanoid.JumpPower
            end
        end

        orbitAngle = 0
        orbitHeartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
            if isOrbiting then
                pcall(orbitPlayer, deltaTime)
            end
        end)

        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
        pcall(WindUI.Notify, WindUI, { Title = "Orbit around " .. targetName, Content = "Enabled", Duration = 2 })
    end

    local function stopOrbit()
        isOrbiting = false
        orbitEnabled = false
        undeltedhub.Toggles["orbit_" .. targetName] = false

        if orbitHeartbeatConn then
            orbitHeartbeatConn:Disconnect()
            orbitHeartbeatConn = nil
        end

        local anyOrbitActive = false
        for key, val in pairs(undeltedhub.Toggles) do
            if string.find(key, "orbit_") and val then
                anyOrbitActive = true
                break
            end
        end
        if not anyOrbitActive then
            local character = LocalPlayer.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = originalWalkSpeed
                    humanoid.JumpPower = originalJumpPower
                end
            end
        end

        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
        pcall(WindUI.Notify, WindUI, { Title = "Orbit around " .. targetName, Content = "Disabled", Duration = 2 })
    end

    pcall(function()
        FarmTab:Toggle({
            Title = "Orbit around " .. targetName,
            Value = orbitEnabled,
            Callback = function(state)
                if state then startOrbit() else stopOrbit() end
            end
        })
    end)

    return stopOrbit
end

local function getDemonKingPosition()
    local npc = Workspace:FindFirstChild("NPC")
    if not npc then return nil end
    local demonKing = npc:FindFirstChild("DemonKing")
    if not demonKing then return nil end
    local demonKingModel = demonKing:FindFirstChild("DemonKing")
    if demonKingModel then
        local pos = getPosition(demonKingModel)
        if pos then return pos end
    end
    return getPosition(demonKing)
end

local function getBorockPosition()
    local npc = Workspace:FindFirstChild("NPC")
    if not npc then return nil end
    local boss = npc:FindFirstChild("Boss")
    if not boss then return nil end
    local borock = boss:FindFirstChild("Borock")
    if borock then
        return getPosition(borock)
    end
    return nil
end

local stopOrbitDemonKing = createOrbitToggle("Demon King", getDemonKingPosition, 8, 2.0)
local stopOrbitBorock = createOrbitToggle("Borock", getBorockPosition, 8, 2.0)

undeltedhub.DisableAll = undeltedhub.DisableAll or function() end
local oldDisable = undeltedhub.DisableAll
undeltedhub.DisableAll = function()
    stopAutoFarm()
    stopOrbitDemonKing()
    stopOrbitBorock()
    oldDisable()
end