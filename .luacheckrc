-- Luacheck configuration for QuietShuffle WoW Addon

std = "lua51"
max_line_length = false
codes = true

-- Exclude external libraries
exclude_files = {
    "Libs/**",
}

-- Global variables we define
globals = {
    "QuietShuffleSavedData",
    "SLASH_QUIETSHUFFLE1",
    "SlashCmdList",
}

-- WoW API globals we read from
read_globals = {
    -- Lua globals
    "bit",
    "string", "table", "math", "pairs", "ipairs", "type", "tostring", "tonumber",
    "select", "unpack", "wipe", "date", "time", "pcall", "print", "format",
    "strsplit", "strmatch", "strfind", "strlen", "strsub", "strupper", "strlower",
    "tinsert", "tremove", "tContains", "CopyTable",
    "getmetatable", "setmetatable", "rawget", "rawset",
    
    -- WoW Frame API
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "GameFontNormal",
    "GameFontNormalLarge",
    "GameFontHighlight",
    "GameFontHighlightSmall",
    "ChatFontNormal",
    "Settings",
    "InterfaceOptionsFrame_OpenToCategory",
    "StaticPopupDialogs",
    "StaticPopup_Show",
    
    -- Chat Frame API
    "ChatFrame_AddMessageEventFilter",
    "ChatFrame_RemoveMessageEventFilter",
    "DEFAULT_CHAT_FRAME",
    "NUM_CHAT_WINDOWS",
    "FCF_GetCurrentChatFrame",
    
    -- C_* namespaces
    "C_PvP",
    "C_Timer",
    "C_Scenario",
    "C_ChatInfo",
    
    -- Event/Frame functions
    "GetBattlefieldStatus",
    "IsInInstance",
    "IsActiveBattlefieldArena",
    "GetNumGroupMembers",
    "IsInGroup",
    "IsInRaid",
    "UnitName",
    "UnitGUID",
    "UnitClass",
    "UnitExists",
    "GetRealmName",
    "GetPlayerInfoByGUID",
    "GetClassColor",
    "Ambiguate",
    
    -- Library globals
    "LibStub",
    
    -- Chat frame globals (ChatFrame1 through ChatFrame10)
    "ChatFrame1",
    "ChatFrame2",
    "ChatFrame3",
    "ChatFrame4",
    "ChatFrame5",
    "ChatFrame6",
    "ChatFrame7",
    "ChatFrame8",
    "ChatFrame9",
    "ChatFrame10",
    
    -- Misc
    "PlaySound",
    "SOUNDKIT",
    "GetAddOnMetadata",
    "RAID_CLASS_COLORS",
    "Enum",
    "LE_PARTY_CATEGORY_HOME",
    "LE_PARTY_CATEGORY_INSTANCE",
    "ACCEPT",
    "CANCEL",
}
