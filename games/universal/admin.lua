local WindUI = undeitedhub.WindUI

local AdminTab = undeitedhub.Window:Tab({ Title = "Admin" })

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

local function LoadAdmin(url)
    local success, result = pcall(function()
        local script = HttpGet(url)
        if not script then error("Unsupported executor: missing game:HttpGet or game:HttpGetAsync") end
        local fn, err = LoadString(script, url)
        if not fn then error(err or "Failed to load admin script") end
        return fn()
    end)
    if not success then
        WindUI:Notify({
            Title = "Error",
            Content = "Failed to load admin script. Check your connection.",
            Duration = 4,
        })
    else
        WindUI:Notify({
            Title = "Admin Loaded",
            Content = "Admin script executed successfully.",
            Duration = 3,
        })
    end
end

AdminTab:Button({
    Title = "Load Nameless Admin",
    Callback = function()
        LoadAdmin("https://raw.githubusercontent.com/ltseverydayyou/Nameless-Admin/main/Source.lua")
    end
})

AdminTab:Button({
    Title = "Load Infinite Yield",
    Callback = function()
        LoadAdmin("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source")
    end
})