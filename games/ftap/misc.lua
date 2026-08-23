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
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local Workspace = game:GetService("Workspace")
            local destroyRemote = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")

            local folders = {}
            for _, child in ipairs(Workspace:GetChildren()) do
                if child:IsA("Folder") and child.Name:match("SpawnedInToys$") then
                    table.insert(folders, child)
                end
            end

            local toys = {}
            for _, folder in ipairs(folders) do
                for _, obj in ipairs(folder:GetDescendants()) do
                    table.insert(toys, obj)
                end
            end

            if #toys == 0 then
                SafeNotify({ Title = "Delete Toys", Content = "No toys found.", Duration = 2 })
                return
            end

            if destroyRemote and destroyRemote:IsA("RemoteEvent") then
                for _, toy in ipairs(toys) do
                    pcall(function()
                        destroyRemote:FireServer(toy)
                    end)
                end
                SafeNotify({ Title = "Delete Toys", Content = "Deleted " .. #toys .. " toys via remote.", Duration = 2 })
            else
                for _, toy in ipairs(toys) do
                    pcall(function()
                        toy:Destroy()
                    end)
                end
                SafeNotify({ Title = "Delete Toys", Content = "Deleted " .. #toys .. " toys locally.", Duration = 2 })
            end
        end)
        if not success then
            SafeNotify({ Title = "Error", Content = "Failed to delete toys: " .. tostring(err), Duration = 3 })
        end
    end
})