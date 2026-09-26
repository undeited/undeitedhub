local WindUI = undeitedhub.WindUI
local GymTab = undeitedhub.Window:Tab({ Title = "Gym" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local GYMS = {
    ["Industrial Gym"] = {
        ["Bench (62.5k)"] = {
            machineName = "Industrial Bench",
            variantIndex = 1,
            requiredStrength = 62500,
        },
        ["Bench (125k)"] = {
            machineName = "Industrial Bench",
            variantIndex = 2,
            requiredStrength = 125000,
        },
        ["Bench (250k)"] = {
            machineName = "Industrial Bench",
            variantIndex = 3,
            requiredStrength = 250000,
        },
        ["Bar Lift (250k)"] = {
            machineName = "Industrial Bar Lift",
            variantIndex = 1,
            requiredStrength = 250000,
        },
        ["Boulder (187.5k)"] = {
            machineName = "Industrial Boulder",
            variantIndex = 1,
            requiredStrength = 187500,
        },
        ["Squat (125k)"] = {
            machineName = "Industrial Squat",
            variantIndex = 1,
            requiredStrength = 125000,
        },
        ["Squat (312.5k)"] = {
            machineName = "Industrial Squat",
            variantIndex = 2,
            requiredStrength = 312500,
        },
    },
}

local MACHINE_OPTIONS = {
    "Bench (62.5k)",
    "Bench (125k)",
    "Bench (250k)",
    "Bar Lift (250k)",
    "Boulder (187.5k)",
    "Squat (125k)",
    "Squat (312.5k)",
}

local selectedGym = "Industrial Gym"
local selectedMachine = MACHINE_OPTIONS[1]
local autoFarmEnabled = undeitedhub.Toggles.gymAutoFarm or false
local farmTask = nil
local FARM_COOLDOWN = 0.05
local RESEAT_COOLDOWN = 0.75

local lastReseatTime = 0
local currentMachine = nil

local function getStrength()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if not leaderstats then return nil end
    local strength = leaderstats:FindFirstChild("Strength")
    if strength then return strength.Value end
    for _, v in ipairs(leaderstats:GetChildren()) do
        if v:IsA("IntValue") or v:IsA("NumberValue") then
            if string.lower(v.Name):find("strength") then
                return v.Value
            end
        end
    end
    return nil
end

local function findMachinesFolder()
    local direct = Workspace:FindFirstChild("machinesFolder")
    if direct then return direct end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "machinesFolder" then return obj end
    end
    return nil
end

local function getMachineInstance(folder, machineName, variantIndex)
    if not folder or not machineName then return nil end
    variantIndex = variantIndex or 1

    local matches = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == machineName then
            table.insert(matches, child)
        end
    end

    return matches[variantIndex]
end

local function collectInteractSeats(machine)
    if not machine then return {} end
    local seats = {}
    local direct = machine:FindFirstChild("interactSeat")
    if direct then table.insert(seats, direct) end
    for _, d in ipairs(machine:GetDescendants()) do
        if d.Name == "interactSeat" and d ~= direct then
            table.insert(seats, d)
        end
    end
    return seats
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function isSeatedOn(seat)
    if not seat then return false end
    local hum = getHumanoid()
    if not hum then return false end
    return hum.SeatPart == seat
end

local function zeroVelocity()
    local hrp = getHRP()
    if not hrp then return end
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function sitOnSeat(seat)
    if not seat then return false end
    local hrp = getHRP()
    if not hrp then return false end

    local targetCFrame = seat.CFrame + Vector3.new(0, 2, 0)

    pcall(function()
        hrp.CFrame = targetCFrame
    end)
    zeroVelocity()
    return true
end

local function fireUseMachine(seat)
    if not seat then return end
    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    local remote = rEvents and rEvents:FindFirstChild("machineInteractRemote")
    if remote then
        pcall(function()
            remote:InvokeServer("useMachine", seat)
        end)
    end
end

local function fireRep(seat)
    if not seat then return end
    local muscleEvent = LocalPlayer:FindFirstChild("muscleEvent")
    if muscleEvent then
        pcall(function()
            muscleEvent:FireServer("rep", seat)
        end)
    end
end

local function runFarmCycle()
    local folder = findMachinesFolder()
    if not folder then return end

    local gymData = GYMS[selectedGym]
    if not gymData then return end

    local config = gymData[selectedMachine]
    if not config then return end

    local myStrength = getStrength()
    if myStrength and myStrength < config.requiredStrength then return end

    local machine = getMachineInstance(folder, config.machineName, config.variantIndex)
    if not machine then
        currentMachine = nil
        return
    end

    if currentMachine ~= machine then
        currentMachine = machine
        lastReseatTime = 0
    end

    local seats = collectInteractSeats(machine)
    if #seats == 0 then return end

    local useSeat = seats[1]
    local repSeat = seats[2] or seats[1]

    if isSeatedOn(useSeat) or isSeatedOn(repSeat) then
        fireRep(repSeat)
        return
    end

    local now = tick()
    if now - lastReseatTime < RESEAT_COOLDOWN then
        return
    end
    lastReseatTime = now

    sitOnSeat(useSeat)
    fireUseMachine(useSeat)
end

local function startAutoFarm()
    if farmTask then return end
    autoFarmEnabled = true
    undeitedhub.Toggles.gymAutoFarm = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    lastReseatTime = 0
    currentMachine = nil

    farmTask = task.spawn(function()
        while autoFarmEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(runFarmCycle)
            end
            task.wait(FARM_COOLDOWN)
        end
        farmTask = nil
    end)
end

local function stopAutoFarm()
    autoFarmEnabled = false
    undeitedhub.Toggles.gymAutoFarm = false
    if farmTask then
        task.cancel(farmTask)
        farmTask = nil
    end
    lastReseatTime = 0
    currentMachine = nil
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

GymTab:Dropdown({
    Title = "Select Gym",
    Values = { "Industrial Gym" },
    Value = selectedGym,
    Callback = function(value)
        selectedGym = value
        currentMachine = nil
        lastReseatTime = 0
    end
})

GymTab:Dropdown({
    Title = "Select Machine",
    Values = MACHINE_OPTIONS,
    Value = selectedMachine,
    Callback = function(value)
        selectedMachine = value
        currentMachine = nil
        lastReseatTime = 0
    end
})

GymTab:Toggle({
    Title = "Auto Farm",
    Value = autoFarmEnabled,
    Callback = function(state)
        if state then
            startAutoFarm()
        else
            stopAutoFarm()
        end
    end
})

if autoFarmEnabled then
    startAutoFarm()
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoFarmEnabled then
        autoFarmEnabled = false
        undeitedhub.Toggles.gymAutoFarm = false
        if farmTask then
            task.cancel(farmTask)
            farmTask = nil
        end
        lastReseatTime = 0
        currentMachine = nil
    end
    oldDisable()
end
