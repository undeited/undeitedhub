local WindUI = undeitedhub.WindUI
local AntisTab = undeitedhub.Window:Tab({ Title = "Antis" })
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

local shurikenAntiKickActive = false
local shurikenAntiKickTask = nil
local shurikenCharFixConnection = nil
local shurikenRespawnConnection = nil

local ShurikenToyList = {
    ["Shuriken"] = "NinjaShuriken",
    ["Pickaxe"] = "ToolPickaxe",
    ["Kunai"] = "NinjaKunai",
    ["Cleaver"] = "ToolCleaver",
}

local ShurikenDropdownValues = {}
for shortName, _ in pairs(ShurikenToyList) do
    table.insert(ShurikenDropdownValues, shortName)
end
table.sort(ShurikenDropdownValues)

local SelectedShurikenToy = ShurikenToyList["Shuriken"]

AntisTab:Dropdown({
    Title = "Select Anti Kick Item",
    Values = ShurikenDropdownValues,
    Value = "Shuriken",
    Callback = function(value)
        SelectedShurikenToy = ShurikenToyList[value]
    end
})

local function fixShurikenCharacter(char)
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hum and hrp then
        hum.AutoRotate = true
        hum.Sit = false
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CanCollide = true
        hrp.CanTouch = true
        hrp.CanQuery = true
        for _, part in pairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
                part.CanTouch = true
                part.CanQuery = true
                part.Velocity = Vector3.zero
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end
end

local function ClearKunai()
    local inv = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    local destroyrem = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
    if inv and destroyrem then
        for _, v in pairs(inv:GetChildren()) do
            if v.Name == "AntiKick" or v.Name == SelectedShurikenToy then
                pcall(function() destroyrem:FireServer(v) end)
            end
        end
    end
end

local function ToggleShurikenAntiKick(enable)
    shurikenAntiKickActive = enable
    if enable then
        fixShurikenCharacter(LocalPlayer.Character)
        if shurikenCharFixConnection then shurikenCharFixConnection:Disconnect() end
        shurikenCharFixConnection = LocalPlayer.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            fixShurikenCharacter(char)
        end)
        if shurikenRespawnConnection then shurikenRespawnConnection:Disconnect() end
        shurikenRespawnConnection = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            if shurikenAntiKickActive then
                ClearKunai()
            end
        end)
        shurikenAntiKickTask = task.spawn(function()
            local plr = LocalPlayer
            local setOwner = ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
            local stickyEvent = ReplicatedStorage:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
            local spawnRemote = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction
            local destroyrem = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
            local canSpawn = plr:WaitForChild("CanSpawnToy")
            local function getHRP()
                if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    return plr.Character.HumanoidRootPart
                else
                    local character = plr.CharacterAdded:Wait()
                    return character:WaitForChild("HumanoidRootPart")
                end
            end
            local function CheckForHome()
                if not Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                    return false
                end
                for _, v in pairs(Workspace.Plots:GetChildren()) do
                    local sign = v:FindFirstChild("PlotSign")
                    local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                    if owners then
                        for _, b in pairs(owners:GetChildren()) do
                            if b.Value == plr.Name then
                                local folder = Workspace.PlotItems:FindFirstChild(v.Name)
                                if folder then return true, folder end
                            end
                        end
                    end
                end
                return false
            end
            local function StickKunai(kunai)
                if not kunai or not kunai:FindFirstChild("StickyPart") then return end
                local currentHRP = getHRP()
                if not currentHRP then return end
                if kunai:FindFirstChild("SoundPart") then
                    if not kunai.SoundPart:FindFirstChild("PartOwner") or kunai.SoundPart.PartOwner.Value ~= plr.Name then
                        setOwner:FireServer(kunai.SoundPart, kunai.SoundPart.CFrame)
                    end
                end
                local firePart = currentHRP:FindFirstChild("FirePlayerPart") or currentHRP:WaitForChild("FirePlayerPart", 5)
                if firePart then
                    stickyEvent:FireServer(kunai.StickyPart, firePart, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)))
                end
                for _, obj in pairs(kunai:GetChildren()) do
                    if obj:IsA("BasePart") then
                        obj.CanTouch = false
                        obj.CanCollide = false
                        obj.CanQuery = false
                        obj.Transparency = 0.8
                    end
                end
                if kunai:FindFirstChild("Handle") then
                    local handle = kunai.Handle
                    if not handle:FindFirstChild("Highlight") then
                        local high = Instance.new("Highlight", handle)
                        high.FillColor = Color3.fromRGB(0, 255, 255)
                    end
                end
            end
            local function SpawnToy(name)
                local t = tick()
                while not canSpawn.Value do
                    if not shurikenAntiKickActive or tick() - t > 5 then return nil end
                    task.wait(0.1)
                end
                local currentHRP = getHRP()
                if currentHRP then
                    task.spawn(function()
                        pcall(function()
                            spawnRemote:InvokeServer(name, currentHRP.CFrame * CFrame.new(0, 12, 20), Vector3.new(0, 0, 0))
                        end)
                    end)
                end
                local boolik, house = CheckForHome()
                local inv = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                if boolik and house then
                    return house:WaitForChild(name, 2)
                elseif not Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) and inv then
                    return inv:WaitForChild(name, 2)
                end
                return nil
            end
            while shurikenAntiKickActive do
                task.wait(0.005)
                if not plr.Character or not plr.Character:FindFirstChild("Humanoid") or plr.Character.Humanoid.Health <= 0 then
                    task.wait(0.5)
                    ClearKunai()
                    return
                end
                local inv = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                local kunai = inv and inv:FindFirstChild(SelectedShurikenToy)
                if Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                    local boolik, house = CheckForHome()
                    if boolik and house and Workspace.Plots:FindFirstChild(house.Name) then
                        local sign = Workspace.Plots[house.Name]:FindFirstChild("PlotSign")
                        if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                            kunai = SpawnToy(SelectedShurikenToy)
                            if kunai == nil then return end
                            kunai.Name = "AntiKick"
                            StickKunai(kunai)
                        end
                    end
                end
                if not kunai then
                    if Workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then return end
                    kunai = SpawnToy(SelectedShurikenToy)
                    if kunai == nil then return end
                    kunai.Name = "AntiKick"
                    if not kunai then return end
                end
                repeat
                    if kunai and kunai:FindFirstChild("StickyPart") and kunai.StickyPart.CanTouch == true then
                        StickKunai(kunai)
                        kunai.Name = "AntiKick"
                    end
                    task.wait(0.3)
                until not kunai or not shurikenAntiKickActive or not kunai:FindFirstChild("StickyPart") or kunai.StickyPart.CanTouch == false
                    or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart")
                    or not kunai:FindFirstChild("StickyPart")
                    or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20
                if not kunai or not kunai:FindFirstChild("StickyPart") or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20 then
                    ClearKunai()
                end
                pcall(function()
                    repeat
                        task.wait(0.05)
                    until not shurikenAntiKickActive or not plr.Character or not plr.Character:FindFirstChild("Humanoid") or not kunai or not kunai:FindFirstChild("StickyPart") or not kunai.StickyPart:FindFirstChild("StickyWeld") or not kunai.StickyPart.StickyWeld.Part1
                    if not kunai or not kunai:FindFirstChild("StickyPart") or (plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health <= 0) or not kunai["StickyPart"]:FindFirstChild("StickyWeld").Part1 then
                        ClearKunai()
                    end
                end)
            end
            ClearKunai()
        end)
    else
        shurikenAntiKickActive = false
        if shurikenAntiKickTask then
            task.cancel(shurikenAntiKickTask)
            shurikenAntiKickTask = nil
        end
        if shurikenCharFixConnection then
            shurikenCharFixConnection:Disconnect()
            shurikenCharFixConnection = nil
        end
        if shurikenRespawnConnection then
            shurikenRespawnConnection:Disconnect()
            shurikenRespawnConnection = nil
        end
        fixShurikenCharacter(LocalPlayer.Character)
        ClearKunai()
    end
end

AntisTab:Toggle({
    Title = "Shuriken Anti Kick",
    Value = false,
    Callback = function(state)
        ToggleShurikenAntiKick(state)
        undeitedhub.Toggles.shurikenAntiKick = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Shuriken Anti Kick",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.shurikenAntiKick then
    ToggleShurikenAntiKick(true)
end

local antiFireActive = false
local antiFireTask = nil
local hkFirePart = nil

local function ToggleAntiFire(state)
    antiFireActive = state
    if state then
        pcall(function()
            if Workspace.Plots and Workspace.Plots.Plot5 and Workspace.Plots.Plot5.Barrier then
                if Workspace.Plots.Plot5.Barrier:FindFirstChild("AntiFirePart") then
                    hkFirePart = Workspace.Plots.Plot5.Barrier.AntiFirePart
                else
                    hkFirePart = Workspace.Plots.Plot5.Barrier:FindFirstChild("PlotBarrier")
                end
                if hkFirePart then
                    hkFirePart.CanCollide = true
                    hkFirePart.CanQuery = true
                    hkFirePart.Name = "AntiFirePart"
                    local h2 = hkFirePart:Clone()
                    h2.Name = "FalseBorder"
                    h2.Parent = hkFirePart.Parent
                    hkFirePart.Size = Vector3.new(1, 1, 1)
                    for _, prt in pairs(hkFirePart:GetChildren()) do
                        prt:Destroy()
                    end
                    hkFirePart.CanQuery = false
                    hkFirePart.CanCollide = false
                end
            end
        end)
        antiFireTask = task.spawn(function()
            while antiFireActive do
                pcall(function()
                    if hkFirePart then
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            hkFirePart.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame
                        end
                        hkFirePart.CanCollide = not hkFirePart.CanCollide
                        hkFirePart.CanCollide = not hkFirePart.CanCollide
                    end
                end)
                task.wait()
            end
            if hkFirePart then
                hkFirePart.CFrame = CFrame.new(0, -15, 0)
            end
        end)
    else
        if antiFireTask then
            task.cancel(antiFireTask)
            antiFireTask = nil
        end
        if hkFirePart then
            hkFirePart.CFrame = CFrame.new(0, -15, 0)
        end
    end
end

AntisTab:Toggle({
    Title = "Anti Fire",
    Value = false,
    Callback = function(state)
        ToggleAntiFire(state)
        undeitedhub.Toggles.antiFire = state
        if undeitedhub.SaveSettings then
            undeitedhub.SaveSettings()
        end
        SafeNotify({
            Title = "Anti Fire",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if undeitedhub.Toggles.antiFire then
    ToggleAntiFire(true)
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if shurikenAntiKickActive then
        ToggleShurikenAntiKick(false)
    end
    if antiFireActive then
        ToggleAntiFire(false)
    end
    oldDisable()
end
