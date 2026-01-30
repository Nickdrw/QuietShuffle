-- ============================================================================
-- QUIETSHUFFLE ADDON - Detection & State
-- ============================================================================

local _, addon = ...

-- ============================================================================
-- ROUND-BASED CHAT MUTE
-- During combat rounds, Blizzard bypasses chat event filters. We use the
-- C_SocialRestrictions API to completely mute chat during rounds.
-- BattleNet/RealID messages still work when chat is disabled.
-- ============================================================================

-- Track if we've muted chat for round
addon._roundChatMuted = false
addon._originalChatDisabledState = nil

-- Mute all chat during round (gates open → first blood)
addon.MuteRoundChat = function()
    if addon._roundChatMuted then return end
    
    -- Remember original state so we can restore it properly
    if C_SocialRestrictions and C_SocialRestrictions.IsChatDisabled then
        addon._originalChatDisabledState = C_SocialRestrictions.IsChatDisabled()
    end
    
    -- Disable all in-game chat (BattleNet/RealID still works)
    if C_SocialRestrictions and C_SocialRestrictions.SetChatDisabled then
        C_SocialRestrictions.SetChatDisabled(true)
        addon._roundChatMuted = true
        addon.Print("|cFFFF6666⚔ Round started:|r All chat disabled.")
    end
end

-- Unmute chat when round ends
addon.UnmuteRoundChat = function()
    if not addon._roundChatMuted then return end
    
    -- Restore to original state (was it already disabled before we muted?)
    local restoreState = addon._originalChatDisabledState or false
    
    if C_SocialRestrictions and C_SocialRestrictions.SetChatDisabled then
        C_SocialRestrictions.SetChatDisabled(restoreState)
        addon._roundChatMuted = false
        addon.Print("|cFF00FF00✓ Round ended:|r Chat restored.")
    end
end

-- Listen for round start/end signals
local roundFrame = CreateFrame("Frame")
roundFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
-- Note: We don't register COMBAT_LOG_EVENT_UNFILTERED here as it can cause taint
-- during rated PvP. We rely on system messages instead.
roundFrame:SetScript("OnEvent", function(self, event, ...)
    if not addon.inSoloShuffle then return end
    
    if event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        local message = ...
        if message then
            -- Round START: Gates open
            if message:match("The Arena battle has begun") then
                addon.MuteRoundChat()
            -- Round END: Prep phase starting (someone died, next round prep)
            elseif message:match("Thirty seconds") or message:match("Fifteen seconds") then
                addon.UnmuteRoundChat()
            -- Also unmute on round win/loss messages
            elseif message:match("wins the round") or message:match("Round") then
                addon.UnmuteRoundChat()
            end
        end
    end
end)

-- Disable chat bubbles (persist previous state once)
-- Note: We disable all three bubble CVars to cover all chat types in arenas:
-- chatBubbles (general), chatBubblesParty (party/instance), chatBubblesRaid (raid/instance)
local function DisableChatBubbles()
    if not addon.chatBubbleState then
        addon.chatBubbleState = {
            chatBubbles = GetCVar("chatBubbles"),
            chatBubblesParty = GetCVar("chatBubblesParty"),
            chatBubblesRaid = GetCVar("chatBubblesRaid")
        }
    end
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar("chatBubbles", "0")
        C_CVar.SetCVar("chatBubblesParty", "0")
        C_CVar.SetCVar("chatBubblesRaid", "0")
    else
        SetCVar("chatBubbles", "0")
        SetCVar("chatBubblesParty", "0")
        SetCVar("chatBubblesRaid", "0")
    end
end

-- Restore chat bubbles to saved state (if any)
local function RestoreChatBubbles()
    if addon.chatBubbleState then
        if C_CVar and C_CVar.SetCVar then
            C_CVar.SetCVar("chatBubbles", addon.chatBubbleState.chatBubbles or "1")
            C_CVar.SetCVar("chatBubblesParty", addon.chatBubbleState.chatBubblesParty or "1")
            C_CVar.SetCVar("chatBubblesRaid", addon.chatBubbleState.chatBubblesRaid or "1")
        else
            SetCVar("chatBubbles", addon.chatBubbleState.chatBubbles or "1")
            SetCVar("chatBubblesParty", addon.chatBubbleState.chatBubblesParty or "1")
            SetCVar("chatBubblesRaid", addon.chatBubbleState.chatBubblesRaid or "1")
        end
        addon.chatBubbleState = nil
    end
end

addon.DisableChatBubbles = DisableChatBubbles
addon.RestoreChatBubbles = RestoreChatBubbles

-- ============================================================================
-- SESSION PERSISTENCE
-- Save active session data to survive reloads/disconnects
-- ============================================================================

-- Save current session to SavedVariables (called after each message capture)
addon.SaveActiveSession = function()
    if not addon.inSoloShuffle then return end
    if not addon.savedData then return end
    
    addon.savedData.activeSession = {
        startTime = addon.sessionStartTime,
        messages = addon.messages or {},
        messageCounter = addon.messageCounter or 0,
        characterKey = addon.GetCharacterKey(),
        timestamp = time()
    }
end

-- Restore session from SavedVariables (called on reconnect)
addon.RestoreActiveSession = function()
    if not addon.savedData then return false end
    if not addon.savedData.activeSession then return false end
    
    local session = addon.savedData.activeSession
    local currentKey = addon.GetCharacterKey()
    
    -- Only restore if it's for this character and recent (within 30 minutes)
    if session.characterKey ~= currentKey then
        addon.ClearActiveSession()
        return false
    end
    
    local age = time() - (session.timestamp or 0)
    if age > 1800 then  -- 30 minutes
        addon.ClearActiveSession()
        return false
    end
    
    -- Restore the session data
    addon.sessionStartTime = session.startTime
    addon.messages = session.messages or {}
    addon.messageCounter = session.messageCounter or #addon.messages
    
    local msgCount = #addon.messages
    if msgCount > 0 then
        addon.Print(string.format("Restored %d message(s) from before reload.", msgCount))
    end
    
    return true
end

-- Clear active session from SavedVariables (called when match ends)
addon.ClearActiveSession = function()
    if addon.savedData then
        addon.savedData.activeSession = nil
    end
end

-- Determine if we're in a Solo Shuffle match
addon.IsSoloShuffleMatch = function()
    if addon.isTestMode then
        return true
    end
    local function IsSoloShuffleByStats()
        if not C_PvP or not C_PvP.GetMatchPVPStatIDs or not C_PvP.GetMatchPVPStatInfo then
            return false
        end
        local ids = C_PvP.GetMatchPVPStatIDs()
        if type(ids) ~= "table" then
            return false
        end
        for _, id in ipairs(ids) do
            local info = C_PvP.GetMatchPVPStatInfo(id)
            local name = info and info.name or info
            if type(name) == "string" then
                if name:find("Round") or name:find("Shuffle") then
                    return true
                end
            end
        end
        return false
    end
    if C_PvP then
        if C_PvP.IsSoloShuffleMatch and C_PvP.IsSoloShuffleMatch() then
            return true
        end
        if C_PvP.IsSoloShuffle and C_PvP.IsSoloShuffle() then
            return true
        end
        if C_PvP.IsRatedSoloShuffle and C_PvP.IsRatedSoloShuffle() then
            return true
        end
        if C_PvP.GetActiveMatchBracket and Enum and Enum.PvPBracketType then
            local bracket = C_PvP.GetActiveMatchBracket()
            if bracket == Enum.PvPBracketType.SoloShuffle then
                return true
            end
        end
    end

    local inScenario = (C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario())
        or (IsInScenario and IsInScenario())
        or false
    if inScenario then
        if C_Scenario and C_Scenario.GetInfo then
            local name = C_Scenario.GetInfo()
            if type(name) == "string" and name:find("Solo Shuffle") then
                return true
            end
        end
        local scenarioID
        if C_Scenario and C_Scenario.GetScenarioID then
            scenarioID = C_Scenario.GetScenarioID()
        elseif GetScenarioID then
            scenarioID = GetScenarioID()
        end
        if scenarioID == 168 then
            return true
        end
    end

    if IsInInstance then
        local _, instanceType = IsInInstance()
        if instanceType == "arena" then
            if GetBattlefieldStatus then
                for i = 1, 4 do
                    local status, name = GetBattlefieldStatus(i)
                    if status == "active" and type(name) == "string" and name:find("Solo Shuffle") then
                        return true
                    end
                end
            end
            if C_PvP and C_PvP.GetActiveMatchBracket and Enum and Enum.PvPBracketType then
                local bracket = C_PvP.GetActiveMatchBracket()
                if bracket == Enum.PvPBracketType.SoloShuffle then
                    return true
                end
            end
            if IsSoloShuffleByStats() then
                return true
            end
            -- Removed groupSize >= 6 fallback - too broad, matches arena brawls like Cage of Carnage
            if C_Scenario and C_Scenario.GetInfo then
                local name = C_Scenario.GetInfo()
                if type(name) == "string" and name:find("Solo Shuffle") then
                    return true
                end
            end
        end
    end

    return false
end

-- Build list of current Solo Shuffle match players
-- Note: This adds to existing players rather than replacing, since team composition
-- changes between rounds and we want to track everyone who was ever in the lobby
addon.RefreshMatchPlayers = function()
    addon.matchPlayers = addon.matchPlayers or {}
    addon.matchPlayersFull = addon.matchPlayersFull or {}
    addon.matchPlayerGuids = addon.matchPlayerGuids or {}
    -- Don't wipe - accumulate players across rounds since teams change

    local groupType = 0
    if IsInRaid and IsInRaid() then
        groupType = 2
    elseif IsInGroup and IsInGroup() then
        groupType = 1
    end

    local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0

    -- Always add the player
    local playerName, playerRealm = UnitFullName("player")
    playerRealm = playerRealm or GetRealmName()
    local playerShort = playerName or GetUnitName("player")
    local playerFull = (playerShort and playerRealm) and (playerShort .. "-" .. playerRealm) or playerShort
    local playerGuid = UnitGUID and UnitGUID("player")
    if playerShort then
        addon.matchPlayers[playerShort] = true
    end
    if playerFull then
        addon.matchPlayersFull[playerFull] = true
    end
    if playerGuid then
        addon.matchPlayerGuids[playerGuid] = true
    end

    -- Add group members (party or raid)
    if groupType == 2 then
        -- Raid group - Solo Shuffle uses this
        for i = 1, groupSize do
            local unitID = "raid" .. i
            local name, realm = UnitFullName(unitID)
            if name then
                realm = realm or GetRealmName()
                local fullName = name .. "-" .. realm
                addon.matchPlayers[name] = true
                addon.matchPlayersFull[fullName] = true
                local guid = UnitGUID(unitID)
                if guid then
                    addon.matchPlayerGuids[guid] = true
                end
            end
        end
    elseif groupType == 1 then
        -- Party group
        for i = 1, 4 do
            local unitID = "party" .. i
            local name, realm = UnitFullName(unitID)
            if name then
                realm = realm or GetRealmName()
                local fullName = name .. "-" .. realm
                addon.matchPlayers[name] = true
                addon.matchPlayersFull[fullName] = true
                local guid = UnitGUID(unitID)
                if guid then
                    addon.matchPlayerGuids[guid] = true
                end
            end
        end
    end
    
    -- Also try to get arena opponents (enemy team)
    for i = 1, 5 do
        local unitID = "arena" .. i
        if UnitExists(unitID) then
            local name, realm = UnitFullName(unitID)
            if name then
                realm = realm or GetRealmName()
                local fullName = name .. "-" .. realm
                addon.matchPlayers[name] = true
                addon.matchPlayersFull[fullName] = true
                local guid = UnitGUID(unitID)
                if guid then
                    addon.matchPlayerGuids[guid] = true
                end
            end
        end
    end
end

-- Check if we're in Solo Shuffle and toggle muting accordingly
addon.CheckSoloShuffleStatus = function()
    if addon.IsEnabled and not addon.IsEnabled() then
        if addon.filteringEnabled and addon.DisableMessageFiltering then
            addon.DisableMessageFiltering()
        end
        if addon.RestoreChatBubbles then
            addon.RestoreChatBubbles()
        end
        return
    end
    local inSoloShuffleMatch = addon.IsSoloShuffleMatch()
    
    -- Additional safety: only consider it a real match if we're in an arena instance
    local inArenaInstance = false
    if IsInInstance then
        local _, instanceType = IsInInstance()
        inArenaInstance = (instanceType == "arena")
    end
    
    -- Must be both: API says Solo Shuffle AND we're in arena instance
    -- Also require at least 4 group members (Solo Shuffle has 6)
    local hasEnoughPlayers = (GetNumGroupMembers() or 0) >= 4
    inSoloShuffleMatch = inSoloShuffleMatch and inArenaInstance and hasEnoughPlayers

    if inSoloShuffleMatch then
        if not addon.inSoloShuffle then
            -- If reconnect handler is processing, let it handle the announcement
            if addon._isReconnect then
                return
            end
            addon.inSoloShuffle = true
            addon.sessionStartTime = time()
            -- Clear any stale activeSession from a previous match
            -- This prevents merging old session data if player disconnected from previous match
            addon.ClearActiveSession()
            -- Reset messages for the new session
            addon.messages = addon.messages or {}
            wipe(addon.messages)
            addon.messageCounter = 0
            local currentKey = addon.GetCharacterKey()
            local _, classFile = UnitClass("player")
            if classFile then
                addon.SetCharacterClass(currentKey, classFile)
            end
            addon.SetActiveCharacter(currentKey)
            DisableChatBubbles()
            addon.matchPlayers = addon.matchPlayers or {}
            addon.matchPlayersFull = addon.matchPlayersFull or {}
            addon.matchPlayerGuids = addon.matchPlayerGuids or {}
            wipe(addon.matchPlayers)
            wipe(addon.matchPlayersFull)
            wipe(addon.matchPlayerGuids)
            addon.RefreshMatchPlayers()
            addon.Print("Solo Shuffle started! Muting chat.")
        else
            -- Already in Solo Shuffle - refresh players in case teams changed
            addon.RefreshMatchPlayers()
        end

        if addon.EnableMessageFiltering then
            addon.EnableMessageFiltering()
        end
    elseif not inSoloShuffleMatch and (addon.inSoloShuffle or addon.filteringEnabled) then
        -- Only end the session if we're truly out of the arena, not just a brief API hiccup
        -- during round transitions. Check if we're still in an arena instance.
        local stillInArena = false
        if IsInInstance then
            local _, instanceType = IsInInstance()
            stillInArena = (instanceType == "arena")
        end
        
        -- If we're still in arena and were previously in Solo Shuffle, maintain the session
        -- This prevents brief API inconsistencies during round transitions from ending filtering
        if stillInArena and addon.inSoloShuffle then
            -- Stay in filtering mode - the APIs are likely just temporarily inconsistent
            if addon.EnableMessageFiltering then
                addon.EnableMessageFiltering()
            end
            return
        end
        
        addon.inSoloShuffle = false
        addon.matchPlayers = addon.matchPlayers or {}
        addon.matchPlayersFull = addon.matchPlayersFull or {}
        addon.matchPlayerGuids = addon.matchPlayerGuids or {}
        wipe(addon.matchPlayers)
        wipe(addon.matchPlayersFull)
        wipe(addon.matchPlayerGuids)
        if addon.DisableMessageFiltering then
            addon.DisableMessageFiltering()
        end
        -- Make sure round chat is unmuted when leaving match
        if addon.UnmuteRoundChat then
            addon.UnmuteRoundChat()
        end
        RestoreChatBubbles()

        local zoneName = GetRealZoneText() or "Unknown"
        local endTime = time()
        local sessionDuration = endTime - (addon.sessionStartTime or endTime)
        
        -- Only save sessions that lasted at least 30 seconds
        -- This prevents phantom sessions from brief API glitches during zone transitions
        if sessionDuration < 30 then
            addon.Print("Solo Shuffle detection ended (too brief, not saving).")
            addon.messages = addon.messages or {}
            wipe(addon.messages)
            addon.messageCounter = 0
            addon.ClearActiveSession()
            return
        end
        
        addon.Print("Solo Shuffle ended! Chat restored.")

        local sessionEntry = {
            startTime = addon.sessionStartTime or endTime,
            endTime = endTime,
            timestamp = addon.sessionStartTime or endTime,
            zone = zoneName,
            message_count = 0,
            messages = {}
        }

        for _, msgData in ipairs(addon.messages) do
            table.insert(sessionEntry.messages, msgData)
            sessionEntry.message_count = sessionEntry.message_count + 1
        end

        local history = addon.EnsureCharacterHistory(addon.GetCharacterKey())
        table.insert(history, sessionEntry)
        
        -- Clean up old sessions to prevent SavedVariables bloat
        if addon.CleanupOldSessions then
            addon.CleanupOldSessions(addon.GetCharacterKey())
        end
        
        -- Clear the active session since match ended normally
        addon.ClearActiveSession()

        if addon.PrintStoredMessages then
            addon.PrintStoredMessages()
        end

        addon.messages = addon.messages or {}
        wipe(addon.messages)
        addon.messageCounter = 0
    else
        if addon.chatBubbleState then
            RestoreChatBubbles()
        end
    end
end

-- Event frame setup
local frame = CreateFrame("Frame", "")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("SCENARIO_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PVP_MATCH_ACTIVE")
frame:RegisterEvent("PVP_MATCH_COMPLETE")
frame:RegisterEvent("PVP_MATCH_STATE_CHANGED")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
frame:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("ARENA_OPPONENT_UPDATE")

frame:SetScript("OnEvent", function(self, event)
    -- Always restore chat on logout to prevent leaving it muted
    if event == "PLAYER_LOGOUT" then
        if addon.UnmuteRoundChat then
            addon.UnmuteRoundChat()
        end
        return
    end
    
    if event == "PLAYER_LOGIN" then
        -- Safety: restore chat if it was left muted from a crash/disconnect
        if C_SocialRestrictions and C_SocialRestrictions.IsChatDisabled 
           and C_SocialRestrictions.IsChatDisabled() then
            -- Only restore if we're not in an arena (crash during match)
            local inInstance, instanceType = IsInInstance()
            if not inInstance or instanceType ~= "arena" then
                C_SocialRestrictions.SetChatDisabled(false)
            end
        end
        
        -- Check if we logged in/reconnected into an active Solo Shuffle
        -- This handles disconnect/reconnect scenarios
        -- Only runs on actual login/reconnect, not on entering arena normally
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType == "arena" then
            -- We're already in arena at login time = reconnect scenario
            -- Normal entry would have PLAYER_ENTERING_WORLD fire after loading
            -- Mark that this is a reconnect so CheckSoloShuffleStatus doesn't double-announce
            addon._isReconnect = true
            -- Delay the check slightly to let APIs initialize after login
            C_Timer.After(1, function()
                -- Only start if we're still not in solo shuffle (CheckSoloShuffleStatus may have already started it)
                if addon.IsSoloShuffleMatch() and not addon.inSoloShuffle then
                    -- Check if there's a saved session to restore
                    local restored = addon.RestoreActiveSession()
                    
                    if restored then
                        addon.Print("|cFFFFAAAAReconnected to Solo Shuffle - restored session.|r")
                    else
                        -- No saved session - this is a fresh start (or first load into arena)
                        -- Clear any stale data and start fresh
                        addon.ClearActiveSession()
                        addon.messages = addon.messages or {}
                        wipe(addon.messages)
                        addon.messageCounter = 0
                        addon.sessionStartTime = time()
                        addon.Print("Solo Shuffle started! Muting chat.")
                    end
                    
                    addon.inSoloShuffle = true
                    addon.sessionStartTime = addon.sessionStartTime or time()
                    local currentKey = addon.GetCharacterKey()
                    local _, classFile = UnitClass("player")
                    if classFile then
                        addon.SetCharacterClass(currentKey, classFile)
                    end
                    addon.SetActiveCharacter(currentKey)
                    addon.matchPlayers = addon.matchPlayers or {}
                    addon.matchPlayersFull = addon.matchPlayersFull or {}
                    addon.matchPlayerGuids = addon.matchPlayerGuids or {}
                    wipe(addon.matchPlayers)
                    wipe(addon.matchPlayersFull)
                    wipe(addon.matchPlayerGuids)
                    addon.RefreshMatchPlayers()
                    DisableChatBubbles()
                    if addon.EnableMessageFiltering then
                        addon.EnableMessageFiltering()
                    end
                end
                addon._isReconnect = false
            end)
        end
        
        if not QuietShuffleSavedData then
            QuietShuffleSavedData = {
                history = {}
            }
        end

        addon.savedData = QuietShuffleSavedData

        local currentKey = addon.GetCharacterKey()
        if addon.savedData.history and type(addon.savedData.history) == "table" then
            local legacyHistory = addon.savedData.history
            addon.savedData.history = nil
            if #legacyHistory > 0 then
                addon.savedData.characters = addon.savedData.characters or {}
                addon.savedData.characters[currentKey] = addon.savedData.characters[currentKey] or { history = {} }
                addon.savedData.characters[currentKey].history = legacyHistory
            end
        end

        local _, classFile = UnitClass("player")
        if classFile then
            addon.SetCharacterClass(currentKey, classFile)
        end
        addon.SetActiveCharacter(currentKey)

        -- Load saved chat frame preference
        if addon.savedData.outputChatFrame and addon.savedData.outputChatFrame ~= "" then
            addon.useDedicatedChatFrame = true
        end

        if addon.RegisterMinimapIcon and addon.RegisterMinimapIcon() then
            -- LibDBIcon handled
        elseif addon.CreateMinimapButton then
            addon.CreateMinimapButton()
        end

        addon.Print("Ready! Use /qs history to view messages or /qs for help.")
        -- Print clickable support message
        local supportLink = "|cFF00CCFF|Haddon:QuietShuffle:settings|h[Any support appreciated!]|h|r"
        addon.Print(supportLink)

        SLASH_QUIETSHUFFLE1 = "/qs"
        SLASH_QUIETSHUFFLE2 = "/quietshuffle"

        if C_Timer and C_Timer.NewTicker then
            addon.useOnUpdate = false
            if not addon.statusTicker then
                addon.statusTicker = C_Timer.NewTicker(5, addon.CheckSoloShuffleStatus)
            end
        else
            addon.useOnUpdate = true
        end
        addon.CheckSoloShuffleStatus()
    elseif event == "SCENARIO_UPDATE"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PVP_MATCH_ACTIVE"
        or event == "PVP_MATCH_COMPLETE"
        or event == "PVP_MATCH_STATE_CHANGED"
        or event == "UPDATE_BATTLEFIELD_STATUS"
        or event == "PLAYER_ENTERING_BATTLEGROUND" then
        
        -- Pre-register filters early when entering any arena to avoid missing early messages
        -- The filter callback checks addon.filteringEnabled before suppressing, so this is safe
        if event == "PLAYER_ENTERING_BATTLEGROUND" or event == "PVP_MATCH_ACTIVE" or event == "PVP_MATCH_STATE_CHANGED" then
            if IsInInstance then
                local _, instanceType = IsInInstance()
                if instanceType == "arena" and addon.EnableMessageFiltering then
                    -- Pre-enable filtering; CheckSoloShuffleStatus will set inSoloShuffle if appropriate
                    if not addon._filtersRegistered then
                        addon.EnableMessageFiltering()
                    end
                end
            end
        end
        addon.CheckSoloShuffleStatus()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "ARENA_OPPONENT_UPDATE" then
        -- Refresh match players when group or arena opponents change
        if addon.inSoloShuffle then
            addon.RefreshMatchPlayers()
        end
    end
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    if not addon.useOnUpdate then
        return
    end
    addon.statusPollElapsed = (addon.statusPollElapsed or 0) + elapsed
    if addon.statusPollElapsed >= 2 then
        addon.statusPollElapsed = 0
        addon.CheckSoloShuffleStatus()
    end
end)
