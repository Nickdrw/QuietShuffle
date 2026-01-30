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

-- Helper to check if a player name is in the match
local function IsMatchPlayer(name)
    if not name then return false end
    
    -- Normalize: remove realm suffix variations
    local shortName = name:match("^([^-]+)") or name
    
    -- Also try lowercase for case-insensitive matching
    local shortNameLower = shortName:lower()
    
    -- Check short name table (most reliable)
    if addon.matchPlayers then
        if addon.matchPlayers[shortName] then
            return true
        end
        -- Try case-insensitive
        for playerName, _ in pairs(addon.matchPlayers) do
            if playerName:lower() == shortNameLower then
                return true
            end
        end
    end
    
    -- Check full name table
    if addon.matchPlayersFull then
        -- Direct match
        if addon.matchPlayersFull[name] then
            return true
        end
        -- Try with current realm if name has no realm
        if not name:find("-") then
            local realm = GetRealmName and GetRealmName() or ""
            realm = realm:gsub("%s+", "")  -- Remove spaces from realm name
            if addon.matchPlayersFull[name .. "-" .. realm] then
                return true
            end
        end
        -- Try case-insensitive on full names
        local nameLower = name:lower()
        for playerName, _ in pairs(addon.matchPlayersFull) do
            if playerName:lower() == nameLower then
                return true
            end
        end
    end
    
    return false
end

-- ============================================================================
-- OUTGOING MESSAGE HANDLING
-- We cannot block outgoing messages during rated PvP without causing taint.
-- SetScript/HookScript on chat editboxes triggers ADDON_ACTION_FORBIDDEN.
-- Instead, we hide outgoing messages from display and show a warning.
-- During rounds, C_SocialRestrictions.SetChatDisabled blocks everything anyway.
-- ============================================================================

-- Helper to check if sender is the player themselves
local function IsSelf(sender)
    if not sender then return false end
    local selfName = UnitName("player")
    if not selfName then return false end
    local senderShort = sender:match("^([^-]+)") or sender
    return senderShort == selfName
end

-- Helper to store outgoing message in history (with deduplication via lineID)
local function StoreOutgoingMessage(event, message, target, lineID)
    -- Dedupe using lineID if available
    if lineID and lineID > 0 then
        addon._seenLineIDs = addon._seenLineIDs or {}
        if addon._seenLineIDs[lineID] then
            return false  -- duplicate, already stored
        end
        addon._seenLineIDs[lineID] = true
        -- Clean old lineIDs periodically (keep last 100)
        local count = 0
        for _ in pairs(addon._seenLineIDs) do count = count + 1 end
        if count > 100 then
            addon._seenLineIDs = { [lineID] = true }
        end
    end
    
    local selfName = UnitName("player")
    local selfGuid = UnitGUID("player")
    
    addon.messages = addon.messages or {}
    addon.messageCounter = (addon.messageCounter or 0) + 1
    table.insert(addon.messages, {
        sender = selfName or "You",
        channel = event,
        message = tostring(message) or "",
        timestamp = time(),
        lineID = lineID,
        guid = selfGuid,
        class = select(2, UnitClass("player")),
        id = addon.messageCounter,
        outgoing = true,
        target = target  -- for whispers, who we whispered
    })
    return true  -- stored successfully
end

-- Intercept and store chat messages
-- IMPORTANT: During rated PvP, some chat arguments are marked as "secret" by Blizzard.
-- We extract varargs at the top level but skip lineID/guid if it causes issues.
addon.InterceptChatMessage = function(self, event, message, sender, ...)
    -- Quick exit if not filtering
    if not addon.filteringEnabled or not addon.inSoloShuffle then
        return false
    end

    -- Extract lineID early for deduplication (works for both incoming and outgoing)
    local lineID, _ = ExtractChatLineInfo(...)

    -- Handle outgoing messages (messages YOU sent)
    -- We can't block them, but we hide them, store them, and show a warning
    
    -- Outgoing whisper to lobby player
    if event == "CHAT_MSG_WHISPER_INFORM" then
        -- 'sender' param is actually the target for WHISPER_INFORM
        local isMatch = IsMatchPlayer(sender)
        if addon.debugFilters then
            addon.Print(string.format("|cFFFFFF00[DEBUG] Outgoing whisper to '%s' - IsMatchPlayer: %s|r", 
                tostring(sender), tostring(isMatch)))
        end
        if not isMatch then
            return false  -- let whispers to non-match players through
        end
        local stored = StoreOutgoingMessage(event, message, sender, lineID)
        if stored then
            addon.SaveActiveSession()
            addon.Print("|cFFFFAAAA⚠ You whispered a lobby player.|r Stay quiet, stay focused!")
        end
        return true  -- hide from chat
    end
    
    -- Outgoing say/yell
    if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" then
        if IsSelf(sender) then
            local stored = StoreOutgoingMessage(event, message, nil, lineID)
            if stored then
                addon.SaveActiveSession()
                addon.Print("|cFFFFAAAA⚠ You sent a message.|r Stay quiet, stay focused!")
            end
            return true  -- hide from chat
        end
    end
    
    -- Outgoing party/instance chat
    if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" 
       or event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
        if IsSelf(sender) then
            local stored = StoreOutgoingMessage(event, message, nil, lineID)
            if stored then
                addon.SaveActiveSession()
                addon.Print("|cFFFFAAAA⚠ You sent a party message.|r Stay quiet, stay focused!")
            end
            return true  -- hide from chat
        end
    end

    -- Outgoing emote
    if event == "CHAT_MSG_EMOTE" or event == "CHAT_MSG_TEXT_EMOTE" then
        if IsSelf(sender) then
            local stored = StoreOutgoingMessage(event, message, nil, lineID)
            if stored then
                addon.SaveActiveSession()
                addon.Print("|cFFFFAAAA⚠ You used an emote.|r Stay quiet, stay focused!")
            end
            return true  -- hide from chat
        end
    end

    -- For incoming whispers, only filter if sender is a match player
    if event == "CHAT_MSG_WHISPER" then
        local isMatch = IsMatchPlayer(sender)
        if addon.debugFilters then
            addon.Print(string.format("|cFFFFFF00[DEBUG] Incoming whisper from '%s' - IsMatchPlayer: %s|r", 
                tostring(sender), tostring(isMatch)))
        end
        if not isMatch then
            return false  -- let whispers from non-match players through
        end
    end
    
    -- Skip if this is our own message (already handled above)
    -- This prevents double-storing outgoing messages
    if IsSelf(sender) then
        -- If we get here, it's an outgoing message type we didn't explicitly handle
        -- Just filter it without storing (already stored above if applicable)
        return true
    end

    -- Extract potential lineID and guid at top level using select (MUST be outside pcall)
    -- Chat event varargs after (message, sender): language, channelString, target, flags, 
    -- unknown, channelNumber, channelName, unknown, lineID, guid, bnSenderID
    -- So lineID is typically at position 9, guid at position 10 (but can vary by event)
    local arg9 = select(9, ...)
    local arg10 = select(10, ...)
    local arg11 = select(11, ...)
    local arg12 = select(12, ...)
    
    -- Try to find lineID (numeric > 0)
    local lineID = nil
    if type(arg9) == "number" and arg9 > 0 then
        lineID = arg9
    elseif type(arg11) == "number" and arg11 > 0 then
        lineID = arg11
    elseif type(arg10) == "number" and arg10 > 0 then
        lineID = arg10
    end
    
    -- Try to find guid (string matching Player-*)
    local guid = nil
    if type(arg10) == "string" and arg10:match("^Player%-") then
        guid = arg10
    elseif type(arg12) == "string" and arg12:match("^Player%-") then
        guid = arg12
    elseif type(arg11) == "string" and arg11:match("^Player%-") then
        guid = arg11
    end
    
    -- Dedupe using lineID to prevent duplicate captures from multiple filter registrations
    if lineID and lineID > 0 then
        addon._seenLineIDs = addon._seenLineIDs or {}
        if addon._seenLineIDs[lineID] then
            return true  -- still suppress, but don't re-record
        end
        addon._seenLineIDs[lineID] = true
        -- Clean old lineIDs periodically (keep last 100)
        local count = 0
        for _ in pairs(addon._seenLineIDs) do count = count + 1 end
        if count > 100 then
            addon._seenLineIDs = { [lineID] = true }
        end
    end

    -- Wrap the capture logic in pcall to prevent errors from breaking filters
    local ok, result = pcall(function()
        local timestamp = time()
        local senderStr = tostring(sender) or ""
        local messageStr = tostring(message) or ""

        local classFile = nil
        if guid then
            classFile = addon.ResolveClassFromGUID(guid)
        end

        addon.messages = addon.messages or {}
        addon.messageCounter = (addon.messageCounter or 0) + 1
        table.insert(addon.messages, {
            sender = senderStr,
            channel = event,
            message = messageStr,
            timestamp = timestamp,
            lineID = lineID,
            guid = guid,
            class = classFile,
            id = addon.messageCounter
        })
        
        addon.SaveActiveSession()

        return true
    end)

    -- Handle pcall result - on error, let message through
    if not ok then
        return false
    end
    return result
end

-- NOTE: We only use ChatFrame_AddMessageEventFilter which is the official, safe API.
-- Previously we wrapped ChatFrame_MessageEventHandler, ChatFrame_OnEvent, and
-- ChatFrame.AddMessage directly, but this causes ADDON_ACTION_FORBIDDEN errors
-- during rated PvP because those functions become protected during combat.
-- The official filter API handles this correctly without causing taint.

-- Register message interception using the official filter API
addon.EnableMessageFiltering = function()
    if addon.filteringEnabled then
        return
    end
    addon.filteringEnabled = true
    
    -- Only register filters once (avoid any gaps)
    if not addon._filtersRegistered then
        for _, event in ipairs(addon.CHAT_FILTER_EVENTS) do
            ChatFrame_AddMessageEventFilter(event, addon.InterceptChatMessage)
        end
        addon._filtersRegistered = true
        if addon.debugFilters then
            addon.Print("Filters registered")
        end
    end
end

-- Disable message interception
addon.DisableMessageFiltering = function()
    addon.filteringEnabled = false
    -- Filters stay registered but inactive - the filteringEnabled check at the
    -- top of InterceptChatMessage will return false and let messages through.
    -- This avoids add/remove cycles that can cause duplicates or missed messages.
    if addon.debugFilters then
        addon.Print("Filters disabled")
    end
end

-- Note: Chat history scanning was removed. During rated PvP combat rounds,
-- Blizzard bypasses the event system entirely. We now use C_SocialRestrictions
-- to mute chat during rounds instead (see Detection.lua).
