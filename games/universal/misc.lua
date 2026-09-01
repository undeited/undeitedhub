local WindUI = undeitedhub.WindUI
local MiscTab = undeitedhub.Window:Tab({ Title = "Misc" })

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

local function HttpGet(url)
    if game and type(game.HttpGet) == "function" then
        return game:HttpGet(url)
    end
    if game and type(game.HttpGetAsync) == "function" then
        return game:HttpGetAsync(url)
    end
    return nil
end

local function LoadString(script, chunkName)
    if type(loadstring) == "function" then
        return loadstring(script, chunkName)
    end
    if type(load) == "function" then
        return load(script, chunkName)
    end
    return nil
end

local function LoadDex(url)
    local success, result = pcall(function()
        local script = HttpGet(url)
        if not script then error("Unsupported executor: missing game:HttpGet or game:HttpGetAsync") end
        local fn, err = LoadString(script, url)
        if not fn then error(err or "Failed to load Dex") end
        return fn()
    end)
    if not success then
        WindUI:Notify({
            Title = "Error",
            Content = "Failed to load Dex. Check your connection.",
            Duration = 4,
        })
    else
        WindUI:Notify({
            Title = "Dex Loaded",
            Content = "Dex loaded successfully.",
            Duration = 3,
        })
    end
end

MiscTab:Button({
    Title = "Load Dex",
    Callback = function()
        LoadDex("https://raw.githubusercontent.com/ltseverydayyou/uuuuuuu/refs/heads/main/DexByMoonMobile")
    end
})

MiscTab:Button({
    Title = "Load Hydroxide",
    Callback = function()
        local success, err = pcall(function()
            local loadHydroxide = LoadScript("shared/hydroxide.lua")
            loadHydroxide()
        end)
        if success then
            WindUI:Notify({
                Title = "Hydroxide",
                Content = "Loaded successfully.",
                Duration = 3,
            })
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Failed to load Hydroxide: " .. tostring(err),
                Duration = 4,
            })
        end
    end
})

SetupAntiFling()

undeitedhub.DisableAll = function()
    antiFlingEnabled = false
    undeitedhub.Toggles.antiFlingEnabled = false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
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
end