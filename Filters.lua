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
    local inSoloShuffleMatch = addon.IsSoloShuffleMatch and addon.IsSoloShuffleMatch() or false
    if inSoloShuffleMatch and not addon.inSoloShuffle then
        if addon.CheckSoloShuffleStatus then
            addon.CheckSoloShuffleStatus()
        end
    elseif not inSoloShuffleMatch and addon.inSoloShuffle then
        if addon.CheckSoloShuffleStatus then
            addon.CheckSoloShuffleStatus()
        end
    end

    -- If the filter is firing, capture it (filtering is active)

    if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
        if addon.isTestMode then
            -- capture
        elseif not addon.matchPlayers[sender] then
            return false
        end
    end

    local timestamp = time()
    local lineID, guid = ExtractChatLineInfo(...)

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

    return true
end

-- Register message interception
addon.EnableMessageFiltering = function()
    addon.filteringEnabled = true
    for _, event in ipairs(addon.CHAT_FILTER_EVENTS) do
        ChatFrame_RemoveMessageEventFilter(event, addon.InterceptChatMessage)
    end
    for _, event in ipairs(addon.CHAT_FILTER_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, addon.InterceptChatMessage)
    end
end

-- Disable message interception
addon.DisableMessageFiltering = function()
    addon.filteringEnabled = false
    for _, event in ipairs(addon.CHAT_FILTER_EVENTS) do
        ChatFrame_RemoveMessageEventFilter(event, addon.InterceptChatMessage)
    end
end
