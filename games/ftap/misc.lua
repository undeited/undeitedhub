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

-- ============================================================
-- INF Reach
-- ExtendGrabLine is only the visual beam. The server validates
-- distance when SetNetworkOwner fires, so we briefly move the
-- player next to the target while that remote is sent, then
-- snap back. We do NOT modify ExtendGrabLine anymore because
-- changing its value corrupts the game's grab state machine
-- and produces "Unable to cast CoordinateFrame to bool".
-- ============================================================
local infReachEnabled = undeitedhub.Toggles.infReachEnabled or false
local infReachHooked = false
local INF_GRAB_RANGE = 30
local INF_TELEPORT_HOLD = 0.2
local INF_TELEPORT_COOLDOWN = 0.15
local lastTeleportTime = 0

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

        if infReachEnabled
            and method == "FireServer"
            and typeof(self) == "Instance"
            and self.Name == "SetNetworkOwner"
        then
            -- Capture varargs into a local table so nested closures
            -- can still access them (varargs aren't available inside
            -- nested functions).
            local args = { ... }

            pcall(function()
                local targetPart = args[1]
                if typeof(targetPart) ~= "Instance" then return end
                if not targetPart:IsA("BasePart") then return end

                local now = tick()
                if now - lastTeleportTime < INF_TELEPORT_COOLDOWN then return end

                local char = game.Players.LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local dist = (targetPart.Position - hrp.Position).Magnitude
                if dist <= INF_GRAB_RANGE then return end

                lastTeleportTime = now

                local savedCFrame = hrp.CFrame
                local savedVelocity = hrp.AssemblyLinearVelocity

                hrp.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 5, 0))

                task.delay(INF_TELEPORT_HOLD, function()
                    local c = game.Players.LocalPlayer.Character
                    local h = c and c:FindFirstChild("HumanoidRootPart")
                    if h and h.Parent then
                        pcall(function()
                            h.CFrame = savedCFrame
                            h.AssemblyLinearVelocity = savedVelocity
                        end)
                    end
                end)
            end)
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
