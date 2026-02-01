-- ============================================================================
-- QUIETSHUFFLE ADDON - Settings
-- ============================================================================

local _, addon = ...

local function ClearHistory()
    local history = addon.GetActiveHistory()
    for i = #history, 1, -1 do
        table.remove(history, i)
    end
    addon.Print("History cleared!")
    addon.selectedSessionIndex = nil
    if addon.PopulateSessionList then
        addon.PopulateSessionList()
    end
    if addon.ShowSessionMessages then
        addon.ShowSessionMessages(0)
    end
end

local function ConfirmClearHistory()
    local data = {
        text = "Clear all QuietShuffle history? This cannot be undone.",
        acceptText = ACCEPT,
        cancelText = CANCEL,
        callback = ClearHistory,
    }
    if StaticPopup_ShowCustomGenericConfirmation then
        StaticPopup_ShowCustomGenericConfirmation(data)
    else
        ClearHistory()
    end
end

local function CreateSettingsPanel()
    local panel = CreateFrame("Frame")

    if addon.historyBackground then
        local bgImage = panel:CreateTexture(nil, "BACKGROUND")
        bgImage:SetTexture(addon.historyBackground)
        bgImage:SetAlpha(0.25)
        bgImage:SetTexCoord(0, 1, 0, 1)
        bgImage:SetAllPoints(panel)
        panel.bgImage = bgImage
    end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("QuietShuffle")
    title:SetTextColor(1, 1, 1)

    local titleDivider = panel:CreateTexture(nil, "ARTWORK")
    titleDivider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    titleDivider:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    titleDivider:SetHeight(8)
    titleDivider:SetTexture("Interface\\COMMON\\UI-TooltipDivider-Transparent")

    -- Development notice
    local devNotice = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    devNotice:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -56)
    devNotice:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    devNotice:SetJustifyH("LEFT")
    devNotice:SetText("|cFFFFCC00This addon is in active development.|r Feedback and bug reports are welcome!")

    -- Links below notice
    local linksText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    linksText:SetPoint("TOPLEFT", devNotice, "BOTTOMLEFT", 0, -4)
    linksText:SetJustifyH("LEFT")
    linksText:SetText("|cFF88CCFFCurseForge:|r curseforge.com/wow/addons/quietshuffle  |  |cFF88CCFFGitHub:|r github.com/Nickdrw/QuietShuffle")

    local yOffset = -105

    -- Buttons section
    local clearButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, yOffset)
    clearButton:SetSize(140, 24)
    clearButton:SetText("Clear History")
    clearButton:SetScript("OnClick", ConfirmClearHistory)

    local showButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    showButton:SetPoint("LEFT", clearButton, "RIGHT", 12, 0)
    showButton:SetSize(140, 24)
    showButton:SetText("Show History")
    showButton:SetScript("OnClick", function()
        if addon.ShowHistoryWindow then
            addon.ShowHistoryWindow()
        end
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
            InterfaceOptionsFrame:Hide()
        end
    end)

    yOffset = yOffset - 40

    -- 4-column layout (label/control pairs)
    local col1X = 16
    local col2X = 260
    -- col3X and col4X reserved for future use

    -- Enable QuietShuffle
    local enableLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    enableLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", col1X, yOffset)
    enableLabel:SetText("Enable QuietShuffle")

    local enableCheckbox = CreateFrame("CheckButton", "QuietShuffle_EnableCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", panel, "TOPLEFT", col2X, yOffset + 2)
    enableCheckbox:SetScript("OnClick", function(self)
        if addon.SetEnabled then
            addon.SetEnabled(self:GetChecked())
        end
    end)

    yOffset = yOffset - 42

    -- Show Minimap Button
    local minimapLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    minimapLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", col1X, yOffset)
    minimapLabel:SetText("Show Minimap Button")

    local minimapCheckbox = CreateFrame("CheckButton", "QuietShuffle_MinimapCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    minimapCheckbox:SetPoint("TOPLEFT", panel, "TOPLEFT", col2X, yOffset + 2)
    minimapCheckbox:SetScript("OnClick", function(self)
        QuietShuffleLDBIconDB = QuietShuffleLDBIconDB or {}
        QuietShuffleLDBIconDB.hide = not self:GetChecked()
        local icon = LibStub and LibStub("LibDBIcon-1.0", true)
        if icon then
            if QuietShuffleLDBIconDB.hide then
                icon:Hide(addon.name)
            else
                icon:Show(addon.name)
            end
        elseif addon.minimapButton then
            if QuietShuffleLDBIconDB.hide then
                addon.minimapButton:Hide()
            else
                addon.minimapButton:Show()
            end
        end
    end)

    yOffset = yOffset - 42

    -- Output Chat Tab
    local chatFrameLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    chatFrameLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", col1X, yOffset)
    chatFrameLabel:SetText("Output Chat Tab")

    local chatFrameDropdown = CreateFrame("Frame", "QuietShuffle_ChatTabDropdown", panel, "UIDropDownMenuTemplate")
    chatFrameDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", col2X - 16, yOffset)

    local function GetDefaultChatTabName()
        local tab = _G["ChatFrame1Tab"]
        local name = tab and tab:GetText()
        if name and name ~= "" then
            return name
        end
        return "General"
    end

    local function ApplyChatFrameSelection(tabName)
        addon.savedData = addon.savedData or {}
        if not tabName or tabName == "" then
            addon.savedData.outputChatFrame = nil
            addon.useDedicatedChatFrame = false
            addon.dedicatedChatFrame = nil
            addon.Print("Using default chat frame for output.")
        else
            local frame = addon.FindChatFrameByName(tabName)
            if frame then
                addon.savedData.outputChatFrame = tabName
                addon.useDedicatedChatFrame = true
                addon.dedicatedChatFrame = nil
                addon.Print("Using '" .. tabName .. "' chat tab for output.")
            else
                addon.savedData.outputChatFrame = nil
                addon.useDedicatedChatFrame = false
                addon.dedicatedChatFrame = nil
                addon.Print("Chat tab '" .. tabName .. "' not found. Reverting to General tab.")
            end
        end
        if addon.RefreshChatFrameDropdown then
            addon.RefreshChatFrameDropdown()
        end
    end

    local function InitializeChatFrameDropdown()
        local defaultName = GetDefaultChatTabName()
        local function GetAllVisibleChatFrames()
            local frames = {}
            local dockedSet = {}

            if type(FCFDock_GetChatFrames) == "function" and GENERAL_CHAT_DOCK then
                local dockedFrames = FCFDock_GetChatFrames(GENERAL_CHAT_DOCK)
                if dockedFrames then
                    for _, frame in ipairs(dockedFrames) do
                        table.insert(frames, frame)
                        dockedSet[frame] = true
                    end
                end
            elseif type(DOCKED_CHAT_FRAMES) == "table" then
                for _, frameName in ipairs(DOCKED_CHAT_FRAMES) do
                    local frame = _G[frameName]
                    if frame then
                        table.insert(frames, frame)
                        dockedSet[frame] = true
                    end
                end
            end

            for i = 1, NUM_CHAT_WINDOWS do
                local frame = _G["ChatFrame" .. i]
                if frame and frame:IsShown() and not dockedSet[frame] then
                    table.insert(frames, frame)
                end
            end

            return frames
        end

        UIDropDownMenu_Initialize(chatFrameDropdown, function(self, level)
            local info = UIDropDownMenu_CreateInfo()
            info.text = defaultName
            info.value = nil
            info.func = function()
                ApplyChatFrameSelection(nil)
            end
            info.checked = not addon.savedData.outputChatFrame
            UIDropDownMenu_AddButton(info, level)

            local allFrames = GetAllVisibleChatFrames()
            for _, frame in ipairs(allFrames) do
                local tab = _G[frame:GetName() .. "Tab"]
                if tab and tab:IsShown() then
                    local tabName = tab:GetText()
                    if tabName and tabName ~= "" and tabName ~= defaultName and tabName ~= COMBAT_LOG and tabName ~= "Combat Log" then
                        info = UIDropDownMenu_CreateInfo()
                        info.text = tabName
                        info.value = tabName
                        info.func = function()
                            ApplyChatFrameSelection(tabName)
                        end
                        info.checked = (addon.savedData.outputChatFrame == tabName)
                        UIDropDownMenu_AddButton(info, level)
                    end
                end
            end
        end)
    end

    addon.RefreshChatFrameDropdown = function()
        if not chatFrameDropdown then
            return
        end
        local defaultName = GetDefaultChatTabName()
        
        -- Build list of currently visible tabs
        local validTabs = {}
        validTabs[defaultName] = true
        
        local function GetAllVisibleChatFrames()
            local frames = {}
            local dockedSet = {}
            if type(FCFDock_GetChatFrames) == "function" and GENERAL_CHAT_DOCK then
                local dockedFrames = FCFDock_GetChatFrames(GENERAL_CHAT_DOCK)
                if dockedFrames then
                    for _, frame in ipairs(dockedFrames) do
                        table.insert(frames, frame)
                        dockedSet[frame] = true
                    end
                end
            elseif type(DOCKED_CHAT_FRAMES) == "table" then
                for _, frameName in ipairs(DOCKED_CHAT_FRAMES) do
                    local frame = _G[frameName]
                    if frame then
                        table.insert(frames, frame)
                        dockedSet[frame] = true
                    end
                end
            end
            for i = 1, NUM_CHAT_WINDOWS do
                local frame = _G["ChatFrame" .. i]
                if frame and frame:IsShown() and not dockedSet[frame] then
                    table.insert(frames, frame)
                end
            end
            return frames
        end
        
        -- Collect valid tab names
        local allFrames = GetAllVisibleChatFrames()
        for _, frame in ipairs(allFrames) do
            local tab = _G[frame:GetName() .. "Tab"]
            if tab and tab:IsShown() then
                local tabName = tab:GetText()
                if tabName and tabName ~= "" and tabName ~= COMBAT_LOG and tabName ~= "Combat Log" then
                    validTabs[tabName] = true
                end
            end
        end
        
        -- Check if saved selection is still valid
        local selected = addon.savedData and addon.savedData.outputChatFrame or nil
        if selected and not validTabs[selected] then
            -- Selected tab no longer exists, reset
            addon.savedData.outputChatFrame = nil
            addon.useDedicatedChatFrame = false
            addon.dedicatedChatFrame = nil
            selected = nil
        end
        
        -- Display General if no valid selection
        UIDropDownMenu_SetText(chatFrameDropdown, selected or defaultName)
        InitializeChatFrameDropdown()
    end

    addon.chatFrameDropdown = chatFrameDropdown
    UIDropDownMenu_SetWidth(chatFrameDropdown, 170)
    addon.RefreshChatFrameDropdown()

    -- Support section (anchored to bottom)
    local supportLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    supportLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 90)
    supportLabel:SetText("Support the Developer")

    -- URL display popup frame (shared between buttons)
    local urlPopup = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    urlPopup:SetSize(400, 80)
    urlPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    urlPopup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    urlPopup:SetFrameStrata("DIALOG")
    urlPopup:EnableMouse(true)
    urlPopup:Hide()

    local urlPopupTitle = urlPopup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    urlPopupTitle:SetPoint("TOP", urlPopup, "TOP", 0, -16)
    urlPopupTitle:SetText("Copy this URL (Ctrl+C)")

    local urlEditBox = CreateFrame("EditBox", nil, urlPopup, "InputBoxTemplate")
    urlEditBox:SetPoint("TOP", urlPopupTitle, "BOTTOM", 0, -8)
    urlEditBox:SetSize(360, 22)
    urlEditBox:SetAutoFocus(false)
    urlEditBox:SetScript("OnEscapePressed", function(self)
        urlPopup:Hide()
    end)
    urlEditBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    local urlCloseButton = CreateFrame("Button", nil, urlPopup, "UIPanelButtonTemplate")
    urlCloseButton:SetPoint("TOP", urlEditBox, "BOTTOM", 0, -8)
    urlCloseButton:SetSize(80, 22)
    urlCloseButton:SetText("Close")
    urlCloseButton:SetScript("OnClick", function()
        urlPopup:Hide()
    end)

    local function ShowURL(url, titleText)
        urlPopupTitle:SetText(titleText or "Copy this URL (Ctrl+C)")
        urlEditBox:SetText(url)
        urlPopup:Show()
        urlEditBox:SetFocus()
        urlEditBox:HighlightText()
    end

    -- PayPal button
    local paypalButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    paypalButton:SetPoint("TOPLEFT", supportLabel, "BOTTOMLEFT", 0, -8)
    paypalButton:SetSize(180, 26)
    paypalButton:SetText("Buy me a coffee")
    paypalButton:SetScript("OnClick", function()
        -- PayPal link
        ShowURL("https://paypal.me/NickDrw", "PayPal - Buy me a coffee (Ctrl+C to copy)")
    end)

    local paypalIcon = paypalButton:CreateTexture(nil, "ARTWORK")
    paypalIcon:SetSize(16, 16)
    paypalIcon:SetPoint("LEFT", paypalButton, "LEFT", 8, 0)
    paypalIcon:SetTexture("Interface\\AddOns\\QuietShuffle\\media\\paypal")
    paypalButton.Text:SetPoint("CENTER", paypalButton, "CENTER", 8, 0)

    -- Patreon button
    local patreonButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    patreonButton:SetPoint("LEFT", paypalButton, "RIGHT", 12, 0)
    patreonButton:SetSize(180, 26)
    patreonButton:SetText("Support me on Patreon")
    patreonButton:SetScript("OnClick", function()
        -- Patreon link
        ShowURL("https://patreon.com/NickDrew", "Patreon - Support me (Ctrl+C to copy)")
    end)

    local patreonIcon = patreonButton:CreateTexture(nil, "ARTWORK")
    patreonIcon:SetSize(16, 16)
    patreonIcon:SetPoint("LEFT", patreonButton, "LEFT", 8, 0)
    patreonIcon:SetTexture("Interface\\AddOns\\QuietShuffle\\media\\patreon")
    patreonButton.Text:SetPoint("CENTER", patreonButton, "CENTER", 8, 0)

    -- Spread the Word button
    local spreadButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    spreadButton:SetPoint("LEFT", patreonButton, "RIGHT", 12, 0)
    spreadButton:SetSize(180, 26)
    spreadButton:SetText("View on CurseForge")
    spreadButton:SetScript("OnClick", function()
        ShowURL("https://www.curseforge.com/wow/addons/quietshuffle", "CurseForge - Share with friends! (Ctrl+C to copy)")
    end)

    local curseforgeIcon = spreadButton:CreateTexture(nil, "ARTWORK")
    curseforgeIcon:SetSize(16, 16)
    curseforgeIcon:SetPoint("LEFT", spreadButton, "LEFT", 8, 0)
    curseforgeIcon:SetTexture("Interface\\AddOns\\QuietShuffle\\media\\curseforge")
    spreadButton.Text:SetPoint("CENTER", spreadButton, "CENTER", 8, 0)

    -- GitHub button
    local githubButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    githubButton:SetPoint("TOPLEFT", paypalButton, "BOTTOMLEFT", 0, -8)
    githubButton:SetSize(180, 26)
    githubButton:SetText("Project on GitHub")
    githubButton:SetScript("OnClick", function()
        ShowURL("https://github.com/Nickdrw/QuietShuffle", "GitHub - Project page (Ctrl+C to copy)")
    end)

    local githubIcon = githubButton:CreateTexture(nil, "ARTWORK")
    githubIcon:SetSize(16, 16)
    githubIcon:SetPoint("LEFT", githubButton, "LEFT", 8, 0)
    githubIcon:SetTexture("Interface\\AddOns\\QuietShuffle\\media\\github")
    githubButton.Text:SetPoint("CENTER", githubButton, "CENTER", 8, 0)

    panel:HookScript("OnShow", function()
        if addon.IsEnabled then
            enableCheckbox:SetChecked(addon.IsEnabled())
        else
            enableCheckbox:SetChecked(true)
        end
        QuietShuffleLDBIconDB = QuietShuffleLDBIconDB or {}
        minimapCheckbox:SetChecked(not QuietShuffleLDBIconDB.hide)
        -- Validate and refresh chat frame selection
        addon.savedData = addon.savedData or {}
        if addon.ValidateChatFrameSelection then
            addon.ValidateChatFrameSelection()
        end
        if addon.RefreshChatFrameDropdown then
            addon.RefreshChatFrameDropdown()
        end
    end)

    return panel
end

local function RegisterSettingsPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local panel = CreateSettingsPanel()
        local category = Settings.RegisterCanvasLayoutCategory(panel, addon.name)
        Settings.RegisterAddOnCategory(category)
        addon.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        local panel = CreateSettingsPanel()
        panel.name = addon.name
        InterfaceOptions_AddCategory(panel)
        addon.settingsCategory = panel
    end
end

RegisterSettingsPanel()
