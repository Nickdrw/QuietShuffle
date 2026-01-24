-- ============================================================================
-- QUIETSHUFFLE ADDON - Slash Commands
-- ============================================================================

local _, addon = ...

SLASH_QUIETSHUFFLE1 = "/qs"
SLASH_QUIETSHUFFLE2 = "/quietshuffle"

SlashCmdList["QUIETSHUFFLE"] = function(msg)
    local command, arg = msg:match("^(%S+)%s*(.*)")

    if not command or command == "" then
        if addon.CheckSoloShuffleStatus then
            addon.CheckSoloShuffleStatus()
        end
        local inSoloShuffleMatch = addon.IsSoloShuffleMatch and addon.IsSoloShuffleMatch() or false
        if inSoloShuffleMatch then
            print("|cFFFFFF00" .. addon.name .. "|r: Currently IN Solo Shuffle (muting active)")
        else
            print("|cFFFFFF00" .. addon.name .. "|r: NOT in Solo Shuffle")
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
            print("|cFFFFFF00" .. addon.name .. "|r: Solo Shuffle was not started. Use '/qs test start' first.")
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
        print("|cFFFFFF00" .. addon.name .. "|r: Stored messages cleared.")
        return
    end

    if command == "history" then
        if addon.ShowHistoryWindow then
            addon.ShowHistoryWindow()
        end
        return
    end

    print("|cFFFFFF00" .. addon.name .. "|r: Unknown command.")
    print("  /qs - Show status")
    print("  /qs history - Show message history window")
    print("  /qs test start - Simulate Solo Shuffle start")
    print("  /qs test stop - Simulate Solo Shuffle end")
    print("  /qs clear - Clear current messages")
end
