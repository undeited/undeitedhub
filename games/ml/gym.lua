local WindUI = undeitedhub.WindUI
local GymTab = undeitedhub.Window:Tab({ Title = "Gym" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local GYM_DEFS = {
    { name = "Industrial Gym", prefix = "Industrial" },
    { name = "Jungle Gym",     prefix = "Jungle" },
    { name = "Frost Gym",      prefix = "Frost" },
    { name = "Legends Gym",    prefix = "Legends" },
    { name = "Mythical Gym",   prefix = "Mythical" },
    { name = "Eternal Gym",    prefix = "Eternal" },
}

local GYM_OPTIONS = {}
local GYM_PREFIXES = {}
for _, def in ipairs(GYM_DEFS) do
    table.insert(GYM_OPTIONS, def.name)
    GYM_PREFIXES[def.name] = def.prefix
end

local function findOption(list, value, fallback)
    if type(value) == "string" then
        for _, v in ipairs(list) do
            if v == value then return v end
        end
    end
    return fallback
end

local autoFarmEnabled = undeitedhub.Toggles.gymAutoFarm or false

local heartbeatConn = nil
local useMachineRunning = false

local selectedGym = findOption(GYM_OPTIONS, undeitedhub.Toggles.gymSelectedGym, GYM_OPTIONS[1])
local selectedMachineDisplay = undeitedhub.Toggles.gymSelectedMachine or ""

local pinnedMachine = nil
local pinnedUseSeat = nil
local pinnedRepSeat = nil

local machineOptionIndex = {}

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

local function formatStrength(v)
    if not v or v <= 0 then return "?" end
    if v >= 1e9 then return string.format("%.1fB", v / 1e9) end
    if v >= 1e6 then return string.format("%.1fM", v / 1e6) end
    if v >= 1e3 then return string.format("%.1fk", v / 1e3) end
    return tostring(v)
end

local function discoverMachines(gymName)
    local prefix = GYM_PREFIXES[gymName]
    if not prefix then return {} end
    local folder = findMachinesFolder()
    if not folder then return {} end

    local list = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") and child.Name:sub(1, #prefix) == prefix then
            local nextChar = child.Name:sub(#prefix + 1, #prefix + 1)
            if nextChar == "" or nextChar == " " or nextChar == "_" or nextChar == "-" then
                local strength = readMachineStrength(child) or 0
                table.insert(list, {
                    machine = child,
                    name = child.Name,
                    strength = strength,
                })
            end
        end
    end
    return list
end

local function buildMachineOptions(gymName)
    local prefix = GYM_PREFIXES[gymName] or ""
    local machines = discoverMachines(gymName)

    local groups = {}
    local order = {}
    for _, entry in ipairs(machines) do
        local base = entry.name
        if prefix ~= "" and base:sub(1, #prefix) == prefix then
            base = base:sub(#prefix + 1)
            base = base:gsub("^[%s_%-]+", "")
        end
        if base == "" then base = entry.name end
        if not groups[base] then
            groups[base] = {}
            table.insert(order, base)
        end
        table.insert(groups[base], entry)
    end

    table.sort(order)

    local options = {}
    local index = {}

    for _, base in ipairs(order) do
        local entries = groups[base]
        table.sort(entries, function(a, b)
            if a.strength ~= b.strength then return a.strength < b.strength end
            local pa = getInstancePosition(a.machine)
            local pb = getInstancePosition(b.machine)
            if pa.Y ~= pb.Y then return pa.Y < pb.Y end
            if pa.X ~= pb.X then return pa.X < pb.X end
            return pa.Z < pb.Z
        end)

        for i, entry in ipairs(entries) do
            local display = base .. " (" .. formatStrength(entry.strength) .. ")"
            if index[display] then
                display = display .. " #" .. i
            end
            local safety = 2
            while index[display] do
                display = base .. " (" .. formatStrength(entry.strength) .. ") #" .. i .. "." .. safety
                safety = safety + 1
            end
            index[display] = entry
            table.insert(options, display)
        end
    end

    return options, index
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
    if not selectedMachineDisplay or selectedMachineDisplay == "" then
        pinnedMachine = nil
        pinnedUseSeat = nil
        pinnedRepSeat = nil
        return
    end

    local _, index = buildMachineOptions(selectedGym)
    local entry = index[selectedMachineDisplay]
    if not entry or not entry.machine or not entry.machine.Parent then
        pinnedMachine = nil
        pinnedUseSeat = nil
        pinnedRepSeat = nil
        return
    end

    local myStrength = getStrength()
    local required = readMachineStrength(entry.machine) or 0
    if myStrength and required > 0 and myStrength < required then
        pinnedMachine = nil
        pinnedUseSeat = nil
        pinnedRepSeat = nil
        return
    end

    local seats = collectInteractSeats(entry.machine)
    if #seats == 0 then
        pinnedMachine = nil
        pinnedUseSeat = nil
        pinnedRepSeat = nil
        return
    end

    pinnedMachine = entry.machine
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

local gymDropdown
local machineDropdown

local function refreshMachineDropdown(preserveSelection)
    local options, index = buildMachineOptions(selectedGym)
    machineOptionIndex = index

    if preserveSelection and selectedMachineDisplay ~= "" and index[selectedMachineDisplay] then
        -- keep current selection
    elseif #options > 0 then
        selectedMachineDisplay = options[1]
    else
        selectedMachineDisplay = ""
    end

    pcall(function()
        machineDropdown:Refresh(options, true)
        machineDropdown:Set(selectedMachineDisplay)
    end)
end

gymDropdown = GymTab:Dropdown({
    Title = "Select Gym",
    Values = GYM_OPTIONS,
    Value = selectedGym,
    Callback = function(value)
        selectedGym = findOption(GYM_OPTIONS, value, GYM_OPTIONS[1])
        undeitedhub.Toggles.gymSelectedGym = selectedGym
        selectedMachineDisplay = ""
        refreshMachineDropdown(false)
        undeitedhub.Toggles.gymSelectedMachine = selectedMachineDisplay
        if undeitedhub.SaveSettings then pcall(undeitedhub.SaveSettings) end
        refreshPinned()
    end
})

machineDropdown = GymTab:Dropdown({
    Title = "Select Machine",
    Values = {},
    Value = "",
    Callback = function(value)
        selectedMachineDisplay = value
        undeitedhub.Toggles.gymSelectedMachine = selectedMachineDisplay
        if undeitedhub.SaveSettings then pcall(undeitedhub.SaveSettings) end
        refreshPinned()
    end
})

task.defer(function()
    pcall(function()
        gymDropdown:Set(selectedGym)
    end)
    task.wait(0.1)
    local options, index = buildMachineOptions(selectedGym)
    machineOptionIndex = index
    if selectedMachineDisplay ~= "" and index[selectedMachineDisplay] then
        pcall(function()
            machineDropdown:Refresh(options, true)
            machineDropdown:Set(selectedMachineDisplay)
        end)
    elseif #options > 0 then
        selectedMachineDisplay = options[1]
        pcall(function()
            machineDropdown:Refresh(options, true)
            machineDropdown:Set(selectedMachineDisplay)
        end)
    else
        pcall(function()
            machineDropdown:Refresh(options, true)
        end)
    end
    undeitedhub.Toggles.gymSelectedMachine = selectedMachineDisplay
    if undeitedhub.SaveSettings then pcall(undeitedhub.SaveSettings) end
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

undeitedhub.Toggles.gymSelectedGym = selectedGym
if undeitedhub.SaveSettings then
    pcall(undeitedhub.SaveSettings)
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoFarmEnabled then
        stopAutoFarm()
    end
    oldDisable()
end
