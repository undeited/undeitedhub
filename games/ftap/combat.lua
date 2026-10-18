local WindUI = undeitedhub.WindUI
local CombatTab = undeitedhub.Window:Tab({ Title = "Combat" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AeroServices = ReplicatedStorage:WaitForChild("Aero"):WaitForChild("AeroRemoteServices"):WaitForChild("GameService")
local AttackStart = AeroServices:WaitForChild("WeaponAttackStart")
local AnimComplete = AeroServices:WaitForChild("WeaponAnimComplete")

local autoSwingEnabled = undeitedhub.Toggles.AutoSwing or false
local lastSwingTime = 0
local SWING_COOLDOWN = 0.1

local superStrengthEnabled = undeitedhub.Toggles.SuperStrength or false
local superStrengthValue = undeitedhub.Toggles.SuperStrengthValue or 400
local superStrengthConnection = nil

local function SwingWeapon()
    AttackStart:FireServer()
    AnimComplete:FireServer()
    if typeof(getNil) == "function" then
        pcall(function()
            getNil("Event", "BindableEvent"):Fire()
        end)
    end
end

local function ApplySuperStrength(character)
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local bodyVelocity = root:FindFirstChild("SuperStrengthBV")
    if not bodyVelocity then
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "SuperStrengthBV"
        bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVelocity.Parent = root
    end
    bodyVelocity.Velocity = camera.CFrame.LookVector * superStrengthValue
    task.delay(1, function()
        if bodyVelocity and bodyVelocity.Parent then
            bodyVelocity:Destroy()
        end
    end)
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
        pcall(function()
            WindUI:Notify({
                Title = "Auto Swing",
                Content = state and "Enabled" or "Disabled",
                Duration = 2,
            })
        end)
        if state then
            lastSwingTime = tick()
        end
    end
})

CombatTab:Toggle({
    Title = "Super Strength",
    Value = superStrengthEnabled,
    Callback = function(state)
        superStrengthEnabled = state
        undeitedhub.Toggles.SuperStrength = state
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
        if state then
            superStrengthConnection = game:GetService("UserInputService").InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton2 and _G.UNDEITEDHUB_WINDOW_VISIBLE then
                    local character = game.Players.LocalPlayer.Character
                    ApplySuperStrength(character)
                end
            end)
        else
            if superStrengthConnection then
                superStrengthConnection:Disconnect()
                superStrengthConnection = nil
            end
        end
    end
})

CombatTab:Slider({
    Title = "Strength",
    Value = superStrengthValue,
    Min = 100,
    Max = 5000,
    Callback = function(value)
        superStrengthValue = value
        undeitedhub.Toggles.SuperStrengthValue = value
        if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    end
})

undeitedhub.DisableAll = undeitedhub.DisableAll or function() end
local oldDisable = undeitedhub.DisableAll
undeitedhub.DisableAll = function()
    autoSwingEnabled = false
    undeitedhub.Toggles.AutoSwing = false
    superStrengthEnabled = false
    undeitedhub.Toggles.SuperStrength = false
    if superStrengthConnection then
        superStrengthConnection:Disconnect()
        superStrengthConnection = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
    oldDisable()
end
