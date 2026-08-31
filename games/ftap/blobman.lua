local WindUI = undeltedhub.WindUI
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

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

local BlobmanTab = undeltedhub.Window:Tab({ Title = "Blobman" })

local grabEnabled = undeltedhub.Toggles.autoGrabPlayers or false
local grabTask = nil

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

local function manageBlobmanSeating()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return nil end

    if hum.SeatPart and hum.SeatPart.Name == "VehicleSeat" and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
        return hum.SeatPart.Parent
    end

    if not toyFolder then return nil end

    for _, blobman in ipairs(toyFolder:GetChildren()) do
        if blobman.Name == "CreatureBlobman" then
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
        end
    end
    return nil
end

local function startGrabLoop()
    if grabTask then return end
    grabEnabled = true
    undeltedhub.Toggles.autoGrabPlayers = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Grab Nearest", Content = "Enabled", Duration = 2 })

    grabTask = task.spawn(function()
        while grabEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE then
                local blobman = manageBlobmanSeating()
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
    undeltedhub.Toggles.autoGrabPlayers = false
    if grabTask then
        task.cancel(grabTask)
        grabTask = nil
    end
    leftHeldTarget = nil
    rightHeldTarget = nil
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Grab Nearest", Content = "Disabled", Duration = 2 })
end

BlobmanTab:Toggle({
    Title = "Auto Grab Nearest",
    Value = grabEnabled,
    Callback = function(state)
        if state then startGrabLoop() else stopGrabLoop() end
    end
})

local oldDisable = undeltedhub.DisableAll or function() end
undeltedhub.DisableAll = function()
    if grabEnabled then stopGrabLoop() end
    oldDisable()
end