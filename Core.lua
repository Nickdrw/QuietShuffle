-- ============================================================================
-- QUIETSHUFFLE ADDON - Core
-- ============================================================================

local _, addon = ...

addon.name = "QuietShuffle"
addon.version = "1.0.0"

-- ============================================================================
-- SAVEDVARIABLES SETUP - Initialize persistent storage
-- ============================================================================

addon.savedData = {
    history = {}
}

-- ============================================================================
-- STORAGE TABLE - Holds all intercepted messages
-- ============================================================================

addon.messages = {}
addon.messageCounter = 0

-- Track whether we're currently in Solo Shuffle
addon.inSoloShuffle = false

-- Track whether message filtering is enabled
addon.filteringEnabled = false

-- Track if we're in test mode (for testing without real match)
addon.isTestMode = false

-- Track session buttons we create
addon.sessionButtons = {}

-- Track message row frames for reuse in the message list
addon.messageRows = {}

-- Track report buttons for session players
addon.reportButtons = {}

-- Track report list panel state
addon.reportListButtons = {}
addon.reportListOpen = false

-- Track session start time
addon.sessionStartTime = nil

-- Track original chat bubble settings
addon.chatBubbleState = nil

-- Track active character history
addon.activeCharacterKey = nil
addon.activeHistory = nil

-- Track players in the current Solo Shuffle match
addon.matchPlayers = {}

-- Use OnUpdate polling only when C_Timer ticker isn't available
addon.useOnUpdate = false

-- Chat events to filter during Solo Shuffle
addon.CHAT_FILTER_EVENTS = {
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_PARTY_GUIDE",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
}

-- Helper to get table keys
addon.TableKeys = function(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end

-- Character helpers
addon.GetCharacterKey = function()
    local name, realm = UnitFullName("player")
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    return string.format("%s-%s", name or "Unknown", realm or "Unknown")
end

addon.EnsureCharacterHistory = function(key)
    addon.savedData.characters = addon.savedData.characters or {}
    if not addon.savedData.characters[key] then
        addon.savedData.characters[key] = { history = {} }
    end
    return addon.savedData.characters[key].history
end

addon.SetCharacterClass = function(key, classFile)
    if not key or not classFile then
        return
    end
    addon.savedData.characters = addon.savedData.characters or {}
    addon.savedData.characters[key] = addon.savedData.characters[key] or { history = {} }
    addon.savedData.characters[key].class = classFile
end

addon.SetActiveCharacter = function(key)
    addon.activeCharacterKey = key
    addon.activeHistory = addon.EnsureCharacterHistory(key)
    if addon.activeHistory and #addon.activeHistory > 0 then
        addon.selectedSessionIndex = #addon.activeHistory
    else
        addon.selectedSessionIndex = nil
    end
end

addon.GetActiveHistory = function()
    if not addon.activeHistory or not addon.activeCharacterKey then
        addon.SetActiveCharacter(addon.GetCharacterKey())
    end
    return addon.activeHistory
end

local CLASS_ORDER = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    DEATHKNIGHT = 6,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
    MONK = 10,
    DRUID = 11,
    DEMONHUNTER = 12,
    EVOKER = 13,
}

addon.GetCharacterKeys = function()
    local entries = {}
    if addon.savedData and addon.savedData.characters then
        for k, v in pairs(addon.savedData.characters) do
            table.insert(entries, { key = k, class = v.class })
        end
    end
    table.sort(entries, function(a, b)
        local ao = CLASS_ORDER[a.class] or 99
        local bo = CLASS_ORDER[b.class] or 99
        if ao ~= bo then
            return ao < bo
        end
        return (a.key or "") < (b.key or "")
    end)
    return entries
end

addon.GetColoredCharacterLabel = function(key)
    if not key or not addon.savedData or not addon.savedData.characters then
        return key or "Unknown"
    end
    local classFile = addon.savedData.characters[key] and addon.savedData.characters[key].class
    if classFile and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        local color = string.format("|cFF%02X%02X%02X", c.r * 255, c.g * 255, c.b * 255)
        return string.format("%s%s|r", color, key)
    end
    return key
end

-- Initialization message
print("|cFFFFFF00" .. addon.name .. " v" .. addon.version .. "|r: Loaded! Type /qs for status.")
