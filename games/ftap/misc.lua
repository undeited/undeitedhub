local WindUI = undeitedhub.WindUI
local MiscTab = undeitedhub.Window:Tab({ Title = "Misc" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

MiscTab:Button({
    Title = "Delete All Toys",
    Callback = function()
        pcall(function()
            local player = Players.LocalPlayer
            if not player then return end

            local destroyRemote = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")

            local playerFolderName = player.Name .. "SpawnedInToys"
            local playerFolder = Workspace:FindFirstChild(playerFolderName)
            if not playerFolder then return end

            local toys = {}
            for _, child in ipairs(playerFolder:GetChildren()) do
                if child:IsA("Model") or child:IsA("BasePart") then
                    table.insert(toys, child)
                end
            end

            if #toys == 0 then return end

            if destroyRemote and destroyRemote:IsA("RemoteEvent") then
                for _, toy in ipairs(toys) do
                    pcall(function()
                        destroyRemote:FireServer(toy)
                    end)
                end
            else
                for _, toy in ipairs(toys) do
                    pcall(function()
                        toy:Destroy()
                    end)
                end
            end
        end)
    end
})

local sparklerEnabled = false
local orbitTask = nil
local activeSparklers = {}
local orbitAngle = 0

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

local function startSparklers()
    sparklerEnabled = true
    activeSparklers = {}
    orbitAngle = 0

    for i = 1, 10 do
        if not sparklerEnabled then break end
        spawnSparkler()
        task.wait(0.1)
    end

    if not sparklerEnabled then return end

    local toysFolder = Workspace:WaitForChild(LocalPlayer.Name .. "SpawnedInToys", 2)
    if toysFolder then
        for _, child in ipairs(toysFolder:GetChildren()) do
            if child.Name == "FireworkSparkler" then
                local base = child:FindFirstChild("Base")
                if base then
                    table.insert(activeSparklers, child)
                    local grabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")
                    local setNet = grabEvents and grabEvents:FindFirstChild("SetNetworkOwner")
                    if setNet then
                        pcall(function() setNet:FireServer(base, base.CFrame) end)
                    end
                end
            end
        end
    end

    orbitTask = RunService.Heartbeat:Connect(function(dt)
        if not sparklerEnabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        orbitAngle = orbitAngle + 3 * dt
        local radius = 5

        for i, sparkler in ipairs(activeSparklers) do
            if sparkler and sparkler.Parent then
                local offsetAngle = orbitAngle + (i * (math.pi * 2 / #activeSparklers))
                local targetPos = root.Position + Vector3.new(math.cos(offsetAngle) * radius, 2, math.sin(offsetAngle) * radius)
                
                pcall(function()
                    sparkler:PivotTo(CFrame.new(targetPos))
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
    clearSparklers()
end

MiscTab:Toggle({
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
