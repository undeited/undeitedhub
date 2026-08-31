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

local GAME_FOLDER = "ml"

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

local function SaveSettings()
    pcall(function()
        if not makefolder then return end
        makefolder("undeltedhub")
        makefolder("undeltedhub/" .. GAME_FOLDER)
        if not writefile then return end
        local data = {
            toggles = undeltedhub.Toggles,
            theme = ResolveThemeName(undeltedhub.CurrentTheme or "Default"),
            toggleKey = undeltedhub.ToggleKey or config.toggleKey or "K",
        }
        writefile(undeltedhub.SettingsFile, game:GetService("HttpService"):JSONEncode(data))
    end)
end

local function LoadSettings()
    pcall(function()
        if not isfile then return end
        if isfile(undeltedhub.SettingsFile) then
            local data = game:GetService("HttpService"):JSONDecode(readfile(undeltedhub.SettingsFile))
            if data and data.toggles then
                for key, value in pairs(data.toggles) do
                    undeltedhub.Toggles[key] = value
                end
            end
            if data and data.theme then
                undeltedhub.CurrentTheme = ResolveThemeName(data.theme)
            end
            if data and data.toggleKey then
                undeltedhub.ToggleKey = data.toggleKey
            end
        end
    end)
end

LoadSettings()
undeltedhub.ToggleKey = undeltedhub.ToggleKey or config.toggleKey or "K"

local Window = WindUI:CreateWindow({
    Title = "Undelted Hub",
    Author = "by coolio",
    Folder = "undeltedhub/" .. GAME_FOLDER,
    Size = UDim2.fromOffset(580, 460),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(850, 560),
    Transparent = true,
    Theme = ResolveThemeName(undeltedhub.CurrentTheme or "Default"),
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

LoadScript("games/ml/esp.lua")
LoadScript("games/ml/autofarm.lua")
LoadScript("games/ml/troll.lua")
LoadScript("shared/settings.lua")

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