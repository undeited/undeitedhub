local WindUI = bandithub.WindUI
local FarmTab = bandithub.Window:Tab({ Title = "Auto Farm" })

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

local LocalPlayer = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
local muscleEvent = LocalPlayer:FindFirstChild("muscleEvent")

local function GetRebirthRemote()
    if not rEvents then return nil end
    local remote = rEvents:FindFirstChild("rebirthRemote")
    if remote and remote:IsA("RemoteFunction") then
        return remote
    end
    local success, result = pcall(function()
        return rEvents:WaitForChild("rebirthRemote", 5)
    end)
    if success and result and result:IsA("RemoteFunction") then
        return result
    end
    return nil
end

local function GetStrength()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local strength = leaderstats:FindFirstChild("Strength")
        if strength then return strength.Value end
    end
    return 0
end

local function GetRebirths()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local rebirths = leaderstats:FindFirstChild("Rebirths")
        if rebirths then return rebirths.Value end
    end
    return 0
end

local function CalculateRequiredRebirthStrength(rebirths)
    return 100 + rebirths * 50
end

local exerciseList = {
    "Weight",
    "Handstands",
    "Pushups",
    "Situps"
}

local selectedExercise = exerciseList[1]
local autoTrainEnabled = false
local trainTask = nil
local TRAIN_COOLDOWN = 0.5

local function EquipTool(toolName)
    local player = game.Players.LocalPlayer
    if not player then return false end
    local char = player.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    if char:FindFirstChild(toolName) then
        return true
    end

    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local tool = backpack:FindFirstChild(toolName)
        if tool and tool:IsA("Tool") then
            humanoid:EquipTool(tool)
            return true
        end
    end
    return false
end

local function DoRep()
    if not muscleEvent or not muscleEvent:IsA("RemoteEvent") then
        SafeNotify({ Title = "Auto Train", Content = "muscleEvent not found", Duration = 2 })
        return
    end

    local equipped = EquipTool(selectedExercise)
    if not equipped then
        SafeNotify({ Title = "Auto Train", Content = "Tool not found: " .. selectedExercise, Duration = 2 })
        return
    end

    task.wait(0.1)

    pcall(function()
        muscleEvent:FireServer("rep")
    end)
end

local function StartTraining()
    if trainTask then return end
    autoTrainEnabled = true
    bandithub.Toggles.autoTrainEnabled = true
    if bandithub.SaveSettings then bandithub.SaveSettings() end
    SafeNotify({ Title = "Auto Train", Content = "Enabled (" .. selectedExercise .. ")", Duration = 2 })
    trainTask = task.spawn(function()
        while autoTrainEnabled do
            if not _G.BANDITHUB_WINDOW_VISIBLE then
                task.wait(0.5)
                continue
            end
            DoRep()
            task.wait(TRAIN_COOLDOWN)
        end
    end)
end

local function StopTraining()
    autoTrainEnabled = false
    bandithub.Toggles.autoTrainEnabled = false
    if trainTask then
        task.cancel(trainTask)
        trainTask = nil
    end
    if bandithub.SaveSettings then bandithub.SaveSettings() end
    SafeNotify({ Title = "Auto Train", Content = "Disabled", Duration = 2 })
end

FarmTab:Dropdown({
    Title = "Exercise",
    Values = exerciseList,
    Default = exerciseList[1],
    Callback = function(value)
        selectedExercise = value
        if autoTrainEnabled then
            StopTraining()
            task.wait(0.2)
            StartTraining()
        end
    end
})

FarmTab:Toggle({
    Title = "Auto Train",
    Value = bandithub.Toggles.autoTrainEnabled or false,
    Callback = function(state)
        if state then StartTraining() else StopTraining() end
    end
})

local autoRebirthEnabled = false
local rebirthTask = nil
local REBIRTH_COOLDOWN = 2

local function DoRebirth()
    if not _G.BANDITHUB_WINDOW_VISIBLE then return end
    local rebirthRemote = GetRebirthRemote()
    if not rebirthRemote then
        SafeNotify({ Title = "Rebirth", Content = "Rebirth remote not found", Duration = 2 })
        return
    end
    local strength = GetStrength()
    local rebirths = GetRebirths()
    local required = CalculateRequiredRebirthStrength(rebirths)
    if strength >= required then
        pcall(function()
            local success, result = rebirthRemote:InvokeServer("rebirthRequest")
            if success then
                SafeNotify({ Title = "Rebirth", Content = "Rebirthed successfully!", Duration = 2 })
            else
                SafeNotify({ Title = "Rebirth", Content = "Rebirth failed", Duration = 2 })
            end
        end)
    end
end

local function StartAutoRebirth()
    if rebirthTask then return end
    autoRebirthEnabled = true
    bandithub.Toggles.autoRebirthEnabled = true
    if bandithub.SaveSettings then bandithub.SaveSettings() end
    SafeNotify({ Title = "Auto Rebirth", Content = "Enabled", Duration = 2 })
    rebirthTask = task.spawn(function()
        while autoRebirthEnabled do
            if not _G.BANDITHUB_WINDOW_VISIBLE then
                task.wait(0.5)
                continue
            end
            DoRebirth()
            task.wait(REBIRTH_COOLDOWN)
        end
    end)
end

local function StopAutoRebirth()
    autoRebirthEnabled = false
    bandithub.Toggles.autoRebirthEnabled = false
    if rebirthTask then
        task.cancel(rebirthTask)
        rebirthTask = nil
    end
    if bandithub.SaveSettings then bandithub.SaveSettings() end
    SafeNotify({ Title = "Auto Rebirth", Content = "Disabled", Duration = 2 })
end

FarmTab:Toggle({
    Title = "Auto Rebirth",
    Value = bandithub.Toggles.autoRebirthEnabled or false,
    Callback = function(state)
        if state then StartAutoRebirth() else StopAutoRebirth() end
    end
})

FarmTab:Button({
    Title = "Rebirth Now",
    Callback = function()
        DoRebirth()
    end
})

local oldDisable = bandithub.DisableAll
bandithub.DisableAll = function()
    StopTraining()
    StopAutoRebirth()
    if oldDisable then oldDisable() end
end