-- ============================================================================
-- QUIETSHUFFLE ADDON - Slash Commands
-- ============================================================================

local _, addon = ...

SlashCmdList["QUIETSHUFFLE"] = function(msg)
    local command, arg = msg:match("^(%S+)%s*(.*)")

    -- Allow enable/disable commands even when addon is disabled
    if command == "enable" then
        if addon.SetEnabled then
            addon.SetEnabled(true)
            addon.Print("|cFF00FF00QuietShuffle enabled|r")
        end
        return
    end

    if command == "disable" then
        if addon.SetEnabled then
            addon.SetEnabled(false)
            addon.Print("|cFFFF0000QuietShuffle disabled|r")
        end
        return
    end

    if addon.IsEnabled and not addon.IsEnabled() then
        addon.Print("|cFFFF0000QuietShuffle disabled|r")
        addon.Print("Use |cFFFFD700/qs enable|r to enable the addon, or check the box in the Settings panel.")
        return
    end

    if not command or command == "" then
        -- Show enabled/disabled status
        local enabled = addon.IsEnabled and addon.IsEnabled()
        if enabled then
            addon.Print("|cFF00FF00QuietShuffle enabled|r")
        else
            addon.Print("|cFFFF0000QuietShuffle disabled|r")
        end
        addon.Print("List of available commands")
        addon.Print("/qs enable - Enable the addon")
        addon.Print("/qs disable - Disable the addon")
        addon.Print("/qs settings - Open settings panel")
        addon.Print("/qs history - Show message history window")
        return
    end

    if command == "settings" then
        if addon.OpenSettings then
            addon.OpenSettings()
        end
        return
    end

    if command == "history" then
        if addon.ShowHistoryWindow then
            addon.ShowHistoryWindow()
        end
        return
    end

    -- Debug command (hidden from help)
    if command == "debug" then
        if arg == "on" or arg == "off" then
            addon.debugFilters = (arg == "on")
        end
        addon.Print("Debug " .. (addon.debugFilters and "enabled" or "disabled") .. ".")
        return
    end

    if command == "players" then
        addon.Print("Match players tracked:")
        if addon.matchPlayers then
            local count = 0
            for name, _ in pairs(addon.matchPlayers) do
                addon.Print("  - " .. name)
                count = count + 1
            end
            if count == 0 then
                addon.Print("  (none)")
            end
        else
            addon.Print("  (table not initialized)")
        end
        return
    end

    addon.Print("Unknown command.")
    -- Show enabled/disabled status
    local enabled = addon.IsEnabled and addon.IsEnabled()
    if enabled then
        addon.Print("|cFF00FF00QuietShuffle enabled|r")
    else
        addon.Print("|cFFFF0000QuietShuffle disabled|r")
    end
    addon.Print("List of available commands")
    addon.Print("/qs enable - Enable the addon")
    addon.Print("/qs disable - Disable the addon")
    addon.Print("/qs history - Show message history window")
end
