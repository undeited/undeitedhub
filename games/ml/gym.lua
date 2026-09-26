local WindUI = undeitedhub.WindUI
local GymTab = undeitedhub.Window:Tab({ Title = "Gym" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local GYMS = {
    ["Industrial Gym"] = {
        ["Bench (62.5k)"] = { machineName = "Industrial Bench", variantIndex = 1, requiredStrength = 62500 },
        ["Bench (125k)"] = { machineName = "Industrial Bench", variantIndex = 2, requiredStrength = 125000 },
        ["Bench (250k)"] = { machineName = "Industrial Bench", variantIndex = 3, requiredStrength = 250000 },
        ["Bar Lift (250k)"] = { machineName = "Industrial Bar Lift", variantIndex = 1, requiredStrength = 250000 },
        ["Boulder (187.5k)"] = { machineName = "Industrial Boulder", variantIndex = 1, requiredStrength = 187500 },
        ["Squat (125k)"] = { machineName = "Industrial Squat", variantIndex = 1, requiredStrength = 125000 },
        ["Squat (312.5k)"] = { machineName = "Industrial Squat", variantIndex = 2, requiredStrength = 312500 },
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
    if requiredStrength then
        for _, m in ipairs(matches) do
            local s = readMachineStrength(m)
            if s and math.abs(s - requiredStrength) < 1 then return m end
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
    if not config then return end
    local myStrength = getStrength()
    if myStrength and myStrength < config.requiredStrength then
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
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
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
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

GymTab:Dropdown({
    Title = "Select Gym",
    Values = { "Industrial Gym" },
    Value = selectedGym,
    Callback = function(value)
        selectedGym = value
        refreshPinned()
    end
})

GymTab:Dropdown({
    Title = "Select Machine",
    Values = MACHINE_OPTIONS,
    Value = selectedMachine,
    Callback = function(value)
        selectedMachine = value
        refreshPinned()
    end
})

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

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoFarmEnabled then
        stopAutoFarm()
    end
    oldDisable()
end
