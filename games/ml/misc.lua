local WindUI = undeitedhub.WindUI

local MiscTab = undeitedhub.Window:Tab({ Title = "Misc" })
if not MiscTab then return end
task.wait(0.1)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
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
local DEFAULT_INTERVAL = 0.1

local function getMachinesFolder()
    return Workspace:FindFirstChild("machinesFolder")
end

local function findMachineBySeatedSeat()
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

local function findMachineByProximity()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local pos = hrp.Position

    local folder = getMachinesFolder()
    if not folder then return nil end

    local nearest, nearestDist = nil, 20
    for _, machine in ipairs(folder:GetChildren()) do
        local seat = machine:FindFirstChild("interactSeat")
        if seat and seat:IsA("BasePart") then
            local d = (seat.Position - pos).Magnitude
            if d < nearestDist then
                nearestDist = d
                nearest = machine
            end
        end
    end
    return nearest
end

local function getActiveMachine()
    return findMachineBySeatedSeat() or findMachineByProximity()
end

local function getRepSeat(machine)
    if not machine then return nil end
    local direct = machine:FindFirstChild("interactSeat")
    if direct and direct:IsA("BasePart") then
        return direct
    end
    for _, d in ipairs(machine:GetDescendants()) do
        if d.Name == "interactSeat" and d:IsA("BasePart") then
            return d
        end
    end
    return nil
end

local function getRepTime(machine)
    if not machine then return DEFAULT_INTERVAL end
    local rt = machine:FindFirstChild("repTime")
    if rt then
        if rt:IsA("NumberValue") or rt:IsA("IntValue") then
            local v = tonumber(rt.Value)
            if v and v > 0 then
                if v > 5 then v = v / 1000 end
                return math.max(0.05, v)
            end
        end
    end
    local attr = machine:GetAttribute("repTime")
    if type(attr) == "number" and attr > 0 then
        return math.max(0.05, attr)
    end
    return DEFAULT_INTERVAL
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

    autoLiftTask = task.spawn(function()
        while autoLiftEnabled do
            local waitTime = DEFAULT_INTERVAL
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local machine = getActiveMachine()
                if machine then
                    local seat = getRepSeat(machine)
                    if seat then
                        fireRep(seat)
                    end
                    waitTime = getRepTime(machine)
                end
            end
            task.wait(waitTime)
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
