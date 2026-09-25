local WindUI = undeitedhub.WindUI
local MiscTab = undeitedhub.Window:Tab({ Title = "Misc" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
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

MiscTab:Button({
    Title = "Delete All Toys",
    Callback = function()
        pcall(function()
            local player = Players.LocalPlayer
            if not player then
                SafeNotify({ Title = "Error", Content = "Local player not found", Duration = 2 })
                return
            end

            local destroyRemote = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")

            local playerFolderName = player.Name .. "SpawnedInToys"
            local playerFolder = Workspace:FindFirstChild(playerFolderName)
            if not playerFolder then
                SafeNotify({ Title = "Delete Toys", Content = "No toys found for you.", Duration = 2 })
                return
            end

            local toys = {}
            for _, child in ipairs(playerFolder:GetChildren()) do
                if child:IsA("Model") or child:IsA("BasePart") then
                    table.insert(toys, child)
                end
            end

            if #toys == 0 then
                SafeNotify({ Title = "Delete Toys", Content = "No toys found in your folder.", Duration = 2 })
                return
            end

            if destroyRemote and destroyRemote:IsA("RemoteEvent") then
                for _, toy in ipairs(toys) do
                    pcall(function()
                        destroyRemote:FireServer(toy)
                    end)
                end
                SafeNotify({ Title = "Delete Toys", Content = "Deleted " .. #toys .. " of your toys via remote.", Duration = 2 })
            else
                for _, toy in ipairs(toys) do
                    pcall(function()
                        toy:Destroy()
                    end)
                end
                SafeNotify({ Title = "Delete Toys", Content = "Deleted " .. #toys .. " of your toys locally.", Duration = 2 })
            end
        end)
    end
})

local HAMBURGER_TOY_NAME = "FoodHamburger"
local HAMBURGER_SPAM_INTERVAL = 0.05
local HAMBURGER_SPAWN_VECTOR = Vector3.new(0, -117.76699829101562, 0)
local HAMBURGER_DROP_VECTOR = Vector3.new(0, 170.93299865722656, 0)

local hamburgerSpamEnabled = undeitedhub.Toggles.hamburgerSpam or false
local hamburgerSpamTask = nil
local activeHamburger = nil

local function getToysFolder()
    return Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
end

local function getSpawnRemote()
    local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
    return menuToys and menuToys:FindFirstChild("SpawnToyRemoteFunction")
end

local function findAllHamburgers()
    local folder = getToysFolder()
    if not folder then return {} end
    local list = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name == HAMBURGER_TOY_NAME then
            table.insert(list, child)
        end
    end
    return list
end

local function findExistingHamburger()
    local list = findAllHamburgers()
    return list[1]
end

local function getHoldDropRemotes(hamburger)
    if not hamburger then return nil, nil end
    local holdPart = hamburger:FindFirstChild("HoldPart")
    if not holdPart then return nil, nil end
    local holdRemote = holdPart:FindFirstChild("HoldItemRemoteFunction")
    local dropRemote = holdPart:FindFirstChild("DropItemRemoteFunction")
    return holdRemote, dropRemote
end

local function spawnHamburger()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local spawnRemote = getSpawnRemote()
    if not spawnRemote then return nil end

    local spawnCFrame = hrp.CFrame * CFrame.new(0, 1.5, -3)
    pcall(function()
        spawnRemote:InvokeServer(HAMBURGER_TOY_NAME, spawnCFrame, HAMBURGER_SPAWN_VECTOR)
    end)

    for i = 1, 20 do
        task.wait()
        local h = findExistingHamburger()
        if h then return h end
    end
    return nil
end

local function getOrCreateHamburger()
    local existing = findExistingHamburger()
    if existing then return existing end
    return spawnHamburger()
end

local function spamGrabDrop(hamburger)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local holdRemote, dropRemote = getHoldDropRemotes(hamburger)
    if not holdRemote then return end

    pcall(function()
        holdRemote:InvokeServer(hamburger, char)
    end)

    if dropRemote then
        local dropCFrame = hrp.CFrame * CFrame.new(0, 1.5, -4)
        pcall(function()
            dropRemote:InvokeServer(hamburger, dropCFrame, HAMBURGER_DROP_VECTOR)
        end)
    end
end

local function startHamburgerSpam()
    if hamburgerSpamTask then return end
    hamburgerSpamEnabled = true
    undeitedhub.Toggles.hamburgerSpam = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    hamburgerSpamTask = task.spawn(function()
        local existing = findExistingHamburger()
        if existing then
            activeHamburger = existing
            SafeNotify({ Title = "Hamburger Spam", Content = "Using existing hamburger", Duration = 2 })
        else
            activeHamburger = spawnHamburger()
            if not activeHamburger then
                SafeNotify({ Title = "Hamburger Spam", Content = "Failed to spawn hamburger", Duration = 2 })
                hamburgerSpamEnabled = false
                undeitedhub.Toggles.hamburgerSpam = false
                hamburgerSpamTask = nil
                return
            end
        end

        while hamburgerSpamEnabled do
            if not activeHamburger or not activeHamburger.Parent then
                activeHamburger = getOrCreateHamburger()
                if not activeHamburger then
                    task.wait(0.5)
                    continue
                end
            end

            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(spamGrabDrop, activeHamburger)
            end

            task.wait(HAMBURGER_SPAM_INTERVAL)
        end

        activeHamburger = nil
        hamburgerSpamTask = nil
    end)
end

local function stopHamburgerSpam()
    hamburgerSpamEnabled = false
    undeitedhub.Toggles.hamburgerSpam = false
    if hamburgerSpamTask then
        task.cancel(hamburgerSpamTask)
        hamburgerSpamTask = nil
    end
    activeHamburger = nil
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

MiscTab:Toggle({
    Title = "Hamburger Spam",
    Value = hamburgerSpamEnabled,
    Callback = function(state)
        if state then
            startHamburgerSpam()
        else
            stopHamburgerSpam()
        end
        SafeNotify({
            Title = "Hamburger Spam",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if hamburgerSpamEnabled then
    startHamburgerSpam()
end

undeitedhub.DisableAll = undeitedhub.DisableAll or function() end
local oldDisable = undeitedhub.DisableAll
undeitedhub.DisableAll = function()
    if hamburgerSpamEnabled then
        stopHamburgerSpam()
    end
    oldDisable()
end
