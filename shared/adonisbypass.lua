local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local requiredFuncs = {
    "hookfunction", "getgc", "getgenv", "getrenv", "newcclosure",
    "getrawmetatable", "setreadonly", "checkcaller", "islclosure",
    "getnamecallmethod", "hookmetamethod", "getconnections", "firetouchinterest"
}

local canRun = true
for _, funcName in ipairs(requiredFuncs) do
    if typeof(getfenv()[funcName]) ~= "function" then
        canRun = false
        break
    end
end

if typeof(setthreadidentity) ~= "function" and typeof(setidentity) ~= "function" then
    canRun = false
end

if not canRun then
    return
end

local hookfunction = hookfunction
local newcclosure = newcclosure
local getgc = getgc
local typeof = typeof
local rawget = rawget
local rawset = rawset
local pcall = pcall
local task = task
local unpack = unpack or table.unpack
local setreadonly = setreadonly
local getrawmetatable = getrawmetatable
local checkcaller = checkcaller

local isThreadIdentitySet = pcall(function()
    if setthreadidentity then
        setthreadidentity(2)
    else
        setidentity(2)
    end
end)

local hooked = {
    Detected = {},
    Kill = {},
    Kick = {},
    Ban = {},
    Crash = {},
    Disconnect = {},
    RemoteSend = {},
    RemoteFire = {}
}

local clientTable = nil
local antiTable = nil
local remoteTable = nil
local remoteObject = nil

local function deepSearchTable(tbl, depth, visited)
    if depth > 3 then return end
    if visited[tbl] then return end
    visited[tbl] = true

    local vars = rawget(tbl, "Variables")
    local proc = rawget(tbl, "Process")
    if vars and proc then
        clientTable = tbl
        return true
    end

    for k, v in pairs(tbl) do
        if typeof(v) == "table" then
            if deepSearchTable(v, depth + 1, visited) then
                return true
            end
        end
    end
    return false
end

local function scanGCForAdonis()
    local count = 0
    for a, b in getgc(true) do
        local obj = (typeof(b) == "table" and b) or (typeof(a) == "table" and a)
        if obj then
            local vars = rawget(obj, "Variables")
            local proc = rawget(obj, "Process")
            if vars and proc then
                clientTable = obj
                return true
            end

            local anti = rawget(obj, "Anti")
            if typeof(anti) == "table" then
                local det = rawget(anti, "Detected")
                if typeof(det) == "function" then
                    antiTable = anti
                end
            end
        end
        count = count + 1
        if count % 5000 == 0 then
            task.wait()
        end
    end
    return false
end

local function hookDetected(detFunc)
    if hooked.Detected[detFunc] then return end
    pcall(function()
        local oldDet
        oldDet = hookfunction(detFunc, newcclosure(function(action, info, nocrash, ...)
            if typeof(action) == "string" then
                if action == "namecallInstance" or action == "namecall" then
                    return false
                end
            end
            return false
        end))
        hooked.Detected[detFunc] = true
    end)
end

local function hookKillFuncs(tbl)
    if not tbl then return end

    local killFuncs = {"Kill", "Kick", "Ban", "Crash", "Disconnect"}
    for _, name in ipairs(killFuncs) do
        local f = rawget(tbl, name)
        if typeof(f) == "function" and not hooked[name][f] then
            pcall(function()
                hookfunction(f, newcclosure(function() return nil end))
                hooked[name][f] = true
            end)
        end
    end
end

local function hookRemote(remote)
    if not remote then return end
    if typeof(remote) ~= "table" and typeof(remote) ~= "userdata" then return end

    local send = rawget(remote, "Send")
    if typeof(send) == "function" and not hooked.RemoteSend[send] then
        pcall(function()
            local oldSend
            oldSend = hookfunction(send, newcclosure(function(cmd, ...)
                if typeof(cmd) == "string" then
                    local lower = string.lower(cmd)
                    if lower == "detected" or lower == "kick" or lower == "ban" or lower == "crash" or lower == "anti" then
                        return nil
                    end
                end
                return oldSend(cmd, ...)
            end))
            hooked.RemoteSend[send] = true
        end)
    end

    local fire = rawget(remote, "FireServer")
    if typeof(fire) == "function" and not hooked.RemoteFire[fire] then
        pcall(function()
            local oldFire
            oldFire = hookfunction(fire, newcclosure(function(self, ...)
                local args = {...}
                for _, arg in ipairs(args) do
                    if typeof(arg) == "string" then
                        local lower = string.lower(arg)
                        if lower == "detected" or lower == "kick" or lower == "ban" then
                            return nil
                        end
                    end
                end
                return oldFire(self, ...)
            end))
            hooked.RemoteFire[fire] = true
        end)
    end
end

local function safeProcessAdonis()
    if not clientTable then
        scanGCForAdonis()
    end

    if clientTable then
        local anti = rawget(clientTable, "Anti")
        if typeof(anti) == "table" then
            local det = rawget(anti, "Detected")
            if typeof(det) == "function" then
                hookDetected(det)
            end
        end

        local mainDet = rawget(clientTable, "Detected")
        if typeof(mainDet) == "function" then
            hookDetected(mainDet)
        end

        hookKillFuncs(clientTable)

        local remote = rawget(clientTable, "Remote")
        if typeof(remote) == "table" then
            hookRemote(remote)
        end
    end
end

local function scanReplicatedStorage()
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if typeof(v) == "userdata" or typeof(v) == "Instance" then
            pcall(function()
                if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("UnreliableRemoteEvent") then
                    local name = string.lower(v.Name)
                    local parent = string.lower(v.Parent and v.Parent.Name or "")
                    if name:find("adonis") or name:find("anti") or name:find("detect") or parent:find("adonis") then
                        hookRemote(v)
                    end
                end
            end)
        end
    end
end

task.spawn(function()
    safeProcessAdonis()
    scanReplicatedStorage()
end)

task.spawn(function()
    while true do
        task.wait(3)
        safeProcessAdonis()
    end
end)

task.spawn(function()
    while true do
        task.wait(5)
        scanReplicatedStorage()
    end
end)

pcall(function()
    if setthreadidentity then
        setthreadidentity(7)
    else
        setidentity(7)
    end
end)
