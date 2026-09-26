local WindUI = undeitedhub.WindUI
local GymTab = undeitedhub.Window:Tab({ Title = "Gym" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local function Notify(title, content, duration)
    duration = duration or 3
    if WindUI and type(WindUI.Notify) == "function" then
        pcall(WindUI.Notify, WindUI, { Title = title, Content = content, Duration = duration })
    else
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = title,
                Text = content,
                Duration = duration,
            })
        end)
    end
end

local GYMS = {
    ["Industrial Gym"] = {
        ["Bench 1 (62.5k)"] = {
            machineName = "Industrial Bench 1",
            benchName = "Bench",
            requiredStrength = 62500,
        },
        ["Bench 2 (125k)"] = {
            machineName = "Industrial Bench 2",
            benchName = "Bench",
            requiredStrength = 125000,
        },
        ["Bench 3 (250k)"] = {
            machineName = "Industrial Bench 3",
            benchName = "Bench",
            requiredStrength = 250000,
        },
    },
}

local MACHINE_OPTIONS = { "Auto (Best)", "Bench 1 (62.5k)", "Bench 2 (125k)", "Bench 3 (250k)" }

local selectedGym = "Industrial Gym"
local selectedMachine = "Auto (Best)"
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

local function formatNumber(n)
    if not n then return "?" end
    n = math.floor(n)
    if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(n)
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

local function resolveMachineKey()
    local gymData = GYMS[selectedGym]
    if not gymData then return nil end

    local myStrength = getStrength()

    if selectedMachine == "Auto (Best)" then
        local bestKey = nil
        local bestReq = -1
        for key, cfg in pairs(gymData) do
            if myStrength and myStrength >= cfg.requiredStrength then
                if cfg.requiredStrength > bestReq then
                    bestReq = cfg.requiredStrength
                    bestKey = key
                end
            end
        end
        return bestKey, myStrength
    end

    return selectedMachine, myStrength
end

local function runFarmCycle(silent)
    local folder = findMachinesFolder()
    if not folder then
        if not silent then Notify("Gym", "machinesFolder not found in Workspace") end
        return false, "no folder"
    end

    local gymData = GYMS[selectedGym]
    if not gymData then
        if not silent then Notify("Gym", "Unknown gym: " .. tostring(selectedGym)) end
        return false, "no gym"
    end

    local machineKey, myStrength = resolveMachineKey()
    if not machineKey then
        if not silent then
            local need = myStrength and "higher strength" or "unknown strength"
            Notify("Gym", "No bench available (need " .. need .. ")")
        end
        return false, "no bench available"
    end

    local config = gymData[machineKey]
    if not config then
        if not silent then Notify("Gym", "No config for " .. tostring(machineKey)) end
        return false, "no config"
    end

    if myStrength and myStrength < config.requiredStrength then
        if not silent then
            Notify(
                "Gym",
                "Need " .. formatNumber(config.requiredStrength) ..
                " strength (you have " .. formatNumber(myStrength) .. ")"
            )
        end
        return false, "not enough strength"
    end

    local machine = folder:FindFirstChild(config.machineName)
    if not machine then
        if not silent then Notify("Gym", "Machine not found: " .. config.machineName) end
        return false, "no machine"
    end

    local bench = machine:FindFirstChild(config.benchName)
    if not bench and machine.Name == config.benchName then
        bench = machine
    end
    local benchPart = getPartFromInstance(bench)
    if benchPart then
        teleportToPart(benchPart)
    elseif not silent then
        Notify("Gym", "Bench part not found inside " .. config.machineName)
    end

    local seats = collectInteractSeats(machine)
    if #seats == 0 then
        if not silent then Notify("Gym", "No interactSeat inside " .. config.machineName) end
        return false, "no seat"
    end

    local useSeat = seats[1]
    local repSeat = seats[2] or seats[1]

    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    local remote = rEvents and rEvents:FindFirstChild("machineInteractRemote")
    if remote then
        pcall(function()
            remote:InvokeServer("useMachine", useSeat)
        end)
    elseif not silent then
        Notify("Gym", "machineInteractRemote not found")
    end

    local muscleEvent = LocalPlayer:FindFirstChild("muscleEvent")
    if muscleEvent then
        pcall(function()
            muscleEvent:FireServer("rep", repSeat)
        end)
    elseif not silent then
        Notify("Gym", "muscleEvent not found on LocalPlayer")
    end

    return true, machineKey
end

local function startAutoFarm()
    if farmTask then return end
    autoFarmEnabled = true
    undeitedhub.Toggles.gymAutoFarm = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    farmTask = task.spawn(function()
        local firstCycle = true
        while autoFarmEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(runFarmCycle, firstCycle)
                firstCycle = false
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

GymTab:Button({
    Title = "Test Once",
    Callback = function()
        local ok, info = runFarmCycle(false)
        if ok then
            Notify("Gym", "Cycle ran on: " .. tostring(info))
        else
            Notify("Gym", "Cycle failed: " .. tostring(info))
        end
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
