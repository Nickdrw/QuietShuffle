-- ============================================================================
-- QUIETSHUFFLE ADDON - Slash Commands
-- ============================================================================

local _, addon = ...

SLASH_QUIETSHUFFLE1 = "/qs"
SLASH_QUIETSHUFFLE2 = "/quietshuffle"

SlashCmdList["QUIETSHUFFLE"] = function(msg)
    local command, arg = msg:match("^(%S+)%s*(.*)")

    if addon.IsEnabled and not addon.IsEnabled() then
        addon.Print("Disabled")
        return
    end

    if not command or command == "" then
        if addon.CheckSoloShuffleStatus then
            addon.CheckSoloShuffleStatus()
        end
        local inSoloShuffleMatch = addon.IsSoloShuffleMatch and addon.IsSoloShuffleMatch() or false
        if inSoloShuffleMatch then
            addon.Print("Currently IN Solo Shuffle (muting active)")
        else
            addon.Print("NOT in Solo Shuffle")
        end
        if addon.PrintStoredMessages then
            addon.PrintStoredMessages()
        end
        return
    end

    if command == "test" and arg == "start" then
        addon.isTestMode = true
        if addon.CheckSoloShuffleStatus then
            addon.CheckSoloShuffleStatus()
        end
        return
    end



    if command == "test" and arg == "stop" then
        if not addon.inSoloShuffle then
            addon.Print("Solo Shuffle was not started. Use '/qs test start' first.")
            return
        end

        addon.isTestMode = false
        if addon.CheckSoloShuffleStatus then
            addon.CheckSoloShuffleStatus()
        end
        return
    end

    if command == "clear" then
        addon.messages = {}
        addon.Print("Stored messages cleared.")
        return
    end

    if command == "history" then
        if addon.ShowHistoryWindow then
            addon.ShowHistoryWindow()
        end
        return
    end

    if command == "debug" and (arg == "on" or arg == "off") then
        addon.debugFilters = (arg == "on")
        addon.Print("Debug " .. (addon.debugFilters and "enabled" or "disabled") .. ".")
        return
    end

    addon.Print("Unknown command.")
    addon.Print("/qs - Show status")
    addon.Print("/qs history - Show message history window")
    addon.Print("/qs test start - Simulate Solo Shuffle start")
    addon.Print("/qs test stop - Simulate Solo Shuffle end")
    addon.Print("/qs clear - Clear current messages")
    addon.Print("/qs debug on|off - Toggle filter debug")
end
