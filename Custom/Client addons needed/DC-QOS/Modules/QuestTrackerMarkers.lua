-- ============================================================
-- DC-QoS: Quest Tracker Marker Visuals
-- ============================================================
-- Retail-style quest marker rendering extracted from QuestFrames
-- so tracker marker visuals live in a dedicated module.
-- ============================================================

local addon = DCQOS
local questTrackingUtils = type(addon.GetQuestTrackingUtils) == "function" and addon:GetQuestTrackingUtils() or nil

addon.QuestTrackerMarkers = addon.QuestTrackerMarkers or {}
local Markers = addon.QuestTrackerMarkers

local DC_ADDON_BACKGROUND_TEXTURE = "Interface\\DC\\Shared\\FelLeather_512.tga"
local QUEST_TRACKER_TEXTURE_ROOT = "Interface\\AddOns\\DC-QOS\\Textures\\QuestTracker\\"
local QUEST_TRACKER_BUTTONS_TEXTURE = QUEST_TRACKER_TEXTURE_ROOT .. "questtrackerbuttons"
local QUEST_TRACKER_MAP_BUTTON_TEXTURE = QUEST_TRACKER_TEXTURE_ROOT .. "ui-questtracker-mapbutton"
local QUEST_TRACKER_ARROW_TEXTURE = QUEST_TRACKER_TEXTURE_ROOT .. "supertrackerarrow"
local QUEST_DAILY_POI_TEXTURE = QUEST_TRACKER_TEXTURE_ROOT .. "ui-worldmap-questicon-daily"
local QUEST_TRACK_BOX_TEXTURE = QUEST_TRACKER_MAP_BUTTON_TEXTURE
local QUEST_TRACK_CHECK_TEXTURE = QUEST_TRACKER_ARROW_TEXTURE
local QUEST_TRACK_PULSE_TEXTURE = QUEST_TRACKER_BUTTONS_TEXTURE
local QUEST_POI_GLOW_TEXTURE = "Interface\\Minimap\\UI-Minimap-Ping"
local QUEST_POI_PULSE_TEXTURE = "Interface\\Minimap\\UI-Minimap-Ping-Expand"

function Markers.GetSuperTrackedQuestId()
    if questTrackingUtils and type(questTrackingUtils.GetSuperTrackedQuestId) == "function" then
        return questTrackingUtils.GetSuperTrackedQuestId()
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
                if type(self.IsMouseOver) == "function" and self:IsMouseOver() then
                    return
                end
                local poiIcon = self.poiIcon
                if poiIcon and type(poiIcon.IsMouseOver) == "function" and poiIcon:IsMouseOver() then
                    return
                end
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
    local selectQuest = opts.selectQuest

    local parent = poiIcon.GetParent and poiIcon:GetParent() or button
    local chrome = CreateFrame("Frame", nil, parent)
    chrome:SetFrameStrata((poiIcon.GetFrameStrata and poiIcon:GetFrameStrata()) or button:GetFrameStrata())
    chrome:SetFrameLevel(math.max((poiIcon.GetFrameLevel and poiIcon:GetFrameLevel() or (button.GetFrameLevel and button:GetFrameLevel() or 1)) - 1, 0))
    chrome:EnableMouse(false)

    local glow = chrome:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints(chrome)
    glow:SetTexture(QUEST_POI_GLOW_TEXTURE)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    chrome.glow = glow

    local pulse = chrome:CreateTexture(nil, "OVERLAY")
    pulse:SetAllPoints(chrome)
    pulse:SetTexture(QUEST_POI_PULSE_TEXTURE)
    pulse:SetBlendMode("ADD")
    pulse:SetAlpha(0)
    chrome.pulse = pulse

    local completeDot = chrome:CreateTexture(nil, "OVERLAY")
    completeDot:SetSize(6, 6)
    completeDot:SetPoint("CENTER", chrome, "CENTER", 0, 0)
    completeDot:SetTexture("Interface\\Buttons\\WHITE8x8")
    completeDot:SetVertexColor(0.58, 0.84, 0.42, 1)
    completeDot:SetAlpha(0)
    chrome.completeDot = completeDot

    if not button.__dcqosWorldQuestPoiHooks then
        button.__dcqosWorldQuestPoiHooks = true

        local function IsStillHoveringQuestPoi()
            return (type(button.IsMouseOver) == "function" and button:IsMouseOver())
                or (type(poiIcon.IsMouseOver) == "function" and poiIcon:IsMouseOver())
        end

        local function HandleEnter()
            if type(setHoverQuestId) == "function" then
                setHoverQuestId(button.questId or button.questID)
            end
        end

        local function HandleLeave()
            if type(setHoverQuestId) == "function" then
                if IsStillHoveringQuestPoi() then
                    return
                end
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

        local function HideStandaloneQuestDetailPanels()
            for _, frame in ipairs({ QuestLogDetailFrame, QuestLogFrame }) do
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

        local function HandleSelect(mouseButton)
            if mouseButton and mouseButton ~= "LeftButton" then
                return false
            end

            local now = (type(GetTime) == "function" and GetTime()) or 0
            if (now - (button.__dcqosWorldQuestPoiSelectAt or 0)) < 0.05 then
                return true
            end
            button.__dcqosWorldQuestPoiSelectAt = now

            if type(selectQuest) == "function" then
                selectQuest(button)
            end

            HideStandaloneQuestDetailPanels()
            if addon and type(addon.DelayedCall) == "function" then
                addon:DelayedCall(0, HideStandaloneQuestDetailPanels)
                addon:DelayedCall(0.05, HideStandaloneQuestDetailPanels)
            end

            return true
        end

        local function WrapSelectClick(frame, scriptName)
            if not frame
                or type(frame.GetScript) ~= "function"
                or type(frame.SetScript) ~= "function" then
                return false
            end

            local okGetScript, original = pcall(frame.GetScript, frame, scriptName)
            if not okGetScript then
                return false
            end
            if type(original) ~= "function" then
                return false
            end

            local wrappedKey = "__dcqosWorldQuestPoiWrapped" .. scriptName
            if frame[wrappedKey] then
                return true
            end

            local okSetScript = pcall(frame.SetScript, frame, scriptName, function(self, ...)
                local mouseButton = select(1, ...)
                if HandleSelect(mouseButton) then
                    return
                end

                return original(self, ...)
            end)
            if not okSetScript then
                return false
            end

            frame[wrappedKey] = true
            frame[wrappedKey .. "Original"] = original

            return true
        end

        local wrappedMouseUp = WrapSelectClick(button, "OnMouseUp")
        local wrappedIconMouseUp = WrapSelectClick(poiIcon, "OnMouseUp")
        local wrappedClick = wrappedMouseUp or WrapSelectClick(button, "OnClick")
        local wrappedIconClick = wrappedIconMouseUp or WrapSelectClick(poiIcon, "OnClick")

        if type(button.HookScript) == "function" then
            button:HookScript("OnEnter", HandleEnter)
            button:HookScript("OnLeave", HandleLeave)
            button:HookScript("OnHide", HandleHide)
        end
        if type(poiIcon.HookScript) == "function" then
            poiIcon:HookScript("OnEnter", HandleEnter)
            poiIcon:HookScript("OnLeave", HandleLeave)
            poiIcon:HookScript("OnHide", HandleHide)
            if not wrappedClick and not wrappedMouseUp and not wrappedIconClick and not wrappedIconMouseUp then
                pcall(poiIcon.HookScript, poiIcon, "OnMouseUp", HandleSelect)
            end
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
        selectQuest = opts.selectQuest,
    })
    if not chrome then
        return
    end

    local shown = poiIcon.IsShown == nil or poiIcon:IsShown()
    if not shown then
        if poiIcon.SetScale then
            poiIcon:SetScale(1)
        end
        chrome:Hide()
        return
    end

    local isTracked = opts.isTracked == true
    local isSelected = opts.isSelected == true
    local isWatched = opts.isWatched == true
    local isComplete = opts.isComplete == true
    local isHover = opts.isHover == true
    local isDaily = opts.isDaily == true

    local size = math.max((poiIcon.GetWidth and poiIcon:GetWidth() or 14), (poiIcon.GetHeight and poiIcon:GetHeight() or 14)) + 10
    chrome:ClearAllPoints()
    chrome:SetPoint("CENTER", poiIcon, "CENTER", 0, 0)
    chrome:SetWidth(size)
    chrome:SetHeight(size)
    chrome:Show()

    local resolveTextureRegion = type(opts.resolveTextureRegion) == "function" and opts.resolveTextureRegion or ResolveTextureRegion
    local iconRegion = resolveTextureRegion(poiIcon)
    if iconRegion then
        local currentTexture = iconRegion.GetTexture and iconRegion:GetTexture() or nil
        local shouldCaptureOriginal = currentTexture ~= QUEST_DAILY_POI_TEXTURE
            or not iconRegion.__dcqosOriginalTexture

        if shouldCaptureOriginal then
            iconRegion.__dcqosOriginalTexture = currentTexture
            if iconRegion.GetTexCoord then
                local left, right, top, bottom = iconRegion:GetTexCoord()
                iconRegion.__dcqosOriginalTexCoord = { left, right, top, bottom }
            else
                iconRegion.__dcqosOriginalTexCoord = nil
            end
        end
    end

    local borderR, borderG, borderB, borderA = 0.28, 0.20, 0.10, 0.36
    local fillAlpha = 0
    local glowAlpha = 0.06
    local pulseAlpha = 0
    local dotAlpha = 0
    local iconR, iconG, iconB = 0.88, 0.78, 0.52
    local iconScale = 1.0

    if isDaily and not isComplete then
        borderR, borderG, borderB, borderA = 0.28, 0.56, 0.92, 0.42
        glowAlpha = 0.12
        iconR, iconG, iconB = 0.56, 0.82, 1.0
    end

    if isTracked then
        if isDaily then
            borderR, borderG, borderB, borderA = 0.38, 0.72, 1.0, 0.88
            iconR, iconG, iconB = 0.72, 0.92, 1.0
        else
            borderR, borderG, borderB, borderA = 0.95, 0.78, 0.26, 0.84
            iconR, iconG, iconB = 1.0, 0.88, 0.36
        end
        fillAlpha = 0
        glowAlpha = 0.52
        pulseAlpha = 0.82
        iconScale = 1.16
    elseif isSelected then
        if isDaily then
            borderR, borderG, borderB, borderA = 0.34, 0.66, 0.96, 0.0
            iconR, iconG, iconB = 0.78, 0.94, 1.0
        else
            borderR, borderG, borderB, borderA = 0.96, 0.74, 0.22, 0.0
            iconR, iconG, iconB = 1.0, 0.78, 0.18
        end
        fillAlpha = 0
        glowAlpha = 0
        pulseAlpha = 0
        iconScale = 1.0
    elseif isWatched then
        if isDaily then
            borderR, borderG, borderB, borderA = 0.32, 0.62, 0.92, 0.56
            iconR, iconG, iconB = 0.64, 0.86, 1.0
        else
            borderR, borderG, borderB, borderA = 0.74, 0.62, 0.32, 0.52
            iconR, iconG, iconB = 0.92, 0.80, 0.42
        end
        fillAlpha = 0
        glowAlpha = 0.20
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
            iconScale = 1.0
        end
        glowAlpha = math.max(glowAlpha, 0.24)
        pulseAlpha = math.max(pulseAlpha, 0.18)
    end

    -- The extra glow/pulse ring around the native world-map POI read as a confusing
    -- "second circle" that was also centered differently from the POI number. Drop
    -- it entirely; the recolored POI number/icon is the tracked/selected indicator.
    chrome.glow:SetAlpha(0)
    chrome.pulse:SetAlpha(0)
    chrome.completeDot:SetAlpha(dotAlpha)

    if poiIcon.SetAlpha then
        poiIcon:SetAlpha(1)
    end

    if poiIcon.SetScale then
        poiIcon:SetScale(1)
    end

    chrome:SetWidth(size * iconScale)
    chrome:SetHeight(size * iconScale)

    if iconRegion and iconRegion.SetTexture then
        if isDaily and not isComplete then
            iconRegion:SetTexture(QUEST_DAILY_POI_TEXTURE)
            if iconRegion.SetTexCoord then
                iconRegion:SetTexCoord(0, 1, 0, 1)
            end
        elseif iconRegion.__dcqosOriginalTexture then
            iconRegion:SetTexture(iconRegion.__dcqosOriginalTexture)
            if iconRegion.SetTexCoord and iconRegion.__dcqosOriginalTexCoord then
                iconRegion:SetTexCoord(unpack(iconRegion.__dcqosOriginalTexCoord))
            end
        end
    end

    if iconRegion and iconRegion.SetVertexColor then
        iconRegion:SetVertexColor(iconR, iconG, iconB)
    end
end

local function SetTrackerFontColor(fontString, r, g, b)
    if not fontString then
        return
    end

    if type(fontString.SetTextColor) == "function" then
        fontString:SetTextColor(r, g, b)
    end
    if type(fontString.SetShadowOffset) == "function" then
        fontString:SetShadowOffset(1, -1)
    end
    if type(fontString.SetShadowColor) == "function" then
        fontString:SetShadowColor(0, 0, 0, 0.9)
    end
end

function Markers.EnsureWatchFrameQuestChrome(root)
    if not root then
        return nil
    end

    if root.__dcqosWatchQuestChrome then
        return root.__dcqosWatchQuestChrome
    end

    local chrome = CreateFrame("Frame", nil, root)
    chrome:SetPoint("TOPLEFT", root, "TOPLEFT", -6, 2)
    chrome:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 6, -2)
    chrome:SetFrameStrata(root:GetFrameStrata())
    chrome:SetFrameLevel(math.max((root.GetFrameLevel and root:GetFrameLevel() or 1) - 1, 0))
    chrome:EnableMouse(false)
    chrome:SetBackdrop({
        bgFile = DC_ADDON_BACKGROUND_TEXTURE,
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true,
        tileSize = 32,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    chrome:SetBackdropColor(0.05, 0.04, 0.02, 0.48)
    chrome:SetBackdropBorderColor(0.28, 0.20, 0.10, 0.18)

    local tint = chrome:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(chrome)
    tint:SetTexture("Interface\\Buttons\\WHITE8x8")
    tint:SetVertexColor(0.52, 0.34, 0.08, 0.06)
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
    accent:SetAlpha(0.10)
    chrome.accent = accent

    local trackBox = root:CreateTexture(nil, "ARTWORK")
    trackBox:SetSize(14, 14)
    trackBox:SetTexture(QUEST_TRACK_BOX_TEXTURE)
    trackBox:SetTexCoord(0, 1, 0, 1)
    chrome.trackBox = trackBox

    local trackIcon = root:CreateTexture(nil, "OVERLAY")
    trackIcon:SetSize(11, 15)
    trackIcon:SetTexture(QUEST_TRACK_CHECK_TEXTURE)
    trackIcon:SetTexCoord(0, 1, 0, 1)
    trackIcon:SetAlpha(0.24)
    chrome.trackIcon = trackIcon

    local trackPulse = root:CreateTexture(nil, "OVERLAY")
    trackPulse:SetSize(22, 22)
    trackPulse:SetTexture(QUEST_TRACK_PULSE_TEXTURE)
    trackPulse:SetBlendMode("ADD")
    trackPulse:SetAlpha(0)
    chrome.trackPulse = trackPulse

    local completeDot = root:CreateTexture(nil, "OVERLAY")
    completeDot:SetSize(6, 6)
    completeDot:SetTexture("Interface\\Buttons\\WHITE8x8")
    completeDot:SetVertexColor(0.58, 0.84, 0.42, 1)
    completeDot:SetAlpha(0)
    chrome.completeDot = completeDot

    local followLabel = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    followLabel.__dcqosTrackerMeta = true
    followLabel:SetText("Following")
    followLabel:SetTextColor(1.0, 0.88, 0.42)
    followLabel:SetShadowOffset(1, -1)
    followLabel:SetShadowColor(0, 0, 0, 0.9)
    followLabel:Hide()
    chrome.followLabel = followLabel

    local routeText = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    routeText.__dcqosTrackerMeta = true
    routeText:SetJustifyH("LEFT")
    routeText:SetTextColor(0.84, 0.92, 1.0)
    routeText:SetShadowOffset(1, -1)
    routeText:SetShadowColor(0, 0, 0, 0.85)
    routeText:SetText("")
    routeText:Hide()
    chrome.routeText = routeText

    root.__dcqosWatchQuestBullets = {}
    root.__dcqosWatchQuestExtraSpacing = 4
    root.__dcqosWatchQuestChrome = chrome
    return chrome
end

function Markers.UpdateWatchFrameQuestChrome(root, options)
    if not root then
        return
    end

    local chrome = Markers.EnsureWatchFrameQuestChrome(root)
    if not chrome then
        return
    end

    local opts = options or {}
    local titleFont = opts.titleFont
    local objectiveFonts = opts.objectiveFonts or {}
    local isTracked = opts.isTracked == true
    local isWatched = opts.isWatched == true
    local isComplete = opts.isComplete == true
    local isHover = opts.isHover == true
    local routeText = type(opts.routeText) == "string" and opts.routeText or nil

    local borderR, borderG, borderB, borderA = 0.28, 0.20, 0.10, 0.20
    local fillAlpha = 0.06
    local glowAlpha = 0.0
    local accentAlpha = 0.10
    local trackAlpha = 0.20
    local pulseAlpha = 0.0
    local dotAlpha = 0.0
    local titleR, titleG, titleB = 0.90, 0.83, 0.67
    local objectiveR, objectiveG, objectiveB = 0.72, 0.69, 0.60
    local bulletR, bulletG, bulletB = 0.66, 0.56, 0.26

    if isWatched then
        borderR, borderG, borderB, borderA = 0.48, 0.38, 0.16, 0.30
        fillAlpha = 0.08
        accentAlpha = 0.16
        trackAlpha = 0.34
        titleR, titleG, titleB = 0.95, 0.88, 0.72
        objectiveR, objectiveG, objectiveB = 0.78, 0.74, 0.64
        bulletR, bulletG, bulletB = 0.82, 0.68, 0.28
    end

    if isTracked then
        borderR, borderG, borderB, borderA = 0.92, 0.74, 0.24, 0.66
        fillAlpha = 0.10
        glowAlpha = 0.30
        accentAlpha = 0.82
        trackAlpha = 1.0
        pulseAlpha = 0.44
        titleR, titleG, titleB = 1.0, 0.92, 0.48
        objectiveR, objectiveG, objectiveB = 0.92, 0.87, 0.74
        bulletR, bulletG, bulletB = 1.0, 0.84, 0.36
    elseif isComplete then
        borderR, borderG, borderB, borderA = 0.46, 0.64, 0.34, 0.50
        fillAlpha = 0.08
        glowAlpha = 0.14
        accentAlpha = 0.24
        trackAlpha = 0.24
        titleR, titleG, titleB = 0.74, 0.95, 0.64
        objectiveR, objectiveG, objectiveB = 0.66, 0.88, 0.58
        bulletR, bulletG, bulletB = 0.58, 0.84, 0.42
        dotAlpha = 1.0
    end

    if isComplete and isTracked then
        dotAlpha = 1.0
    end

    if isHover then
        glowAlpha = math.max(glowAlpha, 0.18)
        accentAlpha = math.max(accentAlpha, 0.28)
        fillAlpha = math.max(fillAlpha, 0.09)
    end

    chrome:SetBackdropColor(0.05, 0.04, 0.02, 0.46 + fillAlpha)
    chrome:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
    chrome.tint:SetVertexColor(borderR, borderG, borderB, fillAlpha)
    chrome.glow:SetVertexColor(borderR, borderG, borderB, 1)
    chrome.glow:SetAlpha(glowAlpha)
    chrome.accent:SetWidth(isTracked and 3 or 2)
    chrome.accent:SetVertexColor(borderR, borderG, borderB, 1)
    chrome.accent:SetAlpha(accentAlpha)

    local trackAnchor = titleFont or root
    chrome.trackBox:ClearAllPoints()
    if titleFont then
        chrome.trackBox:SetPoint("RIGHT", titleFont, "LEFT", -8, 0)
    else
        chrome.trackBox:SetPoint("TOPLEFT", root, "TOPLEFT", 4, -2)
    end
    chrome.trackIcon:ClearAllPoints()
    chrome.trackIcon:SetPoint("CENTER", chrome.trackBox, "CENTER", 0, 0)
    chrome.trackIcon:SetAlpha(trackAlpha)
    chrome.trackPulse:ClearAllPoints()
    chrome.trackPulse:SetPoint("CENTER", chrome.trackBox, "CENTER", 0, 0)
    chrome.trackPulse:SetVertexColor(borderR, borderG, borderB, 1)
    chrome.trackPulse:SetAlpha(pulseAlpha)
    chrome.completeDot:ClearAllPoints()
    chrome.completeDot:SetPoint("CENTER", chrome.trackBox, "CENTER", 0, 0)
    chrome.completeDot:SetAlpha(dotAlpha)

    chrome.followLabel:ClearAllPoints()
    chrome.followLabel:SetPoint("TOPRIGHT", root, "TOPRIGHT", -4, -2)
    if isTracked then
        chrome.followLabel:Show()
    else
        chrome.followLabel:Hide()
    end

    SetTrackerFontColor(titleFont, titleR, titleG, titleB)

    local lastVisibleObjective = nil
    for i = 1, #objectiveFonts do
        local fontString = objectiveFonts[i]
        local bullet = root.__dcqosWatchQuestBullets[i]
        if not bullet then
            bullet = root:CreateTexture(nil, "ARTWORK")
            bullet:SetSize(4, 4)
            bullet:SetTexture("Interface\\Buttons\\WHITE8x8")
            root.__dcqosWatchQuestBullets[i] = bullet
        end

        if fontString and (fontString.IsShown == nil or fontString:IsShown()) then
            SetTrackerFontColor(fontString, objectiveR, objectiveG, objectiveB)
            bullet:ClearAllPoints()
            bullet:SetPoint("LEFT", fontString, "LEFT", -10, 0)
            bullet:SetVertexColor(bulletR, bulletG, bulletB, 1)
            bullet:Show()
            lastVisibleObjective = fontString
        else
            bullet:Hide()
        end
    end

    for i = #objectiveFonts + 1, #(root.__dcqosWatchQuestBullets or {}) do
        local bullet = root.__dcqosWatchQuestBullets[i]
        if bullet then
            bullet:Hide()
        end
    end

    local routeAnchor = lastVisibleObjective or titleFont or trackAnchor
    chrome.routeText:ClearAllPoints()
    chrome.routeText:SetWidth(math.max(((root.GetWidth and root:GetWidth()) or 220) - 22, 160))
    chrome.routeText:SetPoint("TOPLEFT", routeAnchor, "BOTTOMLEFT", 14, -4)

    if routeText and routeText ~= "" then
        chrome.routeText:SetText("Route: " .. routeText)
        chrome.routeText:Show()
        root.__dcqosWatchQuestExtraSpacing = 18
    else
        chrome.routeText:SetText("")
        chrome.routeText:Hide()
        root.__dcqosWatchQuestExtraSpacing = 4
    end
end
