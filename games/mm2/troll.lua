local WindUI = undeitedhub.WindUI
local utils = undeitedhub.Utils
local config = undeitedhub.Config
local MathUtils = undeitedhub.MathUtils

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

if not undeitedhub.GetCurrentMurderer then
    function undeitedhub.GetCurrentMurderer()
        for _, player in ipairs(game.Players:GetPlayers()) do
            if player ~= game.Players.LocalPlayer then
                local char = player.Character
                if char then
                    local knife = char:FindFirstChild("Knife") or player.Backpack:FindFirstChild("Knife")
                    if not knife then
                        for _, child in ipairs(char:GetDescendants()) do
                            if child.Name:lower():find("knife") then
                                knife = child
                                break
                            end
                        end
                    end
                    if knife then return player end
                end
            end
        end
        return nil
    end
end

if not undeitedhub.GetCurrentSheriff then
    function undeitedhub.GetCurrentSheriff()
        for _, player in ipairs(game.Players:GetPlayers()) do
            if player == game.Players.LocalPlayer then continue end
            local char = player.Character
            if not char then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local hasGun = char:FindFirstChild("Gun") or player.Backpack:FindFirstChild("Gun")
            if hasGun then
                return player
            end
        end
        return nil
    end
end

local TrollTab = undeitedhub.Window:Tab({ Title = "Troll" })

local function IsInLobby()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return false end
    local character = localPlayer.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    local lobby = workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("RegularLobby")
    if not lobby then return false end
    local lobbyPos
    if lobby:IsA("BasePart") then
        lobbyPos = lobby.Position
    elseif lobby.PrimaryPart then
        lobbyPos = lobby.PrimaryPart.Position
    else
        for _, part in ipairs(lobby:GetDescendants()) do
            if part:IsA("BasePart") then
                lobbyPos = part.Position
                break
            end
        end
    end
    if not lobbyPos then return false end
    return (rootPart.Position - lobbyPos).Magnitude < 75
end

local function IsPlayerInLobby(player)
    if not player then return false end
    local char = player.Character
    if not char then return false end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    local lobby = workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("RegularLobby")
    if not lobby then return false end
    local lobbyPos
    if lobby:IsA("BasePart") then
        lobbyPos = lobby.Position
    elseif lobby.PrimaryPart then
        lobbyPos = lobby.PrimaryPart.Position
    else
        for _, part in ipairs(lobby:GetDescendants()) do
            if part:IsA("BasePart") then
                lobbyPos = part.Position
                break
            end
        end
    end
    if not lobbyPos then return false end
    return (rootPart.Position - lobbyPos).Magnitude < 75
end

local function IsRoundActive()
    local roundTimer = workspace:FindFirstChild("RoundTimerPart")
    if roundTimer then
        local time = roundTimer:GetAttribute("Time")
        if time ~= nil and time > 0 then
            return true
        end
    end
    if IsInLobby() then
        return false
    end
    local localPlayer = game.Players.LocalPlayer
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= localPlayer then
            if not IsPlayerInLobby(player) then
                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local flingManager = {}

flingManager.FlingVelocity = Vector3.new(9e7, -9e8, 9e7)
flingManager.FlingAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
flingManager.MoverFlingVelocity = Vector3.new(9e8, 9e8, 9e8)
flingManager.cFlingOldPos = nil

function flingManager.IsFiniteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function flingManager.IsFiniteVector(value)
    return typeof(value) == "Vector3"
        and flingManager.IsFiniteNumber(value.X)
        and flingManager.IsFiniteNumber(value.Y)
        and flingManager.IsFiniteNumber(value.Z)
end

function flingManager.SetFlingVelocity(part)
    if not part then return end
    pcall(function() part.AssemblyLinearVelocity = flingManager.FlingVelocity end)
    pcall(function() part.AssemblyAngularVelocity = flingManager.FlingAngularVelocity end)
    pcall(function() part.Velocity = flingManager.FlingVelocity end)
    pcall(function() part.RotVelocity = flingManager.FlingAngularVelocity end)
end

function flingManager.SetMoverFlingVelocity(mover)
    if not mover then return end
    pcall(function() mover.Velocity = flingManager.MoverFlingVelocity end)
end

function flingManager.ClearPartVelocity(part)
    if not part then return end
    local zero = Vector3.new(0, 0, 0)
    pcall(function() part.AssemblyLinearVelocity = zero end)
    pcall(function() part.AssemblyAngularVelocity = zero end)
    pcall(function() part.Velocity = zero end)
    pcall(function() part.RotVelocity = zero end)
end

function flingManager.GetPartVelocity(part)
    local best = Vector3.new(0, 0, 0)
    local bestSq = 0
    if not part then return best, 0 end
    local ok, assemblyVel = pcall(function() return part.AssemblyLinearVelocity end)
    if ok and flingManager.IsFiniteVector(assemblyVel) then
        best = assemblyVel
        bestSq = assemblyVel:Dot(assemblyVel)
    end
    local legacyOk, legacyVel = pcall(function() return part.Velocity end)
    if legacyOk and flingManager.IsFiniteVector(legacyVel) then
        local legacySq = legacyVel:Dot(legacyVel)
        if legacySq > bestSq then
            best = legacyVel
            bestSq = legacySq
        end
    end
    return best, math.sqrt(bestSq)
end

function flingManager.GetPlayerCharacter(plr)
    if not plr or typeof(plr) ~= "Instance" or not plr:IsA("Player") then
        return nil
    end
    local char = plr.Character
    if char and char.Parent and char:IsDescendantOf(workspace) then
        return char
    end
    return char
end

local function getRoot(model)
    if not model then return nil end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and hum.RootPart then return hum.RootPart end
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
end

local function getHum(model)
    if not model then return nil end
    return model:FindFirstChildOfClass("Humanoid")
end

local function getHead(model)
    if not model then return nil end
    return model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
end

local function IsSeated(player)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and (hum.SeatPart or hum:GetState() == Enum.HumanoidStateType.Seated)
end

local function FlingPlayer(target, silent)
    if not target or target == game.Players.LocalPlayer then
        if not silent then SafeNotify({ Title = "Fling", Content = "Invalid target", Duration = 2 }) end
        return false
    end

    if not IsRoundActive() then
        if not silent then SafeNotify({ Title = "Fling", Content = "Round is not active", Duration = 2 }) end
        return false
    end

    local targetChar = target.Character
    if not targetChar then
        if not silent then SafeNotify({ Title = "Fling", Content = "Target has no character", Duration = 2 }) end
        return false
    end
    local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
    if not targetHum or targetHum.Health <= 0 then
        if not silent then SafeNotify({ Title = "Fling", Content = "Target is dead", Duration = 2 }) end
        return false
    end

    if IsPlayerInLobby(target) then
        if not silent then SafeNotify({ Title = "Fling", Content = "Target is in lobby", Duration = 2 }) end
        return false
    end

    if IsSeated(target) then
        if not silent then SafeNotify({ Title = "Fling", Content = "Target is seated", Duration = 2 }) end
        return false
    end

    local localPlayer = game.Players.LocalPlayer
    local character = flingManager.GetPlayerCharacter(localPlayer) or localPlayer.Character
    local humanoid = getHum(character)
    local rootPart = humanoid and humanoid.RootPart or getRoot(character)

    if not rootPart or not humanoid then
        if not silent then SafeNotify({ Title = "Fling", Content = "Local character invalid", Duration = 2 }) end
        return false
    end

    local tChar = flingManager.GetPlayerCharacter(target)
    if not tChar then
        if not silent then SafeNotify({ Title = "Fling", Content = "Target character missing", Duration = 2 }) end
        return false
    end

    local tHum = getHum(tChar)
    local tRoot = tHum and tHum.RootPart or getRoot(tChar)
    local tHead = getHead(tChar)

    if not tRoot or not tHum or tHum.Health <= 0 then
        if not silent then SafeNotify({ Title = "Fling", Content = "Target invalid or dead", Duration = 2 }) end
        return false
    end

    local acc = tChar:FindFirstChildOfClass("Accessory")
    local handle = acc and acc:FindFirstChild("Handle")
    local originalFPDH = workspace.FallenPartsDestroyHeight

    workspace.FallenPartsDestroyHeight = 0 / 0
    flingManager.cFlingOldPos = rootPart.CFrame

    local flingPart = Instance.new("Part")
    flingPart.Anchored = false
    flingPart.CanCollide = false
    flingPart.Transparency = 1
    flingPart.Size = Vector3.new(1, 1, 1)
    flingPart.CFrame = rootPart.CFrame
    flingPart.Parent = workspace

    local flingWeld = Instance.new("WeldConstraint")
    flingWeld.Part0 = flingPart
    flingWeld.Part1 = rootPart
    flingWeld.Parent = flingPart

    local function cleanupFlingPart()
        if flingPart then
            flingPart:Destroy()
            flingPart = nil
        end
    end

    if tHead then
        workspace.CurrentCamera.CameraSubject = tHead
    elseif handle then
        workspace.CurrentCamera.CameraSubject = handle
    elseif tHum and tRoot then
        workspace.CurrentCamera.CameraSubject = tHum
    end

    if not tChar:FindFirstChildWhichIsA("BasePart") then
        cleanupFlingPart()
        workspace.FallenPartsDestroyHeight = originalFPDH
        if not silent then SafeNotify({ Title = "Fling", Content = "Target has no parts", Duration = 2 }) end
        return false
    end

    local function FPos(BasePart, Pos, Ang)
        local targetCFrame = CFrame.new(BasePart.Position) * Pos * Ang
        flingPart.CFrame = targetCFrame
        character:PivotTo(targetCFrame)
        flingManager.SetFlingVelocity(flingPart)
    end

    local function SFBasePart(BasePart)
        local timeLimit = 2
        local startTime = tick()
        local angle = 0
        repeat
            if rootPart and tHum then
                local _, baseSpeed = flingManager.GetPartVelocity(BasePart)
                if baseSpeed < 50 then
                    angle = angle + 100
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + tHum.MoveDirection * baseSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + tHum.MoveDirection * baseSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(2.25, 1.5, -2.25) + tHum.MoveDirection * baseSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(-2.25, -1.5, 2.25) + tHum.MoveDirection * baseSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + tHum.MoveDirection, CFrame.Angles(math.rad(angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + tHum.MoveDirection, CFrame.Angles(math.rad(angle), 0, 0))
                    task.wait()
                else
                    local _, targetRootSpeed = flingManager.GetPartVelocity(tRoot)
                    FPos(BasePart, CFrame.new(0, 1.5, tHum.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, -tHum.WalkSpeed), CFrame.Angles(0, 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, tHum.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, targetRootSpeed / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, -targetRootSpeed / 1.25), CFrame.Angles(0, 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, targetRootSpeed / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(-90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                    task.wait()
                end
            else
                break
            end
        until not BasePart:IsDescendantOf(tChar)
            or not target
            or target.Parent ~= game.Players
            or tHum.Health <= 0
            or tick() > startTime + timeLimit
    end

    local bv = Instance.new("BodyVelocity")
    bv.Parent = flingPart
    flingManager.SetMoverFlingVelocity(bv)
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)

    humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    local basePartToUse
    if tRoot and tHead and (tRoot.Position - tHead.Position).Magnitude > 5 then
        basePartToUse = tHead
    elseif tRoot then
        basePartToUse = tRoot
    elseif tHead then
        basePartToUse = tHead
    elseif handle then
        basePartToUse = handle
    end

    if basePartToUse then
        SFBasePart(basePartToUse)
    end

    bv:Destroy()
    cleanupFlingPart()

    humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    workspace.CurrentCamera.CameraSubject = humanoid

    repeat
        rootPart.CFrame = flingManager.cFlingOldPos * CFrame.new(0, 0.5, 0)
        character:PivotTo(flingManager.cFlingOldPos * CFrame.new(0, 0.5, 0))
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        for _, x in next, character:GetChildren() do
            if x:IsA("BasePart") then
                flingManager.ClearPartVelocity(x)
            end
        end
        task.wait()
    until (rootPart.Position - flingManager.cFlingOldPos.Position).Magnitude < 25

    workspace.FallenPartsDestroyHeight = originalFPDH

    if not silent then SafeNotify({ Title = "Fling", Content = "Flung " .. target.Name .. " into the void!", Duration = 2 }) end
    return true
end

local autoFlingMurdererEnabled = undeitedhub.Toggles.autoFlingMurdererEnabled or false
local autoFlingSheriffEnabled = undeitedhub.Toggles.autoFlingSheriffEnabled or false
local autoFlingCooldown = 5
local lastFlingMurdererTime = 0
local lastFlingSheriffTime = 0

game:GetService("RunService").Heartbeat:Connect(function()
    if autoFlingMurdererEnabled and _G.UNDEITEDHUB_WINDOW_VISIBLE then
        local now = tick()
        if now - lastFlingMurdererTime >= autoFlingCooldown and IsRoundActive() then
            local target = undeitedhub.GetCurrentMurderer()
            if target then
                local char = target.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 and not IsPlayerInLobby(target) then
                        lastFlingMurdererTime = now
                        pcall(FlingPlayer, target, true)
                    end
                end
            end
        end
    end

    if autoFlingSheriffEnabled and _G.UNDEITEDHUB_WINDOW_VISIBLE then
        local now = tick()
        if now - lastFlingSheriffTime >= autoFlingCooldown and IsRoundActive() then
            local target = undeitedhub.GetCurrentSheriff()
            if target then
                local char = target.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 and not IsPlayerInLobby(target) then
                        if char:FindFirstChild("Gun") or target.Backpack:FindFirstChild("Gun") then
                            lastFlingSheriffTime = now
                            pcall(FlingPlayer, target, true)
                        end
                    end
                end
            end
        end
    end
end)

TrollTab:Button({
    Title = "Fling Murderer",
    Callback = function()
        if not IsRoundActive() then
            SafeNotify({ Title = "Fling", Content = "Round is not active", Duration = 2 })
            return
        end
        local murderer = undeitedhub.GetCurrentMurderer()
        if murderer then
            FlingPlayer(murderer, false)
        else
            SafeNotify({ Title = "Fling", Content = "No murderer found", Duration = 2 })
        end
    end
})

TrollTab:Button({
    Title = "Fling Sheriff",
    Callback = function()
        if not IsRoundActive() then
            SafeNotify({ Title = "Fling", Content = "Round is not active", Duration = 2 })
            return
        end
        local sheriff = undeitedhub.GetCurrentSheriff()
        if sheriff then
            local char = sheriff.Character
            if char and (char:FindFirstChild("Gun") or sheriff.Backpack:FindFirstChild("Gun")) then
                FlingPlayer(sheriff, false)
            else
                SafeNotify({ Title = "Fling", Content = "Sheriff has no gun or is dead", Duration = 2 })
            end
        else
            SafeNotify({ Title = "Fling", Content = "No sheriff found", Duration = 2 })
        end
    end
})

TrollTab:Toggle({
    Title = "Auto Fling Murderer",
    Value = autoFlingMurdererEnabled,
    Callback = function(state)
        autoFlingMurdererEnabled = state
        undeitedhub.Toggles.autoFlingMurdererEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Auto Fling Murderer", Content = state and "Enabled" or "Disabled", Duration = 2 })
        if state then lastFlingMurdererTime = tick() end
    end
})

TrollTab:Toggle({
    Title = "Auto Fling Sheriff",
    Value = autoFlingSheriffEnabled,
    Callback = function(state)
        autoFlingSheriffEnabled = state
        undeitedhub.Toggles.autoFlingSheriffEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Auto Fling Sheriff", Content = state and "Enabled" or "Disabled", Duration = 2 })
        if state then lastFlingSheriffTime = tick() end
    end
})

local function GetPlayerKnife()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return nil end
    local char = localPlayer.Character
    if char then
        local knife = char:FindFirstChild("Knife")
        if knife and knife:IsA("Tool") then return knife end
    end
    local backpack = localPlayer:FindFirstChild("Backpack")
    if backpack then
        local knife = backpack:FindFirstChild("Knife")
        if knife and knife:IsA("Tool") then return knife end
    end
    return nil
end

local function KillSheriff()
    local localPlayer = game.Players.LocalPlayer
    if not localPlayer then return end
    local knife = GetPlayerKnife()
    if not knife then return end
    local handleTouched = knife:FindFirstChild("Events") and knife.Events:FindFirstChild("HandleTouched")
    if not handleTouched or not handleTouched:IsA("RemoteEvent") then return end
    local sheriff = undeitedhub.GetCurrentSheriff()
    if not sheriff then return end
    if IsPlayerInLobby(sheriff) then return end
    local character = sheriff.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        handleTouched:FireServer(rootPart)
    end
end

TrollTab:Button({
    Title = "Kill Sheriff",
    Callback = function()
        local localPlayer = game.Players.LocalPlayer
        if not localPlayer then
            SafeNotify({ Title = "Error", Content = "Local player not found", Duration = 2 })
            return
        end
        local knife = GetPlayerKnife()
        if not knife then
            SafeNotify({ Title = "Error", Content = "You are not the murderer", Duration = 2 })
            return
        end
        if IsInLobby() then
            SafeNotify({ Title = "Kill Sheriff", Content = "Cannot kill in lobby", Duration = 2 })
            return
        end
        if not IsRoundActive() then
            SafeNotify({ Title = "Kill Sheriff", Content = "Round is not active", Duration = 2 })
            return
        end
        pcall(KillSheriff)
        SafeNotify({ Title = "Kill Sheriff", Content = "Attempted to kill sheriff", Duration = 2 })
    end
})

local autoKillSheriffEnabled = undeitedhub.Toggles.autoKillSheriffEnabled or false
local lastAutoKillSheriffTime = 0
local KILL_COOLDOWN = 1

game:GetService("RunService").Heartbeat:Connect(function()
    if autoKillSheriffEnabled and _G.UNDEITEDHUB_WINDOW_VISIBLE then
        local now = tick()
        if now - lastAutoKillSheriffTime >= KILL_COOLDOWN and IsRoundActive() then
            local localPlayer = game.Players.LocalPlayer
            if localPlayer then
                local knife = GetPlayerKnife()
                if knife then
                    local sheriff = undeitedhub.GetCurrentSheriff()
                    if sheriff then
                        local char = sheriff.Character
                        if char then
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            if hum and hum.Health > 0 and not IsPlayerInLobby(sheriff) then
                                lastAutoKillSheriffTime = now
                                pcall(KillSheriff)
                            end
                        end
                    end
                end
            end
        end
    end
end)

TrollTab:Toggle({
    Title = "Auto Kill Sheriff",
    Value = autoKillSheriffEnabled,
    Callback = function(state)
        autoKillSheriffEnabled = state
        undeitedhub.Toggles.autoKillSheriffEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({
            Title = "Auto Kill Sheriff",
            Content = autoKillSheriffEnabled and "Enabled" or "Disabled",
            Duration = 2,
        })
        if autoKillSheriffEnabled then
            lastAutoKillSheriffTime = tick()
        end
    end
})

undeitedhub.DisableAll = function()
    autoFlingMurdererEnabled = false
    undeitedhub.Toggles.autoFlingMurdererEnabled = false
    autoFlingSheriffEnabled = false
    undeitedhub.Toggles.autoFlingSheriffEnabled = false
    autoKillSheriffEnabled = false
    undeitedhub.Toggles.autoKillSheriffEnabled = false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end