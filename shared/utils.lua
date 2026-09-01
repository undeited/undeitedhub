local undeitedhub = {}

local function GetHttpFunction()
    if game and type(game.HttpGet) == "function" then
        return function(url)
            return game:HttpGet(url)
        end
    end
    if game and type(game.HttpGetAsync) == "function" then
        return function(url)
            return game:HttpGetAsync(url)
        end
    end
    return nil
end

local function GetLoadFunction()
    if type(loadstring) == "function" then
        return function(script, chunkName)
            return loadstring(script, chunkName)
        end
    end
    if type(load) == "function" then
        return function(script, chunkName)
            return load(script, chunkName)
        end
    end
    return nil
end

function undeitedhub.HttpGet(url)
    local httpFunc = GetHttpFunction()
    if not httpFunc then
        error("Unsupported executor: missing game:HttpGet or game:HttpGetAsync")
    end
    return httpFunc(url)
end

function undeitedhub.LoadString(script, chunkName)
    local loadFunc = GetLoadFunction()
    if not loadFunc then
        error("Unsupported executor: missing loadstring or load")
    end
    return loadFunc(script, chunkName)
end

function undeitedhub.GetPlayerFromArg(arg)
    if typeof(arg) == "Instance" and arg:IsA("Player") then
        return arg
    elseif type(arg) == "string" then
        return game.Players:FindFirstChild(arg)
    end
    return nil
end

function undeitedhub.PlayerHasTool(player, toolName)
    if not player then return false end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == toolName then
                return true
            end
        end
    end
    local character = player.Character
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == toolName then
                return true
            end
        end
    end
    return false
end

return undeitedhub