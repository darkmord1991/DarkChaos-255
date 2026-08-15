-- DC-MythicPlus DeathPins.lua
--
-- World-map death markers for the active Mythic+ run, split out of Core.lua.
--
-- Core.lua sits close to Lua 5.1's hard limit of 200 file-scope locals, and
-- this block was eight of them (ActiveWorldMapId, WorldMapParent, deathPins,
-- DestroyDeathPin, AcquireDeathPin, UpdateDeathPinsInternal, deathPinWatcher,
-- deathPinTicker). None of them were referenced anywhere else.
--
-- Reads namespace.runTracker for the active run's death locations; exports
-- namespace.ScheduleDeathPinUpdate(), which Core.lua already called through the
-- namespace rather than directly.

local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

local function ActiveWorldMapId()
    if WorldMapFrame then
        if WorldMapFrame.GetMapID then
            local ok, mapId = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
            if ok and mapId and mapId ~= 0 then
                return mapId
            end
        end
        if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetMapID then
            local ok, mapId = pcall(WorldMapFrame.ScrollContainer.GetMapID, WorldMapFrame.ScrollContainer)
            if ok and mapId and mapId ~= 0 then
                return mapId
            end
        end
    end
    if type(GetCurrentMapAreaID) == "function" then
        local mapId = GetCurrentMapAreaID()
        if mapId and mapId ~= 0 then
            return mapId
        end
    end
    if WorldMapFrame and WorldMapFrame.mapID and WorldMapFrame.mapID ~= 0 then
        return WorldMapFrame.mapID
    end
    return nil
end

local function WorldMapParent()
    return WorldMapButton or (WorldMapFrame and WorldMapFrame.ScrollContainer) or WorldMapFrame
end

local deathPins = {
    pins = {},
    pending = false,
    elapsed = 0,
    lastMapId = nil,
}

local function DestroyDeathPin(id)
    local pin = deathPins.pins[id]
    if not pin then
        return
    end
    pin:Hide()
    pin:SetScript("OnEnter", nil)
    pin:SetScript("OnLeave", nil)
    pin:SetParent(nil)
    deathPins.pins[id] = nil
end

local function AcquireDeathPin(id)
    local pin = deathPins.pins[id]
    if pin then
        return pin
    end
    if not WorldMapFrame then
        return nil
    end
    local parent = WorldMapParent()
    if not parent then
        return nil
    end
    pin = CreateFrame("Button", "DCMythicPlusDeathPin" .. tostring(id), parent)
    pin:SetSize(18, 18)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin.texture:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8")
    pin:SetFrameStrata("HIGH")
    pin:Hide()
    pin.deathId = id

    pin:SetScript("OnEnter", function(self)
        local entry
        local tracker = namespace.runTracker
        for _, e in ipairs(tracker and tracker.deathLocations or {}) do
            if e and e.id == self.deathId then
                entry = e
                break
            end
        end
        if not entry then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Death #" .. tostring(entry.id or "?"), 1, 0.2, 0.2)
        GameTooltip:AddLine(string.format("Victim: %s", tostring(entry.name or "?")), 1, 1, 1)

        if entry.killer and (entry.killer.sourceName or entry.killer.spellName) then
            local killerName = entry.killer.sourceName or "Unknown"
            local spell = entry.killer.spellName or ""
            local amount = entry.killer.amount
            local extra = ""
            if amount and amount > 0 then
                extra = string.format(" (%d)", amount)
            end
            if spell ~= "" then
                GameTooltip:AddLine(string.format("Killing blow: %s - %s%s", tostring(killerName), tostring(spell), extra), 1, 0.82, 0)
            else
                GameTooltip:AddLine(string.format("Killing blow: %s%s", tostring(killerName), extra), 1, 0.82, 0)
            end
        else
            GameTooltip:AddLine("Killing blow: (unknown)", 0.8, 0.8, 0.8)
        end

        if entry.elapsed then
            GameTooltip:AddLine("Time: " .. FormatSeconds(entry.elapsed), 0.7, 0.9, 1)
        end
        local place = entry.subzone and entry.subzone ~= "" and entry.subzone or entry.zone
        if place and place ~= "" then
            GameTooltip:AddLine("Location: " .. tostring(place), 0.7, 0.7, 0.9)
        end
        if entry.x and entry.y and (entry.x > 0 or entry.y > 0) then
            GameTooltip:AddLine(string.format("Coords: %.1f, %.1f", entry.x * 100, entry.y * 100), 0.7, 0.7, 0.9)
        end

        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)

    deathPins.pins[id] = pin
    return pin
end

local function UpdateDeathPinsInternal()
    if not WorldMapFrame or not (WorldMapFrame.IsShown and WorldMapFrame:IsShown()) then
        for _, pin in pairs(deathPins.pins) do
            pin:Hide()
        end
        return
    end

    -- Only show pins for the currently active run. Resolved through the
    -- namespace because runTracker is owned by Core.lua, which loads after this
    -- file; a nil check keeps an early WORLD_MAP_UPDATE from erroring.
    local runTracker = namespace.runTracker
    if not runTracker or not runTracker.active or not runTracker.runKey then
        for _, pin in pairs(deathPins.pins) do
            pin:Hide()
        end
        return
    end

    local parent = WorldMapParent()
    if not parent then
        return
    end

    local activeMapId = ActiveWorldMapId()
    if activeMapId == deathPins.lastMapId and not deathPins.forceUpdate then
        return
    end
    deathPins.lastMapId = activeMapId
    deathPins.forceUpdate = nil

    local shown = {}
    local shownCount = 0
    local maxPins = 30
    for i = 1, #runTracker.deathLocations do
        local e = runTracker.deathLocations[i]
        if e and e.id and e.runKey == runTracker.runKey and e.mapId and tonumber(e.mapId) == tonumber(activeMapId) and e.x and e.y and (e.x > 0 or e.y > 0) then
            local pin = AcquireDeathPin(e.id)
            if pin then
                local px = e.x * (parent:GetWidth() or 0)
                local py = e.y * (parent:GetHeight() or 0)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", parent, "TOPLEFT", px, -py)
                pin:Show()
                shown[e.id] = true
                shownCount = shownCount + 1
                if shownCount >= maxPins then
                    break
                end
            end
        end
    end

    for id, pin in pairs(deathPins.pins) do
        if not shown[id] then
            pin:Hide()
        end
    end
end

function namespace.ScheduleDeathPinUpdate()
    deathPins.pending = true
    deathPins.elapsed = 0
    deathPins.forceUpdate = true
end

local deathPinWatcher = CreateFrame("Frame")
deathPinWatcher:RegisterEvent("WORLD_MAP_UPDATE")
deathPinWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
deathPinWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
deathPinWatcher:SetScript("OnEvent", function()
    namespace.ScheduleDeathPinUpdate()
end)

if WorldMapFrame and WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow", function() namespace.ScheduleDeathPinUpdate() end)
    WorldMapFrame:HookScript("OnSizeChanged", function() namespace.ScheduleDeathPinUpdate() end)
end

local deathPinTicker = CreateFrame("Frame")
deathPinTicker:SetScript("OnUpdate", function(_, elapsed)
    if not deathPins.pending then
        return
    end
    deathPins.elapsed = deathPins.elapsed + elapsed
    if deathPins.elapsed >= 0.1 then
        deathPins.elapsed = 0
        deathPins.pending = false
        UpdateDeathPinsInternal()
    end
end)
