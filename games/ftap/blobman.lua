local WindUI = undeltedhub.WindUI
local Toggles = undeltedhub.Toggles
local Config = undeltedhub.Config

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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local R = ReplicatedStorage
local SpawnToyRF = R.MenuToys.SpawnToyRemoteFunction
local DestroyToy = R.MenuToys.DestroyToy
local GrabEvents = R:WaitForChild("GrabEvents")
local SetNetworkOwner = GrabEvents:WaitForChild("SetNetworkOwner")
local DestroyGrabLine = GrabEvents:WaitForChild("DestroyGrabLine")

local function getSelectedPlayer()
    if undeltedhub.GetSelectedPlayer then
        return undeltedhub.GetSelectedPlayer()
    end
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then return pl end
    end
    return nil
end

local function getBlobman()
    local folder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if folder then
        return folder:FindFirstChild("CreatureBlobman")
    end
    return nil
end

local function spawnBlobman()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        SpawnToyRF:InvokeServer("CreatureBlobman", hrp.CFrame * CFrame.new(0, 5, 5), Vector3.zero)
    end)
    local t = tick()
    repeat task.wait(0.05) until getBlobman() or tick() - t > 3
    return getBlobman()
end

local autoSitActive = false
local autoSitTask = nil

BlobmanTab:Toggle({
    Title = "Auto Sit Blobman",
    Value = Toggles.autoSitBlobman or false,
    Callback = function(state)
        autoSitActive = state
        Toggles.autoSitBlobman = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            autoSitTask = task.spawn(function()
                while autoSitActive do
                    pcall(function()
                        local char = LocalPlayer.Character
                        local hum = char and char:FindFirstChild("Humanoid")
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        if not hum or not root then return end

                        if hum.SeatPart then
                            task.wait(0.1)
                            return
                        end

                        local blob = getBlobman()
                        if not blob then
                            blob = spawnBlobman()
                        end

                        if blob then
                            local seat = blob:FindFirstChild("VehicleSeat")
                            if seat then
                                root.CFrame = seat.CFrame * CFrame.new(0, 1, 0)
                                root.Velocity = Vector3.zero
                                pcall(function()
                                    seat:Sit(hum)
                                end)
                            end
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        else
            if autoSitTask then task.cancel(autoSitTask); autoSitTask = nil end
        end
    end
})

local blobKillActive = false
local blobKillTask = nil

BlobmanTab:Toggle({
    Title = "Blob Kill Target",
    Value = Toggles.blobKillTarget or false,
    Callback = function(state)
        blobKillActive = state
        Toggles.blobKillTarget = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            blobKillTask = task.spawn(function()
                while blobKillActive do
                    local target = getSelectedPlayer()
                    if not target or not target.Character then
                        task.wait(0.1)
                        continue
                    end
                    local tChar = target.Character
                    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                    local tHum = tChar:FindFirstChild("Humanoid")
                    if not tRoot or not tHum or tHum.Health <= 0 then
                        task.wait(0.1)
                        continue
                    end

                    local blob = getBlobman()
                    if not blob then
                        blob = spawnBlobman()
                        if not blob then
                            task.wait(0.5)
                            continue
                        end
                    end

                    local myChar = LocalPlayer.Character
                    local myHum = myChar and myChar:FindFirstChild("Humanoid")
                    if myHum and myHum.SeatPart and myHum.SeatPart.Parent == blob then
                        local rightDetector = blob:FindFirstChild("RightDetector")
                        local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
                        local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                        local creatureGrab = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
                        local creatureRelease = scriptObj and scriptObj:FindFirstChild("CreatureRelease")
                        if rightDetector and rightWeld and creatureGrab and creatureRelease then
                            pcall(function()
                                tHum:ChangeState(Enum.HumanoidStateType.Dead)
                                task.wait(0.15)
                                creatureGrab:FireServer(rightDetector, tRoot, rightWeld)
                                task.wait(0.1)
                                creatureRelease:FireServer(rightWeld, tRoot)
                            end)
                        end
                    else
                        local seat = blob:FindFirstChild("VehicleSeat")
                        if seat and myHum then
                            seat:Sit(myHum)
                            task.wait(0.3)
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            if blobKillTask then task.cancel(blobKillTask); blobKillTask = nil end
        end
    end
})

local loopKickBlobActive = false
local loopKickBlobTask = nil
local kickHeight = 25

BlobmanTab:Toggle({
    Title = "Loop Kick (Grab + Blob)",
    Value = Toggles.loopKickBlob or false,
    Callback = function(state)
        loopKickBlobActive = state
        Toggles.loopKickBlob = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            loopKickBlobTask = task.spawn(function()
                while loopKickBlobActive do
                    local target = getSelectedPlayer()
                    if not target or not target.Character then
                        task.wait(0.1)
                        continue
                    end
                    local tChar = target.Character
                    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                    local tHum = tChar:FindFirstChild("Humanoid")
                    if not tRoot or not tHum or tHum.Health <= 0 then
                        task.wait(0.1)
                        continue
                    end

                    local myChar = LocalPlayer.Character
                    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    local myHum = myChar and myChar:FindFirstChild("Humanoid")
                    if not myRoot or not myHum then
                        task.wait(0.1)
                        continue
                    end

                    local seat = myHum.SeatPart
                    if seat and seat.Parent and seat.Parent.Name == "CreatureBlobman" then
                        local blob = seat.Parent
                        local rightDetector = blob:FindFirstChild("RightDetector")
                        local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
                        local leftDetector = blob:FindFirstChild("LeftDetector")
                        local leftWeld = leftDetector and leftDetector:FindFirstChild("LeftWeld")
                        local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                        local creatureGrab = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
                        local creatureDrop = scriptObj and scriptObj:FindFirstChild("CreatureDrop")
                        if creatureGrab and creatureDrop and leftWeld and rightWeld then
                            pcall(function()
                                creatureGrab:FireServer(leftDetector, tRoot, leftWeld)
                                creatureGrab:FireServer(rightDetector, tRoot, rightWeld)
                                creatureDrop:FireServer(leftWeld, tRoot)
                                creatureDrop:FireServer(rightWeld, tRoot)
                            end)
                        end
                    end

                    myRoot.CFrame = tRoot.CFrame
                    pcall(function()
                        tHum.PlatformStand = true
                        SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                        DestroyGrabLine:FireServer(tRoot)
                    end)
                    task.wait(0.2)
                    myRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -3)
                    tRoot.CFrame = myRoot.CFrame * CFrame.new(0, kickHeight, 0)
                    tRoot.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.1)
                end
            end)
        else
            if loopKickBlobTask then task.cancel(loopKickBlobTask); loopKickBlobTask = nil end
        end
    end
})

local spinLoopActive = false
local spinLoopTask = nil
local spinRadius = 25
local spinSpeed = 0.25
local customKickHeight = 20
local spinAngle = 0

BlobmanTab:Slider({
    Title = "Spin Radius",
    Min = 5,
    Max = 50,
    Default = 25,
    Rounding = 0,
    Callback = function(value)
        spinRadius = value
    end
})

BlobmanTab:Slider({
    Title = "Spin Speed",
    Min = 0.05,
    Max = 1,
    Default = 0.25,
    Rounding = 2,
    Callback = function(value)
        spinSpeed = value
    end
})

BlobmanTab:Toggle({
    Title = "Spin Loop Kick",
    Value = Toggles.spinLoopKick or false,
    Callback = function(state)
        spinLoopActive = state
        Toggles.spinLoopKick = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            spinAngle = 0
            spinLoopTask = task.spawn(function()
                while spinLoopActive do
                    local target = getSelectedPlayer()
                    if not target or not target.Character then
                        task.wait(0.1)
                        continue
                    end
                    local tChar = target.Character
                    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                    local tHum = tChar:FindFirstChild("Humanoid")
                    if not tRoot or not tHum or tHum.Health <= 0 then
                        task.wait(0.1)
                        continue
                    end

                    local myChar = LocalPlayer.Character
                    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    local myHum = myChar and myChar:FindFirstChild("Humanoid")
                    if not myRoot or not myHum then
                        task.wait(0.1)
                        continue
                    end

                    local seat = myHum.SeatPart
                    if seat and seat.Parent and seat.Parent.Name == "CreatureBlobman" then
                        local blob = seat.Parent
                        local rightDetector = blob:FindFirstChild("RightDetector")
                        local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
                        local leftDetector = blob:FindFirstChild("LeftDetector")
                        local leftWeld = leftDetector and leftDetector:FindFirstChild("LeftWeld")
                        local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                        local creatureGrab = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
                        local creatureDrop = scriptObj and scriptObj:FindFirstChild("CreatureDrop")
                        if creatureGrab and creatureDrop and leftWeld and rightWeld then
                            pcall(function()
                                creatureGrab:FireServer(leftDetector, tRoot, leftWeld)
                                creatureGrab:FireServer(rightDetector, tRoot, rightWeld)
                                creatureDrop:FireServer(leftWeld, tRoot)
                                creatureDrop:FireServer(rightWeld, tRoot)
                            end)
                        end
                    end

                    spinAngle = spinAngle + spinSpeed
                    if spinAngle > 6.28 then spinAngle = 0 end
                    local x = math.cos(spinAngle) * spinRadius
                    local z = math.sin(spinAngle) * spinRadius

                    myRoot.CFrame = tRoot.CFrame * CFrame.new(x, 0, z)
                    pcall(function()
                        tHum.PlatformStand = true
                        SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                        DestroyGrabLine:FireServer(tRoot)
                    end)
                    task.wait(0.1)
                    tRoot.CFrame = myRoot.CFrame * CFrame.new(0, customKickHeight, 0)
                    tRoot.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.1)
                end
            end)
        else
            if spinLoopTask then task.cancel(spinLoopTask); spinLoopTask = nil end
            spinAngle = 0
        end
    end
})

local oldDisable = undeltedhub.DisableAll or function() end
undeltedhub.DisableAll = function()
    if autoSitActive then
        autoSitActive = false
        if autoSitTask then task.cancel(autoSitTask); autoSitTask = nil end
    end
    if blobKillActive then
        blobKillActive = false
        if blobKillTask then task.cancel(blobKillTask); blobKillTask = nil end
    end
    if loopKickBlobActive then
        loopKickBlobActive = false
        if loopKickBlobTask then task.cancel(loopKickBlobTask); loopKickBlobTask = nil end
    end
    if spinLoopActive then
        spinLoopActive = false
        if spinLoopTask then task.cancel(spinLoopTask); spinLoopTask = nil end
    end
    oldDisable()
end

SafeNotify({ Title = "Blobman", Content = "Methods loaded", Duration = 2 })