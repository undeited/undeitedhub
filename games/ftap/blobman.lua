local WindUI = undeitedhub.WindUI
local BlobmanTab = undeitedhub.Window:Tab({ Title = "Blobman" })

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local autoSitEnabled = undeitedhub.Toggles.autoSit or false
local autoSitTask = nil

local INTERACT_KEY = Enum.KeyCode.F

local leftHeldTarget = nil
local rightHeldTarget = nil
local selectedBringPlayer = nil
local bringDropdown = nil

local function isPlayerValid(player)
    if not player then return false end
    if not player.Character then return false end
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

local function deleteOccupiedBlobmen()
    local folder = getToysFolder()
    if not folder then return end
    local myHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == "CreatureBlobman" and child:IsA("Model") then
            local seat = child:FindFirstChild("VehicleSeat")
            if seat and seat.Occupant then
                local occupant = seat.Occupant
                if occupant ~= myHum then
                    deleteToy(child)
                end
            end
        end
    end
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
    end
end

local function snowshipOnce(part)
    if not part then return false end
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

    local targetChar = target.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not targetHum or targetHum.Health <= 0 then return false end

    local success = false
    for i = 1, 3 do
        if snowshipOnce(targetRoot) then
            success = true
            break
        end
        task.wait(0.1)
    end
    if not success then return false end

    targetRoot.CFrame = detector.CFrame
    targetRoot.Velocity = Vector3.new(0,0,0)
    task.wait(0.08)
    creatureGrab:FireServer(target, targetRoot, weld)
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
    if autoSitTask then return end
    autoSitEnabled = true
    undeitedhub.Toggles.autoSit = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    autoSitTask = task.spawn(function()
        while autoSitEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(deleteOccupiedBlobmen)

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
end

local function bringPlayer(target, dropAfter)
    if not target or target == LocalPlayer then return end
    if not isPlayerValid(target) then return end

    local blobman = getSeatedBlobman()
    if not blobman then
        blobman = sitOnBlobman()
        if not blobman then return
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
    if not localChar then return end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    local targetChar = target.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local originalPos = localRoot.CFrame
    local targetPos = targetRoot.CFrame + Vector3.new(0, 3, 0)
    localRoot.CFrame = targetPos
    task.wait(0.2)

    if not getSeatedBlobman() then
        sitOnBlobman()
        task.wait(0.3)
    end

    local success = false
    for i = 1, 3 do
        success = pcall(grabPlayer, blobman, target, hand)
        if success then break end
        task.wait(0.2)
    end

    localRoot.CFrame = originalPos
    task.wait(0.1)

    if success and dropAfter then
        dropHeldTarget(blobman, hand)
    end
end

local function bringSelectedPlayer()
    if not selectedBringPlayer or selectedBringPlayer == "" then return
    local target = Players:FindFirstChild(selectedBringPlayer)
    if target then bringPlayer(target, false) end
end

local function bringAllPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            bringPlayer(player, true)
            task.wait(0.3)
        end
    end
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
end

bringDropdown = BlobmanTab:Dropdown({
    Title = "Select Player to Bring",
    Values = {},
    Value = "",
    Callback = function(value)
        selectedBringPlayer = value
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

BlobmanTab:Button({
    Title = "Bring All",
    Callback = function()
        pcall(bringAllPlayers)
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

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoSitEnabled then stopAutoSit() end
    oldDisable()
end
