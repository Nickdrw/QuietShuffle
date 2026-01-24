assert(LibStub, "LibDBIcon-1.0 requires LibStub")

local lib, oldminor = LibStub:NewLibrary("LibDBIcon-1.0", 1)
if not lib then return end

lib.objects = lib.objects or {}
lib.db = lib.db or {}

local function getMinimapShape()
    return GetMinimapShape and GetMinimapShape() or "ROUND"
end

local function getRadius()
    return 80
end

local function updatePosition(button, db)
    if not button or not Minimap then
        return
    end
    local angle = (db and db.minimapPos) or 225
    local radius = getRadius()
    local x = math.cos(math.rad(angle)) * radius
    local y = math.sin(math.rad(angle)) * radius
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function createButton(name, dataobj)
    local button = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetSize(32, 32)

    button:SetNormalTexture(dataobj.icon or "Interface/Icons/INV_Misc_QuestionMark")
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
        if dataobj.OnClick then
            dataobj.OnClick(button, mouseButton)
        end
    end)

    button:SetScript("OnEnter", function(self)
        if dataobj.OnTooltipShow then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            dataobj.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        end
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
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            local db = lib.db[name]
            db.minimapPos = angle
            updatePosition(self, db)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        updatePosition(self, lib.db[name])
    end)

    return button
end

function lib:Register(name, dataobj, db)
    if not name or not dataobj then
        return
    end
    lib.db[name] = db or {}
    local button = lib.objects[name]
    if not button then
        button = createButton(name, dataobj)
        lib.objects[name] = button
    end

    if lib.db[name].hide then
        button:Hide()
    else
        button:Show()
        updatePosition(button, lib.db[name])
    end
end

function lib:Show(name)
    local button = lib.objects[name]
    if button then
        button:Show()
    end
end

function lib:Hide(name)
    local button = lib.objects[name]
    if button then
        button:Hide()
    end
end

function lib:IsButtonCompartmentAvailable()
    return false
end

function lib:AddButtonToCompartment()
    return false
end

function lib:RemoveButtonFromCompartment()
    return false
end
