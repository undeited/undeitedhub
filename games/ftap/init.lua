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
undeitedhub.Toggles = {}

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

local themeToApply = ResolveThemeName("Default")
WindUI:SetTheme(themeToApply)

local Window = WindUI:CreateWindow({
    Title = "Undeited Hub",
    Author = "by undeited",
    Folder = "undeitedhub/" .. GAME_FOLDER,
    Size = UDim2.fromOffset(580, 460),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(850, 560),
    Transparent = false,
    Acrylic = false,
    Theme = themeToApply,
    Resizable = true,
    SideBarWidth = 200,
    HideSearchBar = true,
    ScrollBarEnabled = false,
})

Window:SetToggleKey(Enum.KeyCode.K)

undeitedhub.Window = Window

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
    local success, err = pcall(LoadScript, name)
end

SafeLoad("games/ftap/esp.lua")
task.wait(0.05)
SafeLoad("games/ftap/combat.lua")
task.wait(0.05)
SafeLoad("games/ftap/blobman.lua")
task.wait(0.05)
SafeLoad("games/ftap/antis.lua")
task.wait(0.05)
SafeLoad("games/ftap/misc.lua")
task.wait(0.05)
SafeLoad("shared/settings.lua")
