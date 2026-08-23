local WindUI = bandithub.WindUI
local config = bandithub.Config

local SettingsTab = bandithub.Window:Tab({ Title = "Settings" })

local themes = config.themes or { "Default", "Midnight", "Ocean", "Sunset", "Emerald", "Rose", "Plasma", "Snow", "Neon", "Crimson", "Lavender", "Gold", "Mint", "Cyber" }

local currentTheme = bandithub.CurrentTheme or "Default"

local function ApplyTheme(themeName)
    if not themeName or themeName == "" then
        themeName = "Default"
    end
    local found = false
    for _, name in ipairs(themes) do
        if name == themeName then
            found = true
            break
        end
    end
    if not found then
        themeName = "Default"
    end
    currentTheme = themeName
    bandithub.CurrentTheme = themeName
    pcall(function()
        WindUI:SetTheme(themeName)
    end)
    if bandithub.SaveSettings then
        pcall(bandithub.SaveSettings)
    end
end

SettingsTab:Dropdown({
    Title = "Theme",
    Values = themes,
    Value = currentTheme,
    Callback = function(value)
        ApplyTheme(value)
    end
})

bandithub.ApplyTheme = ApplyTheme