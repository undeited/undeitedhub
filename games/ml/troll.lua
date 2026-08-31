local WindUI = undeltedhub.WindUI
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

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

local function GetStrength(player)
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local str = ls:FindFirstChild("Strength")
        if str then return str.Value end
    end
    return 0
end

local function GetCharacter(player)
    return player and player.Character
end

local function GetRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(player)
    local char = GetCharacter(player)
    if not char then return false end
    local hum = GetHumanoid(char)
    return hum and hum.Health > 0
end

local function IsInLobby(player)
    if not player then return false end
    local char = GetCharacter(player)
    if not char then return false end
    local root = GetRoot(char)
    if not root then return false end
    local lobby = Workspace:FindFirstChild("Lobby") or Workspace:FindFirstChild("RegularLobby")
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
    return (root.Position - lobbyPos).Magnitude < 50
end

local function EquipPunch()
    local char = LocalPlayer.Character
    if not char then return nil end
    local punch = char:FindFirstChild("Punch")
    if not punch then
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            punch = backpack:FindFirstChild("Punch")
            if punch then
                punch.Parent = char
                task.wait(0.05)
            end
        end
    end
    return punch
end

local function TryPunch(targetRoot)
    local punch = EquipPunch()
    if not punch then return false end
    if punch:IsA("Tool") then
        pcall(function() punch:Activate() end)
        local remote = punch:FindFirstChild("PunchRemote") or punch:FindFirstChild("Remote")
        if remote and remote:IsA("RemoteEvent") then
            pcall(function() remote:FireServer(targetRoot) end)
        end
        local bindable = punch:FindFirstChild("PunchEvent") or punch:FindFirstChild("Activate")
        if bindable and bindable:IsA("BindableEvent") then
            pcall(function() bindable:Fire() end)
        end
        return true
    end
    return false
end

local function LockPlayer(lock)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = GetHumanoid(char)
    if not hum then return end
    if lock then
        hum.PlatformStand = true
        hum.WalkSpeed = 0
        hum.JumpPower = 0
    else
        hum.PlatformStand = false
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
end

local function FollowAndPunch(target)
    if not target then return false end
    if not IsAlive(target) or IsInLobby(target) then return false end
    local myStrength = GetStrength(LocalPlayer)
    local targetStrength = GetStrength(target)
    if targetStrength >= myStrength then return false end

    local targetChar = GetCharacter(target)
    if not targetChar then return false end
    local targetRoot = GetRoot(targetChar)
    if not targetRoot then return false end

    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local myRoot = GetRoot(myChar)
    if not myRoot then return false end

    LockPlayer(true)
    myRoot.CFrame = targetRoot.CFrame
    while IsAlive(target) and not IsInLobby(target) and targetChar and targetRoot and myRoot do
        local newCF = targetRoot.CFrame
        myRoot.CFrame = newCF
        TryPunch(targetRoot)
        task.wait(0.1)
        targetChar = GetCharacter(target)
        if targetChar then
            targetRoot = GetRoot(targetChar)
        else
            break
        end
        myChar = LocalPlayer.Character
        if myChar then
            myRoot = GetRoot(myChar)
        else
            break
        end
    end
    LockPlayer(false)
    return true
end

local autoKillEnabled = undeltedhub.Toggles.AutoKill or false
local autoKillTask = nil

local function GetBestTarget()
    local myStrength = GetStrength(LocalPlayer)
    local myRoot = GetRoot(GetCharacter(LocalPlayer))
    if not myRoot then return nil end
    local best, bestDist
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) and not IsInLobby(player) then
            local str = GetStrength(player)
            if str < myStrength then
                local root = GetRoot(GetCharacter(player))
                if root then
                    local dist = (root.Position - myRoot.Position).Magnitude
                    if not bestDist or dist < bestDist then
                        best = player
                        bestDist = dist
                    end
                end
            end
        end
    end
    return best
end

local function StartAutoKillLoop()
    if autoKillTask then return end
    autoKillEnabled = true
    undeltedhub.Toggles.AutoKill = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Kill", Content = "Enabled", Duration = 2 })

    autoKillTask = task.spawn(function()
        while autoKillEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE and LocalPlayer and GetCharacter(LocalPlayer) then
                local target = GetBestTarget()
                if target then
                    pcall(FollowAndPunch, target)
                else
                    LockPlayer(false)
                end
            end
            task.wait(0.2)
        end
        LockPlayer(false)
        autoKillTask = nil
    end)
end

local function StopAutoKillLoop()
    autoKillEnabled = false
    undeltedhub.Toggles.AutoKill = false
    if autoKillTask then
        task.cancel(autoKillTask)
        autoKillTask = nil
    end
    LockPlayer(false)
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Kill", Content = "Disabled", Duration = 2 })
end

TrollTab:Toggle({
    Title = "Auto Kill",
    Value = autoKillEnabled,
    Callback = function(state)
        if state then StartAutoKillLoop() else StopAutoKillLoop() end
    end
})

if autoKillEnabled then
    StartAutoKillLoop()
end

local oldDisable = undeltedhub.DisableAll or function() end
undeltedhub.DisableAll = function()
    if autoKillEnabled then StopAutoKillLoop() end
    oldDisable()
end