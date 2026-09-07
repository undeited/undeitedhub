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
local toysFolder = nil

local function getToysFolder()
    if not toysFolder then
        toysFolder = Workspace:FindFirstChild(localPlayer.Name .. "SpawnedInToys")
    end
    return toysFolder
end

local function getNinjaKunai()
    local folder = getToysFolder()
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child.Name == "NinjaKunai" and child:IsA("Model") then
                return child
            end
        end
    end
    return nil
end

local function getStickyPart(kunai)
    if kunai then
        for _, part in ipairs(kunai:GetDescendants()) do
            if part.Name == "StickyPart" and part:IsA("BasePart") then
                return part
            end
        end
    end
    return nil
end

local function getPlayerCharacter()
    if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") and localPlayer.Character:FindFirstChildOfClass("Humanoid") then
        return localPlayer.Character
    end
    return nil
end

local function getPlayerCFrame()
    local char = getPlayerCharacter()
    if char then
        return char.HumanoidRootPart.CFrame
    end
    return nil
end

local function distanceFromCharacter(pos)
    return localPlayer:DistanceFromCharacter(pos)
end

local function lookAt(from, to)
    local unit = (to - from).Unit
    local right = unit:Cross(Vector3.new(0, 1, 0))
    local up = right:Cross(unit)
    return CFrame.fromMatrix(from, right, up)
end

local function checkOwnership(part)
    if part and part:FindFirstChild("PartOwner") and part.PartOwner.Value == localPlayer.Name then
        return true
    end
    return false
end

local function setNetworkOwner(part)
    local setNetworkOwner = ReplicatedStorage:FindFirstChild("GrabEvents") and ReplicatedStorage.GrabEvents:FindFirstChild("SetNetworkOwner")
    if setNetworkOwner then
        local char = getPlayerCharacter()
        if char and part then
            pcall(function()
                setNetworkOwner:FireServer(part, lookAt(char.HumanoidRootPart.Position, part.Position))
            end)
        end
    end
end

local function snowshipOnce(part)
    if not part then return false end
    if checkOwnership(part) then
        return true
    end
    if distanceFromCharacter(part.Position) <= 30 then
        setNetworkOwner(part)
    end
    return false
end

local function snowship(part)
    if not part then return end
    if distanceFromCharacter(part.Position) <= 30 then
        setNetworkOwner(part)
    end
end

local function deleteToy(toy)
    local deleteRemote = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
    if deleteRemote then
        pcall(function()
            deleteRemote:FireServer(toy)
        end)
    end
end

local function spawnToy(args)
    local spawnRemote = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("SpawnToyRemoteFunction")
    if spawnRemote then
        pcall(function()
            spawnRemote:InvokeServer(unpack(args))
        end)
    end
end

local function buyToy(toyName)
    local buyRemote = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("BuyToyRemoteFunction")
    if buyRemote then
        pcall(function()
            buyRemote:InvokeServer(toyName)
        end)
    end
end

local function checkKunaiStatus(kunai)
    if not kunai then return "Useless" end
    local sticky = getStickyPart(kunai)
    if not sticky then return "Useless" end
    local weld = sticky:FindFirstChild("StickyWeld")
    if weld and weld:IsA("Weld") then
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
    local stickyEvent = ReplicatedStorage:FindFirstChild("PlayerEvents") and ReplicatedStorage.PlayerEvents:FindFirstChild("StickyPartEvent")
    if stickyEvent then
        pcall(function()
            stickyEvent:FireServer(sticky, attachPart, relCFrame)
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

    if kunai then
        local sticky = getStickyPart(kunai)
        if sticky then
            local status = checkKunaiStatus(kunai)
            if status == "Useless" then
                deleteToy(kunai)
                return
            end
            if status == "No use!" then
                if distanceFromCharacter(sticky.Position) < 30 then
                    if snowshipOnce(sticky) then
                        attachKunai(kunai)
                    end
                else
                    deleteToy(kunai)
                end
            elseif status == "Used" then
                if distanceFromCharacter(sticky.Position) >= 30 then
                    deleteToy(kunai)
                else
                    snowship(sticky)
                end
            elseif status == "Using" then
                snowship(sticky)
            end
        end
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
    local extinguishPart = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Hole") and Workspace.Map.Hole:FindFirstChild("PoisonBigHole") and Workspace.Map.Hole.PoisonBigHole:FindFirstChild("ExtinguishPart")
    if not extinguishPart then return end

    if firetouchinterest and type(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(firePart, extinguishPart, 0)
            task.wait()
            firetouchinterest(firePart, extinguishPart, 1)
        end)
    else
        pcall(function()
            local origPos = extinguishPart.Position
            extinguishPart.CFrame = firePart.CFrame * CFrame.new(math.random(-1,1), math.random(-1,1), math.random(-1,1))
            task.wait(0.05)
            extinguishPart.Position = origPos
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
        local struggle = ReplicatedStorage:FindFirstChild("CharacterEvents") and ReplicatedStorage.CharacterEvents:FindFirstChild("Struggle")
        if struggle then
            struggle:FireServer(localPlayer)
        end
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
    local deathBarrierHeight = Workspace.FallenPartsDestroyHeight
    if not deathBarrierHeight then deathBarrierHeight = -500
    if pos.Y <= deathBarrierHeight + 50 then
        local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
        if spawnLocation then
            pcall(function()
                root.CFrame = spawnLocation.CFrame + Vector3.new(0, 3, 0)
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