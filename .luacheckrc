-- Luacheck configuration for QuietShuffle WoW Addon

std = "lua51"
max_line_length = false
codes = true

-- Ignore whitespace warnings and unused self/level arguments (common in WoW callbacks)
ignore = {
    "211/_.*",  -- unused variables starting with _
    "211/FormatMessageCount",  -- reserved for future use
    "212/self", -- unused self argument
    "212/level", -- unused level argument (dropdown callbacks)
    "121/SetItemRef",  -- we override this global intentionally
    "611",      -- line contains only whitespace
    "612",      -- line contains trailing whitespace
    "614",      -- trailing whitespace in comment
}

-- Exclude external libraries
exclude_files = {
    "Libs/**",
}

-- Global variables we define
globals = {
    "QuietShuffleSavedData",
    "QuietShuffleLDBIconDB",
    "SLASH_QUIETSHUFFLE1",
    "SLASH_QUIETSHUFFLE2",
    "SlashCmdList",
    "SetItemRef",  -- we hook this
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
    "InterfaceOptions_AddCategory",
    "InterfaceOptionsFrame",
    "SettingsPanel",
    "HideUIPanel",
    "StaticPopupDialogs",
    "StaticPopup_Show",
    "StaticPopup_ShowCustomGenericConfirmation",
    "UISpecialFrames",
    "hooksecurefunc",
    
    -- Chat Frame API
    "ChatFrame_AddMessageEventFilter",
    "ChatFrame_RemoveMessageEventFilter",
    "DEFAULT_CHAT_FRAME",
    "NUM_CHAT_WINDOWS",
    "FCF_GetCurrentChatFrame",
    "FCF_OpenNewWindow",
    "FCFDock_GetChatFrames",
    "GENERAL_CHAT_DOCK",
    "DOCKED_CHAT_FRAMES",
    "ChatTypeInfo",
    "COMBAT_LOG",
    
    -- UIDropDownMenu API
    "UIDropDownMenu_Initialize",
    "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_AddButton",
    "UIDropDownMenu_SetWidth",
    "UIDropDownMenu_SetText",
    "UIDropDownMenu_SetSelectedValue",
    "UIDropDownMenu_JustifyText",
    
    -- C_* namespaces
    "C_PvP",
    "C_Timer",
    "C_Scenario",
    "C_ChatInfo",
    "C_CVar",
    "C_SocialRestrictions",
    "C_PlayerInfo",
    "C_ReportSystem",
    
    -- CVar functions
    "GetCVar",
    "SetCVar",
    
    -- Event/Frame functions
    "GetBattlefieldStatus",
    "IsInInstance",
    "IsActiveBattlefieldArena",
    "IsInScenario",
    "GetScenarioID",
    "GetNumGroupMembers",
    "IsInGroup",
    "IsInRaid",
    "UnitName",
    "UnitFullName",
    "UnitGUID",
    "UnitClass",
    "UnitExists",
    "GetRealmName",
    "GetRealZoneText",
    "GetPlayerInfoByGUID",
    "GetClassColor",
    "GetCursorPosition",
    "Ambiguate",
    "SetItemRef",
    "UnitPopup_ShowMenu",
    "SearchBoxTemplate_OnTextChanged",
    
    -- Player/Location
    "PlayerLocation",
    "ReportInfo",
    "ReportFrame",
    
    -- Library globals
    "LibStub",
    
    -- Minimap
    "Minimap",
    
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
