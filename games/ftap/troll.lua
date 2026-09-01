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

local TrollTab = undeltedhub.Window:Tab({ Title = "Troll" })

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local R = ReplicatedStorage
local GrabEvents = R:WaitForChild("GrabEvents")
local SetNetworkOwner = GrabEvents:WaitForChild("SetNetworkOwner")
local DestroyGrabLine = GrabEvents:WaitForChild("DestroyGrabLine")
local CreateGrabLine = GrabEvents:WaitForChild("CreateGrabLine")

local function sno(part)
    if not part or not part.Parent then return end
    pcall(function()
        SetNetworkOwner:FireServer(part, part.CFrame)
    end)
end

local kickGrabActive = false
local kickGrabConnection = nil
local kickTarget = nil
local kickAttackConn = nil

local function getScreenCenterTarget()
    local camera = Workspace.CurrentCamera
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local ray = camera:ViewportPointToRay(screenCenter.X, screenCenter.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    if LocalPlayer.Character then
        params.FilterDescendantsInstances = {LocalPlayer.Character}
    end
    local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    if result and result.Instance then
        for _, pl in pairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character and result.Instance:IsDescendantOf(pl.Character) then
                return pl
            end
        end
    end
    return nil
end

local function stopKickGrab()
    kickGrabActive = false
    if kickAttackConn then
        kickAttackConn:Disconnect()
        kickAttackConn = nil
    end
    if kickGrabConnection then
        kickGrabConnection:Disconnect()
        kickGrabConnection = nil
    end
    kickTarget = nil
end

local function startKickGrab(targetPlayer)
    if not targetPlayer then return end
    kickGrabActive = true
    kickTarget = targetPlayer

    kickAttackConn = RunService.RenderStepped:Connect(function()
        if not kickGrabActive or not kickTarget then
            stopKickGrab()
            return
        end
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tgtChar = kickTarget.Character
        local tgtRoot = tgtChar and tgtChar:FindFirstChild("HumanoidRootPart")
        if not myRoot or not tgtRoot then return end

        local camera = Workspace.CurrentCamera
        local camCF = camera.CFrame
        local teleportPos = camCF.Position + camCF.LookVector * 20

        pcall(function()
            tgtRoot.CFrame = CFrame.new(teleportPos)
        end)

        local grabCFrame = CFrame.new(-0.0903, 0.419, 0.5, 0.3963,0,-0.9181, -1.094e-7,1,-4.724e-8, 0.9181,5.96e-8,0.3963)
        pcall(function()
            CreateGrabLine:FireServer(tgtRoot, grabCFrame)
            SetNetworkOwner:FireServer(tgtRoot, CFrame.lookAt(myRoot.Position, tgtRoot.Position))
            DestroyGrabLine:FireServer(tgtRoot)
        end)
    end)
end

local kickKeybindToggle = TrollTab:Toggle({
    Title = "Kick Grab (F key)",
    Value = Toggles.kickGrab or false,
    Callback = function(state)
        Toggles.kickGrab = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
        if state then
            if kickGrabConnection then kickGrabConnection:Disconnect() end
            kickGrabConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if input.KeyCode ~= Enum.KeyCode.F then return end
                if kickGrabActive then
                    stopKickGrab()
                    SafeNotify({Title = "Kick Grab", Content = "Stopped", Duration = 2})
                    return
                end
                local target = getScreenCenterTarget()
                if not target then
                    SafeNotify({Title = "Kick Grab", Content = "No target in crosshair", Duration = 2})
                    return
                end
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local tgtRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if not myRoot or not tgtRoot then
                    SafeNotify({Title = "Kick Grab", Content = "Invalid target", Duration = 2})
                    return
                end
                if (myRoot.Position - tgtRoot.Position).Magnitude > 25 then
                    SafeNotify({Title = "Kick Grab", Content = "Too far", Duration = 2})
                    return
                end
                startKickGrab(target)
                SafeNotify({Title = "Kick Grab", Content = "Kicking " .. target.DisplayName, Duration = 2})
            end)
        else
            stopKickGrab()
            if kickGrabConnection then kickGrabConnection:Disconnect(); kickGrabConnection = nil end
        end
    end
})

local oatsKickActive = false
local oatsKickTask = nil

local function getSelectedPlayer()
    if undeltedhub.GetSelectedPlayer then
        return undeltedhub.GetSelectedPlayer()
    end
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then return pl end
    end
    return nil
end

TrollTab:Toggle({
    Title = "Oats Kick (auto target)",
    Value = Toggles.oatsKick or false,
    Callback = function(state)
        oatsKickActive = state
        Toggles.oatsKick = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            oatsKickTask = task.spawn(function()
                while oatsKickActive do
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
                    pcall(function()
                        local myChar = LocalPlayer.Character
                        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                        if myRoot then
                            myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 2.5)
                            task.wait(0.05)
                            for i = 1, 8 do
                                SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                                task.wait(0.01)
                            end
                            for i = 1, 4 do
                                DestroyGrabLine:FireServer(tRoot)
                                task.wait(0.01)
                            end
                            tRoot.CFrame = myRoot.CFrame * CFrame.new(0, 20, 0)
                            tRoot.AssemblyLinearVelocity = Vector3.zero
                            tHum.PlatformStand = true
                            task.wait(0.1)
                            myRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -2)
                        end
                    end)
                    task.wait(0.3)
                end
            end)
        else
            if oatsKickTask then task.cancel(oatsKickTask); oatsKickTask = nil end
        end
    end
})

local ownershipKickActive = false
local ownershipKickTask = nil

TrollTab:Toggle({
    Title = "Ownership Kick",
    Value = Toggles.ownershipKick or false,
    Callback = function(state)
        ownershipKickActive = state
        Toggles.ownershipKick = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            ownershipKickTask = task.spawn(function()
                while ownershipKickActive do
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
                    pcall(function()
                        local myChar = LocalPlayer.Character
                        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                        if myRoot then
                            myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 3)
                            SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                            DestroyGrabLine:FireServer(tRoot)
                            tHum.PlatformStand = true
                            tRoot.CFrame = myRoot.CFrame * CFrame.new(0, 25, 0)
                            tRoot.AssemblyLinearVelocity = Vector3.zero
                        end
                    end)
                    task.wait(0.2)
                end
            end)
        else
            if ownershipKickTask then task.cancel(ownershipKickTask); ownershipKickTask = nil end
        end
    end
})

local palletRagdollActive = false
local palletRagdollTask = nil

local function spawnPallet()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        R.MenuToys.SpawnToyRemoteFunction:InvokeServer(
            "PalletLightBrown",
            hrp.CFrame * CFrame.new(0, 10, 20),
            Vector3.zero
        )
    end)
end

local function setupPalletRagdoll(target)
    if not target or not target.Character then return end
    local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
    local tHum = target.Character:FindFirstChild("Humanoid")
    if not tRoot or not tHum or tHum.Health <= 0 then return end

    local toys = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if not toys then return end

    local pallet = toys:FindFirstChild("PalletForRagdoll") or toys:FindFirstChild("PalletLightBrown")
    if not pallet then
        spawnPallet()
        task.wait(0.2)
        pallet = toys:FindFirstChild("PalletLightBrown")
        if not pallet then return end
    end

    local soundPart = pallet:FindFirstChild("SoundPart")
    if not soundPart then return end

    pcall(function()
        SetNetworkOwner:FireServer(soundPart, soundPart.CFrame)
        DestroyGrabLine:FireServer(soundPart)
    end)

    for _, v in pairs(pallet:GetChildren()) do
        if v:IsA("BasePart") then
            v.CanCollide = false; v.CanQuery = false; v.Transparency = 1
        end
    end
    pallet.Name = "PalletForRagdoll"

    local strike = false
    local ragdollLoop = RunService.RenderStepped:Connect(function()
        if not palletRagdollActive or not target.Character then
            ragdollLoop:Disconnect()
            return
        end
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if tRoot then
            strike = not strike
            if strike then
                soundPart.CFrame = tRoot.CFrame * CFrame.new(0, 2, 0)
                soundPart.AssemblyLinearVelocity = Vector3.new(0, -9e5, 0)
            else
                soundPart.CFrame = tRoot.CFrame * CFrame.new(0, -1, 0)
                soundPart.AssemblyLinearVelocity = Vector3.new(0, 9e5, 0)
            end
        end
    end)
    if not palletRagdollTask then
        palletRagdollTask = task.spawn(function()
            while palletRagdollActive do
                task.wait(0.5)
                local t = getSelectedPlayer()
                if t and t.Character then
                else
                    break
                end
            end
            ragdollLoop:Disconnect()
            if pallet and pallet.Parent then
                pcall(function() R.MenuToys.DestroyToy:FireServer(pallet) end)
            end
            palletRagdollTask = nil
        end)
    end
end

TrollTab:Toggle({
    Title = "Pallet Ragdoll (invis)",
    Value = Toggles.palletRagdoll or false,
    Callback = function(state)
        palletRagdollActive = state
        Toggles.palletRagdoll = state
        if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end

        if state then
            local target = getSelectedPlayer()
            if not target then
                palletRagdollActive = false
                Toggles.palletRagdoll = false
                SafeNotify({Title = "Pallet Ragdoll", Content = "No target selected", Duration = 2})
                return
            end
            setupPalletRagdoll(target)
        else
            if palletRagdollTask then
                task.cancel(palletRagdollTask)
                palletRagdollTask = nil
            end
            local toys = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            if toys then
                for _, v in pairs(toys:GetChildren()) do
                    if v.Name == "PalletForRagdoll" or v.Name == "PalletLightBrown" then
                        pcall(function() R.MenuToys.DestroyToy:FireServer(v) end)
                    end
                end
            end
        end
    end
})

local oldDisable = undeltedhub.DisableAll or function() end
undeltedhub.DisableAll = function()
    if kickGrabActive then stopKickGrab() end
    if kickGrabConnection then kickGrabConnection:Disconnect(); kickGrabConnection = nil end
    if oatsKickActive then oatsKickActive = false; if oatsKickTask then task.cancel(oatsKickTask); oatsKickTask = nil end end
    if ownershipKickActive then ownershipKickActive = false; if ownershipKickTask then task.cancel(ownershipKickTask); ownershipKickTask = nil end end
    if palletRagdollActive then
        palletRagdollActive = false
        if palletRagdollTask then task.cancel(palletRagdollTask); palletRagdollTask = nil end
        local toys = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        if toys then
            for _, v in pairs(toys:GetChildren()) do
                if v.Name == "PalletForRagdoll" or v.Name == "PalletLightBrown" then
                    pcall(function() R.MenuToys.DestroyToy:FireServer(v) end)
                end
            end
        end
    end
    oldDisable()
end

SafeNotify({ Title = "Troll", Content = "Kick methods loaded", Duration = 2 })