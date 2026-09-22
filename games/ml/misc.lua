local WindUI = undeitedhub.WindUI
local MiscTab = undeitedhub.Window:Tab({ Title = "Misc" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local autoSpinEnabled = undeitedhub.Toggles.AutoSpin or false
local autoSpinTask = nil
local SPIN_INTERVAL = 1

local function getFortuneWheelChances()
    local shared = ReplicatedStorage:FindFirstChild("shared")
    if not shared then return nil end
    local catalogs = shared:FindFirstChild("catalogs")
    if not catalogs then return nil end
    local chances = catalogs:FindFirstChild("fortuneWheelChances")
    if not chances then return nil end
    local children = chances:GetChildren()
    if #children == 0 then return nil end
    return children
end

local function getSpinRemote()
    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    if not rEvents then return nil end
    return rEvents:FindFirstChild("openFortuneWheelRemote")
end

local function spinOnce()
    local remote = getSpinRemote()
    if not remote then return false end
    local chances = getFortuneWheelChances()
    if not chances then return false end
    local choice = chances[math.random(1, #chances)]
    pcall(function()
        remote:InvokeServer("openFortuneWheel", choice)
    end)
    return true
end

local function startAutoSpin()
    if autoSpinTask then return end
    autoSpinEnabled = true
    undeitedhub.Toggles.AutoSpin = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    autoSpinTask = task.spawn(function()
        while autoSpinEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(spinOnce)
            end
            task.wait(SPIN_INTERVAL)
        end
        autoSpinTask = nil
    end)
end

local function stopAutoSpin()
    autoSpinEnabled = false
    undeitedhub.Toggles.AutoSpin = false
    if autoSpinTask then
        task.cancel(autoSpinTask)
        autoSpinTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

MiscTab:Toggle({
    Title = "Auto Spin",
    Value = autoSpinEnabled,
    Callback = function(state)
        if state then
            startAutoSpin()
        else
            stopAutoSpin()
        end
        SafeNotify({
            Title = "Auto Spin",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if autoSpinEnabled then
    startAutoSpin()
end

local autoGiftEnabled = undeitedhub.Toggles.AutoGift or false
local autoGiftTask = nil
local GIFT_INTERVAL = 0.5
local MAX_GIFTS = 8

local function getGiftRemote()
    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    if not rEvents then return nil end
    return rEvents:FindFirstChild("freeGiftClaimRemote")
end

local function claimGift(index)
    local remote = getGiftRemote()
    if not remote then return false end
    pcall(function()
        remote:InvokeServer("claimGift", index)
    end)
    return true
end

local function startAutoGift()
    if autoGiftTask then return end
    autoGiftEnabled = true
    undeitedhub.Toggles.AutoGift = true
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end

    autoGiftTask = task.spawn(function()
        local index = 1
        while autoGiftEnabled do
            if _G.UNDEITEDHUB_WINDOW_VISIBLE then
                pcall(claimGift, index)
                index = index + 1
                if index > MAX_GIFTS then
                    index = 1
                end
            end
            task.wait(GIFT_INTERVAL)
        end
        autoGiftTask = nil
    end)
end

local function stopAutoGift()
    autoGiftEnabled = false
    undeitedhub.Toggles.AutoGift = false
    if autoGiftTask then
        task.cancel(autoGiftTask)
        autoGiftTask = nil
    end
    if undeitedhub.SaveSettings then undeitedhub.SaveSettings() end
end

MiscTab:Toggle({
    Title = "Auto Gift",
    Value = autoGiftEnabled,
    Callback = function(state)
        if state then
            startAutoGift()
        else
            stopAutoGift()
        end
        SafeNotify({
            Title = "Auto Gift",
            Content = state and "Enabled" or "Disabled",
            Duration = 2,
        })
    end
})

if autoGiftEnabled then
    startAutoGift()
end

local oldDisable = undeitedhub.DisableAll or function() end
undeitedhub.DisableAll = function()
    if autoSpinEnabled then stopAutoSpin() end
    if autoGiftEnabled then stopAutoGift() end
    oldDisable()
end
