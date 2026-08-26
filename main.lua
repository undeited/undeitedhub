local BASE_URL = "https://raw.githubusercontent.com/undelted/bandithub/main/"

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

if bandithub then
    pcall(function()
        if bandithub.DisableAll then
            bandithub.DisableAll()
        end
        if bandithub.Window and bandithub.Window.Destroy then
            bandithub.Window:Destroy()
        end
    end)
    bandithub = nil
end

local function Fetch(url)
    return HttpGet(url)
end

local function LoadScript(name)
    local script = Fetch(BASE_URL .. name)
    local fn, err = LoadString(script, name)
    if not fn then error(err) end
    return fn()
end

local gamesList = Fetch(BASE_URL .. "games.lua")
local games = assert(LoadString(gamesList, "games"))()

_G.BANDITHUB_WINDOW_VISIBLE = true

local placeId = game.PlaceId or game.GameId
local gameEntry = games[placeId]
if not gameEntry then
    LoadScript("games/universal/init.lua")
else
    LoadScript(gameEntry)
end