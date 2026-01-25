-- ============================================================================
-- QUIETSHUFFLE ADDON - Core
-- ============================================================================

local _, addon = ...

_G.QuietShuffle = addon

addon.name = "QuietShuffle"
addon.version = "1.0.0"

addon.GetChatPrefix = function()
    local icon = addon.chatIcon or addon.minimapIcon or "Interface/Icons/INV_Misc_QuestionMark"
    local quiet = "|cFF2FAEF7Quiet|r"
    local shuffle = "|cFF7B579CShuffle|r"
    return string.format("|T%s:16:16:0:0:64:64:0:64:0:64|t %s%s:", icon, quiet, shuffle)
end

addon.Print = function(...)
    local parts = { ... }
    for i = 1, #parts do
        parts[i] = tostring(parts[i])
    end
    local msg = table.concat(parts, " ")
    print(addon.GetChatPrefix() .. " " .. msg)
end

-- ============================================================================
-- SAVEDVARIABLES SETUP - Initialize persistent storage
-- ============================================================================

addon.savedData = {
    history = {},
    enabled = true
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
addon.debugFilters = false

-- Track whether addon features are enabled
addon.IsEnabled = function()
    return addon.savedData == nil or addon.savedData.enabled ~= false
end

addon.SetEnabled = function(enabled)
    addon.savedData = addon.savedData or {}
    addon.savedData.enabled = enabled and true or false
    if not addon.savedData.enabled then
        if addon.DisableMessageFiltering then
            addon.DisableMessageFiltering()
        end
        addon.filteringEnabled = false
        addon.inSoloShuffle = false
        addon.matchPlayers = {}
        addon.matchPlayersFull = {}
        addon.matchPlayerGuids = {}
        if addon.RestoreChatBubbles then
            addon.RestoreChatBubbles()
        end
    else
        if addon.CheckSoloShuffleStatus then
            addon.CheckSoloShuffleStatus()
        end
    end
end

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
    "CHAT_MSG_PARTY_SAY",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_BATTLEGROUND",
    "CHAT_MSG_BATTLEGROUND_LEADER",
    "CHAT_MSG_ARENA",
    "CHAT_MSG_ARENA_LEADER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
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

addon.OpenSettingsPanel = function()
    if Settings and Settings.OpenToCategory and addon.settingsCategory then
        if addon.settingsCategory.GetID then
            Settings.OpenToCategory(addon.settingsCategory:GetID())
        else
            Settings.OpenToCategory(addon.settingsCategory)
        end
        return
    end
    if InterfaceOptionsFrame_OpenToCategory and addon.settingsCategory then
        InterfaceOptionsFrame_OpenToCategory(addon.settingsCategory)
    end
end

addon.ToggleHistoryWindow = function()
    if addon.historyFrame and addon.historyFrame:IsShown() then
        addon.historyFrame:Hide()
        return
    end
    if addon.ShowHistoryWindow then
        addon.ShowHistoryWindow()
    end
end

-- ============================================================================
-- MINIMAP BUTTON
-- ============================================================================

addon.minimapIcon = "Interface/AddOns/QuietShuffle/Media/quietshuffleicon.tga"
addon.chatIcon = "Interface/AddOns/QuietShuffle/Media/quietshuffleicon16x16_straight_alpha.tga"
addon.historyBackground = "Interface/AddOns/QuietShuffle/Media/quietshuffle_logo"
addon.messageBackground = "Interface/AddOns/QuietShuffle/Media/quietshuffle_logo_bubble"

addon.RegisterMinimapIcon = function()
    if addon.minimapRegistered then
        return true
    end

    if not LibStub then
        return false
    end

    local ldb = LibStub("LibDataBroker-1.1", true)
    local ldbi = LibStub("LibDBIcon-1.0", true)
    if not ldb or not ldbi then
        return false
    end

    local dataobj = ldb:NewDataObject(addon.name, {
        type = "launcher",
        text = addon.name,
        icon = addon.minimapIcon,
    })

    function dataobj.OnClick(_, mouseButton)
        if mouseButton == "LeftButton" then
            if addon.ToggleHistoryWindow then
                addon.ToggleHistoryWindow()
            end
        elseif mouseButton == "RightButton" then
            if addon.OpenSettingsPanel then
                addon.OpenSettingsPanel()
            end
        end
    end

    function dataobj.OnTooltipShow(tt)
        tt:AddLine("QuietShuffle")
        tt:AddLine("Left Click: Open History", 0.9, 0.9, 0.9)
        tt:AddLine("Right Click: Open Settings", 0.9, 0.9, 0.9)
    end

    QuietShuffleLDBIconDB = QuietShuffleLDBIconDB or {}
    ldbi:Register(addon.name, dataobj, QuietShuffleLDBIconDB)
    addon.minimapRegistered = true
    return true
end

local function GetMinimapSettings()
    addon.savedData = addon.savedData or {}
    addon.savedData.minimap = addon.savedData.minimap or { hide = false, angle = 225 }
    return addon.savedData.minimap
end

local function Atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end
    return math.atan(y, x)
end

addon.UpdateMinimapButtonPosition = function()
    if not addon.minimapButton or not Minimap then
        return
    end
    local settings = GetMinimapSettings()
    local angle = settings.angle or 225
    local radius = 80
    local x = math.cos(math.rad(angle)) * radius
    local y = math.sin(math.rad(angle)) * radius
    addon.minimapButton:ClearAllPoints()
    addon.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

addon.CreateMinimapButton = function()
    if addon.minimapButton or not Minimap then
        return
    end

    local settings = GetMinimapSettings()

    local button = CreateFrame("Button", "QuietShuffleMinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetSize(32, 32)

    button:SetNormalTexture(addon.minimapIcon or "Interface/Icons/INV_Misc_QuestionMark")
    local icon = button:GetNormalTexture()
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetSize(32, 32)
    icon:SetTexCoord(0, 1, 0, 1)

    button:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")

    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")
    border:SetSize(56, 56)
    border:SetPoint("CENTER")
    button.border = border

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            if addon.ToggleHistoryWindow then
                addon.ToggleHistoryWindow()
            end
        elseif mouseButton == "RightButton" then
            if addon.OpenSettingsPanel then
                addon.OpenSettingsPanel()
            end
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("QuietShuffle")
        GameTooltip:AddLine("Left Click: Open History", 1, 1, 1)
        GameTooltip:AddLine("Right Click: Open Settings", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(Atan2(cy - my, cx - mx))
            settings.angle = angle
            addon.UpdateMinimapButtonPosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        addon.UpdateMinimapButtonPosition()
    end)

    addon.minimapButton = button

    if settings.hide then
        button:Hide()
    else
        button:Show()
        addon.UpdateMinimapButtonPosition()
    end
end

-- Initialization message
addon.Print("v" .. addon.version .. ": Loaded! Type /qs for status.")
