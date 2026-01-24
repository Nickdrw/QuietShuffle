-- ============================================================================
-- QUIETSHUFFLE ADDON - UI & History
-- ============================================================================

local _, addon = ...

-- Print stored messages (link to history)
addon.PrintStoredMessages = function()
    if next(addon.messages) == nil then
        print("|cFFFFFF00" .. addon.name .. "|r: No messages stored.")
        return
    end
    print("|cFFFFFF00" .. addon.name .. "|r: " .. "|Hquietshuffle:history|h|cFF00FF00[View Message History]|r|h")
end

-- Build or reuse a row for message display
local function ShowPlayerDropdown(name)
    if not name then
        return
    end
    if SetItemRef then
        SetItemRef("player:" .. name, name, "RightButton")
        return
    end
    if UnitPopup_ShowMenu then
        if not addon.playerDropdown then
            addon.playerDropdown = CreateFrame("Frame", "QuietShufflePlayerDropdown", UIParent, "UIDropDownMenuTemplate")
        end
        UnitPopup_ShowMenu(addon.playerDropdown, "PLAYER", nil, name)
    end
end

local function GetOrCreateMessageRow(index)
    local row = addon.messageRows[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, addon.historyMessageContentFrame)
    row:SetSize(addon.historyMessageContentFrame:GetWidth(), 26)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row.text:SetWidth(addon.historyMessageContentFrame:GetWidth())

    row.prefixText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.prefixText:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.prefixText:SetJustifyH("LEFT")
    row.prefixText:SetWordWrap(false)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.messageText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.messageText:SetJustifyH("LEFT")
    row.messageText:SetWordWrap(true)

    row.nameButton = CreateFrame("Button", nil, row)
    row.nameButton:EnableMouse(true)
    row.nameButton:RegisterForClicks("RightButtonUp")
    row.nameButton:SetFrameLevel(row:GetFrameLevel() + 2)
    row.nameButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" and row.msgData and row.msgData.sender then
            ShowPlayerDropdown(row.msgData.sender)
        end
    end)

    row:SetScript("OnSizeChanged", function(self, width)
        if self.text then
            self.text:SetWidth(width)
        end
        if self.messageText then
            if self.isFiltered then
                self.messageText:SetWidth((self.messageText:GetStringWidth() or 0) + 2)
            else
                local prefixW = self.prefixText and self.prefixText:GetStringWidth() or 0
                local nameW = self.nameText and self.nameText:GetStringWidth() or 0
                local available = math.max(10, width - (prefixW + nameW))
                self.messageText:SetWidth(available)
            end
        end
    end)

    addon.messageRows[index] = row
    return row
end

-- Helper function to format a single message in chat style
local function FormatChatMessageParts(msgData)
    local sender = msgData.sender or "Unknown"
    local channel = msgData.channel or "Unknown"
    local message = msgData.message or ""
    local timestamp = msgData.timestamp or 0
    local playerClass = msgData.class

    if (not playerClass or not RAID_CLASS_COLORS[playerClass]) and msgData.guid and addon.ResolveClassFromGUID then
        playerClass = addon.ResolveClassFromGUID(msgData.guid)
    end

    local timeStr = date("%H:%M:%S", math.floor(timestamp))

    local classHex = "FFFFFF"
    if playerClass then
        local r, g, b = GetClassColor(playerClass)
        if r and g and b then
            classHex = string.format("%02X%02X%02X", r * 255, g * 255, b * 255)
        end
    end

    local channelHex = "FFFFFF"
    local channelLabel = "[" .. channel .. "]"

    if channel == "CHAT_MSG_WHISPER" then
        channelHex = "FF80FF"
        channelLabel = "[From]"
    elseif channel == "CHAT_MSG_WHISPER_INFORM" then
        channelHex = "FF80FF"
        channelLabel = "[To]"
    elseif channel == "CHAT_MSG_PARTY" or channel == "CHAT_MSG_PARTY_LEADER" or channel == "CHAT_MSG_PARTY_GUIDE" then
        channelHex = "9D9FFF"
        channelLabel = "[Party]"
    elseif channel == "CHAT_MSG_INSTANCE_CHAT" or channel == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
        channelHex = "FFA335"
        channelLabel = "[Instance]"
    elseif channel == "CHAT_MSG_SAY" then
        local c = ChatTypeInfo and ChatTypeInfo.SAY
        if c then
            channelHex = string.format("%02X%02X%02X", c.r * 255, c.g * 255, c.b * 255)
        end
        channelLabel = "[Says]"
    elseif channel == "CHAT_MSG_YELL" then
        local c = ChatTypeInfo and ChatTypeInfo.YELL
        if c then
            channelHex = string.format("%02X%02X%02X", c.r * 255, c.g * 255, c.b * 255)
        end
        channelLabel = "[Yells]"
    end

    return {
        prefix = string.format("|cFF%s%s|r |cFF%s%s|r ", channelHex, timeStr, channelHex, channelLabel),
        name = string.format("|cFF%s[%s]|r", classHex, sender),
        message = message
    }
end

local function OpenReportForPlayer(name, guid, lineID)
    if not name or name == "" then
        return
    end
    local playerLocation = nil
    if lineID and PlayerLocation and PlayerLocation.CreateFromChatLineID then
        playerLocation = PlayerLocation:CreateFromChatLineID(lineID)
    elseif guid and PlayerLocation and PlayerLocation.CreateFromGUID then
        playerLocation = PlayerLocation:CreateFromGUID(guid)
    end
    if ReportInfo and ReportFrame and Enum and Enum.ReportType then
        local isChatLine = playerLocation and playerLocation.IsChatLineID and playerLocation:IsChatLineID()
        local reportType = isChatLine and Enum.ReportType.Chat or Enum.ReportType.InWorld
        if not reportType then
            reportType = Enum.ReportType.InWorld
        end
        local reportInfo = ReportInfo:CreateReportInfoFromType(reportType)
        if reportInfo then
            if guid and reportInfo.SetReportTarget then
                reportInfo:SetReportTarget(guid)
            end
            if reportType == Enum.ReportType.Chat and isChatLine and reportInfo.SetReportedChatInline then
                reportInfo:SetReportedChatInline()
            end
            ReportFrame:InitiateReport(reportInfo, name, playerLocation)
            return
        end
    end
    if C_ReportSystem and C_ReportSystem.OpenReportPlayerDialog then
        local isChatLine = playerLocation and playerLocation.IsChatLineID and playerLocation:IsChatLineID()
        local reportType = (Enum and Enum.ReportType and (isChatLine and Enum.ReportType.Chat or Enum.ReportType.InWorld)) or nil
        if reportType then
            C_ReportSystem.OpenReportPlayerDialog(reportType, name, playerLocation)
        else
            C_ReportSystem.OpenReportPlayerDialog(name)
        end
        return
    end
    if SetItemRef then
        SetItemRef("player:" .. name, name, "RightButton")
    end
end

local function UpdateReportButtons(messageList)
    if not addon.reportPanel or not addon.reportListPanel or not addon.reportToggleButton then
        return
    end

    local function UpdateReportLayout()
        if not addon.reportListPanel then
            return
        end
        if addon.reportListOpen then
            addon.reportListPanel:Show()
        else
            addon.reportListPanel:Hide()
        end
    end

    for i = 1, #addon.reportListButtons do
        addon.reportListButtons[i]:Hide()
    end
    addon.reportListButtons = {}

    if not messageList or #messageList == 0 then
        addon.reportListOpen = false
        addon.reportListPanel:Hide()
        addon.reportToggleButton:SetEnabled(false)
        UpdateReportLayout()
        return
    end

    local players = {}
    local order = {}
    local selfName = UnitName("player")
    for _, msgData in ipairs(messageList) do
        local sender = msgData.sender
        if sender and sender ~= "" and sender ~= selfName and not players[sender] then
            players[sender] = { name = sender, guid = msgData.guid, lineID = msgData.lineID }
            table.insert(order, sender)
        end
    end

    if #order == 0 then
        addon.reportListOpen = false
        addon.reportListPanel:Hide()
        addon.reportToggleButton:SetEnabled(false)
        UpdateReportLayout()
        return
    end

    table.sort(order)

    addon.reportToggleButton:SetEnabled(true)

    local padding = 8
    local topOffset = 28
    local y = -(padding + topOffset)
    local buttonHeight = 22

    for _, sender in ipairs(order) do
        local entry = players[sender]
        local button = CreateFrame("Button", nil, addon.reportListPanel, "UIPanelButtonTemplate")
        button:SetText(sender)
        button:SetHeight(buttonHeight)
        button:SetPoint("TOPLEFT", addon.reportListPanel, "TOPLEFT", padding, y)
        button:SetPoint("TOPRIGHT", addon.reportListPanel, "TOPRIGHT", -padding, y)
        button:SetScript("OnClick", function()
            OpenReportForPlayer(entry.name, entry.guid, entry.lineID)
        end)

        table.insert(addon.reportListButtons, button)
        y = y - (buttonHeight + padding)
    end

    UpdateReportLayout()
end

addon.ShowSessionMessages = function(sessionIndex)
    addon.selectedSessionIndex = sessionIndex
    local history = addon.GetActiveHistory()
    local reportMessages = nil

    local rowIndex = 0
    local yOffset = 0

    local function AddRow(text, msgData)
        rowIndex = rowIndex + 1
        local row = GetOrCreateMessageRow(rowIndex)
        row:Show()
        row.msgData = msgData
        row.isFiltered = false
        row:SetWidth(addon.historyMessageContentFrame:GetWidth())
        local rowHeight = 24
        if msgData then
            local parts = FormatChatMessageParts(msgData)
            row.text:Hide()
            row.prefixText:Show()
            row.nameText:Show()
            row.messageText:Show()

            row.prefixText:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            row.prefixText:SetText(parts.prefix)

            row.nameText:SetPoint("TOPLEFT", row.prefixText, "TOPRIGHT", 0, 0)
            row.nameText:SetText(parts.name)

            local rawMessage = parts.message or ""
            local hasFilterLink = rawMessage:match("|H.-|h.-|h")

            local prefixW = row.prefixText:GetStringWidth() or 0
            local nameW = row.nameText:GetStringWidth() or 0

            if hasFilterLink then
                row.isFiltered = true
                row.messageText:SetPoint("TOPLEFT", row.nameText, "TOPRIGHT", 0, 0)
                row.messageText:SetWordWrap(false)
                row.messageText:SetText(": |cFFFFFF00Message filtered by Blizzard censure.|r")
                row.messageText:SetWidth((row.messageText:GetStringWidth() or 0) + 2)
            else
                row.isFiltered = false
                row.messageText:SetPoint("TOPLEFT", row.nameText, "TOPRIGHT", 0, 0)
                row.messageText:SetWordWrap(true)
                row.messageText:SetText(": " .. rawMessage)
                local available = math.max(10, row:GetWidth() - (prefixW + nameW))
                row.messageText:SetWidth(available)
            end

            local nameH = row.nameText:GetStringHeight() or 14
            row.nameButton:Show()
            row.nameButton:SetPoint("TOPLEFT", row.nameText, "TOPLEFT", 0, 0)
            row.nameButton:SetSize(nameW + 4, nameH + 4)

            local textHeight = row.messageText:GetStringHeight() or 0
            rowHeight = math.max(24, textHeight + 6)
            row:SetHeight(rowHeight)
        else
            row.prefixText:Hide()
            row.nameText:Hide()
            row.messageText:Hide()
            row.nameButton:Hide()
            row.text:Show()
            row.text:SetText(text)

            local textHeight = row.text:GetStringHeight() or 0
            rowHeight = math.max(24, textHeight + 6)
            row:SetHeight(rowHeight)
        end
        row:SetPoint("TOPLEFT", addon.historyMessageContentFrame, "TOPLEFT", 0, -yOffset)
        yOffset = yOffset + rowHeight + 2
    end

    if sessionIndex == 0 then
        if not addon.inSoloShuffle and history and #history > 0 then
            AddRow("Select a session to view its messages.")
            UpdateReportButtons(nil)
            return
        end
        if addon.messages and next(addon.messages) then
            AddRow("|cFFFFFF00=== Current Session ===|r")
            for _, msgData in ipairs(addon.messages) do
                AddRow(nil, msgData)
            end
            reportMessages = addon.messages
        else
            if addon.inSoloShuffle then
                AddRow("No message in current session.")
            else
                AddRow("No message for this character.")
            end
        end
    else
        local session = history[sessionIndex]
        if session and session.messages and #session.messages > 0 then
            for _, msgData in ipairs(session.messages) do
                AddRow(nil, msgData)
            end
            reportMessages = session.messages
        else
            AddRow("No message in this session.")
        end
    end

    for i = rowIndex + 1, #addon.messageRows do
        if addon.messageRows[i] then
            addon.messageRows[i]:Hide()
            addon.messageRows[i].msgData = nil
        end
    end

    addon.historyMessageContentFrame:SetHeight(math.max(400, yOffset))
    addon.lastReportMessages = reportMessages
    UpdateReportButtons(reportMessages)
end

local function FormatMessageCount(count)
    if count == 1 then
        return count .. " message"
    else
        return count .. " messages"
    end
end

addon.PopulateSessionList = function()
    for i = 1, #addon.sessionButtons do
        addon.sessionButtons[i]:Hide()
    end
    addon.sessionButtons = {}

    local yOffset = 0
    local sessionCount = 0
    local messageCount = 0

    if addon.inSoloShuffle then
        sessionCount = sessionCount + 1
        messageCount = 0
        if addon.messages then
            for _ in ipairs(addon.messages) do
                messageCount = messageCount + 1
            end
        end

        local currentZoneName = GetRealZoneText() or "Current Session"
        local button = CreateFrame("Button", nil, addon.historySessionContentFrame, "BackdropTemplate")
        button:SetSize(220, 28)
        button:SetPoint("TOPLEFT", addon.historySessionContentFrame, "TOPLEFT", 5, yOffset)

        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        button:SetBackdropColor(0.15, 0.15, 0.2, 0.8)
        button:SetBackdropBorderColor(0.3, 0.3, 0.4, 0.8)

        local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        buttonText:SetPoint("LEFT", button, "LEFT", 8, 0)
        buttonText:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        buttonText:SetJustifyH("LEFT")
        buttonText:SetWordWrap(false)
        buttonText:SetText(string.format("|cFF40FF40● |r|cFFFFFFFF[Current] %s|r", FormatMessageCount(messageCount)))

        button:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.25, 0.25, 0.35, 1)
            buttonText:SetText(string.format("|cFF40FF40● |r|cFFFFD700[Current] %s|r", FormatMessageCount(messageCount)))
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(currentZoneName)
            end
        end)
        button:SetScript("OnLeave", function(self)
            if addon.selectedSessionIndex == 0 then
                self:SetBackdropColor(0.2, 0.35, 0.5, 0.9)
                buttonText:SetText(string.format("|cFF40FF40● |r|cFFFFD700[Current] %s|r", FormatMessageCount(messageCount)))
            else
                self:SetBackdropColor(0.15, 0.15, 0.2, 0.8)
                buttonText:SetText(string.format("|cFF40FF40● |r|cFFFFFFFF[Current] %s|r", FormatMessageCount(messageCount)))
            end
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)

        button:SetScript("OnClick", function()
            addon.ShowSessionMessages(0)
            addon.PopulateSessionList()
        end)

        if addon.selectedSessionIndex == 0 then
            button:SetBackdropColor(0.2, 0.35, 0.5, 0.9)
            buttonText:SetText(string.format("|cFF40FF40● |r|cFFFFD700[Current] %s|r", FormatMessageCount(messageCount)))
        end

        table.insert(addon.sessionButtons, button)
        yOffset = yOffset - 32
    end

    local history = addon.GetActiveHistory()
    for i = #history, 1, -1 do
        sessionCount = sessionCount + 1
        local session = history[i]
        local sessionIndex = i

        local startTime = session.startTime or session.timestamp
        local endTime = session.endTime or session.timestamp
        local dateStr = date("%d/%m/%y", startTime)
        local startTimeStr = date("%H:%M", startTime)
        local endTimeStr = date("%H:%M", endTime)
        local zoneName = session.zone or "Unknown"
        local zoneInitial = ""
        for word in zoneName:gmatch("%S+") do
            zoneInitial = zoneInitial .. word:sub(1, 1)
        end
        if zoneInitial == "" then
            zoneInitial = "?"
        end
        local sessionLabel = string.format("%s %s-%s - %s (%d)", dateStr, startTimeStr, endTimeStr, zoneInitial, session.message_count)

        local button = CreateFrame("Button", nil, addon.historySessionContentFrame, "BackdropTemplate")
        button:SetSize(220, 28)
        button:SetPoint("TOPLEFT", addon.historySessionContentFrame, "TOPLEFT", 5, yOffset)

        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        button:SetBackdropColor(0.15, 0.15, 0.2, 0.8)
        button:SetBackdropBorderColor(0.3, 0.3, 0.4, 0.8)

        local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        buttonText:SetPoint("LEFT", button, "LEFT", 8, 0)
        buttonText:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        buttonText:SetJustifyH("LEFT")
        buttonText:SetWordWrap(false)
        buttonText:SetText(sessionLabel)

        button:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.25, 0.25, 0.35, 1)
            buttonText:SetText(string.format("|cFFFFD700%s|r", sessionLabel))
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local duration = endTime - startTime
                local minutes = math.floor(duration / 60)
                local seconds = duration % 60
                GameTooltip:SetText(string.format("%s (%d:%02d)", zoneName, minutes, seconds))
            end
        end)
        button:SetScript("OnLeave", function(self)
            if addon.selectedSessionIndex == sessionIndex then
                self:SetBackdropColor(0.2, 0.35, 0.5, 0.9)
                buttonText:SetText(string.format("|cFFFFD700%s|r", sessionLabel))
            else
                self:SetBackdropColor(0.15, 0.15, 0.2, 0.8)
                buttonText:SetText(sessionLabel)
            end
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)

        button:SetScript("OnClick", function()
            addon.ShowSessionMessages(sessionIndex)
            addon.PopulateSessionList()
        end)

        if addon.selectedSessionIndex == sessionIndex then
            button:SetBackdropColor(0.2, 0.35, 0.5, 0.9)
            buttonText:SetText(string.format("|cFFFFD700%s|r", sessionLabel))
        end

        table.insert(addon.sessionButtons, button)
        yOffset = yOffset - 32
    end

    addon.historySessionContentFrame:SetHeight(math.max(30, sessionCount * 32))
end

addon.CreateHistoryWindow = function()
    if addon.historyFrame then
        addon.historyFrame:Show()
        return
    end

    local frame = CreateFrame("Frame", "QuietShuffleHistoryFrame", UIParent, "BasicFrameTemplate")
    frame:SetSize(900, 450)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -5)
    title:SetText("|cFFFFD700QuietShuffle|r |cFFCCCCCC- Solo Shuffle History|r")

    local sessionPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sessionPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
    sessionPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 260, 40)
    sessionPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    sessionPanel:SetBackdropColor(0.1, 0.1, 0.15, 0.9)
    sessionPanel:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)

    local sessionScrollFrame = CreateFrame("ScrollFrame", "QuietShuffleSessionScroll", sessionPanel, "UIPanelScrollFrameTemplate")
    sessionScrollFrame:SetPoint("TOPLEFT", sessionPanel, "TOPLEFT", 5, -5)
    sessionScrollFrame:SetPoint("BOTTOMRIGHT", sessionPanel, "BOTTOMRIGHT", -25, 5)

    local sessionContentFrame = CreateFrame("Frame", nil, sessionScrollFrame)
    sessionContentFrame:SetWidth(210)
    sessionScrollFrame:SetScrollChild(sessionContentFrame)

    local listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -38)
    listLabel:SetText("|cFFFFD700Sessions|r")

    local characterDropdown = CreateFrame("Frame", "QuietShuffleCharacterDropdown", frame, "UIDropDownMenuTemplate")
    characterDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", -5, -10)
    UIDropDownMenu_SetWidth(characterDropdown, 210)
    UIDropDownMenu_JustifyText(characterDropdown, "LEFT")

    local separator = frame:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.6, 0.6, 0.7, 0.8)
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", sessionPanel, "TOPRIGHT", 15, 0)
    separator:SetPoint("BOTTOMLEFT", sessionPanel, "BOTTOMRIGHT", 15, 0)

    local messagePanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    messagePanel:SetPoint("TOPLEFT", separator, "TOPRIGHT", 15, 0)
    messagePanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 70)
    messagePanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    messagePanel:SetBackdropColor(0.1, 0.1, 0.15, 0.9)
    messagePanel:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)

    local msgLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgLabel:SetPoint("TOPLEFT", messagePanel, "TOPLEFT", 5, 22)
    msgLabel:SetText("|cFFFFD700Messages|r")

    local messageScrollFrame = CreateFrame("ScrollFrame", "QuietShuffleMessageScroll", messagePanel, "UIPanelScrollFrameTemplate")
    messageScrollFrame:SetPoint("TOPLEFT", messagePanel, "TOPLEFT", 5, -5)
    messageScrollFrame:SetPoint("BOTTOMRIGHT", messagePanel, "BOTTOMRIGHT", -25, 5)

    local messageContentFrame = CreateFrame("Frame", nil, messageScrollFrame)
    messageContentFrame:SetWidth(messageScrollFrame:GetWidth() - 30)
    messageContentFrame:SetHeight(400)
    messageScrollFrame:SetScrollChild(messageContentFrame)

    -- Report buttons panel (below messages)
    local reportPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    reportPanel:SetPoint("TOPLEFT", messagePanel, "BOTTOMLEFT", 0, -8)
    reportPanel:SetPoint("BOTTOMRIGHT", messagePanel, "BOTTOMRIGHT", 0, -40)
    reportPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    reportPanel:SetBackdropColor(0.08, 0.08, 0.12, 0.9)
    reportPanel:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)

    local reportToggleButton = CreateFrame("Button", nil, reportPanel, "UIPanelButtonTemplate")
    reportToggleButton:SetPoint("CENTER", reportPanel, "CENTER", 0, 0)
    reportToggleButton:SetSize(140, 24)
    reportToggleButton:SetText("Report player(s)")
    reportToggleButton:SetScript("OnClick", function()
        addon.reportListOpen = not addon.reportListOpen
        UpdateReportButtons(addon.lastReportMessages)
    end)

    local reportListPanel = CreateFrame("Frame", "QuietShuffleReportFrame", UIParent, "BasicFrameTemplate")
    reportListPanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 10, 0)
    reportListPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 10, 0)
    reportListPanel:SetWidth(220)
    if reportListPanel.TitleText then
        reportListPanel.TitleText:SetText("|cFFFFD700Report|r")
    end
    reportListPanel:SetScript("OnHide", function()
        addon.reportListOpen = false
    end)
    reportListPanel:Hide()

    table.insert(UISpecialFrames, "QuietShuffleHistoryFrame")

    frame:HookScript("OnHide", function()
        if addon.reportListPanel then
            addon.reportListOpen = false
            addon.reportListPanel:Hide()
        end
    end)

    addon.historyFrame = frame
    addon.characterDropdown = characterDropdown
    addon.historySessionScrollFrame = sessionScrollFrame
    addon.historySessionContentFrame = sessionContentFrame
    addon.historyMessageScrollFrame = messageScrollFrame
    addon.historyMessageContentFrame = messageContentFrame
    addon.reportPanel = reportPanel
    addon.messagePanel = messagePanel
    addon.reportToggleButton = reportToggleButton
    addon.reportListPanel = reportListPanel
end

addon.ShowHistoryWindow = function()
    if not addon.historyFrame then
        addon.CreateHistoryWindow()
    end

    addon.PopulateSessionList()
    if addon.characterDropdown then
        local entries = addon.GetCharacterKeys()
        UIDropDownMenu_Initialize(addon.characterDropdown, function(self, level)
            for _,entry in ipairs(entries) do
                local key = entry.key
                local classFile = entry.class
                local info = UIDropDownMenu_CreateInfo()
                if classFile and RAID_CLASS_COLORS[classFile] then
                    local c = RAID_CLASS_COLORS[classFile]
                    local color = string.format("|cFF%02X%02X%02X", c.r * 255, c.g * 255, c.b * 255)
                    info.text = string.format("%s%s|r", color, key)
                else
                    info.text = key
                end
                info.value = key
                info.checked = (key == addon.activeCharacterKey)
                info.func = function()
                    addon.SetActiveCharacter(key)
                    UIDropDownMenu_SetSelectedValue(addon.characterDropdown, key)
                    UIDropDownMenu_SetText(addon.characterDropdown, addon.GetColoredCharacterLabel(key))
                    addon.PopulateSessionList()
                    if addon.selectedSessionIndex then
                        addon.ShowSessionMessages(addon.selectedSessionIndex)
                    else
                        addon.ShowSessionMessages(0)
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedValue(addon.characterDropdown, addon.activeCharacterKey)
        UIDropDownMenu_SetText(addon.characterDropdown, addon.GetColoredCharacterLabel(addon.activeCharacterKey))
    end

    if not addon.selectedSessionIndex then
        local history = addon.GetActiveHistory()
        if addon.messages and next(addon.messages) then
            addon.selectedSessionIndex = 0
        elseif #history > 0 then
            addon.selectedSessionIndex = #history
        else
            addon.selectedSessionIndex = nil
        end
    end
    if addon.selectedSessionIndex then
        addon.ShowSessionMessages(addon.selectedSessionIndex)
    else
        addon.ShowSessionMessages(0)
    end

    addon.historyFrame:SetFrameStrata("DIALOG")
    addon.historyFrame:Show()
end

-- Handle clickable link in chat
hooksecurefunc("SetItemRef", function(link, text, button)
    if link and string.find(link, "^quietshuffle:") then
        local command = string.match(link, "^quietshuffle:([^:]+)")
        if command == "history" then
            local history = addon.GetActiveHistory()
            if history and #history > 0 then
                addon.selectedSessionIndex = #history
            else
                addon.selectedSessionIndex = 0
            end
            addon.ShowHistoryWindow()
            return
        end
    end
end)
