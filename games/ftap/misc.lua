local WindUI = undeitedhub.WindUI
local MiscTab = undeitedhub.Window:Tab({ Title = "Misc" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

MiscTab:Button({
    Title = "Delete All Toys",
    Callback = function()
        pcall(function()
            local player = Players.LocalPlayer
            if not player then return end

            local destroyRemote = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")

            local playerFolderName = player.Name .. "SpawnedInToys"
            local playerFolder = Workspace:FindFirstChild(playerFolderName)
            if not playerFolder then return end

            local toys = {}
            for _, child in ipairs(playerFolder:GetChildren()) do
                if child:IsA("Model") or child:IsA("BasePart") then
                    table.insert(toys, child)
                end
            end

            if #toys == 0 then return end

            if destroyRemote and destroyRemote:IsA("RemoteEvent") then
                for _, toy in ipairs(toys) do
                    pcall(function()
                        destroyRemote:FireServer(toy)
                    end)
                end
            else
                for _, toy in ipairs(toys) do
                    pcall(function()
                        toy:Destroy()
                    end)
                end
            end
        end)
    end
})

local fartherReachEnabled = false
local diedHandle = nil

local function ReloadScript()
    if LocalPlayer.Character then
        local grabbing = LocalPlayer.Character:FindFirstChild("GrabbingScript")
        if grabbing then
            grabbing.Enabled = false
            grabbing.Enabled = true
        end
    end
end

local function ToggleFartherReach(state)
    fartherReachEnabled = state
    
    if state then
        local lineTexture = LocalPlayer:FindFirstChild("FartherReach")
        if lineTexture then lineTexture:Destroy() end

        local newTexture = Instance.new("BoolValue")
        newTexture.Name = "FartherReach"
        newTexture.Value = true
        newTexture.Parent = LocalPlayer

        local gamepassEvents = ReplicatedStorage:FindFirstChild("GamepassEvents")
        local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
        
        if gamepassEvents and menuToys then
            local scriptNotify = gamepassEvents:FindFirstChild("FurtherReachBoughtNotifier")
            local activator = menuToys:FindFirstChild("LimitedTimeToyEvent")
            
            if scriptNotify and activator then
                scriptNotify.Parent = ReplicatedFirst
                activator.Parent = gamepassEvents
                activator.Name = "FurtherReachBoughtNotifier"

                ReloadScript()
                task.delay(0.1, function()
                    pcall(function() activator:FireServer() end)
                end)
            end
        end

        if diedHandle then diedHandle:Disconnect() end
        diedHandle = LocalPlayer.CharacterAdded:Connect(function(Character)
            Character:WaitForChild("GrabbingScript")
            ToggleFartherReach(false)
            task.wait(0.1)
            ToggleFartherReach(true)
        end)
    else
        local lineTexture = LocalPlayer:FindFirstChild("FartherReach")
        if lineTexture then lineTexture:Destroy() end

        local gamepassEvents = ReplicatedStorage:FindFirstChild("GamepassEvents")
        local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
        
        if gamepassEvents and menuToys then
            local scriptNotify = gamepassEvents:FindFirstChild("FurtherReachBoughtNotifier")
            if not scriptNotify then
                scriptNotify = gamepassEvents:FindFirstChild("LimitedTimeToyEvent")
            end
            
            local activator = menuToys:FindFirstChild("LimitedTimeToyEvent")
            if not activator then
                activator = menuToys:FindFirstChild("FurtherReachBoughtNotifier")
            end

            if scriptNotify then
                scriptNotify.Parent = gamepassEvents
            end
            
            if activator then
                activator.Name = "LimitedTimeToyEvent"
                activator.Parent = menuToys
            end
        end

        ReloadScript()
        
        if diedHandle then
            diedHandle:Disconnect()
            diedHandle = nil
        end
    end
end

MiscTab:Button({
    Title = "Free Farther Reach Gamepass",
    Callback = function()
        fartherReachEnabled = not fartherReachEnabled
        ToggleFartherReach(fartherReachEnabled)
        
        pcall(function()
            WindUI:Notify({
                Title = "Free Farther Reach",
                Content = fartherReachEnabled and "Enabled" or "Disabled",
                Duration = 2,
            })
        end)
    end
})

undeitedhub.DisableAll = undeitedhub.DisableAll or function() end
local oldDisable = undeitedhub.DisableAll
undeitedhub.DisableAll = function()
    if fartherReachEnabled then
        ToggleFartherReach(false)
    end
    oldDisable()
end
