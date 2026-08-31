local WindUI = undeltedhub.WindUI
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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

local function KillTarget(target)
    if not target or target == LocalPlayer then return false end
    if not IsAlive(target) then return false end
    if IsInLobby(target) then return false end

    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local myRoot = GetRoot(myChar)
    local myHum = GetHumanoid(myChar)
    if not myRoot or not myHum or myHum.Health <= 0 then return false end

    local targetChar = GetCharacter(target)
    if not targetChar then return false end
    local targetRoot = GetRoot(targetChar)
    if not targetRoot then return false end

    local punch = myChar:FindFirstChild("Punch")
    if not punch then
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            punch = backpack:FindFirstChild("Punch")
            if punch then
                punch.Parent = myChar
                task.wait(0.05)
            end
        end
    end
    if not punch then return false end

    local behind = targetRoot.CFrame * CFrame.new(0, 1, -2)
    myRoot.CFrame = behind

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

local autoKillEnabled = undeltedhub.Toggles.AutoKill or false
local autoKillTask = nil

local function GetNearestTarget()
    local myRoot = GetRoot(GetCharacter(LocalPlayer))
    if not myRoot then return nil end
    local best, bestDist
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) and not IsInLobby(player) then
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
    return best
end

local function StartAutoKillLoop()
    if autoKillTask then return end
    autoKillEnabled = true
    undeltedhub.Toggles.AutoKill = true
    if undeltedhub.SaveSettings then undeltedhub.SaveSettings() end
    SafeNotify({ Title = "Auto Kill", Content = "Enabled (nearest)", Duration = 2 })

    autoKillTask = task.spawn(function()
        local cooldown = 0.3
        while autoKillEnabled do
            if _G.UNDELTEDHUB_WINDOW_VISIBLE and LocalPlayer and GetCharacter(LocalPlayer) then
                local target = GetNearestTarget()
                if target then
                    pcall(KillTarget, target)
                end
            end
            task.wait(cooldown)
        end
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