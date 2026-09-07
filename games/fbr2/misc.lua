local WindUI = undeitedhub.WindUI
local MiscTab = undeitedhub.Window:Tab({ Title = "Misc" })

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