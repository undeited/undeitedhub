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
            benchName = "Bench",
            requiredStrength = 62500,
        },
        ["Bench (125k)"] = {
            machineName = "Industrial Bench",
            variantIndex = 2,
            benchName = "Bench",
            requiredStrength = 125000,
        },
        ["Bench (250k)"] = {
            machineName = "Industrial Bench",
            variantIndex = 3,
            benchName = "Bench",
            requiredStrength = 250000,
        },
        ["Bar Lift (250k)"] = {
            machineName = "Industrial Bar Lift",
            variantIndex = 1,
            benchName = "Bar",
            requiredStrength = 250000,
        },
        ["Boulder (187.5k)"] = {
            machineName = "Industrial Boulder",
            variantIndex = 1,
            benchName = "Boulder",
            requiredStrength = 187500,
        },
        ["Squat (125k)"] = {
            machineName = "Industrial Squat",
            variantIndex = 1,
            benchName = "Squat",
            requiredStrength = 125000,
        },
        ["Squat (312.5k)"] = {
            machineName = "Industrial Squat",
            variantIndex = 2,
            benchName = "Squat",
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

local function getPartFromInstance(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart end
        return inst:FindFirstChildWhichIsA("BasePart")
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

local function teleportToPart(part)
    if not part then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    pcall(function()
        hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
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
    if not machine then return end

    local bench = machine:FindFirstChild(config.benchName)
    local benchPart = getPartFromInstance(bench)
    if not benchPart then
        benchPart = getPartFromInstance(machine)
    end
    if benchPart then
        teleportToPart(benchPart)
    end

    local seats = collectInteractSeats(machine)
    if #seats == 0 then return end

    local useSeat = seats[1]
    local repSeat = seats[2] or seats[1]

    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    local remote = rEvents and rEvents:FindFirstChild("machineInteractRemote")
    if remote then
        pcall(function()
            remote:InvokeServer("useMachine", useSeat)
        end)
    end

    local muscleEvent = LocalPlayer:FindFirstChild("muscleEvent")
    if muscleEvent then
        pcall(function()
            muscleEvent:FireServer("rep", repSeat)
        end)
    end
end

local function startAutoFarm()
    if farmTask then return end
    autoFarmEnabled = true
    undeitedhub.Toggles.gymAutoFarm = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

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
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

GymTab:Dropdown({
    Title = "Select Gym",
    Values = { "Industrial Gym" },
    Value = selectedGym,
    Callback = function(value)
        selectedGym = value
    end
})

GymTab:Dropdown({
    Title = "Select Machine",
    Values = MACHINE_OPTIONS,
    Value = selectedMachine,
    Callback = function(value)
        selectedMachine = value
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
    end
    oldDisable()
end
