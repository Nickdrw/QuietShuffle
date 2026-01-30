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

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Settings")

    local clearButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearButton:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
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

    local enableCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", clearButton, "BOTTOMLEFT", 0, -12)
    enableCheckbox.Text:SetText("Enable QuietShuffle")
    enableCheckbox:SetScript("OnClick", function(self)
        if addon.SetEnabled then
            addon.SetEnabled(self:GetChecked())
        end
    end)

    local minimapCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    minimapCheckbox:SetPoint("TOPLEFT", enableCheckbox, "BOTTOMLEFT", 0, -8)
    minimapCheckbox.Text:SetText("Show Minimap Button")
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

    -- Chat frame output settings
    local chatFrameLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    chatFrameLabel:SetPoint("TOPLEFT", minimapCheckbox, "BOTTOMLEFT", 0, -16)
    chatFrameLabel:SetText("Output Chat Tab Name:")

    local chatFrameInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    chatFrameInput:SetPoint("TOPLEFT", chatFrameLabel, "BOTTOMLEFT", 6, -4)
    chatFrameInput:SetSize(150, 22)
    chatFrameInput:SetAutoFocus(false)
    chatFrameInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText():trim()
        addon.savedData = addon.savedData or {}
        if text == "" then
            addon.savedData.outputChatFrame = nil
            addon.useDedicatedChatFrame = false
            addon.dedicatedChatFrame = nil
            addon.Print("Using default chat frame for output.")
        else
            addon.savedData.outputChatFrame = text
            addon.useDedicatedChatFrame = true
            addon.dedicatedChatFrame = nil  -- Force re-lookup
            local frame = addon.FindChatFrameByName(text)
            if frame then
                addon.Print("Using '" .. text .. "' chat tab for output.")
            else
                addon.Print("Chat tab '" .. text .. "' not found. Create it or check spelling.")
            end
        end
        self:ClearFocus()
    end)
    chatFrameInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local defaultButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    defaultButton:SetPoint("LEFT", chatFrameInput, "RIGHT", 8, 0)
    defaultButton:SetSize(70, 22)
    defaultButton:SetText("Default")
    defaultButton:SetScript("OnClick", function()
        chatFrameInput:SetText("General")
        chatFrameInput:GetScript("OnEnterPressed")(chatFrameInput)
    end)

    local clearChatFrameButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearChatFrameButton:SetPoint("LEFT", defaultButton, "RIGHT", 4, 0)
    clearChatFrameButton:SetSize(60, 22)
    clearChatFrameButton:SetText("Clear")
    clearChatFrameButton:SetScript("OnClick", function()
        chatFrameInput:SetText("")
        chatFrameInput:GetScript("OnEnterPressed")(chatFrameInput)
    end)

    local chatFrameHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    chatFrameHint:SetPoint("TOPLEFT", chatFrameInput, "BOTTOMLEFT", -6, -4)
    chatFrameHint:SetText("Leave empty for default chat. Press Enter to apply.")
    chatFrameHint:SetTextColor(0.6, 0.6, 0.6)

    -- Support section (anchored to bottom)
    local supportLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    supportLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 60)
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
    paypalButton:SetSize(160, 26)
    paypalButton:SetText("Buy me a coffee")
    paypalButton:SetScript("OnClick", function()
        -- PayPal link
        ShowURL("https://paypal.me/NickDrw", "PayPal - Buy me a coffee (Ctrl+C to copy)")
    end)

    -- Icon placeholder for PayPal (16x16 recommended)
    local paypalIcon = paypalButton:CreateTexture(nil, "ARTWORK")
    paypalIcon:SetSize(16, 16)
    paypalIcon:SetPoint("LEFT", paypalButton, "LEFT", 8, 0)
    -- paypalIcon:SetTexture("Interface\\AddOns\\QuietShuffle\\media\\paypal")  -- Uncomment when icon added
    paypalButton.icon = paypalIcon

    -- Patreon button
    local patreonButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    patreonButton:SetPoint("LEFT", paypalButton, "RIGHT", 12, 0)
    patreonButton:SetSize(180, 26)
    patreonButton:SetText("Support me on Patreon")
    patreonButton:SetScript("OnClick", function()
        -- Patreon link
        ShowURL("https://patreon.com/NickDrew", "Patreon - Support me (Ctrl+C to copy)")
    end)

    -- Icon placeholder for Patreon (16x16 recommended)
    local patreonIcon = patreonButton:CreateTexture(nil, "ARTWORK")
    patreonIcon:SetSize(16, 16)
    patreonIcon:SetPoint("LEFT", patreonButton, "LEFT", 8, 0)
    -- patreonIcon:SetTexture("Interface\\AddOns\\QuietShuffle\\media\\patreon")  -- Uncomment when icon added
    patreonButton.icon = patreonIcon

    -- Spread the Word button
    local spreadButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    spreadButton:SetPoint("LEFT", patreonButton, "RIGHT", 12, 0)
    spreadButton:SetSize(140, 26)
    spreadButton:SetText("Spread the word")
    spreadButton:SetScript("OnClick", function()
        -- Placeholder URL - replace with actual CurseForge link
        ShowURL("https://www.curseforge.com/wow/addons/PLACEHOLDER", "CurseForge - Share with friends! (Ctrl+C to copy)")
    end)

    -- Icon placeholder for CurseForge (16x16 recommended)
    local spreadIcon = spreadButton:CreateTexture(nil, "ARTWORK")
    spreadIcon:SetSize(16, 16)
    spreadIcon:SetPoint("LEFT", spreadButton, "LEFT", 8, 0)
    -- spreadIcon:SetTexture("Interface\\AddOns\\QuietShuffle\\media\\curseforge")  -- Uncomment when icon added
    spreadButton.icon = spreadIcon

    panel:HookScript("OnShow", function()
        if addon.IsEnabled then
            enableCheckbox:SetChecked(addon.IsEnabled())
        else
            enableCheckbox:SetChecked(true)
        end
        QuietShuffleLDBIconDB = QuietShuffleLDBIconDB or {}
        minimapCheckbox:SetChecked(not QuietShuffleLDBIconDB.hide)
        -- Load saved chat frame name
        addon.savedData = addon.savedData or {}
        chatFrameInput:SetText(addon.savedData.outputChatFrame or "")
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
