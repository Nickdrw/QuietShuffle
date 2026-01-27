-- ============================================================================
-- QUIETSHUFFLE ADDON - Slash Commands
-- ============================================================================

local _, addon = ...

SlashCmdList["QUIETSHUFFLE"] = function(msg)
    local command, arg = msg:match("^(%S+)%s*(.*)")

    if addon.IsEnabled and not addon.IsEnabled() then
        addon.Print("Disabled")
        return
    end

    if not command or command == "" then
        addon.Print("List of available commands")
        addon.Print("/qs status - Show status")
        addon.Print("/qs history - Show message history window")
        addon.Print("/qs clear - Clear current messages")
        addon.Print("/qs chatframe - Toggle dedicated chat tab output")
        addon.Print("/qs debug on|off - Toggle debug output")
        return
    end

    if command == "status" then
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
        addon.messages = addon.messages or {}
        wipe(addon.messages)
        addon.Print("Stored messages cleared.")
        return
    end

    if command == "history" then
        if addon.ShowHistoryWindow then
            addon.ShowHistoryWindow()
        end
        return
    end

    if command == "chatframe" then
        -- Toggle or set chat frame. Usage: /qs chatframe [name]
        addon.savedData = addon.savedData or {}
        if arg and arg ~= "" then
            -- Set specific chat frame
            addon.savedData.outputChatFrame = arg
            addon.useDedicatedChatFrame = true
            addon.dedicatedChatFrame = nil
            local frame = addon.FindChatFrameByName(arg)
            if frame then
                addon.Print("Using '" .. arg .. "' chat tab for output.")
            else
                addon.Print("Chat tab '" .. arg .. "' not found. Create it or check spelling.")
            end
        else
            -- Toggle off
            addon.savedData.outputChatFrame = nil
            addon.useDedicatedChatFrame = false
            addon.dedicatedChatFrame = nil
            addon.Print("Using default chat frame for output.")
            addon.Print("Use /qs chatframe <name> to set a specific tab, or configure in Settings.")
        end
        return
    end

    if command == "debug" then
        if arg == "on" or arg == "off" then
            addon.debugFilters = (arg == "on")
        end
        addon.Print("Debug " .. (addon.debugFilters and "enabled" or "disabled") .. ".")
        return
    end

    addon.Print("Unknown command.")
    addon.Print("List of available commands")
    addon.Print("/qs status - Show status")
    addon.Print("/qs history - Show message history window")
    addon.Print("/qs clear - Clear current messages")
    addon.Print("/qs chatframe - Toggle dedicated chat tab output")
    addon.Print("/qs debug on|off - Toggle debug output")
end
