local WindUI = undeitedhub.WindUI
local MiscTab = undeitedhub.Window:Tab({ Title = "Misc" })

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
    end
})

local infReachEnabled = undeitedhub.Toggles.infReachEnabled or false
local infReachHooked = false
local INF_REACH_DISTANCE = 1e6

local function SetupInfReach()
    if infReachHooked then return end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        SafeNotify({
            Title = "INF Reach",
            Content = "Executor does not support hookmetamethod.",
            Duration = 4,
        })
        return
    end

    local oldNamecall
    local hookFn = function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer"
            and infReachEnabled
            and typeof(self) == "Instance"
            and self.Name == "ExtendGrabLine"
        then
            local args = { ... }
            if type(args[1]) == "number" then
                return oldNamecall(self, INF_REACH_DISTANCE)
            end
        end
        return oldNamecall(self, ...)
    end

    if type(newcclosure) == "function" then
        hookFn = newcclosure(hookFn)
    end

    oldNamecall = hookmetamethod(game, "__namecall", hookFn)
    infReachHooked = true
end

MiscTab:Toggle({
    Title = "INF Reach",
    Value = infReachEnabled,
    Callback = function(state)
        infReachEnabled = state
        undeitedhub.Toggles.infReachEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

        if state then
            SetupInfReach()
        end

        SafeNotify({
            Title = "INF Reach",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if infReachEnabled then
    task.spawn(function()
        task.wait(0.5)
        SetupInfReach()
    end)
end

undeitedhub.DisableAll = undeitedhub.DisableAll or function() end
local oldDisable = undeitedhub.DisableAll
undeitedhub.DisableAll = function()
    infReachEnabled = false
    undeitedhub.Toggles.infReachEnabled = false
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    oldDisable()
end
