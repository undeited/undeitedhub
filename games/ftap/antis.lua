local WindUI = undeitedhub.WindUI
local AntiTab = undeitedhub.Window:Tab({ Title = "Antis" })

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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer

local antiKickEnabled = undeitedhub.Toggles.antiKick or false
local antiBurnEnabled = undeitedhub.Toggles.antiBurn or false
local antiGrabEnabled = undeitedhub.Toggles.antiGrab or false
local antiVoidEnabled = undeitedhub.Toggles.antiVoidEnabled or false
local antiTask = nil

local function getToysFolder()
    return Workspace:FindFirstChild(localPlayer.Name .. "SpawnedInToys")
end

local function getNinjaKunai()
    local folder = getToysFolder()
    if not folder then return nil end
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == "NinjaKunai" and child:IsA("Model") then
            return child
        end
    end
    return nil
end

local function getStickyPart(kunai)
    if not kunai then return nil end
    for _, part in ipairs(kunai:GetDescendants()) do
        if part.Name == "StickyPart" and part:IsA("BasePart") then
            return part
        end
    end
    return nil
end

local function getPlayerCharacter()
    if not localPlayer.Character then return nil end
    if not localPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    if not localPlayer.Character:FindFirstChildOfClass("Humanoid") then return nil end
    return localPlayer.Character
end

local function getPlayerCFrame()
    local char = getPlayerCharacter()
    if char then return char.HumanoidRootPart.CFrame end
    return nil
end

local function distanceTo(pos)
    return localPlayer:DistanceFromCharacter(pos)
end

local function lookAt(from, to)
    local unit = (to - from).Unit
    local right = unit:Cross(Vector3.new(0, 1, 0))
    local up = right:Cross(unit)
    return CFrame.fromMatrix(from, right, up)
end

local function hasOwnership(part)
    if not part then return false end
    local owner = part:FindFirstChild("PartOwner")
    if owner and owner.Value == localPlayer.Name then
        return true
    end
    return false
end

local function setNetworkOwner(part)
    if not part then return end
    local remote = ReplicatedStorage:FindFirstChild("GrabEvents")
    if remote then remote = remote:FindFirstChild("SetNetworkOwner") end
    if not remote then return end
    local char = getPlayerCharacter()
    if not char then return end
    pcall(function()
        remote:FireServer(part, lookAt(char.HumanoidRootPart.Position, part.Position))
    end)
end

local function snowshipOnce(part)
    if not part then return false end
    if hasOwnership(part) then return true end
    if distanceTo(part.Position) <= 30 then
        setNetworkOwner(part)
    end
    return false
end

local function snowship(part)
    if not part then return end
    if distanceTo(part.Position) <= 30 then
        setNetworkOwner(part)
    end
end

local function deleteToy(toy)
    if not toy then return end
    local remote = ReplicatedStorage:FindFirstChild("MenuToys")
    if remote then remote = remote:FindFirstChild("DestroyToy") end
    if remote then
        pcall(function()
            remote:FireServer(toy)
        end)
    end
end

local function spawnToy(args)
    if not args then return end
    local remote = ReplicatedStorage:FindFirstChild("MenuToys")
    if remote then remote = remote:FindFirstChild("SpawnToyRemoteFunction") end
    if remote then
        pcall(function()
            remote:InvokeServer(unpack(args))
        end)
    end
end

local function buyToy(toyName)
    if not toyName then return end
    local remote = ReplicatedStorage:FindFirstChild("MenuToys")
    if remote then remote = remote:FindFirstChild("BuyToyRemoteFunction") end
    if remote then
        pcall(function()
            remote:InvokeServer(toyName)
        end)
    end
end

local function getKunaiStatus(kunai)
    if not kunai then return "Useless" end
    local sticky = getStickyPart(kunai)
    if not sticky then return "Useless" end
    local weld = sticky:FindFirstChild("StickyWeld")
    if weld and weld:IsA("WeldConstraint") then
        local part1 = weld.Part1
        if part1 and part1:IsDescendantOf(getPlayerCharacter()) then
            return "Using"
        end
        return "Used"
    end
    return "No use!"
end

local function attachKunai(kunai)
    if not kunai then return end
    local sticky = getStickyPart(kunai)
    if not sticky then return end
    local char = getPlayerCharacter()
    if not char then return end
    local attachPart = char:FindFirstChild("Left Leg") or char:FindFirstChild("HumanoidRootPart")
    if not attachPart then return end
    local relCFrame = CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(90))
    local remote = ReplicatedStorage:FindFirstChild("PlayerEvents")
    if remote then remote = remote:FindFirstChild("StickyPartEvent") end
    if remote then
        pcall(function()
            remote:FireServer(sticky, attachPart, relCFrame)
        end)
    end
end

local function ensureKunai()
    if not antiKickEnabled then return end
    local char = getPlayerCharacter()
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local kunai = getNinjaKunai()
    if not kunai then
        local cframe = getPlayerCFrame()
        if cframe then
            spawnToy({
                "NinjaKunai",
                CFrame.new(cframe.Position.X, cframe.Position.Y, cframe.Position.Z, -0.133750245, -0.471861839, 0.871468484, -3.7252903e-9, 0.879369617, 0.476139903, -0.991015136, 0.0636838302, -0.117615893),
                Vector3.new(0, 97.69000244140625, 0)
            })
            buyToy("NinjaKunai")
            task.wait(0.5)
            kunai = getNinjaKunai()
        end
    end

    if not kunai then return end

    local sticky = getStickyPart(kunai)
    if not sticky then return end

    local status = getKunaiStatus(kunai)
    if status == "Useless" then
        deleteToy(kunai)
        return
    end

    if status == "No use!" then
        if distanceTo(sticky.Position) < 30 then
            if snowshipOnce(sticky) then
                attachKunai(kunai)
            end
        else
            deleteToy(kunai)
        end
    elseif status == "Used" then
        if distanceTo(sticky.Position) >= 30 then
            deleteToy(kunai)
        else
            snowship(sticky)
        end
    elseif status == "Using" then
        snowship(sticky)
    end
end

local function handleBurn()
    if not antiBurnEnabled then return end
    local char = getPlayerCharacter()
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local firePart = root:FindFirstChild("FirePlayerPart")
    if not firePart then return end
    local canBurn = firePart:FindFirstChild("CanBurn")
    if not canBurn or not canBurn.Value then return end

    local extinguish = Workspace:FindFirstChild("Map")
    if extinguish then extinguish = extinguish:FindFirstChild("Hole") end
    if extinguish then extinguish = extinguish:FindFirstChild("PoisonBigHole") end
    if extinguish then extinguish = extinguish:FindFirstChild("ExtinguishPart") end
    if not extinguish then return end

    if firetouchinterest and type(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(firePart, extinguish, 0)
            task.wait()
            firetouchinterest(firePart, extinguish, 1)
        end)
    else
        pcall(function()
            local oldPos = extinguish.Position
            extinguish.CFrame = firePart.CFrame * CFrame.new(math.random(-1,1), math.random(-1,1), math.random(-1,1))
            task.wait(0.05)
            extinguish.Position = oldPos
        end)
    end
end

local function handleGrab()
    if not antiGrabEnabled then return end
    local isHeld = localPlayer:FindFirstChild("IsHeld")
    if not isHeld or not isHeld.Value then return end
    local char = getPlayerCharacter()
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    pcall(function()
        root.Anchored = true
        root.Velocity = Vector3.new(0,0,0)
        local struggle = ReplicatedStorage:FindFirstChild("CharacterEvents")
        if struggle then struggle = struggle:FindFirstChild("Struggle") end
        if struggle then struggle:FireServer(localPlayer) end
        task.wait(0.1)
        root.Anchored = false
    end)
end

local function handleVoid()
    if not antiVoidEnabled then return end
    local char = getPlayerCharacter()
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local pos = root.Position
    local deathHeight = Workspace.FallenPartsDestroyHeight
    if not deathHeight then deathHeight = -500
    if pos.Y <= deathHeight + 50 then
        local spawn = Workspace:FindFirstChild("SpawnLocation")
        if spawn then
            pcall(function()
                root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
            end)
        else
            pcall(function()
                root.CFrame = CFrame.new(0, 50, 0)
            end)
        end
    end
end

local function antiLoop()
    while antiKickEnabled or antiBurnEnabled or antiGrabEnabled or antiVoidEnabled do
        if _G.UNDEITEDHUB_WINDOW_VISIBLE then
            pcall(ensureKunai)
            pcall(handleBurn)
            pcall(handleGrab)
            pcall(handleVoid)
        end
        task.wait(0.5)
    end
end

local function startAnti()
    if antiTask then return end
    antiKickEnabled = undeitedhub.Toggles.antiKick or false
    antiBurnEnabled = undeitedhub.Toggles.antiBurn or false
    antiGrabEnabled = undeitedhub.Toggles.antiGrab or false
    antiVoidEnabled = undeitedhub.Toggles.antiVoidEnabled or false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    antiTask = task.spawn(antiLoop)
end

local function stopAnti()
    antiKickEnabled = false
    antiBurnEnabled = false
    antiGrabEnabled = false
    antiVoidEnabled = false
    undeitedhub.Toggles.antiKick = false
    undeitedhub.Toggles.antiBurn = false
    undeitedhub.Toggles.antiGrab = false
    undeitedhub.Toggles.antiVoidEnabled = false
    if antiTask then
        task.cancel(antiTask)
        antiTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

AntiTab:Toggle({
    Title = "Anti Kick",
    Value = antiKickEnabled,
    Callback = function(state)
        antiKickEnabled = state
        undeitedhub.Toggles.antiKick = state
        if state then startAnti() else stopAnti() end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Kick", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

AntiTab:Toggle({
    Title = "Anti Burn",
    Value = antiBurnEnabled,
    Callback = function(state)
        antiBurnEnabled = state
        undeitedhub.Toggles.antiBurn = state
        if state then startAnti() else stopAnti() end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Burn", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

AntiTab:Toggle({
    Title = "Anti Grab",
    Value = antiGrabEnabled,
    Callback = function(state)
        antiGrabEnabled = state
        undeitedhub.Toggles.antiGrab = state
        if state then startAnti() else stopAnti() end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Grab", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

AntiTab:Toggle({
    Title = "Anti Void",
    Value = antiVoidEnabled,
    Callback = function(state)
        antiVoidEnabled = state
        undeitedhub.Toggles.antiVoidEnabled = state
        if state then startAnti() else stopAnti() end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Anti Void", Content = state and "Enabled" or "Disabled", Duration = 2 })
    end
})

if antiKickEnabled or antiBurnEnabled or antiGrabEnabled or antiVoidEnabled then
    startAnti()
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    stopAnti()
    oldDisable()
end