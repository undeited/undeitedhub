local WindUI = undeitedhub.WindUI
local GymTab = undeitedhub.Window:Tab({ Title = "Gym" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local GYMS = {
    ["Industrial Gym"] = {
        ["Bench (62.5k)"]    = { machineName = "Industrial Bench",     variantIndex = 1, requiredStrength = 62500 },
        ["Bench (125k)"]     = { machineName = "Industrial Bench",     variantIndex = 2, requiredStrength = 125000 },
        ["Bench (250k)"]     = { machineName = "Industrial Bench",     variantIndex = 3, requiredStrength = 250000 },
        ["Bar Lift (250k)"]  = { machineName = "Industrial Bar Lift",  variantIndex = 1, requiredStrength = 250000 },
        ["Boulder (187.5k)"] = { machineName = "Industrial Boulder",   variantIndex = 1, requiredStrength = 187500 },
        ["Squat (125k)"]     = { machineName = "Industrial Squat",     variantIndex = 1, requiredStrength = 125000 },
        ["Squat (312.5k)"]   = { machineName = "Industrial Squat",     variantIndex = 2, requiredStrength = 312500 },
    },
    ["Frost Gym"] = {
        ["Press (1k)"]   = { machineName = "Frost Press", variantIndex = 1, requiredStrength = 1000 },
        ["Press (3k)"]   = { machineName = "Frost Press", variantIndex = 2, requiredStrength = 3000 },
        ["Press (7.5k)"] = { machineName = "Frost Press", variantIndex = 3, requiredStrength = 7500 },
        ["Press (15k)"]  = { machineName = "Frost Press", variantIndex = 4, requiredStrength = 15000 },
        ["Squat (4k)"]   = { machineName = "Frost Squat", variantIndex = 1, requiredStrength = 4000 },
        ["Squat (10k)"]  = { machineName = "Frost Squat", variantIndex = 2, requiredStrength = 10000 },
        ["Lift (5k)"]    = { machineName = "Frost Lift",  variantIndex = 1, requiredStrength = 5000 },
    },
    ["Mythical Gym"] = {
        ["Pullup (4k)"]  = { machineName = "Mythical Pullup", variantIndex = 1, requiredStrength = 4000 },
        ["Pullup (8k)"]  = { machineName = "Mythical Pullup", variantIndex = 2, requiredStrength = 8000 },
        ["Press (15k)"]  = { machineName = "Mythical Press",  variantIndex = 1, requiredStrength = 15000 },
        ["Throw (10k)"]  = { machineName = "Mythical Throw",  variantIndex = 1, requiredStrength = 10000 },
        ["Throw (18k)"]  = { machineName = "Mythical Throw",  variantIndex = 2, requiredStrength = 18000 },
        ["Throw (25k)"]  = { machineName = "Mythical Throw",  variantIndex = 3, requiredStrength = 25000 },
    },
    ["Legends Gym"] = {
        ["Pullup (18)"] = { machineName = "Legends Pullup", variantIndex = 1, requiredStrength = 0 },
        ["Pullup (24)"] = { machineName = "Legends Pullup", variantIndex = 2, requiredStrength = 0 },
        ["Throw (36)"]  = { machineName = "Legends Throw",  variantIndex = 1, requiredStrength = 0 },
        ["Press (42)"]  = { machineName = "Legends Press",  variantIndex = 1, requiredStrength = 0 },
        ["Squat (45)"]  = { machineName = "Legends Squat",  variantIndex = 1, requiredStrength = 0 },
        ["Lift (50)"]   = { machineName = "Legends Lift",   variantIndex = 1, requiredStrength = 0 },
    },
    ["Eternal Gym"] = {
        ["Press (15k)"] = { machineName = "Eternal Press", variantIndex = 1, requiredStrength = 15000 },
    },
    ["Muscle King Gym"] = {
        ["Bench"]        = { machineName = "Muscle King Bench", variantIndex = 1, requiredStrength = 0 },
        ["Squat (60)"]   = { machineName = "Muscle King Squat", variantIndex = 1, requiredStrength = 0 },
        ["Boulder (65)"] = { machineName = "King Boulder",      variantIndex = 1, requiredStrength = 0 },
        ["Lift (80)"]    = { machineName = "Muscle King Lift",  variantIndex = 1, requiredStrength = 0 },
    },
    ["Jungle Gym"] = {
        ["Bench (25k)"]     = { machineName = "Jungle Bench",     variantIndex = 1, requiredStrength = 25000 },
        ["Bench (50k)"]     = { machineName = "Jungle Bench",     variantIndex = 2, requiredStrength = 50000 },
        ["Bench (100k)"]    = { machineName = "Jungle Bench",     variantIndex = 3, requiredStrength = 100000 },
        ["Squat (50k)"]     = { machineName = "Jungle Squat",     variantIndex = 1, requiredStrength = 50000 },
        ["Squat (125k)"]    = { machineName = "Jungle Squat",     variantIndex = 2, requiredStrength = 125000 },
        ["Boulder (75k)"]   = { machineName = "Jungle Boulder",   variantIndex = 1, requiredStrength = 75000 },
        ["Bar Lift (100k)"] = { machineName = "Jungle Bar Lift",  variantIndex = 1, requiredStrength = 100000 },
    },
}

local GYM_OPTIONS = {
    "Industrial Gym",
    "Frost Gym",
    "Mythical Gym",
    "Legends Gym",
    "Eternal Gym",
    "Muscle King Gym",
    "Jungle Gym",
}

local function saveAll()
    if undeitedhub.SaveSettings then
        pcall(undeitedhub.SaveSettings)
    end
end

local function findOption(list, value, fallback)
    if type(value) == "string" then
        for _, v in ipairs(list) do
            if v == value then return v end
        end
    end
    return fallback
end

local function buildMachineOptions(gymName)
    local data = GYMS[gymName]
    if not data then return {} end
    local options = {}
    for name, _ in pairs(data) do
        table.insert(options, name)
    end
    table.sort(options)
    return options
end

local function findMachineOption(gymName, machineDisplay)
    if type(machineDisplay) ~= "string" or machineDisplay == "" then
        return nil
    end
    local data = GYMS[gymName]
    if not data then return nil end
    if data[machineDisplay] then return machineDisplay end
    return nil
end

local selectedGym = findOption(GYM_OPTIONS, undeitedhub.Toggles.gymSelectedGym, GYM_OPTIONS[1])
local selectedMachine = findMachineOption(selectedGym, undeitedhub.Toggles.gymSelectedMachine)
if not selectedMachine then
    local opts = buildMachineOptions(selectedGym)
    selectedMachine = opts[1] or ""
end

local autoFarmEnabled = undeitedhub.Toggles.gymAutoFarm or false

undeitedhub.Toggles.gymSelectedGym = selectedGym
undeitedhub.Toggles.gymSelectedMachine = selectedMachine
undeitedhub.Toggles.gymAutoFarm = autoFarmEnabled

local heartbeatConn = nil
local useMachineRunning = false

local pinnedMachine = nil
local pinnedUseSeat = nil
local pinnedRepSeat = nil

local lastMachineCheck = 0
local lastRemoteFire = 0
local lastUseMachine = 0
local lastCharacter = nil

local MACHINE_CHECK_INTERVAL = 1.0
local REMOTE_INTERVAL = 0.15
local USE_MACHINE_INTERVAL = 0.5

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

local function getInstancePosition(inst)
    if not inst then return Vector3.zero end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local ok, pivot = pcall(function() return inst:GetPivot() end)
        if ok and pivot then return pivot.Position end
        local prim = inst.PrimaryPart
        if prim then return prim.Position end
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("BasePart") then return d.Position end
        end
    end
    return Vector3.zero
end

local function readMachineStrength(machine)
    if not machine then return nil end

    local req = machine:FindFirstChild("requirements")
    if req then
        local s = req:FindFirstChild("Strength")
        if s and (s:IsA("IntValue") or s:IsA("NumberValue")) then
            local v = tonumber(s.Value)
            if v then return v end
        end
        for _, d in ipairs(req:GetDescendants()) do
            if d:IsA("IntValue") or d:IsA("NumberValue") then
                if string.lower(d.Name):find("strength") then
                    local v = tonumber(d.Value)
                    if v then return v end
                end
            end
        end
    end

    for _, attr in ipairs({ "Strength", "RequiredStrength", "Requirement", "Required", "StrengthRequired" }) do
        local v = machine:GetAttribute(attr)
        if type(v) == "number" then return v end
    end

    for _, d in ipairs(machine:GetDescendants()) do
        if d:IsA("IntValue") or d:IsA("NumberValue") then
            local lname = string.lower(d.Name)
            if lname:find("strength") or lname:find("require") then
                if type(d.Value) == "number" then return d.Value end
            end
        end
    end

    return nil
end

local function getMachineMatches(folder, machineName)
    if not folder or not machineName then return {} end
    local matches = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == machineName then
            table.insert(matches, child)
        end
    end
    table.sort(matches, function(a, b)
        local pa = getInstancePosition(a)
        local pb = getInstancePosition(b)
        if pa.Y ~= pb.Y then return pa.Y < pb.Y end
        if pa.X ~= pb.X then return pa.X < pb.X end
        return pa.Z < pb.Z
    end)
    return matches
end

local function getMachineInstance(folder, machineName, variantIndex, requiredStrength)
    local matches = getMachineMatches(folder, machineName)
    if #matches == 0 then return nil end
    if #matches == 1 then return matches[1] end
    if requiredStrength and requiredStrength > 0 then
        for _, m in ipairs(matches) do
            local s = readMachineStrength(m)
            if s and math.abs(s - requiredStrength) < 1 then
                return m
            end
        end
    end
    return matches[variantIndex or 1]
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

local function refreshPinned()
    local folder = findMachinesFolder()
    if not folder then
        pinnedMachine = nil
        pinnedUseSeat = nil
        pinnedRepSeat = nil
        return
    end
    local gymData = GYMS[selectedGym]
    if not gymData then return end
    local config = gymData[selectedMachine]
    if not config then
        pinnedMachine = nil
        pinnedUseSeat = nil
        pinnedRepSeat = nil
        return
    end

    local myStrength = getStrength()
    if not myStrength then
        pinnedMachine = nil
        pinnedUseSeat = nil
        pinnedRepSeat = nil
        return
    end

    local machine = getMachineInstance(folder, config.machineName, config.variantIndex, config.requiredStrength)
    if not machine then
        pinnedMachine = nil
        pinnedUseSeat = nil
        pinnedRepSeat = nil
        return
    end

    local liveRequired = readMachineStrength(machine)
    local gate = liveRequired or config.requiredStrength
    if gate and gate > 0 and myStrength < gate then
        pinnedMachine = nil
        pinnedUseSeat = nil
        pinnedRepSeat = nil
        return
    end

    local seats = collectInteractSeats(machine)
    if #seats == 0 then
        pinnedMachine = nil
        pinnedUseSeat = nil
        pinnedRepSeat = nil
        return
    end

    pinnedMachine = machine
    pinnedUseSeat = seats[1]
    pinnedRepSeat = seats[2] or seats[1]
end

local function onHeartbeat()
    if not autoFarmEnabled then return end
    if not _G.UNDEITEDHUB_WINDOW_VISIBLE then return end

    local now = tick()
    if now - lastMachineCheck >= MACHINE_CHECK_INTERVAL then
        lastMachineCheck = now
        refreshPinned()
    end

    if not pinnedMachine or not pinnedMachine.Parent then return end
    if not pinnedUseSeat or not pinnedUseSeat.Parent then return end

    local char = LocalPlayer.Character
    if not char then return end
    if char ~= lastCharacter then
        lastCharacter = char
        lastUseMachine = 0
        lastRemoteFire = 0
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return end

    local isRealSeat = pinnedUseSeat:IsA("Seat") or pinnedUseSeat:IsA("VehicleSeat")
    local isSeatedOnMachine = hum.SeatPart and hum.SeatPart:IsDescendantOf(pinnedMachine)

    if isRealSeat then
        if isSeatedOnMachine then
            if now - lastRemoteFire >= REMOTE_INTERVAL then
                lastRemoteFire = now
                fireRep(pinnedRepSeat)
            end
        else
            pcall(function()
                hrp.CFrame = pinnedUseSeat.CFrame + Vector3.new(0, 1.5, 0)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
            if not useMachineRunning and now - lastUseMachine >= USE_MACHINE_INTERVAL then
                lastUseMachine = now
                useMachineRunning = true
                task.spawn(function()
                    fireUseMachine(pinnedUseSeat)
                    useMachineRunning = false
                end)
            end
        end
    else
        pcall(function()
            hrp.CFrame = pinnedUseSeat.CFrame + Vector3.new(0, 1.5, 0)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end)
        if not useMachineRunning and now - lastUseMachine >= USE_MACHINE_INTERVAL then
            lastUseMachine = now
            useMachineRunning = true
            task.spawn(function()
                fireUseMachine(pinnedUseSeat)
                useMachineRunning = false
            end)
        end
        if now - lastRemoteFire >= REMOTE_INTERVAL then
            lastRemoteFire = now
            fireRep(pinnedRepSeat)
        end
    end
end

local function startAutoFarm()
    if heartbeatConn then return end
    autoFarmEnabled = true
    undeitedhub.Toggles.gymAutoFarm = true
    saveAll()
    lastMachineCheck = 0
    lastRemoteFire = 0
    lastUseMachine = 0
    lastCharacter = nil
    refreshPinned()
    heartbeatConn = RunService.Heartbeat:Connect(onHeartbeat)
end

local function stopAutoFarm()
    autoFarmEnabled = false
    undeitedhub.Toggles.gymAutoFarm = false
    if heartbeatConn then
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end
    pinnedMachine = nil
    pinnedUseSeat = nil
    pinnedRepSeat = nil
    lastCharacter = nil
    saveAll()
end

local gymDropdown
local machineDropdown

local function applySelectionAndSave()
    undeitedhub.Toggles.gymSelectedGym = selectedGym
    undeitedhub.Toggles.gymSelectedMachine = selectedMachine
    saveAll()
end

local function refreshMachineDropdown(resetSelection)
    local options = buildMachineOptions(selectedGym)

    if resetSelection then
        selectedMachine = options[1] or ""
    else
        local current = findMachineOption(selectedGym, selectedMachine)
        if current then
            selectedMachine = current
        else
            selectedMachine = options[1] or ""
        end
    end

    pcall(function()
        machineDropdown:Refresh(options, true)
        machineDropdown:Set(selectedMachine)
    end)

    applySelectionAndSave()
end

gymDropdown = GymTab:Dropdown({
    Title = "Select Gym",
    Values = GYM_OPTIONS,
    Value = selectedGym,
    Callback = function(value)
        selectedGym = findOption(GYM_OPTIONS, value, GYM_OPTIONS[1])
        undeitedhub.Toggles.gymSelectedGym = selectedGym
        refreshMachineDropdown(true)
        refreshPinned()
    end
})

machineDropdown = GymTab:Dropdown({
    Title = "Select Machine",
    Values = buildMachineOptions(selectedGym),
    Value = selectedMachine,
    Callback = function(value)
        local resolved = findMachineOption(selectedGym, value)
        if resolved then
            selectedMachine = resolved
        else
            selectedMachine = value
        end
        applySelectionAndSave()
        refreshPinned()
    end
})

task.defer(function()
    pcall(function()
        gymDropdown:Set(selectedGym)
    end)
    task.wait(0.15)
    pcall(function()
        local options = buildMachineOptions(selectedGym)
        machineDropdown:Refresh(options, true)
        machineDropdown:Set(selectedMachine)
    end)
end)

GymTab:Toggle({
    Title = "Auto Farm",
    Value = autoFarmEnabled,
    Callback = function(state)
        if state then startAutoFarm() else stopAutoFarm() end
    end
})

if autoFarmEnabled then
    startAutoFarm()
end

applySelectionAndSave()

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoFarmEnabled then
        stopAutoFarm()
    end
    oldDisable()
end
