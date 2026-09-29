local WindUI = undeitedhub.WindUI

local MiscTab = undeitedhub.Window:Tab({ Title = "Misc" })
if not MiscTab then return end
task.wait(0.1)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
        if state then
            startAutoSpin()
        else
            stopAutoSpin()
        end
    end
})

if autoSpinEnabled then
    startAutoSpin()
end

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
                if index > MAX_GIFTS then
                    index = 1
                end
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
        if state then
            startAutoGift()
        else
            stopAutoGift()
        end
    end
})

if autoGiftEnabled then
    startAutoGift()
end

local autoLiftEnabled = undeitedhub.Toggles.AutoLift or false
local autoLiftTask = nil
local LIFT_INTERVAL = 0.15
local MACHINE_RANGE = 12

local function getEquippedTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            return child
        end
    end
    return nil
end

local function findMachinesFolder()
    local direct = Workspace:FindFirstChild("machinesFolder")
    if direct then return direct end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "machinesFolder" then
            return obj
        end
    end
    return nil
end

local function findNearestMachine()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local pos = hrp.Position

    local folder = findMachinesFolder()
    if not folder then return nil end

    local nearest, nearestDist = nil, MACHINE_RANGE
    for _, machine in ipairs(folder:GetChildren()) do
        if machine:IsA("Model") then
            local seat = machine:FindFirstChild("interactSeat")
            if not seat then
                for _, d in ipairs(machine:GetDescendants()) do
                    if d.Name == "interactSeat" and d:IsA("BasePart") then
                        seat = d
                        break
                    end
                end
            end
            if seat and seat:IsA("BasePart") then
                local d = (seat.Position - pos).Magnitude
                if d < nearestDist then
                    nearestDist = d
                    nearest = { machine = machine, seat = seat }
                end
            end
        end
    end
    return nearest
end

local function fireUseMachine(seat)
    if not seat then return end
    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    local remote = rEvents and rEvents:FindFirstChild("machineInteractRemote")
    if remote then
        pcall(function() remote:InvokeServer("useMachine", seat) end)
    end
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
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if char and hum and hum.Health > 0 then
                    local nearby = findNearestMachine()
                    if nearby then
                        local seat = nearby.seat
                        local isSeated = hum.SeatPart and hum.SeatPart:IsDescendantOf(nearby.machine)
                        if isSeated then
                            fireRep(seat)
                        else
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                pcall(function()
                                    hrp.CFrame = seat.CFrame + Vector3.new(0, 1.5, 0)
                                    hrp.AssemblyLinearVelocity = Vector3.zero
                                    hrp.AssemblyAngularVelocity = Vector3.zero
                                end)
                            end
                            fireUseMachine(seat)
                        end
                    end

                    local tool = getEquippedTool()
                    if tool then
                        pcall(function() tool:Activate() end)
                    else
                        local backpack = LocalPlayer:FindFirstChild("Backpack")
                        if backpack then
                            local weight = backpack:FindFirstChild("Weight")
                            if weight and hum then
                                pcall(function() hum:EquipTool(weight) end)
                            end
                        end
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
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

MiscTab:Toggle({
    Title = "Auto Lift",
    Value = autoLiftEnabled,
    Callback = function(state)
        if state then
            startAutoLift()
        else
            stopAutoLift()
        end
    end
})

if autoLiftEnabled then
    startAutoLift()
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoSpinEnabled then stopAutoSpin() end
    if autoGiftEnabled then stopAutoGift() end
    if autoLiftEnabled then stopAutoLift() end
    oldDisable()
end
