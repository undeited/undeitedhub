local WindUI = bandithub.WindUI
local NameTagTab = bandithub.Window:Tab({ Title = "Name Tag" })

local function SetNameColor(color)
    local Event = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
    if Event then
        Event = Event:FindFirstChild("SetNameColor")
    end
    if Event and Event:IsA("RemoteEvent") then
        pcall(function()
            Event:FireServer(color)
        end)
    else
        WindUI:Notify({ Title = "Error", Content = "SetNameColor remote not found", Duration = 2 })
    end
end

local function SetGradient(color1, color2)
    local Event = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
    if Event then
        Event = Event:FindFirstChild("SetNameColor")
    end
    if Event and Event:IsA("RemoteEvent") then
        pcall(function()
            Event:FireServer({
                mode = "gradient",
                color1 = color1,
                color2 = color2
            })
        end)
    else
        WindUI:Notify({ Title = "Error", Content = "SetNameColor remote not found", Duration = 2 })
    end
end

local solidPresets = {
    { Name = "White", Color = Color3.fromRGB(255, 255, 255) },
    { Name = "Red", Color = Color3.fromRGB(255, 0, 0) },
    { Name = "Orange", Color = Color3.fromRGB(255, 165, 0) },
    { Name = "Yellow", Color = Color3.fromRGB(255, 255, 0) },
    { Name = "Green", Color = Color3.fromRGB(0, 255, 0) },
    { Name = "Cyan", Color = Color3.fromRGB(0, 255, 255) },
    { Name = "Blue", Color = Color3.fromRGB(0, 0, 255) },
    { Name = "Purple", Color = Color3.fromRGB(128, 0, 255) },
    { Name = "Pink", Color = Color3.fromRGB(255, 105, 180) },
    { Name = "Brown", Color = Color3.fromRGB(139, 69, 19) },
    { Name = "Black", Color = Color3.fromRGB(0, 0, 0) },
    { Name = "Gray", Color = Color3.fromRGB(128, 128, 128) },
}

local solidNames = {}
for _, p in ipairs(solidPresets) do
    table.insert(solidNames, p.Name)
end

local gradientPresets = {
    { Name = "Red to Orange", Color1 = Color3.fromRGB(255, 0, 0), Color2 = Color3.fromRGB(255, 165, 0) },
    { Name = "Orange to Yellow", Color1 = Color3.fromRGB(255, 165, 0), Color2 = Color3.fromRGB(255, 255, 0) },
    { Name = "Yellow to Green", Color1 = Color3.fromRGB(255, 255, 0), Color2 = Color3.fromRGB(0, 255, 0) },
    { Name = "Green to Cyan", Color1 = Color3.fromRGB(0, 255, 0), Color2 = Color3.fromRGB(0, 255, 255) },
    { Name = "Cyan to Blue", Color1 = Color3.fromRGB(0, 255, 255), Color2 = Color3.fromRGB(0, 0, 255) },
    { Name = "Blue to Purple", Color1 = Color3.fromRGB(0, 0, 255), Color2 = Color3.fromRGB(128, 0, 255) },
    { Name = "Purple to Pink", Color1 = Color3.fromRGB(128, 0, 255), Color2 = Color3.fromRGB(255, 105, 180) },
    { Name = "Pink to Red", Color1 = Color3.fromRGB(255, 105, 180), Color2 = Color3.fromRGB(255, 0, 0) },
    { Name = "Black to White", Color1 = Color3.fromRGB(0, 0, 0), Color2 = Color3.fromRGB(255, 255, 255) },
    { Name = "White to Black", Color1 = Color3.fromRGB(255, 255, 255), Color2 = Color3.fromRGB(0, 0, 0) },
    { Name = "Red to Blue", Color1 = Color3.fromRGB(255, 0, 0), Color2 = Color3.fromRGB(0, 0, 255) },
    { Name = "Blue to Red", Color1 = Color3.fromRGB(0, 0, 255), Color2 = Color3.fromRGB(255, 0, 0) },
}

local gradientNames = {}
for _, p in ipairs(gradientPresets) do
    table.insert(gradientNames, p.Name)
end

NameTagTab:Dropdown({
    Title = "Solid Presets",
    Values = solidNames,
    Default = "White",
    Callback = function(value)
        for _, p in ipairs(solidPresets) do
            if p.Name == value then
                SetNameColor(p.Color)
                WindUI:Notify({ Title = "Color", Content = "Set color to " .. p.Name, Duration = 2 })
                break
            end
        end
    end
})

NameTagTab:Dropdown({
    Title = "Gradient Presets",
    Values = gradientNames,
    Default = gradientNames[1],
    Callback = function(value)
        for _, p in ipairs(gradientPresets) do
            if p.Name == value then
                SetGradient(p.Color1, p.Color2)
                WindUI:Notify({ Title = "Gradient", Content = "Set gradient to " .. p.Name, Duration = 2 })
                break
            end
        end
    end
})

local rainbowRunning = false
local rainbowCoroutine = nil
local rainbowButton = nil

local function stopRainbow()
    getgenv().RainbowCycle = false
    rainbowRunning = false
    rainbowCoroutine = nil
    if rainbowButton then
        rainbowButton.Title = "Start Rainbow"
    end
    WindUI:Notify({ Title = "Rainbow", Content = "Stopped", Duration = 2 })
end

local function startRainbow()
    if rainbowRunning then return end
    rainbowRunning = true
    getgenv().RainbowCycle = true

    local Event = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
    if Event then
        Event = Event:FindFirstChild("SetNameColor")
    end

    if not Event or not Event:IsA("RemoteEvent") then
        getgenv().RainbowCycle = false
        rainbowRunning = false
        WindUI:Notify({ Title = "Rainbow", Content = "SetNameColor remote not found", Duration = 2 })
        if rainbowButton then
            rainbowButton.Title = "Start Rainbow"
        end
        return
    end

    rainbowCoroutine = coroutine.create(function()
        local hue = 0
        local speed = 0.01
        while getgenv().RainbowCycle do
            if not _G.BANDITHUB_WINDOW_VISIBLE then
                task.wait(0.1)
                continue
            end
            hue = (hue + speed) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            pcall(function()
                Event:FireServer(color)
            end)
            task.wait(0.05)
        end
        rainbowRunning = false
    end)
    coroutine.resume(rainbowCoroutine)

    if rainbowButton then
        rainbowButton.Title = "Stop Rainbow"
    end
    WindUI:Notify({ Title = "Rainbow", Content = "Started", Duration = 2 })
end

rainbowButton = NameTagTab:Button({
    Title = "Start Rainbow",
    Callback = function()
        if rainbowRunning then
            stopRainbow()
        else
            startRainbow()
        end
    end
})

NameTagTab:Button({
    Title = "Reset to White",
    Callback = function()
        if rainbowRunning then
            stopRainbow()
        end
        SetNameColor(Color3.fromRGB(255, 255, 255))
        WindUI:Notify({ Title = "Color", Content = "Reset to White", Duration = 2 })
    end
})

bandithub.DisableAll = function()
    stopRainbow()
end