local WindUI = undeitedhub.WindUI
local PlayerTab = undeitedhub.Window:Tab({ Title = "Player" })

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local localPlayer = Players.LocalPlayer

local connections = {}
local antiAfkEnabled = undeitedhub.Toggles.antiAfkEnabled or false
local fullbrightEnabled = undeitedhub.Toggles.fullbrightEnabled or false
local fovEnabled = undeitedhub.Toggles.fovEnabled or false
local movementEnabled = undeitedhub.Toggles.movementEnabled or false
local originalLighting = {}
local originalFov
local originalMovement

local function SaveToggle(name, value)
    undeitedhub.Toggles[name] = value
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

local function Notify(title, content)
    WindUI:Notify({ Title = title, Content = content, Duration = 2 })
end

local function GetHumanoid()
    local character = localPlayer and localPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function SetAntiAfk(enabled)
    antiAfkEnabled = enabled
    SaveToggle("antiAfkEnabled", enabled)
    if connections.antiAfk then
        connections.antiAfk:Disconnect()
        connections.antiAfk = nil
    end
    if enabled and localPlayer then
        connections.antiAfk = localPlayer.Idled:Connect(function()
            local camera = workspace.CurrentCamera
            if not camera then return end
            VirtualUser:Button2Down(Vector2.new(0, 0), camera.CFrame)
            task.wait(0.1)
            VirtualUser:Button2Up(Vector2.new(0, 0), camera.CFrame)
        end)
    end
end

local function SetFullbright(enabled)
    fullbrightEnabled = enabled
    SaveToggle("fullbrightEnabled", enabled)
    if enabled then
        originalLighting = {
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
            GlobalShadows = Lighting.GlobalShadows,
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
        }
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    else
        for property, value in pairs(originalLighting) do
            Lighting[property] = value
        end
        originalLighting = {}
    end
end

local function SetFov(enabled)
    fovEnabled = enabled
    SaveToggle("fovEnabled", enabled)
    local camera = workspace.CurrentCamera
    if not camera then return end
    if enabled then
        originalFov = originalFov or camera.FieldOfView
        camera.FieldOfView = 90
    elseif originalFov then
        camera.FieldOfView = originalFov
        originalFov = nil
    end
end

local function SetMovement(enabled)
    movementEnabled = enabled
    SaveToggle("movementEnabled", enabled)
    local humanoid = GetHumanoid()
    if not humanoid then return end
    if enabled then
        originalMovement = originalMovement or {
            WalkSpeed = humanoid.WalkSpeed,
            JumpPower = humanoid.JumpPower,
        }
        humanoid.WalkSpeed = 24
        humanoid.JumpPower = 65
    elseif originalMovement then
        humanoid.WalkSpeed = originalMovement.WalkSpeed
        humanoid.JumpPower = originalMovement.JumpPower
        originalMovement = nil
    end
end

PlayerTab:Toggle({ Title = "Anti AFK", Value = antiAfkEnabled, Callback = SetAntiAfk })
PlayerTab:Toggle({ Title = "Fullbright", Value = fullbrightEnabled, Callback = SetFullbright })
PlayerTab:Toggle({ Title = "Wide FOV", Value = fovEnabled, Callback = SetFov })
PlayerTab:Toggle({ Title = "Movement Preset", Value = movementEnabled, Callback = SetMovement })

PlayerTab:Button({
    Title = "Reset Character",
    Callback = function()
        local humanoid = GetHumanoid()
        if humanoid then
            humanoid.Health = 0
            Notify("Player", "Character reset")
        end
    end,
})

PlayerTab:Button({
    Title = "Rejoin Server",
    Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
    end,
})

PlayerTab:Button({
    Title = "Copy Job ID",
    Callback = function()
        if setclipboard then
            setclipboard(game.JobId)
            Notify("Player", "Job ID copied")
        else
            Notify("Player", "Clipboard is not supported")
        end
    end,
})

connections.character = localPlayer.CharacterAdded:Connect(function()
    task.wait(0.25)
    if movementEnabled then SetMovement(true) end
    if fovEnabled then SetFov(true) end
end)

if antiAfkEnabled then SetAntiAfk(true) end
if fullbrightEnabled then SetFullbright(true) end
if fovEnabled then SetFov(true) end
if movementEnabled then SetMovement(true) end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    SetAntiAfk(false)
    SetFullbright(false)
    SetFov(false)
    SetMovement(false)
    if connections.character then
        connections.character:Disconnect()
        connections.character = nil
    end
    oldDisable()
end
local WindUI = undeitedhub.WindUI
local PlayerTab = undeitedhub.Window:Tab({ Title = "Player" })

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local localPlayer = Players.LocalPlayer

local connections = {}
local antiAfkEnabled = undeitedhub.Toggles.antiAfkEnabled or false
local fullbrightEnabled = undeitedhub.Toggles.fullbrightEnabled or false
local fovEnabled = undeitedhub.Toggles.fovEnabled or false
local movementEnabled = undeitedhub.Toggles.movementEnabled or false
local originalLighting = {}
local originalFov = nil
local originalMovement = nil

local function SaveToggle(name, value)
    undeitedhub.Toggles[name] = value
    if undeitedhub.SaveSettings then
        undeitedhub.SaveSettings()
    end
end

local function Notify(title, content)
    WindUI:Notify({ Title = title, Content = content, Duration = 2 })
end

local function GetHumanoid()
    local character = localPlayer and localPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function SetAntiAfk(enabled)
    antiAfkEnabled = enabled
    SaveToggle("antiAfkEnabled", enabled)
    if connections.antiAfk then
        connections.antiAfk:Disconnect()
        connections.antiAfk = nil
    end
    if enabled and localPlayer then
        connections.antiAfk = localPlayer.Idled:Connect(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end

local function SetFullbright(enabled)
    fullbrightEnabled = enabled
    SaveToggle("fullbrightEnabled", enabled)
    if enabled then
        originalLighting = {
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
            GlobalShadows = Lighting.GlobalShadows,
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
        }
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    else
        for property, value in pairs(originalLighting) do
            Lighting[property] = value
        end
        originalLighting = {}
    end
end

local function SetFov(enabled)
    fovEnabled = enabled
    SaveToggle("fovEnabled", enabled)
    local camera = workspace.CurrentCamera
    if not camera then return end
    if enabled then
        originalFov = originalFov or camera.FieldOfView
        camera.FieldOfView = 90
    elseif originalFov then
        camera.FieldOfView = originalFov
        originalFov = nil
    end
end

local function SetMovement(enabled)
    movementEnabled = enabled
    SaveToggle("movementEnabled", enabled)
    local humanoid = GetHumanoid()
    if not humanoid then return end
    if enabled then
        originalMovement = originalMovement or {
            WalkSpeed = humanoid.WalkSpeed,
            JumpPower = humanoid.JumpPower,
        }
        humanoid.WalkSpeed = 24
        humanoid.JumpPower = 65
    elseif originalMovement then
        humanoid.WalkSpeed = originalMovement.WalkSpeed
        humanoid.JumpPower = originalMovement.JumpPower
        originalMovement = nil
    end
end

PlayerTab:Toggle({
    Title = "Anti AFK",
    Value = antiAfkEnabled,
    Callback = SetAntiAfk,
})

PlayerTab:Toggle({
    Title = "Fullbright",
    Value = fullbrightEnabled,
    Callback = SetFullbright,
})

PlayerTab:Toggle({
    Title = "Wide FOV",
    Value = fovEnabled,
    Callback = SetFov,
})

PlayerTab:Toggle({
    Title = "Movement Preset",
    Value = movementEnabled,
    Callback = SetMovement,
})

PlayerTab:Button({
    Title = "Reset Character",
    Callback = function()
        local humanoid = GetHumanoid()
        if humanoid then
            humanoid.Health = 0
            Notify("Player", "Character reset")
        end
    end,
})

PlayerTab:Button({
    Title = "Rejoin Server",
    Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
    end,
})

PlayerTab:Button({
    Title = "Copy Job ID",
    Callback = function()
        if setclipboard then
            setclipboard(game.JobId)
            Notify("Player", "Job ID copied")
        else
            Notify("Player", "Clipboard is not supported")
        end
    end,
})

connections.character = localPlayer.CharacterAdded:Connect(function()
    task.wait(0.25)
    if movementEnabled then SetMovement(true) end
    if fovEnabled then SetFov(true) end
end)

if antiAfkEnabled then SetAntiAfk(true) end
if fullbrightEnabled then SetFullbright(true) end
if fovEnabled then SetFov(true) end
if movementEnabled then SetMovement(true) end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    SetAntiAfk(false)
    SetFullbright(false)
    SetFov(false)
    SetMovement(false)
    if connections.character then
        connections.character:Disconnect()
        connections.character = nil
    end
    if connections.visibility then
        connections.visibility:Disconnect()
        connections.visibility = nil
    end
    oldDisable()
end
