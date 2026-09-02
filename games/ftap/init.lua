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

LoadScript("games/ftap/esp.lua")
LoadScript("games/ftap/combat.lua")
LoadScript("games/ftap/misc.lua")
LoadScript("games/ftap/troll.lua")
LoadScript("games/ftap/blobman.lua")
LoadScript("shared/settings.lua")

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