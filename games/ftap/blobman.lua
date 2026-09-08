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
local grabTask = nil
local autoSitTask = nil

local INTERACT_KEY = Enum.KeyCode.F
local PROXIMITY_RANGE = 20
local CHECK_DELAY = 0.5

local leftHeldTarget = nil
local rightHeldTarget = nil
local toyFolder = nil

local function updateToyFolder()
    toyFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
end
updateToyFolder()
Workspace.DescendantAdded:Connect(function(child)
    if child.Name == LocalPlayer.Name .. "SpawnedInToys" then
        toyFolder = child
    end
end)

local function getPlayerCharacter()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
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

local function countBlobmen()
    local folder = getToysFolder()
    if not folder then return 0 end
    local count = 0
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == "CreatureBlobman" and child:IsA("Model") then
            count = count + 1
        end
    end
    return count
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

local function getNearestUnheldPlayer(blobmanModel, excludeLeft, excludeRight)
    local rootPart = blobmanModel:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local pivotPoint = rootPart.Position
    local best = nil
    local bestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local targetRoot = char:FindFirstChild("HumanoidRootPart")
        local targetHum = char:FindFirstChildOfClass("Humanoid")
        if not targetRoot or not targetHum or targetHum.Health <= 0 then continue end
        if char:FindFirstChildOfClass("ForceField") then continue end
        if char == excludeLeft or char == excludeRight then continue end

        local dist = (pivotPoint - targetRoot.Position).Magnitude
        if dist < PROXIMITY_RANGE and dist < bestDist then
            best = char
            bestDist = dist
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

local function getSeatedBlobman()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    if hum.SeatPart and hum.SeatPart.Name == "VehicleSeat" and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
        return hum.SeatPart.Parent
    end
    return nil
end

local function sitOnBlobman()
    local char = LocalPlayer.Character
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

local function startGrabLoop()
    if grabTask then return end
    grabEnabled = true
    undeitedhub.Toggles.autoGrabPlayers = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Grab Nearest", Content = "Enabled", Duration = 2 })

    grabTask = task.spawn(function()
        while grabEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local blobman = getSeatedBlobman()
                if blobman then
                    local leftDetector = blobman:FindFirstChild("LeftDetector")
                    local rightDetector = blobman:FindFirstChild("RightDetector")
                    local leftWeld = leftDetector and leftDetector:FindFirstChild("LeftWeld")
                    local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
                    local ownerScript = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
                    local creatureGrab = ownerScript and ownerScript:FindFirstChild("CreatureGrab")

                    if leftWeld and rightWeld and creatureGrab then
                        if leftHeldTarget then
                            local leftHum = leftHeldTarget:FindFirstChildOfClass("Humanoid")
                            if not leftWeld.Attachment0 or not leftWeld.Attachment0:IsDescendantOf(leftHeldTarget) or (leftHum and leftHum.Health <= 0) or not leftHeldTarget.Parent then
                                leftHeldTarget = nil
                            end
                        end
                        if rightHeldTarget then
                            local rightHum = rightHeldTarget:FindFirstChildOfClass("Humanoid")
                            if not rightWeld.Attachment0 or not rightWeld.Attachment0:IsDescendantOf(rightHeldTarget) or (rightHum and rightHum.Health <= 0) or not rightHeldTarget.Parent then
                                rightHeldTarget = nil
                            end
                        end

                        if not leftHeldTarget then
                            local victim = getNearestUnheldPlayer(blobman, nil, rightHeldTarget)
                            if victim then
                                local victimRoot = victim:FindFirstChild("HumanoidRootPart")
                                local victimHum = victim:FindFirstChildOfClass("Humanoid")
                                if victimRoot and victimHum and victimHum.Health > 0 and victim.Parent then
                                    leftHeldTarget = victim
                                    victimRoot.CFrame = leftDetector.CFrame
                                    victimRoot.Velocity = Vector3.new(0,0,0)
                                    task.wait(0.08)
                                    if victimHum.Health > 0 and victim.Parent then
                                        creatureGrab:FireServer(victim, victimRoot, leftWeld)
                                        playGrabAnimation(blobman, "left")
                                    else
                                        leftHeldTarget = nil
                                    end
                                    task.wait(0.12)
                                end
                            end
                        end

                        if not rightHeldTarget then
                            local victim = getNearestUnheldPlayer(blobman, leftHeldTarget, nil)
                            if victim then
                                local victimRoot = victim:FindFirstChild("HumanoidRootPart")
                                local victimHum = victim:FindFirstChildOfClass("Humanoid")
                                if victimRoot and victimHum and victimHum.Health > 0 and victim.Parent then
                                    rightHeldTarget = victim
                                    victimRoot.CFrame = rightDetector.CFrame
                                    victimRoot.Velocity = Vector3.new(0,0,0)
                                    task.wait(0.08)
                                    if victimHum.Health > 0 and victim.Parent then
                                        creatureGrab:FireServer(victim, victimRoot, rightWeld)
                                        playGrabAnimation(blobman, "right")
                                    else
                                        rightHeldTarget = nil
                                    end
                                    task.wait(0.12)
                                end
                            end
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
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local seated = hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman"
                        if not seated then
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

-- Kick function
local function kickNearestPlayer()
    local blobman = getSeatedBlobman()
    if not blobman then
        SafeNotify({ Title = "Kick", Content = "You are not seated on a blobman", Duration = 2 })
        return
    end

    local leftDetector = blobman:FindFirstChild("LeftDetector")
    local rightDetector = blobman:FindFirstChild("RightDetector")
    local leftWeld = leftDetector and leftDetector:FindFirstChild("LeftWeld")
    local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
    local ownerScript = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
    local creatureGrab = ownerScript and ownerScript:FindFirstChild("CreatureGrab")
    local creatureDrop = ownerScript and ownerScript:FindFirstChild("CreatureDrop")

    if not leftWeld or not rightWeld or not creatureGrab or not creatureDrop then
        SafeNotify({ Title = "Kick", Content = "Missing blobman components", Duration = 2 })
        return
    end

    local victim = getNearestUnheldPlayer(blobman, leftHeldTarget, rightHeldTarget)
    if not victim then
        SafeNotify({ Title = "Kick", Content = "No nearby unheld player found", Duration = 2 })
        return
    end

    local victimRoot = victim:FindFirstChild("HumanoidRootPart")
    local victimHum = victim:FindFirstChildOfClass("Humanoid")
    if not victimRoot or not victimHum or victimHum.Health <= 0 then
        SafeNotify({ Title = "Kick", Content = "Invalid target", Duration = 2 })
        return
    end

    local grabState = grabEnabled
    if grabState then stopGrabLoop() end

    local targetWeld, detector
    if not leftHeldTarget then
        targetWeld = leftWeld
        detector = leftDetector
    elseif not rightHeldTarget then
        targetWeld = rightWeld
        detector = rightDetector
    else
        SafeNotify({ Title = "Kick", Content = "Both hands are full", Duration = 2 })
        if grabState then startGrabLoop() end
        return
    end

    victimRoot.CFrame = detector.CFrame
    victimRoot.Velocity = Vector3.new(0,0,0)
    task.wait(0.08)
    creatureGrab:FireServer(victim, victimRoot, targetWeld)
    task.wait(0.2)

    local vel = Vector3.new(0, 150, 0)
    victimRoot.Velocity = vel
    creatureDrop:FireServer(targetWeld, victimRoot)
    task.wait(0.1)

    if targetWeld == leftWeld then leftHeldTarget = nil else rightHeldTarget = nil end

    SafeNotify({ Title = "Kick", Content = "Kicked " .. victim.Parent.Name, Duration = 2 })
    if grabState then startGrabLoop() end
end

-- Bring function
local function bringNearestPlayer()
    local blobman = getSeatedBlobman()
    if not blobman then
        SafeNotify({ Title = "Bring", Content = "You are not seated on a blobman", Duration = 2 })
        return
    end

    local leftDetector = blobman:FindFirstChild("LeftDetector")
    local rightDetector = blobman:FindFirstChild("RightDetector")
    local leftWeld = leftDetector and leftDetector:FindFirstChild("LeftWeld")
    local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
    local ownerScript = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
    local creatureGrab = ownerScript and ownerScript:FindFirstChild("CreatureGrab")
    local creatureDrop = ownerScript and ownerScript:FindFirstChild("CreatureDrop")

    if not leftWeld or not rightWeld or not creatureGrab or not creatureDrop then
        SafeNotify({ Title = "Bring", Content = "Missing blobman components", Duration = 2 })
        return
    end

    local victim = getNearestUnheldPlayer(blobman, leftHeldTarget, rightHeldTarget)
    if not victim then
        SafeNotify({ Title = "Bring", Content = "No nearby unheld player found", Duration = 2 })
        return
    end

    local victimRoot = victim:FindFirstChild("HumanoidRootPart")
    local victimHum = victim:FindFirstChildOfClass("Humanoid")
    if not victimRoot or not victimHum or victimHum.Health <= 0 then
        SafeNotify({ Title = "Bring", Content = "Invalid target", Duration = 2 })
        return
    end

    local grabState = grabEnabled
    if grabState then stopGrabLoop() end

    local targetWeld, detector
    if not leftHeldTarget then
        targetWeld = leftWeld
        detector = leftDetector
    elseif not rightHeldTarget then
        targetWeld = rightWeld
        detector = rightDetector
    else
        SafeNotify({ Title = "Bring", Content = "Both hands are full", Duration = 2 })
        if grabState then startGrabLoop() end
        return
    end

    victimRoot.CFrame = detector.CFrame
    victimRoot.Velocity = Vector3.new(0,0,0)
    task.wait(0.08)
    creatureGrab:FireServer(victim, victimRoot, targetWeld)
    task.wait(0.2)

    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    if localRoot then
        victimRoot.CFrame = localRoot.CFrame + Vector3.new(0, 2, 0) -- teleport to your position
    end

    creatureDrop:FireServer(targetWeld, victimRoot)
    task.wait(0.1)

    if targetWeld == leftWeld then leftHeldTarget = nil else rightHeldTarget = nil end

    SafeNotify({ Title = "Bring", Content = "Brought " .. victim.Parent.Name .. " to you", Duration = 2 })
    if grabState then startGrabLoop() end
end

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

BlobmanTab:Button({
    Title = "Kick Nearest Player",
    Callback = function()
        pcall(kickNearestPlayer)
    end
})

BlobmanTab:Button({
    Title = "Bring Nearest Player",
    Callback = function()
        pcall(bringNearestPlayer)
    end
})

if grabEnabled then startGrabLoop() end
if autoSitEnabled then startAutoSit() end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if grabEnabled then stopGrabLoop() end
    if autoSitEnabled then stopAutoSit() end
    oldDisable()
end