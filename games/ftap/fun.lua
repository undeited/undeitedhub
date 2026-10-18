local WindUI = undeitedhub.WindUI
local FunTab = undeitedhub.Window:Tab({ Title = "Fun" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local MAX_SPARKLERS = 4

local sparklerEnabled = false
local orbitTask = nil
local syncTask = nil
local activeSparklers = {}
local orbitAngle = 0
local lastSpawnTime = 0
local stuckTimers = {}

local function isPlayerInPlot()
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local pos = hrp.Position

    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return false end

    for _, plot in ipairs(plotsFolder:GetChildren()) do
        if plot:IsA("Model") then
            local base = plot:FindFirstChild("PlotArea") or plot:FindFirstChild("Base") or plot:FindFirstChild("Floor")
            if base and base:IsA("BasePart") then
                local size = base.Size
                local lp = base.CFrame:PointToObjectSpace(pos)
                if math.abs(lp.X) <= size.X * 0.5 + 2 and math.abs(lp.Z) <= size.Z * 0.5 + 2 then
                    return true
                end
            end
        end
    end
    return false
end

local function spawnSparkler()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    if not menuToys then return end
    local spawnRemote = menuToys:FindFirstChild("SpawnToyRemoteFunction")
    if spawnRemote then
        pcall(function()
            spawnRemote:InvokeServer("FireworkSparkler", root.CFrame, Vector3.new(0, 108.14399719238281, 0))
        end)
    end
end

local function destroySparkler(sparkler)
    if not sparkler then return end
    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    local destroyRemote = menuToys and menuToys:FindFirstChild("DestroyToy")
    
    if destroyRemote then
        pcall(function() destroyRemote:InvokeServer(sparkler) end)
    end
    pcall(function() sparkler:Destroy() end)
    stuckTimers[sparkler] = nil
end

local function syncSparklers()
    if not sparklerEnabled then return end
    
    if isPlayerInPlot() then
        activeSparklers = {}
        stuckTimers = {}
        return
    end

    local toysFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if not toysFolder then
        activeSparklers = {}
        if tick() - lastSpawnTime > 1 then
            lastSpawnTime = tick()
            spawnSparkler()
        end
        return
    end

    local currentSparklers = {}
    for _, child in ipairs(toysFolder:GetChildren()) do
        if child.Name == "FireworkSparkler" then
            currentSparklers[child] = true
        end
    end

    -- Remove invalid sparklers from active list
    for i = #activeSparklers, 1, -1 do
        local sp = activeSparklers[i]
        if not currentSparklers[sp] or not sp.Parent then
            table.remove(activeSparklers, i)
            stuckTimers[sp] = nil
        end
    end

    -- Add newly spawned sparklers
    for sparkler in pairs(currentSparklers) do
        if #activeSparklers < MAX_SPARKLERS then
            local found = false
            for _, sp in ipairs(activeSparklers) do
                if sp == sparkler then
                    found = true
                    break
                end
            end

            if not found then
                table.insert(activeSparklers, sparkler)
                local base = sparkler:FindFirstChild("Base")
                local grabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")
                local setNet = grabEvents and grabEvents:FindFirstChild("SetNetworkOwner")
                if base and setNet then
                    pcall(function() setNet:FireServer(base, base.CFrame) end)
                end
            end
        end
    end

    -- Auto-spawn missing sparklers
    local missing = MAX_SPARKLERS - #activeSparklers
    if missing > 0 and tick() - lastSpawnTime > 0.5 then
        lastSpawnTime = tick()
        for i = 1, missing do
            spawnSparkler()
        end
    end
end

local function startSparklers()
    sparklerEnabled = true
    activeSparklers = {}
    stuckTimers = {}
    orbitAngle = 0
    lastSpawnTime = 0
    
    syncTask = task.spawn(function()
        while sparklerEnabled do
            syncSparklers()
            task.wait(0.2)
        end
    end)

    orbitTask = RunService.Heartbeat:Connect(function(dt)
        if not sparklerEnabled then return end
        if isPlayerInPlot() then return end

        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local count = #activeSparklers
        if count == 0 then return end

        orbitAngle = orbitAngle + 3 * dt
        local radius = 5

        -- Iterate backwards so we can safely remove elements
        for i = #activeSparklers, 1, -1 do
            local sparkler = activeSparklers[i]
            if sparkler and sparkler.Parent then
                local base = sparkler:FindFirstChild("Base")
                
                -- Force unanchor just in case the game anchored it
                if base and base.Anchored then
                    base.Anchored = false
                end

                local offsetAngle = orbitAngle + (i * (math.pi * 2 / count))
                local offsetX = math.cos(offsetAngle) * radius
                local offsetZ = math.sin(offsetAngle) * radius
                
                local targetPos = root.Position + Vector3.new(offsetX, 2, offsetZ)
                local lookDir = Vector3.new(offsetX, 0, offsetZ).Unit
                
                pcall(function()
                    sparkler:PivotTo(CFrame.lookAt(targetPos, targetPos + lookDir))
                end)

                -- Stuck Detection
                local currentPos = sparkler:GetPivot().Position
                if (currentPos - targetPos).Magnitude > 4 then
                    stuckTimers[sparkler] = (stuckTimers[sparkler] or 0) + 1
                    
                    -- If stuck for ~15 frames (roughly 0.25 seconds), delete it
                    if stuckTimers[sparkler] > 15 then
                        destroySparkler(sparkler)
                        table.remove(activeSparklers, i)
                    end
                else
                    stuckTimers[sparkler] = 0
                end
            else
                table.remove(activeSparklers, i)
            end
        end
    end)
end

local function stopSparklers()
    sparklerEnabled = false
    if orbitTask then
        orbitTask:Disconnect()
        orbitTask = nil
    end
    if syncTask then
        task.cancel(syncTask)
        syncTask = nil
    end
    activeSparklers = {}
    stuckTimers = {}
end

FunTab:Toggle({
    Title = "Sparkler Madness",
    Value = sparklerEnabled,
    Callback = function(state)
        if state then
            startSparklers()
        else
            stopSparklers()
        end
    end
})

undeitedhub.DisableAll = undeitedhub.DisableAll or function() end
local oldDisable = undeitedhub.DisableAll
undeitedhub.DisableAll = function()
    if sparklerEnabled then
        stopSparklers()
    end
    oldDisable()
end
