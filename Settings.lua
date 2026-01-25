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

    panel:HookScript("OnShow", function()
        if addon.IsEnabled then
            enableCheckbox:SetChecked(addon.IsEnabled())
        else
            enableCheckbox:SetChecked(true)
        end
        QuietShuffleLDBIconDB = QuietShuffleLDBIconDB or {}
        minimapCheckbox:SetChecked(not QuietShuffleLDBIconDB.hide)
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
