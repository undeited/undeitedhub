local modules = {}
local cache = {}
local function import(name)
    if cache[name] then return table.unpack(cache[name]) end
    if name:find("rbxassetid://") then
        local assets = { game:GetObjects(name)[1] }
        cache[name] = assets
        return table.unpack(assets)
    end
    local module = modules[name]
    if not module then error("Missing bundled Hydroxide module: " .. name) end
    local values = { module() }
    cache[name] = values
    return table.unpack(values)
end

modules["init"] = function()
    local environment = assert(getgenv, "<OH> ~ Your exploit is not supported")()
    
    if oh then
        oh.Exit()
    end
    
    local importCache = {}
    
    local function hasMethods(methods)
        for name in pairs(methods) do
            if not environment[name] then
                return false
            end
        end
    
        return true
    end
    
    local function useMethods(module)
        for name, method in pairs(module) do
            if method then
                environment[name] = method
            end
        end
    end
    
    if Window and PROTOSMASHER_LOADED then
        getgenv().get_script_function = nil
    end
    
    local globalMethods = {
        checkCaller = checkcaller,
        newCClosure = newcclosure,
        hookFunction = hookfunction or detour_function,
        getGc = getgc or get_gc_objects,
        getInfo = debug.getinfo or getinfo,
        getSenv = getsenv,
        getMenv = getmenv or getsenv,
        getContext = getthreadcontext or get_thread_context or (syn and syn.get_thread_identity),
        getConnections = get_signal_cons or getconnections,
        getScriptClosure = getscriptclosure or get_script_function,
        getNamecallMethod = getnamecallmethod or get_namecall_method,
        getCallingScript = getcallingscript or get_calling_script,
        getLoadedModules = getloadedmodules or get_loaded_modules,
        getConstants = debug.getconstants or getconstants or getconsts,
        getUpvalues = debug.getupvalues or getupvalues or getupvals,
        getProtos = debug.getprotos or getprotos,
        getStack = debug.getstack or getstack,
        getConstant = debug.getconstant or getconstant or getconst,
        getUpvalue = debug.getupvalue or getupvalue or getupval,
        getProto = debug.getproto or getproto,
        getMetatable = getrawmetatable or debug.getmetatable,
        getHui = get_hidden_gui or gethui,
        setClipboard = setclipboard or writeclipboard,
        setConstant = debug.setconstant or setconstant or setconst,
        setContext = setthreadcontext or set_thread_context or (syn and syn.set_thread_identity),
        setUpvalue = debug.setupvalue or setupvalue or setupval,
        setStack = debug.setstack or setstack,
        setReadOnly = setreadonly or (make_writeable and function(table, readonly) if readonly then make_readonly(table) else make_writeable(table) end end),
        isLClosure = islclosure or is_l_closure or (iscclosure and function(closure) return not iscclosure(closure) end),
        isReadOnly = isreadonly or is_readonly,
        isXClosure = is_synapse_function or issentinelclosure or is_protosmasher_closure or is_sirhurt_closure or iselectronfunction or istempleclosure or checkclosure,
        hookMetaMethod = hookmetamethod or (hookfunction and function(object, method, hook) return hookfunction(getMetatable(object)[method], hook) end),
        readFile = readfile,
        writeFile = writefile,
        makeFolder = makefolder,
        isFolder = isfolder,
        isFile = isfile,
    }
    
    if PROTOSMASHER_LOADED then
        globalMethods.getConstant = function(closure, index)
            return globalMethods.getConstants(closure)[index]
        end
    end
    
    local oldGetUpvalue = globalMethods.getUpvalue
    local oldGetUpvalues = globalMethods.getUpvalues
    
    globalMethods.getUpvalue = function(closure, index)
        if type(closure) == "table" then
            return oldGetUpvalue(closure.Data, index)
        end
    
        return oldGetUpvalue(closure, index)
    end
    
    globalMethods.getUpvalues = function(closure)
        if type(closure) == "table" then
            return oldGetUpvalues(closure.Data)
        end
    
        return oldGetUpvalues(closure)
    end
    
    environment.hasMethods = hasMethods
    environment.oh = {
        Events = {},
        Hooks = {},
        Cache = importCache,
        Methods = globalMethods,
        Constants = {
            Types = {
                ["nil"] = "rbxassetid://4800232219",
                table = "rbxassetid://4666594276",
                string = "rbxassetid://4666593882",
                number = "rbxassetid://4666593882",
                boolean = "rbxassetid://4666593882",
                userdata = "rbxassetid://4666594723",
                vector = "rbxassetid://4666594723",
                ["function"] = "rbxassetid://4666593447",
                ["thread"] = "rbxassetid://4666593447",
                ["integral"] = "rbxassetid://4666593882"
            },
            Syntax = {
                ["nil"] = Color3.fromRGB(244, 135, 113),
                table = Color3.fromRGB(225, 225, 225),
                string = Color3.fromRGB(225, 150, 85),
                number = Color3.fromRGB(170, 225, 127),
                boolean = Color3.fromRGB(127, 200, 255),
                userdata = Color3.fromRGB(225, 225, 225),
                vector = Color3.fromRGB(225, 225, 225),
                ["function"] = Color3.fromRGB(225, 225, 225),
                ["thread"] = Color3.fromRGB(225, 225, 225),
                ["unnamed_function"] = Color3.fromRGB(175, 175, 175)
            }
        },
        Exit = function()
            for _i, event in pairs(oh.Events) do
                event:Disconnect()
            end
    
            for original, hook in pairs(oh.Hooks) do
                local hookType = type(hook)
                if hookType == "function" then
                    hookFunction(hook, original)
                elseif hookType == "table" then
                    hookFunction(hook.Closure.Data, hook.Original)
                end
            end
    
            local ui = importCache["rbxassetid://11389137937"]
            local assets = importCache["rbxassetid://5042114982"]
    
            if ui then
                unpack(ui):Destroy()
            end
    
            if assets then
                unpack(assets):Destroy()
            end
        end
    }
    
    if getConnections then 
        for __, connection in pairs(getConnections(game:GetService("ScriptContext").Error)) do
    
            local conn = getrawmetatable(connection)
            local old = conn and conn.__index
            
            if PROTOSMASHER_LOADED ~= nil then setwriteable(conn) else setReadOnly(conn, false) end
            
            if old then
                conn.__index = newcclosure(function(t, k)
                    if k == "Connected" then
                        return true
                    end
                    return old(t, k)
                end)
            end
    
            if PROTOSMASHER_LOADED ~= nil then
                setReadOnly(conn)
                connection:Disconnect()
            else
                setReadOnly(conn, true)
                connection:Disable()
            end
        end
    end
    
    useMethods(globalMethods)
    
    environment.import = import
    useMethods({ import = import })
    
    useMethods(import("methods/string"))
    useMethods(import("methods/table"))
    useMethods(import("methods/userdata"))
    useMethods(import("methods/environment"))
    
    
end

modules["methods/environment"] = function()
    local client = game:GetService("Players").LocalPlayer
    local control = client.PlayerScripts:FindFirstChild("Control Script")
    
    local methods = {}
    
    local function secureCall(closure, ...)
        local env = getfenv(1)
        local renv = getrenv()
        local results
        
        setfenv(1, setmetatable({ script = script }, {
            __index = renv
        }))
    
        results = (syn and { syn.secure_call(closure, control, ...) }) or { closure(...) }
    
        setfenv(1, env)
    
        return unpack(results)
    end
    
    methods.secureCall = secureCall
    return methods
end

modules["methods/string"] = function()
    local methods = {}
    
    local function toString(value)
        local dataType = typeof(value)
    
        if dataType == "userdata" or dataType == "table" then
            local mt = getMetatable(value)
            local __tostring = mt and rawget(mt, "__tostring")
    
            if not mt or (mt and not __tostring) then 
                return tostring(value) 
            end
    
            rawset(mt, "__tostring", nil)
            
            value = tostring(value):gsub((dataType == "userdata" and "userdata: ") or "table: ", '')
            
            rawset(mt, "__tostring", __tostring)
    
            return value 
        elseif type(value) == "userdata" then
            return userdataValue(value)
        elseif dataType == "function" then
            local closureName = getInfo(value).name or ''
            return (closureName == '' and "Unnamed function") or closureName
        else
            return tostring(value)
        end
    end
    
    local gsubCharacters = {
        ["\""] = "\\\"",
        ["\\"] = "\\\\",
        ["\0"] = "\\0",
        ["\n"] = "\\n",
        ["\t"] = "\\t",
        ["\f"] = "\\f",
        ["\r"] = "\\r",
        ["\v"] = "\\v",
        ["\a"] = "\\a",
        ["\b"] = "\\b"
    }
    
    local function dataToString(data)
        local dataType = type(data)
    
        if dataType == "string" then
            return '"' .. data:gsub("[%c%z\\\"]", gsubCharacters) .. '"'
        elseif dataType == "table" then
            return tableToString(data)
        elseif dataType == "userdata" then
            if typeof(data) == "Instance" then
                return getInstancePath(data)
            end
    
            return userdataValue(data)
        end
    
        return tostring(data)
    end
    
    local function toUnicode(string)
        local codepoints = "utf8.char("
        
        for _i, v in utf8.codes(string) do
            codepoints = codepoints .. v .. ', '
        end
        
        return codepoints:sub(1, -3) .. ')'
    end
    
    methods.toString = toString
    methods.dataToString = dataToString
    methods.toUnicode = toUnicode
    return methods
end

modules["methods/table"] = function()
    local methods = {}
    
    local function tableToString(data, root, indents)
        local dataType = type(data)
    
        if dataType == "userdata" then
            return (typeof(data) == "Instance" and getInstancePath(data)) or userdataValue(data)
        elseif dataType == "string" then
            if #(data:gsub('%w', ''):gsub('%s', ''):gsub('%p', '')) > 0 then
                local success, result = pcall(toUnicode, data)
                return (success and result) or toString(data)
            else
                return ('"%s"'):format(data:gsub('"', '\\"'))
            end
        elseif dataType == "table" then
            indents = indents or 1
            root = root or data
    
            local head = '{\n'
            local elements = 0
            local indent = ('\t'):rep(indents)
            
            for i,v in pairs(data) do
                if i ~= root and v ~= root then
                    head = head .. ("%s[%s] = %s,\n"):format(indent, tableToString(i, root, indents + 1), tableToString(v, root, indents + 1))
                else
                    head = head .. ("%sOH_CYCLIC_PROTECTION,\n"):format(indent)
                end
    
                elements = elements + 1
            end
            
            if elements > 0 then
                return ("%s\n%s"):format(head:sub(1, -3), ('\t'):rep(indents - 1) .. '}')
            else
                return "{}"
            end
        end
    
        return tostring(data)
    end
    
    local function compareTables(x, y)
        for i, v in pairs(x) do
            if v ~= y[i] then
                return false
            end
        end
    
        return true
    end
    
    methods.tableToString = tableToString
    methods.compareTables = compareTables
    return methodsend

modules["methods/userdata"] = function()
    local methods = {}
    
    local players = game:GetService("Players")
    local client = players.LocalPlayer
    
    local function getInstancePath(instance)
        local name = instance.Name
        local head = (#name > 0 and '.' .. name) or "['']"
        
        if not instance.Parent and instance ~= game then
            return head .. " --[[ PARENTED TO NIL OR DESTROYED ]]"
        end
        
        if instance == game then
            return "game"
        elseif instance == workspace then
            return "workspace"
        else
            local _success, result = pcall(game.GetService, game, instance.ClassName)
            
            if result then
                head = ':GetService("' .. instance.ClassName .. '")'
            elseif instance == client then
                head = '.LocalPlayer' 
            else
                local nonAlphaNum = name:gsub('[%w_]', '')
                local noPunct = nonAlphaNum:gsub('[%s%p]', '')
                
                if tonumber(name:sub(1, 1)) or (#nonAlphaNum ~= 0 and #noPunct == 0) then
                    head = '["' .. name:gsub('"', '\\"'):gsub('\\', '\\\\') .. '"]'
                elseif #nonAlphaNum ~= 0 and #noPunct > 0 then
                    head = '[' .. toUnicode(name) .. ']'
                end
            end
        end
        
        return getInstancePath(instance.Parent) .. head
    end
    
    local function userdataValue(data)
        local dataType = typeof(data)
    
        if dataType == "userdata" then
            return "aux.placeholderUserdataConstant"
        elseif dataType == "Instance" then
            return data.Name
        elseif dataType == "BrickColor" then
            return dataType .. ".new(\"" .. tostring(data) .. "\")"
        elseif
            dataType == "TweenInfo" or
            dataType == "Vector3" or
            dataType == "Vector2" or
            dataType == "CFrame" or
            dataType == "Color3" or
            dataType == "Random" or
            dataType == "Faces" or
            dataType == "UDim2" or
            dataType == "UDim" or
            dataType == "Rect" or
            dataType == "Axes" or
            dataType == "NumberRange" or
            dataType == "RaycastParams" or
            dataType == "PhysicalProperties"
        then
            return dataType .. ".new(" .. tostring(data) .. ")"
        elseif dataType == "DateTime" then
            return dataType .. ".now()"
        elseif dataType == "PathWaypoint" then
            local split = tostring(data):split('}, ')
            local vector = split[1]:gsub('{', "Vector3.new(")
            return dataType .. ".new(" .. vector .. "), " .. split[2] .. ')'
        elseif dataType == "Ray" or dataType == "Region3" then
            local split = tostring(data):split('}, ')
            local vprimary = split[1]:gsub('{', "Vector3.new(")
            local vsecondary = split[2]:gsub('{', "Vector3.new("):gsub('}', ')')
            return dataType .. ".new(" .. vprimary .. "), " .. vsecondary .. ')'
        elseif dataType == "ColorSequence" or dataType == "NumberSequence" then 
            return dataType .. ".new(" .. tableToString(data.Keypoints) .. ')'
        elseif dataType == "ColorSequenceKeypoint" then
            return "ColorSequenceKeypoint.new(" .. data.Time .. ", Color3.new(" .. tostring(data.Value) .. "))"
        elseif dataType == "NumberSequenceKeypoint" then
            local envelope = data.Envelope and data.Value .. ", " .. data.Envelope or data.Value
            return "NumberSequenceKeypoint.new(" .. data.Time .. ", " .. envelope .. ")"
        end
    
        return tostring(data)
    end
    
    local function isUserdata(type)
        return type == "BrickColor"
            or type == "TweenInfo"
            or type == "Instance"
            or type == "DateTime"
            or type == "Vector3" 
            or type == "Vector2"
            or type == "Region3"
            or type == "CFrame"
            or type == "Color3"
            or type == "Random"
            or type == "Faces"
            or type == "UDim2"
            or type == "UDim"
            or type == "Rect"
            or type == "Axes"
            or type == "Ray"
            or type == "RaycastParams"
            or type == "PathWaypoint"
            or type == "PhysicalProperties"
            or type == "ColorSequence"
            or type == "ColorSequenceKeypoint"
            or type == "NumberRange"
            or type == "NumberSequence"
            or type == "NumberSequenceKeypoint"
    end
    
    methods.isUserdata = isUserdata
    methods.userdataValue = userdataValue
    methods.getInstancePath = getInstancePath
    return methods
end

modules["modules/ClosureSpy"] = function()
    local ClosureSpy = {}
    
    local requiredMethods = {
        ["hookFunction"] = true,
        ["newCClosure"] = true,
        ["isLClosure"] = true,
        ["getProtos"] = true,
        ["getUpvalues"] = true,
        ["getUpvalue"] = true,
        ["getContext"] = true,
        ["setContext"] = true,
        ["setUpvalue"] = true,
        ["getConstants"] = true,
        ["getConstant"] = true,
        ["setConstant"] = true
    }
    
    local eventCallback
    
    
    function log(hook, callingScript, ...)
        local vargs = {...}
        
        if eventCallback and not hook:AreArgsIgnored(vargs) then
            local call = {
                script = callingScript,
                args = vargs
            }
            eventCallback(hook, call)
        end
    end
    
    local function setEvent(callback)
        if not eventCallback then
            eventCallback = callback
        end
    end
    
    local Hook = {}
    local hookMap = {}
    hookCache = {}
    
    function Hook.new(closure)
        local hook = {}
        local data = closure.Data
    
        if getInfo(data).nups < 1 then
            return
        elseif hookCache[data] then
            return false
        end
    
        local wrap = { hook, data }
        hookCache[data] = hookFunction(data, function(...)
            local vargs = {...}
            local uHook = wrap[1]
            local uData = wrap[2]
    
            if not uHook.Ignored and not uHook:AreArgsIgnored(vargs) then
                log(uHook, getCallingScript(), ...)
            end
    
            if not uHook.Blocked and not uHook:AreArgsBlocked(vargs) then
                return hookCache[uData](...)
            end
        end)
    
        closure.Data = hookCache[data]
    
        hook.Closure = closure
        hook.Calls = 0
        hook.Logs = {}
        hook.Ignored = false
        hook.Blocked = false
        hook.Ignore = Hook.ignore
        hook.Block = Hook.block
        hook.IgnoreArg = Hook.ignoreArg
        hook.BlockArg = Hook.blockArg
        hook.Remove = Hook.remove
        hook.Clear = Hook.clear
        hook.BlockedArgs = {}
        hook.IgnoredArgs = {}
        hook.AreArgsBlocked = Hook.areArgsBlocked
        hook.AreArgsIgnored = Hook.areArgsIgnored
        hook.IncrementCalls = Hook.incrementCalls
        hook.DecrementCalls = Hook.decrementCalls
    
        hookMap[data] = hook
    
        return hook
    end
    
    function Hook.remove(hook)
        hookMap[hook.Closure.Data] = nil
    end
    
    function Hook.clear(hook)
        hook.Calls = 0
    end
    
    function Hook.block(hook)
        hook.Blocked = not hook.Blocked
    end
    
    function Hook.ignore(hook)  
        hook.Ignored = not hook.Ignored
    end
    
    function Hook.blockArg(hook, index, value, byType)
        local blockedArgs = hook.BlockedArgs
        local blockedIndex = blockedArgs[index]
    
        if not blockedIndex then
            blockedIndex = {
                types = {},
                values = {}
            }
            blockedArgs[index] = blockedIndex
        end
    
        if byType then
            blockedIndex.types[value] = true
        else
            blockedIndex.values[value] = true
        end
    end
    
    function Hook.ignoreArg(hook, index, value, byType)
        local ignoredArgs = hook.IgnoredArgs
        local indexIgnore = ignoredArgs[index]
    
        if not indexIgnore then
            indexIgnore = {
                types = {},
                values = {}
            }
    
            ignoredArgs[index] = indexIgnore
        end
    
        if byType then
            indexIgnore.types[value] = true
        else
            indexIgnore.values[value] = true
        end
    end
    
    function Hook.areArgsBlocked(hook, args)
        local blockedArgs = hook.BlockedArgs
    
        for index, value in pairs(args) do
            local indexBlock = blockedArgs[index]
            
            if indexBlock and ( indexBlock.types[typeof(value)] or indexBlock.values[value] ~= nil ) then
                return true
            end
        end
    
        return false
    end
    
    function Hook.areArgsIgnored(hook, args)
        local ignoredArgs = hook.IgnoredArgs
    
        for index, value in pairs(args) do
            local indexIgnore = ignoredArgs[index]
    
            if indexIgnore and ( indexIgnore.types[typeof(value)] or indexIgnore.values[value] ~= nil ) then
                return true
            end
        end
    
        return false
    end
    
    function Hook.incrementCalls(hook, vargs)
        hook.Calls = hook.Calls + 1
        table.insert(hook.Logs, vargs)
    end
    
    function Hook.decrementCalls(hook, vargs)
        local logs = hook.Logs
    
        hook.Calls = hook.Calls - 1
        table.remove(logs, table.find(logs, vargs))
    end
    
    ClosureSpy.Hook = Hook
    ClosureSpy.SetEvent = setEvent
    ClosureSpy.RequiredMethods = requiredMethods
    return ClosureSpyend

modules["modules/ConstantScanner"] = function()
    local ConstantScanner = {}
    local Closure = import("objects/Closure")
    local Constant = import("objects/Constant")
    
    local requiredMethods = {
        ["getGc"] = true,
        ["getInfo"] = true,
        ["isXClosure"] = true,
        ["getConstant"] = true,
        ["setConstant"] = true,
        ["getConstants"] = true
    }
    
    local function compareConstant(query, constant)
        local constantType = type(constant)
    
        local stringCheck = constantType == "string" and (query == constant or constant:lower():find(query:lower()))
        local numberCheck = constantType == "number" and (tonumber(query) == constant or ("%.2f"):format(constant) == query)
        local userDataCheck = constantType == "userdata" and toString(constant) == query
    
        if constantType == "function" then
            local closureName = getInfo(constant).name or ''
            return query == closureName or closureName:lower():find(query:lower())
        end
    
        return stringCheck or numberCheck or userDataCheck
    end 
    
    local function scan(query)
        local constants = {}
    
        for _i, closure in pairs(getGc()) do
            if type(closure) == "function" and not isXClosure(closure) and isLClosure(closure) and not constants[closure] then
                for index, constant in pairs(getConstants(closure)) do
                    if compareConstant(query, constant) then
                        local storage = constants[closure]
    
                        if not storage then
                            local newClosure = Closure.new(closure)
                            newClosure.Constants[index] = Constant.new(newClosure, index, constant)
                            constants[closure] = newClosure
                        else
                            storage.Constants[index] = Constant.new(storage, index, constant)
                        end
                    end
                end
            end
        end
    
        return constants
    end
    
    ConstantScanner.Scan = scan
    ConstantScanner.RequiredMethods = requiredMethods
    return ConstantScannerend

modules["modules/Explorer"] = function()
    local Explorer = {}
    
    
    
    return Explorerend

modules["modules/ModuleScanner"] = function()
    local ModuleScanner = {}
    local ModuleScript = import("objects/ModuleScript")
    
    local requiredMethods = {
        ["getMenv"] = true,
        ["getProtos"] = true,
        ["getConstants"] = true,
        ["getScriptClosure"] = true,
        ["getLoadedModules"] = true
    }
    
    local function scan(query)
        local modules = {}
        query = query or ""
        
        for _i, module in pairs(getLoadedModules()) do
            if module.Name:lower():find(query) then
                modules[module] = ModuleScript.new(module)
            end
        end
    
        return modules
    end
    
    ModuleScanner.Scan = scan
    ModuleScanner.RequiredMethods = requiredMethods
    return ModuleScannerend

modules["modules/RemoteSpy"] = function()
    local RemoteSpy = {}
    local Remote = import("objects/Remote")
    
    local requiredMethods = {
        ["checkCaller"] = true,
        ["newCClosure"] = true,
        ["hookFunction"] = true,
        ["isReadOnly"] = true,
        ["setReadOnly"] = true,
        ["getInfo"] = true,
        ["getMetatable"] = true,
        ["setClipboard"] = true,
        ["getNamecallMethod"] = true,
        ["getCallingScript"] = true,
    }
    
    local remoteMethods = {
        FireServer = true,
        InvokeServer = true,
        Fire = true,
        Invoke = true
    }
    
    local remotesViewing = {
        RemoteEvent = true,
        RemoteFunction = false,
        BindableEvent = false,
        BindableFunction = false
    }
    
    local methodHooks = {
        RemoteEvent = Instance.new("RemoteEvent").FireServer,
        RemoteFunction = Instance.new("RemoteFunction").InvokeServer,
        BindableEvent = Instance.new("BindableEvent").Fire,
        BindableFunction = Instance.new("BindableFunction").Invoke
    }
    
    local currentRemotes = {}
    
    local remoteDataEvent = Instance.new("BindableEvent")
    local eventSet = false
    
    local function connectEvent(callback)
        remoteDataEvent.Event:Connect(callback)
    
        if not eventSet then
            eventSet = true
        end
    end
    
    local nmcTrampoline
    nmcTrampoline = hookMetaMethod(game, "__namecall", function(...)
        local instance = ...
        
        if typeof(instance) ~= "Instance" then
            return nmcTrampoline(...)
        end
    
        local method = getNamecallMethod()
    
        if method == "fireServer" then
            method = "FireServer"
        elseif method == "invokeServer" then
            method = "InvokeServer"
        end
            
        if remotesViewing[instance.ClassName] and instance ~= remoteDataEvent and remoteMethods[method] then
            local remote = currentRemotes[instance]
            local vargs = {select(2, ...)}
                
            if not remote then
                remote = Remote.new(instance)
                currentRemotes[instance] = remote
            end
    
            local remoteIgnored = remote.Ignored
            local remoteBlocked = remote.Blocked
            local argsIgnored = remote.AreArgsIgnored(remote, vargs)
            local argsBlocked = remote.AreArgsBlocked(remote, vargs)
    
            if eventSet and (not remoteIgnored and not argsIgnored) then
                local call = {
                    script = getCallingScript((PROTOSMASHER_LOADED ~= nil and 2) or nil),
                    args = vargs,
                    func = getInfo(3).func
                }
    
                remote.IncrementCalls(remote, call)
                remoteDataEvent.Fire(remoteDataEvent, instance, call)
            end
    
            if remoteBlocked or argsBlocked then
                return
            end
        end
    
        return nmcTrampoline(...)
    end)
    
    
    
    local pcall = pcall
    
    local function checkPermission(instance)
        if (instance.ClassName) then end
    end
    
    for _name, hook in pairs(methodHooks) do
        local originalMethod
        originalMethod = hookFunction(hook, newCClosure(function(...)
            local instance = ...
    
            if typeof(instance) ~= "Instance" then
                return originalMethod(...)
            end
                    
            do
                local success = pcall(checkPermission, instance)
                if (not success) then return originalMethod(...) end
            end
    
            if instance.ClassName == _name and remotesViewing[instance.ClassName] and instance ~= remoteDataEvent then
                local remote = currentRemotes[instance]
                local vargs = {select(2, ...)}
    
                if not remote then
                    remote = Remote.new(instance)
                    currentRemotes[instance] = remote
                end
    
                local remoteIgnored = remote.Ignored 
                local argsIgnored = remote:AreArgsIgnored(vargs)
                
                if eventSet and (not remoteIgnored and not argsIgnored) then
                    local call = {
                        script = getCallingScript((PROTOSMASHER_LOADED ~= nil and 2) or nil),
                        args = vargs,
                        func = getInfo(3).func
                    }
        
                    remote:IncrementCalls(call)
                    remoteDataEvent:Fire(instance, call)
                end
    
                if remote.Blocked or remote:AreArgsBlocked(vargs) then
                    return
                end
            end
            
            return originalMethod(...)
        end))
    
        oh.Hooks[originalMethod] = hook
    end
    
    RemoteSpy.RemotesViewing = remotesViewing
    RemoteSpy.CurrentRemotes = currentRemotes
    RemoteSpy.ConnectEvent = connectEvent
    RemoteSpy.RequiredMethods = requiredMethods
    return RemoteSpy
end

modules["modules/ScriptScanner"] = function()
    local ScriptScanner = {}
    local LocalScript = import("objects/LocalScript")
    
    local requiredMethods = {
        ["getGc"] = true,
        ["getSenv"] = true,
        ["getProtos"] = true,
        ["getConstants"] = true,
        ["getScriptClosure"] = true,
        ["isXClosure"] = true
    }
    
    local function scan(query)
        local scripts = {}
        query = query or ""
    
        for _i, v in pairs(getGc()) do
            if type(v) == "function" and not isXClosure(v) then
                local script = rawget(getfenv(v), "script")
    
                if typeof(script) == "Instance" and 
                    not scripts[script] and 
                    script:IsA("LocalScript") and 
                    script.Name:lower():find(query) and
                    getScriptClosure(script) and
                    pcall(function() getsenv(script) end)
                then
                    scripts[script] = LocalScript.new(script)
                end
            end
        end
    
        return scripts
    end
    
    ScriptScanner.RequiredMethods = requiredMethods
    ScriptScanner.Scan = scan
    return ScriptScannerend

modules["modules/UpvalueScanner"] = function()
    local UpvalueScanner = {}
    local Closure = import("objects/Closure")
    local Upvalue = import("objects/Upvalue")
    
    local requiredMethods = {
        ["getGc"] = true,
        ["getInfo"] = true,
        ["isXClosure"] = true,
        ["getUpvalue"] = true,
        ["setUpvalue"] = true,
        ["getUpvalues"] = true
    }
    
    local function compareUpvalue(query, upvalue, ignore)
        local upvalueType = type(upvalue)
    
        local stringCheck = upvalueType == "string" and (query == upvalue or upvalue:lower():find(query:lower()))
        local numberCheck = not ignore and upvalueType == "number" and not isTableIndex and (tonumber(query) == upvalue or ("%.2f"):format(upvalue) == query)
        
        if upvalueType == "userdata" then
            if typeof(upvalueType) == "Instance" then
                local instanceName = upvalue.Name
                return (instanceName == query or instanceName:find(query))
            end
    
            return toString(upvalue) == query
        elseif upvalueType == "function" then
            local closureName = getInfo(upvalue).name or ''
            return query == closureName or closureName:lower():find(query:lower())
        end
    
        return stringCheck or numberCheck or userDataCheck
    end
    
    local function scan(query, deepSearch)
        local upvalues = {}
    
        for _i, closure in pairs(getGc()) do
            if type(closure) == "function" and not isXClosure(closure) and not upvalues[closure] then
                for index, value in pairs(getUpvalues(closure)) do
                    local valueType = type(value)
    
                    if valueType ~= "table" and compareUpvalue(query, value) then
                        local storage = upvalues[closure]
    
                        if not storage then
                            local newClosure = Closure.new(closure)
                            newClosure.Upvalues[index] = Upvalue.new(newClosure, index, value)
                            upvalues[closure] = newClosure
                        else
                            storage.Upvalues[index] = Upvalue.new(storage, index, value)
                        end
                    elseif deepSearch and valueType == "table" then
                        local storage = upvalues[closure]
                        local table
    
                        for i, v in pairs(value) do
                            if (i ~= value and v ~= value) and (compareUpvalue(query, i, true) or compareUpvalue(query, v)) then
                                if not storage then
                                    local newClosure = Closure.new(closure)
                                    storage = newClosure
                                    upvalues[closure] = newClosure
                                end
    
                                if not table then
                                    table = Upvalue.new(storage, index, value)
                                    table.Scanned = {}
                                    storage.Upvalues[index] = table
                                end
    
                                table.Scanned[i] = v
                            end
                        end
                    end
                end
            end
        end
    
        return upvalues
    end
    
    UpvalueScanner.Scan = scan
    UpvalueScanner.RequiredMethods = requiredMethods
    return UpvalueScanner
end

modules["objects/Closure"] = function()
    local Closure = {}
    local closureCache = {}
    
    function Closure.new(data)
        if closureCache[data] then
            return closureCache[data]
        end
    
        local closure = {}
        local name = getInfo(data).name or ''
        
        closure.Name = (name ~= '' and name) or "Unnamed function"
        closure.Data = data
        closure.Environment = getfenv(data)
    
        closure.Upvalues = {}
        closure.Constants = {}
    
        closure.TemporaryUpvalues = {}
        closure.TemporaryConstants = {}
    
        return closure
    end
    
    return Closureend

modules["objects/Constant"] = function()
    local Constant = {}
    
    function Constant.new(closure, index, value)
        local constant = {}
    
        constant.Closure = closure
        constant.Index = index
        constant.Value = value
        constant.Set = Constant.set
        constant.Update = Constant.update
    
        return constant
    end
    
    function Constant.set(constant, value)
        setConstant(constant.Closure, constant.Index, value)
        constant.Value = value
    end
    
    function Constant.update(constant)
        constant.Value = getConstant(constant.Closure, constant.Index)
    end
    
    return Constantend

modules["objects/LocalScript"] = function()
    local LocalScript = {}
    
    function LocalScript.new(instance)
        local localScript = {}
        local closure = getScriptClosure(instance)
    
        localScript.Instance = instance
        localScript.Environment = getSenv(instance)
        localScript.Constants = getConstants(closure)
        localScript.Protos = getProtos(closure)
    
        return localScript
    end
    
    return LocalScriptend

modules["objects/ModuleScript"] = function()
    local ModuleScript = {}
    
    function ModuleScript.new(instance)
        local moduleScript = {}
        local closure = getScriptClosure(instance)
    
        moduleScript.Instance = instance
        moduleScript.Constants = getConstants(closure)
        moduleScript.Protos = getProtos(closure)
    
    
        return moduleScript
    end
    
    return ModuleScript
end

modules["objects/Remote"] = function()
    local Remote = {}
    
    function Remote.new(instance)
        local remote = {}
    
        remote.Instance = instance
        remote.Logs = {}
        remote.Calls = 0
        remote.Blocked = false
        remote.Ignored = false
        remote.Clear = Remote.clear
        remote.Block = Remote.block
        remote.Ignore = Remote.ignore
        remote.BlockedArgs = {}
        remote.IgnoredArgs = {}
        remote.BlockArg = Remote.blockArg
        remote.IgnoreArg = Remote.ignoreArg
        remote.AreArgsBlocked = Remote.areArgsBlocked
        remote.AreArgsIgnored = Remote.areArgsIgnored
        remote.IncrementCalls = Remote.incrementCalls
        remote.DecrementCalls = Remote.decrementCalls
    
        return remote
    end
    
    function Remote.clear(remote)
        remote.Calls = 0
        remote.Logs = {}
    end
    
    function Remote.block(remote)
        remote.Blocked = not remote.Blocked
    end
    
    function Remote.ignore(remote)  
        remote.Ignored = not remote.Ignored
    end
    
    function Remote.blockArg(remote, index, value, byType)
        local blockedArgs = remote.BlockedArgs
        local blockedIndex = blockedArgs[index]
    
        if not blockedIndex then
            blockedIndex = {
                types = {},
                values = {}
            }
            blockedArgs[index] = blockedIndex
        end
    
        if byType then
            blockedIndex.types[value] = true
        else
            blockedIndex.values[value] = true
        end
    end
    
    function Remote.ignoreArg(remote, index, value, byType)
        local ignoredArgs = remote.IgnoredArgs
        local indexIgnore = ignoredArgs[index]
    
        if not indexIgnore then
            indexIgnore = {
                types = {},
                values = {}
            }
    
            ignoredArgs[index] = indexIgnore
        end
    
        if byType then
            indexIgnore.types[value] = true
        else
            indexIgnore.values[value] = true
        end
    end
    
    function Remote.areArgsBlocked(remote, args)
        local blockedArgs = remote.BlockedArgs
    
        for index, value in pairs(args) do
            local indexBlock = blockedArgs[index]
            
            if indexBlock and ( indexBlock.types[typeof(value)] or indexBlock.values[value] ~= nil ) then
                return true
            end
        end
    end
    
    function Remote.areArgsIgnored(remote, args)
        local ignoredArgs = remote.IgnoredArgs
    
        for index, value in pairs(args) do
            local indexIgnore = ignoredArgs[index]
    
            if indexIgnore and ( indexIgnore.types[typeof(value)] or indexIgnore.values[value] ~= nil ) then
                return true
            end
        end
    end
    
    function Remote.incrementCalls(remote, vargs)
        remote.Calls = remote.Calls + 1
        table.insert(remote.Logs, vargs)
    end
    
    function Remote.decrementCalls(remote, vargs)
        local logs = remote.Logs
    
        remote.Calls = remote.Calls - 1
        table.remove(logs, table.find(logs, vargs))
    end
    
    return Remoteend

modules["objects/Upvalue"] = function()
    local Upvalue = {}
    local TableUpvalue = {}
    
    function Upvalue.new(closure, index, value)
        local upvalue = {}
    
        upvalue.Closure = closure
        upvalue.Index = index
        upvalue.Value = value
        upvalue.Set = Upvalue.set
        upvalue.Update = Upvalue.update
    
        return upvalue
    end
    
    function Upvalue.set(upvalue, value)
        setUpvalue(upvalue.Closure.Data, upvalue.Index, value)
        upvalue.Value = value
    end
    
    function Upvalue.update(upvalue, newValue)
        local value = newValue or getUpvalue(upvalue.Closure.Data, upvalue.Index)
        local scanned = upvalue.Scanned
    
        upvalue.Value = value
    
        if type(value) ~= "table" and scanned then
            upvalue.Scanned = nil
        elseif scanned then
            for i,v in pairs(value) do
                if scanned[i] then
                    scanned[i] = v
                end
            end
        end
    end
    
    return Upvalue, TableUpvalueend

modules["ohaux"] = function()
    local aux = {}
    
    local getGc = getgc
    local getInfo = debug.getinfo or getinfo
    local getUpvalue = debug.getupvalue or getupvalue or getupval
    local getConstants = debug.getconstants or getconstants or getconsts
    local isXClosure = is_synapse_function or issentinelclosure or is_protosmasher_closure or is_sirhurt_closure or istempleclosure or checkclosure
    local isLClosure = islclosure or is_l_closure or (iscclosure and function(f) return not iscclosure(f) end)
    
    assert(getGc and getInfo and getConstants and isXClosure, "Your exploit is not supported")
    
    local placeholderUserdataConstant = newproxy(false)
    
    local function matchConstants(closure, list)
        if not list then
            return true
        end
        
        local constants = getConstants(closure)
        
        for index, value in pairs(list) do
            if constants[index] ~= value and value ~= placeholderUserdataConstant then
                return false
            end
        end
        
        return true
    end
    
    local function searchClosure(script, name, upvalueIndex, constants)
        for _i, v in pairs(getGc()) do
            local parentScript = rawget(getfenv(v), "script")
    
            if type(v) == "function" and 
                isLClosure(v) and 
                not isXClosure(v) and 
                (
                    (script == nil and parentScript.Parent == nil) or script == parentScript
                ) 
                and pcall(getUpvalue, v, upvalueIndex)
            then
                if ((name and name ~= "Unnamed function") and getInfo(v).name == name) and matchConstants(v, constants) then
                    return v
                elseif (not name or name == "Unnamed function") and matchConstants(v, constants) then
                    return v
                end
            end
        end
    end
    
    aux.placeholderUserdataConstant = placeholderUserdataConstant
    aux.searchClosure = searchClosure
    
    return aux
end

modules["ui/controls/CheckBox"] = function()
    local CheckBox = {}
    
    function CheckBox.new(instance)
        local checkBox = {}
        local toggle = instance:FindFirstChild("Toggle") or instance
        local label = toggle.Label
    
        toggle.MouseButton1Click:Connect(function()
            checkBox.Enabled = not checkBox.Enabled
    
            if checkBox.Callback then
                checkBox.Callback(checkBox.Enabled)
            end
    
            label.Text = (checkBox.Enabled and '✓') or ''
        end)
    
        checkBox.Enabled = label.Text == '✓'
        checkBox.Instance = instance
        checkBox.SetCallback = CheckBox.setCallback
    
        return checkBox
    end
    
    function CheckBox.setCallback(checkBox, callback)
        checkBox.Callback = callback
    end
    
    return CheckBoxend

modules["ui/controls/ContextMenu"] = function()
    local Assets = import("rbxassetid://5042114982").Controls
    local Storage = import("rbxassetid://11389137937").ContextMenus
    
    local Players = game:GetService("Players")
    local UserInput = game:GetService("UserInputService")
    local TextService = game:GetService("TextService")
    local TweenService = game:GetService("TweenService")
    
    local client = Players.LocalPlayer
    local mouse = client:GetMouse()
    
    local ContextMenuButton = {}
    local ContextMenu = {}
    
    local currentContextMenu
    local constants = {
        fadeLength = TweenInfo.new(0.15),
        textWidth = Vector2.new(1337420, 20)
    }
    
    function ContextMenuButton.new(icon, text)
        local contextMenuButton = {}
        local instance = Assets.ContextMenuButton:Clone()
        local label = instance.Label
    
        local enterAnimation = TweenService:Create(label, constants.fadeLength, { TextTransparency = 0 })
        local leaveAnimation = TweenService:Create(label, constants.fadeLength, { TextTransparency = 0.2 })
    
        label.Text = text
        instance.Icon.Image = icon
    
        instance.MouseButton1Click:Connect(function()
            if contextMenuButton.Callback then
                contextMenuButton.Callback()
            end
        end)
    
        instance.MouseEnter:Connect(function()
            enterAnimation:Play()
        end)
    
        instance.MouseLeave:Connect(function()
            leaveAnimation:Play()
        end)
    
        contextMenuButton.Instance = instance
        contextMenuButton.SetIcon = ContextMenuButton.setIcon
        contextMenuButton.SetText = ContextMenuButton.setText
        contextMenuButton.SetCallback = ContextMenuButton.setCallback
        return contextMenuButton
    end
    
    function ContextMenuButton.setIcon(contextMenuButton, newIcon)
        contextMenuButton.Instance.Icon.Image = newIcon
    end
    
    function ContextMenuButton.setText(contextMenuButton, newText)
        contextMenuButton.Instance.Label.Text = newText
    end
    
    function ContextMenuButton.setCallback(contextMenuButton, callback)
        if not contextMenuButton.Callback then
            contextMenuButton.Callback = callback
        end
    end
    
    function ContextMenu.new(contextMenuButtons)
        local contextMenu = {}
        local instance = Assets.ContextMenu:Clone()
        local instanceWidth = 0
        local instanceHeight = 0
    
        instance.Parent = Storage
        
        for _i, contextMenuButton in pairs(contextMenuButtons) do
            local buttonInstance = contextMenuButton.Instance
            local textWidth = TextService:GetTextSize(buttonInstance.Label.Text, 18, "SourceSans", constants.textWidth).X
    
            buttonInstance.Parent = instance.List
            buttonInstance.TextWrapped = false
    
            local buttonWidth = buttonInstance.Icon.AbsoluteSize.X + textWidth + 16
            
            if buttonWidth > instanceWidth then
                instanceWidth = buttonWidth
            end
    
            instanceHeight = instanceHeight + buttonInstance.AbsoluteSize.Y
        end
        
        instance.Size = UDim2.new(0, instanceWidth, 0, instanceHeight)
        instance.Visible = false
        
        contextMenu.Instance = instance
        contextMenu.Visible = false
        contextMenu.Buttons = {}
        contextMenu.Show = ContextMenu.show
        contextMenu.Hide = ContextMenu.hide
        return contextMenu
    end
    
    function ContextMenu.add(contextMenu, contextMenuButton)
        table.insert(contextMenu.Buttons, contextMenuButton)
    end
    
    function ContextMenu.show(contextMenu)
        if currentContextMenu then
            currentContextMenu:Hide()
        end
    
        local instance = contextMenu.Instance
    
        instance.Visible = true
        instance.Position = UDim2.new(0, mouse.X, 0, mouse.Y)
        
        contextMenu.Visible = true
        currentContextMenu = contextMenu
    end
    
    function ContextMenu.hide(contextMenu)
        contextMenu.Visible = false
        contextMenu.Instance.Visible = false
    end
    
    UserInput.InputEnded:Connect(function(input)
        if currentContextMenu and input.UserInputType == Enum.UserInputType.MouseButton1 then
            currentContextMenu:Hide()
            currentContextMenu = nil
        end
    end)
    
    return ContextMenu, ContextMenuButtonend

modules["ui/controls/Dropdown"] = function()
    local UserInput = game:GetService("UserInputService")
    
    local Dropdown = {}
    local dropdownCache = {}
    
    function Dropdown.new(instance)
        local dropdown = {}
        local selection = instance.Selection
    
        instance.Collapse.MouseButton1Click:Connect(function()
            local collapsed = not dropdown.Collapsed
    
            selection.Visible = not collapsed
            dropdown.Collapsed = collapsed
        end)
    
        for _i, v in pairs(instance.Selection.Clip.List:GetChildren()) do
            if v:IsA("TextButton") then
                v.MouseButton1Click:Connect(function()
    
                    dropdown:Collapse(v.Name)
                end)
            end
        end
    
        dropdown.Collapse = Dropdown.collapse
        dropdown.Collapsed = true
        dropdown.Instance = instance
        dropdown.SetSelected = Dropdown.setSelected
        dropdown.SetCallback = Dropdown.setCallback
    
        table.insert(dropdownCache, dropdown)
    
        return dropdown
    end
    
    function Dropdown.setSelected(dropdown, buttonName)
        local instance = dropdown.Instance
        local selection = instance.Selection.Clip.List
        local button = selection:FindFirstChild(buttonName)
    
        if button then
            instance.Label.Text = buttonName
    
            dropdown.Collapsed = true
            dropdown.Selected = button
            dropdown:Callback(button)
        end
    end
    
    function Dropdown.collapse(dropdown, name)
        local instance = dropdown.Instance
        local selection = instance.Selection
    
        if name then
            local button = selection.Clip.List:FindFirstChild(name)
    
            if button then
                instance.Label.Text = button.Name
    
                dropdown.Selected = button
                dropdown:Callback(button)
            end
        end
    
        selection.Visible = false
        dropdown.Collapsed = true
    end
    
    function Dropdown.setCallback(dropdown, callback)
        if not dropdown.Callback then
            dropdown.Callback = callback
        end
    end
    
    
    
    
    
    
    
    
    
    return Dropdownend

modules["ui/controls/List"] = function()
    local UserInput = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    
    local List = {}
    local ListButton = {}
    
    local lists = {}
    local ctrlHeld = false
    local constants = {
        tweenTime = TweenInfo.new(0.15),
        selected = Color3.fromRGB(55, 35, 35),
        deselected = Color3.fromRGB(35, 35, 35)
    }
    
    function List.new(instance, multiClick)
        local list = {}
    
        instance.CanvasSize = UDim2.new(0, 0, 0, 15)
    
        list.Buttons = {}
        list.Instance = instance
        list.Clear = List.clear
        list.Recalculate = List.recalculate
        list.BindContextMenu = List.bindContextMenu
        list.BindContextMenuSelected = List.bindContextMenuSelected
        list.MultiClickEnabled = multiClick
    
        table.insert(lists, list)
    
        return list
    end
    
    function ListButton.new(instance, list)
        local listButton = {}
        local listInstance = list.Instance
    
        list.Buttons[instance] = listButton
    
        if instance.Visible then
            listInstance.CanvasSize = listInstance.CanvasSize + UDim2.new(0, 0, 0, instance.AbsoluteSize.Y + 5)
        end
    
        instance.Parent = listInstance
        instance.MouseButton1Click:Connect(function()
            if not ctrlHeld and listButton.Callback then
                listButton.Callback()
            elseif list.MultiClickEnabled and ctrlHeld then
                if not list.Selected then
                    list.Selected = {}
                end
    
                if listButton.SelectedCallback then
                    listButton.SelectedCallback()
                end
    
                local foundButton = table.find(list.Selected, listButton)
    
                if not foundButton then
                    table.insert(list.Selected, listButton)
                    listButton.SelectAnimation:Play()
                else
                    table.remove(list.Selected, foundButton)
                    listButton.DeselectAnimation:Play()
                end
            end
        end)
    
        instance.MouseButton2Click:Connect(function()
            if not ctrlHeld and listButton.RightCallback then
                listButton.RightCallback()
            end
        end)
    
        listButton.List = list
        listButton.Instance = instance
        listButton.SetCallback = ListButton.setCallback
        listButton.SetRightCallback = ListButton.setRightCallback
        listButton.SetSelectedCallback = ListButton.setSelectedCallback
        listButton.Remove = ListButton.remove
        listButton.SelectAnimation = TweenService:Create(instance, constants.tweenTime, { ImageColor3 = constants.selected })
        listButton.DeselectAnimation = TweenService:Create(instance, constants.tweenTime, { ImageColor3 = constants.deselected })
        return listButton
    end
    
    function List.clear(list)
        local instance = list.Instance
    
        for _i, listButton in pairs(instance:GetChildren()) do
            if listButton:IsA("ImageButton") then
                listButton:Destroy()
            end
        end
    
        instance.CanvasSize = UDim2.new(0, 0, 0, 15)
        list.Buttons = {}
    end
    
    function List.recalculate(list)
        local newHeight = 15
    
        for instance in pairs(list.Buttons) do
            if instance.Visible then
                newHeight = newHeight + instance.AbsoluteSize.Y + 5
            end
        end
    
        list.Instance.CanvasSize = UDim2.new(0, 0, 0, newHeight)
    end
    
    function List.bindContextMenu(list, contextMenu)
        if not list.BoundContextMenu then
            local function showContextMenu()
                if not list.Selected then
                    contextMenu:Show()
                end
            end
    
            list.Instance.ChildAdded:Connect(function(instance)
                instance.MouseButton2Click:Connect(showContextMenu)
            end)
    
            list.BoundContextMenu = contextMenu
        end
    end
    
    function List.bindContextMenuSelected(list, contextMenu)
        if not list.BoundContextMenuSelected then
            local function showContextMenu()
                if list.Selected then
                    contextMenu:Show()
                end
            end
    
            list.Instance.ChildAdded:Connect(function(instance)
                instance.MouseButton2Click:Connect(showContextMenu)
            end)
    
            list.BoundContextMenuSelected = contextMenu
        end
    end
    
    function ListButton.setCallback(listButton, callback)
        listButton.Callback = callback
    end
    
    function ListButton.setRightCallback(listButton, callback)
        listButton.RightCallback = callback
    end
    
    function ListButton.setSelectedCallback(listButton, callback)
        listButton.SelectedCallback = callback
    end
    
    function ListButton.remove(listButton)
        local list = listButton.List
        local instance = listButton.Instance
        local listInstance = list.Instance
    
        listInstance.CanvasSize = listInstance.CanvasSize - UDim2.new(0, 0, 0, instance.AbsoluteSize.Y + 5)
        list.Buttons[instance] = nil 
    
        instance:Destroy()
    end
    
    oh.Events.ListInputBegan = UserInput.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.LeftControl then
            ctrlHeld = true
        elseif not ctrlHeld and input.UserInputType == Enum.UserInputType.MouseButton1 then
            for _i, list in pairs(lists) do
                if list.Selected then
                    for _k, listButton in pairs(list.Selected) do
                        listButton.DeselectAnimation:Play()
                    end
    
                    list.Selected = nil
                end
            end
        end
    end)
    
    oh.Events.ListInputEnded = UserInput.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.LeftControl then
            ctrlHeld = false 
        end
    end)
    
    return List, ListButtonend

modules["ui/controls/MessageBox"] = function()
    local TextService = game:GetService("TextService")
    
    local Interface = import("rbxassetid://11389137937")
    local Base = Interface.Base
    local Object = Base.MessageBox
    local Shadow = Base.MessageBoxShadow
    
    local MessageBox = {}
    local MessageType = {}
    
    local selectedButtons
    local firstClickEvent 
    local secondClickEvent
    
    local constants = {
        dynamicWidth = Vector2.new(133742069, 25),
        dynamicHeight = Vector2.new(Object.AbsoluteSize.X, 133742069)
    }
    
    MessageType.OK = 1
    MessageType.OKCancel = 2
    MessageType.YesNo = 3
    
    function MessageBox.Show(title, message, messageType, firstCallback, secondCallback)
        if firstClickEvent then
            firstClickEvent:Disconnect()
            
            if secondClickEvent then
                secondClickEvent:Disconnect()
            end
        end
        
        local first, second
        local inner = Object.Inner
        local buttons = inner.Buttons
    
        local messageWidth = TextService:GetTextSize(title, 18, "SourceSans", constants.dynamicWidth).X + 10
        if messageWidth <= 300 then
            messageWidth = 300
        end
    
        local messageHeight = TextService:GetTextSize(message, 18, "SourceSans", Vector2.new(messageWidth - 30, 133742069)).Y + 95
    
        if messageType == MessageType.OK then
            selectedButtons = buttons.OK
            first =  selectedButtons.OK
        elseif messageType == MessageType.OKCancel then
            selectedButtons = buttons.OKCancel
            first = selectedButtons.OK
            second = selectedButtons.Cancel
        elseif messageType == MessageType.YesNo then
            selectedButtons = buttons.YesNo
            first = selectedButtons.Yes
            second = selectedButtons.No
        else
            return
        end
    
        Object.Title.Text = title
        inner.Message.Text = message
    
        Object.Size = UDim2.new(0, messageWidth, 0, messageHeight)
        Object.Position = UDim2.new(0.5, -(messageWidth / 2), 0.5, -(messageHeight / 2))
    
        firstClickEvent = first.MouseButton1Click:Connect(function()
            if firstCallback then
                firstCallback()
            end
    
            MessageBox.Hide()
        end)
    
        if second then
            secondClickEvent = second.MouseButton1Click:Connect(function()
                if secondCallback then
                    secondCallback()
                end
    
                MessageBox.Hide()
            end)
        end
    
        selectedButtons.Visible = true
        Shadow.Visible = true
        Object.Visible = true
    end
    
    function MessageBox.Hide()
        if firstClickEvent then
            firstClickEvent:Disconnect()
    
            if secondClickEvent then
                secondClickEvent:Disconnect()
            end
        end
    
        firstClickEvent = nil
        secondClickEvent = nil
    
        Shadow.Visible = false
        Object.Visible = false
    
        selectedButtons.Visible = false
    end
    
    return MessageBox, MessageTypeend

modules["ui/controls/Prompt"] = function()
    local Prompts = import("rbxassetid://11389137937").Base.Prompts
    
    local Prompt = {}
    local currentPrompt
    
    function Prompt.new(instance)
        local prompt = {}
    
        prompt.Instance = instance
        prompt.Show = Prompt.show
        prompt.Hide = Prompt.hide
    
        return prompt
    end
    
    function Prompt.show(prompt)
        currentPrompt = prompt
    
        Prompts.PromptShadow.Visible = true
        prompt.Instance.Visible = true
    end
    
    function Prompt.hide(prompt)
        Prompts.PromptShadow.Visible = false
        prompt.Instance.Visible = false
    
        currentPrompt = nil
    end
    
    return Prompt
end

modules["ui/controls/TabSelector"] = function()
    local TweenService = game:GetService("TweenService")
    
    local TabSelector = {}
    
    local Base = import("rbxassetid://11389137937").Base
    local Tabs = Base.Tabs.Container
    local Pages = Base.Body.Pages
    
    local MessageBox, MessageType = import("ui/controls/MessageBox")
    
    local requiredMethods = {
        ConstantScanner = import("modules/ConstantScanner").RequiredMethods,
        UpvalueScanner = import("modules/UpvalueScanner").RequiredMethods,
        ScriptScanner = import("modules/ScriptScanner").RequiredMethods,
        ModuleScanner = import("modules/ModuleScanner").RequiredMethods,
        ClosureSpy = import("modules/ClosureSpy").RequiredMethods,
        RemoteSpy = import("modules/RemoteSpy").RequiredMethods
    }
    
    local constants = {
        fadeLength = TweenInfo.new(0.15),
        tabSelected = Color3.fromRGB(45, 45, 45),
        iconSelected = Color3.fromRGB(255, 255, 255),
        tabUnselected = Color3.fromRGB(20, 20, 20),
        iconUnselected = Color3.fromRGB(127, 127, 127)
    }
    
    local selectedTab 
    local selectedPage = Pages.Home
    
    local function methodsCheck(methods)
        local globalMethods = oh.Methods
        local missingMethods = ""
    
        for methodName in pairs(methods) do
            if not globalMethods[methodName] then
                missingMethods = missingMethods .. methodName .. ", "
            end
        end
    
        return (missingMethods ~= "" and missingMethods:sub(1, -3)) or nil
    end
    
    local animationCache = {}
    local function selectTab(tabName)
        local methodsFound = requiredMethods[tabName]
        local missingMethods = methodsFound and methodsCheck(methodsFound)
    
        if missingMethods then
            return MessageBox.Show(
                "Your exploit does not support this section",
                "The following functions are missing from your exploit: " .. missingMethods,
                MessageType.OK
            )
        end
    
        local tab = Tabs:FindFirstChild(tabName)
        local page = Pages:FindFirstChild(tabName)
    
        if selectedTab then
            local tabAnimation = animationCache[selectedTab]
            tabAnimation.unselected:Play()
            tabAnimation.iconUnselected:Play()
        end
    
        selectedPage.Visible = false
        page.Visible = true
        tab.ImageColor3 = constants.tabSelected
        tab.Icon.ImageColor3 = constants.iconSelected
    
        oh.setStatus(page.Name:sub(1, 1) .. page.Name:sub(2):gsub('%u', function(c) return ' ' .. c end))
        
        selectedTab = tab
        selectedPage = page
        return true
    end
    
    for _i, tab in pairs(Tabs:GetChildren()) do
        if tab:IsA("ImageButton") then
            local selected = TweenService:Create(tab, constants.fadeLength, { ImageColor3 = constants.tabSelected })
            local unselected = TweenService:Create(tab, constants.fadeLength, { ImageColor3 = constants.tabUnselected })
            local iconSelected = TweenService:Create(tab.Icon, constants.fadeLength, { ImageColor3 = constants.iconSelected })
            local iconUnselected = TweenService:Create(tab.Icon, constants.fadeLength, { ImageColor3 = constants.iconUnselected })
    
            animationCache[tab] = {
                selected = selected,
                unselected = unselected,
                iconSelected = iconSelected,
                iconUnselected = iconUnselected
            }
    
            tab.MouseButton1Click:Connect(function()
                if selectedTab ~= tab and Tabs:FindFirstChild(tab.Name) then
                    selectTab(tab.Name)
                end
            end)
    
            tab.MouseEnter:Connect(function()
                if selectedPage ~= Pages:FindFirstChild(tab.Name) then
                    selected:Play()
                    iconSelected:Play()
                end
            end)
    
            tab.MouseLeave:Connect(function()
                if selectedPage ~= Pages:FindFirstChild(tab.Name) then
                    unselected:Play()
                    iconUnselected:Play()
                end
            end)
        end
    end
    
    TabSelector.SelectTab = selectTab
    return TabSelector
end

modules["ui/main"] = function()
    local CoreGui = game:GetService("CoreGui")
    local UserInput = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    
    local Interface = import("rbxassetid://11389137937")
    
    if oh.Cache["ui/main"] then
    	return Interface
    end
    
    import("ui/controls/TabSelector")
    local MessageBox, MessageType = import("ui/controls/MessageBox")
    
    local RemoteSpy
    local ClosureSpy
    local ScriptScanner
    local ModuleScanner
    local UpvalueScanner
    local ConstantScanner
    
    xpcall(function()
    	RemoteSpy = import("ui/modules/RemoteSpy")
    	ClosureSpy = import("ui/modules/ClosureSpy")
    	ScriptScanner = import("ui/modules/ScriptScanner")
    	ModuleScanner = import("ui/modules/ModuleScanner")
    	UpvalueScanner = import("ui/modules/UpvalueScanner")
    	ConstantScanner = import("ui/modules/ConstantScanner")
    end, function(err)
    	local message
    	if err:find("valid member") then
    		message = "The UI has updated, please rejoin and restart. If you get this message more than once, screenshot this message and report it in the Hydroxide server.\n\n" .. err
    	else
    		message = "Report this error in Hydroxide's server:\n\n" .. err
    	end
    
    	MessageBox.Show("An error has occurred", message, MessageType.OK, function()
    		Interface:Destroy() 
    	end)
    end)
    
    local constants = {
    	opened = UDim2.new(0.5, -325, 0.5, -175),
    	closed = UDim2.new(0.5, -325, 0, -400),
    	reveal = UDim2.new(0.5, -15, 0, 20),
    	conceal = UDim2.new(0.5, -15, 0, -75)
    }
    
    local Open = Interface.Open
    local Base = Interface.Base
    local Drag = Base.Drag
    local Status = Base.Status
    local Collapse = Drag.Collapse
    
    function oh.setStatus(text)
    	Status.Text = '• Status: ' .. text
    end
    
    function oh.getStatus()
    	return Status.Text:gsub('• Status: ', '')
    end
    
    local dragging
    local dragStart
    local startPos
    
    Drag.InputBegan:Connect(function(input)
    	if input.UserInputType == Enum.UserInputType.MouseButton1 then
    		local dragEnded 
    
    		dragging = true
    		dragStart = input.Position
    		startPos = Base.Position
    
    		dragEnded = input.Changed:Connect(function()
    			if input.UserInputState == Enum.UserInputState.End then
    				dragging = false
    				dragEnded:Disconnect()
    			end
    		end)
    	end
    end)
    
    oh.Events.Drag = UserInput.InputChanged:Connect(function(input)
    	if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
    		local delta = input.Position - dragStart
    		Base.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    	end
    end)
    
    Open.MouseButton1Click:Connect(function()
    	Open:TweenPosition(constants.conceal, "Out", "Quad", 0.15)
    	Base:TweenPosition(constants.opened, "Out", "Quad", 0.15)
    end)
    
    Collapse.MouseButton1Click:Connect(function()
    	Base:TweenPosition(constants.closed, "Out", "Quad", 0.15)
    	Open:TweenPosition(constants.reveal, "Out", "Quad", 0.15)
    end)
    
    Interface.Name = HttpService:GenerateGUID(false)
    if getHui then
    	Interface.Parent = getHui()
    else
    	if syn then
    		syn.protect_gui(Interface)
    	end
    
    	Interface.Parent = CoreGui
    end
    
    return Interface
end

modules["ui/modules/ClosureSpy"] = function()
    local TextService = game:GetService("TextService")
    local TweenService = game:GetService("TweenService")
    
    local ClosureSpy = {}
    local Methods = import("modules/ClosureSpy")
    
    if not hasMethods(Methods.RequiredMethods) then
        return ClosureSpy
    end
    
    local Prompt = import("ui/controls/Prompt")
    local CheckBox = import("ui/controls/CheckBox")
    local Dropdown = import("ui/controls/Dropdown")
    local List, ListButton = import("ui/controls/List")
    local MessageBox, MessageType = import("ui/controls/MessageBox")
    local ContextMenu, ContextMenuButton = import("ui/controls/ContextMenu")
    
    local Base = import("rbxassetid://11389137937").Base
    local Assets = import("rbxassetid://5042114982").ClosureSpy
    
    local Prompts = Base.Prompts
    local Page = Base.Body.Pages.ClosureSpy
    
    local ClosureList = Page.List
    local ListQuery = ClosureList.Query
    local ListSearch = ListQuery.Search
    local ListRefresh = ListQuery.Refresh
    local ListResults = ClosureList.Results.Clip.Content
    
    local ClosureLogs = Page.Logs
    local LogsButtons = ClosureLogs.Buttons
    local LogsClosure = ClosureLogs.ClosureObject
    local LogsBack = ClosureLogs.Back
    local LogsResults = ClosureLogs.Results.Clip.Content
    
    local ClosureConditions = Page.Conditions
    local ConditionsClosure = ClosureConditions.ClosureObject
    local ConditionsButtons = ClosureConditions.Buttons
    local ConditionsResults = ClosureConditions.Results.Clip.Content
    local ConditionsBack = ClosureConditions.Back
    
    local NewClosureCondition = Prompts.NewClosureCondition
    local NewConditionInner = NewClosureCondition.Inner
    local NewConditionButtons = NewConditionInner.Buttons
    local NewConditionContent = NewConditionInner.Content
    local NewConditionIndex = NewConditionContent.Index
    
    local currentClosures = Methods.CurrentClosures
    
    local icons = {
        type = "rbxassetid://4702850565",
        status = "rbxassetid://4909102841",
        valueType = "rbxassetid://4702850565",
        block = "rbxassetid://4891641806",
        unblock = "rbxassetid://4891642508",
        ignore = "rbxassetid://4842578510",
        unignore = "rbxassetid://4842578818"
    }
    
    local constants = {
        fadeLength = TweenInfo.new(0.15),
        textWidth = Vector2.new(1337420, 20),
        normalColor = Color3.new(1, 1, 1),
        blockedColor = Color3.fromRGB(170, 0, 0),
        ignoredColor = Color3.fromRGB(100, 100, 100)
    }
    
    local newClosureCondition = Prompt.new(NewClosureCondition)
    local conditionStatus = Dropdown.new(NewConditionContent.Status)
    local conditionType = Dropdown.new(NewConditionContent.Type)
    local conditionValueType = Dropdown.new(NewConditionContent.ValueType)
    
    local closureList = List.new(ListResults, true)
    local hookLogs = List.new(LogsResults)
    local closureConditions = List.new(ConditionsResults, true)
    
    local currentLogs = {}
    local removed = {}
    
    local selected = {
        logs = {},
        conditions = {}
    }
    
    local conditionContext = ContextMenuButton.new("rbxassetid://4891633802", "Call Conditions")
    local clearContext = ContextMenuButton.new("rbxassetid://4892169181", "Clear Calls")
    local ignoreContext = ContextMenuButton.new("rbxassetid://4842578510", "Ignore Calls")
    local blockContext = ContextMenuButton.new("rbxassetid://4891641806", "Block Calls")
    local removeContext = ContextMenuButton.new("rbxassetid://4702831188", "Remove Log")
    
    local callingScriptContext = ContextMenuButton.new("rbxassetid://4800244808", "Get Calling Script")
    local spyClosureContext = ContextMenuButton.new("rbxassetid://4666593447", "Spy Calling Function")
    
    local removeConditionContext = ContextMenuButton.new("rbxassetid://4702831188", "Remove Condition")
    
    local clearContextSelected = ContextMenuButton.new("rbxassetid://4892169181", "Clear Calls")
    local ignoreContextSelected = ContextMenuButton.new("rbxassetid://4842578510", "Ignore Calls")
    local blockContextSelected = ContextMenuButton.new("rbxassetid://4891641806", "Block Calls")
    local unignoreContextSelected = ContextMenuButton.new("rbxassetid://4842578818", "Unignore Calls")
    local unblockContextSelected = ContextMenuButton.new("rbxassetid://4891642508", "Unblock Calls")
    local removeContextSelected = ContextMenuButton.new("rbxassetid://4702831188", "Remove Logs")
    
    local removeConditionContextSelected = ContextMenuButton.new("rbxassetid://4702831188", "Remove Conditions")
    
    local closureListMenu = ContextMenu.new({ conditionContext, clearContext, ignoreContext, blockContext, removeContext })
    local closureListMenuSelected = ContextMenu.new({ clearContextSelected, ignoreContextSelected, unignoreContextSelected, blockContextSelected, unblockContextSelected, removeContextSelected })
    local hookLogsMenu = ContextMenu.new({ callingScriptContext, spyClosureContext, repeatCallContext })
    local closureConditionMenu = ContextMenu.new({ removeConditionContext })
    local closureConditionMenuSelected = ContextMenu.new({ removeConditionContextSelected })
    
    local function checkCurrentIgnored()
        local selectedHook = (selected.hookLog or selected.logContext).Hook
    
        LogsButtons.Ignore.Label.Text = (selectedHook.Ignored and "Unignore") or "Ignore"
        LogsButtons.Ignore.Icon.Image = (selectedHook.Ignored and icons.unignore) or icons.ignore
    
        local newWidth = TextService:GetTextSize((selectedHook.Ignored and "Unignore") or "Ignore", 18, "SourceSans", constants.textWidth).X + 30
    
        LogsButtons.Ignore.Size = UDim2.new(0, newWidth, 0, 20)
    end
    
    local function checkCurrentBlocked()
        local selectedHook = (selected.hookLog or selected.logContext).Hook
    
        LogsButtons.Block.Label.Text = (selectedHook.Blocked and "Unblock") or "Block"
        LogsButtons.Block.Icon.Image = (selectedHook.Blocked and icons.unblock) or icons.block
    
        local newWidth = TextService:GetTextSize((selectedHook.Blocked and "Unblock") or "Block", 18, "SourceSans", constants.textWidth).X + 30
    
        LogsButtons.Block.Size = UDim2.new(0, newWidth, 0, 20)
    end
    
    local Condition = {}
    function Condition.new(closure, status, index, value, type)
        local condition = {}
        local instance = Assets.ConditionPod:Clone() 
        local content = instance.Content
        local identifiers = instance.Identifiers
        local button = ListButton.new(instance, closureConditions)
        local check = CheckBox.new(content.Toggle)
        local valueType = type or typeof(value)
        local typeIcons = oh.Constants.Types
        local branch = (status == "Ignore" and closure.IgnoredArgs[index]) or closure.BlockedArgs[index]
    
        condition.Branch = branch
        condition.Status = status
        condition.Index = index
        condition.Value = value
        condition.Type = type
        condition.Closure = closure
        condition.Enabled = true
        condition.Instance = instance
        condition.Button = button
        condition.Toggle = Condition.toggle
        condition.Remove = Condition.remove
    
        check:SetCallback(function()
            condition:Toggle()
        end)
    
        button:SetRightCallback(function()
            selected.condition = condition
        end)
    
        button:SetSelectedCallback(function()
            if not table.find(selected.conditions, condition) then
                table.insert(selected.conditions, condition)
            end
        end)
        
        if byType then
            instance.Identifiers.ByType.Visible = false
        end 
        
        identifiers.ByType.Visible = type ~= nil
        identifiers.Status.Image = (status == "Ignore" and icons.ignore) or icons.block
        identifiers.Status.Border.Image = identifiers.Status.Image
    
        content.Index.Text = index
        content.Label.Text = (type and valueType) or toString(value)
        content.Label.TextColor3 = oh.Constants.Syntax[valueType] or oh.Constants.Syntax["userdata"]
        content.Type.Image = typeIcons[valueType] or typeIcons["userdata"]
    
        return condition
    end
    
    function Condition.toggle(condition)
        condition.Enabled = not condition.Enabled
    
        local index = condition.Index
        local value = condition.Value
        local closure = condition.Closure
        local ignoredArgs = closure.IgnoredArgs[index]
        local blockedArgs = closure.BlockedArgs[index]
        local argStatus = (condition.Status == "Ignore" and ignoredArgs) or blockedArgs
    
        if value then
            argStatus.values[value] = condition.Enabled or nil
        else
            argStatus.types[condition.Type] = condition.Enabled or nil
        end
    end
    
    function Condition.remove(condition)
        local branch = condition.Branch
        condition.Button:Remove()
    
        if condition.Value then
            branch.values[condition.Value] = nil
        else
            branch.types[condition.Type] = nil
        end
    end
    
    local function createConditions(hook)
        closureConditions:Clear()
    
        ClosureList.Visible = false
        ClosureLogs.Visible = false
        ClosureConditions.Visible = true
    
        local nameLength = TextService:GetTextSize(hook.Closure.Name, 18, "SourceSans", constants.textWidth).X + 20
    
        ConditionsClosure.Icon.Image = oh.Constants.Types["function"]
        ConditionsClosure.Label.Text = hook.Closure.Name
        ConditionsClosure.Label.Size = UDim2.new(0, nameLength, 0, 20)
        ConditionsClosure.Position = UDim2.new(1, -nameLength, 0, 0)
    
        for index, arg in pairs(hook.IgnoredArgs) do
            for type in pairs(arg.types) do
                Condition.new(hook, "Ignore", index, nil, type)
            end
    
            for value in pairs(arg.values) do
                Condition.new(hook, "Ignore", index, value)
            end
        end
    
        for index, arg in pairs(hook.BlockedArgs) do
            for type in pairs(arg.types) do
                Condition.new(hook, "Block", index, nil, type)
            end
    
            for value in pairs(arg.values) do
                Condition.new(hook, "Block", index, value)
            end
        end
    end
    
    closureList:BindContextMenu(closureListMenu)
    closureList:BindContextMenuSelected(closureListMenuSelected)
    hookLogs:BindContextMenu(hookLogsMenu)
    closureConditions:BindContextMenu(closureConditionMenu)
    closureConditions:BindContextMenuSelected(closureConditionMenuSelected)
    
    
    local Log = {}
    local ArgsLog = {}
    
    function Log.new(hook)
        local log = {}
        local button = Assets.ClosureLog:Clone()
        local buttonName = button:FindFirstChild("Name")
        local buttonInfo = button.Information
        local listButton = ListButton.new(button, closureList)
        local closure = hook.Closure
        local original = closure.Data
    
        local normalAnimation = TweenService:Create(buttonName, constants.fadeLength, { TextColor3 = constants.normalColor })
        local blockAnimation = TweenService:Create(buttonName, constants.fadeLength, { TextColor3 = constants.blockedColor })
        local ignoreAnimation = TweenService:Create(buttonName, constants.fadeLength, { TextColor3 = constants.ignoredColor })
    
        buttonInfo.Protos.Text = #getProtos(original)
        buttonInfo.Upvalues.Text = #getUpvalues(original)
        buttonInfo.Constants.Text = #getConstants(original)
    
        button.Name = closure.Name
        buttonName.Text = closure.Name
    
        local function viewLogs()
            if selected.hookLog then
                hookLogs:Clear()
            end
            
            local nameLength = TextService:GetTextSize(closure.Name, 18, "SourceSans", constants.textWidth).X + 20
            
            selected.hookLog = log
    
            for _i, call in pairs(hook.Logs) do
                ArgsLog.new(log, call)
            end
    
            checkCurrentBlocked()
            checkCurrentIgnored()
    
            LogsClosure.Icon.Image = oh.Constants.Types["function"]
            LogsClosure.Label.Text = closure.Name
            LogsClosure.Label.Size = UDim2.new(0, nameLength, 0, 20)
            LogsClosure.Position = UDim2.new(1, -nameLength, 0, 0)
    
            hookLogs:Recalculate()
        end
    
        listButton:SetCallback(function()
            local oldContext = getContext()
            setContext(7)
    
            if selected.hookLog ~= log then
                if #hook.Logs > 400 then
                    MessageBox.Show("Warning",
                        "This closure seems to have a lot of calls, opening this may cause your game to freeze for a few seconds.\n\nContinue?",
                        MessageType.YesNo,
                        viewLogs)
                else
                    viewLogs()
                end
            end
    
            ClosureList.Visible = false
            ClosureLogs.Visible = true
    
            selected.hookLog = log
    
            setContext(oldContext)
        end)
    
        listButton:SetRightCallback(function()
            local oldContext = getContext()
            setContext(7)
    
            ignoreContext:SetIcon((hook.Ignored and icons.unignore) or icons.ignore)
            ignoreContext:SetText((hook.Ignored and "Unignore Calls") or "Ignore Calls")
            blockContext:SetIcon((hook.Blocked and icons.unblock) or icons.block)
            blockContext:SetText((hook.Blocked and "Unblock Calls") or "Block Calls")
    
            selected.logContext = log
    
            setContext(oldContext)
        end)
    
        listButton:SetSelectedCallback(function()
            if not table.find(selected.logs, log) then
                table.insert(selected.logs, log)
            end
        end)
    
        currentLogs[hook] = log
    
        log.Hook = hook
        log.Button = listButton
        log.BlockAnimation = blockAnimation
        log.IgnoreAnimation = ignoreAnimation
        log.NormalAnimation = normalAnimation
        log.NormalAnimation = normalAnimation
        log.Clear = Log.clear
        log.PlayBlock = Log.playBlock
        log.PlayIgnore = Log.playIgnore
        log.PlayNormal = Log.playNormal
        log.Adjust = Log.adjust
        log.IncrementCalls = Log.incrementCalls
        log.Decrementcalls = Log.decrementCalls
    
        return log
    end
    
    local function createArg(instance, index, value)
        local arg = Assets.Arg:Clone()
        local valueType = type(value)
    
        arg.Icon.Image = oh.Constants.Types[valueType]
        arg.Index.Text = index
        arg.Label.Text = toString(value)
        arg.Label.TextColor3 = oh.Constants.Syntax[valueType]
        arg.Parent = instance.Contents
    
        return arg.AbsoluteSize.Y + 5
    end
    
    function ArgsLog.new(log, call)
        local instance = Assets.CallPod:Clone()
        local args = call.args
    
        if selected.hookLog ~= log then
            instance.Visible = false
        end
    
        local button = ListButton.new(instance, hookLogs)
        local height = 0
    
        if #args == 0 then
            height = height + createArg(instance, 1, nil)
        else
            for i = 1, #args do
                local v = args[i]
                height = height + createArg(instance, i, v)
            end
        end
    
        button:SetRightCallback(function()
            selected.args = call.args
            selected.callingScript = call.script
        end)
    
        button.Instance.Size = button.Instance.Size + UDim2.new(0, 0, 0, height)
    
        return button 
    end
    
    function Log.playIgnore(log)
        log.IgnoreAnimation:Play()
    end
    
    function Log.playBlock(log)
        log.BlockAnimation:Play()
    end
    
    function Log.playNormal(log)
        log.NormalAnimation:Play()
    end
    
    function Log.adjust(log)
        local logInstance = log.Button.Instance
        local logIcon = logInstance.Icon
        local logName = logInstance:FindFirstChild("Name")
    
        local callWidth = TextService:GetTextSize(logInstance.Calls.Text, 18, "SourceSans", constants.textWidth).X + 10
        local labelWidth = callWidth + 21
    
        logInstance.Calls.Size = UDim2.new(0, callWidth, 0, 20)
        logIcon.Position = UDim2.new(0, callWidth, 0.5, -7)
        logName.Position = UDim2.new(0, labelWidth, 0, 0)
        logName.Size = UDim2.new(1, -labelWidth, 1, 0)
    end
    
    function Log.clear(log)
        local logInstance = log.Button.Instance
    
        log.Hook:Clear()
    
        if selected.hookLog == log then
            hookLogs:Clear()
        end
    
        logInstance.Calls.Text = 0
        log:Adjust()
    end
    
    function Log.incrementCalls(log, call)
        local logInstance = log.Button.Instance
        local hook = log.Hook
    
        hook.Calls = hook.Calls + 1
        local calls = hook.Calls
        logInstance.Calls.Text = (calls < 10000 and calls) or "..."
    
        log:Adjust()
        
        if selected.hookLog == log then
            ArgsLog.new(log, call)
            hookLogs:Recalculate()
        end
    end
    
    function Log.decrementCalls(log, args)
        local buttonInstance = log.Button.Instance
        local hook = log.Hook
    
        hook.Calls = Hook.calls - 1
    
        local calls = hook.Calls
    
    
        buttonInstance.Calls.Text = (calls < 10000 and calls) or "..."
        log:Adjust()
    end
    
    function Log.remove(log)
        local hook = log.Hook
    
        log.Button:Remove()
        currentLogs[hook] = nil
        removed[hook] = true
    end
    
    
    ListSearch.FocusLost:Connect(function(returned)
        if returned then
            for hook, log in pairs(currentLogs) do
                local instance = log.Button.Instance
                instance.Visible = not (instance.Visible and not hook.Closure.Name:lower():find(ListSearch.Text))
            end
    
            closureList:Recalculate()
            ListSearch.Text = ""
        end
    end)
    
    ListRefresh.MouseButton1Click:Connect(function()
        closureList:Recalculate()
    end)
    
    LogsBack.MouseButton1Click:Connect(function()
        ClosureLogs.Visible = false
        ClosureList.Visible = true
    end)
    
    LogsButtons.Ignore.MouseButton1Click:Connect(function()
        local selectedLog = selected.hookLog
        local hook = selectedLog.Hook
    
        hook:Ignore()
    
        checkCurrentIgnored()
    
        if hook.Blocked then
            selectedLog:PlayBlock()
        elseif hook.Ignored then
            selectedLog:PlayIgnore()
        else
            selectedLog:PlayNormal()
        end
    end)
    
    LogsButtons.Block.MouseButton1Click:Connect(function()
        local selectedLog = selected.hookLog
        local hook = selectedLog.Hook
    
        hook:Block()
    
        checkCurrentBlocked()
    
        if hook.Blocked then
            selectedLog:PlayBlock()
        elseif hook.Ignored then
            selectedLog:PlayIgnore()
        else
            selectedLog:PlayNormal()
        end
    end)
    
    LogsButtons.Clear.MouseButton1Click:Connect(function()
        selected.hookLog:Clear()
    end)
    
    LogsButtons.Conditions.MouseButton1Click:Connect(function()
        selected.conditionLog = selected.logContext or selected.hookLog
    
        createConditions(selected.conditionLog.Hook)
    end)
    
    ConditionsBack.MouseButton1Click:Connect(function()
        ClosureConditions.Visible = false
    
        if selected.hookLog then
            ClosureLogs.Visible = true
        else
            ClosureList.Visible = true
        end
    end)
    
    ConditionsButtons.New.MouseButton1Click:Connect(function()
        newClosureCondition:Show()
    end)
    
    NewConditionButtons.Add.MouseButton1Click:Connect(function()
        if not conditionStatus.Selected then
            return MessageBox.Show("Error", "Invalid condition status", MessageType.OK)
        end
    
        local status = conditionStatus.Selected.Name
        local type = conditionType.Selected.Name
        local valueType = conditionValueType.Selected.Name
        local value = NewConditionContent.Value.Input.Text
    
        if status ~= "Ignore" and status ~= "Block" then
            MessageBox.Show("Error", "Invalid condition status", MessageType.OK)
        elseif not oh.Constants.Types[type] and not isUserdata(type) then
            MessageBox.Show("Error", "Invalid condition type", MessageType.OK)
        elseif valueType ~= "Value" and valueType ~= "Type" then
            MessageBox.Show("Error", "Invalid condition value association", MessageType.OK)
        elseif valueType == "Value" then
            if type == "string" then
                value = toString(value)
            elseif type == "number" then
                value = tonumber(value)
    
                if not value then
                    return MessageBox.Show("Error", "Your input does not match the type you selected", MessageType.OK)
                end
            elseif type == "boolean" then
                if value == "true" then
                    value = true
                elseif value == "false" then
                    value = false
                else
                    return MessageBox.Show("Error", "Your input does not match the type you selected", MessageType.OK)
                end
            else 
                local success, result = pcall(loadstring("return " .. value))
    
                if valueType == "Value" then
                    if not success then
                        return MessageBox.Show("Error", "There was an error interpreting your input value", MessageType.OK)
                    elseif typeof(result) ~= type then
                        return MessageBox.Show("Error", "Your input does not match the type you selected", MessageType.OK)
                    else
                        value = result
                    end
                end
            end
        else
            value = type
        end
    
        local selectedHook = selected.conditionLog.Hook
        local argIndex = tonumber(NewConditionIndex.Value.Input.Text)
        local byType = valueType == "Type"
    
        if status == "Block" then
            selectedHook:BlockArg(argIndex, value, byType)
        else
            selectedHook:IgnoreArg(argIndex, value, byType)
        end
    
        if byType then
            Condition.new(selectedHook, status, argIndex, nil, value)
        else
            Condition.new(selectedHook, status, argIndex, value)
        end
    
        newClosureCondition:Hide()
    end)
    
    NewConditionButtons.Cancel.MouseButton1Click:Connect(function()
        newClosureCondition:Hide()
    end)
    
    NewConditionIndex.Add.MouseButton1Click:Connect(function()
        local newIndex = tonumber(NewConditionIndex.Value.Input.Text) + 1
        NewConditionIndex.Value.Input.Text = newIndex
    end)
    
    NewConditionIndex.Sub.MouseButton1Click:Connect(function()
        local newIndex = tonumber(NewConditionIndex.Value.Input.Text) - 1
        NewConditionIndex.Value.Input.Text = (newIndex <= 0 and 1) or newIndex
    end)
    
    NewConditionIndex.Value.Input.FocusLost:Connect(function()
        local newIndex = tonumber(NewConditionIndex.Value.Input.Text)
    
        if not newIndex or newIndex <= 0 then
            NewConditionIndex.Value.Input.Text = 1
        end
    end)
    
    
    conditionContext:SetCallback(function()
        selected.conditionLog = selected.logContext or selected.hookLog
    
        createConditions(selected.conditionLog.Hook)
    end)
    
    clearContext:SetCallback(function()
        selected.logContext:Clear()
    end)
    
    ignoreContext:SetCallback(function()
        local selectedLog = selected.logContext
        local hook = selectedLog.Hook
        
        hook:Ignore()
    
        checkCurrentIgnored()
    
        if hook.Blocked then
            selectedLog:PlayBlock()
        elseif hook.Ignored then
            selectedLog:PlayIgnore()
        else
            selectedLog:PlayNormal()
        end
    end)
    
    blockContext:SetCallback(function()
        local selectedLog = selected.logContext
        local hook = selectedLog.Hook
    
        hook:Block()
    
        checkCurrentBlocked()
        
        if hook.Blocked then
            selectedLog:PlayBlock()
        elseif hook.Ignored then
            selectedLog:PlayIgnore()
        else
            selectedLog:PlayNormal()
        end
    end)
    
    removeContext:SetCallback(function()
        selected.logContext:Remove()
    end)
    
    
    ignoreContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            local hook = log.Hook
    
            if not hook.Ignored then
                hook:Ignore()
            end
    
            if log.Blocked then
                log:PlayBlock()
            elseif hook.Ignored then
                log:PlayIgnore()
            end
        end
    
        selected.logs = {}
    end)
    
    unignoreContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            local hook = log.Hook
    
            if hook.Ignored then
                hook:Ignore()
            end
    
            if hook.Blocked then
                log:PlayBlock()
            else
                log:PlayNormal()
            end
        end
    
        selected.logs = {}
    end)
    
    blockContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            local hook = log.Hook
    
            if not hook.Blocked then
                hook:Block()
            end
    
            if hook.Blocked then
                log:PlayBlock()
            elseif hook.Ignored then
                log:PlayIgnore()
            end
        end
    
        selected.logs = {}
    end)
    
    unblockContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            local hook = log.Hook
    
            if hook.Blocked then
                hook:Block()
            end
    
            if hook.Ignored then
                log:PlayIgnore()
            else
                log:PlayNormal()
            end
        end
    
        selected.logs = {}
    end)
    
    clearContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            log:Clear()
        end
    
        selected.logs = {}
    end)
    
    removeContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            log:Remove()
        end
    
        closureList:Recalculate()
        selected.logs = {}
    end)
    
    callingScriptContext:SetCallback(function()
        local oldStatus = oh.getStatus()
    
        oh.setStatus("Copying " .. selected.callingScript.Name .. "'s path")
        setClipboard(getInstancePath(selected.callingScript))
        wait(0.25)
        oh.setStatus(oldStatus)
    end)
    
    removeConditionContext:SetCallback(function()
        selected.condition:Remove()
        selected.condition = nil
    end)
    
    removeConditionContextSelected:SetCallback(function()
        for _i, condition in pairs(selected.conditions) do
            condition:Remove()
        end
    
        selected.conditions = {}
    end)
    
    conditionStatus:SetCallback(function(_dropdown, selected)
        local iconCondition = (selected.Name == "Ignore" and icons.ignore) or icons.block
        local icon = NewConditionContent.Status.Icon 
    
        icon.Image = iconCondition
        icon.Border.Image = iconCondition
    end)
    
    conditionType:SetCallback(function(_dropdown, selected)
        local icon = NewConditionContent.Type.Icon 
        local typeIcons = oh.Constants.Types
        local iconCondition = typeIcons[selected.Name] or typeIcons["userdata"]
        
        icon.Image = iconCondition
        icon.Border.Image = iconCondition
    end)
    
    conditionValueType:SetCallback(function(_dropdown, selected)
        local iconCondition = (selected.Name == "Type" and icons.type) or oh.Constants.Types["integral"]
        local icon = NewConditionContent.ValueType.Icon 
    
        icon.Image = iconCondition
        icon.Border.Image = iconCondition
    end)
    
    Methods.SetEvent(function(hook, call)
        local oldContext = getContext()
        setContext(7)
    
        if not removed[hook] then
            local log = currentLogs[hook] or Log.new(hook)
            log:IncrementCalls(call)
        end
        
        setContext(oldContext)
    end)
    
    return ClosureSpy
end

modules["ui/modules/ConstantScanner"] = function()
    local TextService = game:GetService("TextService")
    
    local ConstantScanner = {}
    local ClosureSpy = import("modules/ClosureSpy")
    local Methods = import("modules/ConstantScanner")
    
    if not hasMethods(Methods.RequiredMethods) then
        return ConstantScanner
    end
    
    local Constant = import("objects/Constant")
    
    local List, ListButton = import("ui/controls/List")
    local MessageBox, MessageType = import("ui/controls/MessageBox")
    local ContextMenu, ContextMenuButton = import("ui/controls/ContextMenu")
    local TabSelector = import("ui/controls/TabSelector")
    
    local Page = import("rbxassetid://11389137937").Base.Body.Pages.ConstantScanner
    local Assets = import("rbxassetid://5042114982").ConstantScanner
    
    local Query = Page.Query
    local Search = Query.Search
    local SearchBox = Query.Query
     
    local constantList = List.new(Page.Results.Clip.Content)
    local constantLogs = {}
    local selectedLog 
    
    local spyClosureContext = ContextMenuButton.new("rbxassetid://4666593447", "Spy Closure")
    local viewConstantsContext = ContextMenuButton.new("rbxassetid://5179169654", "View All Constants")
    local getScriptContext = ContextMenuButton.new("rbxassetid://4891705738", "Get Script Path")
    
    local constants = {
        tempConstantColor = Color3.fromRGB(40, 20, 20),
        tempBorderColor = Color3.fromRGB(20, 0, 0)
    }
    
    constantList:BindContextMenu(ContextMenu.new({ spyClosureContext, viewConstantsContext, getScriptContext }))
    
    local function addConstant(constant, temporary)
        local constantLog = Assets.Constant:Clone()
        local index = constant.Index
        local value = constant.Value
        local valueType = type(value)
        local valueText = toString(value)
    
        if temporary then
            constantLog.ImageColor3 = constants.tempConstantColor
            constantLog.Border.ImageColor3 = constants.tempBorderColor
        end
    
        if valueType == "function" then
            local closureName = getInfo(value).name or ''
            constantLog.Value.Text = (closureName == '' and "Unnamed function") or closureName
        else
            constantLog.Value.Text = toString(value)
        end
    
        constantLog.Name = index
        constantLog.Index.Text = index
        constantLog.Value.TextColor3 = oh.Constants.Syntax[valueType]
        constantLog.Icon.Image = oh.Constants.Types[valueType]
    
    
    
    
    
    
        return constantLog
    end
    
    
    local Log = {}
    
    function Log.new(closure)
        local log = {}
        local button = Assets.ClosureLog:Clone()
        local listButton = ListButton.new(button, constantList) 
        local constants = closure.Constants
        local logHeight = 30
    
        for _i, constant in pairs(constants) do
            local constantLog = addConstant(constant)
            constantLog.Parent = button.Constants
    
            logHeight = logHeight + constantLog.AbsoluteSize.Y + 5
        end
    
        if closure.Name == "Unnamed function" then
            button:FindFirstChild("Name").TextColor3 = Color3.fromRGB(127, 127, 127)
        end
    
        button:FindFirstChild("Name").Text = closure.Name
        button.Size = UDim2.new(1, 0, 0, logHeight)
    
        listButton:SetRightCallback(function()
            selectedLog = log
        end)
    
        constantLogs[closure.Data] = log
    
        log.Closure = closure
        log.Constants = constants
        log.Button = listButton
        return log
    end
    
    
    local function addConstants()
        local query = SearchBox.Text
    
        if query:gsub(' ', '') ~= '' then
            if not tonumber(query) and query:len() <= 1 then
                return
            end
    
            constantList:Clear()
            constantLogs = {}
    
            for _i, closure in pairs(Methods.Scan(query)) do
                Log.new(closure)
            end
    
            constantList:Recalculate()
        else
            MessageBox.Show("Invalid query", "Your query is too short", MessageType.OK)
        end
    
        SearchBox.Text = ''
    end
    
    local SpyHook = ClosureSpy.Hook
    spyClosureContext:SetCallback(function()
        local selectedClosure = selectedLog.Closure
    
        if TabSelector.SelectTab("ClosureSpy") then
            local result = SpyHook.new(selectedClosure)
    
            if result == false then
                MessageBox.Show("Already hooked", "You are already spying " .. selectedClosure.Name)
            elseif result == nil then
                MessageBox.Show("Cannot hook", ('Cannot hook "%s" because there are no upvalues'):format(selectedClosure.Name))
            end
        end
    end)
    
    viewConstantsContext:SetCallback(function()
        if selectedLog then
            local temporaryConstants = selectedLog.TemporaryConstants 
            local instance = selectedLog.Button.Instance
            local newHeight = 0
    
            if temporaryConstants then
                for _i, constantLog in pairs(temporaryConstants) do
                    newHeight = newHeight - (constantLog.AbsoluteSize.Y + 5)
                    constantLog:Destroy()
                end
    
                selectedLog.TemporaryConstants = nil
                selectedLog.Closure.TemporaryConstants = {}
            else
                local closure = selectedLog.Closure
    
                temporaryConstants = {}
    
                for i,v in pairs(getConstants(closure.Data)) do
                    if not closure.Constants[i] then
                        local constant = Constant.new(closure, i, v) 
    
                        local constantLog = addConstant(constant, true)
                        constantLog.Parent = instance.Constants
                        
                        newHeight = newHeight + constantLog.AbsoluteSize.Y + 5
                        temporaryConstants[i] = constantLog
                        closure.TemporaryConstants[i] = constant
                    end
                end
    
                selectedLog.TemporaryConstants = temporaryConstants
            end
    
            newHeight = UDim2.new(0, 0, 0, newHeight)
    
            instance.Constants.Size = instance.Constants.Size + newHeight
            instance.Size = instance.Size + newHeight
    
            constantList:Recalculate()
        end
    end)
    
    getScriptContext:SetCallback(function()
        if selectedLog then
            local script = getfenv(selectedLog.Closure.Data).script
                
            if typeof(script) == "Instance" then
                setClipboard(getInstancePath(script))
            end
        end
    end)
    
    Search.MouseButton1Click:Connect(addConstants)
    SearchBox.FocusLost:Connect(function(returned)
        if returned then
            addConstants()
        end
    end)
    
    return ConstantScanner
end

modules["ui/modules/Explorer"] = function()
    local Explorer = {}
    local Methods = import("modules/Explorer")
    
    if not hasMethods(Methods.RequiredMethods) then
        return Explorer
    end
    
    return Explorerend

modules["ui/modules/ModuleScanner"] = function()
    local ModuleScanner = {}
    local Methods = import("modules/ModuleScanner")
    
    if not hasMethods(Methods.RequiredMethods) then
        return ModuleScanner
    end
    
    local List, ListButton = import("ui/controls/List")
    local MessageBox, MessageType = import("ui/controls/MessageBox")
    local ContextMenu, ContextMenuButton = import("ui/controls/ContextMenu")
    
    local Page = import("rbxassetid://11389137937").Base.Body.Pages.ModuleScanner
    local Assets = import("rbxassetid://5042114982").ModuleScanner
    
    local Query = Page.Query
    local Search = Query.Search
    local Refresh = Query.Refresh
    local Results = Page.Results.Clip.Content
    
    local moduleList = List.new(Results)
    local moduleLogs = {}
    local selectedLog
    
    local pathContext = ContextMenuButton.new("rbxassetid://4891705738", "Get Module Path")
    moduleList:BindContextMenu(ContextMenu.new({ pathContext }))
    
    pathContext:SetCallback(function()
        local selectedInstance = selectedLog.ModuleScript.Instance
    
        setClipboard(getInstancePath(selectedInstance))
        MessageBox.Show("Success", ("%s's path was copied to your clipboard."):format(selectedInstance.Name), MessageType.OK)
    end)
    
    
    
    local Log = {}
    
    function Log.new(moduleScript)
        local log = {}
        local moduleInstance = moduleScript.Instance
        local button = Assets.ModuleLog:Clone()
        local listButton = ListButton.new(button, moduleList)
        
        button.Name = moduleInstance.Name
        button:FindFirstChild("Name").Text = moduleInstance.Name
        button.Protos.Text = #moduleScript.Protos
        button.Constants.Text = #moduleScript.Constants
    
        listButton:SetRightCallback(function()
            selectedLog = log
        end)
    
        moduleLogs[moduleInstance] = log
    
        log.ModuleScript = moduleScript
        log.Button = listButton
        return log
    end
    
    
    
    local function addModules(query)
        moduleList:Clear()
        moduleLogs = {}
    
        for _moduleInstance, moduleScript in pairs(Methods.Scan(query)) do
            Log.new(moduleScript)
        end
    
        moduleList:Recalculate()
    end
    
    Search.FocusLost:Connect(function(returned)
        if returned then
            addModules(Search.Text)
            Search.Text = ""
        end
    end)
    
    Refresh.MouseButton1Click:Connect(function()
        addModules()
    end)
    
    addModules()
    
    return ModuleScannerend

modules["ui/modules/RemoteSpy"] = function()
    local TextService = game:GetService("TextService")
    local TweenService = game:GetService("TweenService")
    
    local RemoteSpy = {}
    local Methods = import("modules/RemoteSpy")
    local ClosureSpy = import("modules/ClosureSpy")
    local Closure = import("objects/Closure")
    
    if not hasMethods(Methods.RequiredMethods) then
        return RemoteSpy
    end
    
    local Prompt = import("ui/controls/Prompt")
    local CheckBox = import("ui/controls/CheckBox")
    local Dropdown = import("ui/controls/Dropdown")
    local List, ListButton = import("ui/controls/List")
    local MessageBox, MessageType = import("ui/controls/MessageBox")
    local ContextMenu, ContextMenuButton = import("ui/controls/ContextMenu")
    local TabSelector = import("ui/controls/TabSelector")
    
    local Base = import("rbxassetid://11389137937").Base
    local Assets = import("rbxassetid://5042114982").RemoteSpy
    
    local Prompts = Base.Prompts
    local Page = Base.Body.Pages.RemoteSpy
    
    local RemoteList = Page.List
    local ListFlags = RemoteList.Flags
    local ListQuery = RemoteList.Query
    local ListSearch = ListQuery.Search
    local ListRefresh = ListQuery.Refresh
    local ListResults = RemoteList.Results.Clip.Content
    
    local RemoteLogs = Page.Logs
    local LogsButtons = RemoteLogs.Buttons
    local LogsRemote = RemoteLogs.RemoteObject
    local LogsBack = RemoteLogs.Back
    local LogsResults = RemoteLogs.Results.Clip.Content
    
    local RemoteConditions = Page.Conditions
    local ConditionsRemote = RemoteConditions.RemoteObject
    local ConditionsButtons = RemoteConditions.Buttons
    local ConditionsResults = RemoteConditions.Results.Clip.Content
    local ConditionsBack = RemoteConditions.Back
    
    local NewRemoteCondition = Prompts.NewRemoteCondition
    local NewConditionInner = NewRemoteCondition.Inner
    local NewConditionButtons = NewConditionInner.Buttons
    local NewConditionContent = NewConditionInner.Content
    local NewConditionIndex = NewConditionContent.Index
    
    local remotesViewing = Methods.RemotesViewing
    local currentRemotes = Methods.CurrentRemotes
    
    local icons = {
        type = "rbxassetid://4702850565",
        status = "rbxassetid://4909102841",
        valueType = "rbxassetid://4702850565",
        block = "rbxassetid://4891641806",
        unblock = "rbxassetid://4891642508",
        ignore = "rbxassetid://4842578510",
        unignore = "rbxassetid://4842578818",
        RemoteEvent = "rbxassetid://4229806545",
        RemoteFunction = "rbxassetid://4229810474",
        BindableEvent = "rbxassetid://4229809371",
        BindableFunction = "rbxassetid://4229807624"
    }
    
    local constants = {
        fadeLength = TweenInfo.new(0.15),
        textWidth = Vector2.new(1337420, 20),
        normalColor = Color3.new(1, 1, 1),
        blockedColor = Color3.fromRGB(170, 0, 0),
        ignoredColor = Color3.fromRGB(100, 100, 100)
    }
    
    local newRemoteCondition = Prompt.new(NewRemoteCondition)
    local conditionStatus = Dropdown.new(NewConditionContent.Status)
    local conditionType = Dropdown.new(NewConditionContent.Type)
    local conditionValueType = Dropdown.new(NewConditionContent.ValueType)
    
    local remoteList = List.new(ListResults, true)
    local remoteLogs = List.new(LogsResults)
    local remoteConditions = List.new(ConditionsResults, true)
    
    local currentLogs = {}
    local removed = {}
    
    local selected = {
        logs = {},
        conditions = {}
    }
    
    local pathContext = ContextMenuButton.new("rbxassetid://4891705738", "Get Remote Path")
    local conditionContext = ContextMenuButton.new("rbxassetid://4891633802", "Call Conditions")
    local clearContext = ContextMenuButton.new("rbxassetid://4892169181", "Clear Calls")
    local ignoreContext = ContextMenuButton.new("rbxassetid://4842578510", "Ignore Calls")
    local blockContext = ContextMenuButton.new("rbxassetid://4891641806", "Block Calls")
    local removeContext = ContextMenuButton.new("rbxassetid://4702831188", "Remove Log")
    
    local scriptContext = ContextMenuButton.new("rbxassetid://4800244808", "Generate Script")
    local callingScriptContext = ContextMenuButton.new("rbxassetid://4800244808", "Get Calling Script")
    local spyClosureContext = ContextMenuButton.new("rbxassetid://4666593447", "Spy Calling Function")
    local repeatCallContext = ContextMenuButton.new("rbxassetid://4907151581", "Repeat Call")
    local viewAsHexContext = ContextMenuButton.new("rbxassetid://9058292613", "Toggle String Hex View")
    
    local removeConditionContext = ContextMenuButton.new("rbxassetid://4702831188", "Remove Condition")
    
    local pathContextSelected = ContextMenuButton.new("rbxassetid://4891705738", "Get Paths")
    local clearContextSelected = ContextMenuButton.new("rbxassetid://4892169181", "Clear Calls")
    local ignoreContextSelected = ContextMenuButton.new("rbxassetid://4842578510", "Ignore Calls")
    local blockContextSelected = ContextMenuButton.new("rbxassetid://4891641806", "Block Calls")
    local unignoreContextSelected = ContextMenuButton.new("rbxassetid://4842578818", "Unignore Calls")
    local unblockContextSelected = ContextMenuButton.new("rbxassetid://4891642508", "Unblock Calls")
    local removeContextSelected = ContextMenuButton.new("rbxassetid://4702831188", "Remove Logs")
    
    local removeConditionContextSelected = ContextMenuButton.new("rbxassetid://4702831188", "Remove Conditions")
    
    local remoteListMenu = ContextMenu.new({ pathContext, conditionContext, clearContext, ignoreContext, blockContext, removeContext })
    local remoteListMenuSelected = ContextMenu.new({ pathContextSelected, clearContextSelected, ignoreContextSelected, unignoreContextSelected, blockContextSelected, unblockContextSelected, removeContextSelected })
    local remoteLogsMenu = ContextMenu.new({ scriptContext, callingScriptContext, spyClosureContext, repeatCallContext, viewAsHexContext })
    local remoteConditionMenu = ContextMenu.new({ removeConditionContext })
    local remoteConditionMenuSelected = ContextMenu.new({ removeConditionContextSelected })
    
    local function checkCurrentIgnored()
        local selectedRemote = (selected.remoteLog or selected.logContext).Remote
    
        LogsButtons.Ignore.Label.Text = (selectedRemote.Ignored and "Unignore") or "Ignore"
        LogsButtons.Ignore.Icon.Image = (selectedRemote.Ignored and icons.unignore) or icons.ignore
    
        local newWidth = TextService:GetTextSize((selectedRemote.Ignored and "Unignore") or "Ignore", 18, "SourceSans", constants.textWidth).X + 30
    
        LogsButtons.Ignore.Size = UDim2.new(0, newWidth, 0, 20)
    end
    
    local function checkCurrentBlocked()
        local selectedRemote = selected.remoteLog.Remote
    
        LogsButtons.Block.Label.Text = (selectedRemote.Blocked and "Unblock") or "Block"
        LogsButtons.Block.Icon.Image = (selectedRemote.Blocked and icons.unblock) or icons.block
    
        local newWidth = TextService:GetTextSize((selectedRemote.Blocked and "Unblock") or "Block", 18, "SourceSans", constants.textWidth).X + 30
    
        LogsButtons.Block.Size = UDim2.new(0, newWidth, 0, 20)
    end
    
    local Condition = {}
    function Condition.new(remote, status, index, value, type)
        local condition = {}
        local instance = Assets.ConditionPod:Clone() 
        local content = instance.Content
        local identifiers = instance.Identifiers
        local button = ListButton.new(instance, remoteConditions)
        local check = CheckBox.new(content.Toggle)
        local valueType = type or typeof(value)
        local typeIcons = oh.Constants.Types
        local branch = (status == "Ignore" and remote.IgnoredArgs[index]) or remote.BlockedArgs[index]
    
        condition.Branch = branch
        condition.Status = status
        condition.Index = index
        condition.Value = value
        condition.Type = type
        condition.Remote = remote
        condition.Enabled = true
        condition.Instance = instance
        condition.Button = button
        condition.Toggle = Condition.toggle
        condition.Remove = Condition.remove
    
        check:SetCallback(function()
            condition:Toggle()
        end)
    
        button:SetRightCallback(function()
            selected.condition = condition
        end)
    
        button:SetSelectedCallback(function()
            if not table.find(selected.conditions, condition) then
                table.insert(selected.conditions, condition)
            end
        end)
        
        if byType then
            instance.Identifiers.ByType.Visible = false
        end 
        
        identifiers.ByType.Visible = type ~= nil
        identifiers.Status.Image = (status == "Ignore" and icons.ignore) or icons.block
        identifiers.Status.Border.Image = identifiers.Status.Image
    
        content.Index.Text = index
        content.Label.Text = (type and valueType) or toString(value)
        content.Label.TextColor3 = oh.Constants.Syntax[valueType] or oh.Constants.Syntax["userdata"]
        content.Type.Image = typeIcons[valueType] or typeIcons["userdata"]
    
        return condition
    end
    
    function Condition.toggle(condition)
        condition.Enabled = not condition.Enabled
    
        local index = condition.Index
        local value = condition.Value
        local remote = condition.Remote
        local ignoredArgs = remote.IgnoredArgs[index]
        local blockedArgs = remote.BlockedArgs[index]
        local argStatus = (condition.Status == "Ignore" and ignoredArgs) or blockedArgs
    
        if value then
            argStatus.values[value] = condition.Enabled or nil
        else
            argStatus.types[condition.Type] = condition.Enabled or nil
        end
    end
    
    function Condition.remove(condition)
        local branch = condition.Branch
        condition.Button:Remove()
    
        if condition.Value then
            branch.values[condition.Value] = nil
        else
            branch.types[condition.Type] = nil
        end
    end
    
    local function createConditions(remote)
        remoteConditions:Clear()
    
        RemoteList.Visible = false
        RemoteLogs.Visible = false
        RemoteConditions.Visible = true
    
        local remoteInstance = remote.Instance
        local remoteInstanceName = remoteInstance.Name
        local remoteClassName = remoteInstance.ClassName
        local nameLength = TextService:GetTextSize(remoteInstanceName, 18, "SourceSans", constants.textWidth).X + 20
    
        ConditionsRemote.Icon.Image = icons[remoteClassName]
        ConditionsRemote.Label.Text = remoteInstanceName
        ConditionsRemote.Label.Size = UDim2.new(0, nameLength, 0, 20)
        ConditionsRemote.Position = UDim2.new(1, -nameLength, 0, 0)
    
        for index, arg in pairs(remote.IgnoredArgs) do
            for type in pairs(arg.types) do
                Condition.new(remote, "Ignore", index, nil, type)
            end
    
            for value in pairs(arg.values) do
                Condition.new(remote, "Ignore", index, value)
            end
        end
    
        for index, arg in pairs(remote.BlockedArgs) do
            for type in pairs(arg.types) do
                Condition.new(remote, "Block", index, nil, type)
            end
    
            for value in pairs(arg.values) do
                Condition.new(remote, "Block", index, value)
            end
        end
    end
    
    remoteList:BindContextMenu(remoteListMenu)
    remoteList:BindContextMenuSelected(remoteListMenuSelected)
    remoteLogs:BindContextMenu(remoteLogsMenu)
    remoteConditions:BindContextMenu(remoteConditionMenu)
    remoteConditions:BindContextMenuSelected(remoteConditionMenuSelected)
    
    
    local Log = {}
    local ArgsLog = {}
    
    function Log.new(remote)
        local log = {}
        local button = Assets.RemoteLog:Clone()
        local remoteInstance = remote.Instance
        local remoteInstanceName = remoteInstance.Name
        local remoteClassName = remoteInstance.ClassName
        local listButton = ListButton.new(button, remoteList)
        
        local normalAnimation = TweenService:Create(button.Label, constants.fadeLength, { TextColor3 = constants.normalColor })
        local blockAnimation = TweenService:Create(button.Label, constants.fadeLength, { TextColor3 = constants.blockedColor })
        local ignoreAnimation = TweenService:Create(button.Label, constants.fadeLength, { TextColor3 = constants.ignoredColor })
    
        button.Name = remoteInstanceName
        button.Label.Text = remoteInstanceName
        button.Icon.Image = icons[remoteClassName]
    
        local function viewLogs()
            if selected.remoteLog then
                remoteLogs:Clear()
            end
            
            local nameLength = TextService:GetTextSize(remoteInstanceName, 18, "SourceSans", constants.textWidth).X + 20
            
            selected.remoteLog = log
    
            for _i, call in pairs(remote.Logs) do
                ArgsLog.new(log, call)
            end
    
            checkCurrentBlocked()
            checkCurrentIgnored()
    
            LogsRemote.Icon.Image = icons[remoteClassName]
            LogsRemote.Label.Text = remoteInstanceName
            LogsRemote.Label.Size = UDim2.new(0, nameLength, 0, 20)
            LogsRemote.Position = UDim2.new(1, -nameLength, 0, 0)
    
            remoteLogs:Recalculate()
        end
    
        listButton:SetCallback(function()
            if selected.remoteLog ~= log then
                if #remote.Logs > 400 then
                    MessageBox.Show("Warning",
                        "This remote seems to have a lot of calls, opening this may cause your game to freeze for a few seconds.\n\nContinue?",
                        MessageType.YesNo,
                        viewLogs)
                else
                    viewLogs()
                end
            end
    
            RemoteList.Visible = false
            RemoteLogs.Visible = true
        end)
    
        listButton:SetRightCallback(function()
            ignoreContext:SetIcon((remote.Ignored and icons.unignore) or icons.ignore)
            ignoreContext:SetText((remote.Ignored and "Unignore Calls") or "Ignore Calls")
            blockContext:SetIcon((remote.Blocked and icons.unblock) or icons.block)
            blockContext:SetText((remote.Blocked and "Unblock Calls") or "Block Calls")
    
            selected.logContext = log
        end)
    
        listButton:SetSelectedCallback(function()
            if not table.find(selected.logs, log) then
                table.insert(selected.logs, log)
            end
        end)
    
        currentLogs[remoteInstance] = log
    
        log.Remote = remote
        log.Button = listButton
        log.BlockAnimation = blockAnimation
        log.IgnoreAnimation = ignoreAnimation
        log.NormalAnimation = normalAnimation
        log.NormalAnimation = normalAnimation
        log.Clear = Log.clear
        log.PlayBlock = Log.playBlock
        log.PlayIgnore = Log.playIgnore
        log.PlayNormal = Log.playNormal
        log.Adjust = Log.adjust
        log.IncrementCalls = Log.incrementCalls
        log.Decrementcalls = Log.decrementCalls
        log.Remove = Log.remove
        return log
    end
    
    local function createArg(instance, index, value)
        local arg = Assets.RemoteArg:Clone()
        local valueType = type(value)
    
        arg.Icon.Image = oh.Constants.Types[valueType]
        arg.Index.Text = index
        
        if valueType == "table" then
            arg.Label.Text = toString(value)
        else
            arg.Label.Text = dataToString(value)
        end
        
        arg.Label.TextColor3 = oh.Constants.Syntax[valueType]
        arg.Name = tostring(index)
        arg.Parent = instance.Contents
    
        return arg.AbsoluteSize.Y + 5
    end
    
    function ArgsLog.new(log, callInfo)
        local instance = Assets.CallPod:Clone()
        local args = callInfo.args
    
        if selected.remoteLog ~= log then
            instance.Visible = false
        end
    
        local button = ListButton.new(instance, remoteLogs)
        local height = 0
    
        if #args == 0 then
            height = height + createArg(instance, 1, nil)
        else
            for i = 1, #args do
                local v = args[i]
                height = height + createArg(instance, i, v)
            end
        end
    
        button:SetRightCallback(function()
            selected.args = callInfo.args
            selected.callingScript = callInfo.script
            selected.func = callInfo.func
            selected.callPodButton = button
        end)
    
        button.Instance.Size = button.Instance.Size + UDim2.new(0, 0, 0, height)
    
        return button 
    end
    
    function Log.playIgnore(log)
        log.IgnoreAnimation:Play()
    end
    
    function Log.playBlock(log)
        log.BlockAnimation:Play()
    end
    
    function Log.playNormal(log)
        log.NormalAnimation:Play()
    end
    
    function Log.adjust(log)
        local remoteClassName = log.Remote.Instance.ClassName
        local logInstance = log.Button.Instance
        local logIcon = logInstance.Icon
    
        local callWidth = TextService:GetTextSize(logInstance.Calls.Text, 18, "SourceSans", constants.textWidth).X + 10
        local iconPosition = callWidth - (((remoteClassName == "RemoteEvent" or remoteClassName == "BindableEvent") and 4) or 0)
        local labelWidth = iconPosition + 21
    
        logInstance.Calls.Size = UDim2.new(0, callWidth, 1, 0)
        logIcon.Position = UDim2.new(0, iconPosition, 0.5, (remoteClassName == "RemoteEvent" and -9) or -7)
        logInstance.Label.Position = UDim2.new(0, labelWidth, 0, 0)
        logInstance.Label.Size = UDim2.new(1, -labelWidth, 1, 0)
    end
    
    function Log.clear(log)
        local logInstance = log.Button.Instance
    
        log.Remote:Clear()
    
        if selected.remoteLog == log then
            remoteLogs:Clear()
        end
    
        logInstance.Calls.Text = 0
        log:Adjust()
    end
    
    function Log.incrementCalls(log, callInfo)
        local buttonInstance = log.Button.Instance
        local remote = log.Remote
        local calls = remote.Calls
    
        buttonInstance.Calls.Text = (calls < 10000 and calls) or "..."
    
        log:Adjust()
        
        if selected.remoteLog == log then
            ArgsLog.new(log, callInfo)
            remoteLogs:Recalculate()
        end
    end
    
    function Log.decrementCalls(log, args)
        local buttonInstance = log.Button.Instance
        local remote = log.Remote
        local calls = remote.Calls
    
        remote:DecrementCalls(args)
        buttonInstance.Calls.Text = (calls < 10000 and calls) or "..."
        log:Adjust()
    end
    
    function Log.remove(log)
        local remoteInstance = log.Remote.Instance
    
        log.Button:Remove()
        currentLogs[remoteInstance] = nil
        removed[remoteInstance] = true
    end
    
    
    
    local function refreshLogs()
        for remoteInstance, log in pairs(currentLogs) do
            log.Button.Instance.Visible = remotesViewing[remoteInstance.ClassName]
        end
    
        remoteList:Recalculate()
    end
    
    for _i,flag in pairs(ListFlags:GetChildren()) do
        if flag:IsA("Frame") then
            local check = CheckBox.new(flag)
    
            check:SetCallback(function(enabled)
                remotesViewing[flag.Name] = enabled
                refreshLogs()
            end)
        end
    end
    
    ListSearch.FocusLost:Connect(function(returned)
        if returned then
            for remoteInstance, log in pairs(currentLogs) do
                local instance = log.Button.Instance
                instance.Visible = not (instance.Visible and not remoteInstance.Name:lower():find(ListSearch.Text))
            end
    
            remoteList:Recalculate()
            ListSearch.Text = ""
        end
    end)
    
    ListRefresh.MouseButton1Click:Connect(function()
        refreshLogs()
    end)
    
    LogsBack.MouseButton1Click:Connect(function()
        RemoteLogs.Visible = false
        RemoteList.Visible = true
    end)
    
    LogsButtons.Ignore.MouseButton1Click:Connect(function()
        local selectedRemote = selected.remoteLog.Remote
    
        selectedRemote:Ignore()
    
        checkCurrentIgnored()
    
        if selectedRemote.Blocked then
            selected.remoteLog:PlayBlock()
        elseif selectedRemote.Ignored then
            selected.remoteLog:PlayIgnore()
        else
            selected.remoteLog:PlayNormal()
        end
    end)
    
    LogsButtons.Block.MouseButton1Click:Connect(function()
        local selectedRemote = selected.remoteLog.Remote
    
        selectedRemote:Block()
    
        checkCurrentBlocked()
    
        if selectedRemote.Blocked then
            selected.remoteLog:PlayBlock()
        elseif selectedRemote.Ignored then
            selected.remoteLog:PlayIgnore()
        else
            selected.remoteLog:PlayNormal()
        end
    end)
    
    LogsButtons.Clear.MouseButton1Click:Connect(function()
        selected.remoteLog:Clear()
    end)
    
    LogsButtons.Conditions.MouseButton1Click:Connect(function()
        selected.conditionLog = selected.logContext or selected.remoteLog
    
        createConditions(selected.conditionLog.Remote)
    end)
    
    ConditionsBack.MouseButton1Click:Connect(function()
        RemoteConditions.Visible = false
    
        if selected.remoteLog then
            RemoteLogs.Visible = true
        else
            RemoteList.Visible = true
        end
    end)
    
    ConditionsButtons.New.MouseButton1Click:Connect(function()
        newRemoteCondition:Show()
    end)
    
    NewConditionButtons.Add.MouseButton1Click:Connect(function()
        if not conditionStatus.Selected then
            return MessageBox.Show("Error", "Invalid condition status", MessageType.OK)
        end
    
        local status = conditionStatus.Selected.Name
        local type = conditionType.Selected.Name
        local valueType = conditionValueType.Selected.Name
        local value = NewConditionContent.Value.Input.Text
    
        if status ~= "Ignore" and status ~= "Block" then
            MessageBox.Show("Error", "Invalid condition status", MessageType.OK)
        elseif not oh.Constants.Types[type] and not isUserdata(type) then
            MessageBox.Show("Error", "Invalid condition type", MessageType.OK)
        elseif valueType ~= "Value" and valueType ~= "Type" then
            MessageBox.Show("Error", "Invalid condition value association", MessageType.OK)
        elseif valueType == "Value" then
            if type == "string" then
                value = toString(value)
            elseif type == "number" then
                value = tonumber(value)
    
                if not value then
                    return MessageBox.Show("Error", "Your input does not match the type you selected", MessageType.OK)
                end
            elseif type == "boolean" then
                if value == "true" then
                    value = true
                elseif value == "false" then
                    value = false
                else
                    return MessageBox.Show("Error", "Your input does not match the type you selected", MessageType.OK)
                end
            else 
                local success, result = pcall(loadstring("return " .. value))
    
                if valueType == "Value" then
                    if not success then
                        return MessageBox.Show("Error", "There was an error interpreting your input value", MessageType.OK)
                    elseif typeof(result) ~= type then
                        return MessageBox.Show("Error", "Your input does not match the type you selected", MessageType.OK)
                    else
                        value = result
                    end
                end
            end
        else
            value = type
        end
    
        local selectedRemote = selected.conditionLog.Remote
        local argIndex = tonumber(NewConditionIndex.Value.Input.Text)
        local byType = valueType == "Type"
    
        if status == "Block" then
            selectedRemote:BlockArg(argIndex, value, byType)
        else
            selectedRemote:IgnoreArg(argIndex, value, byType)
        end
    
        if byType then
            Condition.new(selectedRemote, status, argIndex, nil, value)
        else
            Condition.new(selectedRemote, status, argIndex, value)
        end
    
        newRemoteCondition:Hide()
    end)
    
    NewConditionButtons.Cancel.MouseButton1Click:Connect(function()
        newRemoteCondition:Hide()
    end)
    
    NewConditionIndex.Add.MouseButton1Click:Connect(function()
        local newIndex = tonumber(NewConditionIndex.Value.Input.Text) + 1
        NewConditionIndex.Value.Input.Text = newIndex
    end)
    
    NewConditionIndex.Sub.MouseButton1Click:Connect(function()
        local newIndex = tonumber(NewConditionIndex.Value.Input.Text) - 1
        NewConditionIndex.Value.Input.Text = (newIndex <= 0 and 1) or newIndex
    end)
    
    NewConditionIndex.Value.Input.FocusLost:Connect(function()
        local newIndex = tonumber(NewConditionIndex.Value.Input.Text)
    
        if not newIndex or newIndex <= 0 then
            NewConditionIndex.Value.Input.Text = 1
        end
    end)
    
    pathContext:SetCallback(function()
        local selectedInstance = selected.logContext.Remote.Instance
        local oldStatus = oh.getStatus()
    
        oh.setStatus("Copying " .. selectedInstance.Name .. "'s path")
        setClipboard(getInstancePath(selectedInstance))
        wait(0.25)
        oh.setStatus(oldStatus)
    end)
    
    conditionContext:SetCallback(function()
        selected.conditionLog = selected.logContext or selected.remoteLog
    
        createConditions(selected.conditionLog.Remote)
    end)
    
    clearContext:SetCallback(function()
        selected.logContext:Clear()
    end)
    
    ignoreContext:SetCallback(function()
        local selectedRemote = selected.logContext.Remote
    
        selected.logContext.Remote:Ignore()
    
        checkCurrentIgnored()
    
        if selectedRemote.Blocked then
            selected.logContext:PlayBlock()
        elseif selectedRemote.Ignored then
            selected.logContext:PlayIgnore()
        else
            selected.logContext:PlayNormal()
        end
    end)
    
    blockContext:SetCallback(function()
        local selectedRemote = selected.logContext.Remote
    
        selected.logContext.Remote:Block()
    
        checkCurrentBlocked()
        
        if selectedRemote.Blocked then
            selected.logContext:PlayBlock()
        elseif selectedRemote.Ignored then
            selected.logContext:PlayIgnore()
        else
            selected.logContext:PlayNormal()
        end
    end)
    
    removeContext:SetCallback(function()
        selected.logContext:Remove()
    end)
    
    pathContextSelected:SetCallback(function()
        local paths = ""
    
        for _i, log in pairs(selected.logs) do
            paths = paths .. getInstancePath(log.Remote.Instance) .. '\n'
        end
    
        setClipboard(paths)
        selected.logs = {}
    end)
    
    ignoreContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            local remote = log.Remote
    
            remote:Ignore()
    
            if remote.Blocked then
                log:PlayBlock()
            elseif remote.Ignored then
                log:PlayIgnore()
            end
        end
    
        selected.logs = {}
    end)
    
    unignoreContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            local remote = log.Remote
    
            if remote.Ignored then
                remote:Ignore()
            end
    
            if remote.Blocked then
                log:PlayBlock()
            else
                log:PlayNormal()
            end
        end
    
        selected.logs = {}
    end)
    
    blockContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            local remote = log.Remote
    
            if remote.Blocked then
                remote:Block()
            end
    
            if remote.Blocked then
                log:PlayBlock()
            elseif remote.Ignored then
                log:PlayIgnore()
            end
        end
    
        selected.logs = {}
    end)
    
    unblockContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            local remote = log.Remote
    
            remote:Unblock()
    
            if remote.Ignored then
                log:PlayIgnore()
            else
                log:PlayNormal()
            end
        end
    
        selected.logs = {}
    end)
    
    clearContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            log:Clear()
        end
    
        selected.logs = {}
    end)
    
    removeContextSelected:SetCallback(function()
        for _i, log in pairs(selected.logs) do
            log:Remove()
        end
    
        remoteList:Recalculate()
        selected.logs = {}
    end)
    
    scriptContext:SetCallback(function()
        local script = "-- This script was generated by Hydroxide's RemoteSpy: https://github.com/Upbolt/Hydroxide\n\n"
        local selectedRemote = selected.remoteLog.Remote.Instance
        local remoteClassName = selectedRemote.ClassName
        local remotePath = getInstancePath(selectedRemote)
        local method
    
        if remoteClassName == "RemoteEvent" then
            method = "FireServer"
        elseif remoteClassName == "RemoteFunction" then
            method = "InvokeServer"
        elseif remoteClassName == "BindableEvent" then
            method = "Fire"
        elseif remoteClassName == "BindableFunction" then
            method = "Invoke"
        end
    
        local oldStatus = oh.getStatus()
        oh.setStatus("Generating RemoteSpy Pseudocode ...")
    
        if #selected.args == 0 then
            setClipboard(script .. remotePath .. ':' .. method .. "()")
        else
            local selectedArgs = selected.args
            local args = ""
    
            for i = 1, #selectedArgs do
                local v = selectedArgs[i]
                local valueType = type(v)
                local robloxValueType = typeof(v)
                local variableName = robloxValueType:sub(1, 1):upper() .. robloxValueType:sub(2)
    
                if valueType == "userdata" or valueType == "vector" then
                    v = (typeof(v) == "Instance" and getInstancePath(v)) or userdataValue(v)
                elseif valueType == "table" then
                    v = tableToString(v)
                elseif valueType == "string" then
                    v = dataToString(v)
                else
                    v = toString(v)
                end
    
                script = script .. ("local oh%s%d = %s\n"):format(variableName, i, v) 
                args = args .. ("oh%s%d, "):format(variableName, i)
            end
    
            setClipboard(script .. '\n' .. remotePath .. ':' .. method .. '(' .. args:sub(1, -3) .. ')')
        end
    
        wait(0.25)
        oh.setStatus(oldStatus)
    end)
    
    callingScriptContext:SetCallback(function()
        local oldStatus = oh.getStatus()
    
        oh.setStatus("Copying " .. selected.callingScript.Name .. "'s path")
        setClipboard(getInstancePath(selected.callingScript))
        wait(0.25)
        oh.setStatus(oldStatus)
    end)
    
    local SpyHook = ClosureSpy.Hook
    spyClosureContext:SetCallback(function()
        if TabSelector.SelectTab("ClosureSpy") then
            local selectedClosure = Closure.new(selected.func)
            local result = SpyHook.new(selectedClosure)
    
            if result == false then
                MessageBox.Show("Already hooked", "You are already spying " .. selectedClosure.Name)
            elseif result == nil then
                MessageBox.Show("Cannot hook", ('Cannot hook "%s" because there are no upvalues'):format(selectedClosure.Name))
            end
        end
    end)
    
    repeatCallContext:SetCallback(function()
        local remoteInstance = selected.remoteLog.Remote.Instance
        local remoteClassName = remoteInstance.ClassName
        local method 
    
        if remoteClassName == "RemoteEvent" then
            method = "FireServer"
        elseif remoteClassName == "RemoteFunction" then
            method = "InvokeServer"
        elseif remoteClassName == "BindableEvent" then
            method = "Fire"
        elseif remoteClassName == "BindableFunction" then
            method = "Invoke"
        end
    
        local oldStatus = oh.getStatus()
        oh.setStatus("Recalling " .. remoteInstance.Name)
    
        remoteInstance[method](remoteInstance, unpack(selected.args))
    
        wait(0.25)
    
        oh.setStatus(oldStatus)
    end)
    
    viewAsHexContext:SetCallback(function()
        selected.callPodButton.hexViewEnabled = not selected.callPodButton.hexViewEnabled
        if not selected.callPodButton.oldStrings then
            selected.callPodButton.oldStrings = {}
        end
    
        for idx, arg in pairs(selected.args) do
            if type(arg) == "string" then
                local textObject = selected.callPodButton.Instance.Contents[tostring(idx)].Label
                if selected.callPodButton.hexViewEnabled then
                    selected.callPodButton.oldStrings[idx] = arg
                    local hexString = ""
                    for i = 1, #arg do
                        hexString = hexString .. string.format("%02X ", arg:byte(i, i))
                    end
                    textObject.Text = hexString
                else
                    textObject.Text = dataToString(selected.callPodButton.oldStrings[idx])
                end
            end
        end
    end)
    
    removeConditionContext:SetCallback(function()
        selected.condition:Remove()
        selected.condition = nil
    end)
    
    removeConditionContextSelected:SetCallback(function()
        for _i, condition in pairs(selected.conditions) do
            condition:Remove()
        end
    
        selected.conditions = {}
    end)
    
    conditionStatus:SetCallback(function(_dropdown, selected)
        local iconCondition = (selected.Name == "Ignore" and icons.ignore) or icons.block
        local icon = NewConditionContent.Status.Icon 
    
        icon.Image = iconCondition
        icon.Border.Image = iconCondition
    end)
    
    conditionType:SetCallback(function(_dropdown, selected)
        local icon = NewConditionContent.Type.Icon 
        local typeIcons = oh.Constants.Types
        local iconCondition = typeIcons[selected.Name] or typeIcons["userdata"]
        
        icon.Image = iconCondition
        icon.Border.Image = iconCondition
    end)
    
    conditionValueType:SetCallback(function(_dropdown, selected)
        local iconCondition = (selected.Name == "Type" and icons.type) or oh.Constants.Types["integral"]
        local icon = NewConditionContent.ValueType.Icon 
    
        icon.Image = iconCondition
        icon.Border.Image = iconCondition
    end)
    
    Methods.ConnectEvent(function(remoteInstance, callInfo)
        if not removed[remoteInstance] then
            local remote = currentRemotes[remoteInstance]
            local log = currentLogs[remoteInstance] or Log.new(remote)
    
            log:IncrementCalls(callInfo)
        end
    end)
    
    return RemoteSpy
end

modules["ui/modules/ScriptScanner"] = function()
    local TextService = game:GetService("TextService")
    local TweenService = game:GetService("TweenService")
    
    local ScriptScanner = {}
    local Methods = import("modules/ScriptScanner")
    
    if not hasMethods(Methods.RequiredMethods) then
        return ScriptScanner
    end
    
    local List, ListButton = import("ui/controls/List")
    local MessageBox, MessageType = import("ui/controls/MessageBox")
    local ContextMenu, ContextMenuButton = import("ui/controls/ContextMenu")
    
    local Page = import("rbxassetid://11389137937").Base.Body.Pages.ScriptScanner
    local Assets = import("rbxassetid://5042114982").ScriptScanner
    
    local ScriptList = Page.List
    local ScriptInfo = Page.Info
    
    local ListQuery = ScriptList.Query
    local ListSearch = ListQuery.Search
    local ListRefresh = ListQuery.Refresh
    local ListResults = ScriptList.Results.Clip.Content
    
    local InfoScript = ScriptInfo.ScriptObject
    local InfoBack = ScriptInfo.Back
    local InfoOptions = ScriptInfo.Options.Clip.Content
    local InfoSections = ScriptInfo.Sections
    
    local InfoSource = InfoSections.Source
    local InfoEnvironment = InfoSections.Environment
    local InfoProtos = InfoSections.Protos
    local InfoConstants = InfoSections.Constants
    
    local EnvironmentQuery = InfoEnvironment.Query
    local EnvironmentResultsClip = InfoEnvironment.Results.Clip
    local EnvironmentResultsStatus = EnvironmentResultsClip.ResultStatus
    local EnvironmentResults = EnvironmentResultsClip.Content
    
    local ConstantsQuery = InfoConstants.Query
    local ConstantsResultsClip = InfoConstants.Results.Clip
    local ConstantsResultsStatus = ConstantsResultsClip.ResultStatus
    local ConstantsResults = ConstantsResultsClip.Content
    
    local ProtosQuery = InfoProtos.Query
    local ProtosResultsClip = InfoProtos.Results.Clip
    local ProtosResultsStatus = ProtosResultsClip.ResultStatus
    local ProtosResults = ProtosResultsClip.Content
    
    local scriptList = List.new(ListResults)
    local protosList = List.new(ProtosResults)
    local constantsList = List.new(ConstantsResults)
    
    local scriptLogs = {}
    local selected = {}
    local icons = {
        LocalScript = "rbxassetid://4800244808"
    }
    
    local constants = {
        fadeLength = TweenInfo.new(0.15),
        textWidth = Vector2.new(133742069, 20)
    }
    
    local pathContext = ContextMenuButton.new("rbxassetid://4891705738", "Get Script Path")
    scriptList:BindContextMenu(ContextMenu.new({ pathContext }))
    
    pathContext:SetCallback(function()
        local selectedInstance = selected.logContext.LocalScript.Instance
    
        setClipboard(getInstancePath(selectedInstance))
        MessageBox.Show("Success", ("%s's path was copied to your clipboard."):format(selectedInstance.Name), MessageType.OK)
    end)
    
    local function createProto(index, value)
        local instance = Assets.ProtoPod:Clone()
        local information = instance.Information
        local functionName = getInfo(value).name or ''
        local indexWidth = TextService:GetTextSize(index, 18, "SourceSans", constants.textWidth).X + 8
    
        if functionName == '' then
            functionName = "Unnamed function"
            information.Label.TextColor3 = oh.Constants.Syntax["unnamed_function"]
        end
        
        information.Index.Text = index
        information.Label.Text = functionName
    
        information.Index.Size = UDim2.new(0, indexWidth, 0, 20)
        information.Label.Size = UDim2.new(1, -(indexWidth + 20), 1, 0)
        information.Icon.Position = UDim2.new(0, indexWidth, 0, 2)
        information.Label.Position = UDim2.new(0, indexWidth + 20, 0, 0)
    
        ListButton.new(instance, protosList)
    end
    
    local function createConstant(index, value)
        local instance = Assets.ConstantPod:Clone()
        local information = instance.Information
        local valueType = type(value)
        local indexWidth = TextService:GetTextSize(index, 18, "SourceSans", constants.textWidth).X + 8    
    
        information.Index.Text = index
    
        information.Index.Size = UDim2.new(0, indexWidth, 0, 20)
        information.Label.Size = UDim2.new(1, -(indexWidth + 20), 1, 0)
        information.Icon.Position = UDim2.new(0, indexWidth, 0, 2)
        information.Label.Position = UDim2.new(0, indexWidth + 20, 0, 0)
    
        if valueType == "function" then
            local functionName = getInfo(value).name or ''
    
            if functionName == '' then
                functionName = "Unnamed function"
                information.Label.TextColor3 = oh.Constants.Syntax["unnamed_function"]
            end
            
            information.Label.Text = functionName
        else
            information.Label.Text = toString(value)
        end
        
        ListButton.new(instance, constantsList)
    end
    
    
    local Log = {}
    
    function Log.new(localScript)
        local log = {}
        local scriptInstance = localScript.Instance
        local button = Assets.ScriptLog:Clone()
        local listButton = ListButton.new(button, scriptList)
        local scriptName = scriptInstance.Name
    
        button.Name = scriptName
        button:FindFirstChild("Name").Text = scriptName
        button.Protos.Text = #localScript.Protos
        button.Constants.Text = #localScript.Constants
    
        listButton:SetCallback(function()
            if selected.scriptLog ~= log then
                protosList:Clear()
                constantsList:Clear()
                
                ScriptList.Visible = false
                ScriptInfo.Visible = true
    
                local nameLength = TextService:GetTextSize(scriptName, 18, "SourceSans", constants.textWidth).X + 20
                
                InfoScript.Icon.Image = icons.LocalScript
                InfoScript.Label.Text = scriptName
                InfoScript.Label.Size = UDim2.new(0, nameLength, 0, 20)
                InfoScript.Position = UDim2.new(1, -nameLength, 0, 0)
    
                for i,v in pairs(localScript.Protos) do
                    createProto(i, v)
                end 
    
                for i,v in pairs(localScript.Constants) do
                    createConstant(i, v)
                end
    
    
    
    
    
    
    
                selected.scriptLog = log
            end
        end)
    
        listButton:SetRightCallback(function()
            selected.logContext = log
        end)
    
        scriptLogs[scriptInstance] = log
    
        log.LocalScript = localScript
        log.Button = listButton
        return log
    end
    
    
    
    local function addScripts(query)
        scriptList:Clear()
        scriptLogs = {}
    
        for _instance, localScript in pairs(Methods.Scan(query)) do
            Log.new(localScript)
        end
    
        scriptList:Recalculate()
    end
    
    ListSearch.FocusLost:Connect(function(returned)
        if returned then
            addScripts(ListSearch.Text)
            ListSearch.Text = ""
        end
    end)
    
    ListRefresh.MouseButton1Click:Connect(function()
        addScripts()
    end)
    
    addScripts()
    
    InfoBack.MouseButton1Click:Connect(function()
        ScriptInfo.Visible = false
        ScriptList.Visible = true
    end)
    
    local selectedSection = InfoProtos
    local selectedSectionButton = InfoOptions.Protos
    local animationCache = {}
    
    for _i, sectionButton in pairs(InfoOptions:GetChildren()) do
        if sectionButton:IsA("TextButton") then
            local label = sectionButton.Label
            local enterAnimation = TweenService:Create(label, constants.fadeLength, { TextTransparency = 0 })
            local leaveAnimation = TweenService:Create(label, constants.fadeLength, { TextTransparency = 0.2 })
    
            sectionButton.MouseButton1Click:Connect(function()
                local section = InfoSections:FindFirstChild(sectionButton.Name)
                animationCache[selectedSectionButton].leave:Play()
                
                selectedSection.Visible = false
                section.Visible = true
                
                selectedSection = section
                selectedSectionButton = sectionButton
    
            end)
    
            sectionButton.MouseEnter:Connect(function()
                if selectedSectionButton ~= sectionButton then
                    enterAnimation:Play()
                end
            end)
    
            sectionButton.MouseLeave:Connect(function()
                if selectedSectionButton ~= sectionButton then
                    leaveAnimation:Play()
                end
            end)
    
            animationCache[sectionButton] = {
                enter = enterAnimation,
                leave = leaveAnimation
            }
        end
    end
    
    return ScriptScannerend

modules["ui/modules/UpvalueScanner"] = function()
    local RunService = game:GetService("RunService")
    local TextService = game:GetService("TextService")
    
    local UpvalueScanner = {}
    local ClosureSpy = import("modules/ClosureSpy")
    local Methods = import("modules/UpvalueScanner")
    
    if not hasMethods(Methods.RequiredMethods) then
        return UpvalueScanner
    end
    
    local Upvalue = import("objects/Upvalue")
    
    local Prompt = import("ui/controls/Prompt")
    local CheckBox = import("ui/controls/CheckBox")
    local Dropdown = import("ui/controls/Dropdown")
    local List, ListButton = import("ui/controls/List")
    local TabSelector = import("ui/controls/TabSelector")
    local MessageBox, MessageType = import("ui/controls/MessageBox")
    local ContextMenu, ContextMenuButton = import("ui/controls/ContextMenu")
    
    local Base = import("rbxassetid://11389137937").Base
    local Assets = import("rbxassetid://5042114982").UpvalueScanner
    
    local Prompts = Base.Prompts
    local Page = Base.Body.Pages.UpvalueScanner
    
    local Query = Page.Query
    local Search = Query.Search
    local SearchBox = Query.Query
    local Filters = Page.Filters
    local ResultsClip = Page.Results.Clip
    local ResultStatus = ResultsClip.ResultStatus
    
    local modifyUpvalue = Prompt.new(Prompts.ModifyUpvalue)
    local modifyElement = Prompt.new(Prompts.ModifyElement)
    local deepSearch = CheckBox.new(Filters.SearchInTables)
    local upvalueList = List.new(ResultsClip.Content)
    
    local deepSearchFlag = false
    local currentUpvalues = {}
    
    local selectedLog
    local selectedUpvalue
    local selectedUpvalueLog
    local selectedElement
    
    local spyClosureContext = ContextMenuButton.new("rbxassetid://4666593447", "Spy Closure")
    local viewUpvaluesContext = ContextMenuButton.new("rbxassetid://5179169654", "View All Upvalues")
    local changeUpvalueContext = ContextMenuButton.new("rbxassetid://5458573463", "Change Upvalue")
    local changeTableContext = ContextMenuButton.new("rbxassetid://5458573463", "Change Upvalue")
    local viewElementsContext = ContextMenuButton.new("rbxassetid://5179169654", "View All Elements")
    local changeElementContext = ContextMenuButton.new("rbxassetid://5458573463", "Change Element")
    local upvalueScriptContext = ContextMenuButton.new("rbxassetid://4800244808", "Generate Script")
    local tableScriptContext = ContextMenuButton.new("rbxassetid://4800244808", "Generate Script")
    local elementScriptContext = ContextMenuButton.new("rbxassetid://4800244808", "Generate Script")
    local getScriptContext = ContextMenuButton.new("rbxassetid://4891705738", "Get Script Path")
    
    local closureContextMenu = ContextMenu.new({ spyClosureContext, viewUpvaluesContext, getScriptContext })
    local tableContextMenu = ContextMenu.new({ changeTableContext, viewElementsContext, tableScriptContext })
    local upvalueContextMenu = ContextMenu.new({ changeUpvalueContext, upvalueScriptContext })
    local elementContextMenu = ContextMenu.new({ changeElementContext, elementScriptContext })
    
    local modifyUpvalueInner = modifyUpvalue.Instance.Inner
    local modifyUpvalueContent = modifyUpvalueInner.Content
    local modifyUpvalueButtons = modifyUpvalueInner.Buttons.SetCancel
    local modifyUpvalueType = modifyUpvalueContent.Type
    local modifyUpvalueValue = modifyUpvalueContent.Value.Input
    
    local modifyElementInner = modifyElement.Instance.Inner
    local modifyElementContent = modifyElementInner.Content
    local modifyElementButtons = modifyElementInner.Buttons.SetCancel
    local modifyElementType = modifyElementContent.Type
    local modifyElementValue = modifyElementContent.Value.Input
    
    local upvalueTypeDropdown = Dropdown.new(modifyUpvalueType)
    local elementTypeDropdown = Dropdown.new(modifyElementType)
    
    local constants = {
        tempElementColor = Color3.fromRGB(30, 10, 10),
        tempUpvalueColor = Color3.fromRGB(40, 20, 20),
        tempBorderColor = Color3.fromRGB(20, 0, 0)
    }
    
    local function typeMismatchMessage()
        MessageBox.Show("Error", 
            "Value does not match selected type",
            MessageType.OK)
    end
    
    local function addElement(upvalueLog, upvalue, index, value, temporary)
        local elementLog = Assets.Element:Clone()
        local elementIndexType = type(index)
        local elementValueType = type(value)
        local indexText = toString(index)
    
        if temporary then
            elementLog.ImageColor3 = constants.tempElementColor
            elementLog.Border.ImageColor3 = constants.tempBorderColor
        end
    
        elementLog.Name = indexText
        elementLog.Index.Label.Text = indexText
        elementLog.Value.Label.Text = toString(value)
        elementLog.Index.Label.TextColor3 = oh.Constants.Syntax[elementIndexType]
        elementLog.Index.Icon.Image = oh.Constants.Types[elementIndexType]
        elementLog.Value.Label.TextColor3 = oh.Constants.Syntax[elementValueType]
        elementLog.Value.Icon.Image = oh.Constants.Types[elementValueType]
    
        elementLog.MouseButton2Click:Connect(function()
            selectedUpvalue = upvalue
            selectedUpvalueLog = upvalueLog
            selectedElement = index
            elementTypeDropdown:SetSelected(typeof(value))
            elementContextMenu:Show()
        end)
    
        return elementLog
    end
    
    local function updateElement(upvalueLog, index, value)
        local indexText = toString(index)
        local elementIndexType = type(index)
        local elementValueType = type(value)
        local elementLog = upvalueLog.Elements:FindFirstChild(indexText)
    
        elementLog.Index.Label.Text = indexText
        elementLog.Value.Label.Text = toString(value)
        elementLog.Index.Label.TextColor3 = oh.Constants.Syntax[elementIndexType]
        elementLog.Value.Label.TextColor3 = oh.Constants.Syntax[elementValueType]
        elementLog.Value.Icon.Image = oh.Constants.Types[elementIndexType]
        elementLog.Value.Icon.Image = oh.Constants.Types[elementValueType]
        elementLog.Parent = upvalueLog.Elements
    end
    
    local function addUpvalue(upvalue, temporary)
        local upvalueLog
        local index = upvalue.Index
        local value = upvalue.Value
        local valueType = type(value)
        
        if valueType == "table" then
            upvalueLog = Assets.Table:Clone()
            local height = 25
    
            if temporary then
                upvalueLog.ImageColor3 = constants.tempUpvalueColor
                upvalueLog.Border.ImageColor3 = constants.tempBorderColor
            end
    
            if not temporary then
                for i, v in pairs(upvalue.Scanned) do
                    local elementLog = addElement(upvalueLog, upvalue, i, v)
                    elementLog.Parent = upvalueLog.Elements
                    
                    height = height + elementLog.AbsoluteSize.Y + 5
                end
            end
    
            upvalueLog.Size = UDim2.new(1, 0, 0, height)
        else
            upvalueLog = Assets.Upvalue:Clone()
    
            if temporary then
                upvalueLog.ImageColor3 = constants.tempUpvalueColor
                upvalueLog.Border.ImageColor3 = constants.tempBorderColor
            end
    
            if valueType == "function" then
                local closureName = getInfo(value).name or ''
                upvalueLog.Value.Text = (closureName == '' and "Unnamed function") or closureName
            else
                upvalueLog.Value.Text = toString(value)
            end
        end
        
        upvalueLog.Name = index
        upvalueLog.Index.Text = index
        upvalueLog.Value.TextColor3 = oh.Constants.Syntax[valueType]
        upvalueLog.Icon.Image = oh.Constants.Types[valueType]
    
        upvalueLog.MouseButton2Click:Connect(function()
            selectedUpvalue = upvalue
            selectedUpvalueLog = upvalueLog
            upvalueTypeDropdown:SetSelected(typeof(upvalue.Value))
    
            if upvalue.Scanned then
                tableContextMenu:Show()
            else
                upvalueContextMenu:Show()
            end
        end)
    
        return upvalueLog
    end
    
    local function updateUpvalue(closureLog, upvalue)
        local upvalueLog = closureLog.Instance.Upvalues[tostring(upvalue.Index)]
        local closure = upvalue.Closure
        local index = upvalue.Index
        local newValue = getUpvalue(closure, index)
        local valueType = type(newValue)
    
        if valueType == "function" then
            local closureName = getInfo(newValue).name or ''
            upvalueLog.Value.Text = (closureName == '' and "Unnamed function") or closureName
        elseif valueType == "table" and upvalue.Scanned then
            for i, v in pairs(upvalue.Scanned) do
                updateElement(upvalueLog, i, v)
            end
    
            if upvalue.TemporaryElements then
                local table = upvalue.Value
    
                for idx, _v in pairs(upvalue.TemporaryElements) do
                    updateElement(upvalueLog, idx, table[idx])
                end
            end
        else
            upvalueLog.Value.Text = toString(newValue)
        end
    
        upvalueLog.Value.TextColor3 = oh.Constants.Syntax[valueType]
        upvalueLog.Icon.Image = oh.Constants.Types[valueType]
    
        upvalue:Update(newValue)
    end
    
    
    local Log = {}
    
    function Log.new(closure)
        local log = {}
        local instance = Assets.ClosureLog:Clone()
        local listButton = ListButton.new(instance, upvalueList)
        local logHeight = 30
    
        log.Instance = instance
        log.Closure = closure
        log.Upvalues = {}
        log.Update = Log.update
    
        for i, upvalue in pairs(closure.Upvalues) do
            local upvalueLog = addUpvalue(upvalue)
            upvalueLog.Parent = instance.Upvalues
    
            logHeight = logHeight + upvalueLog.AbsoluteSize.Y + 5
            log.Upvalues[i] = upvalueLog
        end
    
        instance.Size = UDim2.new(1, 0, 0, logHeight)
        instance:FindFirstChild("Name").Text = closure.Name
        
        listButton:SetRightCallback(function()
            selectedLog = log
        end)
        
        currentUpvalues[closure.Data] = log
    
        upvalueList:Recalculate()
        return log
    end
    
    function Log.update(log)
        for _i, upvalue in pairs(log.Closure.Upvalues) do
            updateUpvalue(log, upvalue)
        end
        
        for _i, upvalue in pairs(log.Closure.TemporaryUpvalues) do
            updateUpvalue(log, upvalue)
        end
    end
    
    local function addUpvalues()
        local query = SearchBox.Text
    
        if query:gsub(' ', '') ~= '' then
            if not tonumber(query) and query:len() <= 1 then
                return
            end
    
            local unnamedFunctions = {}
            local showResultLabel = false
    
            upvalueList:Clear()
            currentUpvalues = {}
    
            for _i, closure in pairs(Methods.Scan(query, deepSearchFlag)) do
                if closure.Name == '' then
                    unnamedFunctions[closure.Data] = closure
                else
                    Log.new(closure)
                end
    
                showResultLabel = true
            end
    
            for _i, closure in pairs(unnamedFunctions) do
                Log.new(closure)
            end
    
            ResultStatus.Visible = showResultLabel
    
            upvalueList:Recalculate()
        else
            MessageBox.Show("Invalid query", "Your query is too short", MessageType.OK)
        end
    
        SearchBox.Text = ""
    end
    
    upvalueList:BindContextMenu(closureContextMenu)
    
    deepSearch:SetCallback(function(enabled)
        deepSearchFlag = enabled
        
        if enabled then
            MessageBox.Show("Notice", "Deep searching may result in longer scan times!", MessageType.OK)
        end
    end)
    
    Search.MouseButton1Click:Connect(addUpvalues)
    SearchBox.FocusLost:Connect(function(returned)
        if returned then
            addUpvalues()
        end
    end)
    
    local function setValue(valueText, value, dropdown)
        local raw = valueText
        local valueType = typeof(value)
        local newValue
    
        if valueType == "string" then
            newValue = raw
        elseif valueType == "number" then
            local convert = tonumber(raw)
    
            if convert then
                newValue = convert
            else
                typeMismatchMessage()
            end
        elseif valueType == "boolean" then
            if raw == "true" then
                newValue = true
            elseif raw == "false" then
                newValue = false
            else
                typeMismatchMessage()
            end
        else
            local success, result = pcall(loadstring("return " .. raw))
            
            if success then
                if typeof(result) == dropdown.Selected.Name then
                    newValue = result
                else
                    typeMismatchMessage()
                end
            else
                MessageBox.Show("Error",
                    "There is an error in your input",
                    MessageType.OK)
            end
        end
    
        return newValue
    end
    
    local function typeDropdownAdjust(dropdown, button)
        local instance = dropdown.Instance
        local icon = oh.Constants.Types[button.Name] or oh.Constants.Types["userdata"]
    
        instance.Icon.Image = icon
    end
    
    modifyUpvalueButtons.Set.MouseButton1Click:Connect(function()
        local newValue = setValue(
            modifyUpvalueValue.Text, 
            selectedUpvalue.Value, 
            upvalueTypeDropdown)
    
        if newValue ~= nil then
            selectedUpvalue:Set(newValue)
    
            modifyUpvalueValue.Text = ""
            modifyUpvalue:Hide()
        end
    end)
    
    modifyUpvalueButtons.Cancel.MouseButton1Click:Connect(function()
        modifyUpvalueValue.Text = ""
        modifyUpvalue:Hide()
    end)
    
    modifyElementButtons.Set.MouseButton1Click:Connect(function()
        local upvalueValue = selectedUpvalue.Value
        
        local newValue = setValue(
            modifyElementValue.Text, 
            upvalueValue[selectedElement], 
            elementTypeDropdown)
    
        if newValue ~= nil then
            upvalueValue[selectedElement] = newValue
    
            modifyElementValue.Text = ""
            modifyElement:Hide()
        end
    end)
    
    modifyElementButtons.Cancel.MouseButton1Click:Connect(function()
        modifyElementValue.Text = ""
        modifyElement:Hide()
    end)
    
    upvalueTypeDropdown:SetCallback(typeDropdownAdjust)
    elementTypeDropdown:SetCallback(typeDropdownAdjust)
    
    local function generateScriptFormat(elementIndex)
        local generatedScript = [[-- Generated by Hydroxide's Upvalue Scanner: https://github.com/Upbolt/Hydroxide
    
    local aux = ohaux
    
    local scriptPath = %s
    local closureName = "%s"
    local upvalueIndex = %d
    local closureConstants = %s
    
    local closure = aux.searchClosure(scriptPath, closureName, upvalueIndex, closureConstants)
    local value = YOUR_NEW_VALUE_HERE
    ]]
    
        if elementIndex and elementIndex ~= "nil" then
            generatedScript = generatedScript .. ("local elementIndex = %s\n"):format(elementIndex)
            generatedScript = generatedScript .. "\n\n-- DO NOT RELY ON THIS FEATURE TO PRODUCE %s FUNCTIONAL SCRIPTS\n"
            return generatedScript .. "debug.getupvalue(closure, upvalueIndex)[elementIndex] = value"
        end
        
        return generatedScript .. "\n\n-- DO NOT RELY ON THIS FEATURE TO PRODUCE %s FUNCTIONAL SCRIPTS\ndebug.setupvalue(closure, upvalueIndex, value)"
    end
    
    local function generateScript(elementIndex) 
        local index = selectedUpvalue.Index
        local closure = selectedUpvalue.Closure
        local closureData = closure.Data
        local closureScript = rawget(getfenv(closureData), "script")
    
        local generatedScript = generateScriptFormat(dataToString(elementIndex))
    
        local currentConstants = {}
        local currentIndex = 0
    
        if closureScript and not closureScript.Parent then
            closureScript = nil
        end
    
        for idx, constant in pairs(getConstants(closureData)) do
            if currentIndex > 5 then 
                break 
            elseif type(constant) ~= "function" then
                currentConstants[idx] = constant
                currentIndex = currentIndex + 1
            end
        end
    
        setClipboard(
            generatedScript:format(
                (closureScript and getInstancePath(closureScript)) or "nil", 
                closure.Name, 
                index,
                tableToString(currentConstants),
                "100%"
            )
        )
    end
    
    upvalueScriptContext:SetCallback(function()
        generateScript()
    end)
    
    tableScriptContext:SetCallback(function()
        generateScript()
    end)
    
    elementScriptContext:SetCallback(function()
        generateScript(selectedElement)
    end)
    
    local SpyHook = ClosureSpy.Hook
    spyClosureContext:SetCallback(function()
        local closure = selectedLog.Closure
    
        if TabSelector.SelectTab("ClosureSpy") then
            local result = SpyHook.new(closure)
    
            if result == false then
                MessageBox.Show("Already hooked", "You are already spying " .. closure.Name)
            elseif result == nil then
                MessageBox.Show("Cannot hook", ('Cannot hook "%s" because there are no upvalues'):format(closure.Name))
            end
        end
    end)
    
    viewUpvaluesContext:SetCallback(function()
        if selectedLog then
            local temporaryUpvalues = selectedLog.TemporaryUpvalues 
            local instance = selectedLog.Instance
            local newHeight = 0
    
            if temporaryUpvalues then
                for _i, upvalueLog in pairs(temporaryUpvalues) do
                    newHeight = newHeight - (upvalueLog.AbsoluteSize.Y + 5)
                    upvalueLog:Destroy()
                end
    
                selectedLog.TemporaryUpvalues = nil
                selectedLog.Closure.TemporaryUpvalues = {}
            else
                local closure = selectedLog.Closure
                
                temporaryUpvalues = {}
    
                for i,v in pairs(getUpvalues(closure)) do
                    if not closure.Upvalues[i] then
                        local upvalue = Upvalue.new(closure, i, v)
                        
                        if type(v) == "table" then
                            upvalue.Scanned = {}
                        end
                        
                        local upvalueLog = addUpvalue(upvalue, true)
                        upvalueLog.Parent = instance.Upvalues
                        
                        newHeight = newHeight + upvalueLog.AbsoluteSize.Y + 5
                        temporaryUpvalues[i] = upvalueLog
                        closure.TemporaryUpvalues[i] = upvalue
                    end
                end
    
                selectedLog.TemporaryUpvalues = temporaryUpvalues
            end
    
            newHeight = UDim2.new(0, 0, 0, newHeight)
    
            instance.Upvalues.Size = instance.Upvalues.Size + newHeight
            instance.Size = instance.Size + newHeight
    
            upvalueList:Recalculate()
        end
    end)
    
    getScriptContext:SetCallback(function()
        if selectedLog then
            local script = getfenv(selectedLog.Closure.Data).script
                
            if typeof(script) == "Instance" then
                setClipboard(getInstancePath(script))
            end
        end
    end)
    
    viewElementsContext:SetCallback(function()
        local temporaryElements = selectedUpvalue and selectedUpvalue.TemporaryElements
        local newHeight = 0
    
        if temporaryElements then
            for index, _v in pairs(temporaryElements) do
                local elementLog = selectedUpvalueLog.Elements[toString(index)]
                newHeight = newHeight - (elementLog.AbsoluteSize.Y + 5)
    
                elementLog:Destroy()
            end
    
            selectedUpvalue.TemporaryElements = nil
        else
            local scanned = selectedUpvalue.Scanned
            temporaryElements = {}
    
            for i,v in pairs(selectedUpvalue.Value) do
                if not scanned[i] then
                    local elementLog = addElement(selectedUpvalueLog, selectedUpvalue, i, v, true)
                    elementLog.Parent = selectedUpvalueLog.Elements
    
                    newHeight = newHeight + elementLog.AbsoluteSize.Y + 5
                    temporaryElements[i] = elementLog
                end
            end 
    
            selectedUpvalue.TemporaryElements = temporaryElements
        end
    
        newHeight = UDim2.new(0, 0, 0, newHeight)
    
        selectedUpvalueLog.Size = selectedUpvalueLog.Size + newHeight
        selectedUpvalueLog.Parent.Parent.Size = selectedUpvalueLog.Parent.Parent.Size + newHeight
        upvalueList:Recalculate()
    end)
    
    local function changeUpvalue()
        if selectedUpvalue then
            local index = selectedUpvalue.Index
            local indexFrame = modifyUpvalueContent.Index
            local indexNumber = indexFrame.Number
            local indexWidth = TextService:GetTextSize(tostring(index), 18, "SourceSans", indexFrame.AbsoluteSize).X
            
            indexNumber.Text = index
            indexNumber.Size = UDim2.new(0, indexWidth, 0, 25)
            
            modifyUpvalue:Show()
        end
    end
    
    changeUpvalueContext:SetCallback(changeUpvalue)
    changeTableContext:SetCallback(changeUpvalue)
    
    changeElementContext:SetCallback(function()
        if selectedUpvalue and selectedElement then
            local index = selectedElement
            local indexType = type(index)
            local indexFrame = modifyElementContent.Index
            local indexLabel = indexFrame.Data
            local indexWidth = TextService:GetTextSize(index, 18, "SourceSans", indexFrame.AbsoluteSize).X
            
            indexLabel.Text = index
            indexLabel.TextColor3 = oh.Constants.Syntax[indexType]
            indexLabel.Size = UDim2.new(0, indexWidth, 0, 25)
            
            modifyElement:Show()
        end
    end)
    
    oh.Events.UpdateUpvalues = RunService.Heartbeat:Connect(function()
        for _i, closureLog in pairs(currentUpvalues) do
            closureLog:Update()
        end
    end)
    
    return UpvalueScanner 
end

return modules["init"]()
