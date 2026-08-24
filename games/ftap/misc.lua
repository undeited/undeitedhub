local WindUI = bandithub.WindUI

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

local MiscTab = bandithub.Window:Tab({ Title = "Misc" })

MiscTab:Button({
    Title = "Delete All Toys",
    Callback = function()
        local success, err = pcall(function()
            local Players = game:GetService("Players")
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local Workspace = game:GetService("Workspace")
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
        if not success then
            SafeNotify({ Title = "Error", Content = "Failed to delete toys: " .. tostring(err), Duration = 3 })
        end
    end
})

local antiVoidEnabled = bandithub.Toggles.antiVoidEnabled or false
local antiVoidLoop = nil

local function StartAntiVoid()
    if antiVoidLoop then return end

    local Workspace = game:GetService("Workspace")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    if not player then return end

    local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
    local deathBarrierHeight = Workspace.FallenPartsDestroyHeight
    if not deathBarrierHeight then
        deathBarrierHeight = -500
    end

    local threshold = 50
    local teleportOffset = Vector3.new(0, 3, 0)
    local safePos = Vector3.new(0, 50, 0)

    antiVoidLoop = task.spawn(function()
        while antiVoidEnabled do
            if _G.BANDITHUB_WINDOW_VISIBLE then
                local char = player.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local pos = root.Position
                        if pos.Y <= deathBarrierHeight + threshold then
                            if spawnLocation then
                                pcall(function()
                                    root.CFrame = spawnLocation.CFrame + teleportOffset
                                end)
                            else
                                pcall(function()
                                    root.CFrame = CFrame.new(safePos)
                                end)
                            end
                        end
                    end
                end
            end
            task.wait(0.1)
        end
        antiVoidLoop = nil
    end)
end

local function StopAntiVoid()
    if antiVoidLoop then
        task.cancel(antiVoidLoop)
        antiVoidLoop = nil
    end
end

local function ToggleAntiVoid(state)
    antiVoidEnabled = state
    bandithub.Toggles.antiVoidEnabled = state
    if bandithub.SaveSettings then bandithub.SaveSettings() end

    if state then
        StartAntiVoid()
        SafeNotify({ Title = "Anti Void", Content = "Enabled", Duration = 2 })
    else
        StopAntiVoid()
        SafeNotify({ Title = "Anti Void", Content = "Disabled", Duration = 2 })
    end
end

MiscTab:Toggle({
    Title = "Anti Void",
    Value = antiVoidEnabled,
    Callback = function(state)
        ToggleAntiVoid(state)
    end
})

bandithub.DisableAll = bandithub.DisableAll or function() end
local oldDisable = bandithub.DisableAll
bandithub.DisableAll = function()
    if antiVoidEnabled then
        StopAntiVoid()
        antiVoidEnabled = false
        bandithub.Toggles.antiVoidEnabled = false
        if bandithub.SaveSettings then bandithub.SaveSettings() end
    end
    oldDisable()
end
