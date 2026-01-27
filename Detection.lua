-- ============================================================================
-- QUIETSHUFFLE ADDON - Detection & State
-- ============================================================================

local _, addon = ...

-- Disable chat bubbles (persist previous state once)
local function DisableChatBubbles()
    if not addon.chatBubbleState then
        addon.chatBubbleState = {
            chatBubbles = GetCVar("chatBubbles"),
            chatBubblesParty = GetCVar("chatBubblesParty")
        }
    end
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar("chatBubbles", "0")
        C_CVar.SetCVar("chatBubblesParty", "0")
    else
        SetCVar("chatBubbles", "0")
        SetCVar("chatBubblesParty", "0")
    end
end

-- Restore chat bubbles to saved state (if any)
local function RestoreChatBubbles()
    if addon.chatBubbleState then
        if C_CVar and C_CVar.SetCVar then
            C_CVar.SetCVar("chatBubbles", addon.chatBubbleState.chatBubbles or "1")
            C_CVar.SetCVar("chatBubblesParty", addon.chatBubbleState.chatBubblesParty or "1")
        else
            SetCVar("chatBubbles", addon.chatBubbleState.chatBubbles or "1")
            SetCVar("chatBubblesParty", addon.chatBubbleState.chatBubblesParty or "1")
        end
        addon.chatBubbleState = nil
    end
end

addon.DisableChatBubbles = DisableChatBubbles
addon.RestoreChatBubbles = RestoreChatBubbles

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
            local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
            if groupSize >= 6 then
                return true
            end
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
addon.RefreshMatchPlayers = function()
    wipe(addon.matchPlayers)
    wipe(addon.matchPlayersFull)
    wipe(addon.matchPlayerGuids)

    local groupType = 0
    if IsInRaid and IsInRaid() then
        groupType = 2
    elseif IsInGroup and IsInGroup() then
        groupType = 1
    end

    local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0

    if groupType == 0 then
        local name, realm = UnitFullName("player")
        realm = realm or GetRealmName()
        local shortName = name or GetUnitName("player")
        local fullName = (shortName and realm) and (shortName .. "-" .. realm) or shortName
        local guid = UnitGUID and UnitGUID("player")
        if shortName then
            addon.matchPlayers[shortName] = true
        end
        if fullName then
            addon.matchPlayersFull[fullName] = true
        end
        if guid then
            addon.matchPlayerGuids[guid] = true
        end
    else
        for i = 1, groupSize do
            local unitID = (groupType == 1) and ("party" .. i) or ("raid" .. i)
            local name, realm = UnitFullName(unitID)
            realm = realm or GetRealmName()
            local shortName = name or GetUnitName(unitID)
            local fullName = (shortName and realm) and (shortName .. "-" .. realm) or shortName
            local guid = UnitGUID and UnitGUID(unitID)
            if shortName then
                addon.matchPlayers[shortName] = true
            end
            if fullName then
                addon.matchPlayersFull[fullName] = true
            end
            if guid then
                addon.matchPlayerGuids[guid] = true
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

    if inSoloShuffleMatch then
        if not addon.inSoloShuffle then
            addon.inSoloShuffle = true
            addon.sessionStartTime = time()
            local currentKey = addon.GetCharacterKey()
            local _, classFile = UnitClass("player")
            if classFile then
                addon.SetCharacterClass(currentKey, classFile)
            end
            addon.SetActiveCharacter(currentKey)
            DisableChatBubbles()
            wipe(addon.matchPlayers)
            wipe(addon.matchPlayersFull)
            wipe(addon.matchPlayerGuids)
            addon.RefreshMatchPlayers()
            addon.Print("Solo Shuffle started! Muting communications from match players.")
            if addon.debugFilters then
                addon.Print("inSoloShuffle=true")
            end
        end

        if addon.EnableMessageFiltering then
            addon.EnableMessageFiltering()
        end
    elseif not inSoloShuffleMatch and (addon.inSoloShuffle or addon.filteringEnabled) then
        addon.inSoloShuffle = false
        wipe(addon.matchPlayers)
        wipe(addon.matchPlayersFull)
        wipe(addon.matchPlayerGuids)
        if addon.DisableMessageFiltering then
            addon.DisableMessageFiltering()
        end
        RestoreChatBubbles()
        addon.Print("Solo Shuffle ended! Messages unmuted.")
        if addon.debugFilters then
            addon.Print("inSoloShuffle=false")
        end

        local zoneName = GetRealZoneText() or "Unknown"
        local endTime = time()
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

        if addon.debugFilters then
            local counts = {}
            local labelMap = {
                CHAT_MSG_SAY = "/say",
                CHAT_MSG_YELL = "/yell",
                CHAT_MSG_PARTY = "/party",
                CHAT_MSG_PARTY_LEADER = "/party",
                CHAT_MSG_PARTY_GUIDE = "/party",
                CHAT_MSG_INSTANCE_CHAT = "/instance",
                CHAT_MSG_INSTANCE_CHAT_LEADER = "/instance",
                CHAT_MSG_BATTLEGROUND = "/battleground",
                CHAT_MSG_BATTLEGROUND_LEADER = "/battleground",
                CHAT_MSG_ARENA = "/arena",
                CHAT_MSG_ARENA_LEADER = "/arena",
                CHAT_MSG_WHISPER = "whisper",
                CHAT_MSG_WHISPER_INFORM = "whisper",
                CHAT_MSG_EMOTE = "emote",
                CHAT_MSG_TEXT_EMOTE = "text emote",
            }
            for _, msgData in ipairs(addon.messages) do
                local label = labelMap[msgData.channel] or msgData.channel or "Unknown"
                counts[label] = (counts[label] or 0) + 1
            end

            addon.Print("Summary (captured):", tostring(#addon.messages))
            local order = {
                "/say",
                "/yell",
                "/party",
                "/instance",
                "/battleground",
                "/arena",
                "whisper",
                "emote",
                "text emote",
            }
            for _, label in ipairs(order) do
                if counts[label] then
                    addon.Print(label .. ":", tostring(counts[label]))
                    counts[label] = nil
                end
            end
            for label, count in pairs(counts) do
                addon.Print(tostring(label) .. ":", tostring(count))
            end
        end

        local history = addon.EnsureCharacterHistory(addon.GetCharacterKey())
        table.insert(history, sessionEntry)

        if addon.PrintStoredMessages then
            addon.PrintStoredMessages()
        end

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
frame:RegisterEvent("SCENARIO_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PVP_MATCH_ACTIVE")
frame:RegisterEvent("PVP_MATCH_COMPLETE")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
frame:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
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

        print("|cFFFFFF00" .. addon.name .. "|r: Ready! Use /qs history to view messages or /qs for help.")

        SLASH_QUIETSHUFFLE1 = "/qs"
        SLASH_QUIETSHUFFLE2 = "/quietshuffle"

        if C_Timer and C_Timer.NewTicker then
            addon.useOnUpdate = false
            if not addon.statusTicker then
                addon.statusTicker = C_Timer.NewTicker(2, addon.CheckSoloShuffleStatus)
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
        or event == "UPDATE_BATTLEFIELD_STATUS"
        or event == "PLAYER_ENTERING_BATTLEGROUND" then
        addon.CheckSoloShuffleStatus()
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
