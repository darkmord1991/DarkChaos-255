-- ============================================================
-- DC-QoS: World Map Window (clean combined map + quest log)
-- ============================================================
-- A single, self-contained owner of the combined world-map view. Retail-look:
-- the map, the quest list and the quest details sit together in one movable,
-- auto-fitting window -- the stock 3.3.5 QUEST-MAP view, scaled as ONE unit.
--
-- Why this is clean (and the earlier per-element approach was not): we scale the
-- WHOLE WorldMapFrame uniformly (the proven Mapster technique) and let the stock
-- quest-map layout assemble itself on the parchment. Every piece (map canvas,
-- quest column, details book, POI pins, player arrow) keeps its native
-- relationship, so nothing drifts, overflows, or leaves a black band. The map
-- fills the parchment because the parchment frame textures ARE the background.
--
-- This module OWNS the world map. The old standalone-map code in Interface.lua is
-- disabled (SetupLargerWorldMap is a no-op) so the two never fight.
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
            topInset = 28,      -- px reserved below the info bar
            bottomInset = 110,  -- px reserved above the action bars
            maxScale = 1.15,    -- never blow the 1024x768 layout up past this
            point = nil,        -- saved drag position {p, x, y}
        },
    },
}

-- The stock quest-map view scales the canvas group by WORLDMAP_QUESTLIST_SIZE
-- (0.691). These globals exist in the client's WorldMapFrame.lua.
local QUESTLIST_SIZE = 0.691
local FRAME_W, FRAME_H = 1024, 768

local state = {
    active = false,
    windowed = false,
    hooksInstalled = false,
    reapplying = false,
    eventFrame = nil,
    origFullscreenScale = nil,
    fullscreenGuarded = false,
    -- captured stock state for teardown
    savedParent = nil,
    savedUIPanelWindow = nil,
    savedPanelEnabled = nil,
    savedMovable = nil,
    savedClamped = nil,
    savedKeyboard = nil,
    addedSpecialFrame = false,
    -- combat blob-reparent bookkeeping
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

-- ---------------------------------------------------------------- fit scale

-- Height available between the info bar (top) and the bottom action bars. Only
-- the BOTTOM bars reserve space; the vertical side bars sit on the right edge
-- and must not collapse the band.
local function GetBandHeight()
    local s = GetSettings()
    local uiH = (UIParent and UIParent:GetHeight()) or 768
    local barTop = 0
    for _, nm in ipairs({ "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight" }) do
        local f = _G[nm]
        if f and f.GetTop and (not f.IsShown or f:IsShown()) then
            local t = f:GetTop()
            if t and t > barTop then
                barTop = t
            end
        end
    end
    local bottom = (barTop > 0) and barTop or s.bottomInset
    if bottom < 60 then
        bottom = 60
    elseif bottom > 260 then
        bottom = 260
    end
    local h = uiH - s.topInset - bottom
    if h < 200 then
        h = uiH - s.topInset - s.bottomInset
    end
    return h, bottom
end

-- Scale the whole 1024x768 layout to fit the band; clamp so it never dwarfs the
-- screen on tall resolutions.
local function GetFitScale()
    local band = GetBandHeight()
    local s = band / FRAME_H
    if s < 0.55 then
        s = 0.55
    elseif s > (GetSettings().maxScale or 1.15) then
        s = GetSettings().maxScale or 1.15
    end
    return s
end

-- Centre the window in the band (nudged up so it clears the action bars). The
-- offset is in the frame's OWN scaled space, so convert screen px by the scale.
local function GetCenterOffsetY(scale)
    local _, bottom = GetBandHeight()
    local s = GetSettings()
    if scale <= 0 then scale = 1 end
    return ((bottom - s.topInset) / 2) / scale
end

-- ------------------------------------------------- fullscreen-mod neutralize

-- The client ships a native "fullscreen world map" mod: WorldMapFrame_Update
-- calls the global SetupFullscreenScale(self) whenever WORLDMAP_SETTINGS.size ~=
-- WORLDMAP_WINDOWED_SIZE, and it rescales the map to the SCREEN, fighting our
-- window. Replace it with a guarded no-op while our window owns the map.
local function GuardFullscreenScale()
    if state.fullscreenGuarded then
        return
    end
    state.fullscreenGuarded = true
    state.origFullscreenScale = rawget(_G, "SetupFullscreenScale")
    local orig = state.origFullscreenScale
    _G.SetupFullscreenScale = function(...)
        if state.active then
            return
        end
        if type(orig) == "function" then
            return orig(...)
        end
    end
end

local function UnguardFullscreenScale()
    if not state.fullscreenGuarded then
        return
    end
    _G.SetupFullscreenScale = state.origFullscreenScale
    state.origFullscreenScale = nil
    state.fullscreenGuarded = false
end

-- ------------------------------------------------------------- windowing

-- One-time: detach WorldMapFrame from the UIPanel system and make it a movable,
-- top-level window. Captures the stock state so OnDisable can restore it.
local function MakeWindowed()
    if state.windowed or not WorldMapFrame or InCombat() then
        return
    end

    if UIPanelWindows then
        state.savedUIPanelWindow = UIPanelWindows["WorldMapFrame"]
        UIPanelWindows["WorldMapFrame"] = nil
    end
    if WorldMapFrame.GetAttribute then
        state.savedPanelEnabled = WorldMapFrame:GetAttribute("UIPanelLayout-enabled")
        pcall(WorldMapFrame.SetAttribute, WorldMapFrame, "UIPanelLayout-enabled", false)
    end
    state.savedParent = WorldMapFrame:GetParent()
    state.savedMovable = WorldMapFrame:IsMovable()
    state.savedClamped = WorldMapFrame.IsClampedToScreen and WorldMapFrame:IsClampedToScreen()
    state.savedKeyboard = WorldMapFrame.IsKeyboardEnabled and WorldMapFrame:IsKeyboardEnabled()

    WorldMapFrame:SetParent(UIParent)
    WorldMapFrame:SetToplevel(true)
    WorldMapFrame:SetMovable(true)
    WorldMapFrame:EnableMouse(true)
    -- Releasing keyboard capture lets the chat edit box open while the map is up
    -- (stock enableKeyboard="true" swallowed Enter). ESC still closes via
    -- UISpecialFrames.
    if WorldMapFrame.EnableKeyboard then
        WorldMapFrame:EnableKeyboard(false)
    end
    if WorldMapFrame.SetClampedToScreen then
        WorldMapFrame:SetClampedToScreen(false)
    end
    WorldMapFrame:RegisterForDrag("LeftButton")
    WorldMapFrame:SetScript("OnDragStart", function(self)
        if self.StartMoving then self:StartMoving() end
    end)
    WorldMapFrame:SetScript("OnDragStop", function(self)
        if self.StopMovingOrSizing then self:StopMovingOrSizing() end
        -- persist position
        local p, _, _, x, y = self:GetPoint(1)
        if p then
            GetSettings().point = { p = p, x = x, y = y }
        end
    end)

    if BlackoutWorld then BlackoutWorld:Hide() end
    if WorldMapTitleButton then WorldMapTitleButton:Hide() end

    -- ESC closes the window.
    if UISpecialFrames and not state.addedSpecialFrame then
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "WorldMapFrame" then found = true break end
        end
        if not found then
            tinsert(UISpecialFrames, "WorldMapFrame")
            state.addedSpecialFrame = true
        end
    end

    state.windowed = true
end

-- The stock quest-map view: map on the left, quest list on the right, details on
-- the parchment book, all at QUESTLIST_SIZE. This is Blizzard's SizeUp path.
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

    -- show the quest-view chrome
    for _, nm in ipairs({
        "WorldMapZoneMinimapDropDown", "WorldMapZoomOutButton", "WorldMapZoneDropDown",
        "WorldMapContinentDropDown", "WorldMapQuestScrollFrame", "WorldMapQuestDetailScrollFrame",
        "WorldMapQuestRewardScrollFrame",
    }) do
        local f = _G[nm]
        if f and f.Show then f:Show() end
    end
    -- hide the mini-window chrome + BOTH fullscreen/mini size toggles (this is the
    -- one canonical view; the stock toggles would tear the windowed layout apart)
    for _, nm in ipairs({ "WorldMapFrameMiniBorderLeft", "WorldMapFrameMiniBorderRight",
        "WorldMapFrameSizeUpButton", "WorldMapFrameSizeDownButton" }) do
        local f = _G[nm]
        if f and f.Hide then f:Hide() end
    end

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

    -- hide the fullscreen-only "-full" patch tiles (13..18); keep map tiles 1..12
    if NUM_WORLDMAP_DETAIL_TILES and NUM_WORLDMAP_PATCH_TILES then
        for i = NUM_WORLDMAP_DETAIL_TILES + 1, NUM_WORLDMAP_DETAIL_TILES + NUM_WORLDMAP_PATCH_TILES do
            local t = _G["WorldMapFrameTexture" .. i]
            if t and t.Hide then t:Hide() end
        end
    end

    if type(WorldMapFrame_SetPOIMaxBounds) == "function" then
        pcall(WorldMapFrame_SetPOIMaxBounds)
    end
end

-- Scale + position the WHOLE window so the 1024x768 quest-map layout fits the
-- band. Uniform scale keeps every element aligned.
local function ApplyWindowTransform()
    if not WorldMapFrame or InCombat() then
        return
    end
    local scale = GetFitScale()
    WorldMapFrame:SetScale(scale)

    WorldMapFrame:ClearAllPoints()
    local saved = GetSettings().point
    if saved and saved.p then
        WorldMapFrame:SetPoint(saved.p, UIParent, saved.p, saved.x or 0, saved.y or 0)
    else
        WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, GetCenterOffsetY(scale))
    end
end

local function ApplyAll()
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
    MakeWindowed()
    ApplyQuestView()
    ApplyWindowTransform()
    state.reapplying = false
end

-- ---------------------------------------------------------------- hooks

-- WorldMapBlobFrame does hit-area math on show; in combat that path can taint or
-- error while the frame is reparented, so we park it off the panel during combat
-- and restore afterward (mirrors Mapster's proven guard).
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
    if state.blobWasShown then
        WorldMapBlobFrame:Show()
    end
    state.blobWasShown = nil
end

local function InstallHooks()
    if state.hooksInstalled or not WorldMapFrame then
        return
    end

    if type(WorldMapFrame.HookScript) == "function" then
        WorldMapFrame:HookScript("OnShow", function()
            if state.active then
                ApplyAll()
            end
        end)
    end

    -- The stock view functions reset the canvas scale/anchor; re-assert ours
    -- after them so quest-less zones (SetFullMapView) and quest zones alike land
    -- on our windowed quest-map layout.
    if type(hooksecurefunc) == "function" then
        for _, fn in ipairs({ "WorldMapFrame_SetFullMapView", "WorldMapFrame_SetQuestMapView" }) do
            if type(_G[fn]) == "function" then
                hooksecurefunc(fn, function()
                    if state.active and not state.reapplying then
                        ApplyAll()
                    end
                end)
            end
        end
    end

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

    state.hooksInstalled = true
end

-- ---------------------------------------------------------------- lifecycle

function WorldMapWindow.OnEnable()
    if not IsEnabled() or not WorldMapFrame then
        return
    end
    state.active = true

    -- Stock branches into the mini windowed map when this CVar is set; keep off.
    if type(SetCVar) == "function" then
        pcall(SetCVar, "miniWorldMap", 0)
    end

    GuardFullscreenScale()
    InstallHooks()

    -- If the map is already open, transform it now.
    if WorldMapFrame.IsShown and WorldMapFrame:IsShown() then
        ApplyAll()
    end
end

function WorldMapWindow.OnDisable()
    state.active = false
    UnguardFullscreenScale()
    if state.eventFrame then
        state.eventFrame:UnregisterAllEvents()
    end
    -- Best-effort restore of the stock UIPanel behaviour (full restore happens on
    -- next login anyway since we only mutated runtime frame state).
    if WorldMapFrame and not InCombat() then
        if UIPanelWindows and state.savedUIPanelWindow ~= nil then
            UIPanelWindows["WorldMapFrame"] = state.savedUIPanelWindow
        end
        if WorldMapFrame.SetAttribute and state.savedPanelEnabled ~= nil then
            pcall(WorldMapFrame.SetAttribute, WorldMapFrame, "UIPanelLayout-enabled", state.savedPanelEnabled)
        end
        if state.savedKeyboard ~= nil and WorldMapFrame.EnableKeyboard then
            WorldMapFrame:EnableKeyboard(state.savedKeyboard)
        end
    end
    state.windowed = false
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
    desc:SetText("Combined, movable world map: map + quest list + details in one auto-fitting window. Drag to move; the size auto-fits between your info bar and action bars.")

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
            ApplyAll()
        end
    end)

    return yOffset - 50
end

addon:RegisterModule("WorldMapWindow", WorldMapWindow)
