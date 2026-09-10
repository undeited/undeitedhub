local WindUI = undeitedhub.WindUI
local BlobmanTab = undeitedhub.Window:Tab({ Title = "Blobman" })

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local autoSitEnabled = undeitedhub.Toggles.autoSit or false
local autoSitTask = nil

local kickEnabled = undeitedhub.Toggles.kickPlayer or false
local kickTask = nil
local selectedKickPlayer = nil
local kickDropdown = nil
local KICK_HEIGHT = 25

local INTERACT_KEY = Enum.KeyCode.F
local leftHeldTarget = nil
local rightHeldTarget = nil
local selectedBringPlayer = nil
local bringDropdown = nil
local hoveringTargets = {}
local hoverConnections = {}

local function isPlayerInProtectedPlot(player)
    if not player or not player.Character then return false end
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return false end
    local character = player.Character
    for i = 1, 5 do
        local plot = plots:FindFirstChild("Plot" .. i)
        if plot and character:IsDescendantOf(plot) then return true end
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    for i = 1, 5 do
        local plot = plots:FindFirstChild("Plot" .. i)
        if plot then
            for _, part in ipairs(plot:GetDescendants()) do
                if part:IsA("BasePart") then
                    local relative = part.CFrame:PointToObjectSpace(root.Position)
                    local halfSize = part.Size / 2
                    if math.abs(relative.X) <= halfSize.X and math.abs(relative.Y) <= halfSize.Y and math.abs(relative.Z) <= halfSize.Z then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function isPlayerValid(player)
    if not player then return false end
    if not player.Character then return false end
    if isPlayerInProtectedPlot(player) then return false end
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

local function deleteOccupiedBlobmen()
    local folder = getToysFolder()
    if not folder then return end
    local character = LocalPlayer.Character
    local myHum = character and character:FindFirstChildOfClass("Humanoid")
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == "CreatureBlobman" and child:IsA("Model") then
            local seat = child:FindFirstChild("VehicleSeat")
            if seat and seat.Occupant and seat.Occupant ~= myHum then
                deleteToy(child)
            end
        end
    end
end

local function setNetworkOwner(part)
    if not part then return end
    local grabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")
    if not grabEvents then return end
    local remote = grabEvents:FindFirstChild("SetNetworkOwner")
    if not remote then return end
    local character = getPlayerCharacter()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        pcall(function() remote:FireServer(part, CFrame.lookAt(root.Position, part.Position)) end)
    end
end

local function snowshipOnce(part)
    if not part then return false end
    local owner = part:FindFirstChild("PartOwner")
    if owner and owner.Value == LocalPlayer.Name then return true end
    if LocalPlayer:DistanceFromCharacter(part.Position) <= 30 then
        setNetworkOwner(part)
        return true
    end
    return false
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

local function dropHeldTarget(blobman, side)
    if not blobman then return false end
    local target = side == "left" and leftHeldTarget or rightHeldTarget
    if not target then return false end
    stopHover(target)
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
    if isPlayerInProtectedPlot(target) then return false end
    local leftDetector = blobman:FindFirstChild("LeftDetector")
    local rightDetector = blobman:FindFirstChild("RightDetector")
    local leftWeld = leftDetector and leftDetector:FindFirstChild("LeftWeld")
    local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
    local ownerScript = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
    local creatureGrab = ownerScript and ownerScript:FindFirstChild("CreatureGrab")
    local detector
    local weld
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
    local networkOwned = false
    for i = 1, 3 do
        if isPlayerInProtectedPlot(target) then return false end
        if snowshipOnce(targetRoot) then
            networkOwned = true
            break
        end
        task.wait(0.1)
    end
    if not networkOwned then return false end
    if isPlayerInProtectedPlot(target) then return false end
    targetRoot.CFrame = detector.CFrame
    targetRoot.AssemblyLinearVelocity = Vector3.zero
    targetRoot.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.08)
    local grabSuccess = pcall(function()
        creatureGrab:FireServer(target, targetRoot, weld)
    end)
    if not grabSuccess then return false end
    task.wait(0.15)
    if hand == "left" then leftHeldTarget = target else rightHeldTarget = target end
    playGrabAnimation(blobman, hand)
    return true
end

local function startAutoSit()
    if autoSitTask then return end
    autoSitEnabled = true
    undeitedhub.Toggles.autoSit = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    autoSitTask = task.spawn(function()
        while autoSitEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(deleteOccupiedBlobmen)
                local character = getPlayerCharacter()
                if character then
                    local hum = character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        if not getSeatedBlobman() then
                            pcall(sitOnBlobman)
                        end
                    end
                end
            end
            task.wait(1)
        end
        autoSitTask = nil
    end)
end

local function stopAutoSit()
    autoSitEnabled = false
    undeitedhub.Toggles.autoSit = false
    if autoSitTask then
        task.cancel(autoSitTask)
        autoSitTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

local function getPlayerFromDropdownValue(value)
    if not value or value == "" then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if player.DisplayName == value then return player end
            if value == player.DisplayName .. " (@)" .. player.Name .. ")" then return player end
        end
    end
    return nil
end

local function startKickLoop()
    if kickTask then return end
    kickEnabled = true
    undeitedhub.Toggles.kickPlayer = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    kickTask = task.spawn(function()
        local GE = ReplicatedStorage:FindFirstChild("GrabEvents")
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then
            kickEnabled = false
            undeitedhub.Toggles.kickPlayer = false
            if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
            return
        end

        local savedPos = myRoot.CFrame
        local dragging = false
        local grabStartTime = 0
        local target = nil

        while kickEnabled do
            if selectedKickPlayer and selectedKickPlayer ~= "" then
                target = getPlayerFromDropdownValue(selectedKickPlayer)
            else
                target = nil
            end

            if not target or not target.Parent or not target.Character then
                task.wait(0.5)
                continue
            end

            local tChar = target.Character
            local tRoot = tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar:FindFirstChild("Humanoid")
            local seat = myChar and myChar.Humanoid and myChar.Humanoid.SeatPart

            if tRoot and tHum and tHum.Health > 0 then
                tRoot.AssemblyLinearVelocity = Vector3.zero
                tRoot.Velocity = Vector3.zero

                if seat then
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
                end

                if not dragging then
                    myRoot.CFrame = tRoot.CFrame
                    if GE then
                        pcall(function()
                            tHum.PlatformStand = true
                            if GE.SetNetworkOwner then GE.SetNetworkOwner:FireServer(tRoot, myRoot.CFrame) end
                            if GE.CreateGrabLine then GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false) end
                        end)
                    end
                    if grabStartTime == 0 then grabStartTime = tick() end
                    if tick() - grabStartTime > 0.3 then
                        dragging = true
                        grabStartTime = 0
                    end
                else
                    local lockPos = savedPos * CFrame.new(0, KICK_HEIGHT, 0)
                    myRoot.CFrame = savedPos
                    tRoot.CFrame = lockPos
                    if GE then
                        pcall(function()
                            tHum.PlatformStand = true
                            if GE.SetNetworkOwner then GE.SetNetworkOwner:FireServer(tRoot, lockPos) end
                            if GE.DestroyGrabLine then GE.DestroyGrabLine:FireServer(tRoot) end
                            if GE.CreateGrabLine then GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false) end
                        end)
                    end
                end
            else
                dragging = false
                grabStartTime = 0
            end

            RunService.Heartbeat:Wait()
        end

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
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

local function bringPlayer(target, dropAfter)
    if not target or target == LocalPlayer then return end
    if not isPlayerValid(target) then return end
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
    if not targetRoot then return end
    if isPlayerInProtectedPlot(target) then return end
    local originalCFrame = localRoot.CFrame
    localRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
    task.wait(0.2)
    if not getSeatedBlobman() then
        sitOnBlobman()
        task.wait(0.3)
    end
    local success = false
    for i = 1, 3 do
        if isPlayerInProtectedPlot(target) then break end
        local callSuccess, result = pcall(function()
            return grabPlayer(blobman, target, hand)
        end)
        if callSuccess and result then
            success = true
            break
        end
        task.wait(0.2)
    end
    localRoot.CFrame = originalCFrame
    task.wait(0.1)
    if success and dropAfter then
        dropHeldTarget(blobman, hand)
    end
end

local function bringSelectedPlayer()
    if not selectedBringPlayer or selectedBringPlayer == "" then return end
    local target = getPlayerFromDropdownValue(selectedBringPlayer)
    if target then
        bringPlayer(target, false)
    end
end

local function bringAllPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isPlayerValid(player) and not isPlayerInProtectedPlot(player) then
            bringPlayer(player, true)
            task.wait(0.3)
        end
    end
end

local function getDropdownName(player)
    local duplicate = false
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer ~= LocalPlayer and otherPlayer.DisplayName == player.DisplayName then
            duplicate = true
            break
        end
    end
    if duplicate then
        return player.DisplayName .. " (@)" .. player.Name .. ")"
    end
    return player.DisplayName
end

local function refreshDropdowns()
    local displayNames = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not isPlayerInProtectedPlot(player) then
            table.insert(displayNames, getDropdownName(player))
        end
    end
    table.sort(displayNames)
    if bringDropdown then
        bringDropdown:Refresh(displayNames, true)
        if not table.find(displayNames, selectedBringPlayer) then
            selectedBringPlayer = displayNames[1] or ""
            pcall(function() bringDropdown:Set(selectedBringPlayer) end)
        end
    end
    if kickDropdown then
        kickDropdown:Refresh(displayNames, true)
        if not table.find(displayNames, selectedKickPlayer) then
            selectedKickPlayer = displayNames[1] or ""
            pcall(function() kickDropdown:Set(selectedKickPlayer) end)
        end
    end
end

bringDropdown = BlobmanTab:Dropdown({
    Title = "Select Player to Bring",
    Values = {},
    Value = "",
    Callback = function(value) selectedBringPlayer = value end
})

kickDropdown = BlobmanTab:Dropdown({
    Title = "Select Player to Kick",
    Values = {},
    Value = "",
    Callback = function(value) selectedKickPlayer = value end
})

Players.PlayerAdded:Connect(function(player)
    task.wait(0.1)
    player.CharacterAdded:Connect(function()
        task.wait(0.2)
        refreshDropdowns()
    end)
    refreshDropdowns()
end)

Players.PlayerRemoving:Connect(function(player)
    stopHover(player)
    if selectedBringPlayer == player.DisplayName or selectedBringPlayer == player.DisplayName .. " (@)" .. player.Name .. ")" then
        selectedBringPlayer = nil
    end
    if selectedKickPlayer == player.DisplayName or selectedKickPlayer == player.DisplayName .. " (@)" .. player.Name .. ")" then
        selectedKickPlayer = nil
    end
    refreshDropdowns()
end)

for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(function()
        task.wait(0.2)
        refreshDropdowns()
    end)
end

refreshDropdowns()

BlobmanTab:Button({
    Title = "Bring Selected Player",
    Callback = function() pcall(bringSelectedPlayer) end
})

BlobmanTab:Button({
    Title = "Bring All",
    Callback = function() pcall(bringAllPlayers) end
})

BlobmanTab:Toggle({
    Title = "Kick Player",
    Value = kickEnabled,
    Callback = function(state)
        if state then startKickLoop() else stopKickLoop() end
    end
})

BlobmanTab:Toggle({
    Title = "Auto Sit",
    Value = autoSitEnabled,
    Callback = function(state)
        if state then startAutoSit() else stopAutoSit() end
    end
})

if autoSitEnabled then startAutoSit() end
if kickEnabled then startKickLoop() end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoSitEnabled then stopAutoSit() end
    if kickEnabled then stopKickLoop() end
    for target in pairs(hoveringTargets) do stopHover(target) end
    oldDisable()
end
