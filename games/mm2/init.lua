local BASE_URL = "https://raw.githubusercontent.com/undelted/undeltedhub/main/"

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

local GAME_FOLDER = "mm2"

local WindUI = LoadScript("shared/windui.lua")
local utils = LoadScript("shared/utils.lua")
local config = LoadScript("shared/config.lua")

undeltedhub = undeltedhub or {}
undeltedhub.WindUI = WindUI
undeltedhub.Utils = utils
undeltedhub.Config = config
undeltedhub.Toggles = undeltedhub.Toggles or {}
undeltedhub.SettingsFile = "undeltedhub/" .. GAME_FOLDER .. "/settings.json"

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
        if isfile and isfile(undeltedhub.SettingsFile) then
            local data = game:GetService("HttpService"):JSONDecode(readfile(undeltedhub.SettingsFile))
            if data then
                if data.toggles then
                    for k, v in pairs(data.toggles) do
                        undeltedhub.Toggles[k] = v
                    end
                end
                if data.theme then
                    undeltedhub.CurrentTheme = ResolveThemeName(data.theme)
                end
                if data.toggleKey then
                    undeltedhub.ToggleKey = data.toggleKey
                end
                if data.walkSpeed then config.walkSpeed = data.walkSpeed end
                if data.jumpPower then config.jumpPower = data.jumpPower end
                return
            end
        end

        if _G.UNDELTEDHUB_STORAGE and _G.UNDELTEDHUB_STORAGE[game.PlaceId] then
            local stored = _G.UNDELTEDHUB_STORAGE[game.PlaceId]
            if stored.toggles then
                for k, v in pairs(stored.toggles) do
                    undeltedhub.Toggles[k] = v
                end
            end
            if stored.theme then
                undeltedhub.CurrentTheme = ResolveThemeName(stored.theme)
            end
            if stored.toggleKey then
                undeltedhub.ToggleKey = stored.toggleKey
            end
            if stored.walkSpeed then config.walkSpeed = stored.walkSpeed end
            if stored.jumpPower then config.jumpPower = stored.jumpPower end
        end
    end)
end

local function SaveSettings()
    pcall(function()
        local data = {
            toggles = undeltedhub.Toggles,
            theme = ResolveThemeName(undeltedhub.CurrentTheme or "Default"),
            toggleKey = undeltedhub.ToggleKey or config.toggleKey or "K",
            walkSpeed = config.walkSpeed,
            jumpPower = config.jumpPower,
        }

        if writefile and makefolder then
            makefolder("undeltedhub")
            makefolder("undeltedhub/" .. GAME_FOLDER)
            writefile(undeltedhub.SettingsFile, game:GetService("HttpService"):JSONEncode(data))
        end

        _G.UNDELTEDHUB_STORAGE = _G.UNDELTEDHUB_STORAGE or {}
        _G.UNDELTEDHUB_STORAGE[game.PlaceId] = data
    end)
end

LoadSettings()
undeltedhub.ToggleKey = undeltedhub.ToggleKey or config.toggleKey or "K"

local themeToApply = ResolveThemeName(undeltedhub.CurrentTheme or "Default")
WindUI:SetTheme(themeToApply)

local Window = WindUI:CreateWindow({
    Title = "Undelted Hub",
    Author = "by undelted",
    Folder = "undeltedhub/" .. GAME_FOLDER,
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

Window:SetToggleKey(Enum.KeyCode[undeltedhub.ToggleKey])

undeltedhub.Window = Window
undeltedhub.SaveSettings = SaveSettings
undeltedhub.LoadSettings = LoadSettings

_G.UNDELTEDHUB_WINDOW_VISIBLE = true
local frame = Window.Frame
if frame then
    frame:GetPropertyChangedSignal("Visible"):Connect(function()
        _G.UNDELTEDHUB_WINDOW_VISIBLE = frame.Visible
    end)
    frame.AncestryChanged:Connect(function()
        if not frame.Parent then
            if undeltedhub.DisableAll then
                undeltedhub.DisableAll()
            end
        end
    end)
end

-- 🔹 LOAD MM2 MODULES WITH IMPROVED ERROR REPORTING
local function SafeLoad(name)
    local success, err = pcall(LoadScript, name)
    if not success then
        local errMsg = tostring(err):sub(1, 200) -- truncate for notification
        print("❌ Failed to load " .. name .. ": " .. tostring(err))
        WindUI:Notify({
            Title = "Error: " .. name,
            Content = errMsg,
            Duration = 6,
        })
    end
end

SafeLoad("games/mm2/esp.lua")
SafeLoad("games/mm2/combat.lua")
SafeLoad("games/mm2/troll.lua")
SafeLoad("games/mm2/misc.lua")
SafeLoad("games/mm2/teleport.lua")
SafeLoad("games/mm2/autofarm.lua")
SafeLoad("shared/settings.lua")

if _G.UNDELTEDHUB_STATES then
    for key, value in pairs(_G.UNDELTEDHUB_STATES) do
        undeltedhub.Toggles[key] = value
    end
    _G.UNDELTEDHUB_STATES = nil
end

if undeltedhub.RestoreStates then
    undeltedhub.RestoreStates()
end

SaveSettings()