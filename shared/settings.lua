local WindUI = undeitedhub.WindUI
local config = undeitedhub.Config

local SettingsTab = undeitedhub.Window:Tab({ Title = "Settings" })

local themes = config.themes or { "Default", "Midnight", "Ocean", "Sunset", "Emerald", "Rose", "Plasma", "Snow", "Neon", "Crimson", "Lavender", "Gold", "Mint", "Cyber" }

local currentTheme = undeitedhub.CurrentTheme or "Default"

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
    undeitedhub.CurrentTheme = themeName
    pcall(function()
        WindUI:SetTheme(themeName)
    end)
    if undeitedhub.SaveSettings then
        pcall(undeitedhub.SaveSettings)
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

undeitedhub.ApplyTheme = ApplyTheme