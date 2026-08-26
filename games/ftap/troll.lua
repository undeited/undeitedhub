local WindUI = undeltedhub.WindUI
local utils = undeltedhub.Utils

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

local TrollTab = undeltedhub.Window:Tab({ Title = "Troll" })

TrollTab:Button({
    Title = "Spawn Missile",
    Callback = function()
        if _G.bombInProgress then
            SafeNotify({ Title = "Troll", Content = "A missile spawn is already in progress", Duration = 2 })
            return
        end

        _G.bombInProgress = true

        local oldError = error
        error = function(msg, level)
            if type(msg) == "string" and msg:find("attempt to index nil with 'Touched'") then
                return
            end
            oldError(msg, level)
        end

        if seterrorhandler then
            local oldHandler = errorhandler or function() end
            seterrorhandler(function(err, level)
                if type(err) == "string" and err:find("attempt to index nil with 'Touched'") then
                    return
                end
                oldHandler(err, level)
            end)
        end

        local function run()
            local Players = game:GetService("Players")
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local player = Players.LocalPlayer
            if not player then return end

            local character = player.Character or player.CharacterAdded:Wait()
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if not rootPart then return end

            local SpawnRemote = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction
            local ExplodeRemote = ReplicatedStorage.BombEvents.BombExplode
            local BombReplicator = ReplicatedStorage.BombEvents.BombReplicator
            local SetNetworkOwner = ReplicatedStorage.GrabEvents.SetNetworkOwner

            local function getBombsInPlayerFolder()
                local folder = workspace:FindFirstChild(player.Name .. "SpawnedInToys")
                if not folder then return {} end
                local bombs = {}
                for _, child in ipairs(folder:GetChildren()) do
                    if child:IsA("Model") and string.match(child.Name, "^BombMissile") then
                        if child:FindFirstChild("PartHitDetector", true) and child:FindFirstChild("Body", true) then
                            table.insert(bombs, child)
                        end
                    end
                end
                return bombs
            end

            local existingBombs = getBombsInPlayerFolder()

            local spawnResult = SpawnRemote:InvokeServer(
                "BombMissile",
                rootPart.CFrame,
                rootPart.Orientation or Vector3.new()
            )
            if spawnResult ~= "SpawnedToy" then return end

            local bombModel = nil
            local start = tick()
            repeat
                local currentBombs = getBombsInPlayerFolder()
                for _, bomb in ipairs(currentBombs) do
                    local isNew = true
                    for _, existing in ipairs(existingBombs) do
                        if bomb == existing then
                            isNew = false
                            break
                        end
                    end
                    if isNew then
                        bombModel = bomb
                        break
                    end
                end
                if bombModel then break end
                task.wait(0.05)
            until tick() - start > 4.0

            if not bombModel then return end

            local hitbox = bombModel:FindFirstChild("PartHitDetector", true)
            local body = bombModel:FindFirstChild("Body", true)
            if not hitbox or not body then return end

            local settleStart = tick()
            repeat
                local vel = body.AssemblyLinearVelocity
                if vel and vel.Magnitude < 1 then break end
                task.wait(0.1)
            until tick() - settleStart > 3.0

            pcall(function()
                SetNetworkOwner:FireServer(body, body.CFrame)
            end)
            task.wait(0.3)

            pcall(function() BombReplicator:FireServer() end)
            task.wait(0.2)
            pcall(function() BombReplicator:FireServer() end)
            task.wait(2.0)

            local explosionData = {
                Radius = 17.5,
                TimeLength = 0.5,
                Hitbox = hitbox,
                ExplodesByFire = true,
                MaxForcePerStudSquared = 225,
                Model = bombModel,
                ImpactSpeed = 100,
                ExplodesByPointy = false,
                DestroysModel = true,
                PositionPart = body
            }

            for attempt = 1, 7 do
                pcall(function()
                    ExplodeRemote:FireServer(explosionData, body.Position)
                end)
                task.wait(1.0)
                if not bombModel.Parent then break end
                if attempt < 7 then task.wait(0.5) end
            end

            task.wait(0.3)
        end

        pcall(run)
        _G.bombInProgress = false
    end
})