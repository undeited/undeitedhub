-- ============================================================
-- Combined script for Fling Things And People (FTAP)
-- ============================================================

local BASE_URL = "https://raw.githubusercontent.com/undeited/undeitedhub/main/"

local function HttpGet(url)
    if game and type(game.HttpGet) == "function" then
        return game:HttpGet(url)
    end
    if game and type(game.HttpGetAsync) == "function" then
        return game:HttpGetAsync(url)
    end
    error("Unsupported executor: missing game:HttpGet or game:HttpGetAsync")
end

local function LoadString(script, chunkName)
    if type(loadstring) == "function" then
        return loadstring(script, chunkName)
    end
    if type(load) == "function" then
        return load(script, chunkName)
    end
    error("Unsupported executor: missing loadstring or load")
end

local function LoadScript(name)
    local script = HttpGet(BASE_URL .. name)
    local fn, err = LoadString(script, name)
    if not fn then error(err) end
    return fn()
end

local function CheckExecutor()
    local missing = {}
    if not game then table.insert(missing, "game") end
    if not Instance then table.insert(missing, "Instance") end
    if not task then table.insert(missing, "task") end
    if not pcall then table.insert(missing, "pcall") end
    if not (type(loadstring) == "function" or type(load) == "function") then table.insert(missing, "loadstring/load") end
    if not (game and (type(game.HttpGet) == "function" or type(game.HttpGetAsync) == "function")) then table.insert(missing, "game:HttpGet or game:HttpGetAsync") end
    if #missing > 0 then
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Executor Incompatible",
                Text = "Missing executor support: " .. table.concat(missing, ", "),
                Duration = 5,
            })
        end)
        return false
    end
    return true
end

if not CheckExecutor() then return end

local GAME_FOLDER = "ftap"

local WindUI = LoadScript("shared/windui.lua")
local utils = LoadScript("shared/utils.lua")
local config = LoadScript("shared/config.lua")
local MathUtils = LoadScript("shared/math_utils.lua")

undeitedhub = undeitedhub or {}
undeitedhub.WindUI = WindUI
undeitedhub.Utils = utils
undeitedhub.Config = config
undeitedhub.MathUtils = MathUtils
undeitedhub.Toggles = undeitedhub.Toggles or {}
undeitedhub.SettingsFile = "undeitedhub/" .. GAME_FOLDER .. "/settings.json"

local function ResolveThemeName(themeName)
    local available = config and config.themes or { "Default" }
    if type(themeName) ~= "string" or themeName == "" then
        return available[1] or "Default"
    end
    if themeName == "Undelted" then
        return "Default"
    end
    for _, name in ipairs(available) do
        if name == themeName then
            return name
        end
    end
    return available[1] or "Default"
end

local function LoadSettings()
    pcall(function()
        if isfile and isfile(undeitedhub.SettingsFile) then
            local data = game:GetService("HttpService"):JSONDecode(readfile(undeitedhub.SettingsFile))
            if data then
                if data.toggles then
                    for k, v in pairs(data.toggles) do
                        undeitedhub.Toggles[k] = v
                    end
                end
                if data.theme then
                    undeitedhub.CurrentTheme = ResolveThemeName(data.theme)
                end
                if data.toggleKey then
                    undeitedhub.ToggleKey = data.toggleKey
                end
                if data.walkSpeed then config.walkSpeed = data.walkSpeed end
                if data.jumpPower then config.jumpPower = data.jumpPower end
                return
            end
        end

        if _G.UNDEITEDHUB_STORAGE and _G.UNDEITEDHUB_STORAGE[game.PlaceId] then
            local stored = _G.UNDEITEDHUB_STORAGE[game.PlaceId]
            if stored.toggles then
                for k, v in pairs(stored.toggles) do
                    undeitedhub.Toggles[k] = v
                end
            end
            if stored.theme then
                undeitedhub.CurrentTheme = ResolveThemeName(stored.theme)
            end
            if stored.toggleKey then
                undeitedhub.ToggleKey = stored.toggleKey
            end
            if stored.walkSpeed then config.walkSpeed = stored.walkSpeed end
            if stored.jumpPower then config.jumpPower = stored.jumpPower end
        end
    end)
end

local function SaveSettings()
    pcall(function()
        local data = {
            toggles = undeitedhub.Toggles,
            theme = ResolveThemeName(undeitedhub.CurrentTheme or "Default"),
            toggleKey = undeitedhub.ToggleKey or config.toggleKey or "K",
            walkSpeed = config.walkSpeed,
            jumpPower = config.jumpPower,
        }

        if writefile and makefolder then
            makefolder("undeitedhub")
            makefolder("undeitedhub/" .. GAME_FOLDER)
            writefile(undeitedhub.SettingsFile, game:GetService("HttpService"):JSONEncode(data))
        end

        _G.UNDEITEDHUB_STORAGE = _G.UNDEITEDHUB_STORAGE or {}
        _G.UNDEITEDHUB_STORAGE[game.PlaceId] = data
    end)
end

LoadSettings()
undeitedhub.ToggleKey = undeitedhub.ToggleKey or config.toggleKey or "K"

local themeToApply = ResolveThemeName(undeitedhub.CurrentTheme or "Default")
WindUI:SetTheme(themeToApply)

local Window = WindUI:CreateWindow({
    Title = "Undeited Hub",
    Author = "by undeited",
    Folder = "undeitedhub/" .. GAME_FOLDER,
    Size = UDim2.fromOffset(580, 460),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(850, 560),
    Transparent = true,
    Theme = themeToApply,
    Resizable = true,
    SideBarWidth = 200,
    HideSearchBar = true,
    ScrollBarEnabled = false,
})

Window:SetToggleKey(Enum.KeyCode[undeitedhub.ToggleKey])

undeitedhub.Window = Window
undeitedhub.SaveSettings = SaveSettings
undeitedhub.LoadSettings = LoadSettings

_G.UNDEITEDHUB_WINDOW_VISIBLE = true
local frame = Window.Frame
if frame then
    frame:GetPropertyChangedSignal("Visible"):Connect(function()
        _G.UNDEITEDHUB_WINDOW_VISIBLE = frame.Visible
    end)
    frame.AncestryChanged:Connect(function()
        if not frame.Parent then
            if undeitedhub.DisableAll then
                undeitedhub.DisableAll()
            end
        end
    end)
end

-- ============================================================
-- VISUAL TAB (ESP)
-- ============================================================
do
    local VisualTab = Window:Tab({ Title = "Visual" })
    local espEnabled = undeitedhub.Toggles.espEnabled or false
    local highlightMap = {}
    local ESP_COLOR = Color3.fromRGB(255, 0, 0)

    local function ClearESP()
        for _, highlight in pairs(highlightMap) do
            if highlight and highlight.Parent then
                pcall(highlight.Destroy, highlight)
            end
        end
        highlightMap = {}
    end

    local function UpdateESP()
        if not espEnabled or not _G.UNDEITEDHUB_WINDOW_VISIBLE then
            ClearESP()
            return
        end

        local localPlayer = game.Players.LocalPlayer
        local seen = {}

        for _, player in ipairs(game.Players:GetPlayers()) do
            if player ~= localPlayer and player.Character and player.Character.Parent then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local highlight = highlightMap[player]
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "UndeitedSP"
                        highlight.FillColor = ESP_COLOR
                        highlight.FillTransparency = 0.5
                        highlight.OutlineColor = ESP_COLOR
                        highlight.OutlineTransparency = 0.2
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.Parent = player.Character
                        highlightMap[player] = highlight
                    end
                    highlight.Adornee = player.Character
                    highlight.Enabled = true
                    seen[player] = true
                end
            end
        end

        for player, highlight in pairs(highlightMap) do
            if not seen[player] and highlight and highlight.Parent then
                pcall(highlight.Destroy, highlight)
                highlightMap[player] = nil
            end
        end
    end

    local function RefreshESP()
        pcall(UpdateESP)
    end

    VisualTab:Toggle({
        Title = "ESP Highlight",
        Value = espEnabled,
        Callback = function(state)
            espEnabled = state
            undeitedhub.Toggles.espEnabled = state
            if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
            WindUI:Notify({ Title = "ESP", Content = state and "Enabled" or "Disabled", Duration = 2 })
            if not espEnabled then ClearESP() else UpdateESP() end
        end
    })

    local function ConnectPlayer(player)
        if not player then return end
        player.CharacterAdded:Connect(function()
            task.wait(0.2)
            RefreshESP()
        end)
        player.CharacterRemoving:Connect(RefreshESP)
    end

    for _, player in ipairs(game.Players:GetPlayers()) do
        ConnectPlayer(player)
    end

    game.Players.PlayerAdded:Connect(ConnectPlayer)
    game.Players.PlayerRemoving:Connect(function(player)
        local highlight = highlightMap[player]
        if highlight and highlight.Parent then
            pcall(highlight.Destroy, highlight)
        end
        highlightMap[player] = nil
    end)

    task.spawn(function()
        while true do
            task.wait(0.5)
            pcall(UpdateESP)
        end
    end)

    local oldDisable = undeitedhub.DisableAll or function() end
    undeitedhub.DisableAll = function()
        espEnabled = false
        undeitedhub.Toggles.espEnabled = false
        ClearESP()
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        oldDisable()
    end
end

-- ============================================================
-- COMBAT TAB (Auto Swing)
-- ============================================================
do
    local CombatTab = Window:Tab({ Title = "Combat" })

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local AeroServices = ReplicatedStorage:WaitForChild("Aero"):WaitForChild("AeroRemoteServices"):WaitForChild("GameService")
    local AttackStart = AeroServices:WaitForChild("WeaponAttackStart")
    local AnimComplete = AeroServices:WaitForChild("WeaponAnimComplete")

    local autoSwingEnabled = undeitedhub.Toggles.AutoSwing or false
    local lastSwingTime = 0
    local SWING_COOLDOWN = 0.1

    local function SwingWeapon()
        AttackStart:FireServer()
        AnimComplete:FireServer()
        if typeof(getNil) == "function" then
            pcall(function()
                getNil("Event", "BindableEvent"):Fire()
            end)
        end
    end

    game:GetService("RunService").Heartbeat:Connect(function()
        if autoSwingEnabled and _G.UNDEITEDHUB_WINDOW_VISIBLE then
            local now = tick()
            if now - lastSwingTime >= SWING_COOLDOWN then
                lastSwingTime = now
                pcall(SwingWeapon)
            end
        end
    end)

    CombatTab:Toggle({
        Title = "Auto Swing",
        Value = autoSwingEnabled,
        Callback = function(state)
            autoSwingEnabled = state
            undeitedhub.Toggles.AutoSwing = state
            if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
            WindUI:Notify({ Title = "Auto Swing", Content = state and "Enabled" or "Disabled", Duration = 2 })
            if state then lastSwingTime = tick() end
        end
    })

    local oldDisable = undeitedhub.DisableAll or function() end
    undeitedhub.DisableAll = function()
        autoSwingEnabled = false
        undeitedhub.Toggles.AutoSwing = false
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        oldDisable()
    end
end

-- ============================================================
-- MISC TAB (Delete Toys + Anti Void)
-- ============================================================
do
    local MiscTab = Window:Tab({ Title = "Misc" })

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

    local antiVoidEnabled = undeitedhub.Toggles.antiVoidEnabled or false
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
                if _G.UNDEITEDHUB_WINDOW_VISIBLE then
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
        undeitedhub.Toggles.antiVoidEnabled = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

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

    local oldDisable = undeitedhub.DisableAll or function() end
    undeitedhub.DisableAll = function()
        if antiVoidEnabled then
            StopAntiVoid()
            antiVoidEnabled = false
            undeitedhub.Toggles.antiVoidEnabled = false
            if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        end
        oldDisable()
    end
end

-- ============================================================
-- TROLL TAB (Spawn Missile)
-- ============================================================
do
    local TrollTab = Window:Tab({ Title = "Troll" })

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
end

-- ============================================================
-- BLOBMAN TAB (Auto Grab Nearest)
-- ============================================================
do
    local BlobmanTab = Window:Tab({ Title = "Blobman" })

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

    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Workspace = game:GetService("Workspace")
    local VirtualInputManager = game:GetService("VirtualInputManager")

    local grabEnabled = undeitedhub.Toggles.autoGrabPlayers or false
    local grabTask = nil

    local INTERACT_KEY = Enum.KeyCode.F
    local PROXIMITY_RANGE = 20
    local CHECK_DELAY = 0.5

    local leftHeldTarget = nil
    local rightHeldTarget = nil
    local toyFolder = nil

    local function updateToyFolder()
        toyFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    end
    updateToyFolder()
    Workspace.DescendantAdded:Connect(function(child)
        if child.Name == LocalPlayer.Name .. "SpawnedInToys" then
            toyFolder = child
        end
    end)

    local function getNearestUnheldPlayer(blobmanModel, excludeLeft, excludeRight)
        local rootPart = blobmanModel:FindFirstChild("HumanoidRootPart")
        if not rootPart then return nil end

        local pivotPoint = rootPart.Position
        local best = nil
        local bestDist = math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            if not char then continue end
            local targetRoot = char:FindFirstChild("HumanoidRootPart")
            local targetHum = char:FindFirstChildOfClass("Humanoid")
            if not targetRoot or not targetHum or targetHum.Health <= 0 then continue end
            if char:FindFirstChildOfClass("ForceField") then continue end
            if char == excludeLeft or char == excludeRight then continue end

            local dist = (pivotPoint - targetRoot.Position).Magnitude
            if dist < PROXIMITY_RANGE and dist < bestDist then
                best = char
                bestDist = dist
            end
        end
        return best
    end

    local function manageBlobmanSeating()
        local char = LocalPlayer.Character
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp or hum.Health <= 0 then return nil end

        if hum.SeatPart and hum.SeatPart.Name == "VehicleSeat" and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
            return hum.SeatPart.Parent
        end

        if not toyFolder then return nil end

        for _, blobman in ipairs(toyFolder:GetChildren()) do
            if blobman.Name == "CreatureBlobman" then
                local seat = blobman:FindFirstChild("VehicleSeat")
                if seat and (not seat.Occupant or seat.Occupant == hum) then
                    local camera = Workspace.CurrentCamera
                    hrp.CFrame = seat.CFrame + Vector3.new(0, 1.5, 0)
                    task.wait(0.05)
                    camera.CFrame = CFrame.new(camera.CFrame.Position, seat.Position)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(true, INTERACT_KEY, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, INTERACT_KEY, false, game)
                    task.wait(0.3)
                    if hum.SeatPart and hum.SeatPart.Parent == blobman then
                        return blobman
                    end
                end
            end
        end
        return nil
    end

    local function startGrabLoop()
        if grabTask then return end
        grabEnabled = true
        undeitedhub.Toggles.autoGrabPlayers = true
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Auto Grab Nearest", Content = "Enabled", Duration = 2 })

        grabTask = task.spawn(function()
            while grabEnabled do
                if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                    local blobman = manageBlobmanSeating()
                    if blobman then
                        local leftDetector = blobman:FindFirstChild("LeftDetector")
                        local rightDetector = blobman:FindFirstChild("RightDetector")
                        local leftWeld = leftDetector and leftDetector:FindFirstChild("LeftWeld")
                        local rightWeld = rightDetector and rightDetector:FindFirstChild("RightWeld")
                        local ownerScript = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
                        local creatureGrab = ownerScript and ownerScript:FindFirstChild("CreatureGrab")

                        if leftWeld and rightWeld and creatureGrab then
                            if leftHeldTarget then
                                local leftHum = leftHeldTarget:FindFirstChildOfClass("Humanoid")
                                if not leftWeld.Attachment0 or not leftWeld.Attachment0:IsDescendantOf(leftHeldTarget) or (leftHum and leftHum.Health <= 0) or not leftHeldTarget.Parent then
                                    leftHeldTarget = nil
                                end
                            end
                            if rightHeldTarget then
                                local rightHum = rightHeldTarget:FindFirstChildOfClass("Humanoid")
                                if not rightWeld.Attachment0 or not rightWeld.Attachment0:IsDescendantOf(rightHeldTarget) or (rightHum and rightHum.Health <= 0) or not rightHeldTarget.Parent then
                                    rightHeldTarget = nil
                                end
                            end

                            if not leftHeldTarget then
                                local victim = getNearestUnheldPlayer(blobman, nil, rightHeldTarget)
                                if victim then
                                    local victimRoot = victim:FindFirstChild("HumanoidRootPart")
                                    local victimHum = victim:FindFirstChildOfClass("Humanoid")
                                    if victimRoot and victimHum and victimHum.Health > 0 and victim.Parent then
                                        leftHeldTarget = victim
                                        victimRoot.CFrame = leftDetector.CFrame
                                        victimRoot.Velocity = Vector3.new(0,0,0)
                                        task.wait(0.08)
                                        if victimHum.Health > 0 and victim.Parent then
                                            creatureGrab:FireServer(victim, victimRoot, leftWeld)
                                        else
                                            leftHeldTarget = nil
                                        end
                                        task.wait(0.12)
                                    end
                                end
                            end

                            if not rightHeldTarget then
                                local victim = getNearestUnheldPlayer(blobman, leftHeldTarget, nil)
                                if victim then
                                    local victimRoot = victim:FindFirstChild("HumanoidRootPart")
                                    local victimHum = victim:FindFirstChildOfClass("Humanoid")
                                    if victimRoot and victimHum and victimHum.Health > 0 and victim.Parent then
                                        rightHeldTarget = victim
                                        victimRoot.CFrame = rightDetector.CFrame
                                        victimRoot.Velocity = Vector3.new(0,0,0)
                                        task.wait(0.08)
                                        if victimHum.Health > 0 and victim.Parent then
                                            creatureGrab:FireServer(victim, victimRoot, rightWeld)
                                        else
                                            rightHeldTarget = nil
                                        end
                                        task.wait(0.12)
                                    end
                                end
                            end
                        end
                    else
                        leftHeldTarget = nil
                        rightHeldTarget = nil
                    end
                end
                task.wait(CHECK_DELAY)
            end
            grabTask = nil
        end)
    end

    local function stopGrabLoop()
        grabEnabled = false
        undeitedhub.Toggles.autoGrabPlayers = false
        if grabTask then
            task.cancel(grabTask)
            grabTask = nil
        end
        leftHeldTarget = nil
        rightHeldTarget = nil
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        SafeNotify({ Title = "Auto Grab Nearest", Content = "Disabled", Duration = 2 })
    end

    BlobmanTab:Toggle({
        Title = "Auto Grab Nearest",
        Value = grabEnabled,
        Callback = function(state)
            if state then startGrabLoop() else stopGrabLoop() end
        end
    })

    local oldDisable = undeitedhub.DisableAll or function() end
    undeitedhub.DisableAll = function()
        if grabEnabled then stopGrabLoop() end
        oldDisable()
    end
end

-- ============================================================
-- SETTINGS TAB (Theme)
-- ============================================================
do
    local SettingsTab = Window:Tab({ Title = "Settings" })
    local themes = config.themes or { "Default", "Midnight", "Ocean", "Sunset", "Emerald", "Rose", "Plasma", "Snow", "Neon", "Crimson", "Lavender", "Gold", "Mint", "Cyber" }
    local currentTheme = undeitedhub.CurrentTheme or "Default"

    local function ApplyTheme(themeName)
        if not themeName or themeName == "" then
            themeName = "Default"
        end
        local found = false
        for _, name in ipairs(themes) do
            if name == themeName then
                found = true
                break
            end
        end
        if not found then
            themeName = "Default"
        end
        currentTheme = themeName
        undeitedhub.CurrentTheme = themeName
        pcall(function()
            WindUI:SetTheme(themeName)
        end)
        if undeitedhub.SaveSettings then
            pcall(undeitedhub.SaveSettings)
        end
    end

    SettingsTab:Dropdown({
        Title = "Theme",
        Values = themes,
        Value = currentTheme,
        Callback = function(value)
            ApplyTheme(value)
        end
    })

    undeitedhub.ApplyTheme = ApplyTheme
end

-- ============================================================
-- SAVE STATE
-- ============================================================
if _G.UNDEITEDHUB_STATES then
    for key, value in pairs(_G.UNDEITEDHUB_STATES) do
        undeitedhub.Toggles[key] = value
    end
    _G.UNDEITEDHUB_STATES = nil
end

if undeitedhub.RestoreStates then
    undeitedhub.RestoreStates()
end

SaveSettings()