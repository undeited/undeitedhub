local hub = undeitedhub

hub.Closed = false
hub.Connections = {}
hub.TrackedInstances = {}
hub.CloseHandlers = {}

local PRUNE_THRESHOLD = 64

local function pruneConnections()
    local kept = {}
    for _, con in ipairs(hub.Connections) do
        local ok, connected = pcall(function() return con.Connected end)
        if ok and connected then
            kept[#kept + 1] = con
        end
    end
    hub.Connections = kept
end

function hub.IsClosed()
    return hub.Closed == true
end

function hub.Track(obj)
    if obj == nil then return obj end
    local kind = typeof(obj)
    if kind == "RBXScriptConnection" then
        if hub.Closed then
            pcall(function() obj:Disconnect() end)
            return obj
        end
        hub.Connections[#hub.Connections + 1] = obj
        if #hub.Connections > PRUNE_THRESHOLD and #hub.Connections % PRUNE_THRESHOLD == 1 then
            pruneConnections()
        end
    elseif kind == "Instance" then
        if hub.Closed then
            pcall(function() obj:Destroy() end)
            return obj
        end
        hub.TrackedInstances[obj] = true
    end
    return obj
end

function hub.OnClose(fn)
    if type(fn) ~= "function" then return end
    if hub.Closed then
        pcall(fn)
        return
    end
    hub.CloseHandlers[#hub.CloseHandlers + 1] = fn
end

function hub.Close(reason)
    if hub.Closed then return end
    hub.Closed = true
    _G.UNDEITEDHUB_WINDOW_VISIBLE = false

    for i = #hub.CloseHandlers, 1, -1 do
        pcall(hub.CloseHandlers[i])
    end
    hub.CloseHandlers = {}

    for _, con in ipairs(hub.Connections) do
        pcall(function() con:Disconnect() end)
    end
    hub.Connections = {}

    for inst in pairs(hub.TrackedInstances) do
        pcall(function() inst:Destroy() end)
    end
    hub.TrackedInstances = {}

    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        local char = lp and lp.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
        end
    end)

    local window = hub.Window
    if reason ~= "window" and window then
        pcall(function() window:Destroy() end)
    end
    local screenGui = nil
    pcall(function()
        local lib = hub.WindUI
        if lib and typeof(lib.ScreenGui) == "Instance" then
            screenGui = lib.ScreenGui
        end
    end)
    if screenGui then
        task.delay(1, function()
            pcall(function() screenGui:Destroy() end)
        end)
    end

    hub.Window = nil
end

hub.DisableAll = function()
    hub.Close("disableall")
end

function hub.HookWindow(window)
    if not window then return end
    local function onWindowGone()
        hub.Close("window")
    end

    pcall(function()
        if type(window.OnDestroy) == "function" then
            window:OnDestroy(onWindowGone)
        end
    end)

    local main = nil
    pcall(function()
        main = window.UIElements and window.UIElements.Main
    end)
    if typeof(main) == "Instance" then
        local con = main.AncestryChanged:Connect(function()
            if main:IsDescendantOf(game) then return end
            task.delay(0.15, function()
                if not main:IsDescendantOf(game) then
                    onWindowGone()
                end
            end)
        end)
        hub.Connections[#hub.Connections + 1] = con
    end
end
