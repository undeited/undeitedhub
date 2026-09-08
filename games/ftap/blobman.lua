local WindUI = undeitedhub.WindUI
local BlobmanTab = undeitedhub.Window:Tab({ Title = "Blobman" })

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
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local grabEnabled = undeitedhub.Toggles.autoGrabPlayers or false
local autoSitEnabled = undeitedhub.Toggles.autoSit or false
local autoKickEnabled = undeitedhub.Toggles.autoKickPlayer or false
local grabTask = nil
local autoSitTask = nil
local autoKickTask = nil

local INTERACT_KEY = Enum.KeyCode.F
local PROXIMITY_RANGE = 20
local CHECK_DELAY = 0.5
local KICK_INTERVAL = 0.3
local KICK_STRENGTH = 1000
local OWNERSHIP_TIMEOUT = 1.0

local leftHeldTarget = nil
local rightHeldTarget = nil
local selectedBringPlayer = nil
local selectedKickPlayer = nil
local bringDropdown = nil
local kickDropdown = nil

local grabbedCooldown = {}

local function isPlayerValid(player)
    if not player then return false end
    if not player.Character then return false end
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function isPlayerInPlot(player)
    if not player or not player.Character then return false end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return false end
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") and root:IsDescendantOf(plot) then
            return true
        end
    end
    return false
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
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        return LocalPlayer.Character
    end
    return nil
end

local function getPlayerCFrame()
    local char = getPlayerCharacter()
    if char then return char.HumanoidRootPart.CFrame end
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
    if not cframe then return end
    local spawnRemote = ReplicatedStorage:FindFirstChild("MenuToys")
    if spawnRemote then
        spawnRemote = spawnRemote:FindFirstChild("SpawnToyRemoteFunction")
    end
    if spawnRemote then
        pcall(function()
            spawnRemote:InvokeServer("CreatureBlobman", cframe, Vector3.new(0, 97.69000244140625, 0))
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

local function setNetworkOwner(part)
    if not part then return end
    local remote = ReplicatedStorage:FindFirstChild("GrabEvents")
    if remote then
        remote = remote:FindFirstChild("SetNetworkOwner")
    end
    if remote then
        local char = getPlayerCharacter()
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function()
                remote:FireServer(part, CFrame.lookAt(root.Position, part.Position))
            end)
        end
    else
        SafeNotify({ Title = "Error", Content = "SetNetworkOwner remote missing", Duration = 2 })
    end
end

local function waitForOwnership(part, timeout)
    timeout = timeout or OWNERSHIP_TIMEOUT
    local start = tick()
    while tick() - start < timeout do
        local owner = part:FindFirstChild("PartOwner")
        if owner and owner.Value == LocalPlayer.Name then
            return true
        end
        task.wait(0.05)
    end
    return false
end

local function snowshipOnce(part)
    if not part then return false end
    local owner = part:FindFirstChild("PartOwner")
    if owner and owner.Value == LocalPlayer.Name then
        return true
    end
    if LocalPlayer:DistanceFromCharacter(part.Position) <= 30 then
        setNetworkOwner(part)
        return waitForOwnership(part)
    end
    return false
end

local function getSeatedBlobman()
    local char = getPlayerCharacter()
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
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
    local char = getPlayerCharacter()
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return nil end

    if getSeatedBlobman() then
        return getSeatedBlobman()
    end

    local blobman = ensureSingleBlobman()
    if not blobman then return nil end

    local seat = blobman:FindFirstChild("VehicleSeat")
    if seat and (not seat.Occupant or seat.Occupant == hum) then
        local camera = Workspace.CurrentCamera
        hrp.CFrame = seat.CFrame + Vector3.new(0, 1.5, 0)
        task.wait(0.05)
        camera.CFrame = CFrame.new(camera.CFrame.Position, seat.Position)
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

local function getNearestUnheldPlayer(blobmanModel, excludeLeft, excludeRight)
    local rootPart = blobmanModel:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    local pivot = rootPart.Position
    local best = nil
    local bestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not isPlayerValid(player) then continue end
        if player == excludeLeft or player == excludeRight then continue end
        if isPlayerInPlot(player) then continue end
        if grabbedCooldown[player] and tick() - grabbedCooldown[player] < 2 then continue end
        local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local dist = (pivot - targetRoot.Position).Magnitude
            if dist < PROXIMITY_RANGE and dist < bestDist then
                best = player
                bestDist = dist
            end
        end
    end
    return best
end

local function playGrabAnimation(blobman, side)
    if not blobman then return end
    local anims = blobman:FindFirstChild("BlobmanAnimations")
    if not anims then return end
    local relay = anims:FindFirstChild("RelayClientAnimation")
    if not relay or not relay:IsA("RemoteEvent") then return end
    local animName = side == "left" and "LeftGrabAnimation" or "RightGrabAnimation"
    pcall(function()
        relay:FireServer(animName, true)
    end)
end

local function dropHeldTarget(blobman, side)
    if not blobman then return false end
    local target = side == "left" and leftHeldTarget or rightHeldTarget
    if not target then return false end
    local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end

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
    if not blobman or not target then return false end
    if isPlayerInPlot(target) then
        SafeNotify({ Title = "Grab", Content = "Target is in a plot", Duration = 2 })
        return false
    end

    local leftDetector = blobman:FindFirstChild("LeftDetector")
    local rightDetector = blobman:FindFirstChild("RightDetector")
    local leftWeld = leftDetector and leftDetector:FindFirstChild("LeftWeld")
    local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
    local ownerScript = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
    local creatureGrab = ownerScript and ownerScript:FindFirstChild("CreatureGrab")

    if not ownerScript or not creatureGrab then
        SafeNotify({ Title = "Grab", Content = "CreatureGrab remote missing", Duration = 2 })
        return false
    end

    local detector, weld
    if hand == "left" then
        detector = leftDetector
        weld = leftWeld
    else
        detector = rightDetector
        weld = rightWeld
    end

    if not detector or not weld then
        SafeNotify({ Title = "Grab", Content = "Weld or detector missing for " .. hand, Duration = 2 })
        return false
    end

    local targetChar = target.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not targetHum or targetHum.Health <= 0 then
        return false
    end

    local owned = false
    for _ = 1, 3 do
        if snowshipOnce(targetRoot) then
            owned = true
            break
        end
        task.wait(0.1)
    end
    if not owned then
        SafeNotify({ Title = "Grab", Content = "Failed to steal ownership of target", Duration = 2 })
        return false
    end

    targetRoot.CFrame = detector.CFrame
    targetRoot.Velocity = Vector3.new(0,0,0)
    task.wait(0.08)
    pcall(function()
        creatureGrab:FireServer(target, targetRoot, weld)
    end)
    task.wait(0.15)

    if hand == "left" then
        leftHeldTarget = target
    else
        rightHeldTarget = target
    end
    grabbedCooldown[target] = tick()
    playGrabAnimation(blobman, hand)
    return true
end

local function startGrabLoop()
    if grabTask then return end
    grabEnabled = true
    undeitedhub.Toggles.autoGrabPlayers = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Grab Nearest", Content = "Enabled", Duration = 2 })

    grabTask = task.spawn(function()
        while grabEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                clearInvalidHeldTargets()
                local blobman = getSeatedBlobman()
                if blobman then
                    if not leftHeldTarget then
                        local victim = getNearestUnheldPlayer(blobman, nil, rightHeldTarget)
                        if victim then
                            pcall(grabPlayer, blobman, victim, "left")
                        end
                    end

                    if not rightHeldTarget then
                        local victim = getNearestUnheldPlayer(blobman, leftHeldTarget, nil)
                        if victim then
                            pcall(grabPlayer, blobman, victim, "right")
                        end
                    end
                else
                    leftHeldTarget = nil
                    rightHeldTarget = nil
                end
            end
            task.wait(CHECK_DELAY)
        end
        grabTask = nil
    end)
end

local function stopGrabLoop()
    grabEnabled = false
    undeitedhub.Toggles.autoGrabPlayers = false
    if grabTask then
        task.cancel(grabTask)
        grabTask = nil
    end
    leftHeldTarget = nil
    rightHeldTarget = nil
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Grab Nearest", Content = "Disabled", Duration = 2 })
end

local function startAutoSit()
    if autoSitTask then return end
    autoSitEnabled = true
    undeitedhub.Toggles.autoSit = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Sit", Content = "Enabled", Duration = 2 })

    autoSitTask = task.spawn(function()
        while autoSitEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local char = getPlayerCharacter()
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
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
    SafeNotify({ Title = "Auto Sit", Content = "Disabled", Duration = 2 })
end

local function bringSelectedPlayer()
    if not selectedBringPlayer or selectedBringPlayer == "" then
        SafeNotify({ Title = "Bring", Content = "No player selected", Duration = 2 })
        return
    end

    local target = Players:FindFirstChild(selectedBringPlayer)
    if not target then
        SafeNotify({ Title = "Bring", Content = "Player not found", Duration = 2 })
        return
    end

    if target == LocalPlayer then
        SafeNotify({ Title = "Bring", Content = "You cannot bring yourself", Duration = 2 })
        return
    end

    if not isPlayerValid(target) then
        SafeNotify({ Title = "Bring", Content = "Target is dead or invalid", Duration = 2 })
        return
    end

    if isPlayerInPlot(target) then
        SafeNotify({ Title = "Bring", Content = "Target is inside a plot", Duration = 2 })
        return
    end

    local blobman = getSeatedBlobman()
    if not blobman then
        blobman = sitOnBlobman()
        if not blobman then
            SafeNotify({ Title = "Bring", Content = "Failed to sit on blobman", Duration = 2 })
            return
        end
    end

    local grabState = grabEnabled
    if grabState then stopGrabLoop() end

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
        SafeNotify({ Title = "Bring", Content = "Both hands are full and couldn't free one", Duration = 2 })
        if grabState then startGrabLoop() end
        return
    end

    local ok, result = pcall(grabPlayer, blobman, target, hand)
    if ok and result then
        SafeNotify({ Title = "Bring", Content = "Brought " .. target.Name, Duration = 2 })
    else
        SafeNotify({ Title = "Bring", Content = "Failed to bring " .. target.Name, Duration = 2 })
    end

    if grabState then startGrabLoop() end
end

local function performKick(target)
    if not target then return false end
    if not isPlayerValid(target) then return false end
    if isPlayerInPlot(target) then return false end

    local blobman = getSeatedBlobman()
    if not blobman then
        blobman = sitOnBlobman()
        if not blobman then return false end
    end

    local leftDetector = blobman:FindFirstChild("LeftDetector")
    local rightDetector = blobman:FindFirstChild("RightDetector")
    local leftWeld = leftDetector and leftDetector:FindFirstChild("LeftWeld")
    local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
    local ownerScript = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
    local creatureGrab = ownerScript and ownerScript:FindFirstChild("CreatureGrab")
    local creatureDrop = ownerScript and ownerScript:FindFirstChild("CreatureDrop")

    if not leftWeld or not rightWeld or not creatureGrab or not creatureDrop then
        return false
    end

    clearInvalidHeldTargets()

    local hand
    if not leftHeldTarget then
        hand = "left"
    elseif not rightHeldTarget then
        hand = "right"
    else
        return false
    end

    local targetChar = target.Character
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not targetHum or targetHum.Health <= 0 then return false end

    local ok, grabbed = pcall(grabPlayer, blobman, target, hand)
    if not ok or not grabbed then
        return false
    end

    local weld = hand == "left" and leftWeld or rightWeld
    task.wait(0.15)

    targetRoot.AssemblyLinearVelocity = Vector3.new(0, KICK_STRENGTH, 0)
    task.wait(0.05)
    pcall(function()
        creatureDrop:FireServer(weld, targetRoot)
    end)

    if hand == "left" then
        leftHeldTarget = nil
    else
        rightHeldTarget = nil
    end

    return true
end

local function startAutoKick()
    if autoKickTask then return end
    autoKickEnabled = true
    undeitedhub.Toggles.autoKickPlayer = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Kick Player", Content = "Enabled", Duration = 2 })

    autoKickTask = task.spawn(function()
        while autoKickEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                if not selectedKickPlayer or selectedKickPlayer == "" then
                    task.wait(0.5)
                    continue
                end
                local target = Players:FindFirstChild(selectedKickPlayer)
                if not target then
                    task.wait(0.5)
                    continue
                end
                if target == LocalPlayer then
                    task.wait(0.5)
                    continue
                end
                if isPlayerInPlot(target) then
                    task.wait(0.5)
                    continue
                end
                if grabbedCooldown[target] and tick() - grabbedCooldown[target] < 2 then
                    task.wait(0.5)
                    continue
                end

                local grabState = grabEnabled
                if grabState then stopGrabLoop() end

                pcall(performKick, target)

                if grabState then startGrabLoop() end
            end
            task.wait(KICK_INTERVAL)
        end
        autoKickTask = nil
    end)
end

local function stopAutoKick()
    autoKickEnabled = false
    undeitedhub.Toggles.autoKickPlayer = false
    if autoKickTask then
        task.cancel(autoKickTask)
        autoKickTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Kick Player", Content = "Disabled", Duration = 2 })
end

local function refreshDropdowns()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
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
    Title = "Select Player to Auto Kick",
    Values = {},
    Value = "",
    Callback = function(value)
        selectedKickPlayer = value
    end
})

Players.PlayerAdded:Connect(refreshDropdowns)
Players.PlayerRemoving:Connect(refreshDropdowns)
refreshDropdowns()

BlobmanTab:Button({
    Title = "Bring Selected Player",
    Callback = function()
        pcall(bringSelectedPlayer)
    end
})

BlobmanTab:Toggle({
    Title = "Auto Kick Player",
    Value = autoKickEnabled,
    Callback = function(state)
        if state then startAutoKick() else stopAutoKick() end
    end
})

BlobmanTab:Toggle({
    Title = "Auto Grab Nearest",
    Value = grabEnabled,
    Callback = function(state)
        if state then startGrabLoop() else stopGrabLoop() end
    end
})

BlobmanTab:Toggle({
    Title = "Auto Sit",
    Value = autoSitEnabled,
    Callback = function(state)
        if state then startAutoSit() else stopAutoSit() end
    end
})

if grabEnabled then startGrabLoop() end
if autoSitEnabled then startAutoSit() end
if autoKickEnabled then startAutoKick() end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if grabEnabled then stopGrabLoop() end
    if autoSitEnabled then stopAutoSit() end
    if autoKickEnabled then stopAutoKick() end
    oldDisable()
end