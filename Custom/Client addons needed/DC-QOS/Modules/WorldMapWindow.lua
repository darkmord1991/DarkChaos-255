-- ============================================================
-- DC-QoS: World Map Window (combined map + quest log, Mapster-based)
-- ============================================================
-- A single, self-contained owner of the combined world-map view, built on the
-- PROVEN Mapster technique: turn WorldMapFrame into a movable, top-level window
-- ONCE (at login, while hidden), put it in the stock QUEST-MAP view (map + quest
-- list + details on the parchment), and scale the WHOLE frame uniformly. Retail
-- enhancements layer on top of this stable base.
--
-- HARD RULE: this module NEVER touches the client's SetupFullscreenScale. That
-- function is load-bearing inside WorldMapFrame_OnShow (it displays/scales the
-- map). A previous version no-op'd it and left the map open-but-invisible while
-- the UI hid -- unusable. By leaving it alone, the WORST case here is the map
-- stays fullscreen (still fully functional); it can never break the UI again.
-- Our OnShow hook runs AFTER the stock handler, so our windowed geometry wins.
--
-- This module OWNS the map. The old Interface.lua takeover is retired (no-op).
-- ============================================================

local addon = DCQOS
if not addon then
    return
end

local WorldMapWindow = {
    displayName = "World Map Window",
    settingKey = "worldMapWindow",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
    defaults = {
        worldMapWindow = {
            enabled = true,
            topInset = 28,       -- px reserved below the info bar
            bottomInset = 120,   -- px reserved above the action bars
            scale = nil,         -- user scale override; nil = auto-fit to the band
            point = nil,         -- saved drag position {p, x, y}
        },
    },
}

local QUESTLIST_SIZE = 0.691
local FRAME_W, FRAME_H = 1024, 768

local state = {
    active = false,
    setup = false,       -- one-time windowing done
    reapplying = false,
    eventFrame = nil,
    blobWasShown = nil,
}

local function GetSettings()
    return (addon.settings and addon.settings.worldMapWindow)
        or WorldMapWindow.defaults.worldMapWindow
end

local function IsEnabled()
    local s = GetSettings()
    return s and s.enabled ~= false
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function SafeSetCVar(name, value)
    if type(SetCVar) == "function" then
        pcall(SetCVar, name, value)
    end
end

-- ---------------------------------------------------------------- fit scale

-- Top inset in UIParent units: directly below the DC info bar when it is
-- shown (the window docks under it), else the configured fallback.
local function GetTopInset()
    local s = GetSettings()
    local bar = _G["DCInfoBarFrame"]
    if bar and bar.GetBottom and (not bar.IsShown or bar:IsShown()) and UIParent then
        local bottom = bar:GetBottom()
        local uiTop = UIParent.GetTop and UIParent:GetTop()
        if bottom and uiTop then
            local barScale = bar.GetEffectiveScale and bar:GetEffectiveScale() or 1
            local uiScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
            local inset = uiTop - (bottom * barScale / uiScale)
            if inset >= 0 and inset <= 120 then
                return inset
            end
        end
    end
    return s.topInset
end

-- Height available between the info bar (top) and the bottom action bars.
local function GetBandHeight()
    local s = GetSettings()
    local uiH = (UIParent and UIParent:GetHeight()) or 768
    local topInset = GetTopInset()
    local barTop = 0
    for _, nm in ipairs({ "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight" }) do
        local f = _G[nm]
        if f and f.GetTop and (not f.IsShown or f:IsShown()) then
            local t = f:GetTop()
            if t and t > barTop then barTop = t end
        end
    end
    local bottom = (barTop > 0) and barTop or s.bottomInset
    if bottom < 60 then bottom = 60 elseif bottom > 260 then bottom = 260 end
    local h = uiH - topInset - bottom
    if h < 200 then h = uiH - topInset - s.bottomInset end
    return h
end

-- Whole-frame scale: fit the 768-tall layout into the band, never upscaling past
-- 1.0 (the native art size). A user override wins if set.
local function GetWindowScale()
    local s = GetSettings()
    if s.scale and s.scale > 0 then
        return s.scale
    end
    local fit = GetBandHeight() / FRAME_H
    if fit < 0.55 then fit = 0.55 elseif fit > 1.0 then fit = 1.0 end
    return fit
end

-- ------------------------------------------------------------- windowing

local onShowHooked = false

-- Mapster SizeUp: the stock quest-map view -- map on the left, quest list on the
-- right, details/rewards on the parchment book. Every canvas element at
-- QUESTLIST_SIZE (the designed quest-view state; pins stay aligned).
local function ApplyQuestView()
    if not WorldMapFrame or InCombat() then
        return
    end

    if WORLDMAP_SETTINGS then
        WORLDMAP_SETTINGS.size = QUESTLIST_SIZE
    end

    WorldMapFrame:SetWidth(FRAME_W)
    WorldMapFrame:SetHeight(FRAME_H)

    if WorldMapPositioningGuide then
        WorldMapPositioningGuide:ClearAllPoints()
        WorldMapPositioningGuide:SetPoint("CENTER")
    end
    if WorldMapDetailFrame then
        WorldMapDetailFrame:SetScale(QUESTLIST_SIZE)
        WorldMapDetailFrame:ClearAllPoints()
        WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -726, -99)
    end
    if WorldMapButton then WorldMapButton:SetScale(QUESTLIST_SIZE) end
    if WorldMapFrameAreaFrame then WorldMapFrameAreaFrame:SetScale(QUESTLIST_SIZE) end
    if WorldMapBlobFrame then
        WorldMapBlobFrame:SetScale(QUESTLIST_SIZE)
        WorldMapBlobFrame.xRatio = nil
    end

    for _, nm in ipairs({
        "WorldMapZoneMinimapDropDown", "WorldMapZoomOutButton", "WorldMapZoneDropDown",
        "WorldMapContinentDropDown", "WorldMapQuestScrollFrame", "WorldMapQuestDetailScrollFrame",
        "WorldMapQuestRewardScrollFrame",
    }) do
        local f = _G[nm]
        if f and f.Show then f:Show() end
    end
    for _, nm in ipairs({ "WorldMapFrameMiniBorderLeft", "WorldMapFrameMiniBorderRight",
        "WorldMapFrameSizeUpButton" }) do
        local f = _G[nm]
        if f and f.Hide then f:Hide() end
    end
    if WorldMapFrameSizeDownButton then WorldMapFrameSizeDownButton:Hide() end

    if WorldMapLevelDropDown and WorldMapPositioningGuide then
        WorldMapLevelDropDown:SetPoint("TOPRIGHT", WorldMapPositioningGuide, "TOPRIGHT", -50, -35)
        if WorldMapLevelDropDown.header then WorldMapLevelDropDown.header:Show() end
    end
    if WorldMapFrameCloseButton and WorldMapPositioningGuide then
        WorldMapFrameCloseButton:ClearAllPoints()
        WorldMapFrameCloseButton:SetPoint("TOPRIGHT", WorldMapPositioningGuide, 4, 4)
    end
    if WorldMapTrackQuest and WorldMapPositioningGuide then
        WorldMapTrackQuest:ClearAllPoints()
        WorldMapTrackQuest:SetPoint("BOTTOMLEFT", WorldMapPositioningGuide, "BOTTOMLEFT", 16, 4)
    end
    if WorldMapFrameTitle then
        WorldMapFrameTitle:ClearAllPoints()
        WorldMapFrameTitle:SetPoint("CENTER", 0, 372)
    end

    if type(WorldMapFrame_SetPOIMaxBounds) == "function" then
        pcall(WorldMapFrame_SetPOIMaxBounds)
    end
end

-- Whole-frame scale + position.
local function ApplyScaleAndPosition()
    if not WorldMapFrame or InCombat() then
        return
    end
    local scale = GetWindowScale()
    WorldMapFrame:SetScale(scale)
    WorldMapFrame:ClearAllPoints()
    local saved = GetSettings().point
    if saved and saved.p then
        WorldMapFrame:SetPoint(saved.p, UIParent, saved.p, saved.x or 0, saved.y or 0)
    else
        -- Dock directly under the info bar. SetPoint offsets are in the
        -- frame's own scaled space, hence the division.
        WorldMapFrame:SetPoint("TOP", UIParent, "TOP", 0, -(GetTopInset() + 2) / scale)
    end
end

-- Re-assert our windowed layout. Runs after the stock OnShow (which calls the
-- client's SetupFullscreenScale) and after any view switch, so ours wins.
local function Reapply()
    if not state.active or state.reapplying or not WorldMapFrame then
        return
    end
    if not (WorldMapFrame.IsShown and WorldMapFrame:IsShown()) then
        return
    end
    if InCombat() then
        return
    end
    state.reapplying = true
    ApplyQuestView()
    ApplyScaleAndPosition()
    state.reapplying = false
end

-- The zone map (WorldMapDetailTile1..12) is a 4x3 grid of 256px tiles =
-- 1024x768, but the canvas is only 1002x668: Blizzard-format zone BLPs pad
-- the last 22px column / 100px row with opaque black. The stock map hid that
-- overhang inside its black surround; on this client's parchment/book art it
-- hangs past the map's bottom/right edge as black bars covering the quest
-- book and list. Crop the padding off the edge tiles (safe: no tile anchors
-- to an edge tile's far side). Sizes/texcoords survive SetTexture, so once
-- at setup is enough.
local function CropDetailTilePadding()
    for i = 1, 12 do
        local tile = _G["WorldMapDetailTile" .. i]
        if tile and tile.SetTexCoord then
            local w = (i % 4 == 0) and 234 or 256
            local h = (i > 8) and 156 or 256
            tile:SetWidth(w)
            tile:SetHeight(h)
            tile:SetTexCoord(0, w / 256, 0, h / 256)
        end
    end
end

-- One-time: make WorldMapFrame a movable, top-level window (Mapster's OnEnable
-- sequence). Done while the frame is hidden to avoid corrupting the show. Never
-- touches SetupFullscreenScale.
local function SetupWindow()
    if state.setup or not WorldMapFrame or InCombat() then
        return
    end

    SafeSetCVar("miniWorldMap", 0)
    SafeSetCVar("advancedWorldMap", 0)

    local vis = WorldMapFrame:IsVisible()
    if vis and type(HideUIPanel) == "function" then
        HideUIPanel(WorldMapFrame)
    end

    if UIPanelWindows then
        UIPanelWindows["WorldMapFrame"] = nil
    end
    if WorldMapFrame.SetAttribute then
        pcall(WorldMapFrame.SetAttribute, WorldMapFrame, "UIPanelLayout-enabled", false)
    end

    if BlackoutWorld then BlackoutWorld:Hide() end
    if WorldMapTitleButton then WorldMapTitleButton:Hide() end

    CropDetailTilePadding()

    -- Release keyboard capture so chat opens while the map is up (ESC still
    -- closes via UISpecialFrames).
    if WorldMapFrame.EnableKeyboard then
        WorldMapFrame:EnableKeyboard(false)
    end

    WorldMapFrame:SetMovable(true)
    WorldMapFrame:RegisterForDrag("LeftButton")
    WorldMapFrame:SetScript("OnDragStart", function(self)
        if self.StartMoving then self:StartMoving() end
    end)
    WorldMapFrame:SetScript("OnDragStop", function(self)
        if self.StopMovingOrSizing then self:StopMovingOrSizing() end
        local p, _, _, x, y = self:GetPoint(1)
        if p then
            GetSettings().point = { p = p, x = x, y = y }
        end
    end)

    WorldMapFrame:SetParent(UIParent)
    WorldMapFrame:SetToplevel(true)
    WorldMapFrame:SetWidth(FRAME_W)
    WorldMapFrame:SetHeight(FRAME_H)
    if WorldMapFrame.SetClampedToScreen then
        WorldMapFrame:SetClampedToScreen(false)
    end

    if not onShowHooked and type(WorldMapFrame.HookScript) == "function" then
        WorldMapFrame:HookScript("OnShow", function()
            if state.active then Reapply() end
        end)
        onShowHooked = true
    end

    -- ESC closes.
    if UISpecialFrames then
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "WorldMapFrame" then found = true break end
        end
        if not found then tinsert(UISpecialFrames, "WorldMapFrame") end
    end

    state.setup = true

    if vis and type(ShowUIPanel) == "function" then
        ShowUIPanel(WorldMapFrame)
    end
end

-- ---------------------------------------------------------------- combat

-- WorldMapBlobFrame's hit-area math can taint/error while the map updates in
-- combat with a reparented frame; park it off-panel during combat (Mapster's
-- proven guard) and restore after.
local function OnRegenDisabled()
    if not state.active or not WorldMapBlobFrame then return end
    state.blobWasShown = WorldMapBlobFrame:IsShown()
    WorldMapBlobFrame:SetParent(nil)
    WorldMapBlobFrame:ClearAllPoints()
    WorldMapBlobFrame:SetPoint("TOP", UIParent, "BOTTOM")
    WorldMapBlobFrame:Hide()
end

local function OnRegenEnabled()
    if not state.active or not WorldMapBlobFrame then return end
    WorldMapBlobFrame:SetParent(WorldMapFrame)
    WorldMapBlobFrame:ClearAllPoints()
    if WorldMapDetailFrame then
        WorldMapBlobFrame:SetPoint("TOPLEFT", WorldMapDetailFrame)
    end
    if state.blobWasShown then WorldMapBlobFrame:Show() end
    state.blobWasShown = nil
end

local function InstallViewHooks()
    if type(hooksecurefunc) ~= "function" then
        return
    end
    for _, fn in ipairs({ "WorldMapFrame_SetFullMapView", "WorldMapFrame_SetQuestMapView" }) do
        if type(_G[fn]) == "function" then
            hooksecurefunc(fn, function()
                if state.active and not state.reapplying then Reapply() end
            end)
        end
    end
end

-- ---------------------------------------------------------------- lifecycle

function WorldMapWindow.OnEnable()
    if not IsEnabled() or not WorldMapFrame then
        return
    end
    state.active = true

    -- v2 layout: the default anchor moved from screen-centre to "docked under
    -- the info bar". Old saved drag points would pin the window to the old
    -- default, so clear them once.
    local s = GetSettings()
    if s.layoutVersion ~= 2 then
        s.layoutVersion = 2
        s.point = nil
    end

    SetupWindow()
    InstallViewHooks()

    if not state.eventFrame then
        state.eventFrame = CreateFrame("Frame")
        state.eventFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_DISABLED" then
                OnRegenDisabled()
            elseif event == "PLAYER_REGEN_ENABLED" then
                OnRegenEnabled()
            end
        end)
    end
    state.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    state.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    if WorldMapFrame.IsShown and WorldMapFrame:IsShown() then
        Reapply()
    end
end

function WorldMapWindow.OnDisable()
    state.active = false
    if state.eventFrame then
        state.eventFrame:UnregisterAllEvents()
    end
end

function WorldMapWindow.CreateSettings(parent)
    local settings = GetSettings()

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("World Map Window")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(460)
    desc:SetJustifyH("LEFT")
    desc:SetText("Combined, movable world map: map + quest list + details in one window (Mapster-based). Drag to move; size auto-fits between your info bar and action bars. Requires /reload after toggling.")

    local yOffset = -76
    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable combined world-map window")
    enabledCb:SetChecked(settings.enabled ~= false)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("worldMapWindow.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 34

    local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 22)
    resetBtn:SetPoint("TOPLEFT", 16, yOffset)
    resetBtn:SetText("Reset map position")
    resetBtn:SetScript("OnClick", function()
        GetSettings().point = nil
        if state.active and WorldMapFrame and WorldMapFrame:IsShown() then
            Reapply()
        end
    end)

    return yOffset - 50
end

addon:RegisterModule("WorldMapWindow", WorldMapWindow)
