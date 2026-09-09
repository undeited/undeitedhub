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

local blobmanMonitorTask = nil
local BLOBMAN_VOID_Y = -100
local BLOBMAN_RESPAWN_DELAY = 0.5

local INTERACT_KEY = Enum.KeyCode.F

local leftHeldTarget = nil
local rightHeldTarget = nil
local selectedBringPlayer = nil
local bringDropdown = nil

local hoveringTargets = {}
local hoverConnections = {}

local function isPlayerInProtectedPlot(player)
    if not player or not player.Character then
        return false
    end

    local plots = Workspace:FindFirstChild("Plots")

    if not plots then
        return false
    end

    local character = player.Character

    for i = 1, 5 do
        local plot = plots:FindFirstChild("Plot" .. i)

        if plot and character:IsDescendantOf(plot) then
            return true
        end
    end

    local root = character:FindFirstChild("HumanoidRootPart")

    if not root then
        return false
    end

    for i = 1, 5 do
        local plot = plots:FindFirstChild("Plot" .. i)

        if plot then
            for _, part in ipairs(plot:GetDescendants()) do
                if part:IsA("BasePart") then
                    local relative =
                        part.CFrame:PointToObjectSpace(root.Position)

                    local halfSize = part.Size / 2

                    if math.abs(relative.X) <= halfSize.X
                        and math.abs(relative.Y) <= halfSize.Y
                        and math.abs(relative.Z) <= halfSize.Z then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function isPlayerValid(player)
    if not player then
        return false
    end

    if not player.Character then
        return false
    end

    if isPlayerInProtectedPlot(player) then
        return false
    end

    local hum = player.Character:FindFirstChildOfClass("Humanoid")

    return hum and hum.Health > 0
end

local function clearInvalidHeldTargets()
    if leftHeldTarget and not isPlayerValid(leftHeldTarget) then
        leftHeldTarget = nil
    end

    if rightHeldTarget and not isPlayerValid(rightHeldTarget) then
        rightHeldTarget = nil
    end
end

local function getPlayerCharacter()
    if LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        return LocalPlayer.Character
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

local function getToysFolder()
    return Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
end

local function getBlobmen()
    local folder = getToysFolder()

    if not folder then
        return {}
    end

    local blobmen = {}

    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == "CreatureBlobman" and child:IsA("Model") then
            table.insert(blobmen, child)
        end
    end

    return blobmen
end

local function deleteToy(toy)
    if not toy then
        return
    end

    local remote = ReplicatedStorage:FindFirstChild("MenuToys")

    if remote then
        remote = remote:FindFirstChild("DestroyToy")
    end

    if remote then
        pcall(function()
            remote:FireServer(toy)
        end)
    end
end

local function spawnBlobman()
    local cframe = getPlayerCFrame()

    if not cframe then
        return
    end

    local spawnRemote = ReplicatedStorage:FindFirstChild("MenuToys")

    if spawnRemote then
        spawnRemote = spawnRemote:FindFirstChild("SpawnToyRemoteFunction")
    end

    if spawnRemote then
        pcall(function()
            spawnRemote:InvokeServer(
                "CreatureBlobman",
                cframe,
                Vector3.new(0, 97.69000244140625, 0)
            )
        end)
    end

    local buyRemote = ReplicatedStorage:FindFirstChild("MenuToys")

    if buyRemote then
        buyRemote = buyRemote:FindFirstChild("BuyToyRemoteFunction")
    end

    if buyRemote then
        pcall(function()
            buyRemote:InvokeServer("CreatureBlobman")
        end)
    end
end

local function ensureSingleBlobman()
    local blobmen = getBlobmen()
    local count = #blobmen

    if count == 0 then
        spawnBlobman()

        task.wait(0.5)

        blobmen = getBlobmen()
        count = #blobmen
    end

    if count > 1 then
        for i = 2, count do
            deleteToy(blobmen[i])
        end

        task.wait(0.2)
    end

    return getBlobmen()[1]
end

local function startBlobmanMonitor()
    if blobmanMonitorTask then
        return
    end

    blobmanMonitorTask = task.spawn(function()
        while true do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local blobmen = getBlobmen()

                if #blobmen == 0 then
                    spawnBlobman()
                    task.wait(0.5)
                else
                    local blobman = blobmen[1]

                    local primary =
                        blobman.PrimaryPart
                        or blobman:FindFirstChild("HumanoidRootPart")
                        or blobman:FindFirstChild("VehicleSeat")

                    if primary and primary.Position.Y <= BLOBMAN_VOID_Y then
                        deleteToy(blobman)

                        task.wait(BLOBMAN_RESPAWN_DELAY)

                        if #getBlobmen() == 0 then
                            spawnBlobman()
                            task.wait(0.5)
                        end
                    elseif #blobmen > 1 then
                        for i = 2, #blobmen do
                            deleteToy(blobmen[i])
                        end
                    end
                end
            end

            task.wait(0.25)
        end
    end)
end

local function deleteOccupiedBlobmen()
    local folder = getToysFolder()

    if not folder then
        return
    end

    local myHum = LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

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
    if not part then
        return
    end

    local remote = ReplicatedStorage:FindFirstChild("GrabEvents")

    if remote then
        remote = remote:FindFirstChild("SetNetworkOwner")
    end

    if remote then
        local char = getPlayerCharacter()
        local root = char and char:FindFirstChild("HumanoidRootPart")

        if root then
            pcall(function()
                remote:FireServer(
                    part,
                    CFrame.lookAt(root.Position, part.Position)
                )
            end)
        end
    end
end

local function snowshipOnce(part)
    if not part then
        return false
    end

    local owner = part:FindFirstChild("PartOwner")

    if owner and owner.Value == LocalPlayer.Name then
        return true
    end

    if LocalPlayer:DistanceFromCharacter(part.Position) <= 30 then
        setNetworkOwner(part)
        return true
    end

    return false
end

local function getSeatedBlobman()
    local char = getPlayerCharacter()

    if not char then
        return nil
    end

    local hum = char:FindFirstChildOfClass("Humanoid")

    if not hum or hum.Health <= 0 then
        return nil
    end

    if hum.SeatPart
        and hum.SeatPart.Parent
        and hum.SeatPart.Parent.Name == "CreatureBlobman" then
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
    local char = getPlayerCharacter()

    if not char then
        return nil
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    if not hum or not hrp or hum.Health <= 0 then
        return nil
    end

    local seated = getSeatedBlobman()

    if seated then
        return seated
    end

    local blobman = ensureSingleBlobman()

    if not blobman then
        return nil
    end

    local seat = blobman:FindFirstChild("VehicleSeat")

    if seat and (not seat.Occupant or seat.Occupant == hum) then
        local camera = Workspace.CurrentCamera

        hrp.CFrame = seat.CFrame + Vector3.new(0, 1.5, 0)

        task.wait(0.05)

        if camera then
            camera.CFrame = CFrame.new(
                camera.CFrame.Position,
                seat.Position
            )
        end

        task.wait(0.05)

        VirtualInputManager:SendKeyEvent(
            true,
            INTERACT_KEY,
            false,
            game
        )

        task.wait(0.05)

        VirtualInputManager:SendKeyEvent(
            false,
            INTERACT_KEY,
            false,
            game
        )

        task.wait(0.3)

        if hum.SeatPart and hum.SeatPart.Parent == blobman then
            return blobman
        end
    end

    return nil
end

local function playGrabAnimation(blobman, side)
    if not blobman then
        return
    end

    local anims = blobman:FindFirstChild("BlobmanAnimations")

    if not anims then
        return
    end

    local relay = anims:FindFirstChild("RelayClientAnimation")

    if not relay or not relay:IsA("RemoteEvent") then
        return
    end

    local animName =
        side == "left"
        and "LeftGrabAnimation"
        or "RightGrabAnimation"

    pcall(function()
        relay:FireServer(animName, true)
    end)
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
    if not target or not blobman then
        return
    end

    stopHover(target)

    hoveringTargets[target] = true

    hoverConnections[target] = RunService.Heartbeat:Connect(function()
        if not hoveringTargets[target] then
            stopHover(target)
            return
        end

        if not isPlayerValid(target) then
            stopHover(target)
            return
        end

        if not blobman or not blobman.Parent then
            stopHover(target)
            return
        end

        local targetCharacter = target.Character

        local targetRoot =
            targetCharacter
            and targetCharacter:FindFirstChild("HumanoidRootPart")

        local blobmanRoot =
            blobman:FindFirstChild("HumanoidRootPart")
            or blobman.PrimaryPart
            or blobman:FindFirstChild("VehicleSeat")

        if not targetRoot or not blobmanRoot then
            return
        end

        targetRoot.CFrame =
            blobmanRoot.CFrame * CFrame.new(0, 30, 0)

        targetRoot.AssemblyLinearVelocity = Vector3.zero
        targetRoot.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function dropHeldTarget(blobman, side)
    if not blobman then
        return false
    end

    local target =
        side == "left"
        and leftHeldTarget
        or rightHeldTarget

    if not target then
        return false
    end

    stopHover(target)

    local root = target.Character
        and target.Character:FindFirstChild("HumanoidRootPart")

    if not root then
        if side == "left" then
            leftHeldTarget = nil
        else
            rightHeldTarget = nil
        end

        return false
    end

    local leftDetector = blobman:FindFirstChild("LeftDetector")
    local rightDetector = blobman:FindFirstChild("RightDetector")

    local leftWeld =
        leftDetector
        and leftDetector:FindFirstChild("LeftWeld")

    local rightWeld =
        rightDetector
        and rightDetector:FindFirstChild("RightWeld")

    local ownerScript =
        blobman:FindFirstChild("BlobmanSeatAndOwnerScript")

    local creatureDrop =
        ownerScript
        and ownerScript:FindFirstChild("CreatureDrop")

    local weld =
        side == "left"
        and leftWeld
        or rightWeld

    if creatureDrop and weld then
        pcall(function()
            creatureDrop:FireServer(weld, root)
        end)

        if side == "left" then
            leftHeldTarget = nil
        else
            rightHeldTarget = nil
        end

        return true
    end

    return false
end

local function grabPlayer(blobman, target, hand)
    if not blobman or not target then
        return false
    end

    if isPlayerInProtectedPlot(target) then
        return false
    end

    local leftDetector = blobman:FindFirstChild("LeftDetector")
    local rightDetector = blobman:FindFirstChild("RightDetector")

    local leftWeld =
        leftDetector
        and leftDetector:FindFirstChild("LeftWeld")

    local rightWeld =
        rightDetector
        and rightDetector:FindFirstChild("RightWeld")

    local ownerScript =
        blobman:FindFirstChild("BlobmanSeatAndOwnerScript")

    local creatureGrab =
        ownerScript
        and ownerScript:FindFirstChild("CreatureGrab")

    local detector
    local weld

    if hand == "left" then
        detector = leftDetector
        weld = leftWeld
    else
        detector = rightDetector
        weld = rightWeld
    end

    if not detector or not weld or not creatureGrab then
        return false
    end

    local targetChar = target.Character

    local targetRoot =
        targetChar
        and targetChar:FindFirstChild("HumanoidRootPart")

    local targetHum =
        targetChar
        and targetChar:FindFirstChildOfClass("Humanoid")

    if not targetRoot or not targetHum or targetHum.Health <= 0 then
        return false
    end

    local success = false

    for i = 1, 3 do
        if isPlayerInProtectedPlot(target) then
            return false
        end

        if snowshipOnce(targetRoot) then
            success = true
            break
        end

        task.wait(0.1)
    end

    if not success then
        return false
    end

    if isPlayerInProtectedPlot(target) then
        return false
    end

    targetRoot.CFrame = detector.CFrame
    targetRoot.AssemblyLinearVelocity = Vector3.zero
    targetRoot.AssemblyAngularVelocity = Vector3.zero

    task.wait(0.08)

    local grabSuccess = pcall(function()
        creatureGrab:FireServer(target, targetRoot, weld)
    end)

    if not grabSuccess then
        return false
    end

    task.wait(0.15)

    if hand == "left" then
        leftHeldTarget = target
    else
        rightHeldTarget = target
    end

    playGrabAnimation(blobman, hand)

    return true
end

local function startAutoSit()
    if autoSitTask then
        return
    end

    autoSitEnabled = true
    undeitedhub.Toggles.autoSit = true

    if undeitedhub.SaveSettings then
        undeitedhub.SaveSettings()
    end

    autoSitTask = task.spawn(function()
        while autoSitEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(deleteOccupiedBlobmen)

                local char = getPlayerCharacter()

                if char then
                    local hum =
                        char:FindFirstChildOfClass("Humanoid")

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

    if undeitedhub.SaveSettings then
        undeitedhub.SaveSettings()
    end
end

local function isPlayerHeld(player)
    return leftHeldTarget == player
        or rightHeldTarget == player
end

local function kickPlayer(target)
    if not target or target == LocalPlayer then
        return
    end

    if not isPlayerValid(target) then
        return
    end

    local blobman = getSeatedBlobman()

    if not blobman then
        blobman = sitOnBlobman()

        if not blobman then
            return
        end
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

    local localChar = getPlayerCharacter()

    if not localChar then
        return
    end

    local localRoot =
        localChar:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return
    end

    local targetChar = target.Character

    local targetRoot =
        targetChar
        and targetChar:FindFirstChild("HumanoidRootPart")

    if not targetRoot then
        return
    end

    if isPlayerInProtectedPlot(target) then
        return
    end

    local originalPos = localRoot.CFrame

    local targetPos =
        targetRoot.CFrame + Vector3.new(0, 3, 0)

    localRoot.CFrame = targetPos

    task.wait(0.2)

    if not getSeatedBlobman() then
        sitOnBlobman()
        task.wait(0.3)
    end

    local success = false

    for i = 1, 3 do
        if isPlayerInProtectedPlot(target) then
            break
        end

        local callSuccess, result = pcall(function()
            return grabPlayer(blobman, target, hand)
        end)

        if callSuccess and result then
            success = true
            break
        end

        task.wait(0.2)
    end

    localRoot.CFrame = originalPos

    task.wait(0.1)

    if not success then
        return
    end

    if isPlayerInProtectedPlot(target) then
        dropHeldTarget(blobman, hand)
        return
    end

    startHover(target, blobman)
end

local function kickLoop()
    while kickEnabled do
        if _G.UNDEITEDHUB_WINDOW_VISIBLE then
            if selectedKickPlayer and selectedKickPlayer ~= "" then
                local target =
                    Players:FindFirstChild(selectedKickPlayer)

                if target
                    and target ~= LocalPlayer
                    and isPlayerValid(target) then

                    pcall(kickPlayer, target)
                end
            end
        end

        task.wait(0.5)
    end
end

local function startKickLoop()
    if kickTask then
        return
    end

    kickEnabled = true
    undeitedhub.Toggles.kickPlayer = true

    if undeitedhub.SaveSettings then
        undeitedhub.SaveSettings()
    end

    kickTask = task.spawn(kickLoop)
end

local function stopKickLoop()
    kickEnabled = false
    undeitedhub.Toggles.kickPlayer = false

    if kickTask then
        task.cancel(kickTask)
        kickTask = nil
    end

    for target in pairs(hoveringTargets) do
        stopHover(target)
    end

    local blobman = getSeatedBlobman()

    if blobman then
        if leftHeldTarget then
            dropHeldTarget(blobman, "left")
        end

        if rightHeldTarget then
            dropHeldTarget(blobman, "right")
        end
    end

    if undeitedhub.SaveSettings then
        undeitedhub.SaveSettings()
    end
end

local function bringPlayer(target, dropAfter)
    if not target or target == LocalPlayer then
        return
    end

    if not isPlayerValid(target) then
        return
    end

    local blobman = getSeatedBlobman()

    if not blobman then
        blobman = sitOnBlobman()

        if not blobman then
            return
        end
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

    local localChar = getPlayerCharacter()

    if not localChar then
        return
    end

    local localRoot =
        localChar:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return
    end

    local targetChar = target.Character

    local targetRoot =
        targetChar
        and targetChar:FindFirstChild("HumanoidRootPart")

    if not targetRoot then
        return
    end

    if isPlayerInProtectedPlot(target) then
        return
    end

    local originalPos = localRoot.CFrame

    local targetPos =
        targetRoot.CFrame + Vector3.new(0, 3, 0)

    localRoot.CFrame = targetPos

    task.wait(0.2)

    if not getSeatedBlobman() then
        sitOnBlobman()
        task.wait(0.3)
    end

    local success = false

    for i = 1, 3 do
        if isPlayerInProtectedPlot(target) then
            break
        end

        local callSuccess, result = pcall(function()
            return grabPlayer(blobman, target, hand)
        end)

        if callSuccess and result then
            success = true
            break
        end

        task.wait(0.2)
    end

    localRoot.CFrame = originalPos

    task.wait(0.1)

    if success and dropAfter then
        dropHeldTarget(blobman, hand)
    end
end

local function bringSelectedPlayer()
    if not selectedBringPlayer or selectedBringPlayer == "" then
        return
    end

    local target =
        Players:FindFirstChild(selectedBringPlayer)

    if target then
        bringPlayer(target, false)
    end
end

local function bringAllPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer
            and isPlayerValid(player)
            and not isPlayerInProtectedPlot(player) then

            bringPlayer(player, true)
            task.wait(0.3)
        end
    end
end

local function refreshDropdowns()
    local names = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer
            and not isPlayerInProtectedPlot(player) then
            table.insert(names, player.Name)
        end
    end

    if bringDropdown then
        bringDropdown:Refresh(names, true)

        if not table.find(names, selectedBringPlayer) then
            selectedBringPlayer = names[1] or ""

            pcall(function()
                bringDropdown:Set(selectedBringPlayer)
            end)
        end
    end

    if kickDropdown then
        kickDropdown:Refresh(names, true)

        if not table.find(names, selectedKickPlayer) then
            selectedKickPlayer = names[1] or ""

            pcall(function()
                kickDropdown:Set(selectedKickPlayer)
            end)
        end
    end
end

bringDropdown = BlobmanTab:Dropdown({
    Title = "Select Player to Bring",
    Values = {},
    Value = "",
    Callback = function(value)
        selectedBringPlayer = value
    end
})

kickDropdown = BlobmanTab:Dropdown({
    Title = "Select Player to Kick",
    Values = {},
    Value = "",
    Callback = function(value)
        selectedKickPlayer = value
    end
})

Players.PlayerAdded:Connect(refreshDropdowns)

Players.PlayerRemoving:Connect(function(player)
    stopHover(player)
    refreshDropdowns()
end)

refreshDropdowns()

BlobmanTab:Button({
    Title = "Bring Selected Player",
    Callback = function()
        pcall(bringSelectedPlayer)
    end
})

BlobmanTab:Button({
    Title = "Bring All",
    Callback = function()
        pcall(bringAllPlayers)
    end
})

BlobmanTab:Toggle({
    Title = "Kick Player",
    Value = kickEnabled,
    Callback = function(state)
        if state then
            startKickLoop()
        else
            stopKickLoop()
        end
    end
})

BlobmanTab:Toggle({
    Title = "Auto Sit",
    Value = autoSitEnabled,
    Callback = function(state)
        if state then
            startAutoSit()
        else
            stopAutoSit()
        end
    end
})

startBlobmanMonitor()

if autoSitEnabled then
    startAutoSit()
end

if kickEnabled then
    startKickLoop()
end

local oldDisable =
    undeitedhub.DisableAll
    or function()
    end

undeitedhub.DisableAll = function()
    if autoSitEnabled then
        stopAutoSit()
    end

    if kickEnabled then
        stopKickLoop()
    end

    if blobmanMonitorTask then
        task.cancel(blobmanMonitorTask)
        blobmanMonitorTask = nil
    end

    for target in pairs(hoveringTargets) do
        stopHover(target)
    end

    oldDisable()
end
