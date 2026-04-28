-- ============================================================
-- DC-QoS: Quest Tracker Marker Visuals
-- ============================================================
-- Retail-style quest marker rendering extracted from QuestFrames
-- so tracker marker visuals live in a dedicated module.
-- ============================================================

local addon = DCQOS

addon.QuestTrackerMarkers = addon.QuestTrackerMarkers or {}
local Markers = addon.QuestTrackerMarkers

local DC_ADDON_BACKGROUND_TEXTURE = "Interface\\AddOns\\DC-QOS\\Textures\\Backgrounds\\FelLeather_512.tga"
local QUEST_TRACKER_TEXTURE_ROOT = "Interface\\AddOns\\DC-QOS\\Textures\\QuestTracker\\"
local QUEST_TRACKER_BUTTONS_TEXTURE = QUEST_TRACKER_TEXTURE_ROOT .. "questtrackerbuttons"
local QUEST_TRACKER_MAP_BUTTON_TEXTURE = QUEST_TRACKER_TEXTURE_ROOT .. "ui-questtracker-mapbutton"
local QUEST_TRACKER_ARROW_TEXTURE = QUEST_TRACKER_TEXTURE_ROOT .. "supertrackerarrow"
local QUEST_TRACK_BOX_TEXTURE = QUEST_TRACKER_MAP_BUTTON_TEXTURE
local QUEST_TRACK_CHECK_TEXTURE = QUEST_TRACKER_ARROW_TEXTURE
local QUEST_TRACK_PULSE_TEXTURE = QUEST_TRACKER_BUTTONS_TEXTURE
local QUEST_POI_GLOW_TEXTURE = QUEST_TRACKER_BUTTONS_TEXTURE

local function GetTrackedQuestIdFromNavigation()
    if not addon or not addon.Navigation then
        return nil
    end

    local nav = addon.Navigation
    if type(nav.GetSuperTrackedQuestID) ~= "function" then
        return nil
    end

    local ok, questId = pcall(nav.GetSuperTrackedQuestID)
    if not ok then
        return nil
    end

    questId = tonumber(questId)
    if questId and questId > 0 then
        return questId
    end

    return nil
end

function Markers.GetSuperTrackedQuestId()
    local questId = GetTrackedQuestIdFromNavigation()
    if questId then
        return questId
    end

    local api = rawget(_G, "C_SuperTrack")
    if type(api) == "table" and type(api.GetSuperTrackedQuestID) == "function" then
        local ok, value = pcall(api.GetSuperTrackedQuestID)
        value = tonumber(value)
        if ok and value and value > 0 then
            return value
        end
    end

    local getter = _G.GetSuperTrackedQuestID or _G.C_SuperTrack_GetSuperTrackedQuestID
    if type(getter) ~= "function" then
        return nil
    end

    local ok, value = pcall(getter)
    value = tonumber(value)
    if ok and value and value > 0 then
        return value
    end

    return nil
end

local function ResolveTextureRegion(textureOrButton)
    if not textureOrButton then
        return nil
    end

    if type(textureOrButton.GetObjectType) == "function" then
        local objectType = textureOrButton:GetObjectType()
        if objectType == "Texture" then
            return textureOrButton
        end

        if objectType == "Button" then
            local normal = type(textureOrButton.GetNormalTexture) == "function" and textureOrButton:GetNormalTexture() or nil
            if normal then
                return normal
            end

            if type(textureOrButton.GetRegions) == "function" then
                local regions = { textureOrButton:GetRegions() }
                for i = 1, #regions do
                    local region = regions[i]
                    if region and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture" then
                        return region
                    end
                end
            end

            if textureOrButton.poiIcon then
                return ResolveTextureRegion(textureOrButton.poiIcon)
            end
        end
    end

    if type(textureOrButton.GetNormalTexture) == "function" then
        return textureOrButton:GetNormalTexture()
    end

    return nil
end

function Markers.EnsureWorldMapQuestRowChrome(button, options)
    if not button then
        return nil
    end

    if button.__dcqosWorldQuestRowChrome then
        return button.__dcqosWorldQuestRowChrome
    end

    local opts = options or {}
    local getTitleFontString = opts.getTitleFontString
    local setHoverQuestId = opts.setHoverQuestId
    local getHoverQuestId = opts.getHoverQuestId
    local queueRefresh = opts.queueRefresh

    local chrome = CreateFrame("Frame", nil, button)
    chrome:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -1)
    chrome:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 1)
    chrome:SetFrameStrata(button:GetFrameStrata())
    chrome:SetFrameLevel(math.max((button.GetFrameLevel and button:GetFrameLevel() or 1) - 1, 0))
    chrome:EnableMouse(false)
    chrome:SetBackdrop({
        bgFile = DC_ADDON_BACKGROUND_TEXTURE,
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true,
        tileSize = 32,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    chrome:SetBackdropColor(0.05, 0.04, 0.02, 0.58)
    chrome:SetBackdropBorderColor(0.28, 0.20, 0.10, 0.22)

    local tint = chrome:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(chrome)
    tint:SetTexture("Interface\\Buttons\\WHITE8x8")
    tint:SetVertexColor(0.50, 0.32, 0.06, 0.08)
    chrome.tint = tint

    local glow = chrome:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints(chrome)
    glow:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    chrome.glow = glow

    local accent = chrome:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", chrome, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(2)
    accent:SetTexture("Interface\\Buttons\\WHITE8x8")
    accent:SetVertexColor(0.94, 0.76, 0.24, 1)
    accent:SetAlpha(0.12)
    chrome.accent = accent

    local titleFont = type(getTitleFontString) == "function" and getTitleFontString(button) or nil

    local trackBox = button:CreateTexture(nil, "ARTWORK")
    trackBox:SetSize(16, 16)
    trackBox:SetTexture(QUEST_TRACK_BOX_TEXTURE)
    trackBox:SetTexCoord(0, 1, 0, 1)
    if titleFont then
        trackBox:SetPoint("RIGHT", titleFont, "LEFT", -8, 0)
    else
        trackBox:SetPoint("LEFT", button, "LEFT", 12, 0)
    end
    chrome.trackBox = trackBox

    local trackIcon = button:CreateTexture(nil, "OVERLAY")
    trackIcon:SetSize(13, 17)
    trackIcon:SetPoint("CENTER", trackBox, "CENTER", 0, 0)
    trackIcon:SetTexture(QUEST_TRACK_CHECK_TEXTURE)
    trackIcon:SetTexCoord(0, 1, 0, 1)
    trackIcon:SetAlpha(0.34)
    chrome.trackIcon = trackIcon

    local trackPulse = button:CreateTexture(nil, "OVERLAY")
    trackPulse:SetSize(24, 24)
    trackPulse:SetPoint("CENTER", trackBox, "CENTER", 0, 0)
    trackPulse:SetTexture(QUEST_TRACK_PULSE_TEXTURE)
    trackPulse:SetBlendMode("ADD")
    trackPulse:SetAlpha(0)
    chrome.trackPulse = trackPulse

    local trackCheck = button:CreateTexture(nil, "OVERLAY")
    trackCheck:SetSize(16, 16)
    trackCheck:SetPoint("CENTER", trackBox, "CENTER", 0, 0)
    trackCheck:SetTexture(QUEST_TRACK_CHECK_TEXTURE)
    trackCheck:SetAlpha(0)
    chrome.trackCheck = trackCheck

    local completeDot = button:CreateTexture(nil, "OVERLAY")
    completeDot:SetSize(6, 6)
    completeDot:SetPoint("CENTER", trackBox, "CENTER", 0, 0)
    completeDot:SetTexture("Interface\\Buttons\\WHITE8x8")
    completeDot:SetVertexColor(0.58, 0.84, 0.42, 1)
    completeDot:SetAlpha(0)
    chrome.completeDot = completeDot

    if type(button.HookScript) == "function" then
        button:HookScript("OnEnter", function(self)
            if type(setHoverQuestId) == "function" then
                setHoverQuestId(self.questId or self.questID)
            end
        end)
        button:HookScript("OnLeave", function(self)
            if type(setHoverQuestId) == "function" then
                local questId = tonumber(self.questId or self.questID)
                local hoveredQuestId = type(getHoverQuestId) == "function" and tonumber(getHoverQuestId()) or nil
                if not questId or hoveredQuestId == questId then
                    setHoverQuestId(nil)
                end
            end
        end)
        button:HookScript("OnShow", function()
            if type(queueRefresh) == "function" then
                queueRefresh(0)
            end
        end)
        button:HookScript("OnHide", function(self)
            if type(setHoverQuestId) == "function" then
                local questId = tonumber(self.questId or self.questID)
                local hoveredQuestId = type(getHoverQuestId) == "function" and tonumber(getHoverQuestId()) or nil
                if questId and hoveredQuestId == questId then
                    setHoverQuestId(nil)
                end
            end
        end)
    end

    button.__dcqosWorldQuestRowChrome = chrome
    return chrome
end

function Markers.EnsureWorldMapQuestPoiChrome(button, options)
    local poiIcon = button and button.poiIcon or nil
    if not poiIcon then
        return nil
    end

    if button.__dcqosWorldQuestPoiChrome then
        return button.__dcqosWorldQuestPoiChrome
    end

    local opts = options or {}
    local setHoverQuestId = opts.setHoverQuestId
    local getHoverQuestId = opts.getHoverQuestId

    local parent = poiIcon.GetParent and poiIcon:GetParent() or button
    local chrome = CreateFrame("Frame", nil, parent)
    chrome:SetFrameStrata((poiIcon.GetFrameStrata and poiIcon:GetFrameStrata()) or button:GetFrameStrata())
    chrome:SetFrameLevel(math.max((poiIcon.GetFrameLevel and poiIcon:GetFrameLevel() or (button.GetFrameLevel and button:GetFrameLevel() or 1)) - 1, 0))
    chrome:EnableMouse(false)
    chrome:SetBackdrop({
        bgFile = DC_ADDON_BACKGROUND_TEXTURE,
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    chrome:SetBackdropColor(0.05, 0.04, 0.02, 0.76)
    chrome:SetBackdropBorderColor(0.28, 0.20, 0.10, 0.36)

    local glow = chrome:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints(chrome)
    glow:SetTexture(QUEST_POI_GLOW_TEXTURE)
    glow:SetTexCoord(0, 1, 0, 1)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    chrome.glow = glow

    local pulse = chrome:CreateTexture(nil, "OVERLAY")
    pulse:SetAllPoints(chrome)
    pulse:SetTexture(QUEST_POI_GLOW_TEXTURE)
    pulse:SetTexCoord(0, 1, 0, 1)
    pulse:SetBlendMode("ADD")
    pulse:SetAlpha(0)
    chrome.pulse = pulse

    local ring = chrome:CreateTexture(nil, "BORDER")
    ring:SetPoint("CENTER", chrome, "CENTER", 0, 0)
    ring:SetSize(22, 22)
    ring:SetTexture(QUEST_TRACK_BOX_TEXTURE)
    ring:SetTexCoord(0, 1, 0, 1)
    ring:SetAlpha(0.9)
    chrome.ring = ring

    local badge = chrome:CreateTexture(nil, "OVERLAY")
    badge:SetSize(13, 17)
    badge:SetPoint("CENTER", chrome, "CENTER", 0, 0)
    badge:SetTexture(QUEST_TRACK_CHECK_TEXTURE)
    badge:SetTexCoord(0, 1, 0, 1)
    badge:SetAlpha(0)
    chrome.badge = badge

    local completeDot = chrome:CreateTexture(nil, "OVERLAY")
    completeDot:SetSize(6, 6)
    completeDot:SetPoint("CENTER", chrome, "CENTER", 0, 0)
    completeDot:SetTexture("Interface\\Buttons\\WHITE8x8")
    completeDot:SetVertexColor(0.58, 0.84, 0.42, 1)
    completeDot:SetAlpha(0)
    chrome.completeDot = completeDot

    if not button.__dcqosWorldQuestPoiHooks then
        button.__dcqosWorldQuestPoiHooks = true

        local function HandleEnter()
            if type(setHoverQuestId) == "function" then
                setHoverQuestId(button.questId or button.questID)
            end
        end

        local function HandleLeave()
            if type(setHoverQuestId) == "function" then
                local questId = tonumber(button.questId or button.questID)
                local hoveredQuestId = type(getHoverQuestId) == "function" and tonumber(getHoverQuestId()) or nil
                if not questId or hoveredQuestId == questId then
                    setHoverQuestId(nil)
                end
            end
        end

        local function HandleHide()
            if type(setHoverQuestId) == "function" then
                local questId = tonumber(button.questId or button.questID)
                local hoveredQuestId = type(getHoverQuestId) == "function" and tonumber(getHoverQuestId()) or nil
                if questId and hoveredQuestId == questId then
                    setHoverQuestId(nil)
                end
            end
        end

        if type(button.HookScript) == "function" then
            button:HookScript("OnEnter", HandleEnter)
            button:HookScript("OnLeave", HandleLeave)
            button:HookScript("OnHide", HandleHide)
        end
        if type(poiIcon.HookScript) == "function" then
            poiIcon:HookScript("OnEnter", HandleEnter)
            poiIcon:HookScript("OnLeave", HandleLeave)
            poiIcon:HookScript("OnHide", HandleHide)
        end
    end

    button.__dcqosWorldQuestPoiChrome = chrome
    return chrome
end

function Markers.UpdateWorldMapQuestPoi(button, options)
    local poiIcon = button and button.poiIcon or nil
    if not poiIcon then
        return
    end

    local opts = options or {}
    local chrome = Markers.EnsureWorldMapQuestPoiChrome(button, {
        setHoverQuestId = opts.setHoverQuestId,
        getHoverQuestId = opts.getHoverQuestId,
    })
    if not chrome then
        return
    end

    local shown = poiIcon.IsShown == nil or poiIcon:IsShown()
    if not shown then
        chrome:Hide()
        return
    end

    local isTracked = opts.isTracked == true
    local isSelected = opts.isSelected == true
    local isWatched = opts.isWatched == true
    local isComplete = opts.isComplete == true
    local isHover = opts.isHover == true

    local size = math.max((poiIcon.GetWidth and poiIcon:GetWidth() or 14), (poiIcon.GetHeight and poiIcon:GetHeight() or 14)) + 10
    chrome:ClearAllPoints()
    chrome:SetPoint("CENTER", poiIcon, "CENTER", 0, 0)
    chrome:SetWidth(size)
    chrome:SetHeight(size)
    chrome:Show()

    local resolveTextureRegion = type(opts.resolveTextureRegion) == "function" and opts.resolveTextureRegion or ResolveTextureRegion
    local iconRegion = resolveTextureRegion(poiIcon)

    local borderR, borderG, borderB, borderA = 0.28, 0.20, 0.10, 0.36
    local fillAlpha = 0
    local glowAlpha = 0.06
    local pulseAlpha = 0
    local badgeAlpha = 0
    local dotAlpha = 0
    local iconR, iconG, iconB = 0.88, 0.78, 0.52
    local iconScale = 1.0

    if isTracked then
        borderR, borderG, borderB, borderA = 0.95, 0.78, 0.26, 0.84
        fillAlpha = 0
        glowAlpha = 0.52
        pulseAlpha = 0.82
        badgeAlpha = 1
        iconR, iconG, iconB = 1.0, 0.88, 0.36
        iconScale = 1.16
    elseif isSelected then
        borderR, borderG, borderB, borderA = 0.90, 0.72, 0.28, 0.68
        fillAlpha = 0
        glowAlpha = 0.28
        pulseAlpha = 0.32
        badgeAlpha = isWatched and 0.88 or 0
        iconR, iconG, iconB = 0.98, 0.84, 0.42
        iconScale = 1.10
    elseif isWatched then
        borderR, borderG, borderB, borderA = 0.74, 0.62, 0.32, 0.52
        fillAlpha = 0
        glowAlpha = 0.20
        badgeAlpha = 0.80
        iconR, iconG, iconB = 0.92, 0.80, 0.42
        iconScale = 1.06
    elseif isComplete then
        borderR, borderG, borderB, borderA = 0.44, 0.62, 0.30, 0.58
        fillAlpha = 0
        glowAlpha = 0.18
        dotAlpha = 1
        iconR, iconG, iconB = 0.66, 0.86, 0.54
        iconScale = 1.04
    end

    if isHover then
        if not isTracked and not isSelected and not isWatched and not isComplete then
            borderR, borderG, borderB, borderA = 0.84, 0.68, 0.26, 0.54
            fillAlpha = 0
            iconR, iconG, iconB = 0.96, 0.84, 0.44
            iconScale = 1.10
        end
        glowAlpha = math.max(glowAlpha, 0.24)
        pulseAlpha = math.max(pulseAlpha, 0.18)
    end

    chrome:SetBackdropColor(0.05, 0.04, 0.02, fillAlpha)
    chrome:SetBackdropBorderColor(borderR, borderG, borderB, 0)
    chrome.glow:SetVertexColor(borderR, borderG, borderB, 1)
    chrome.glow:SetAlpha(glowAlpha)
    chrome.pulse:SetVertexColor(borderR, borderG, borderB, 1)
    chrome.pulse:SetAlpha(pulseAlpha)
    if chrome.ring then
        chrome.ring:SetVertexColor(borderR, borderG, borderB, 1)
        chrome.ring:SetAlpha(0.9)
        chrome.ring:SetSize(size * iconScale, size * iconScale)
    end
    chrome.badge:SetVertexColor(borderR, borderG, borderB, 1)
    chrome.badge:SetAlpha(badgeAlpha)
    chrome.completeDot:SetAlpha(dotAlpha)

    if poiIcon.SetAlpha then
        poiIcon:SetAlpha(1)
    end

    if iconRegion and iconRegion.SetVertexColor then
        iconRegion:SetVertexColor(iconR, iconG, iconB)
    end
end
