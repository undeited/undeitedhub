local WindUI = undeitedhub.WindUI
local BlobmanTab = undeitedhub.Window:Tab({ Title = "Blobman" })

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

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

local function isPlayerInPlot(player)
    if not player or not player.Character then return false end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local pos = hrp.Position
    local playerName = player.Name

    local parent = player.Character.Parent
    while parent and parent ~= Workspace do
        local lower = parent.Name:lower()
        if lower:find("plot") or lower:find("baseplate") or lower:find("base") then
            return true
        end
        parent = parent.Parent
    end

    local plotsFolder = Workspace:FindFirstChild("Plots")
    if plotsFolder then
        for _, plot in ipairs(plotsFolder:GetChildren()) do
            if plot:IsA("Model") or plot:IsA("BasePart") then
                local plotPart
                if plot:IsA("BasePart") then
                    plotPart = plot
                else
                    plotPart = plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart")
                end
                if plotPart then
                    local size = plotPart.Size
                    local radius = math.max(size.X, size.Z) * 0.7
                    if (pos - plotPart.Position).Magnitude < radius then
                        return true
                    end
                end
            end
        end
    end

    local toysFolder = Workspace:FindFirstChild(playerName .. "SpawnedInToys")
    if toysFolder then
        local nearestDist = math.huge
        for _, toy in ipairs(toysFolder:GetChildren()) do
            local toyPart
            if toy:IsA("BasePart") then
                toyPart = toy
            elseif toy:IsA("Model") then
                toyPart = toy.PrimaryPart or toy:FindFirstChildWhichIsA("BasePart")
            end
            if toyPart then
                local d = (pos - toyPart.Position).Magnitude
                if d < nearestDist then nearestDist = d end
            end
        end
        if nearestDist < 100 then
            return true
        end
    end

    return false
end

local kickEnabled = undeitedhub.Toggles.kickPlayer or false
local kickTask = nil
local selectedKickPlayer = nil
local kickDropdown = nil
local KICK_HEIGHT = 30

local INTERACT_KEY = Enum.KeyCode.F
local leftHeldTarget = nil
local rightHeldTarget = nil
local selectedBringPlayerObj = nil
local bringDropdown = nil
local hoveringTargets = {}
local hoverConnections = {}
local heldHovers = {}

local function isPlayerValid(player)
    if not player then return false end
    if not player.Character then return false end
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function clearInvalidHeldTargets()
    if leftHeldTarget and not isPlayerValid(leftHeldTarget) then leftHeldTarget = nil end
    if rightHeldTarget and not isPlayerValid(rightHeldTarget) then rightHeldTarget = nil end
end

local function getPlayerCharacter()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChildOfClass("Humanoid") then
        return character
    end
    return nil
end

local function getPlayerCFrame()
    local character = getPlayerCharacter()
    if character then return character.HumanoidRootPart.CFrame end
    return nil
end

local function getToysFolder()
    return Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
end

local function getBlobmen()
    local folder = getToysFolder()
    if not folder then return {} end
    local blobmen = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == "CreatureBlobman" and child:IsA("Model") then
            table.insert(blobmen, child)
        end
    end
    return blobmen
end

local function deleteToy(toy)
    if not toy then return end
    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    if not menuToys then return end
    local remote = menuToys:FindFirstChild("DestroyToy")
    if remote then
        pcall(function() remote:FireServer(toy) end)
    end
end

local function spawnBlobman()
    local cframe = getPlayerCFrame()
    if not cframe then return end
    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    if not menuToys then return end
    local spawnRemote = menuToys:FindFirstChild("SpawnToyRemoteFunction")
    if spawnRemote then
        pcall(function()
            spawnRemote:InvokeServer("CreatureBlobman", cframe, Vector3.new(0, 97.69000244140625, 0))
        end)
    end
    local buyRemote = menuToys:FindFirstChild("BuyToyRemoteFunction")
    if buyRemote then
        pcall(function() buyRemote:InvokeServer("CreatureBlobman") end)
    end
end

local function ensureSingleBlobman()
    local blobmen = getBlobmen()
    if #blobmen == 0 then
        spawnBlobman()
        task.wait(0.5)
        blobmen = getBlobmen()
    end
    if #blobmen > 1 then
        for i = 2, #blobmen do
            deleteToy(blobmen[i])
        end
        task.wait(0.2)
    end
    return getBlobmen()[1]
end

local function getSeatedBlobman()
    local character = getPlayerCharacter()
    if not character then return nil end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    if hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
        return hum.SeatPart.Parent
    end
    for _, blobman in ipairs(getBlobmen()) do
        local seat = blobman:FindFirstChild("VehicleSeat")
        if seat and seat.Occupant == hum then
            return blobman
        end
    end
    return nil
end

local function sitOnBlobman()
    local character = getPlayerCharacter()
    if not character then return nil end
    local hum = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return nil end
    local seated = getSeatedBlobman()
    if seated then return seated end
    local blobman = ensureSingleBlobman()
    if not blobman then return nil end
    local seat = blobman:FindFirstChild("VehicleSeat")
    if seat and (not seat.Occupant or seat.Occupant == hum) then
        local camera = Workspace.CurrentCamera
        hrp.CFrame = seat.CFrame + Vector3.new(0, 1.5, 0)
        task.wait(0.05)
        if camera then
            camera.CFrame = CFrame.new(camera.CFrame.Position, seat.Position)
        end
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(true, INTERACT_KEY, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, INTERACT_KEY, false, game)
        task.wait(0.3)
        if hum.SeatPart and hum.SeatPart.Parent == blobman then
            return blobman
        end
    end
    return nil
end

local function playGrabAnimation(blobman, side)
    if not blobman then return end
    local anims = blobman:FindFirstChild("BlobmanAnimations")
    if not anims then return end
    local relay = anims:FindFirstChild("RelayClientAnimation")
    if not relay or not relay:IsA("RemoteEvent") then return end
    local animName = side == "left" and "LeftGrabAnimation" or "RightGrabAnimation"
    pcall(function() relay:FireServer(animName, true) end)
end

local function stopHover(target)
    hoveringTargets[target] = nil
    local connection = hoverConnections[target]
    if connection then
        connection:Disconnect()
        hoverConnections[target] = nil
    end
end

local function startHover(target, blobman)
    if not target or not blobman then return end
    stopHover(target)
    hoveringTargets[target] = true
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not hoveringTargets[target] then
            stopHover(target)
            return
        end
        if not target.Parent or not isPlayerValid(target) then
            stopHover(target)
            return
        end
        if not blobman or not blobman.Parent then
            stopHover(target)
            return
        end
        local character = target.Character
        if not character then return end
        local targetRoot = character:FindFirstChild("HumanoidRootPart")
        local blobmanRoot = blobman:FindFirstChild("HumanoidRootPart") or blobman.PrimaryPart or blobman:FindFirstChild("VehicleSeat")
        if not targetRoot or not blobmanRoot then return end
        local position = blobmanRoot.Position + Vector3.new(0, 15, 0)
        local lookDirection = blobmanRoot.CFrame.LookVector
        targetRoot.AssemblyLinearVelocity = Vector3.zero
        targetRoot.AssemblyAngularVelocity = Vector3.zero
        targetRoot.CFrame = CFrame.lookAt(position, position + lookDirection)
    end)
    hoverConnections[target] = connection
end

local function stopHeldHover(target)
    local conn = heldHovers[target]
    if conn then
        conn:Disconnect()
        heldHovers[target] = nil
    end
end

local function stopAllHeldHovers()
    for target, conn in pairs(heldHovers) do
        pcall(function() conn:Disconnect() end)
    end
    heldHovers = {}
end

local function startHeldHover(target, hand)
    if not target then return end
    stopHeldHover(target)

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not target.Parent then
            stopHeldHover(target)
            return
        end
        local char = target.Character
        if not char then
            stopHeldHover(target)
            return
        end
        local targetRoot = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not targetRoot or not hum or hum.Health <= 0 then
            stopHeldHover(target)
            return
        end

        local blobman = getSeatedBlobman()
        if not blobman then return end

        local detectorName = hand == "left" and "LeftDetector" or "RightDetector"
        local weldName = hand == "left" and "LeftWeld" or "RightWeld"
        local detector = blobman:FindFirstChild(detectorName)
        if not detector then
            stopHeldHover(target)
            return
        end
        local weld = detector:FindFirstChild(weldName)
        local ownerScript = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
        local grab = ownerScript and ownerScript:FindFirstChild("CreatureGrab")
        if not grab or not weld then
            return
        end

        pcall(function()
            grab:FireServer(detector, targetRoot, weld)
        end)

        hum.PlatformStand = true
        targetRoot.CFrame = detector.CFrame
        targetRoot.AssemblyLinearVelocity = Vector3.zero
        targetRoot.AssemblyAngularVelocity = Vector3.zero
    end)
    heldHovers[target] = conn
end

local function dropHeldTarget(blobman, side)
    if not blobman then return false end
    local target = side == "left" and leftHeldTarget or rightHeldTarget
    if not target then return false end
    stopHover(target)
    stopHeldHover(target)
    local character = target.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        if side == "left" then leftHeldTarget = nil else rightHeldTarget = nil end
        return false
    end
    local leftDetector = blobman:FindFirstChild("LeftDetector")
    local rightDetector = blobman:FindFirstChild("RightDetector")
    local leftWeld = leftDetector and leftDetector:FindFirstChild("LeftWeld")
    local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
    local ownerScript = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
    local creatureDrop = ownerScript and ownerScript:FindFirstChild("CreatureDrop")
    local weld = side == "left" and leftWeld or rightWeld
    if creatureDrop and weld then
        pcall(function()
            creatureDrop:FireServer(weld, root)
        end)
        if side == "left" then leftHeldTarget = nil else rightHeldTarget = nil end
        return true
    end
    return false
end

local function grabPlayer(blobman, target, hand)
    if not blobman or not target then return false end

    local leftDetector = blobman:FindFirstChild("LeftDetector")
    local rightDetector = blobman:FindFirstChild("RightDetector")
    local leftWeld = leftDetector and leftDetector:FindFirstChild("LeftWeld")
    local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
    local ownerScript = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
    local creatureGrab = ownerScript and ownerScript:FindFirstChild("CreatureGrab")
    local detector, weld
    if hand == "left" then
        detector = leftDetector
        weld = leftWeld
    else
        detector = rightDetector
        weld = rightWeld
    end
    if not detector or not weld or not creatureGrab then return false end

    local character = target.Character
    local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
    local targetHum = character and character:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not targetHum or targetHum.Health <= 0 then return false end

    local GE = ReplicatedStorage:FindFirstChild("GrabEvents")
    local setNet = GE and GE:FindFirstChild("SetNetworkOwner")
    local createLine = GE and GE:FindFirstChild("CreateGrabLine")

    local myChar = getPlayerCharacter()
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end

    for i = 1, 8 do
        if setNet then
            pcall(function()
                setNet:FireServer(targetRoot, CFrame.lookAt(myRoot.Position, targetRoot.Position))
            end)
        end
        task.wait(0.02)
    end

    if createLine then
        pcall(function()
            createLine:FireServer(targetRoot, Vector3.zero, targetRoot.Position, false)
        end)
    end

    targetRoot.CFrame = detector.CFrame
    targetRoot.AssemblyLinearVelocity = Vector3.zero
    targetRoot.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.08)

    local grabSuccess = pcall(function()
        creatureGrab:FireServer(detector, targetRoot, weld)
    end)
    if not grabSuccess then return false end

    task.wait(0.15)

    if hand == "left" then
        leftHeldTarget = target
    else
        rightHeldTarget = target
    end
    playGrabAnimation(blobman, hand)
    return true
end

local function getDropdownName(player)
    return player.DisplayName .. " (@" .. player.Name .. ")"
end

local function getPlayerFromDropdownValue(value)
    if not value or value == "" then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if value == getDropdownName(player) then
                return player
            end
            if value == player.DisplayName then
                return player
            end
            if value == player.Name then
                return player
            end
        end
    end
    return nil
end

local function buildDisplayNames()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(list, getDropdownName(player))
        end
    end
    table.sort(list)
    return list
end

local function startKickLoop()
    if kickTask then return end
    kickEnabled = true
    undeitedhub.Toggles.kickPlayer = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    kickTask = task.spawn(function()
        local GE = ReplicatedStorage:FindFirstChild("GrabEvents")
        local setNet = GE and GE:FindFirstChild("SetNetworkOwner")
        local createLine = GE and GE:FindFirstChild("CreateGrabLine")
        local destroyLine = GE and GE:FindFirstChild("DestroyGrabLine")

        local dragging = false
        local grabStartTime = 0
        local savedPos = nil
        local target = nil
        local lastTarget = nil
        local waitingForPlotExit = false

        while kickEnabled do
            if selectedKickPlayer and selectedKickPlayer ~= "" then
                target = getPlayerFromDropdownValue(selectedKickPlayer)
            else
                target = nil
            end

            if target ~= lastTarget then
                lastTarget = target
                waitingForPlotExit = false
            end

            if not target or not target.Parent or not target.Character then
                dragging = false
                grabStartTime = 0
                waitingForPlotExit = false
                task.wait(0.2)
                continue
            end

            if isPlayerInPlot(target) then
                if not waitingForPlotExit then
                    waitingForPlotExit = true
                    SafeNotify({
                        Title = "Kick Player",
                        Content = "Target in plot — waiting until they leave...",
                        Duration = 2,
                    })
                end
                dragging = false
                grabStartTime = 0
                task.wait(0.3)
                continue
            end

            if waitingForPlotExit then
                waitingForPlotExit = false
                SafeNotify({
                    Title = "Kick Player",
                    Content = "Target left plot — resuming.",
                    Duration = 2,
                })
            end

            local myChar = getPlayerCharacter()
            if not myChar then
                task.wait(0.1)
                continue
            end

            local myRoot = myChar:FindFirstChild("HumanoidRootPart")
            local myHum = myChar:FindFirstChildOfClass("Humanoid")
            if not myRoot or not myHum or myHum.Health <= 0 then
                task.wait(0.1)
                continue
            end

            local seat = myHum.SeatPart
            if not seat or not seat.Parent or seat.Parent.Name ~= "CreatureBlobman" then
                dragging = false
                grabStartTime = 0
                savedPos = myRoot.CFrame
                pcall(sitOnBlobman)
                task.wait(0.1)
                continue
            end

            if not savedPos then
                savedPos = myRoot.CFrame
            end

            local tChar = target.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar and tChar:FindFirstChild("Humanoid")

            if tRoot and tHum and tHum.Health > 0 then
                tRoot.AssemblyLinearVelocity = Vector3.zero
                tRoot.Velocity = Vector3.zero

                local blobman = seat.Parent
                local remoteFolder = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
                local grab = remoteFolder and remoteFolder:FindFirstChild("CreatureGrab")
                local drop = remoteFolder and remoteFolder:FindFirstChild("CreatureDrop")
                local L_Det = blobman:FindFirstChild("LeftDetector")
                local R_Det = blobman:FindFirstChild("RightDetector")
                local L_Weld = L_Det and (L_Det:FindFirstChild("LeftWeld") or L_Det:FindFirstChild("RigidConstraint"))
                local R_Weld = R_Det and (R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChild("RigidConstraint"))

                if grab and drop and L_Weld and R_Weld then
                    pcall(function()
                        grab:FireServer(L_Det, tRoot, L_Weld)
                        grab:FireServer(R_Det, tRoot, R_Weld)
                        drop:FireServer(L_Weld, tRoot)
                        drop:FireServer(R_Weld, tRoot)
                    end)
                end

                if not dragging then
                    myRoot.CFrame = tRoot.CFrame
                    if setNet then
                        pcall(function()
                            setNet:FireServer(tRoot, myRoot.CFrame)
                        end)
                    end
                    if createLine then
                        pcall(function()
                            createLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                        end)
                    end
                    pcall(function()
                        tHum.PlatformStand = true
                    end)
                    if grabStartTime == 0 then grabStartTime = tick() end
                    if tick() - grabStartTime > 0.3 then
                        dragging = true
                        grabStartTime = 0
                    end
                else
                    local lockPos = savedPos * CFrame.new(0, KICK_HEIGHT, 0)
                    myRoot.CFrame = savedPos
                    myRoot.AssemblyLinearVelocity = Vector3.zero
                    myRoot.AssemblyAngularVelocity = Vector3.zero

                    if setNet then
                        pcall(function()
                            setNet:FireServer(tRoot, lockPos)
                        end)
                    end
                    if destroyLine then
                        pcall(function()
                            destroyLine:FireServer(tRoot)
                        end)
                    end
                    if createLine then
                        pcall(function()
                            createLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                        end)
                    end

                    tRoot.CFrame = lockPos
                    tRoot.AssemblyLinearVelocity = Vector3.zero
                    tRoot.AssemblyAngularVelocity = Vector3.zero
                    tRoot.Velocity = Vector3.zero
                    tRoot.RotVelocity = Vector3.zero

                    pcall(function()
                        tHum.PlatformStand = true
                    end)
                end
            else
                dragging = false
                grabStartTime = 0
            end

            RunService.Heartbeat:Wait()
        end

        local myChar = getPlayerCharacter()
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if myRoot and savedPos then
            myRoot.CFrame = savedPos
        end
        kickEnabled = false
        undeitedhub.Toggles.kickPlayer = false
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        kickTask = nil
    end)
end

local function stopKickLoop()
    kickEnabled = false
    undeitedhub.Toggles.kickPlayer = false
    if kickTask then
        task.cancel(kickTask)
        kickTask = nil
    end
    local blobman = getSeatedBlobman()
    if blobman then
        if leftHeldTarget then dropHeldTarget(blobman, "left") end
        if rightHeldTarget then dropHeldTarget(blobman, "right") end
    end
    for target in pairs(hoveringTargets) do
        stopHover(target)
    end
    stopAllHeldHovers()
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

local function bringPlayer(target, dropAfter)
    if not target or target == LocalPlayer then return end
    if not isPlayerValid(target) then return end

    if isPlayerInPlot(target) then
        SafeNotify({
            Title = "Bring Player",
            Content = "Target is in a plot — teleporting would delete the blobman.",
            Duration = 3,
        })
        return
    end

    local blobman = getSeatedBlobman()
    if not blobman then
        blobman = sitOnBlobman()
        if not blobman then return end
    end

    clearInvalidHeldTargets()
    if leftHeldTarget and rightHeldTarget then
        dropHeldTarget(blobman, "left")
        clearInvalidHeldTargets()
    end

    local hand
    if not leftHeldTarget then
        hand = "left"
    elseif not rightHeldTarget then
        hand = "right"
    else
        return
    end

    local localCharacter = getPlayerCharacter()
    if not localCharacter then return end
    local localRoot = localCharacter:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    local targetCharacter = target.Character
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    local targetHum = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not targetHum then return end

    local GE = ReplicatedStorage:FindFirstChild("GrabEvents")
    local setNet = GE and GE:FindFirstChild("SetNetworkOwner")
    local createLine = GE and GE:FindFirstChild("CreateGrabLine")

    local originalCFrame = localRoot.CFrame

    localRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
    task.wait(0.2)

    if not getSeatedBlobman() then
        sitOnBlobman()
        task.wait(0.3)
    end

    for i = 1, 10 do
        pcall(function()
            if setNet then
                setNet:FireServer(targetRoot, localRoot.CFrame)
            end
        end)
        task.wait(0.01)
    end

    pcall(function()
        if createLine then
            createLine:FireServer(targetRoot, Vector3.zero, targetRoot.Position, false)
        end
    end)

    local success = false
    for i = 1, 3 do
        local callSuccess, result = pcall(function()
            return grabPlayer(blobman, target, hand)
        end)
        if callSuccess and result then
            success = true
            break
        end
        task.wait(0.2)
    end

    if not success then
        localRoot.CFrame = originalCFrame
        return
    end

    localRoot.CFrame = originalCFrame
    task.wait(0.05)

    local currentBlobman = getSeatedBlobman()
    local handDet
    if currentBlobman then
        if hand == "left" then
            handDet = currentBlobman:FindFirstChild("LeftDetector")
        else
            handDet = currentBlobman:FindFirstChild("RightDetector")
        end
    end

    for i = 1, 25 do
        if not targetRoot or not targetRoot.Parent or not targetHum.Parent then break end
        if handDet and handDet.Parent then
            pcall(function()
                targetHum.PlatformStand = true
                targetRoot.CFrame = handDet.CFrame
                targetRoot.AssemblyLinearVelocity = Vector3.zero
                targetRoot.AssemblyAngularVelocity = Vector3.zero
                if setNet then
                    setNet:FireServer(targetRoot, handDet.CFrame)
                end
            end)
        end
        task.wait(0.02)
    end

    if dropAfter then
        local finalBlobman = getSeatedBlobman()
        if finalBlobman then
            dropHeldTarget(finalBlobman, hand)
        end
    else
        startHeldHover(target, hand)
    end
end

local function bringSelectedPlayer()
    if not selectedBringPlayerObj then
        SafeNotify({ Title = "Bring Player", Content = "No player selected.", Duration = 2 })
        return
    end
    if not selectedBringPlayerObj.Parent then
        selectedBringPlayerObj = nil
        SafeNotify({ Title = "Bring Player", Content = "Selected player has left.", Duration = 2 })
        return
    end
    if not isPlayerValid(selectedBringPlayerObj) then
        SafeNotify({ Title = "Bring Player", Content = "Selected player is not valid.", Duration = 2 })
        return
    end
    if isPlayerInPlot(selectedBringPlayerObj) then
        SafeNotify({ Title = "Bring Player", Content = "Target is in a plot.", Duration = 3 })
        return
    end
    bringPlayer(selectedBringPlayerObj, false)
end

local lastRefresh = 0
local REFRESH_COOLDOWN = 0.5
local refreshQueued = false

local function refreshDropdownsNow()
    local displayNames = buildDisplayNames()

    if bringDropdown then
        bringDropdown:Refresh(displayNames, true)
        if selectedBringPlayerObj then
            if not selectedBringPlayerObj.Parent then
                selectedBringPlayerObj = nil
                pcall(function() bringDropdown:Set("") end)
            elseif not table.find(displayNames, getDropdownName(selectedBringPlayerObj)) then
                selectedBringPlayerObj = nil
                pcall(function() bringDropdown:Set("") end)
            end
        end
    end

    if kickDropdown then
        kickDropdown:Refresh(displayNames, true)
        if selectedKickPlayer and selectedKickPlayer ~= "" then
            if not table.find(displayNames, selectedKickPlayer) then
                selectedKickPlayer = ""
                pcall(function() kickDropdown:Set("") end)
            end
        end
    end
end

local function refreshDropdowns()
    local now = tick()
    if now - lastRefresh < REFRESH_COOLDOWN then
        if not refreshQueued then
            refreshQueued = true
            task.delay(REFRESH_COOLDOWN - (now - lastRefresh), function()
                refreshQueued = false
                lastRefresh = tick()
                refreshDropdownsNow()
            end)
        end
        return
    end
    lastRefresh = now
    refreshDropdownsNow()
end

bringDropdown = BlobmanTab:Dropdown({
    Title = "Select Player to Bring",
    Values = buildDisplayNames(),
    Value = "",
    Callback = function(value)
        selectedBringPlayerObj = getPlayerFromDropdownValue(value)
    end
})

kickDropdown = BlobmanTab:Dropdown({
    Title = "Select Player to Kick",
    Values = buildDisplayNames(),
    Value = "",
    Callback = function(value) selectedKickPlayer = value end
})

local watched = setmetatable({}, { __mode = "k" })

local function watchPlayer(player)
    if not player or watched[player] then return end
    watched[player] = true
    player.CharacterAdded:Connect(function()
        task.wait(0.2)
        refreshDropdowns()
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    watchPlayer(player)
end

Players.PlayerAdded:Connect(function(player)
    task.wait(0.1)
    watchPlayer(player)
    refreshDropdowns()
end)

Players.PlayerRemoving:Connect(function(player)
    stopHover(player)
    stopHeldHover(player)
    watched[player] = nil
    if selectedBringPlayerObj == player then
        selectedBringPlayerObj = nil
        pcall(function() bringDropdown:Set("") end)
    end
    local formatted = getDropdownName(player)
    if selectedKickPlayer == formatted or selectedKickPlayer == player.DisplayName or selectedKickPlayer == player.Name then
        selectedKickPlayer = ""
        pcall(function() kickDropdown:Set("") end)
    end
    refreshDropdowns()
end)

task.delay(1, function()
    refreshDropdowns()
end)

BlobmanTab:Button({
    Title = "Bring Player",
    Callback = function()
        local ok, err = pcall(bringSelectedPlayer)
        if not ok then
            SafeNotify({
                Title = "Bring Player Error",
                Content = tostring(err):sub(1, 120),
                Duration = 4,
            })
        end
    end
})

BlobmanTab:Toggle({
    Title = "Kick Player",
    Value = kickEnabled,
    Callback = function(state)
        if state then startKickLoop() else stopKickLoop() end
    end
})

if kickEnabled then startKickLoop() end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if kickEnabled then stopKickLoop() end
    for target in pairs(hoveringTargets) do stopHover(target) end
    stopAllHeldHovers()
    oldDisable()
end
