local WindUI = undeitedhub.WindUI

local MiscTab = undeitedhub.Window:Tab({ Title = "Misc" })
if not MiscTab then return end
task.wait(0.1)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local autoSpinEnabled = undeitedhub.Toggles.AutoSpin or false
local autoSpinTask = nil
local SPIN_INTERVAL = 1

local function getFortuneWheelChances()
    local shared = ReplicatedStorage:FindFirstChild("shared")
    if not shared then return nil end
    local catalogs = shared:FindFirstChild("catalogs")
    if not catalogs then return nil end
    local chances = catalogs:FindFirstChild("fortuneWheelChances")
    if not chances then return nil end
    local children = chances:GetChildren()
    if #children == 0 then return nil end
    return children
end

local function getSpinRemote()
    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    if not rEvents then return nil end
    return rEvents:FindFirstChild("openFortuneWheelRemote")
end

local function spinOnce()
    local remote = getSpinRemote()
    if not remote then return false end
    local chances = getFortuneWheelChances()
    if not chances then return false end
    local choice = chances[math.random(1, #chances)]
    pcall(function()
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer("openFortuneWheel", choice)
        else
            remote:FireServer("openFortuneWheel", choice)
        end
    end)
    return true
end

local function startAutoSpin()
    if autoSpinTask then return end
    autoSpinEnabled = true
    undeitedhub.Toggles.AutoSpin = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    autoSpinTask = task.spawn(function()
        while autoSpinEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(spinOnce)
            end
            task.wait(SPIN_INTERVAL)
        end
        autoSpinTask = nil
    end)
end

local function stopAutoSpin()
    autoSpinEnabled = false
    undeitedhub.Toggles.AutoSpin = false
    if autoSpinTask then
        task.cancel(autoSpinTask)
        autoSpinTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

MiscTab:Toggle({
    Title = "Auto Spin Wheel",
    Value = autoSpinEnabled,
    Callback = function(state)
        if state then startAutoSpin() else stopAutoSpin() end
    end
})

if autoSpinEnabled then startAutoSpin() end

local autoGiftEnabled = undeitedhub.Toggles.AutoGift or false
local autoGiftTask = nil
local GIFT_INTERVAL = 0.5
local MAX_GIFTS = 8

local function getGiftRemote()
    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    if not rEvents then return nil end
    return rEvents:FindFirstChild("freeGiftClaimRemote")
end

local function claimGift(index)
    local remote = getGiftRemote()
    if not remote then return false end
    pcall(function()
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer("claimGift", index)
        else
            remote:FireServer("claimGift", index)
        end
    end)
    return true
end

local function startAutoGift()
    if autoGiftTask then return end
    autoGiftEnabled = true
    undeitedhub.Toggles.AutoGift = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    autoGiftTask = task.spawn(function()
        local index = 1
        while autoGiftEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(claimGift, index)
                index = index + 1
                if index > MAX_GIFTS then index = 1 end
            end
            task.wait(GIFT_INTERVAL)
        end
        autoGiftTask = nil
    end)
end

local function stopAutoGift()
    autoGiftEnabled = false
    undeitedhub.Toggles.AutoGift = false
    if autoGiftTask then
        task.cancel(autoGiftTask)
        autoGiftTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

MiscTab:Toggle({
    Title = "Auto Claim Gifts",
    Value = autoGiftEnabled,
    Callback = function(state)
        if state then startAutoGift() else stopAutoGift() end
    end
})

if autoGiftEnabled then startAutoGift() end

local autoLiftEnabled = undeitedhub.Toggles.AutoLift or false
local autoLiftTask = nil
local LIFT_INTERVAL = 0.15
local GAMEPASS_INJECTED = false

local function getOwnedGamepasses()
    return LocalPlayer:FindFirstChild("ownedGamepasses")
end

local function injectFakeGamepass()
    local owned = getOwnedGamepasses()
    if not owned then return false end
    local existing = owned:FindFirstChild("Auto Lift")
    if existing then
        GAMEPASS_INJECTED = true
        return true
    end
    local flag = Instance.new("BoolValue")
    flag.Name = "Auto Lift"
    flag.Value = true
    flag.Parent = owned
    GAMEPASS_INJECTED = true
    return true
end

local function removeFakeGamepass()
    local owned = getOwnedGamepasses()
    if not owned then return end
    local existing = owned:FindFirstChild("Auto Lift")
    if existing then
        pcall(function() existing:Destroy() end)
    end
    GAMEPASS_INJECTED = false
end

local function fireGuiConnections(obj)
    if not obj then return end
    if typeof(getconnections) ~= "function" then return end
    pcall(function()
        for _, c in ipairs(getconnections(obj.MouseButton1Click)) do
            pcall(c.Fire, c)
        end
        for _, c in ipairs(getconnections(obj.Activated)) do
            pcall(c.Fire, c)
        end
        for _, c in ipairs(getconnections(obj.MouseButton1Down)) do
            pcall(c.Fire, c)
        end
    end)
end

local function tryClickAutoLift()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local clicked = false

    local gameGui = playerGui:FindFirstChild("gameGui")
    if gameGui then
        local hud = gameGui:FindFirstChild("hudNewMenu")
        if hud then
            local top = hud:FindFirstChild("Top")
            if top then
                local btn = top:FindFirstChild("AutoLiftBtn")
                if btn and btn:IsA("GuiObject") then
                    btn.Visible = true
                    fireGuiConnections(btn)
                    clicked = true
                end
            end
        end
    end

    local currencyFrameGui = playerGui:FindFirstChild("currencyFrameGui")
    if currencyFrameGui then
        local cf = currencyFrameGui:FindFirstChild("currencyFrame")
        if cf then
            local frame = cf:FindFirstChild("autoLiftFrame")
            if frame then
                frame.Visible = true
                for _, d in ipairs(frame:GetDescendants()) do
                    if d:IsA("GuiButton") then
                        fireGuiConnections(d)
                        clicked = true
                    end
                end
            end
        end
    end

    return clicked
end

local function getSeatedMachine()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    local seat = hum.SeatPart
    if not seat then return nil end

    local current = seat
    while current do
        local parent = current.Parent
        if not parent then return nil end
        if parent.Name == "machinesFolder" then
            return current
        end
        current = parent
    end
    return nil
end

local function collectInteractSeats(machine)
    local seats = {}
    if not machine then return seats end
    for _, d in ipairs(machine:GetDescendants()) do
        if d.Name == "interactSeat" and d:IsA("BasePart") then
            table.insert(seats, d)
        end
    end
    return seats
end

local function fireRep(seat)
    if not seat then return end
    local muscleEvent = LocalPlayer:FindFirstChild("muscleEvent")
    if muscleEvent then
        pcall(function() muscleEvent:FireServer("rep", seat) end)
    end
end

local function startAutoLift()
    if autoLiftTask then return end
    autoLiftEnabled = true
    undeitedhub.Toggles.AutoLift = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    injectFakeGamepass()
    task.spawn(function()
        task.wait(0.3)
        pcall(tryClickAutoLift)
    end)

    autoLiftTask = task.spawn(function()
        local uiRetryAt = tick() + 1
        while autoLiftEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                if not getOwnedGamepasses():FindFirstChild("Auto Lift") then
                    injectFakeGamepass()
                end

                if tick() >= uiRetryAt then
                    uiRetryAt = tick() + 2
                    pcall(tryClickAutoLift)
                end

                local machine = getSeatedMachine()
                if machine then
                    local seats = collectInteractSeats(machine)
                    for _, seat in ipairs(seats) do
                        fireRep(seat)
                        task.wait(0.03)
                    end
                end
            end
            task.wait(LIFT_INTERVAL)
        end
        autoLiftTask = nil
    end)
end

local function stopAutoLift()
    autoLiftEnabled = false
    undeitedhub.Toggles.AutoLift = false
    if autoLiftTask then
        task.cancel(autoLiftTask)
        autoLiftTask = nil
    end
    if GAMEPASS_INJECTED then
        pcall(function()
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if playerGui then
                local gameGui = playerGui:FindFirstChild("gameGui")
                if gameGui then
                    local hud = gameGui:FindFirstChild("hudNewMenu")
                    local top = hud and hud:FindFirstChild("Top")
                    local btn = top and top:FindFirstChild("AutoLiftBtn")
                    if btn then
                        fireGuiConnections(btn)
                    end
                end
            end
        end)
        removeFakeGamepass()
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

MiscTab:Toggle({
    Title = "Auto Lift",
    Value = autoLiftEnabled,
    Callback = function(state)
        if state then startAutoLift() else stopAutoLift() end
    end
})

if autoLiftEnabled then startAutoLift() end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoSpinEnabled then stopAutoSpin() end
    if autoGiftEnabled then stopAutoGift() end
    if autoLiftEnabled then stopAutoLift() end
    oldDisable()
end
