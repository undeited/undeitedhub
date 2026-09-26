local WindUI = undeitedhub.WindUI
local GymTab = undeitedhub.Window:Tab({ Title = "Gym" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local MACHINES_FOLDER_NAME = "machinesFolder"

local GYMS = {
    ["Industrial Gym"] = {
        ["Bench"] = {
            teleportIndex = 138,
            teleportPart = "Bench",
            interactIndex = 126,
            repIndex = 157,
        },
    },
}

local selectedGym = "Industrial Gym"
local selectedMachine = "Bench"

local autoFarmEnabled = undeitedhub.Toggles.gymAutoFarm or false
local farmTask = nil
local FARM_COOLDOWN = 0.05

local function getMachinesFolder()
    return Workspace:FindFirstChild(MACHINES_FOLDER_NAME)
end

local function getMachineConfig(gym, machine)
    if not gym or not machine then return nil end
    local gymData = GYMS[gym]
    if not gymData then return nil end
    return gymData[machine]
end

local function getChildByIndex(folder, index)
    if not folder or not index then return nil end
    local children = folder:GetChildren()
    return children[index]
end

local function teleportToPart(part)
    if not part or not part:IsA("BasePart") then return false end
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
    local folder = getMachinesFolder()
    if not folder then return false end

    local config = getMachineConfig(selectedGym, selectedMachine)
    if not config then return false end

    local teleportChild = getChildByIndex(folder, config.teleportIndex)
    if teleportChild then
        local bench = teleportChild:FindFirstChild(config.teleportPart)
        if bench and bench:IsA("BasePart") then
            teleportToPart(bench)
        end
    end

    local interactChild = getChildByIndex(folder, config.interactIndex)
    if interactChild then
        local seat = interactChild:FindFirstChild("interactSeat")
        if seat then
            local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
            local remote = rEvents and rEvents:FindFirstChild("machineInteractRemote")
            if remote then
                pcall(function()
                    remote:InvokeServer("useMachine", seat)
                end)
            end
        end
    end

    local repChild = getChildByIndex(folder, config.repIndex)
    if repChild then
        local seat = repChild:FindFirstChild("interactSeat")
        if seat then
            local muscleEvent = LocalPlayer:FindFirstChild("muscleEvent")
            if muscleEvent then
                pcall(function()
                    muscleEvent:FireServer("rep", seat)
                end)
            end
        end
    end

    return true
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

local machineDropdown

GymTab:Dropdown({
    Title = "Select Gym",
    Values = { "Industrial Gym" },
    Value = selectedGym,
    Callback = function(value)
        selectedGym = value
        selectedMachine = "Bench"
        if machineDropdown then
            machineDropdown:Refresh({ "Bench" }, true)
        end
    end
})

machineDropdown = GymTab:Dropdown({
    Title = "Select Machine",
    Values = { "Bench" },
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
