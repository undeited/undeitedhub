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
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local antiKickEnabled = undeitedhub.Toggles.antiKick or false
local antiBurnEnabled = undeitedhub.Toggles.antiBurn or false
local antiGrabEnabled = undeitedhub.Toggles.antiGrab or false
local antiVoidEnabled = undeitedhub.Toggles.antiVoidEnabled or false

local checkTask = nil
local burnConnections = {}
local grabConnection = nil
local antiVoidLoop = nil

local KunaiFound = nil
local u17 = nil

local function GetPlayerCharacter()
    if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") and localPlayer.Character:FindFirstChildOfClass("Humanoid") then
        return localPlayer.Character
    end
    return nil
end

local function GetPlayerCFrame()
    local char = GetPlayerCharacter()
    if char then
        return char.HumanoidRootPart.CFrame
    end
    return nil
end

local function Getdistancefromcharacter(pos)
    return localPlayer:DistanceFromCharacter(pos)
end

local function lookAt(from, to)
    local unit = (to - from).Unit
    local right = unit:Cross(Vector3.new(0, 1, 0))
    local up = right:Cross(unit)
    return CFrame.fromMatrix(from, right, up)
end

local function CheckNetworkOwnerShipOnPart(part)
    if part and part:FindFirstChild("PartOwner") and part.PartOwner.Value == localPlayer.Name then
        return true
    end
    return false
end

local function SNOWshipOnce(part)
    if not part then return false end
    if CheckNetworkOwnerShipOnPart(part) then
        return true
    end
    local dist = Getdistancefromcharacter(part.Position)
    if dist <= 30 then
        local setNetworkOwner = ReplicatedStorage:FindFirstChild("GrabEvents") and ReplicatedStorage.GrabEvents:FindFirstChild("SetNetworkOwner")
        if setNetworkOwner then
            pcall(function()
                setNetworkOwner:FireServer(part, lookAt(GetPlayerCharacter().HumanoidRootPart.Position, part.Position))
            end)
        end
    end
    return false
end

local function SNOWship(part)
    if not part then return end
    local dist = Getdistancefromcharacter(part.Position)
    if dist <= 30 then
        local setNetworkOwner = ReplicatedStorage:FindFirstChild("GrabEvents") and ReplicatedStorage.GrabEvents:FindFirstChild("SetNetworkOwner")
        if setNetworkOwner then
            pcall(function()
                setNetworkOwner:FireServer(part, lookAt(GetPlayerCharacter().HumanoidRootPart.Position, part.Position))
            end)
        end
    end
end

local function getPlayerToysFolder()
    if not u17 then
        u17 = Workspace:FindFirstChild(localPlayer.Name .. "SpawnedInToys")
    end
    return u17
end

local function DeleteToyRE(toy)
    local deleteRemote = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
    if deleteRemote then
        pcall(function()
            deleteRemote:FireServer(toy)
        end)
    end
end

local function SpawnToy(args)
    local spawnRemote = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("SpawnToyRemoteFunction")
    if spawnRemote then
        pcall(function()
            spawnRemote:InvokeServer(unpack(args))
        end)
    end
end

local function BuyToy(toyName)
    local buyRemote = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("BuyToyRemoteFunction")
    if buyRemote then
        pcall(function()
            buyRemote:InvokeServer(toyName)
        end)
    end
end

local function getNinjaKunai()
    local folder = getPlayerToysFolder()
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

local function CheckIfKunaiIsOnPlayer(kunai)
    if not kunai then return "Useless" end
    local sticky = getStickyPart(kunai)
    if not sticky then return "Useless" end
    local weld = sticky:FindFirstChild("StickyWeld")
    if weld and weld:IsA("Weld") then
        local part1 = weld.Part1
        if part1 and part1:IsDescendantOf(GetPlayerCharacter()) then
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
    local char = GetPlayerCharacter()
    if not char then return end
    local attachPart = char:FindFirstChild("Left Leg") or char:FindFirstChild("HumanoidRootPart")
    if not attachPart then return end
    local relCFrame = CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(90))
    local args = {
        [1] = sticky,
        [2] = attachPart,
        [3] = relCFrame
    }
    local stickyEvent = ReplicatedStorage:FindFirstChild("PlayerEvents") and ReplicatedStorage.PlayerEvents:FindFirstChild("StickyPartEvent")
    if stickyEvent then
        pcall(function()
            stickyEvent:FireServer(unpack(args))
        end)
    end
end

local function ensureKunai()
    if not antiKickEnabled then return end
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end
    local char = GetPlayerCharacter()
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local kunai = getNinjaKunai()
    if not kunai then
        local cframe = GetPlayerCFrame()
        if cframe then
            local args = {
                "NinjaKunai",
                CFrame.new(cframe.Position.X, cframe.Position.Y, cframe.Position.Z, -0.133750245, -0.471861839, 0.871468484, -3.7252903e-9, 0.879369617, 0.476139903, -0.991015136, 0.0636838302, -0.117615893),
                Vector3.new(0, 97.69000244140625, 0)
            }
            SpawnToy(args)
            BuyToy("NinjaKunai")
            task.wait(0.5)
            kunai = getNinjaKunai()
        end
    end

    if kunai then
        local sticky = getStickyPart(kunai)
        if sticky then
            local status = CheckIfKunaiIsOnPlayer(kunai)
            if status == "Useless" then
                DeleteToyRE(kunai)
                return
            end
            if status == "No use!" then
                if Getdistancefromcharacter(sticky.Position) < 30 then
                    if SNOWshipOnce(sticky) then
                        attachKunai(kunai)
                    end
                else
                    DeleteToyRE(kunai)
                end
            elseif status == "Used" then
                if Getdistancefromcharacter(sticky.Position) >= 30 then
                    DeleteToyRE(kunai)
                else
                    SNOWship(sticky)
                end
            elseif status == "Using" then
                SNOWship(sticky)
            end
        end
    end
end

local extinguishPart = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Hole") and Workspace.Map.Hole:FindFirstChild("PoisonBigHole") and Workspace.Map.Hole.PoisonBigHole:FindFirstChild("ExtinguishPart")

local function setupAntiBurn(player)
    if not player or player ~= localPlayer then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local firePart = rootPart:FindFirstChild("FirePlayerPart")
    if not firePart then return end
    local canBurn = firePart:FindFirstChild("CanBurn")
    if not canBurn then return end

    if burnConnections[player] then
        burnConnections[player]:Disconnect()
        burnConnections[player] = nil
    end

    local connection = canBurn.Changed:Connect(function()
        if antiBurnEnabled and canBurn.Value and extinguishPart then
            task.spawn(function()
                while antiBurnEnabled and canBurn.Value do
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
                    task.wait(0.1)
                end
            end)
        end
    end)

    burnConnections[player] = connection
end

local function setupAntiGrab(player)
    if not player or player ~= localPlayer then return end
    local isHeld = player:FindFirstChild("IsHeld")
    if not isHeld then return end

    if grabConnection then
        grabConnection:Disconnect()
        grabConnection = nil
    end

    grabConnection = isHeld.Changed:Connect(function()
        if antiGrabEnabled and isHeld.Value then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if root and hum then
                    pcall(function()
                        root.Anchored = true
                        root.Velocity = Vector3.new(0,0,0)
                        local struggle = ReplicatedStorage:FindFirstChild("CharacterEvents") and ReplicatedStorage.CharacterEvents:FindFirstChild("Struggle")
                        if struggle then
                            struggle:FireServer(player)
                        end
                        task.wait(0.1)
                        root.Anchored = false
                    end)
                end
            end
        end
    end)
end

local function StartAntiVoid()
    if antiVoidLoop then return end
    antiVoidLoop = task.spawn(function()
        local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
        local deathBarrierHeight = Workspace.FallenPartsDestroyHeight
        if not deathBarrierHeight then
            deathBarrierHeight = -500
        end
        local threshold = 50
        local teleportOffset = Vector3.new(0, 3, 0)
        local safePos = Vector3.new(0, 50, 0)
        while antiVoidEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local char = localPlayer.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local pos = root.Position
                        if pos.Y <= deathBarrierHeight + threshold then
                            if spawnLocation then
                                pcall(function()
                                    root.CFrame = spawnLocation.CFrame + teleportOffset
                                end)
                            else
                                pcall(function()
                                    root.CFrame = CFrame.new(safePos)
                                end)
                            end
                        end
                    end
                end
            end
            task.wait(0.1)
        end
        antiVoidLoop = nil
    end)
end

local function StopAntiVoid()
    if antiVoidLoop then
        task.cancel(antiVoidLoop)
        antiVoidLoop = nil
    end
end

local function ensureAnti()
    if antiKickEnabled then
        pcall(ensureKunai)
    end
    if antiBurnEnabled then
        pcall(setupAntiBurn, localPlayer)
    end
    if antiGrabEnabled then
        pcall(setupAntiGrab, localPlayer)
    end
end

local function startAnti()
    if checkTask then return end
    antiKickEnabled = undeitedhub.Toggles.antiKick or false
    antiBurnEnabled = undeitedhub.Toggles.antiBurn or false
    antiGrabEnabled = undeitedhub.Toggles.antiGrab or false
    antiVoidEnabled = undeitedhub.Toggles.antiVoidEnabled or false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    if antiVoidEnabled then
        StartAntiVoid()
    end

    checkTask = task.spawn(function()
        while antiKickEnabled or antiBurnEnabled or antiGrabEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(ensureAnti)
            end
            task.wait(1)
        end
        checkTask = nil
    end)
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
    if checkTask then
        task.cancel(checkTask)
        checkTask = nil
    end
    for _, conn in pairs(burnConnections) do
        pcall(conn.Disconnect, conn)
    end
    burnConnections = {}
    if grabConnection then
        pcall(grabConnection.Disconnect, grabConnection)
        grabConnection = nil
    end
    StopAntiVoid()
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
        if state then
            StartAntiVoid()
            SafeNotify({ Title = "Anti Void", Content = "Enabled", Duration = 2 })
        else
            StopAntiVoid()
            SafeNotify({ Title = "Anti Void", Content = "Disabled", Duration = 2 })
        end
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
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
