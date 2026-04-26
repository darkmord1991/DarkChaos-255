-- ============================================================
-- DC-QoS: Interface Module
-- ============================================================
-- Interface and UI enhancements
-- Adapted from Leatrix Plus for WoW 3.3.5a compatibility
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local Interface = {
    displayName = "Interface",
    settingKey = "interface",
    icon = "Interface\\Icons\\INV_Misc_EngGizmos_01",
}

local BG_FELLEATHER = "Interface\\AddOns\\DC-QOS\\Textures\\Backgrounds\\FelLeather_512.tga"
local STANDALONE_WORLD_MAP_SCALE = 1
local STANDALONE_WORLD_MAP_WIDTH = 1024
local STANDALONE_WORLD_MAP_HEIGHT = 736
local STANDALONE_WORLD_MAP_OFFSET_Y = 26

-- Event frames storage for cleanup (must be defined before functions that use it)
local eventFrames = {}
local zoomSettingHookRegistered = false
local questLevelHookRegistered = false
local worldMapHeaderHooksRegistered = false

local combatPlatesState = { active = false, previousShowEnemies = nil }
local gryphonState = { active = false, leftShown = nil, rightShown = nil }
local worldMapState = {
    active = false,
    mapsterHooksInstalled = false,
    mapsterSelectionEventsInstalled = false,
    mapsterSelectQuestFrameHooked = false,
    questLogFrameHooked = false,
    questLogSuppressUntil = 0,
    reassertingSelection = false,
    lastObjectiveQuestLogIndex = nil,
    seededSelection = false,
    lastObjectiveReassertAt = nil,
    movable = nil,
    mouseEnabled = nil,
    onDragStart = nil,
    onDragStop = nil,
    parent = nil,
    clampedToScreen = nil,
    point = nil,
    width = nil,
    height = nil,
    scale = nil,
    standalonePoint = nil,
    addedToSpecialFrames = false,
    titleButtonShown = nil,
    blackoutShown = nil,
    panelLayoutEnabled = nil,
    uiPanelWindow = nil,
    rootTextureStates = nil,
    frameTitleShown = nil,
    areaLabelShown = nil,
    controlPoints = nil,
}
local minimapState = { active = false, mouseWheelEnabled = nil, onMouseWheel = nil, zoomInShown = nil, zoomOutShown = nil }
local cameraZoomState = { active = false, previousMaxFactor = nil }
local buffFrameState = {
    active = false,
    hookInstalled = false,
    pendingRestore = false,
    restoreFrame = nil,
    offsetX = 0,
    offsetY = 0,
    buffPoint = nil,
    tempEnchantPoint = nil,
}

local function GetManagedEventFrame(key)
    if not eventFrames[key] then
        eventFrames[key] = CreateFrame("Frame")
    end
    return eventFrames[key]
end

-- Forward declaration: map update hooks can run before this function is assigned.
local ApplyStandaloneWorldMapWindowState

local function CapturePoint(frame)
    if not frame or not frame.GetPoint then
        return nil
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    if not point then
        return nil
    end

    return {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x or 0,
        y = y or 0,
    }
end

local function RestorePoint(frame, pointData)
    if not frame or not pointData then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        pointData.point,
        pointData.relativeTo,
        pointData.relativePoint,
        pointData.x or 0,
        pointData.y or 0
    )
end

local function RememberWorldMapControlPoint(frame)
    if not frame then
        return
    end

    local name = frame.GetName and frame:GetName() or nil
    if not name then
        return
    end

    if not worldMapState.controlPoints then
        worldMapState.controlPoints = {}
    end

    if worldMapState.controlPoints[name] then
        return
    end

    worldMapState.controlPoints[name] = CapturePoint(frame)
end

local function RestoreWorldMapControlPoints()
    if not worldMapState.controlPoints then
        return
    end

    for name, pointData in pairs(worldMapState.controlPoints) do
        local frame = _G[name]
        if frame and pointData then
            RestorePoint(frame, pointData)
        end
    end

    worldMapState.controlPoints = nil
end

local function EnsureStandaloneWorldMapBackdrop()
    if not WorldMapFrame then
        return nil
    end

    if WorldMapFrame.__dcqosStandaloneBackdrop then
        return WorldMapFrame.__dcqosStandaloneBackdrop
    end

    local backdrop = CreateFrame("Frame", nil, WorldMapFrame)
    backdrop:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 6, -8)
    backdrop:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -6, 8)
    backdrop:SetFrameStrata(WorldMapFrame:GetFrameStrata())

    local frameLevel = WorldMapFrame.GetFrameLevel and WorldMapFrame:GetFrameLevel() or 0
    backdrop:SetFrameLevel(frameLevel > 0 and frameLevel - 1 or 0)
    backdrop:EnableMouse(false)
    backdrop:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    backdrop:SetBackdropColor(0, 0, 0, 0)
    backdrop:SetBackdropBorderColor(0.34, 0.29, 0.18, 0.95)

    local bg = backdrop:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 10, -10)
    bg:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -10, 10)
    bg:SetTexture(BG_FELLEATHER)
    if bg.SetHorizTile then
        bg:SetHorizTile(true)
    end
    if bg.SetVertTile then
        bg:SetVertTile(true)
    end
    backdrop.bg = bg

    local tint = backdrop:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(bg)
    tint:SetTexture("Interface\\Buttons\\WHITE8x8")
    tint:SetVertexColor(0.05, 0.03, 0.01, 0.54)
    backdrop.tint = tint

    local topBand = backdrop:CreateTexture(nil, "ARTWORK")
    topBand:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)
    topBand:SetPoint("TOPRIGHT", bg, "TOPRIGHT", 0, 0)
    topBand:SetHeight(54)
    topBand:SetTexture("Interface\\Buttons\\WHITE8x8")
    topBand:SetVertexColor(0.24, 0.17, 0.06, 0.24)
    backdrop.topBand = topBand

    local divider = backdrop:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", bg, "TOPLEFT", 14, -44)
    divider:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -14, -44)
    divider:SetHeight(1)
    divider:SetTexture("Interface\\Buttons\\WHITE8x8")
    divider:SetVertexColor(0.44, 0.33, 0.14, 0.34)
    backdrop.divider = divider

    backdrop:SetScript("OnSizeChanged", function(self, width, height)
        if not width or not height then
            return
        end

        local tiledWidth = math.max(width - 20, 1) / 512
        local tiledHeight = math.max(height - 20, 1) / 512
        self.bg:SetTexCoord(0, tiledWidth, 0, tiledHeight)
    end)

    WorldMapFrame.__dcqosStandaloneBackdrop = backdrop
    return backdrop
end

local function GetFontStringText(fontString)
    if not fontString or type(fontString.GetText) ~= "function" then
        return nil
    end

    local text = fontString:GetText()
    if type(text) ~= "string" then
        return nil
    end

    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return nil
    end

    return text
end

local function StyleWorldMapHeaderFont(fontString, minSize, sizeDelta, r, g, b)
    if not fontString or not fontString.GetFont or not fontString.SetFont then
        return
    end

    local font, size, flags = fontString:GetFont()
    if not font or not size then
        return
    end

    if not fontString.__dcqosWorldMapFont then
        fontString.__dcqosWorldMapFont = {
            font = font,
            size = size,
            flags = flags,
        }
    end

    local original = fontString.__dcqosWorldMapFont
    fontString:SetFont(original.font, math.max(minSize, original.size + sizeDelta), original.flags)
    if fontString.SetTextColor then
        fontString:SetTextColor(r, g, b)
    end
    if fontString.SetShadowOffset then
        fontString:SetShadowOffset(1, -1)
    end
    if fontString.SetShadowColor then
        fontString:SetShadowColor(0, 0, 0, 0.8)
    end
end

local function GetWorldMapDropdownText(dropdown)
    if not dropdown then
        return nil
    end

    local text = GetFontStringText(dropdown.Text)
    if text then
        return text
    end

    local name = dropdown.GetName and dropdown:GetName() or nil
    if name and _G[name .. "Text"] then
        return GetFontStringText(_G[name .. "Text"])
    end

    return nil
end

local function CreateWorldMapLegendEntry(parent, label, r, g, b)
    local entry = CreateFrame("Frame", nil, parent)
    entry:SetHeight(14)

    local swatch = entry:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("LEFT", entry, "LEFT", 0, 0)
    swatch:SetSize(8, 8)
    swatch:SetTexture("Interface\\Buttons\\WHITE8x8")
    swatch:SetVertexColor(r, g, b, 1)
    entry.swatch = swatch

    local glow = entry:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("CENTER", swatch, "CENTER", 0, 0)
    glow:SetSize(14, 14)
    glow:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(r, g, b, 1)
    glow:SetAlpha(0.35)
    entry.glow = glow

    local text = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", swatch, "RIGHT", 5, 0)
    text:SetText(label)
    StyleWorldMapHeaderFont(text, 10, 0, 0.92, 0.86, 0.72)
    entry.text = text

    entry:SetWidth(14 + (text.GetStringWidth and math.ceil(text:GetStringWidth() or 0) or 0))
    return entry
end

local function EnsureStandaloneWorldMapHeader()
    local backdrop = EnsureStandaloneWorldMapBackdrop()
    if not backdrop or not backdrop.bg then
        return nil
    end

    if backdrop.__dcqosStandaloneHeader then
        return backdrop.__dcqosStandaloneHeader
    end

    local header = CreateFrame("Frame", nil, backdrop)
    header:SetPoint("TOPLEFT", backdrop.bg, "TOPLEFT", 14, -8)
    header:SetPoint("TOPRIGHT", backdrop.bg, "TOPRIGHT", -14, -8)
    header:SetHeight(36)
    header:SetFrameStrata(WorldMapFrame:GetFrameStrata())
    header:SetFrameLevel(backdrop:GetFrameLevel() + 3)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if WorldMapFrame and WorldMapFrame.StartMoving then
            WorldMapFrame:StartMoving()
        end
    end)
    header:SetScript("OnDragStop", function()
        if WorldMapFrame and WorldMapFrame.StopMovingOrSizing then
            WorldMapFrame:StopMovingOrSizing()
            if WorldMapFrame.SetUserPlaced then
                WorldMapFrame:SetUserPlaced(true)
            end
        end
    end)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    title:SetJustifyH("LEFT")
    StyleWorldMapHeaderFont(title, 13, 2, 1.0, 0.88, 0.36)
    header.title = title

    local subtitle = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetJustifyH("LEFT")
    StyleWorldMapHeaderFont(subtitle, 10, 0, 0.88, 0.80, 0.60)
    header.subtitle = subtitle

    local controlsBand = CreateFrame("Frame", nil, header)
    controlsBand:SetHeight(24)
    controlsBand:SetFrameStrata(header:GetFrameStrata())
    controlsBand:SetFrameLevel(header:GetFrameLevel() + 1)
    controlsBand:EnableMouse(false)
    controlsBand:SetBackdrop({
        bgFile = BG_FELLEATHER,
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true,
        tileSize = 32,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    controlsBand:SetBackdropColor(0.05, 0.04, 0.02, 0.84)
    controlsBand:SetBackdropBorderColor(0.38, 0.29, 0.12, 0.40)

    local controlsTint = controlsBand:CreateTexture(nil, "BACKGROUND")
    controlsTint:SetAllPoints(controlsBand)
    controlsTint:SetTexture("Interface\\Buttons\\WHITE8x8")
    controlsTint:SetVertexColor(0.52, 0.32, 0.08, 0.08)
    controlsBand.tint = controlsTint

    local controlsAccent = controlsBand:CreateTexture(nil, "ARTWORK")
    controlsAccent:SetPoint("TOPLEFT", controlsBand, "TOPLEFT", 0, 0)
    controlsAccent:SetPoint("TOPRIGHT", controlsBand, "TOPRIGHT", 0, 0)
    controlsAccent:SetHeight(1)
    controlsAccent:SetTexture("Interface\\Buttons\\WHITE8x8")
    controlsAccent:SetVertexColor(0.90, 0.74, 0.28, 0.54)
    controlsBand.accent = controlsAccent
    header.controlsBand = controlsBand

    local legend = CreateFrame("Frame", nil, header)
    legend:SetPoint("RIGHT", header, "RIGHT", -86, -2)
    legend:SetHeight(14)
    header.legend = legend

    local tracked = CreateWorldMapLegendEntry(legend, "Followed", 0.95, 0.78, 0.26)
    tracked:SetPoint("RIGHT", legend, "RIGHT", 0, 0)
    header.legendTracked = tracked

    local selected = CreateWorldMapLegendEntry(legend, "Selected", 0.92, 0.76, 0.30)
    selected:SetPoint("RIGHT", tracked, "LEFT", -14, 0)
    header.legendSelected = selected

    local complete = CreateWorldMapLegendEntry(legend, "Complete", 0.56, 0.82, 0.40)
    complete:SetPoint("RIGHT", selected, "LEFT", -14, 0)
    header.legendComplete = complete

    backdrop.__dcqosStandaloneHeader = header
    return header
end

local function LayoutStandaloneWorldMapControls(header)
    if not header or not header.controlsBand or not worldMapState.active then
        return
    end

    local rightmostControl
    local leftmostControl

    local closeButton = WorldMapFrameCloseButton
    if closeButton and closeButton.IsShown and closeButton:IsShown() then
        RememberWorldMapControlPoint(closeButton)
        closeButton:ClearAllPoints()
        closeButton:SetPoint("RIGHT", header, "RIGHT", -8, -1)
        rightmostControl = closeButton
        leftmostControl = closeButton
    end

    local sizeAnchor = rightmostControl or header
    local sizeAnchorPoint = rightmostControl and "LEFT" or "RIGHT"
    local sizeButton
    for _, button in ipairs({ WorldMapFrameSizeDownButton, WorldMapFrameSizeUpButton }) do
        if button then
            RememberWorldMapControlPoint(button)
            button:ClearAllPoints()
            button:SetPoint("RIGHT", sizeAnchor, sizeAnchorPoint, -4, 0)
            if button.IsShown and button:IsShown() then
                sizeButton = button
                if not rightmostControl then
                    rightmostControl = button
                end
                leftmostControl = button
            end
        end
    end

    local zoomAnchor = sizeButton or rightmostControl or header
    local zoomAnchorPoint = (sizeButton or rightmostControl) and "LEFT" or "RIGHT"
    if WorldMapZoomOutButton then
        RememberWorldMapControlPoint(WorldMapZoomOutButton)
        WorldMapZoomOutButton:ClearAllPoints()
        WorldMapZoomOutButton:SetPoint("RIGHT", zoomAnchor, zoomAnchorPoint, -8, 0)
        if WorldMapZoomOutButton.IsShown and WorldMapZoomOutButton:IsShown() then
            if not rightmostControl then
                rightmostControl = WorldMapZoomOutButton
            end
            leftmostControl = WorldMapZoomOutButton
        end
    end

    local dropdownAnchor = (WorldMapZoomOutButton and WorldMapZoomOutButton.IsShown and WorldMapZoomOutButton:IsShown()) and WorldMapZoomOutButton or sizeButton or rightmostControl or header
    local dropdownAnchorPoint = dropdownAnchor == header and "RIGHT" or "LEFT"
    local dropdownOffset = dropdownAnchor == header and -16 or -10

    for _, dropdown in ipairs({ WorldMapLevelDropDown, WorldMapZoneMinimapDropDown, WorldMapZoneDropDown, WorldMapContinentDropDown }) do
        if dropdown then
            RememberWorldMapControlPoint(dropdown)
            dropdown:ClearAllPoints()
            dropdown:SetPoint("RIGHT", dropdownAnchor, dropdownAnchorPoint, dropdownOffset, -1)
            if dropdown.IsShown and dropdown:IsShown() then
                if not rightmostControl then
                    rightmostControl = dropdown
                end
                leftmostControl = dropdown
                dropdownAnchor = dropdown
                dropdownAnchorPoint = "LEFT"
                dropdownOffset = -8
            end
        end
    end

    if leftmostControl and rightmostControl then
        header.controlsBand:ClearAllPoints()
        header.controlsBand:SetPoint("TOPLEFT", leftmostControl, "TOPLEFT", -14, 6)
        header.controlsBand:SetPoint("BOTTOMRIGHT", rightmostControl, "BOTTOMRIGHT", 14, -6)
        header.controlsBand:Show()

        header.legend:ClearAllPoints()
        header.legend:SetPoint("RIGHT", header.controlsBand, "LEFT", -16, -2)

        header.title:ClearAllPoints()
        header.title:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
        header.title:SetPoint("RIGHT", header.legend, "LEFT", -20, 0)

        header.subtitle:ClearAllPoints()
        header.subtitle:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -2)
        header.subtitle:SetPoint("RIGHT", header.legend, "LEFT", -20, 0)
    else
        header.controlsBand:Hide()
    end
end

local function EnsureWorldMapButtonChrome(button)
    if not button then
        return nil
    end

    if button.__dcqosWorldMapChrome then
        return button.__dcqosWorldMapChrome
    end

    local chrome = CreateFrame("Frame", nil, button)
    chrome:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
    chrome:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    chrome:SetFrameStrata(button:GetFrameStrata())
    chrome:SetFrameLevel(math.max((button.GetFrameLevel and button:GetFrameLevel() or 1) - 1, 0))
    chrome:EnableMouse(false)
    chrome:SetBackdrop({
        bgFile = BG_FELLEATHER,
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    chrome:SetBackdropColor(0.05, 0.04, 0.02, 0.72)
    chrome:SetBackdropBorderColor(0.38, 0.29, 0.12, 0.42)

    local glow = chrome:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints(chrome)
    glow:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.92, 0.78, 0.30, 1)
    glow:SetAlpha(0.10)
    chrome.glow = glow

    button.__dcqosWorldMapChrome = chrome
    return chrome
end

local function UpdateWorldMapButtonChrome(button)
    local chrome = EnsureWorldMapButtonChrome(button)
    if not chrome then
        return
    end

    local shown = button.IsShown and button:IsShown()
    if shown then
        chrome:Show()
    else
        chrome:Hide()
        return
    end

    local enabled = button.IsEnabled == nil or button:IsEnabled()
    chrome:SetAlpha(enabled and 1 or 0.5)

    local textures = {
        button.GetNormalTexture and button:GetNormalTexture() or nil,
        button.GetPushedTexture and button:GetPushedTexture() or nil,
        button.GetHighlightTexture and button:GetHighlightTexture() or nil,
        button.GetDisabledTexture and button:GetDisabledTexture() or nil,
    }

    for i = 1, #textures do
        local texture = textures[i]
        if texture and texture.SetVertexColor then
            texture:SetVertexColor(0.94, 0.82, 0.42)
        end
    end
end

local function EnsureWorldMapDropdownChrome(dropdown)
    if not dropdown then
        return nil
    end

    if dropdown.__dcqosWorldMapChrome then
        return dropdown.__dcqosWorldMapChrome
    end

    local chrome = CreateFrame("Frame", nil, dropdown)
    chrome:SetFrameStrata(dropdown:GetFrameStrata())
    chrome:SetFrameLevel(math.max((dropdown.GetFrameLevel and dropdown:GetFrameLevel() or 1) - 1, 0))
    chrome:EnableMouse(false)
    chrome:SetBackdrop({
        bgFile = BG_FELLEATHER,
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true,
        tileSize = 32,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    chrome:SetBackdropColor(0.05, 0.04, 0.02, 0.70)
    chrome:SetBackdropBorderColor(0.34, 0.26, 0.12, 0.34)

    local tint = chrome:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(chrome)
    tint:SetTexture("Interface\\Buttons\\WHITE8x8")
    tint:SetVertexColor(0.48, 0.30, 0.06, 0.08)
    chrome.tint = tint

    dropdown.__dcqosWorldMapChrome = chrome
    return chrome
end

local function UpdateWorldMapDropdownChrome(dropdown)
    local chrome = EnsureWorldMapDropdownChrome(dropdown)
    if not chrome then
        return
    end

    local shown = dropdown.IsShown and dropdown:IsShown()
    if shown then
        chrome:Show()
    else
        chrome:Hide()
        return
    end

    local name = dropdown.GetName and dropdown:GetName() or nil
    local button = name and _G[name .. "Button"] or nil

    chrome:ClearAllPoints()
    if button then
        chrome:SetPoint("TOPLEFT", button, "TOPLEFT", -10, 4)
        chrome:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 28, -6)
        UpdateWorldMapButtonChrome(button)
    else
        chrome:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 16, -2)
        chrome:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -20, 2)
    end

    if name then
        local artNames = { name .. "Left", name .. "Middle", name .. "Right" }
        for i = 1, #artNames do
            local texture = _G[artNames[i]]
            if texture then
                texture:Hide()
            end
        end
    end

    if dropdown.header then
        StyleWorldMapHeaderFont(dropdown.header, 10, 0, 0.86, 0.80, 0.60)
    end

    local text = dropdown.Text or (name and _G[name .. "Text"]) or nil
    if text then
        StyleWorldMapHeaderFont(text, 10, 0, 0.96, 0.88, 0.66)
    end
end

local function RestoreWorldMapDropdownArt(dropdown)
    if not dropdown then
        return
    end

    if dropdown.__dcqosWorldMapChrome then
        dropdown.__dcqosWorldMapChrome:Hide()
    end

    local name = dropdown.GetName and dropdown:GetName() or nil
    if not name then
        return
    end

    local artNames = { name .. "Left", name .. "Middle", name .. "Right" }
    for i = 1, #artNames do
        local texture = _G[artNames[i]]
        if texture then
            texture:Show()
        end
    end
end

local function ResolveStandaloneWorldMapHeaderText()
    local areaText = GetFontStringText(WorldMapFrameAreaLabel)
    local frameTitleText = GetFontStringText(WorldMapFrameTitle)
    local titleText = areaText or frameTitleText or (WORLD_MAP or "World Map")
    local subtitleParts = {}

    if frameTitleText and frameTitleText ~= titleText then
        table.insert(subtitleParts, frameTitleText)
    end

    local floorText = GetWorldMapDropdownText(WorldMapLevelDropDown)
    if floorText and floorText ~= titleText then
        table.insert(subtitleParts, floorText)
    end

    local questCount = tonumber(WorldMapFrame and WorldMapFrame.numQuests) or 0
    if questCount > 0 and (not WatchFrame or WatchFrame.showObjectives ~= false) then
        table.insert(subtitleParts, string.format("%d quest%s visible", questCount, questCount == 1 and "" or "s"))
    end

    local subtitleText = table.concat(subtitleParts, "  |  ")
    if subtitleText == "" then
        subtitleText = "Quest overview"
    end

    return titleText, subtitleText
end

local function UpdateStandaloneWorldMapHeader()
    if not worldMapState.active or not WorldMapFrame then
        return
    end

    local header = EnsureStandaloneWorldMapHeader()
    if not header then
        return
    end

    local titleText, subtitleText = ResolveStandaloneWorldMapHeaderText()
    header.title:SetText(titleText)
    header.subtitle:SetText(subtitleText)
    header:Show()

    LayoutStandaloneWorldMapControls(header)

    if WorldMapFrameTitle then
        WorldMapFrameTitle:Hide()
    end
    if WorldMapFrameAreaLabel then
        WorldMapFrameAreaLabel:Hide()
    end

    UpdateWorldMapButtonChrome(WorldMapZoomOutButton)
    UpdateWorldMapButtonChrome(WorldMapFrameCloseButton)
    UpdateWorldMapButtonChrome(WorldMapFrameSizeUpButton)
    UpdateWorldMapButtonChrome(WorldMapFrameSizeDownButton)

    UpdateWorldMapDropdownChrome(WorldMapContinentDropDown)
    UpdateWorldMapDropdownChrome(WorldMapZoneDropDown)
    UpdateWorldMapDropdownChrome(WorldMapZoneMinimapDropDown)
    UpdateWorldMapDropdownChrome(WorldMapLevelDropDown)
end

local function InstallStandaloneWorldMapHeaderHooks()
    if worldMapHeaderHooksRegistered then
        return
    end

    local function RequestUpdate()
        if worldMapState.active then
            ApplyStandaloneWorldMapWindowState()
            UpdateStandaloneWorldMapHeader()
        end
    end

    local hookNames = {
        "WorldMapFrame_Update",
        "WorldMapFrame_UpdateQuests",
        "WorldMapFrame_DisplayQuests",
        "WorldMapLevelDropDown_Update",
    }

    for _, name in ipairs(hookNames) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, RequestUpdate)
        end
    end

    if WorldMapFrame and type(WorldMapFrame.HookScript) == "function" then
        WorldMapFrame:HookScript("OnShow", RequestUpdate)
    end

    local eventFrame = GetManagedEventFrame("worldMapHeader")
    eventFrame:UnregisterAllEvents()
    eventFrame:RegisterEvent("WORLD_MAP_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", RequestUpdate)

    worldMapHeaderHooksRegistered = true
end

local function SetWorldMapRootTextureVisibility(visible)
    if not WorldMapFrame or type(WorldMapFrame.GetRegions) ~= "function" then
        return
    end

    if not worldMapState.rootTextureStates then
        worldMapState.rootTextureStates = {}
        local regions = { WorldMapFrame:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region
                and type(region.GetObjectType) == "function"
                and region:GetObjectType() == "Texture" then
                table.insert(worldMapState.rootTextureStates, {
                    region = region,
                    shown = region.IsShown and region:IsShown() or false,
                    alpha = region.GetAlpha and region:GetAlpha() or 1,
                })
            end
        end
    end

    for i = 1, #(worldMapState.rootTextureStates or {}) do
        local entry = worldMapState.rootTextureStates[i]
        local region = entry and entry.region or nil
        if region then
            if visible then
                if region.SetAlpha and entry.alpha then
                    region:SetAlpha(entry.alpha)
                end
                if entry.shown and region.Show then
                    region:Show()
                elseif region.Hide then
                    region:Hide()
                end
            elseif region.Hide then
                region:Hide()
            end
        end
    end
end

local function SaveStandaloneWorldMapPlacement()
    if not WorldMapFrame then
        return
    end

    worldMapState.standalonePoint = CapturePoint(WorldMapFrame)
end

local function ParseQuestIdFromLink(link)
    if type(link) ~= "string" then
        return nil
    end

    local questId = tonumber(link:match("|Hquest:(%d+):"))
    if questId and questId > 0 then
        return questId
    end

    return nil
end

local function FindQuestLogIndexByQuestId(questId)
    questId = tonumber(questId)
    if not questId or questId <= 0 then
        return nil
    end
    if type(GetNumQuestLogEntries) ~= "function" or type(GetQuestLogTitle) ~= "function" then
        return nil
    end

    local numEntries = GetNumQuestLogEntries() or 0
    for i = 1, numEntries do
        local _, _, _, _, isHeader, _, _, _, questIdFromApi = GetQuestLogTitle(i)
        if not isHeader then
            local rowQuestId = tonumber(questIdFromApi)
            if (not rowQuestId or rowQuestId <= 0) and type(GetQuestLink) == "function" then
                rowQuestId = ParseQuestIdFromLink(GetQuestLink(i))
            end

            if rowQuestId and rowQuestId == questId then
                return i
            end
        end
    end

    return nil
end

local function IsValidQuestLogIndex(questLogIndex)
    questLogIndex = tonumber(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 then
        return false
    end
    if type(GetQuestLogTitle) ~= "function" then
        return false
    end

    local title, _, _, _, isHeader = GetQuestLogTitle(questLogIndex)
    if not title or isHeader then
        return false
    end

    return true
end

local function ResolveQuestLogIndexFromOrdinal(ordinal)
    ordinal = tonumber(ordinal)
    if not ordinal or ordinal <= 0 then
        return nil
    end

    if type(GetQuestIndexForWatch) == "function" then
        local watchQuestLogIndex = tonumber(GetQuestIndexForWatch(ordinal))
        if IsValidQuestLogIndex(watchQuestLogIndex) then
            return watchQuestLogIndex
        end
    end

    if IsValidQuestLogIndex(ordinal) then
        return ordinal
    end

    return nil
end

local function FindWorldMapQuestFrameByQuestLogIndex(questLogIndex)
    questLogIndex = tonumber(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end
    if not WorldMapQuestScrollChildFrame
        or type(WorldMapQuestScrollChildFrame.GetChildren) ~= "function" then
        return nil
    end

    local children = { WorldMapQuestScrollChildFrame:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child then
            local childQuestLogIndex = tonumber(child.questLogIndex or child.questIndex)
            if childQuestLogIndex == questLogIndex then
                return child
            end

            local childQuestId = tonumber(child.questId or child.questID)
            if childQuestId and childQuestId > 0 then
                local resolvedQuestLogIndex = FindQuestLogIndexByQuestId(childQuestId)
                if resolvedQuestLogIndex == questLogIndex then
                    return child
                end
            end
        end
    end

    return nil
end

local function FindFirstWorldMapQuestFrame()
    if not WorldMapQuestScrollChildFrame
        or type(WorldMapQuestScrollChildFrame.GetChildren) ~= "function" then
        return nil, nil
    end

    local children = { WorldMapQuestScrollChildFrame:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child then
            local questLogIndex = tonumber(child.questLogIndex or child.questIndex)
            if IsValidQuestLogIndex(questLogIndex) then
                return child, questLogIndex
            end

            local questId = tonumber(child.questId or child.questID)
            if questId and questId > 0 then
                local resolvedQuestLogIndex = FindQuestLogIndexByQuestId(questId)
                if IsValidQuestLogIndex(resolvedQuestLogIndex) then
                    return child, resolvedQuestLogIndex
                end
            end
        end
    end

    return nil, nil
end

local function ResolveQuestLogIndexFromQuestFrame(questFrame)
    if not questFrame then
        return nil
    end

    local current = questFrame
    for _ = 1, 3 do
        if not current then
            break
        end

        local questLogIndex = tonumber(current.questLogIndex or current.questIndex)
        if IsValidQuestLogIndex(questLogIndex) then
            return questLogIndex
        end

        local questId = tonumber(current.questId or current.questID)
        if questId and questId > 0 then
            local resolvedQuestLogIndex = FindQuestLogIndexByQuestId(questId)
            if IsValidQuestLogIndex(resolvedQuestLogIndex) then
                return resolvedQuestLogIndex
            end
        end

        local ordinal = tonumber(
            current.id
            or current.index
            or current.poiIndex
            or current.questWatchIndex
            or current.questNumber
            or (current.GetID and current:GetID())
            or nil
        )
        if ordinal and ordinal > 0 then
            local resolvedQuestLogIndex = ResolveQuestLogIndexFromOrdinal(ordinal)
            if IsValidQuestLogIndex(resolvedQuestLogIndex) then
                return resolvedQuestLogIndex
            end
        end

        local name = current.GetName and current:GetName() or nil
        if name then
            local suffixNumber = tonumber(name:match("(%d+)$"))
            if suffixNumber and suffixNumber > 0 then
                local resolvedQuestLogIndex = ResolveQuestLogIndexFromOrdinal(suffixNumber)
                if IsValidQuestLogIndex(resolvedQuestLogIndex) then
                    return resolvedQuestLogIndex
                end
            end
        end

        if type(current.GetRegions) == "function" then
            local regions = { current:GetRegions() }
            for i = 1, #regions do
                local region = regions[i]
                if region
                    and type(region.GetObjectType) == "function"
                    and region:GetObjectType() == "FontString"
                    and type(region.GetText) == "function" then
                    local text = region:GetText()
                    local numberText = tonumber(text)
                    if numberText and numberText > 0 then
                        local resolvedQuestLogIndex = ResolveQuestLogIndexFromOrdinal(numberText)
                        if IsValidQuestLogIndex(resolvedQuestLogIndex) then
                            return resolvedQuestLogIndex
                        end
                    end
                end
            end
        end

        current = current.GetParent and current:GetParent() or nil
    end

    return nil
end

local function ResolveSelectedQuestLogIndex()
    if type(GetQuestLogSelection) == "function" then
        local selected = tonumber(GetQuestLogSelection())
        if selected and selected > 0 then
            return selected
        end
    end

    local selectedQuest = nil
    if WorldMapQuestScrollChildFrame and WorldMapQuestScrollChildFrame.selected then
        selectedQuest = WorldMapQuestScrollChildFrame.selected
    elseif WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.selectedQuest then
        selectedQuest = WORLDMAP_SETTINGS.selectedQuest
    end

    if selectedQuest then
        return ResolveQuestLogIndexFromQuestFrame(selectedQuest)
    end

    return nil
end

local function ShouldSuppressStandaloneQuestLogPanels()
    if not worldMapState.active then
        return false
    end

    local now = (type(GetTime) == "function" and GetTime()) or 0
    if now < (worldMapState.questLogSuppressUntil or 0) then
        return true
    end

    return WorldMapFrame
        and type(WorldMapFrame.IsShown) == "function"
        and WorldMapFrame:IsShown()
end

local function SuppressStandaloneQuestLogPanels()
    for _, frame in ipairs({ QuestLogFrame }) do
        if frame and frame.IsShown and frame:IsShown() then
            if type(HideUIPanel) == "function" then
                pcall(HideUIPanel, frame)
            elseif frame.Hide then
                frame:Hide()
            end

            if frame.IsShown and frame:IsShown() and frame.Hide then
                frame:Hide()
            end
        end
    end
end

local function ReassertWorldMapObjectiveState(questLogIndex)
    if not worldMapState.active then
        return
    end

    local requestedQuestLogIndex = tonumber(questLogIndex)
    local allowSelectionWrites = IsValidQuestLogIndex(requestedQuestLogIndex)
        or not worldMapState.seededSelection

    if type(SetCVar) == "function" then
        pcall(SetCVar, "questPOI", "1")
    end
    if _G and _G.SHOW_QUEST_OBJECTIVES_ON_MAP ~= "1" then
        _G.SHOW_QUEST_OBJECTIVES_ON_MAP = "1"
    end
    if WatchFrame then
        WatchFrame.showObjectives = true
    end

    local objectiveChecked = nil
    if WorldMapQuestShowObjectives
        and type(WorldMapQuestShowObjectives.SetChecked) == "function" then
        objectiveChecked = WorldMapQuestShowObjectives.GetChecked
            and WorldMapQuestShowObjectives:GetChecked()
        WorldMapQuestShowObjectives:SetChecked(true)
    end
    if objectiveChecked == false
        and type(WorldMapQuestShowObjectives_Toggle) == "function" then
        pcall(WorldMapQuestShowObjectives_Toggle)
    end

    questLogIndex = requestedQuestLogIndex
    if not IsValidQuestLogIndex(questLogIndex) then
        questLogIndex = ResolveSelectedQuestLogIndex() or worldMapState.lastObjectiveQuestLogIndex
    end

    if not IsValidQuestLogIndex(questLogIndex) and not worldMapState.seededSelection then
        local firstQuestFrame, firstQuestLogIndex = FindFirstWorldMapQuestFrame()
        if firstQuestFrame and IsValidQuestLogIndex(firstQuestLogIndex) then
            questLogIndex = firstQuestLogIndex
            if type(WorldMapFrame_SelectQuestFrame) == "function" and not worldMapState.reassertingSelection then
                worldMapState.reassertingSelection = true
                pcall(WorldMapFrame_SelectQuestFrame, firstQuestFrame)
                worldMapState.reassertingSelection = false
            end
        end
    end

    if IsValidQuestLogIndex(questLogIndex) then
        worldMapState.lastObjectiveQuestLogIndex = questLogIndex
        worldMapState.seededSelection = true
        local selectedQuestLogIndex = ResolveSelectedQuestLogIndex()
        if allowSelectionWrites
            and selectedQuestLogIndex ~= questLogIndex
            and type(QuestLog_SetSelection) == "function" then
            pcall(QuestLog_SetSelection, questLogIndex)
            selectedQuestLogIndex = ResolveSelectedQuestLogIndex()
        end
        if allowSelectionWrites
            and WorldMapFrame
            and type(WorldMapFrame.IsShown) == "function"
            and WorldMapFrame:IsShown()
            and type(QuestLog_OpenToQuestDetails) == "function" then
            pcall(QuestLog_OpenToQuestDetails, questLogIndex)
            if addon and addon.DelayedCall then
                addon:DelayedCall(0, SuppressStandaloneQuestLogPanels)
                addon:DelayedCall(0.05, SuppressStandaloneQuestLogPanels)
            end
        end

        if allowSelectionWrites
            and selectedQuestLogIndex ~= questLogIndex
            and type(WorldMapFrame_SelectQuestFrame) == "function"
            and not worldMapState.reassertingSelection then
            local selectedQuestFrame = FindWorldMapQuestFrameByQuestLogIndex(questLogIndex)
            if selectedQuestFrame then
                worldMapState.reassertingSelection = true
                pcall(WorldMapFrame_SelectQuestFrame, selectedQuestFrame)
                worldMapState.reassertingSelection = false
            end
        end

        if type(WorldMapQuestShowObjectives) == "function" then
            pcall(WorldMapQuestShowObjectives, questLogIndex)
        end
    elseif type(WorldMapQuestShowObjectives) == "function" then
        pcall(WorldMapQuestShowObjectives)
    end

    if addon and addon.EnsureQuestMinimapTrackingEnabled then
        addon:EnsureQuestMinimapTrackingEnabled()
    end

    if type(WorldMapFrame_SetPOIMaxBounds) == "function" then
        pcall(WorldMapFrame_SetPOIMaxBounds)
    end
    if type(WorldMapFrame_UpdateQuests) == "function" then
        pcall(WorldMapFrame_UpdateQuests)
    end
    if type(WatchFrame_Update) == "function" then
        pcall(WatchFrame_Update)
    end

    if ShouldSuppressStandaloneQuestLogPanels() then
        SuppressStandaloneQuestLogPanels()
    end
end

local function ApplyMapsterLikeCombinedMapLayout()
    if not worldMapState.active or not WorldMapFrame then
        return
    end

    local questListScale = tonumber(WORLDMAP_QUESTLIST_SIZE) or 1

    if type(WorldMapFrame_SetQuestMapView) == "function" then
        pcall(WorldMapFrame_SetQuestMapView)
    end
    if WORLDMAP_SETTINGS then
        WORLDMAP_SETTINGS.size = questListScale
    end

    if WorldMapPositioningGuide
        and WorldMapPositioningGuide.ClearAllPoints
        and WorldMapPositioningGuide.SetPoint then
        WorldMapPositioningGuide:ClearAllPoints()
        WorldMapPositioningGuide:SetPoint("CENTER")
    end

    if WorldMapDetailFrame then
        if WorldMapDetailFrame.SetScale then
            WorldMapDetailFrame:SetScale(questListScale)
        end
        if WorldMapDetailFrame.ClearAllPoints and WorldMapDetailFrame.SetPoint and WorldMapPositioningGuide then
            WorldMapDetailFrame:ClearAllPoints()
            WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -726, -99)
        end
    end

    if WorldMapButton and WorldMapButton.SetScale then
        WorldMapButton:SetScale(questListScale)
    end
    if WorldMapFrameAreaFrame and WorldMapFrameAreaFrame.SetScale then
        WorldMapFrameAreaFrame:SetScale(questListScale)
    end
    if WorldMapBlobFrame then
        if WorldMapBlobFrame.SetScale then
            WorldMapBlobFrame:SetScale(questListScale)
        end
        WorldMapBlobFrame.xRatio = nil
        if type(WorldMapBlobFrame_CalculateHitTranslations) == "function" then
            pcall(WorldMapBlobFrame_CalculateHitTranslations)
        end
    end

    if WorldMapZoneMinimapDropDown then
        WorldMapZoneMinimapDropDown:Show()
    end
    if WorldMapZoomOutButton then
        WorldMapZoomOutButton:Show()
    end
    if WorldMapZoneDropDown then
        WorldMapZoneDropDown:Show()
    end
    if WorldMapContinentDropDown then
        WorldMapContinentDropDown:Show()
    end
    if WorldMapQuestScrollFrame then
        WorldMapQuestScrollFrame:Show()
    end
    if WorldMapQuestDetailScrollFrame then
        WorldMapQuestDetailScrollFrame:Show()
    end
    if WorldMapQuestRewardScrollFrame then
        WorldMapQuestRewardScrollFrame:Show()
    end
    if WorldMapFrameSizeDownButton then
        WorldMapFrameSizeDownButton:Show()
    end

    if WorldMapFrameMiniBorderLeft then
        WorldMapFrameMiniBorderLeft:Hide()
    end
    if WorldMapFrameMiniBorderRight then
        WorldMapFrameMiniBorderRight:Hide()
    end
    if WorldMapFrameSizeUpButton then
        WorldMapFrameSizeUpButton:Hide()
    end

    if WorldMapLevelDropDown then
        WorldMapLevelDropDown:Show()
        if WorldMapLevelDropDown.ClearAllPoints and WorldMapLevelDropDown.SetPoint and WorldMapPositioningGuide then
            WorldMapLevelDropDown:ClearAllPoints()
            WorldMapLevelDropDown:SetPoint("TOPRIGHT", WorldMapPositioningGuide, "TOPRIGHT", -50, -35)
        end
        if WorldMapLevelDropDown.header then
            WorldMapLevelDropDown.header:Show()
        end
    end

    if WorldMapFrameCloseButton and WorldMapPositioningGuide
        and WorldMapFrameCloseButton.ClearAllPoints and WorldMapFrameCloseButton.SetPoint then
        WorldMapFrameCloseButton:ClearAllPoints()
        WorldMapFrameCloseButton:SetPoint("TOPRIGHT", WorldMapPositioningGuide, 4, 4)
    end
    if WorldMapFrameSizeDownButton and WorldMapPositioningGuide
        and WorldMapFrameSizeDownButton.ClearAllPoints and WorldMapFrameSizeDownButton.SetPoint then
        WorldMapFrameSizeDownButton:ClearAllPoints()
        WorldMapFrameSizeDownButton:SetPoint("TOPRIGHT", WorldMapPositioningGuide, -16, 4)
    end
    if WorldMapTrackQuest and WorldMapPositioningGuide
        and WorldMapTrackQuest.ClearAllPoints and WorldMapTrackQuest.SetPoint then
        WorldMapTrackQuest:ClearAllPoints()
        WorldMapTrackQuest:SetPoint("BOTTOMLEFT", WorldMapPositioningGuide, "BOTTOMLEFT", 16, 4)
    end

    if WorldMapFrameTitle then
        WorldMapFrameTitle:ClearAllPoints()
        WorldMapFrameTitle:SetPoint("CENTER", 0, 372)
    end

    if WatchFrame then
        WatchFrame.showObjectives = true
    end
    if _G and _G.SHOW_QUEST_OBJECTIVES_ON_MAP ~= "1" then
        _G.SHOW_QUEST_OBJECTIVES_ON_MAP = "1"
    end
    local objectiveChecked = nil
    if WorldMapQuestShowObjectives
        and type(WorldMapQuestShowObjectives.SetChecked) == "function" then
        objectiveChecked = WorldMapQuestShowObjectives.GetChecked
            and WorldMapQuestShowObjectives:GetChecked()
        WorldMapQuestShowObjectives:SetChecked(true)
    end
    if objectiveChecked == false
        and type(WorldMapQuestShowObjectives_Toggle) == "function" then
        pcall(WorldMapQuestShowObjectives_Toggle)
    end

    if type(WorldMapFrame_SetPOIMaxBounds) == "function" then
        pcall(WorldMapFrame_SetPOIMaxBounds)
    end
    if type(WorldMapFrame_DisplayQuests) == "function" then
        pcall(WorldMapFrame_DisplayQuests)
    end
    if type(WorldMapFrame_UpdateQuests) == "function" then
        pcall(WorldMapFrame_UpdateQuests)
    end

    local preferredQuestLogIndex = ResolveSelectedQuestLogIndex()
    if not IsValidQuestLogIndex(preferredQuestLogIndex) then
        preferredQuestLogIndex = worldMapState.lastObjectiveQuestLogIndex
    end

    ReassertWorldMapObjectiveState(preferredQuestLogIndex)
end

ApplyStandaloneWorldMapWindowState = function()
    if not worldMapState.active or not WorldMapFrame then
        return
    end

    if UIPanelWindows then
        UIPanelWindows["WorldMapFrame"] = nil
    end

    if WorldMapFrame.SetAttribute then
        pcall(WorldMapFrame.SetAttribute, WorldMapFrame, "UIPanelLayout-enabled", false)
    end
    if WorldMapFrame.SetParent then
        WorldMapFrame:SetParent(UIParent)
    end
    if WorldMapFrame.SetToplevel then
        WorldMapFrame:SetToplevel(true)
    end
    if WorldMapFrame.SetMovable then
        WorldMapFrame:SetMovable(true)
    end
    if WorldMapFrame.EnableMouse then
        WorldMapFrame:EnableMouse(true)
    end
    if WorldMapFrame.RegisterForDrag then
        WorldMapFrame:RegisterForDrag("LeftButton")
    end
    if WorldMapFrame.SetClampedToScreen then
        WorldMapFrame:SetClampedToScreen(false)
    end
    if WorldMapFrame.SetWidth then
        WorldMapFrame:SetWidth(STANDALONE_WORLD_MAP_WIDTH)
    end
    if WorldMapFrame.SetHeight then
        WorldMapFrame:SetHeight(STANDALONE_WORLD_MAP_HEIGHT)
    end
    if WorldMapFrame.SetScale then
        WorldMapFrame:SetScale(STANDALONE_WORLD_MAP_SCALE)
    end
    if not worldMapState.standalonePoint then
        worldMapState.standalonePoint = {
            point = "CENTER",
            relativeTo = UIParent,
            relativePoint = "CENTER",
            x = 0,
            y = STANDALONE_WORLD_MAP_OFFSET_Y,
        }
    end
    if WorldMapFrame.ClearAllPoints then
        WorldMapFrame:ClearAllPoints()
    end
    RestorePoint(WorldMapFrame, worldMapState.standalonePoint)
    if WorldMapFrame.SetScript then
        WorldMapFrame:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        WorldMapFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if self.SetUserPlaced then
                self:SetUserPlaced(true)
            end
            SaveStandaloneWorldMapPlacement()
        end)
    end

    SetWorldMapRootTextureVisibility(true)
    if BlackoutWorld then
        BlackoutWorld:Hide()
    end
    if WorldMapTitleButton then
        WorldMapTitleButton:Hide()
    end
    if WorldMapFrame.__dcqosStandaloneBackdrop then
        WorldMapFrame.__dcqosStandaloneBackdrop:Hide()
        if WorldMapFrame.__dcqosStandaloneBackdrop.__dcqosStandaloneHeader then
            WorldMapFrame.__dcqosStandaloneBackdrop.__dcqosStandaloneHeader:Hide()
        end
    end

    ApplyMapsterLikeCombinedMapLayout()
end

local function SafeSetCVar(name, value)
    if type(SetCVar) ~= "function" then
        return false
    end

    local ok = pcall(SetCVar, name, value)
    return ok and true or false
end

local function GetClampedZoomFactor(value)
    local zoom = tonumber(value) or 4
    if zoom < 1 then
        zoom = 1
    elseif zoom > 4 then
        zoom = 4
    end
    return math.floor((zoom * 10) + 0.5) / 10
end

-- ============================================================
-- Combat Nameplates
-- ============================================================
local function SetupCombatPlates()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.combatPlates then return end

    if not combatPlatesState.active and type(GetCVar) == "function" then
        combatPlatesState.previousShowEnemies = GetCVar("nameplateShowEnemies")
    end
    combatPlatesState.active = true

    local frame = GetManagedEventFrame("combatPlates")
    frame:UnregisterAllEvents()
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Enter combat
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leave combat
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            SafeSetCVar("nameplateShowEnemies", "1")
        else
            SafeSetCVar("nameplateShowEnemies", "0")
        end
    end)
    
    -- Set initial state based on current combat status
    if UnitAffectingCombat("player") then
        SafeSetCVar("nameplateShowEnemies", "1")
    else
        SafeSetCVar("nameplateShowEnemies", "0")
    end
end

-- ============================================================
-- Auto Quest Watch
-- ============================================================
local function SetupAutoQuestWatch()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.autoQuestWatch then return end

    local frame = GetManagedEventFrame("autoQuestWatch")
    frame:UnregisterAllEvents()
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:SetScript("OnEvent", function(self, event, questLogIndex, questId)
        if questLogIndex then
            AddQuestWatch(questLogIndex)
        end
    end)
end

-- ============================================================
-- Quest Level Text
-- ============================================================
local function SetupQuestLevelText()
    if questLevelHookRegistered then return end
    questLevelHookRegistered = true

    local function BuildQuestTrackerLookup()
        local questLookupByIndex = {}
        local questLookupByTitle = {}
        if type(GetNumQuestLogEntries) ~= "function" or type(GetQuestLogTitle) ~= "function" then
            return questLookupByIndex, questLookupByTitle
        end

        local currentArea
        local areaOrder = 0
        local areaQuestOrder = 0
        local numEntries = GetNumQuestLogEntries() or 0
        for questIndex = 1, numEntries do
            local title, level, _, _, isHeader = GetQuestLogTitle(questIndex)
            if title then
                if isHeader then
                    currentArea = title
                    areaOrder = areaOrder + 1
                    areaQuestOrder = 0
                else
                    areaQuestOrder = areaQuestOrder + 1
                    local info = {
                        title = title,
                        level = (type(level) == "number" and level > 0) and level or nil,
                        areaName = currentArea,
                        areaOrder = areaOrder > 0 and areaOrder or questIndex,
                        areaQuestOrder = areaQuestOrder,
                        questLogIndex = questIndex,
                    }
                    questLookupByIndex[questIndex] = info
                    if info.level then
                        questLookupByTitle[title] = info
                    end
                end
            end
        end

        return questLookupByIndex, questLookupByTitle
    end

    local function StripQuestLevelPrefix(text)
        if type(text) ~= "string" then
            return text
        end
        return (text:gsub("^%[%d+%]%s*", ""))
    end

    local function ApplyQuestLevelsToWatchFrame()
        local settings = addon.settings and addon.settings.interface
        if not settings or not settings.enabled or not settings.questLevelText then
            return
        end
        if not WatchFrame then
            return
        end

        local questLookupByIndex, questLookupByTitle = BuildQuestTrackerLookup()
        if not next(questLookupByIndex) then
            return
        end

        local function EnsureWatchAreaHeader(frame)
            if not frame then
                return nil
            end

            if frame.__dcqosAreaHeader then
                return frame.__dcqosAreaHeader
            end

            local header = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            header:SetJustifyH("LEFT")
            header:SetWidth(220)
            header:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 18, 3)
            if header.SetTextColor then
                header:SetTextColor(0.92, 0.78, 0.30)
            end
            if header.SetShadowOffset then
                header:SetShadowOffset(1, -1)
            end
            if header.SetShadowColor then
                header:SetShadowColor(0, 0, 0, 0.8)
            end
            frame.__dcqosAreaHeader = header
            return header
        end

        local function ResolveWatchQuestInfo(frame)
            local frameName = frame and frame.GetName and frame:GetName() or nil
            local watchIndex = frameName and tonumber(frameName:match("WatchFrameItem(%d+)")) or nil
            if watchIndex and watchIndex > 0 and type(GetQuestIndexForWatch) == "function" then
                local questLogIndex = tonumber(GetQuestIndexForWatch(watchIndex))
                if questLogIndex and questLogIndex > 0 then
                    return questLookupByIndex[questLogIndex]
                end
            end

            return nil
        end

        local function ApplyWatchFrameGrouping()
            if type(GetNumQuestWatches) ~= "function" or type(GetQuestIndexForWatch) ~= "function" then
                return
            end

            local numWatches = GetNumQuestWatches() or 0
            if numWatches <= 0 then
                return
            end

            local entries = {}
            local anchorPoint
            for watchIndex = 1, numWatches do
                local watchRoot = _G["WatchFrameItem" .. watchIndex]
                if watchRoot and watchRoot.IsShown and watchRoot:IsShown() then
                    if not anchorPoint then
                        anchorPoint = CapturePoint(watchRoot)
                    end

                    local questLogIndex = tonumber(GetQuestIndexForWatch(watchIndex))
                    local info = questLogIndex and questLookupByIndex[questLogIndex] or nil
                    table.insert(entries, {
                        root = watchRoot,
                        questLogIndex = questLogIndex,
                        info = info,
                    })
                end
            end

            if #entries == 0 or not anchorPoint then
                return
            end

            table.sort(entries, function(a, b)
                local aAreaOrder = (a.info and a.info.areaOrder) or math.huge
                local bAreaOrder = (b.info and b.info.areaOrder) or math.huge
                if aAreaOrder ~= bAreaOrder then
                    return aAreaOrder < bAreaOrder
                end

                local aQuestOrder = (a.info and a.info.areaQuestOrder) or (a.questLogIndex or math.huge)
                local bQuestOrder = (b.info and b.info.areaQuestOrder) or (b.questLogIndex or math.huge)
                if aQuestOrder ~= bQuestOrder then
                    return aQuestOrder < bQuestOrder
                end

                return (a.questLogIndex or math.huge) < (b.questLogIndex or math.huge)
            end)

            local previousRoot
            local previousAreaName
            for index = 1, #entries do
                local entry = entries[index]
                local root = entry.root
                local info = entry.info
                local showHeader = info and info.areaName and info.areaName ~= "" and info.areaName ~= previousAreaName
                local header = EnsureWatchAreaHeader(root)

                if header then
                    if showHeader then
                        header:SetText(info.areaName)
                        header:Show()
                    else
                        header:Hide()
                    end
                end

                root:ClearAllPoints()
                if previousRoot then
                    local yOffset = showHeader and -16 or -4
                    root:SetPoint("TOPLEFT", previousRoot, "BOTTOMLEFT", 0, yOffset)
                else
                    local firstYOffset = showHeader and -12 or 0
                    root:SetPoint(
                        anchorPoint.point,
                        anchorPoint.relativeTo,
                        anchorPoint.relativePoint,
                        anchorPoint.x or 0,
                        (anchorPoint.y or 0) + firstYOffset
                    )
                end

                previousRoot = root
                previousAreaName = info and info.areaName or previousAreaName
            end
        end

        local function UpdateFrameText(frame, depth)
            if not frame or depth > 3 then
                return
            end

            if type(frame.GetRegions) == "function" then
                local regions = { frame:GetRegions() }
                for i = 1, #regions do
                    local region = regions[i]
                    if region
                        and type(region.GetObjectType) == "function"
                        and region:GetObjectType() == "FontString"
                        and type(region.GetText) == "function"
                        and type(region.SetText) == "function" then
                        local text = region:GetText()
                        if type(text) == "string" and text ~= "" then
                            local baseTitle = StripQuestLevelPrefix(text)
                            local questInfo = questLookupByTitle[baseTitle]
                            local level = questInfo and questInfo.level or nil
                            if level then
                                local withLevel = string.format("[%d] %s", level, baseTitle)
                                if text ~= withLevel then
                                    region:SetText(withLevel)
                                end
                            end
                        end
                    end
                end
            end

            if type(frame.GetChildren) == "function" then
                local children = { frame:GetChildren() }
                for i = 1, #children do
                    UpdateFrameText(children[i], depth + 1)
                end
            end
        end

        UpdateFrameText(WatchFrame, 0)
        ApplyWatchFrameGrouping()
    end

    -- Hook the quest log title button update
    hooksecurefunc("QuestLog_Update", function()
        local settings = addon.settings and addon.settings.interface
        if not settings or not settings.enabled or not settings.questLevelText then
            return
        end

        local numQuests = QUESTS_DISPLAYED or 6
        for i = 1, numQuests do
            local questLogTitle = _G["QuestLogTitle" .. i]
            if questLogTitle then
                local questIndex = questLogTitle:GetID()
                local title, level, tag, suggestedGroup, isHeader, isCollapsed, isComplete = GetQuestLogTitle(questIndex)

                if title and not isHeader then
                    local newTitle = string.format("[%d] %s", level, title)
                    questLogTitle:SetText(newTitle)
                    questLogTitle:SetNormalFontObject("GameFontNormal")
                end
            end
        end
    end)

    if type(WatchFrame_Update) == "function" then
        hooksecurefunc("WatchFrame_Update", ApplyQuestLevelsToWatchFrame)
    end
    if type(QuestWatch_Update) == "function" then
        hooksecurefunc("QuestWatch_Update", ApplyQuestLevelsToWatchFrame)
    end
end

-- ============================================================
-- Hide Gryphons (MainMenuBar art)
-- ============================================================
local function SetupHideGryphons()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.hideGryphons then return end

    if not gryphonState.active then
        if MainMenuBarLeftEndCap and MainMenuBarLeftEndCap.IsShown then
            gryphonState.leftShown = MainMenuBarLeftEndCap:IsShown()
        end
        if MainMenuBarRightEndCap and MainMenuBarRightEndCap.IsShown then
            gryphonState.rightShown = MainMenuBarRightEndCap:IsShown()
        end
    end
    gryphonState.active = true
    
    if MainMenuBarLeftEndCap then
        MainMenuBarLeftEndCap:Hide()
    end
    if MainMenuBarRightEndCap then
        MainMenuBarRightEndCap:Hide()
    end
end

-- ============================================================
-- Larger World Map
-- ============================================================
local function EnsureStandaloneWorldMapShell()
    if not WorldMapFrame then
        return
    end

    local wasShown = WorldMapFrame.IsShown and WorldMapFrame:IsShown() or false
    if wasShown and type(HideUIPanel) == "function" then
        HideUIPanel(WorldMapFrame)
    end

    ApplyStandaloneWorldMapWindowState()

    if UISpecialFrames and not worldMapState.addedToSpecialFrames then
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "WorldMapFrame" then
                found = true
                break
            end
        end
        if not found then
            table.insert(UISpecialFrames, "WorldMapFrame")
            worldMapState.addedToSpecialFrames = true
        end
    end

    if wasShown and type(ShowUIPanel) == "function" then
        ShowUIPanel(WorldMapFrame)
    end
end

local function InstallMapsterLayoutHooks()
    if worldMapState.mapsterHooksInstalled or not WorldMapFrame then
        return
    end

    local function ReapplyLayout()
        if not worldMapState.active then
            return
        end

        ApplyStandaloneWorldMapWindowState()
        if ShouldSuppressStandaloneQuestLogPanels() then
            SuppressStandaloneQuestLogPanels()
        end
        if addon and addon.DelayedCall then
            addon:DelayedCall(0, ApplyStandaloneWorldMapWindowState)
            addon:DelayedCall(0.05, ApplyStandaloneWorldMapWindowState)
        end
    end

    if type(WorldMapFrame.HookScript) == "function" then
        WorldMapFrame:HookScript("OnShow", ReapplyLayout)
    end

    for _, button in ipairs({ WorldMapFrameSizeUpButton, WorldMapFrameSizeDownButton }) do
        if button and type(button.HookScript) == "function" then
            button:HookScript("OnClick", ReapplyLayout)
        end
    end

    worldMapState.mapsterHooksInstalled = true
end

local function InstallMapsterSelectionHooks()
    if type(hooksecurefunc) ~= "function" then
        return
    end

    local function ApplySelectionFromFrame(frame)
        if worldMapState.reassertingSelection then
            return
        end

        local questLogIndex = ResolveQuestLogIndexFromQuestFrame(frame)
        ReassertWorldMapObjectiveState(questLogIndex)
    end

    local function TryInstallSelectionFunctionHooks()
        if not worldMapState.mapsterSelectQuestFrameHooked
            and type(WorldMapFrame_SelectQuestFrame) == "function" then
            hooksecurefunc("WorldMapFrame_SelectQuestFrame", function(questFrame)
                ApplySelectionFromFrame(questFrame)
            end)
            worldMapState.mapsterSelectQuestFrameHooked = true
        end
    end

    TryInstallSelectionFunctionHooks()

    local function SuppressQuestLogPanelOnShow(frame)
        if not frame or not ShouldSuppressStandaloneQuestLogPanels() then
            return
        end

        if type(HideUIPanel) == "function" then
            pcall(HideUIPanel, frame)
        elseif frame.Hide then
            frame:Hide()
        end

        if frame.IsShown and frame:IsShown() and frame.Hide then
            frame:Hide()
        end
    end

    if not worldMapState.questLogFrameHooked
        and QuestLogFrame
        and type(QuestLogFrame.HookScript) == "function" then
        QuestLogFrame:HookScript("OnShow", function(self)
            SuppressQuestLogPanelOnShow(self)
        end)
        worldMapState.questLogFrameHooked = true
    end

    if not worldMapState.mapsterSelectionEventsInstalled then
        local mapObjectiveFrame = GetManagedEventFrame("mapsterObjective")
        mapObjectiveFrame:UnregisterAllEvents()
        mapObjectiveFrame:RegisterEvent("WORLD_MAP_UPDATE")
        mapObjectiveFrame:RegisterEvent("QUEST_LOG_UPDATE")
        mapObjectiveFrame:RegisterEvent("QUEST_POI_UPDATE")
        mapObjectiveFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        mapObjectiveFrame:SetScript("OnEvent", function(_, event)
            TryInstallSelectionFunctionHooks()

            if event == "PLAYER_ENTERING_WORLD" then
                local now = (type(GetTime) == "function" and GetTime()) or 0
                worldMapState.questLogSuppressUntil = now + 2.5
                SuppressStandaloneQuestLogPanels()
                if addon and addon.DelayedCall then
                    addon:DelayedCall(0.10, SuppressStandaloneQuestLogPanels)
                    addon:DelayedCall(0.35, SuppressStandaloneQuestLogPanels)
                end
                return
            end

            if not worldMapState.active then
                return
            end
            if WorldMapFrame and type(WorldMapFrame.IsShown) == "function" and not WorldMapFrame:IsShown() then
                return
            end

            local now = (type(GetTime) == "function" and GetTime()) or 0
            if (now - (worldMapState.lastObjectiveReassertAt or 0)) < 0.08 then
                return
            end
            worldMapState.lastObjectiveReassertAt = now

            ReassertWorldMapObjectiveState()
            SuppressStandaloneQuestLogPanels()
            if addon and addon.DelayedCall then
                addon:DelayedCall(0, ReassertWorldMapObjectiveState)
                addon:DelayedCall(0.05, ReassertWorldMapObjectiveState)
                addon:DelayedCall(0.05, SuppressStandaloneQuestLogPanels)
            end
        end)

        worldMapState.mapsterSelectionEventsInstalled = true
        TryInstallSelectionFunctionHooks()
    end
end

local function SetupLargerWorldMap()
    local settings = addon.settings.interface
    if not settings.enabled then return end
    -- `largerWorldMap` is now informational only; the combined-style world map
    -- shell is always installed when the Interface module is enabled so the
    -- map opens in a Mapster-like windowed layout instead of fullscreen.

    if not WorldMapFrame then
        return
    end

    if not worldMapState.active then
        worldMapState.active = true
        worldMapState.movable = WorldMapFrame.IsMovable and WorldMapFrame:IsMovable() or false
        worldMapState.mouseEnabled = WorldMapFrame.IsMouseEnabled and WorldMapFrame:IsMouseEnabled() or true
        worldMapState.onDragStart = WorldMapFrame.GetScript and WorldMapFrame:GetScript("OnDragStart") or nil
        worldMapState.onDragStop = WorldMapFrame.GetScript and WorldMapFrame:GetScript("OnDragStop") or nil
        worldMapState.parent = WorldMapFrame.GetParent and WorldMapFrame:GetParent() or nil
        worldMapState.clampedToScreen = WorldMapFrame.IsClampedToScreen and WorldMapFrame:IsClampedToScreen() or nil
        worldMapState.point = CapturePoint(WorldMapFrame)
        worldMapState.width = WorldMapFrame.GetWidth and WorldMapFrame:GetWidth() or nil
        worldMapState.height = WorldMapFrame.GetHeight and WorldMapFrame:GetHeight() or nil
        worldMapState.scale = WorldMapFrame.GetScale and WorldMapFrame:GetScale() or 1
        worldMapState.titleButtonShown = WorldMapTitleButton and WorldMapTitleButton.IsShown and WorldMapTitleButton:IsShown() or false
        worldMapState.blackoutShown = BlackoutWorld and BlackoutWorld.IsShown and BlackoutWorld:IsShown() or false
        worldMapState.frameTitleShown = WorldMapFrameTitle and WorldMapFrameTitle.IsShown and WorldMapFrameTitle:IsShown() or false
        worldMapState.areaLabelShown = WorldMapFrameAreaLabel and WorldMapFrameAreaLabel.IsShown and WorldMapFrameAreaLabel:IsShown() or false
        worldMapState.panelLayoutEnabled = WorldMapFrame.GetAttribute and WorldMapFrame:GetAttribute("UIPanelLayout-enabled") or nil
        if UIPanelWindows then
            worldMapState.uiPanelWindow = UIPanelWindows["WorldMapFrame"]
        end
        worldMapState.standalonePoint = {
            point = "CENTER",
            relativeTo = UIParent,
            relativePoint = "CENTER",
            x = 0,
            y = STANDALONE_WORLD_MAP_OFFSET_Y,
        }
    end

    InstallMapsterLayoutHooks()
    InstallMapsterSelectionHooks()

    local now = (type(GetTime) == "function" and GetTime()) or 0
    worldMapState.questLogSuppressUntil = now + 2.5
    SuppressStandaloneQuestLogPanels()
    if addon and addon.DelayedCall then
        addon:DelayedCall(0.10, SuppressStandaloneQuestLogPanels)
        addon:DelayedCall(0.35, SuppressStandaloneQuestLogPanels)
    end

    EnsureStandaloneWorldMapShell()
    ApplyStandaloneWorldMapWindowState()
end

-- ============================================================
-- Buff/Aura Frame Position
-- ============================================================
local function ApplyBuffFramePosition()
    if InCombatLockdown() then return end

    if BuffFrame then
        if not buffFrameState.buffPoint then
            buffFrameState.buffPoint = CapturePoint(BuffFrame)
        end

        BuffFrame:SetMovable(true)
        BuffFrame:SetUserPlaced(true)
        BuffFrame._dcqosRepositioning = true
        BuffFrame:ClearAllPoints()
        BuffFrame:SetPoint("TOPRIGHT", MinimapCluster or UIParent, "TOPLEFT", buffFrameState.offsetX, buffFrameState.offsetY)
        BuffFrame._dcqosRepositioning = nil

        if not buffFrameState.hookInstalled then
            buffFrameState.hookInstalled = true
            hooksecurefunc(BuffFrame, "SetPoint", function(self, ...)
                if not buffFrameState.active or self._dcqosRepositioning then return end
                self._dcqosRepositioning = true
                self:ClearAllPoints()
                self:SetPoint("TOPRIGHT", MinimapCluster or UIParent, "TOPLEFT", buffFrameState.offsetX, buffFrameState.offsetY)
                self._dcqosRepositioning = nil
            end)
        end
    end

    if TemporaryEnchantFrame then
        if not buffFrameState.tempEnchantPoint then
            buffFrameState.tempEnchantPoint = CapturePoint(TemporaryEnchantFrame)
        end

        TemporaryEnchantFrame:ClearAllPoints()
        TemporaryEnchantFrame:SetPoint("TOPRIGHT", MinimapCluster or UIParent, "TOPLEFT", buffFrameState.offsetX, buffFrameState.offsetY)
    end
end

local function RestoreBuffFramePosition()
    if InCombatLockdown() then
        buffFrameState.pendingRestore = true
        if not buffFrameState.restoreFrame then
            buffFrameState.restoreFrame = CreateFrame("Frame")
        end
        buffFrameState.restoreFrame:UnregisterAllEvents()
        buffFrameState.restoreFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        buffFrameState.restoreFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
            RestoreBuffFramePosition()
        end)
        return false
    end

    buffFrameState.pendingRestore = false
    if buffFrameState.restoreFrame then
        buffFrameState.restoreFrame:UnregisterAllEvents()
        buffFrameState.restoreFrame:SetScript("OnEvent", nil)
    end

    if BuffFrame then
        BuffFrame._dcqosRepositioning = true
        RestorePoint(BuffFrame, buffFrameState.buffPoint)
        BuffFrame._dcqosRepositioning = nil
        if BuffFrame.SetUserPlaced then
            BuffFrame:SetUserPlaced(false)
        end
    end

    if TemporaryEnchantFrame then
        RestorePoint(TemporaryEnchantFrame, buffFrameState.tempEnchantPoint)
    end

    return true
end

local function SetupBuffFramePosition()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.buffFrameMove then return end

    buffFrameState.active = true
    buffFrameState.pendingRestore = false
    if buffFrameState.restoreFrame then
        buffFrameState.restoreFrame:UnregisterAllEvents()
        buffFrameState.restoreFrame:SetScript("OnEvent", nil)
    end
    buffFrameState.offsetX = settings.buffFrameOffsetX or 0
    buffFrameState.offsetY = settings.buffFrameOffsetY or 0

    -- Use a frame to handle positioning after combat/loading
    local positioner = GetManagedEventFrame("buffPositioner")
    positioner:UnregisterAllEvents()
    positioner:RegisterEvent("PLAYER_ENTERING_WORLD")
    positioner:RegisterEvent("PLAYER_REGEN_ENABLED")
    positioner:SetScript("OnEvent", ApplyBuffFramePosition)
    
    -- Apply immediately if not in combat
    if not InCombatLockdown() then
        ApplyBuffFramePosition()
    end
    
    -- Also try after a short delay for late-loading UI
    addon:DelayedCall(0.5, ApplyBuffFramePosition)
    addon:DelayedCall(2.0, ApplyBuffFramePosition)
end

-- ============================================================
-- Enhanced Minimap
-- ============================================================
local function SetupEnhancedMinimap()
    if not Minimap then
        return
    end

    if not minimapState.active then
        minimapState.active = true
        minimapState.mouseWheelEnabled = Minimap.IsMouseWheelEnabled and Minimap:IsMouseWheelEnabled() or false
        minimapState.onMouseWheel = Minimap.GetScript and Minimap:GetScript("OnMouseWheel") or nil
        minimapState.zoomInShown = MinimapZoomIn and MinimapZoomIn.IsShown and MinimapZoomIn:IsShown() or false
        minimapState.zoomOutShown = MinimapZoomOut and MinimapZoomOut.IsShown and MinimapZoomOut:IsShown() or false
    end

    -- Allow scrolling to zoom minimap
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            MinimapZoomIn:Click()
        else
            MinimapZoomOut:Click()
        end
    end)
    
    -- Hide minimap zoom buttons
    MinimapZoomIn:Hide()
    MinimapZoomOut:Hide()
end

-- ============================================================
-- Camera Zoom Distance
-- ============================================================
local function ApplyCameraZoomDistance()
    local settings = addon.settings.interface
    if not settings or not settings.enabled then return end

    if settings.extendedCameraZoom then
        local zoomFactor = GetClampedZoomFactor(settings.maxZoomFactor)
        SafeSetCVar("cameraDistanceMaxFactor", tostring(zoomFactor))
    else
        SafeSetCVar("cameraDistanceMaxFactor", "1")
    end
end

local function SetupCameraZoomDistance()
    local settings = addon.settings.interface
    if not settings or not settings.enabled then return end

    if not cameraZoomState.active and type(GetCVar) == "function" then
        cameraZoomState.previousMaxFactor = GetCVar("cameraDistanceMaxFactor")
    end
    cameraZoomState.active = true

    ApplyCameraZoomDistance()

    local frame = GetManagedEventFrame("cameraZoom")
    frame:UnregisterAllEvents()
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function()
        ApplyCameraZoomDistance()
    end)

    addon:DelayedCall(1.0, ApplyCameraZoomDistance)

    if not zoomSettingHookRegistered then
        zoomSettingHookRegistered = true
        addon:RegisterEvent("SETTING_CHANGED", function(path)
            if path == "interface.enabled" or path == "interface.extendedCameraZoom" or path == "interface.maxZoomFactor" then
                ApplyCameraZoomDistance()
            end
        end)
    end
end

-- ============================================================
-- Player Frame Offset
-- ============================================================
local function SetupPlayerFrameOffset()
    local settings = addon.settings.interface
    if not settings.enabled then return end
    
    local yOffset = settings.playerFrameOffsetY or -3
    
    local function ApplyOffset()
        if InCombatLockdown() then return end
        if not PlayerFrame then return end
        
        -- Get current position and nudge down
        local point, relativeTo, relativePoint, x, y = PlayerFrame:GetPoint()
        if point then
            PlayerFrame:ClearAllPoints()
            PlayerFrame:SetPoint(point, relativeTo, relativePoint, x, (y or 0) + yOffset)
        end
    end
    
    -- Apply after UI loads
    addon:DelayedCall(0.5, ApplyOffset)
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function Interface.OnInitialize()
    addon:Debug("Interface module initializing")
end

function Interface.OnEnable()
    addon:Debug("Interface module enabling")

    -- Make sure native quest objective POIs are enabled. Without these the
    -- world map only ever shows the questlist numbers (no shaded POI areas)
    -- and the minimap never decorates tracked quests with their objective
    -- marker dots. They are CVars/state Blizzard otherwise leaves at the
    -- player's last setting, so we re-assert them whenever the addon loads.
    if type(SetCVar) == "function" then
        pcall(SetCVar, "questPOI", "1")
    end
    if _G and _G.SHOW_QUEST_OBJECTIVES_ON_MAP ~= "1" then
        _G.SHOW_QUEST_OBJECTIVES_ON_MAP = "1"
    end
    if WatchFrame then
        WatchFrame.showObjectives = true
    end
    if WorldMapQuestShowObjectives
        and type(WorldMapQuestShowObjectives.SetChecked) == "function" then
        local objectiveChecked = WorldMapQuestShowObjectives.GetChecked
            and WorldMapQuestShowObjectives:GetChecked()
        WorldMapQuestShowObjectives:SetChecked(true)
        if objectiveChecked == false
            and type(WorldMapQuestShowObjectives_Toggle) == "function" then
            pcall(WorldMapQuestShowObjectives_Toggle)
        end
    end
    if type(WatchFrame_Update) == "function" then
        pcall(WatchFrame_Update)
    end

    SetupCombatPlates()
    SetupAutoQuestWatch()
    SetupQuestLevelText()
    SetupHideGryphons()
    SetupLargerWorldMap()
    if not (addon.settings.minimap and addon.settings.minimap.enabled) then
        SetupEnhancedMinimap()
    end
    SetupCameraZoomDistance()
    SetupBuffFramePosition()
    SetupPlayerFrameOffset()
end

function Interface.OnDisable()
    addon:Debug("Interface module disabling")
    -- Unregister all event frames to clean up
    for _, frame in pairs(eventFrames) do
        if frame and frame.UnregisterAllEvents then
            frame:UnregisterAllEvents()
            frame:SetScript("OnEvent", nil)
        end
    end

    if combatPlatesState.active then
        SafeSetCVar("nameplateShowEnemies", tostring(combatPlatesState.previousShowEnemies or "0"))
        combatPlatesState.active = false
        combatPlatesState.previousShowEnemies = nil
    end

    if cameraZoomState.active then
        SafeSetCVar("cameraDistanceMaxFactor", tostring(cameraZoomState.previousMaxFactor or "1"))
        cameraZoomState.active = false
        cameraZoomState.previousMaxFactor = nil
    end

    if gryphonState.active then
        if MainMenuBarLeftEndCap then
            if gryphonState.leftShown then MainMenuBarLeftEndCap:Show() else MainMenuBarLeftEndCap:Hide() end
        end
        if MainMenuBarRightEndCap then
            if gryphonState.rightShown then MainMenuBarRightEndCap:Show() else MainMenuBarRightEndCap:Hide() end
        end
        gryphonState.active = false
        gryphonState.leftShown = nil
        gryphonState.rightShown = nil
    end

    if worldMapState.active and WorldMapFrame then
        if WorldMapFrame.StopMovingOrSizing then
            WorldMapFrame:StopMovingOrSizing()
        end
        SetWorldMapRootTextureVisibility(true)
        if WorldMapFrame.__dcqosStandaloneBackdrop then
            WorldMapFrame.__dcqosStandaloneBackdrop:Hide()
            if WorldMapFrame.__dcqosStandaloneBackdrop.__dcqosStandaloneHeader then
                WorldMapFrame.__dcqosStandaloneBackdrop.__dcqosStandaloneHeader:Hide()
            end
        end
        RestoreWorldMapControlPoints()
        WorldMapFrame:SetMovable(worldMapState.movable and true or false)
        if WorldMapFrame.EnableMouse and worldMapState.mouseEnabled ~= nil then
            WorldMapFrame:EnableMouse(worldMapState.mouseEnabled)
        end
        if WorldMapFrame.SetScript then
            WorldMapFrame:SetScript("OnDragStart", worldMapState.onDragStart)
            WorldMapFrame:SetScript("OnDragStop", worldMapState.onDragStop)
        end
        if WorldMapFrame.SetParent and worldMapState.parent then
            WorldMapFrame:SetParent(worldMapState.parent)
        end
        if WorldMapFrame.SetClampedToScreen and worldMapState.clampedToScreen ~= nil then
            WorldMapFrame:SetClampedToScreen(worldMapState.clampedToScreen)
        end
        if WorldMapFrame.SetWidth and worldMapState.width then
            WorldMapFrame:SetWidth(worldMapState.width)
        end
        if WorldMapFrame.SetHeight and worldMapState.height then
            WorldMapFrame:SetHeight(worldMapState.height)
        end
        if WorldMapFrame.SetScale and worldMapState.scale ~= nil then
            WorldMapFrame:SetScale(worldMapState.scale)
        end
        if WorldMapFrame.ClearAllPoints and worldMapState.point then
            WorldMapFrame:ClearAllPoints()
            RestorePoint(WorldMapFrame, worldMapState.point)
        end
        if WorldMapFrame.SetAttribute then
            pcall(WorldMapFrame.SetAttribute, WorldMapFrame, "UIPanelLayout-enabled", worldMapState.panelLayoutEnabled)
        end
        if UIPanelWindows then
            UIPanelWindows["WorldMapFrame"] = worldMapState.uiPanelWindow
        end
        if WorldMapTitleButton then
            if worldMapState.titleButtonShown then
                WorldMapTitleButton:Show()
            else
                WorldMapTitleButton:Hide()
            end
        end
        if BlackoutWorld then
            if worldMapState.blackoutShown then
                BlackoutWorld:Show()
            else
                BlackoutWorld:Hide()
            end
        end
        if WorldMapFrameTitle then
            if worldMapState.frameTitleShown then
                WorldMapFrameTitle:Show()
            else
                WorldMapFrameTitle:Hide()
            end
        end
        if WorldMapFrameAreaLabel then
            if worldMapState.areaLabelShown then
                WorldMapFrameAreaLabel:Show()
            else
                WorldMapFrameAreaLabel:Hide()
            end
        end
        RestoreWorldMapDropdownArt(WorldMapContinentDropDown)
        RestoreWorldMapDropdownArt(WorldMapZoneDropDown)
        RestoreWorldMapDropdownArt(WorldMapZoneMinimapDropDown)
        RestoreWorldMapDropdownArt(WorldMapLevelDropDown)
        if WorldMapZoomOutButton and WorldMapZoomOutButton.__dcqosWorldMapChrome then
            WorldMapZoomOutButton.__dcqosWorldMapChrome:Hide()
        end
        if WorldMapFrameCloseButton and WorldMapFrameCloseButton.__dcqosWorldMapChrome then
            WorldMapFrameCloseButton.__dcqosWorldMapChrome:Hide()
        end
        if WorldMapFrameSizeUpButton and WorldMapFrameSizeUpButton.__dcqosWorldMapChrome then
            WorldMapFrameSizeUpButton.__dcqosWorldMapChrome:Hide()
        end
        if WorldMapFrameSizeDownButton and WorldMapFrameSizeDownButton.__dcqosWorldMapChrome then
            WorldMapFrameSizeDownButton.__dcqosWorldMapChrome:Hide()
        end
        if UISpecialFrames and worldMapState.addedToSpecialFrames then
            for i = #UISpecialFrames, 1, -1 do
                if UISpecialFrames[i] == "WorldMapFrame" then
                    table.remove(UISpecialFrames, i)
                end
            end
        end
        worldMapState.active = false
        worldMapState.movable = nil
        worldMapState.mouseEnabled = nil
        worldMapState.onDragStart = nil
        worldMapState.onDragStop = nil
        worldMapState.parent = nil
        worldMapState.clampedToScreen = nil
        worldMapState.point = nil
        worldMapState.width = nil
        worldMapState.height = nil
        worldMapState.scale = nil
        worldMapState.standalonePoint = nil
        worldMapState.addedToSpecialFrames = false
        worldMapState.titleButtonShown = nil
        worldMapState.blackoutShown = nil
        worldMapState.panelLayoutEnabled = nil
        worldMapState.uiPanelWindow = nil
        worldMapState.rootTextureStates = nil
        worldMapState.frameTitleShown = nil
        worldMapState.areaLabelShown = nil
        worldMapState.controlPoints = nil
    end

    if minimapState.active and Minimap then
        if Minimap.EnableMouseWheel and minimapState.mouseWheelEnabled ~= nil then
            Minimap:EnableMouseWheel(minimapState.mouseWheelEnabled)
        end
        if Minimap.SetScript then
            Minimap:SetScript("OnMouseWheel", minimapState.onMouseWheel)
        end
        if MinimapZoomIn then
            if minimapState.zoomInShown then MinimapZoomIn:Show() else MinimapZoomIn:Hide() end
        end
        if MinimapZoomOut then
            if minimapState.zoomOutShown then MinimapZoomOut:Show() else MinimapZoomOut:Hide() end
        end
        minimapState.active = false
        minimapState.mouseWheelEnabled = nil
        minimapState.onMouseWheel = nil
        minimapState.zoomInShown = nil
        minimapState.zoomOutShown = nil
    end

    if buffFrameState.active then
        buffFrameState.active = false
        RestoreBuffFramePosition()
    end

    if type(QuestLog_Update) == "function" then
        pcall(QuestLog_Update)
    end
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function Interface.CreateSettings(parent)
    local settings = addon.settings.interface
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Interface Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure interface enhancements and UI modifications.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- Combat Section
    -- ============================================================
    local combatHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    combatHeader:SetPoint("TOPLEFT", 16, yOffset)
    combatHeader:SetText("Combat")
    yOffset = yOffset - 25
    
    -- Combat Nameplates
    local combatPlatesCb = addon:CreateCheckbox(parent)
    combatPlatesCb:SetPoint("TOPLEFT", 16, yOffset)
    combatPlatesCb.Text:SetText("Show Enemy Nameplates in Combat Only")
    combatPlatesCb:SetChecked(settings.combatPlates)
    combatPlatesCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.combatPlates", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Quest Section
    -- ============================================================
    local questHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    questHeader:SetPoint("TOPLEFT", 16, yOffset)
    questHeader:SetText("Quests")
    yOffset = yOffset - 25
    
    -- Auto Quest Watch
    local autoQuestCb = addon:CreateCheckbox(parent)
    autoQuestCb:SetPoint("TOPLEFT", 16, yOffset)
    autoQuestCb.Text:SetText("Auto-add Quests to Watch List")
    autoQuestCb:SetChecked(settings.autoQuestWatch)
    autoQuestCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.autoQuestWatch", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 25

    -- ============================================================
    -- Camera Section
    -- ============================================================
    local cameraHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cameraHeader:SetPoint("TOPLEFT", 16, yOffset)
    cameraHeader:SetText("Camera")
    yOffset = yOffset - 25

    local zoomCb = addon:CreateCheckbox(parent)
    zoomCb:SetPoint("TOPLEFT", 16, yOffset)
    zoomCb.Text:SetText("Allow further camera zoom out")
    zoomCb:SetChecked(settings.extendedCameraZoom)
    zoomCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.extendedCameraZoom", self:GetChecked())
        ApplyCameraZoomDistance()
    end)
    yOffset = yOffset - 30

    local zoomSlider = addon:CreateSlider(parent)
    zoomSlider:SetPoint("TOPLEFT", 16, yOffset)
    zoomSlider:SetWidth(220)
    zoomSlider:SetMinMaxValues(1, 4)
    zoomSlider:SetValueStep(0.1)
    zoomSlider.Text:SetText("Camera Max Zoom Factor")
    zoomSlider.Low:SetText("1.0")
    zoomSlider.High:SetText("4.0")
    zoomSlider:SetValue(GetClampedZoomFactor(settings.maxZoomFactor))
    zoomSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = GetClampedZoomFactor(value)
        if self._dcqosLastValue == rounded then return end
        self._dcqosLastValue = rounded
        addon:SetSetting("interface.maxZoomFactor", rounded)
        if settings.extendedCameraZoom then
            ApplyCameraZoomDistance()
        end
    end)
    yOffset = yOffset - 55

    -- ============================================================
    -- Buff/Aura Frame Section
    -- ============================================================
    local auraHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    auraHeader:SetPoint("TOPLEFT", 16, yOffset)
    auraHeader:SetText("Buff/Aura Frame")
    yOffset = yOffset - 25

    local moveBuffCb = addon:CreateCheckbox(parent)
    moveBuffCb:SetPoint("TOPLEFT", 16, yOffset)
    moveBuffCb.Text:SetText("Move Buff/Aura frame")
    moveBuffCb:SetChecked(settings.buffFrameMove)
    moveBuffCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.buffFrameMove", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 30

    local offsetXSlider = addon:CreateSlider(parent)
    offsetXSlider:SetPoint("TOPLEFT", 16, yOffset)
    offsetXSlider:SetWidth(200)
    offsetXSlider:SetMinMaxValues(-400, 200)
    offsetXSlider:SetValueStep(5)
    offsetXSlider.Text:SetText("Buff Frame X Offset")
    offsetXSlider.Low:SetText("-400")
    offsetXSlider.High:SetText("200")
    offsetXSlider:SetValue(settings.buffFrameOffsetX or 0)
    offsetXSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("interface.buffFrameOffsetX", math.floor(value + 0.5))
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 50

    local offsetYSlider = addon:CreateSlider(parent)
    offsetYSlider:SetPoint("TOPLEFT", 16, yOffset)
    offsetYSlider:SetWidth(200)
    offsetYSlider:SetMinMaxValues(-200, 200)
    offsetYSlider:SetValueStep(5)
    offsetYSlider.Text:SetText("Buff Frame Y Offset")
    offsetYSlider.Low:SetText("-200")
    offsetYSlider.High:SetText("200")
    offsetYSlider:SetValue(settings.buffFrameOffsetY or 0)
    offsetYSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("interface.buffFrameOffsetY", math.floor(value + 0.5))
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 50
    
    -- Quest Level Text
    local questLevelCb = addon:CreateCheckbox(parent)
    questLevelCb:SetPoint("TOPLEFT", 16, yOffset)
    questLevelCb.Text:SetText("Show Quest Levels in Quest Log")
    questLevelCb:SetChecked(settings.questLevelText)
    questLevelCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.questLevelText", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Appearance Section
    -- ============================================================
    local appearanceHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    appearanceHeader:SetPoint("TOPLEFT", 16, yOffset)
    appearanceHeader:SetText("Appearance")
    yOffset = yOffset - 25
    
    -- Hide Gryphons
    local hideGryphonsCb = addon:CreateCheckbox(parent)
    hideGryphonsCb:SetPoint("TOPLEFT", 16, yOffset)
    hideGryphonsCb.Text:SetText("Hide Action Bar Gryphons")
    hideGryphonsCb:SetChecked(settings.hideGryphons)
    hideGryphonsCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.hideGryphons", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 25
    
    -- Larger World Map
    local largerMapCb = addon:CreateCheckbox(parent)
    largerMapCb:SetPoint("TOPLEFT", 16, yOffset)
    largerMapCb.Text:SetText("Standalone Large World Map")
    largerMapCb:SetChecked(settings.largerWorldMap)
    largerMapCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.largerWorldMap", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Info Section
    -- ============================================================
    local infoHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    infoHeader:SetPoint("TOPLEFT", 16, yOffset)
    infoHeader:SetText("Minimap")
    yOffset = yOffset - 25
    
    local minimapInfo = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    minimapInfo:SetPoint("TOPLEFT", 16, yOffset)
    minimapInfo:SetText("• Mouse scroll to zoom minimap\n• Zoom buttons are automatically hidden")
    minimapInfo:SetTextColor(0.7, 0.7, 0.7)
    minimapInfo:SetJustifyH("LEFT")
    
    return yOffset - 60
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("Interface", Interface)
