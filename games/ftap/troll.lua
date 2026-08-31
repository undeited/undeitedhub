local WindUI = undeltedhub.WindUI
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
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

local TrollTab = undeltedhub.Window:Tab({ Title = "Troll" })

TrollTab:Button({
    Title = "Spawn Missile",
    Callback = function()
        if _G.bombInProgress then
            SafeNotify({ Title = "Troll", Content = "A missile spawn is already in progress", Duration = 2 })
            return
        end

        _G.bombInProgress = true

        local oldError = error
        error = function(msg, level)
            if type(msg) == "string" and msg:find("attempt to index nil with 'Touched'") then
                return
            end
            oldError(msg, level)
        end

        if seterrorhandler then
            local oldHandler = errorhandler or function() end
            seterrorhandler(function(err, level)
                if type(err) == "string" and err:find("attempt to index nil with 'Touched'") then
                    return
                end
                oldHandler(err, level)
            end)
        end

        local function run()
            local Players = game:GetService("Players")
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local player = Players.LocalPlayer
            if not player then return end

            local character = player.Character or player.CharacterAdded:Wait()
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if not rootPart then return end

            local SpawnRemote = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction
            local ExplodeRemote = ReplicatedStorage.BombEvents.BombExplode
            local BombReplicator = ReplicatedStorage.BombEvents.BombReplicator
            local SetNetworkOwner = ReplicatedStorage.GrabEvents.SetNetworkOwner

            local function getBombsInPlayerFolder()
                local folder = workspace:FindFirstChild(player.Name .. "SpawnedInToys")
                if not folder then return {} end
                local bombs = {}
                for _, child in ipairs(folder:GetChildren()) do
                    if child:IsA("Model") and string.match(child.Name, "^BombMissile") then
                        if child:FindFirstChild("PartHitDetector", true) and child:FindFirstChild("Body", true) then
                            table.insert(bombs, child)
                        end
                    end
                end
                return bombs
            end

            local existingBombs = getBombsInPlayerFolder()

            local spawnResult = SpawnRemote:InvokeServer(
                "BombMissile",
                rootPart.CFrame,
                rootPart.Orientation or Vector3.new()
            )
            if spawnResult ~= "SpawnedToy" then return end

            local bombModel = nil
            local start = tick()
            repeat
                local currentBombs = getBombsInPlayerFolder()
                for _, bomb in ipairs(currentBombs) do
                    local isNew = true
                    for _, existing in ipairs(existingBombs) do
                        if bomb == existing then
                            isNew = false
                            break
                        end
                    end
                    if isNew then
                        bombModel = bomb
                        break
                    end
                end
                if bombModel then break end
                task.wait(0.05)
            until tick() - start > 4.0

            if not bombModel then return end

            local hitbox = bombModel:FindFirstChild("PartHitDetector", true)
            local body = bombModel:FindFirstChild("Body", true)
            if not hitbox or not body then return end

            local settleStart = tick()
            repeat
                local vel = body.AssemblyLinearVelocity
                if vel and vel.Magnitude < 1 then break end
                task.wait(0.1)
            until tick() - settleStart > 3.0

            pcall(function()
                SetNetworkOwner:FireServer(body, body.CFrame)
            end)
            task.wait(0.3)

            pcall(function() BombReplicator:FireServer() end)
            task.wait(0.2)
            pcall(function() BombReplicator:FireServer() end)
            task.wait(2.0)

            local explosionData = {
                Radius = 17.5,
                TimeLength = 0.5,
                Hitbox = hitbox,
                ExplodesByFire = true,
                MaxForcePerStudSquared = 225,
                Model = bombModel,
                ImpactSpeed = 100,
                ExplodesByPointy = false,
                DestroysModel = true,
                PositionPart = body
            }

            for attempt = 1, 7 do
                pcall(function()
                    ExplodeRemote:FireServer(explosionData, body.Position)
                end)
                task.wait(1.0)
                if not bombModel.Parent then break end
                if attempt < 7 then task.wait(0.5) end
            end

            task.wait(0.3)
        end

        pcall(run)
        _G.bombInProgress = false
    end
})

local grabEnabled = undeltedhub.Toggles.autoGrabPlayers or false
local grabTask = nil

local INTERACT_KEY = Enum.KeyCode.F
local PROXIMITY_RANGE = 20
local CHECK_DELAY = 0.3

local leftHeldTarget = nil
local rightHeldTarget = nil

local function manageBlobmanSeating(toyFolder)
    local char = LocalPlayer.Character
    if not char then
        return nil
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then
        return nil
    end

    if hum.SeatPart and hum.SeatPart.Name == "VehicleSeat" and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
        return hum.SeatPart.Parent
    end

    if toyFolder then
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
    end

    return nil
end

local function getSortedNearbyPlayers(blobmanModel)
    local rootPart = blobmanModel:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return {}
    end

    local pivotPoint = rootPart.Position
    local nearbyList = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
            local targetHum = player.Character:FindFirstChildOfClass("Humanoid")

            if targetRoot and targetHum and targetHum.Health > 0 and not player.Character:FindFirstChildOfClass("ForceField") then
                local distance = (pivotPoint - targetRoot.Position).Magnitude
                if distance < PROXIMITY_RANGE then
                    table.insert(nearbyList, {Player = player.Character, Distance = distance})
                end
            end
        end
    end

    table.sort(nearbyList, function(a, b)
        return a.Distance < b.Distance
    end)

    local finalTargets = {}
    for _, item in ipairs(nearbyList) do
        table.insert(finalTargets, item.Player)
    end
    return finalTargets
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
                local toyFolderName = LocalPlayer.Name .. "SpawnedInToys"
                local toyFolder = Workspace:FindFirstChild(toyFolderName)

                local blobman = manageBlobmanSeating(toyFolder)

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
                            if leftWeld.Attachment0 == nil or not leftWeld.Attachment0:IsDescendantOf(leftHeldTarget) or (leftHum and leftHum.Health <= 0) or not leftHeldTarget.Parent then
                                leftHeldTarget = nil
                            end
                        end

                        if rightHeldTarget then
                            local rightHum = rightHeldTarget:FindFirstChildOfClass("Humanoid")
                            if rightWeld.Attachment0 == nil or not rightWeld.Attachment0:IsDescendantOf(rightHeldTarget) or (rightHum and rightHum.Health <= 0) or not rightHeldTarget.Parent then
                                rightHeldTarget = nil
                            end
                        end

                        if not leftHeldTarget or not rightHeldTarget then
                            local targets = getSortedNearbyPlayers(blobman)

                            for _, victim in ipairs(targets) do
                                if victim ~= leftHeldTarget and victim ~= rightHeldTarget then
                                    local victimRoot = victim:FindFirstChild("HumanoidRootPart")
                                    local victimHum = victim:FindFirstChildOfClass("Humanoid")

                                    if victimRoot and victimHum and victimHum.Health > 0 and victim.Parent then
                                        if not leftHeldTarget and leftDetector then
                                            leftHeldTarget = victim

                                            victimRoot.CFrame = leftDetector.CFrame
                                            victimRoot.Velocity = Vector3.new(0, 0, 0)
                                            task.wait(0.08)

                                            if victimHum.Health > 0 and victim.Parent then
                                                creatureGrab:FireServer(victim, victimRoot, leftWeld)
                                            else
                                                leftHeldTarget = nil
                                            end
                                            task.wait(0.12)

                                        elseif not rightHeldTarget and rightDetector then
                                            rightHeldTarget = victim

                                            victimRoot.CFrame = rightDetector.CFrame
                                            victimRoot.Velocity = Vector3.new(0, 0, 0)
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

                                if leftHeldTarget and rightHeldTarget then
                                    break
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

TrollTab:Toggle({
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