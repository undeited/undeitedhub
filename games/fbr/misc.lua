local WindUI = bandithub.WindUI
local MiscTab = bandithub.Window:Tab({ Title = "Misc" })

MiscTab:Button({
    Title = "Unlock Console",
    Callback = function()
        local Players = game:GetService("Players")
        local StarterPlayer = game:GetService("StarterPlayer")
        local player = Players.LocalPlayer

        if not player then
            WindUI:Notify({ Title = "Error", Content = "Local player not found", Duration = 2 })
            return
        end

        local removed = false

        local playerScripts = player:FindFirstChild("PlayerScripts")
        if playerScripts then
            local block = playerScripts:FindFirstChild("BlockConsole")
            if block then
                block:Destroy()
                removed = true
            end
        end

        local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
        if starterScripts then
            local block = starterScripts:FindFirstChild("BlockConsole")
            if block then
                block:Destroy()
                removed = true
            end
        end

        if removed then
            WindUI:Notify({ Title = "Unlock Console", Content = "Console unlocked!", Duration = 2 })
        else
            WindUI:Notify({ Title = "Unlock Console", Content = "BlockConsole script not found", Duration = 2 })
        end
    end
})

local GroupService = game:GetService("GroupService")
local GROUP_ID = 10625014
local TARGET_RANK_NAMES = {
    "[🔒] Moderator",
    "[ + ] Admin",
    "[🛠️] Developer",
    "[💎] Co-Owner",
    "[👑] Owner"
}

local function CheckPlayer(player)
    if not player then return end
    task.spawn(function()
        local success, role = pcall(function()
            return GroupService:GetRoleInGroupAsync(GROUP_ID, player.UserId)
        end)
        if success and role and role.Name then
            for _, rankName in ipairs(TARGET_RANK_NAMES) do
                if role.Name == rankName then
                    WindUI:Notify({
                        Title = "Staff Joined",
                        Content = string.format("%s (%s) joined the game!", player.Name, rankName),
                        Duration = 5,
                        Icon = "shield"
                    })
                    break
                end
            end
        end
    end)
end

for _, player in ipairs(game.Players:GetPlayers()) do
    CheckPlayer(player)
end

game.Players.PlayerAdded:Connect(CheckPlayer)

if _G.AudioLoggerAlreadyLoaded then return end
_G.AudioLoggerAlreadyLoaded = true

local DISTROKID_USER_ID = 7135127272
local FOLDER_NAME = "audio"
local PUBLIC_FILE = FOLDER_NAME .. "/public.txt"
local PRIVATE_FILE = FOLDER_NAME .. "/private.txt"

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

pcall(function()
    if not isfolder(FOLDER_NAME) then
        makefolder(FOLDER_NAME)
    end
end)

local logEntries = {}
local loggedIds = {}
local assetCategoryCache = {}

local function loadLogs()
    logEntries = {}
    loggedIds = {}

    local function readFileAndAdd(filePath, category)
        pcall(function()
            if isfile(filePath) then
                local content = readfile(filePath)
                for line in content:gmatch("[^\n]+") do
                    local id = line:match("^(%d+)")
                    if not id then continue end
                    local pitch = line:match("%(pitch (%d+%.?%d*)%)")
                    local tpos = line:match("%(tpos (%d+%.?%d*)%)")
                    if pitch and tpos then
                        pitch = tonumber(pitch)
                        tpos = tonumber(tpos)
                        if not loggedIds[id] then
                            loggedIds[id] = true
                            table.insert(logEntries, {
                                id = id,
                                pitch = pitch,
                                tpos = tpos,
                                category = category
                            })
                        end
                    end
                end
            end
        end)
    end

    readFileAndAdd(PUBLIC_FILE, "public")
    readFileAndAdd(PRIVATE_FILE, "private")
end
loadLogs()

local function fetchAssetCategory(assetId)
    if assetCategoryCache[assetId] then
        return assetCategoryCache[assetId]
    end

    local success, info = pcall(function()
        return MarketplaceService:GetProductInfoAsync(tonumber(assetId))
    end)

    if success and info and info.AssetTypeId == 3 then
        local creatorName = info.Creator and info.Creator.Name or ""
        if creatorName == "DistrokidOfficial" then
            assetCategoryCache[assetId] = "public"
            return "public"
        else
            assetCategoryCache[assetId] = "private"
            return "private"
        end
    else
        assetCategoryCache[assetId] = nil
        return nil
    end
end

local function updateFiles()
    local publicLines = {}
    local privateLines = {}

    for _, entry in ipairs(logEntries) do
        local line = string.format("%s (pitch %.2f) (tpos %.2f)", entry.id, entry.pitch, entry.tpos)
        if entry.category == "public" then
            table.insert(publicLines, line)
        else
            table.insert(privateLines, line)
        end
    end

    pcall(function()
        writefile(PUBLIC_FILE, table.concat(publicLines, "\n"))
        writefile(PRIVATE_FILE, table.concat(privateLines, "\n"))
    end)
end

local function addLog(playerName, pitch, timePos, soundId)
    local numericId = soundId and string.gsub(soundId, "^rbxassetid://", "") or ""
    if numericId == "" then return end
    numericId = numericId:gsub("^%s+", ""):gsub("%s+$", "")
    if loggedIds[numericId] then return end

    local category = fetchAssetCategory(numericId)
    if not category then return end

    loggedIds[numericId] = true
    table.insert(logEntries, {
        id = numericId,
        pitch = pitch,
        tpos = timePos,
        category = category
    })

    updateFiles()
end

local loggers = {}

local function setupPlayer(playerName)
    if playerName == LocalPlayer.Name then return end

    local model = Workspace:FindFirstChild(playerName)
    if not model then return end
    local part = model:FindFirstChild("BoomboxSoundPart")
    if not part then return end
    local sound = part:FindFirstChild("BoomBoxSound")
    if not sound or not sound:IsA("Sound") then return end

    local existing = loggers[playerName]
    if existing and existing.sound == sound then return end
    if existing and existing.connection then
        existing.connection:Disconnect()
    end

    local connection = sound:GetPropertyChangedSignal("IsPlaying"):Connect(function()
        if sound.IsPlaying then
            addLog(playerName, sound.PlaybackSpeed, sound.TimePosition, sound.SoundId or "")
        end
    end)

    loggers[playerName] = { sound = sound, connection = connection }

    if sound.IsPlaying then
        addLog(playerName, sound.PlaybackSpeed, sound.TimePosition, sound.SoundId or "")
    end
end

local function scanAllPlayers()
    if not _G.BANDITHUB_WINDOW_VISIBLE then return end
    for _, player in ipairs(Players:GetPlayers()) do
        setupPlayer(player.Name)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        wait(0.5)
        if _G.BANDITHUB_WINDOW_VISIBLE then setupPlayer(player.Name) end
    end)
    if Workspace:FindFirstChild(player.Name) and _G.BANDITHUB_WINDOW_VISIBLE then
        setupPlayer(player.Name)
    end
end)

Workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") and Players:FindFirstChild(child.Name) and _G.BANDITHUB_WINDOW_VISIBLE then
        wait(0.5)
        setupPlayer(child.Name)
    end
end)

spawn(function()
    while wait(3) do
        scanAllPlayers()
    end
end)

scanAllPlayers()