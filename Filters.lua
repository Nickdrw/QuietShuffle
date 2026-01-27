-- ============================================================================
-- QUIETSHUFFLE ADDON - Filters & Capture
-- ============================================================================

local _, addon = ...

-- Resolve class file from GUID for coloring names
addon.ResolveClassFromGUID = function(g)
    if not g then return nil end
    -- Preferred: C_PlayerInfo.GetClass
    local loc = PlayerLocation and PlayerLocation:CreateFromGUID(g)
    if loc and loc.IsValid and loc:IsValid() and C_PlayerInfo and C_PlayerInfo.GetClass then
        local ci = C_PlayerInfo.GetClass(loc)
        if ci and ci.classFile and RAID_CLASS_COLORS[ci.classFile] then
            return ci.classFile
        end
    end
    -- Fallback: scan GetPlayerInfoByGUID returns for a valid class token
    if GetPlayerInfoByGUID then
        local r1,r2,r3,r4,r5,r6,r7,r8 = GetPlayerInfoByGUID(g)
        local candidates = {r1,r2,r3,r4,r5,r6,r7,r8}
        for _,v in ipairs(candidates) do
            if type(v) == "string" then
                local token = v:upper()
                if RAID_CLASS_COLORS[token] then
                    return token
                end
            end
        end
    end
    return nil
end

local function ExtractChatLineInfo(...)
    local lineID = select(9, ...)
    if type(lineID) ~= "number" or lineID <= 0 then
        lineID = select(10, ...)
        if type(lineID) ~= "number" or lineID <= 0 then
            lineID = select(11, ...)
            if type(lineID) ~= "number" or lineID <= 0 then
                lineID = nil
            end
        end
    end

    local guid = select(10, ...)
    if type(guid) ~= "string" or not guid:match("^Player%-") then
        guid = select(11, ...)
        if type(guid) ~= "string" or not guid:match("^Player%-") then
            guid = select(12, ...)
            if type(guid) ~= "string" or not guid:match("^Player%-") then
                guid = nil
            end
        end
    end

    return lineID, guid
end

-- Intercept and store chat messages
addon.InterceptChatMessage = function(self, event, message, sender, ...)
    -- Capture varargs before entering pcall
    local extraArgs = {...}

    -- Wrap in pcall to prevent errors from breaking the filter permanently
    local ok, result = pcall(function()
        -- Trust the current filtering state; detection is handled by events and the timer.
        -- Do NOT call IsSoloShuffleMatch() here - it can return inconsistent values during
        -- round transitions, causing messages to slip through.

        if addon.debugFilters then
            -- Color red if filtering won't happen (state is false)
            if not addon.filteringEnabled or not addon.inSoloShuffle then
                addon.Print("|cFFFF0000filter", event, "inSolo=", tostring(addon.inSoloShuffle), "enabled=", tostring(addon.filteringEnabled), "|r")
            else
                addon.Print("filter", event, "inSolo=", tostring(addon.inSoloShuffle), "enabled=", tostring(addon.filteringEnabled))
            end
        end

        if not addon.filteringEnabled or not addon.inSoloShuffle then
            return false
        end

        -- If the filter is firing, capture it (filtering is active)

        local timestamp = time()

        -- Deduplicate: build a hash key from event, sender, message
        local msgHash = string.format("%s|%s|%s", event or "", sender or "", message or "")
        addon.recentMessages = addon.recentMessages or {}
        local now = GetTime()

        -- Clean up expired hashes (collect keys first to avoid modifying during iteration)
        local expiredKeys = {}
        for k, v in pairs(addon.recentMessages) do
            if now - v > (addon.recentMessageExpiry or 2) then
                table.insert(expiredKeys, k)
            end
        end
        for _, k in ipairs(expiredKeys) do
            addon.recentMessages[k] = nil
        end

        -- Skip if we've already captured this exact message recently
        if addon.recentMessages[msgHash] then
            if addon.debugFilters then
                addon.Print("dedupe skip", event, sender or "Unknown")
            end
            return true  -- still suppress display, but don't re-record
        end
        addon.recentMessages[msgHash] = now

        local lineID, guid = ExtractChatLineInfo(unpack(extraArgs))

        local classFile = addon.ResolveClassFromGUID(guid)

        addon.messages = addon.messages or {}
        addon.messageCounter = (addon.messageCounter or 0) + 1
        table.insert(addon.messages, {
            sender = sender,
            channel = event,
            message = message,
            timestamp = timestamp,
            lineID = lineID,
            guid = guid,
            class = classFile,
            id = addon.messageCounter
        })

        if addon.debugFilters then
            addon.Print("captured", event, sender or "Unknown", "-", message or "")
        end

        return true
    end)

    -- Handle pcall result
    if not ok then
        if addon.debugFilters then
            addon.Print("|cFFFF0000filter error:", tostring(result), "|r")
        end
        return false  -- Don't suppress on error, let message through
    end
    return result
end

local function EnsureChatHandlerHook()
    if addon._chatHandlerWrapped or not ChatFrame_MessageEventHandler then
        return
    end
    local original = ChatFrame_MessageEventHandler
    ChatFrame_MessageEventHandler = function(self, event, ...)
        if addon.filteringEnabled and addon.inSoloShuffle and addon.FilterEventLookup and addon.FilterEventLookup[event] then
            local suppressed = addon.InterceptChatMessage(self, event, ...)
            if suppressed then
                return
            end
        end
        return original(self, event, ...)
    end
    addon._chatHandlerWrapped = true
end

local function EnsureChatFrameOnEventHook()
    if addon._chatFrameOnEventWrapped or not ChatFrame_OnEvent then
        return
    end
    local original = ChatFrame_OnEvent
    ChatFrame_OnEvent = function(self, event, ...)
        if addon.filteringEnabled and addon.inSoloShuffle and addon.FilterEventLookup and addon.FilterEventLookup[event] then
            local suppressed = addon.InterceptChatMessage(self, event, ...)
            if suppressed then
                if addon.debugFilters then
                    addon.Print("suppress", event)
                end
                return
            end
        end
        return original(self, event, ...)
    end
    addon._chatFrameOnEventWrapped = true
end

local function EnsureChatEventDebugHook()
    if addon._chatEventDebugHook or not hooksecurefunc or not ChatFrame_OnEvent then
        return
    end
    hooksecurefunc("ChatFrame_OnEvent", function(_, event, ...)
        if addon.debugFilters and type(event) == "string" and event:find("^CHAT_MSG_") then
            addon.Print("event", event)
        end
    end)
    addon._chatEventDebugHook = true
end

local function ShouldSuppressChatMessage(message)
    if type(message) ~= "string" then
        return false
    end
    -- Check for various channel hyperlink formats
    local channelPatterns = {
        "|Hchannel:PARTY",
        "|Hchannel:PARTY_LEADER",
        "|Hchannel:PARTY_GUIDE",
        "|Hchannel:INSTANCE_CHAT",
        "|Hchannel:INSTANCE_CHAT_LEADER",
        "|Hchannel:BATTLEGROUND",
        "|Hchannel:BATTLEGROUND_LEADER",
        "|Hchannel:ARENA",
        "|Hchannel:ARENA_LEADER",
        "|Hchannel:SAY",
        "|Hchannel:YELL",
        "|Hchannel:EMOTE",
        "|Hchannel:TEXT_EMOTE",
        -- Also catch generic channel format used for /say /yell in some locales
        "|Hchannel:channel:0",
    }
    -- Chat type prefixes that appear in formatted messages (localized)
    local chatTypePrefixes = {
        "%[Party%]",
        "%[Party Leader%]",
        "%[Instance%]",
        "%[Battleground%]",
        "%[Arena%]",
    }
    local ok, suppressed = pcall(function()
        -- Check channel hyperlinks
        for _, pattern in ipairs(channelPatterns) do
            if string.find(message, pattern, 1, true) then
                return true
            end
        end
        -- Check chat type prefixes
        for _, pattern in ipairs(chatTypePrefixes) do
            if string.find(message, pattern) then
                return true
            end
        end
        return false
    end)
    if ok then
        return suppressed
    end
    return false
end

local function EnsureAddMessageHook()
    if addon._addMessageHooked or not NUM_CHAT_WINDOWS then
        return
    end
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.AddMessage and not frame._qsAddMessage then
            frame._qsAddMessage = frame.AddMessage
            frame.AddMessage = function(self, message, ...)
                if addon.filteringEnabled and addon.inSoloShuffle and ShouldSuppressChatMessage(message) then
                    if addon.debugFilters then
                        addon.Print("suppress text")
                    end
                    return
                end
                return self:_qsAddMessage(message, ...)
            end
        end
    end
    addon._addMessageHooked = true
end

-- Register message interception
addon.EnableMessageFiltering = function()
    if addon.filteringEnabled then
        return
    end
    addon.filteringEnabled = true
    if addon.debugFilters then
        addon.Print("enabling filters")
    end
    addon.FilterEventLookup = addon.FilterEventLookup or {}
    wipe(addon.FilterEventLookup)
    for _, event in ipairs(addon.CHAT_FILTER_EVENTS) do
        addon.FilterEventLookup[event] = true
    end
    EnsureChatHandlerHook()
    EnsureChatFrameOnEventHook()
    EnsureChatEventDebugHook()
    EnsureAddMessageHook()
    for _, event in ipairs(addon.CHAT_FILTER_EVENTS) do
        ChatFrame_RemoveMessageEventFilter(event, addon.InterceptChatMessage)
    end
    for _, event in ipairs(addon.CHAT_FILTER_EVENTS) do
        if addon.debugFilters then
            addon.Print("add filter", event)
        end
        ChatFrame_AddMessageEventFilter(event, addon.InterceptChatMessage)
    end
end

-- Disable message interception
addon.DisableMessageFiltering = function()
    addon.filteringEnabled = false
    if addon.debugFilters then
        addon.Print("disabling filters")
    end
    for _, event in ipairs(addon.CHAT_FILTER_EVENTS) do
        ChatFrame_RemoveMessageEventFilter(event, addon.InterceptChatMessage)
    end
end
