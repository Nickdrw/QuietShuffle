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

-- Determine if we're in a Solo Shuffle match
addon.IsSoloShuffleMatch = function()
    if addon.isTestMode then
        return true
    end
    if C_PvP then
        if C_PvP.IsSoloShuffle and C_PvP.IsSoloShuffle() then
            return true
        end
        if C_PvP.IsRatedSoloShuffle and C_PvP.IsRatedSoloShuffle() then
            return true
        end
    end

    local inScenario = (C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario())
        or (IsInScenario and IsInScenario())
        or false
    if inScenario then
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

    return false
end

-- Build list of current Solo Shuffle match players
addon.RefreshMatchPlayers = function()
    addon.matchPlayers = {}

    local groupType = 0
    if IsInRaid and IsInRaid() then
        groupType = 2
    elseif IsInGroup and IsInGroup() then
        groupType = 1
    end

    local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0

    if groupType == 0 then
        addon.matchPlayers[GetUnitName("player")] = true
    else
        for i = 1, groupSize do
            local unitID = (groupType == 1) and ("party" .. i) or ("raid" .. i)
            local name = GetUnitName(unitID)
            if name then
                addon.matchPlayers[name] = true
            end
        end
    end
end

-- Check if we're in Solo Shuffle and toggle muting accordingly
addon.CheckSoloShuffleStatus = function()
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
            addon.matchPlayers = {}
            addon.RefreshMatchPlayers()
            print("|cFFFFFF00" .. addon.name .. "|r: Solo Shuffle started! Muting communications from match players.")
        end

        if addon.EnableMessageFiltering then
            addon.EnableMessageFiltering()
        end
    elseif not inSoloShuffleMatch and (addon.inSoloShuffle or addon.filteringEnabled) then
        addon.inSoloShuffle = false
        addon.matchPlayers = {}
        if addon.DisableMessageFiltering then
            addon.DisableMessageFiltering()
        end
        RestoreChatBubbles()
        print("|cFFFFFF00" .. addon.name .. "|r: Solo Shuffle ended! Messages unmuted.")

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

        local history = addon.EnsureCharacterHistory(addon.GetCharacterKey())
        table.insert(history, sessionEntry)

        if addon.PrintStoredMessages then
            addon.PrintStoredMessages()
        end

        addon.messages = {}
        addon.messageCounter = 0
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
