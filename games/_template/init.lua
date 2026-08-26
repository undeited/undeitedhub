local BASE_URL = "https://raw.githubusercontent.com/undelted/undeltedhub/main/"
local GAME_FOLDER = "replace-me"

local function LoadScript(name)
    local source = game:HttpGet(BASE_URL .. name)
    local loader = loadstring or load
    if not loader then
        error("Unsupported executor: missing loadstring or load")
    end
    local chunk, err = loader(source, name)
    if not chunk then error(err) end
    return chunk()
end

local WindUI = LoadScript("shared/windui.lua")
local utils = LoadScript("shared/utils.lua")
local config = LoadScript("shared/config.lua")

undeltedhub = undeltedhub or {}
undeltedhub.WindUI = WindUI
undeltedhub.Utils = utils
undeltedhub.Config = config
undeltedhub.Toggles = undeltedhub.Toggles or {}
undeltedhub.SettingsFile = "undeltedhub/" .. GAME_FOLDER .. "/settings.json"

local Window = WindUI:CreateWindow({
    Title = "Undelted Hub",
    Author = "by coolio",
    Folder = "undeltedhub/" .. GAME_FOLDER,
    Size = UDim2.fromOffset(580, 460),
    Resizable = true,
})

undeltedhub.Window = Window

LoadScript("shared/settings.lua")
