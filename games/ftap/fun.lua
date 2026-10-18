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
local refillTask = nil
local activeSparklers = {}
local orbitAngle = 0
local lastRefillTime = 0

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

local function clearSparklers()
    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    local destroyRemote = menuToys and menuToys:FindFirstChild("DestroyToy")
    
    for _, sparkler in ipairs(activeSparklers) do
        if sparkler and sparkler.Parent then
            if destroyRemote then
                pcall(function() destroyRemote:InvokeServer(sparkler) end)
            else
                pcall(function() sparkler:Destroy() end)
            end
        end
    end
    activeSparklers = {}
end

local function refillSparklers()
    if not sparklerEnabled then return end
    if isPlayerInPlot() then return end
    
    local now = tick()
    if now - lastRefillTime < 0.5 then return end
    lastRefillTime = now

    local toysFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if not toysFolder then return end

    local currentSparklers = {}
    for _, child in ipairs(toysFolder:GetChildren()) do
        if child.Name == "FireworkSparkler" then
            table.insert(currentSparklers, child)
        end
    end

    local missing = MAX_SPARKLERS - #currentSparklers
    for i = 1, missing do
        spawnSparkler()
    end
end

local function startSparklers()
    sparklerEnabled = true
    activeSparklers = {}
    orbitAngle = 0
    lastRefillTime = 0
    
    refillTask = task.spawn(function()
        while sparklerEnabled do
            if not isPlayerInPlot() then
                refillSparklers()
            else
                clearSparklers()
            end
            task.wait(0.5)
        end
    end)

    orbitTask = RunService.Heartbeat:Connect(function(dt)
        if not sparklerEnabled then return end
        if isPlayerInPlot() then return end

        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        if #activeSparklers == 0 then
            local toysFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            if toysFolder then
                local grabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")
                local setNet = grabEvents and grabEvents:FindFirstChild("SetNetworkOwner")
                
                for _, child in ipairs(toysFolder:GetChildren()) do
                    if child.Name == "FireworkSparkler" then
                        local base = child:FindFirstChild("Base")
                        if base then
                            table.insert(activeSparklers, child)
                            if setNet then
                                pcall(function() setNet:FireServer(base, base.CFrame) end)
                            end
                        end
                    end
                end
            end
        end

        if #activeSparklers == 0 then return end

        orbitAngle = orbitAngle + 3 * dt
        local radius = 5

        for i, sparkler in ipairs(activeSparklers) do
            if sparkler and sparkler.Parent then
                local offsetAngle = orbitAngle + (i * (math.pi * 2 / MAX_SPARKLERS))
                local offsetX = math.cos(offsetAngle) * radius
                local offsetZ = math.sin(offsetAngle) * radius
                
                local targetPos = root.Position + Vector3.new(offsetX, 2, offsetZ)
                local lookDir = Vector3.new(offsetX, 0, offsetZ).Unit
                
                pcall(function()
                    sparkler:PivotTo(CFrame.lookAt(targetPos, targetPos + lookDir))
                end)
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
    if refillTask then
        task.cancel(refillTask)
        refillTask = nil
    end
    clearSparklers()
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
