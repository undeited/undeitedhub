local BASE_URL = "https://raw.githubusercontent.com/undeited/undeitedhub/main/"

local function HttpGet(url)
    if game and type(game.HttpGet) == "function" then
        return game:HttpGet(url)
    end
    if game and type(game.HttpGetAsync) == "function" then
        return game:HttpGetAsync(url)
    end
    return nil
end

local function LoadString(script, chunkName)
    if type(loadstring) == "function" then
        return loadstring(script, chunkName)
    end
    if type(load) == "function" then
        return load(script, chunkName)
    end
    return nil
end

local function LoadScript(name)
    local script = HttpGet(BASE_URL .. name)
    if not script then return nil end
    local fn, err = LoadString(script, name)
    if not fn then return nil end
    return fn()
end

local function CheckExecutor()
    if not game or not Instance or not task or not pcall then return false end
    if not (type(loadstring) == "function" or type(load) == "function") then return false end
    if not (type(game.HttpGet) == "function" or type(game.HttpGetAsync) == "function") then return false end
    return true
end

if not CheckExecutor() then return end

local GAME_FOLDER = "ml"

local WindUI = LoadScript("shared/windui.lua")
local utils = LoadScript("shared/utils.lua")
local config = LoadScript("shared/config.lua")
local MathUtils = LoadScript("shared/math_utils.lua")

if not WindUI then return end

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
        end
    end)
end

local function SaveSettings()
    pcall(function()
        local data = {
            toggles = undeitedhub.Toggles,
            theme = ResolveThemeName(undeitedhub.CurrentTheme or "Default"),
            toggleKey = undeitedhub.ToggleKey or config.toggleKey or "K",
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

local function SafeLoad(name)
    pcall(LoadScript, name)
end

SafeLoad("games/ml/esp.lua")
task.wait(0.05)
SafeLoad("games/ml/combat.lua")
task.wait(0.05)
SafeLoad("games/ml/autofarm.lua")
task.wait(0.05)
SafeLoad("games/ml/gym.lua")
task.wait(0.05)
SafeLoad("games/ml/boss.lua")
task.wait(0.05)
SafeLoad("games/ml/egg.lua")
task.wait(0.05)
SafeLoad("games/ml/misc.lua")
task.wait(0.05)
SafeLoad("shared/settings.lua")

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
