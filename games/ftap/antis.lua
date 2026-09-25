local WindUI = undeitedhub.WindUI
local AntisTab = undeitedhub.Window:Tab({ Title = "Antis" })

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local antiFireActive = false
local antiFireTask = nil
local hkFirePart = nil

local function ToggleAntiFire(state)
    antiFireActive = state
    if state then
        pcall(function()
            if Workspace.Plots and Workspace.Plots.Plot5 and Workspace.Plots.Plot5.Barrier then
                if Workspace.Plots.Plot5.Barrier:FindFirstChild("AntiFirePart") then
                    hkFirePart = Workspace.Plots.Plot5.Barrier:FindFirstChild("AntiFirePart")
                else
                    hkFirePart = Workspace.Plots.Plot5.Barrier:FindFirstChild("PlotBarrier")
                end
                if hkFirePart then
                    hkFirePart.CanCollide = true
                    hkFirePart.CanQuery = true
                    hkFirePart.Name = "AntiFirePart"
                    local h2 = hkFirePart:Clone()
                    h2.Name = "FalseBorder"
                    h2.Parent = hkFirePart.Parent
                    hkFirePart.Size = Vector3.new(1, 1, 1)
                    for _, prt in pairs(hkFirePart:GetChildren()) do
                        prt:Destroy()
                    end
                    hkFirePart.CanQuery = false
                    hkFirePart.CanCollide = false
                end
            end
        end)
        antiFireTask = task.spawn(function()
            while antiFireActive do
                pcall(function()
                    if hkFirePart then
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            hkFirePart.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame
                        end
                        hkFirePart.CanCollide = not hkFirePart.CanCollide
                        hkFirePart.CanCollide = not hkFirePart.CanCollide
                    end
                end)
                task.wait(0.1)
            end
            if hkFirePart then
                hkFirePart.CFrame = CFrame.new(0, -15, 0)
            end
        end)
    else
        if antiFireTask then
            task.cancel(antiFireTask)
            antiFireTask = nil
        end
        if hkFirePart then
            hkFirePart.CFrame = CFrame.new(0, -15, 0)
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Fire",
    Value = false,
    Callback = function(state)
        ToggleAntiFire(state)
        undeitedhub.Toggles.antiFire = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Anti Fire",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiFire then
    ToggleAntiFire(true)
end

local antiLagActive = false

local function ApplyAntiLag(state)
    if state then
        pcall(function()
            LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = true
            for _, plr in pairs(Players:GetPlayers()) do
                if plr.Character and plr.Character:FindFirstChild("GrabParts") then
                    plr.Character.GrabParts:Destroy()
                end
            end
        end)
    else
        pcall(function()
            LocalPlayer.PlayerScripts.CharacterAndBeamMove.Disabled = false
        end)
    end
end

AntisTab:Toggle({
    Title = "Anti Lag",
    Value = false,
    Callback = function(state)
        antiLagActive = state
        ApplyAntiLag(state)
        undeitedhub.Toggles.antiLag = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Anti Lag",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiLag then
    antiLagActive = true
    ApplyAntiLag(true)
end

local antiGrabActive = false
local antiGrabTask = nil

local function getCharacterEvents()
    return ReplicatedStorage:FindFirstChild("CharacterEvents")
end

local function fireRecovery(character, hum)
    local characterEvents = getCharacterEvents()
    if characterEvents then
        local struggle = characterEvents:FindFirstChild("Struggle")
        if struggle then
            pcall(function() struggle:FireServer(LocalPlayer) end)
        end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        local ragdollRemote = characterEvents:FindFirstChild("RagdollRemote")
        if hrp and ragdollRemote then
            pcall(function() ragdollRemote:FireServer(hrp, 0.00000000001) end)
        end
    end

    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        if track.Animation and track.Animation.AnimationId == "rbxassetid://7047322890" then
            pcall(function() track:Stop() end)
        end
    end

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        hum.AutoRotate = true
        if hum.Sit then hum.Sit = false end
        hum.PlatformStand = false
    end)
end

local function clearPartOwnersDeep(character)
    local found = false
    for _, prt in ipairs(character:GetDescendants()) do
        local partOwner = prt:FindFirstChild("PartOwner")
        if partOwner and partOwner.Value ~= "" then
            found = true
            pcall(function() partOwner.Value = "" end)
        end
    end
    return found
end

local function ToggleAntiGrab(state)
    antiGrabActive = state

    if state then
        if antiGrabTask then return end

        antiGrabTask = task.spawn(function()
            while antiGrabActive do
                pcall(function()
                    local character = LocalPlayer.Character
                    if not character then return end
                    local hum = character:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health <= 0 then return end

                    local grabbed = clearPartOwnersDeep(character)
                    if grabbed then
                        fireRecovery(character, hum)
                    end
                end)
                task.wait(0.05)
            end
            antiGrabTask = nil
        end)
    else
        if antiGrabTask then
            task.cancel(antiGrabTask)
            antiGrabTask = nil
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Grab",
    Value = false,
    Callback = function(state)
        ToggleAntiGrab(state)
        undeitedhub.Toggles.antiGrab = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Anti Grab",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiGrab then
    ToggleAntiGrab(true)
end

local HAMBURGER_TOY_NAME = "FoodHamburger"
local HAMBURGER_CHECK_INTERVAL = 0.2
local HAMBURGER_SPAWN_VECTOR = Vector3.new(0, -117.76699829101562, 0)
local HAMBURGER_GRAB_RETRY_INTERVAL = 0.15
local HAMBURGER_RESPAWN_COOLDOWN = 0.5

local antiBlobmanActive = false
local antiBlobmanTask = nil
local activeHamburger = nil
local lastGrabAttempt = 0
local lastRespawnAt = 0

local function getToysFolder()
    return Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
end

local function getSpawnRemote()
    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    return menuToys and menuToys:FindFirstChild("SpawnToyRemoteFunction")
end

local function findAllHamburgers()
    local folder = getToysFolder()
    if not folder then return {} end
    local list = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == HAMBURGER_TOY_NAME then
            table.insert(list, child)
        end
    end
    return list
end

local function findExistingHamburger()
    local list = findAllHamburgers()
    return list[1]
end

local function isInToysFolder(hamburger)
    if not hamburger or not hamburger.Parent then return false end
    local folder = getToysFolder()
    if not folder then return false end
    return hamburger.Parent == folder
end

local function isHamburgerHeld(hamburger)
    if not hamburger or not hamburger.Parent then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local holdPart = hamburger:FindFirstChild("HoldPart")
    if not holdPart then return false end

    for _, child in ipairs(holdPart:GetChildren()) do
        if child:IsA("WeldConstraint") or child:IsA("Weld") or child:IsA("Motor6D") then
            local part0 = child.Part0
            local part1 = child.Part1
            if (part0 and part0:IsDescendantOf(char)) or (part1 and part1:IsDescendantOf(char)) then
                return true
            end
        end
    end

    for _, child in ipairs(hamburger:GetChildren()) do
        if child:IsA("WeldConstraint") or child:IsA("Weld") then
            local part0 = child.Part0
            local part1 = child.Part1
            if (part0 and part0:IsDescendantOf(char)) or (part1 and part1:IsDescendantOf(char)) then
                return true
            end
        end
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local dist = (holdPart.Position - hrp.Position).Magnitude
        if dist < 6 then
            return true
        end
    end

    return false
end

local function getHoldRemote(hamburger)
    if not hamburger then return nil end
    local holdPart = hamburger:FindFirstChild("HoldPart")
    if not holdPart then return nil end
    return holdPart:FindFirstChild("HoldItemRemoteFunction")
end

local function spawnHamburger()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local spawnRemote = getSpawnRemote()
    if not spawnRemote then return nil end

    local spawnCFrame = hrp.CFrame * CFrame.new(0, 1.5, -3)
    pcall(function()
        spawnRemote:InvokeServer(HAMBURGER_TOY_NAME, spawnCFrame, HAMBURGER_SPAWN_VECTOR)
    end)

    for i = 1, 20 do
        task.wait()
        local h = findExistingHamburger()
        if h then return h end
    end
    return nil
end

local function grabHamburger(hamburger)
    local char = LocalPlayer.Character
    if not char then return false end
    local holdRemote = getHoldRemote(hamburger)
    if not holdRemote then return false end
    local ok = pcall(function()
        holdRemote:InvokeServer(hamburger, char)
    end)
    return ok
end

local function getOrCreateHamburger()
    local existing = findExistingHamburger()
    if existing then return existing end

    local now = tick()
    if now - lastRespawnAt < HAMBURGER_RESPAWN_COOLDOWN then return nil end
    lastRespawnAt = now

    local spawned = spawnHamburger()
    if spawned then
        SafeNotify({ Title = "Anti Blobman", Content = "Spawned new hamburger", Duration = 1.5 })
    end
    return spawned
end

local function startAntiBlobman()
    if antiBlobmanTask then return end
    antiBlobmanActive = true
    undeitedhub.Toggles.antiBlobman = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    antiBlobmanTask = task.spawn(function()
        activeHamburger = getOrCreateHamburger()
        if not activeHamburger then
            SafeNotify({ Title = "Anti Blobman", Content = "Failed to get hamburger", Duration = 2 })
            antiBlobmanActive = false
            undeitedhub.Toggles.antiBlobman = false
            antiBlobmanTask = nil
            return
        end

        while antiBlobmanActive do
            if not isInToysFolder(activeHamburger) then
                activeHamburger = getOrCreateHamburger()
            end

            if activeHamburger and activeHamburger.Parent then
                if not isHamburgerHeld(activeHamburger) then
                    local now = tick()
                    if now - lastGrabAttempt > HAMBURGER_GRAB_RETRY_INTERVAL then
                        lastGrabAttempt = now
                        if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                            pcall(grabHamburger, activeHamburger)
                        end
                    end
                end
            end

            task.wait(HAMBURGER_CHECK_INTERVAL)
        end

        activeHamburger = nil
        antiBlobmanTask = nil
    end)
end

local function stopAntiBlobman()
    antiBlobmanActive = false
    undeitedhub.Toggles.antiBlobman = false
    if antiBlobmanTask then
        task.cancel(antiBlobmanTask)
        antiBlobmanTask = nil
    end
    activeHamburger = nil
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

AntisTab:Toggle({
    Title = "Anti Blobman",
    Value = antiBlobmanActive,
    Callback = function(state)
        if state then
            startAntiBlobman()
        else
            stopAntiBlobman()
        end
        SafeNotify({
            Title = "Anti Blobman",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiBlobman then
    startAntiBlobman()
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if antiFireActive then
        ToggleAntiFire(false)
    end
    if antiLagActive then
        antiLagActive = false
        ApplyAntiLag(false)
    end
    if antiGrabActive then
        ToggleAntiGrab(false)
    end
    if antiBlobmanActive then
        stopAntiBlobman()
    end
    oldDisable()
end
