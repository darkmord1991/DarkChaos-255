local MAP_ID_AZSHARA_CRATER = 37
-- Known textures packaged with the addon (used for one-time diagnostics)
-- lightweight addon table must be defined before any addon.* fields are used
local addon = {}
-- Known textures packaged with the addon (used for one-time diagnostics)
-- availableTextures intentionally kept minimal after cleanup; tiled Azshara files are in Textures/AzsharaCrater/
addon.availableTextures = {}
-- Include packaged AzsharaCrater BLP tiles (if present) so they can be tested directly
local azsharaBLPs = {
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater1.blp",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater2.blp",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater3.blp",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater4.blp",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater5.blp",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater6.blp",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater7.blp",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater8.blp",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater9.blp",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater10.blp",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater11.blp",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\AzsharaCrater\\AzsharaCrater12.blp",
}
DCMap_HotspotsSaved = DCMap_HotspotsSaved or {}
addon.forcedTexture = addon.forcedTexture or "auto" -- "auto", "png", "blp"
DCMapExtensionDB = DCMapExtensionDB or {}
-- Allow admin/users to override the map id for the background via saved-vars
if DCMapExtensionDB.mapId == nil then DCMapExtensionDB.mapId = MAP_ID_AZSHARA_CRATER end
-- Default to using the stitched map as the standard background unless explicitly disabled
if DCMapExtensionDB.useStitchedMap == nil then DCMapExtensionDB.useStitchedMap = true end
local function IsDebugEnabled()
    return DCMapExtensionDB and DCMapExtensionDB.debug
end
local function Timestamp()
    if type(date) == "function" then
        local ok, s = pcall(date, "%Y-%m-%d %H:%M:%S")
        if ok and s then return s end
    end
    if type(GetTime) == "function" then return tostring(GetTime()) end
    return "time-n/a"
end
-- forward declaration so the function can be referenced from early event handlers
local PrintTextureDiagnosticsOnce
-- Helper: get or create the stitched container singleton. Reuse existing global when possible
local function GetOrCreateStitchFrame(parent, cols, rows)
    local existing = _G["DCMap_StitchFrame"]
    if existing and type(existing.SetParent) == "function" then
        -- reparent safely and update stored cols/rows
        pcall(existing.SetParent, existing, parent)
        existing._cols = cols or existing._cols or 1
        existing._rows = rows or existing._rows or 1
        -- clear previous tiles to avoid duplicates
        if existing._tiles then
            for i,t in ipairs(existing._tiles) do
                if t and t.SetTexture then pcall(t.SetTexture, t, nil) end
                if t and t.Hide then pcall(t.Hide, t) end
            end
            existing._tiles = nil
        end
        existing._tiles = {}
        return existing
    end
    -- create a fresh stitch container when none exists
    local container = CreateFrame("Frame", "DCMap_StitchFrame", parent)
    -- don't assume parent sizing here; caller will SetAllPoints/SetSize as appropriate
    container._cols = cols or 1
    container._rows = rows or 1
    container._tiles = {}
    -- provide a safe Reflow placeholder; real Reflow may be assigned by caller
    function container:Reflow() end
    return container
end
-- Safe size helpers must be available before any stitch creation/ShowMapBackground calls
local function SafeGetWidth(frame, fallback)
    fallback = fallback or (UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0)
    if not frame then return fallback end
    local fn = frame.GetWidth
    if type(fn) == "function" then
        local ok, w = pcall(fn, frame)
        if ok and type(w) == "number" then return w end
    end
    return fallback
end
local function SafeGetHeight(frame, fallback)
    fallback = fallback or (UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0)
    if not frame then return fallback end
    local fn = frame.GetHeight
    if type(fn) == "function" then
        local ok, h = pcall(fn, frame)
        if ok and type(h) == "number" then return h end
    end
    return fallback
end
-- Helper: report a click on a stitched container with normalized coords and percent values
local function ReportClickToChat(frame, button)
    if not frame then return end
    if type(GetCursorPosition) ~= "function" then
        if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: click (no GetCursorPosition available)") end
        return
    end
    local x, y = GetCursorPosition()
    local uiScale = (UIParent and UIParent.GetScale and UIParent:GetScale()) or 1
    x = x / (uiScale or 1)
    y = y / (uiScale or 1)
    local left = frame.GetLeft and frame:GetLeft() or 0
    local top = frame.GetTop and frame:GetTop() or 0
    local w = SafeGetWidth(frame, 0)
    local h = SafeGetHeight(frame, 0)
    local localX = x - left
    local localY = top - y
    local nx = 0; local ny = 0
    if w and w > 0 then nx = localX / w end
    if h and h > 0 then ny = localY / h end
    local px = nx * 100; local py = ny * 100
    if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: stitched click button=%s nx=%.4f ny=%.4f (%.1f%%, %.1f%%)", tostring(button), nx or 0, ny or 0, px or 0, py or 0))
    end
end
-- Persistent map bounds for converting normalized coords to map/world coordinates.
-- Stored as DCMap_MapBounds[mapId] = { minX = <number>, minY = <number>, maxX = <number>, maxY = <number> }
DCMap_MapBounds = DCMap_MapBounds or {}
local function DCMap_SetMapBounds(mapId, minX, minY, maxX, maxY)
    if not mapId then return false end
    DCMap_MapBounds[tonumber(mapId)] = { minX = tonumber(minX) or 0, minY = tonumber(minY) or 0, maxX = tonumber(maxX) or 0, maxY = tonumber(maxY) or 0 }
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: bounds set for map %s -> minX=%s minY=%s maxX=%s maxY=%s", tostring(mapId), tostring(minX), tostring(minY), tostring(maxX), tostring(maxY)))
    end
    return true
end
local function DCMap_GetMapBounds(mapId)
    if not mapId then return nil end
    return DCMap_MapBounds[tonumber(mapId)]
end
-- Convert normalized coordinates (nx, ny in [0..1]) to map/world coordinates using stored bounds.
-- Returns mapX, mapY or nil if bounds are not available.
local function DCMap_NormalizedToMapCoords(mapId, nx, ny)
    if not nx or not ny then return nil end
    local b = DCMap_GetMapBounds(mapId)
    if not b then return nil end
    local minX, minY, maxX, maxY = b.minX, b.minY, b.maxX, b.maxY
    if not (minX and minY and maxX and maxY) then return nil end
    local mx = minX + (nx * (maxX - minX))
    local my = minY + (ny * (maxY - minY))
    return mx, my
end
-- Extend click reporting: attempt conversion to map/world coords when possible
local function ReportClickToChatWithMapCoords(frame, button)
    pcall(ReportClickToChat, frame, button)
    -- try to guess map id: prefer WorldMap current map, then configured mapId
    local mapId = nil
    if type(GetCurrentMapAreaID) == "function" then mapId = GetCurrentMapAreaID() end
    if not mapId and DCMapExtensionDB and DCMapExtensionDB.mapId then mapId = DCMapExtensionDB.mapId end
    if mapId then
        -- compute normalized coords relative to frame
        if frame then
            local x, y = GetCursorPosition()
            local uiScale = (UIParent and UIParent.GetScale and UIParent:GetScale()) or 1
            x = x / (uiScale or 1)
            y = y / (uiScale or 1)
            local left = frame.GetLeft and frame:GetLeft() or 0
            local top = frame.GetTop and frame:GetTop() or 0
            local w = SafeGetWidth(frame, 0)
            local h = SafeGetHeight(frame, 0)
            if w and h and w > 0 and h > 0 then
                local localX = x - left
                local localY = top - y
                local nx = localX / w
                local ny = localY / h
                local mx, my = DCMap_NormalizedToMapCoords(mapId, nx, ny)
                                if mx and my and IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                                    pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: converted to map coords -> map=%s x=%.4f y=%.4f", tostring(mapId), mx, my))
                                elseif not mx and IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                                    pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: no map bounds available for map %s; use /dcmap bounds set %s <minX> <minY> <maxX> <maxY>", tostring(mapId), tostring(mapId)))
                                end
            end
        end
    end
end
-- Reapply stitch container settings (reparent/resize/reflow) when options change
local function ApplyStitchSettings()
    local st = _G["DCMap_StitchFrame"]
    if not st then return end
    -- choose parent according to fullscreen flag
    local parent
    if DCMapExtensionDB and DCMapExtensionDB.fullscreen then parent = UIParent
    elseif type(WorldMapFrame) == "table" and WorldMapFrame:IsShown() and WorldMapDetailFrame then parent = WorldMapDetailFrame
    else parent = addon.background or WorldMapDetailFrame or UIParent end
    pcall(st.SetParent, st, parent)
    local scale = tonumber(DCMapExtensionDB and DCMapExtensionDB.fullscreenScale) or 1.0
    if parent == UIParent and DCMapExtensionDB and DCMapExtensionDB.fullscreen and scale and scale < 1.0 then
        local sw = SafeGetWidth(parent) or 0
        local sh = SafeGetHeight(parent) or 0
        pcall(st.SetSize, st, sw * scale, sh * scale)
        pcall(st.ClearAllPoints, st)
        pcall(st.SetPoint, st, "CENTER", UIParent, "CENTER", 0, 0)
    else
        pcall(st.SetAllPoints, st, parent)
    end
    local pLevel = (parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 0
    if st.SetFrameLevel then pcall(st.SetFrameLevel, st, pLevel + 50) end
    if DCMapExtensionDB and DCMapExtensionDB.interactable then if st.EnableMouse then pcall(st.EnableMouse, st, true) end else if st.EnableMouse then pcall(st.EnableMouse, st, false) end end
    if st.Reflow then pcall(st.Reflow, st) end
    if st.Show then pcall(st.Show, st) end
end
local function FileExists(path)
    if not WorldMapDetailFrame then return false end
    local created = false
    local tex = addon.bgTex
    if not tex then tex = WorldMapDetailFrame:CreateTexture(); created = true end
    local ok = false
    if tex and tex.SetTexture then ok = pcall(tex.SetTexture, tex, path) end
    if created and tex then tex:SetTexture(nil) end
    return ok
end
-- More detailed diagnostic: try to create a temporary texture on a safe parent and
-- SetTexture it; return status and optional error message. This distinguishes
-- between file-not-found and SetTexture rejection/failure.
local function DiagnosticCheckTexture(path)
    if not path then return false, "nil path" end
    local parent = WorldMapDetailFrame or UIParent
    local tmp = parent:CreateTexture(nil, "ARTWORK")
    local ok, err = pcall(function() tmp:SetTexture(path) end)
    -- clear the texture to avoid holding a reference
    pcall(tmp.SetTexture, tmp, nil)
    -- attempt to hide/destroy tmp by removing parent reference; we can't explicitly Destroy
    -- but nil'ing reference and letting GC handle it is sufficient in this environment.
    tmp = nil
    if ok then return true, nil end
    return false, tostring(err or "SetTexture failed")
end
local function ChooseBestTexture()
    -- After cleanup, prefer the first tiled Azshara texture if present, otherwise fall back to icon
    if azsharaBLPs and azsharaBLPs[1] and FileExists(azsharaBLPs[1]) then return azsharaBLPs[1] end
    return "Interface\\Icons\\INV_Misc_Map_01"
end
local function EnsureMapBackgroundFrame()
    if not addon.background and WorldMapDetailFrame then
        addon.background = CreateFrame("Frame", "DCMap_BackgroundFrame", WorldMapDetailFrame)
        addon.background:SetAllPoints(WorldMapDetailFrame)
        addon.bgTex = addon.background:CreateTexture(nil, "BACKGROUND")
        addon.bgTex:SetAllPoints(addon.background)
        addon.background:Hide()
        addon.background:SetFrameStrata("MEDIUM")
        local parentLevel = WorldMapDetailFrame and WorldMapDetailFrame:GetFrameLevel() or 0
        addon.background:SetFrameLevel(parentLevel + 10)
        addon.bgTex:SetBlendMode("BLEND")
        addon.bgTex:SetDrawLayer("ARTWORK", 0)
        addon.bgTex:SetTexCoord(0, 1, 0, 1)
    end
    if addon.bgTex then
        local chosen = ChooseBestTexture()
        -- Try to actually set the texture; if it fails, fall back and inform in chat
    -- Clear any previously-set texture to force the client to rebind/decoding path
    if addon.bgTex and addon.bgTex.SetTexture then pcall(addon.bgTex.SetTexture, addon.bgTex, nil) end
    -- reset cached current bg path so we actually re-evaluate the texture
    addon._currentBgPath = nil
        local function trySetTexture(path)
            if not path then return false end
            if not (addon.bgTex and addon.bgTex.SetTexture) then return false end
            -- avoid repeating the same diagnostic work if we've already applied this path
            if addon._currentBgPath == path then return true end
            -- use function wrapper so pcall returns (ok, err)
            local ok, err = pcall(function() addon.bgTex:SetTexture(path) end)
            -- attempt to obtain texture size (width x height) if API available
            local sizeInfo = "size=N/A"
            local gotSize, szErr = pcall(function()
                if addon.bgTex and addon.bgTex.GetSize then
                    local w, h = addon.bgTex:GetSize()
                    if w and h then sizeInfo = tostring(w) .. "x" .. tostring(h) end
                end
            end)
            if not gotSize and szErr then sizeInfo = "size-err:" .. tostring(szErr) end
            if ok then
                addon._currentBgPath = path
            end
            if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                local ts = Timestamp()
                local mode = tostring(addon.forcedTexture or "auto")
                if ok then
                    -- only print the OK message once per-change to avoid spam
                    if addon._lastTextureLogPath ~= path then
                        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("%s | mode=%s | SetTexture OK -> %s | %s", ts, mode, tostring(path), sizeInfo))
                        addon._lastTextureLogPath = path
                    end
                else
                    pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("%s | mode=%s | SetTexture FAILED -> %s : %s | %s", ts, mode, tostring(path), tostring(err), sizeInfo))
                end
            end
            return ok
        end
        local ok = trySetTexture(chosen)
        -- If chosen failed, try sensible fallbacks
        if not ok and chosen == PNG_POT_TEXTURE then
            if trySetTexture(PNG_TEXTURE) then chosen = PNG_TEXTURE; ok = true end
        end
        if not ok and chosen ~= BLP_TEXTURE and trySetTexture(BLP_TEXTURE) then chosen = BLP_TEXTURE; ok = true end
        if not ok then
            trySetTexture("Interface\\Icons\\INV_Misc_Map_01")
            chosen = "Interface\\Icons\\INV_Misc_Map_01"
            ok = true
        end
        if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            if ok then
                if addon._lastTextureLogPath ~= chosen then
                    pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: using texture -> "..tostring(chosen))
                    addon._lastTextureLogPath = chosen
                end
            else
                pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: failed to load textures, using icon fallback")
            end
        end
        -- If the chosen path is one we ship with the addon but SetTexture failed, warn specially so we can distinguish
        if not ok then
            for _, shipped in ipairs(addon.availableTextures) do
                if shipped == tostring(chosen) then
                    if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension WARNING: texture exists in Textures folder but failed to load -> "..tostring(chosen))
                    end
                    break
                end
            end
        end
    end
end
local function ClearDetailTextures()
    addon._savedDetailTextures = addon._savedDetailTextures or {}
    if WorldMapDetailFrame then
        local i = 1
        for _, region in ipairs({WorldMapDetailFrame:GetRegions()}) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                if not addon._savedDetailTextures[i] then
                    local ok, tex = pcall(region.GetTexture, region)
                    addon._savedDetailTextures[i] = ok and tex or nil
                end
                pcall(region.SetTexture, region, nil)
            end
            i = i + 1
        end
    end
end
local function RestoreDetailTextures()
    if addon._savedDetailTextures and WorldMapDetailFrame then
        local i = 1
        for _, region in ipairs({WorldMapDetailFrame:GetRegions()}) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                local tex = addon._savedDetailTextures[i]
                if tex then pcall(region.SetTexture, region, tex) end
            end
            i = i + 1
        end
    end
    addon._savedDetailTextures = nil
end
-- Shared helper: hide Blizzard/Mapster detail tiles and ensure our stitched container is reflowed/shown
local function HideNativeTilesAndShowStitch()
    for i = 1, (NUM_WORLDMAP_DETAIL_TILES or 16) do
        local t = _G["WorldMapDetailTile" .. i]
        if t and t.Hide then pcall(t.Hide, t) end
    end
    local st = _G["DCMap_StitchFrame"]
    if st then
        local parent = st.GetParent and st:GetParent() or WorldMapDetailFrame or UIParent
        local plevel = (parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 0
        if st.SetFrameLevel then pcall(st.SetFrameLevel, st, plevel + 50) end
        if st.Reflow then pcall(st.Reflow, st) end
        if st.Show then pcall(st.Show, st) end
    end
end
-- Resilient re-apply: run immediately and schedule a few retries to survive race conditions
local function ResilientShowStitch()
    HideNativeTilesAndShowStitch()
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        pcall(C_Timer.After, 0.05, HideNativeTilesAndShowStitch)
        pcall(C_Timer.After, 0.25, HideNativeTilesAndShowStitch)
        pcall(C_Timer.After, 0.6, HideNativeTilesAndShowStitch)
    else
        local tries = 0
        local f = CreateFrame("Frame")
        f:SetScript("OnUpdate", function(self, elapsed)
            tries = tries + 1
            HideNativeTilesAndShowStitch()
            if tries >= 4 then self:SetScript("OnUpdate", nil); f = nil end
        end)
    end
end
local function ShowMapBackgroundIfNeeded(mapId)
    EnsureMapBackgroundFrame()
    if not addon.background then return end
    -- Prefer an explicit saved override (admin can set DCMapExtensionDB.mapId)
    local configured = tonumber(DCMapExtensionDB.mapId) or MAP_ID_AZSHARA_CRATER
    local ok = false
    if mapId == configured then ok = true end
    -- fallback: try to detect by map name (best-effort, may be localized)
    if not ok and type(GetMapInfo) == "function" then
        local mname = (GetMapInfo() or "")
        if mname:lower():find("azshara") or mname:lower():find("azshara crater") then ok = true end
    end
    if ok then
        addon.background:Show()
        ClearDetailTextures()
        -- If configured to use the stitched map as the main background, attempt to apply it
        if DCMapExtensionDB and DCMapExtensionDB.useStitchedMap then
            -- create or show stitched overlay parented to WorldMapDetailFrame so it becomes the visible map
            local st = _G["DCMap_StitchFrame"]
            if st and st.Reflow then
                pcall(st.Reflow, st)
                pcall(st.Show, st)
            else
                -- create a simple stitch automatically using saved cols/rows (or fallback 4x3)
                local cols = (DCMapExtensionDB.stitchCols and tonumber(DCMapExtensionDB.stitchCols)) or 4
                local rows = (DCMapExtensionDB.stitchRows and tonumber(DCMapExtensionDB.stitchRows)) or 3
                -- build container similar to Stitch Azshara but minimal
                local parent = WorldMapDetailFrame or addon.background or UIParent
                    local pw = SafeGetWidth(parent)
                local ph = SafeGetHeight(parent)
                if pw and ph then
                    local container = CreateFrame("Frame", "DCMap_StitchFrame", parent)
                    -- optionally make the stitched container interactive
                    if DCMapExtensionDB and DCMapExtensionDB.interactable then
                        if container.EnableMouse then pcall(container.EnableMouse, container, true) end
                        if container.SetScript then
                            pcall(container.SetScript, container, "OnEnter", function(self)
                                if GameTooltip and GameTooltip.SetOwner then pcall(GameTooltip.SetOwner, GameTooltip, self, "ANCHOR_RIGHT"); pcall(GameTooltip.SetText, GameTooltip, "Stitched Map") ; pcall(GameTooltip.Show, GameTooltip) end
                            end)
                            pcall(container.SetScript, container, "OnLeave", function(self) if GameTooltip and GameTooltip.Hide then pcall(GameTooltip.Hide, GameTooltip) end end)
                            pcall(container.SetScript, container, "OnMouseDown", function(self, button) pcall(ReportClickToChatWithMapCoords, self, button) end)
                        end
                    end
                    -- honor fullscreen scale when requested; otherwise match parent
                    local scale = tonumber(DCMapExtensionDB and DCMapExtensionDB.fullscreenScale) or 1.0
                    if parent == UIParent and DCMapExtensionDB and DCMapExtensionDB.fullscreen and scale and scale < 1.0 then
                        local sw = SafeGetWidth(parent) or 0
                        local sh = SafeGetHeight(parent) or 0
                        container:SetSize(sw * scale, sh * scale)
                        container:ClearAllPoints()
                        container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                    else
                        container:SetAllPoints(parent)
                    end
                    container:SetFrameStrata("HIGH")
                    local pLevel = (parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 0
                    container:SetFrameLevel(pLevel + 50)
                    -- add a small close button when shown as a UIParent overlay
                    if parent == UIParent then
                        local cbtn = CreateFrame("Button", nil, container, "UIPanelCloseButton")
                        if cbtn and cbtn.SetPoint then cbtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", -6, -6) end
                        if cbtn and cbtn.SetScript then cbtn:SetScript("OnClick", function() pcall(container.Hide, container) end) end
                    end
                        local pw = SafeGetWidth(parent)
                        local ph = SafeGetHeight(parent)
                    container._paths = azsharaBLPs
                    container._tiles = {}
                    local cw = SafeGetWidth(container)
                    local ch = SafeGetHeight(container)
                    -- integer-safe tile sizing: round container size to nearest integer
                    local cw_i = math.floor((cw or pw) + 0.5)
                    local ch_i = math.floor((ch or ph) + 0.5)
                    local tileWBase = (cols > 0) and math.floor(cw_i / cols) or 0
                    local extraW = cw_i - tileWBase * cols
                    local tileHBase = (rows > 0) and math.floor(ch_i / rows) or 0
                    local extraH = ch_i - tileHBase * rows
                    local _tileSuccess = 0
                    local _tileTotal = 0
                    for r = 1, rows do
                        for c = 1, cols do
                            local idx = (r - 1) * cols + c
                            local path = azsharaBLPs[idx]
                            local tex = container:CreateTexture(nil, "ARTWORK")
                            -- distribute extra pixels to the first columns/rows to keep integer sizes
                            local w = tileWBase + ((c <= extraW) and 1 or 0)
                            local h = tileHBase + ((r <= extraH) and 1 or 0)
                            local left = (c - 1) * tileWBase + math.min(c - 1, extraW)
                            local top = (r - 1) * tileHBase + math.min(r - 1, extraH)
                            tex:SetSize(w, h)
                            tex:SetPoint("TOPLEFT", container, "TOPLEFT", left, -top)
                            if path then
                                local ok = pcall(function() tex:SetTexture(path) end)
                                _tileTotal = _tileTotal + 1
                                if ok then _tileSuccess = _tileSuccess + 1 end
                            end
                            table.insert(container._tiles, tex)
                        end
                    end
                    if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: stitch applied %d/%d tiles", _tileSuccess, _tileTotal))
                    end
                    -- add player marker
                    local pm = container:CreateTexture(nil, "OVERLAY")
                    pm:SetSize(16, 16)
                    if pm.SetColorTexture then pcall(pm.SetColorTexture, pm, 1, 0, 0, 1) else pcall(pm.SetTexture, pm, "Interface\\Icons\\INV_Misc_Map_02") end
                    pm:SetDrawLayer("OVERLAY", 9999)
                    container._playerMarker = pm
                    function container:Reflow()
                        -- Use the container's actual size so we stay aligned with canvas/scroll regions
                        local cw = SafeGetWidth(self)
                        local ch = SafeGetHeight(self)
                        if not cw or not ch then return end
                        local cols = tonumber(self._cols) or 1
                        local rows = tonumber(self._rows) or 1
                        if cols <= 0 or rows <= 0 then return end
                        local tileWBase = cw / cols
                        local tileHBase = ch / rows
                        for idx, tex in ipairs(self._tiles or {}) do
                            if tex then
                                local c = ((idx - 1) % cols) + 1
                                local r = math.floor((idx - 1) / cols) + 1
                                -- Let the last column/row absorb any rounding remainder to avoid gaps
                                local w = (c == cols) and (cw - tileWBase * (cols - 1)) or tileWBase
                                local h = (r == rows) and (ch - tileHBase * (rows - 1)) or tileHBase
                                local left = (c - 1) * tileWBase
                                local top = (r - 1) * tileHBase
                                tex:SetSize(w, h)
                                tex:ClearAllPoints()
                                tex:SetPoint("TOPLEFT", self, "TOPLEFT", left, -top)
                            end
                        end
                        -- one-shot diagnostic snapshot for alignment troubleshooting
                        pcall(PrintReflowSnapshot, self, parent)
                    end
                    container:SetScript("OnSizeChanged", function(self) if self.Reflow then pcall(self.Reflow, self) end end)
                    if container.Reflow then pcall(container.Reflow, container) end
                    pcall(container.Show, container)
                end
            end
        end
    else
        addon.background:Hide()
        RestoreDetailTextures()
    end
end
-- POI simple rendering (keeps minimal feature parity)
addon.poiFrames = addon.poiFrames or {}
local function CreatePOI(mapFrame, nx, ny, label, id)
    if not nx or not ny or not mapFrame then return end
    local w = SafeGetWidth(mapFrame, 512)
    local h = SafeGetHeight(mapFrame, 512)
    local x = nx * w
    local y = ny * h
    local name = "DCMap_POI_" .. tostring(id)
    local poi = CreateFrame("Frame", name, mapFrame)
    poi:SetSize(20, 20)
    poi.tex = poi:CreateTexture(nil, "OVERLAY")
    poi.tex:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    poi:SetPoint("TOPLEFT", mapFrame, "TOPLEFT", x, -y)
    if label then
        poi.label = poi:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        poi.label:SetPoint("TOP", poi, "BOTTOM", 0, -2)
        poi.label:SetText(label)
    end
    -- If configured to be interactable, enable mouse and basic tooltip/click handlers
    if DCMapExtensionDB and DCMapExtensionDB.interactable then
        if poi.EnableMouse then pcall(poi.EnableMouse, poi, true) end
        if poi.SetScript then
            pcall(poi.SetScript, poi, "OnEnter", function(self)
                if GameTooltip and GameTooltip.SetOwner then
                    pcall(GameTooltip.SetOwner, GameTooltip, self, "ANCHOR_RIGHT")
                    pcall(GameTooltip.SetText, GameTooltip, label or "")
                    pcall(GameTooltip.Show, GameTooltip)
                end
            end)
            pcall(poi.SetScript, poi, "OnLeave", function(self)
                if GameTooltip and GameTooltip.Hide then pcall(GameTooltip.Hide, GameTooltip) end
            end)
            pcall(poi.SetScript, poi, "OnMouseDown", function(self, button)
                pcall(ReportClickToChatWithMapCoords, self, button)
                    if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: POI clicked id=%s label=%s button=%s", tostring(id), tostring(label), tostring(button)))
                    end
            end)
        end
    end
    return poi
end
local function ClearAllPOIs()
    for id, frame in pairs(addon.poiFrames) do if frame and frame.Hide then frame:Hide() end; addon.poiFrames[id] = nil end
end
local function RenderHotspotsForMap(mapId)
    ClearAllPOIs()
    if not DCMap_HotspotsSaved[mapId] then return end
    local mapFrame = _G["DCMap_StitchFrame"] or WorldMapDetailFrame
    for _, hs in ipairs(DCMap_HotspotsSaved[mapId]) do
        if hs.nx and hs.ny then
            local label = hs.label or ("Hotspot #" .. tostring(hs.id))
            local poi = CreatePOI(mapFrame, hs.nx, hs.ny, label, hs.id)
            if poi then addon.poiFrames[hs.id] = poi end
        end
    end
end
local function ParseHotspotPayload(payload)
    local function trim(s)
        if not s then return s end
        return (s:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    local result = {}
    if not payload then return result end
    -- If the special prefix exists, strip everything before it
    local start = payload:find("HOTSPOT_ADDON")
    if start then payload = payload:sub(start) end
    if payload:sub(1,13) == "HOTSPOT_ADDON|" then payload = payload:sub(14) end
    -- Debug: print raw incoming payload (if debug enabled)
    if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: ParseHotspotPayload raw -> " .. tostring(payload))
    end
    -- Accept tokens separated by '|' or ';' (common delimiters). Support key:value and key=value.
    for token in string.gmatch(payload, "([^|;]+)") do
        token = trim(token)
        if token ~= "" then
            -- try key:val or key=val (allow label values containing spaces/colons)
            local k, v = token:match("^%s*([^:=%s]+)%s*[:=]%s*(.+)%s*$")
            if k and v then
                v = trim(v)
                -- strip surrounding quotes if present
                if v:sub(1,1) == '"' and v:sub(-1) == '"' then v = v:sub(2, -2) end
                if v:sub(1,1) == "'" and v:sub(-1) == "'" then v = v:sub(2, -2) end
                result[k] = v
            else
                -- if token is just a number, or comma-separated numbers, try to capture numeric sequence later
                -- store as-is under an incremental key so we can fallback
                local idx = (#result or 0) + 1
                result[tostring(idx)] = token
            end
        end
    end
    -- If explicit keys weren't present, try a numeric-sequence fallback (map,nx,ny,id)
    if not (result.map or result["map"]) then
        -- gather all numeric-looking tokens in original payload
        local nums = {}
        for n in string.gmatch(payload, "([-]?%d+%.?%d*)") do
            local nn = tonumber(n)
            if nn then table.insert(nums, nn) end
        end
        if #nums >= 3 then
            result.map = result.map or nums[1]
            result.nx = result.nx or nums[2]
            result.ny = result.ny or nums[3]
            if #nums >= 4 then result.id = result.id or nums[4] end
        end
    end
    -- Convert known numeric fields
    if result.map and type(result.map) == "string" then result.map = tonumber(result.map) end
    if result.nx and type(result.nx) == "string" then result.nx = tonumber(result.nx) end
    if result.ny and type(result.ny) == "string" then result.ny = tonumber(result.ny) end
    if result.id and type(result.id) == "string" then result.id = tonumber(result.id) end
    -- Debug: print parsed table
    if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local parts = {}
        for k,v in pairs(result) do table.insert(parts, tostring(k) .. '=' .. tostring(v)) end
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: ParseHotspotPayload parsed -> " .. table.concat(parts, ", "))
    end
    return result
end
local function HandleIncomingHotspot(rawPayload)
    if not rawPayload then return end
    local payload = tostring(rawPayload)
    if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: HandleIncomingHotspot raw -> " .. payload)
    end
    local parsed = ParseHotspotPayload(payload)
    if not parsed or (not parsed.map and not parsed["1"]) or (not parsed.id and not parsed.nx) then
        if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: HandleIncomingHotspot - parsed payload missing required fields")
        end
        return
    end
    -- Normalize map/id presence
    local mapId = parsed.map or tonumber(parsed.map) or parsed["map"] or tonumber(parsed["map"]) or nil
    mapId = mapId or parsed[1]
    local id = parsed.id or parsed["id"]
    -- nx/ny may be present as strings
    local nx = parsed.nx or parsed["nx"]
    local ny = parsed.ny or parsed["ny"]
    if not mapId then
        if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: HandleIncomingHotspot - mapId not found after parsing")
        end
        return
    end
    DCMap_HotspotsSaved[mapId] = DCMap_HotspotsSaved[mapId] or {}
    local parsedEntry = { map = tonumber(mapId), id = tonumber(id) or nil, nx = tonumber(nx) or nil, ny = tonumber(ny) or nil, label = parsed.label }
    local found = false
    for i, hs in ipairs(DCMap_HotspotsSaved[mapId]) do
        if hs.id and parsedEntry.id and hs.id == parsedEntry.id then
            DCMap_HotspotsSaved[mapId][i] = parsedEntry
            found = true
            break
        end
    end
    if not found then table.insert(DCMap_HotspotsSaved[mapId], parsedEntry) end
    if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: HandleIncomingHotspot saved -> map=%s id=%s nx=%s ny=%s label=%s", tostring(parsedEntry.map), tostring(parsedEntry.id), tostring(parsedEntry.nx), tostring(parsedEntry.ny), tostring(parsedEntry.label)))
    end
    local currentMapID = GetCurrentMapAreaID() or 0
    if currentMapID == parsedEntry.map then RenderHotspotsForMap(parsedEntry.map) end
end
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("WORLD_MAP_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then EnsureMapBackgroundFrame(); PrintTextureDiagnosticsOnce();
        -- attempt Mapster integration at login (if already loaded)
        if type(EnsureMapsterIntegration) == "function" then pcall(EnsureMapsterIntegration) end
        -- if stitched mode is enabled by default, ensure stitch is applied for current zone
        if DCMapExtensionDB and DCMapExtensionDB.useStitchedMap then
            local cur = GetCurrentMapAreaID and GetCurrentMapAreaID() or nil
            ShowMapBackgroundIfNeeded(cur)
        end
    elseif event == "WORLD_MAP_UPDATE" then
        local currentMapID = GetCurrentMapAreaID() or 0
        ShowMapBackgroundIfNeeded(currentMapID)
        RenderHotspotsForMap(currentMapID)
        -- if we have a stitched overlay, reflow it so it stays aligned with the map
        local st = _G["DCMap_StitchFrame"]
        if st and st.Reflow then pcall(st.Reflow, st) end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix = arg1; local message = arg2
        if message == nil and prefix ~= nil then message = prefix; prefix = nil end
        if (prefix == "HOTSPOT" or (message and message:find("HOTSPOT_ADDON"))) then HandleIncomingHotspot(message) end
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = arg1
        if message and message:find("HOTSPOT_ADDON") then HandleIncomingHotspot(message) end
    elseif event == "ADDON_LOADED" then
        -- attempt to hook Mapster as soon as it's loaded
        local loadedName = arg1
        if loadedName and loadedName:lower():find("mapster") then
            if type(EnsureMapsterIntegration) == "function" then pcall(EnsureMapsterIntegration) end
        else
            -- generic attempt in case Mapster is already present under other load ordering
            if type(EnsureMapsterIntegration) == "function" then pcall(EnsureMapsterIntegration) end
        end
    end
end)
-- Auto-select configured map when the world map is opened (so the stitched Azshara map becomes the default)
local function AutoSelectStitchedMapOnOpen()
    if not (DCMapExtensionDB and DCMapExtensionDB.useStitchedMap) then return end
    -- only auto-select when the player is in or near Azshara (best-effort by map name or current map id)
    local cur = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    if cur == MAP_ID_AZSHARA_CRATER then
        if type(SetMapByID) == "function" then pcall(SetMapByID, MAP_ID_AZSHARA_CRATER)
        elseif type(SetMapToMapID) == "function" then pcall(SetMapToMapID, MAP_ID_AZSHARA_CRATER) end
    else
        -- best-effort by map name
        if type(GetMapInfo) == "function" then
            local mname = (GetMapInfo() or "")
            if mname:lower():find("azshara") then
                if type(SetMapByID) == "function" then pcall(SetMapByID, MAP_ID_AZSHARA_CRATER)
                elseif type(SetMapToMapID) == "function" then pcall(SetMapToMapID, MAP_ID_AZSHARA_CRATER) end
            end
        end
    end
    -- ensure the stitch container is created/shown if stitched mode is enabled
    local cur2 = GetCurrentMapAreaID and GetCurrentMapAreaID() or nil
    ShowMapBackgroundIfNeeded(cur2)
    -- ensure the stitched overlay is resiliently applied (hide native tiles and reflow ours)
    if type(ResilientShowStitch) == "function" then pcall(ResilientShowStitch) end
end
-- Hook the world map Show so the stitch becomes the selected background immediately
if type(hooksecurefunc) == "function" and type(WorldMapFrame) == "table" then
    pcall(hooksecurefunc, WorldMapFrame, "Show", AutoSelectStitchedMapOnOpen)
end
-- Listen for other addons loading (Mapster may load after us); hook when it's available
eventFrame:RegisterEvent("ADDON_LOADED")
-- Mapster integration: hide default detail tiles when Mapster refreshes them and ensure
-- our stitched container is reflowed/shown. We do this via hooksecurefunc so we don't
-- depend on Mapster's internal APIs directly.
function EnsureMapsterIntegration()
    if not DCMapExtensionDB or not DCMapExtensionDB.useStitchedMap then return end
    if type(Mapster) ~= "table" then return end
    if addon._mapsterHooked then return end
    if type(hooksecurefunc) == "function" then
        -- Use the shared resilient reapply helper so other code paths can call it too
        if type(Mapster.UpdateDetailTiles) == "function" then
            hooksecurefunc(Mapster, "UpdateDetailTiles", ResilientShowStitch)
        end
        if type(Mapster.Refresh) == "function" then
            hooksecurefunc(Mapster, "Refresh", ResilientShowStitch)
        end
        if type(Mapster.SizeUp) == "function" then
            hooksecurefunc(Mapster, "SizeUp", ResilientShowStitch)
        end
        if type(Mapster.SizeDown) == "function" then
            hooksecurefunc(Mapster, "SizeDown", ResilientShowStitch)
        end
        if type(Mapster.ToggleMapSize) == "function" then
            hooksecurefunc(Mapster, "ToggleMapSize", ResilientShowStitch)
        end
        addon._mapsterHooked = true
        if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: Mapster integration hooked") end
    end
end
SLASH_DCMAP1 = "/dcmap"
SlashCmdList["DCMAP"] = function(msg)
    msg = msg and msg:lower() or ""
    local args = {}
    for token in string.gmatch(msg, "%S+") do table.insert(args, token) end
    if msg == "debug" then
        EnsureMapBackgroundFrame(); if type(SetMapByID) == "function" then pcall(SetMapByID, MAP_ID_AZSHARA_CRATER) elseif type(SetMapToMapID) == "function" then pcall(SetMapToMapID, MAP_ID_AZSHARA_CRATER) end; if ShowUIPanel then pcall(ShowUIPanel, WorldMapFrame) end
        DCMap_HotspotsSaved[MAP_ID_AZSHARA_CRATER] = DCMap_HotspotsSaved[MAP_ID_AZSHARA_CRATER] or {}
        table.insert(DCMap_HotspotsSaved[MAP_ID_AZSHARA_CRATER], { id = 99999, nx = 0.5, ny = 0.5, label = "TEST HOTSPOT" })
        RenderHotspotsForMap(MAP_ID_AZSHARA_CRATER)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: debug - opened map and placed test hotspot") end
    elseif msg == "show" then EnsureMapBackgroundFrame(); if addon.background then addon.background:Show() end
    elseif msg == "hide" then EnsureMapBackgroundFrame(); if addon.background then addon.background:Hide() end
    elseif msg == "clear" then DCMap_HotspotsSaved = {}; ClearAllPOIs(); if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: cleared stored hotspots") end
    elseif args[1] == "setmap" and args[2] then
        local id = tonumber(args[2])
        if id then
            DCMapExtensionDB.mapId = id
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: mapId set to %d (use /dcmap show to preview)", id)) end
            -- re-evaluate current map immediately
            local cur = GetCurrentMapAreaID and GetCurrentMapAreaID() or nil
            ShowMapBackgroundIfNeeded(cur)
        else
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: invalid map id") end
        end
    else
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: /dcmap debug|show|hide|clear|setmap <id>") end
    end
end
-- Extend slash commands to set/get map bounds for normalized->map conversion
SLASH_DCMAPBOUNDS1 = "/dcmapbounds"
SlashCmdList["DCMAPBOUNDS"] = function(msg)
    if not msg or msg:match("^%s*$") then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "Usage: /dcmapbounds set <mapId> <minX> <minY> <maxX> <maxY>  OR  /dcmapbounds show <mapId>") end
        return
    end
    local args = {}
    for token in string.gmatch(msg, "%S+") do table.insert(args, token) end
    local cmd = args[1] and args[1]:lower()
    if cmd == "set" and #args >= 6 then
        local mapId = tonumber(args[2])
        local minX = tonumber(args[3])
        local minY = tonumber(args[4])
        local maxX = tonumber(args[5])
        local maxY = tonumber(args[6])
        if mapId and minX and minY and maxX and maxY then
            DCMap_SetMapBounds(mapId, minX, minY, maxX, maxY)
        else
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: invalid arguments for /dcmapbounds set") end
        end
    elseif cmd == "show" and #args >= 2 then
        local mapId = tonumber(args[2])
        if not mapId then if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: invalid mapId") end return end
        local b = DCMap_GetMapBounds(mapId)
        if not b then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: no bounds stored for map "..tostring(mapId)) end
        else
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: map %s bounds -> minX=%s minY=%s maxX=%s maxY=%s", tostring(mapId), tostring(b.minX), tostring(b.minY), tostring(b.maxX), tostring(b.maxY))) end
        end
    else
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "Usage: /dcmapbounds set <mapId> <minX> <minY> <maxX> <maxY>  OR  /dcmapbounds show <mapId>") end
    end
end
-- On-demand reflow diagnostic (prints the same one-shot snapshot; resets the one-shot flag so you can re-run)
SLASH_DCMAPREFLOW1 = "/dcmapreflow"
SlashCmdList["DCMAPREFLOW"] = function()
    -- allow a forced reprint even if the one-shot already fired
    if type(addon) == "table" then addon._reflowDiagDone = nil end
    local container = _G["DCMap_StitchFrame"]
    local parent = _G["DCMap_BackgroundFrame"] or (type(WorldMapDetailFrame) == "table" and WorldMapDetailFrame) or UIParent
    pcall(PrintReflowSnapshot, container, parent)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: reflow snapshot requested (check chat)") end
end
if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension loaded") end
PrintTextureDiagnosticsOnce = function()
    if addon._diagnosticPrinted then return end
    addon._diagnosticPrinted = true
    if not IsDebugEnabled() then return end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: available textures for diagnostics:")
        for _, f in ipairs(addon.availableTextures) do
            local exists = FileExists(f)
            local ok, err = DiagnosticCheckTexture(f)
            if exists and ok then
                pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, " - "..f.."  [OK]")
            elseif exists and not ok then
                pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, " - "..f.."  [EXISTS but SetTexture failed: "..tostring(err).."]")
            else
                pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, " - "..f.."  [missing or unreadable]")
            end
        end
    end
end
-- One-shot reflow diagnostic: when debug is enabled, print a concise snapshot of
-- parent/container sizes, computed tile width/height, and per-tile anchors.
-- This prints only once (per session) to avoid spamming chat.
local function PrintReflowSnapshot(container, parent)
    if addon._reflowDiagDone then return end
    if not IsDebugEnabled() then return end
    if not container then return end
    addon._reflowDiagDone = true
    local pw = SafeGetWidth(parent)
    local ph = SafeGetHeight(parent)
    local cw = SafeGetWidth(container)
    local ch = SafeGetHeight(container)
    local cols = tonumber(container._cols) or 1
    local rows = tonumber(container._rows) or 1
    -- compute integer-safe tile sizes (the same algorithm used by Reflow)
    local tileW = 0
    local tileH = 0
    local cw_i = math.floor((cw or 0) + 0.5)
    local ch_i = math.floor((ch or 0) + 0.5)
    local tileWBase = (cols > 0) and math.floor(cw_i / cols) or 0
    local extraW = cw_i - tileWBase * cols
    local tileHBase = (rows > 0) and math.floor(ch_i / rows) or 0
    local extraH = ch_i - tileHBase * rows
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension REFLOW SNAPSHOT: parent=%s pw=%s ph=%s container=%s cw=%s ch=%s cols=%d rows=%d tileWBase=%d extraW=%d tileHBase=%d extraH=%d", tostring(parent and (parent.GetName and parent:GetName() or tostring(parent)) or "nil"), tostring(pw), tostring(ph), tostring(container and (container.GetName and container:GetName() or "DCMap_StitchFrame") or "nil"), tostring(cw), tostring(ch), cols, rows, tileWBase, extraW, tileHBase, extraH))
        for idx, _ in ipairs(container._tiles or {}) do
            local c = ((idx - 1) % cols) + 1
            local r = math.floor((idx - 1) / cols) + 1
            local w = tileWBase + ((c <= extraW) and 1 or 0)
            local h = tileHBase + ((r <= extraH) and 1 or 0)
            local left = (c - 1) * tileWBase + math.min(c - 1, extraW)
            local top = (r - 1) * tileHBase + math.min(r - 1, extraH)
            local path = (container._paths and container._paths[idx]) or "(n/a)"
            pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("  tile %d: c=%d r=%d left=%d top=%d expected_size=%dx%d path=%s", idx, c, r, left, top, w, h, tostring(path)))
        end
    end
end
-- Interface Options Panel --------------------------------------------------
do
    -- Parent to the Interface Options container when available (safer for older clients)
    local parentContainer = (type(InterfaceOptionsFramePanelContainer) == "table" and InterfaceOptionsFramePanelContainer) or UIParent
    local panel = CreateFrame("Frame", "DCMapExtensionOptionsPanel", parentContainer)
    panel.name = "DC-MapExtension"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DC-MapExtension")
    -- Debug checkbox
    local debugCB = CreateFrame("CheckButton", "DCMapExtensionDebugCB", panel, "InterfaceOptionsCheckButtonTemplate")
    debugCB:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    -- not all clients expose debugCB.Text; be defensive
    local cbText = _G[debugCB:GetName() .. "Text"]
    if cbText and cbText.SetText then
        cbText:SetText("Enable texture diagnostics (prints to chat)")
    else
        local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", debugCB, "RIGHT", 6, 0)
        fs:SetText("Enable texture diagnostics (prints to chat)")
    end
    debugCB:SetScript("OnClick", function(self)
        DCMapExtensionDB = DCMapExtensionDB or {}
        if self:GetChecked() then DCMapExtensionDB.debug = true else DCMapExtensionDB.debug = nil end
    end)
    -- Use stitched map as the active map when viewing the configured zone
    local stitchUseCB = CreateFrame("CheckButton", "DCMapExtensionUseStitchCB", panel, "InterfaceOptionsCheckButtonTemplate")
    stitchUseCB:SetPoint("TOPLEFT", debugCB, "BOTTOMLEFT", 0, -28)
    local stitchText = _G[stitchUseCB:GetName() .. "Text"]
    if stitchText and stitchText.SetText then
        stitchText:SetText("Use stitched Azshara map as default background for this zone")
    else
        local fs2 = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fs2:SetPoint("LEFT", stitchUseCB, "RIGHT", 6, 0)
        fs2:SetText("Use stitched Azshara map as default background for this zone")
    end
    stitchUseCB:SetScript("OnClick", function(self)
        DCMapExtensionDB = DCMapExtensionDB or {}
        if self:GetChecked() then DCMapExtensionDB.useStitchedMap = true else DCMapExtensionDB.useStitchedMap = nil end
        -- if the user enabled the stitched map option, attempt to integrate with Mapster now
        if DCMapExtensionDB.useStitchedMap and type(EnsureMapsterIntegration) == "function" then pcall(EnsureMapsterIntegration) end
    end)
    -- Fullscreen option: parent stitched container to UIParent and fill screen
    local fullscreenCB = CreateFrame("CheckButton", "DCMapExtensionFullscreenCB", panel, "InterfaceOptionsCheckButtonTemplate")
    fullscreenCB:SetPoint("TOPLEFT", stitchUseCB, "BOTTOMLEFT", 0, -12)
    local fullscreenText = _G[fullscreenCB:GetName() .. "Text"]
    if fullscreenText and fullscreenText.SetText then
        fullscreenText:SetText("Make stitched map fullscreen (parent to UIParent)")
    else
        local fsf = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fsf:SetPoint("LEFT", fullscreenCB, "RIGHT", 6, 0)
        fsf:SetText("Make stitched map fullscreen (parent to UIParent)")
    end
    fullscreenCB:SetScript("OnClick", function(self)
        DCMapExtensionDB = DCMapExtensionDB or {}
        if self:GetChecked() then DCMapExtensionDB.fullscreen = true else DCMapExtensionDB.fullscreen = nil end
        pcall(ApplyStitchSettings)
    end)
    -- Interactable option: allow POIs and stitched map to receive mouse/tooltip/clicks
    local interactCB = CreateFrame("CheckButton", "DCMapExtensionInteractCB", panel, "InterfaceOptionsCheckButtonTemplate")
    interactCB:SetPoint("TOPLEFT", fullscreenCB, "BOTTOMLEFT", 0, -12)
    local interactText = _G[interactCB:GetName() .. "Text"]
    if interactText and interactText.SetText then
        interactText:SetText("Enable interaction for stitched map (POI tooltips/clicks)")
    else
        local fsi = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fsi:SetPoint("LEFT", interactCB, "RIGHT", 6, 0)
        fsi:SetText("Enable interaction for stitched map (POI tooltips/clicks)")
    end
    interactCB:SetScript("OnClick", function(self)
        DCMapExtensionDB = DCMapExtensionDB or {}
        if self:GetChecked() then DCMapExtensionDB.interactable = true else DCMapExtensionDB.interactable = nil end
        pcall(ApplyStitchSettings)
    end)
    -- Fullscreen scale (allows a slightly smaller fullscreen stitched map). Range: 0.5 .. 1.0
    local scaleLbl = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    scaleLbl:SetPoint("TOPLEFT", interactCB, "BOTTOMLEFT", 0, -12)
    scaleLbl:SetText("Fullscreen scale (0.5 - 1.0):")
    local scaleEdit = CreateFrame("EditBox", "DCMapExtensionFullscreenScale", panel, "InputBoxTemplate")
    scaleEdit:SetSize(60, 22)
    scaleEdit:SetPoint("LEFT", scaleLbl, "RIGHT", 8, 0)
    scaleEdit:SetAutoFocus(false)
    scaleEdit:SetText("1.0")
    scaleEdit:SetNumeric(true)
    local function applyScaleFromBox()
        local v = tonumber(scaleEdit:GetText()) or 1.0
        if v < 0.5 then v = 0.5 end
        if v > 1.0 then v = 1.0 end
        DCMapExtensionDB = DCMapExtensionDB or {}
        DCMapExtensionDB.fullscreenScale = v
        scaleEdit:SetText(tostring(v))
        pcall(ApplyStitchSettings)
    end
    scaleEdit:SetScript("OnEnterPressed", function() applyScaleFromBox(); scaleEdit:ClearFocus() end)
    scaleEdit:SetScript("OnEditFocusLost", function() applyScaleFromBox() end)
    -- Map ID label
    local lbl = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", debugCB, "BOTTOMLEFT", 0, -12)
    lbl:SetText("Map ID for background:")
    -- Numeric editbox for map id
    local edit = CreateFrame("EditBox", "DCMapExtensionMapIdEdit", panel, "InputBoxTemplate")
    edit:SetSize(80, 22)
    edit:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    local setBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    setBtn:SetSize(60, 22)
    setBtn:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    setBtn:SetText("Set")
    setBtn:SetScript("OnClick", function()
        local v = tonumber(edit:GetText())
        if v then
            DCMapExtensionDB = DCMapExtensionDB or {}
            DCMapExtensionDB.mapId = v
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: mapId set to "..tostring(v)) end
            -- re-evaluate immediately
            local cur = GetCurrentMapAreaID and GetCurrentMapAreaID() or nil
            ShowMapBackgroundIfNeeded(cur)
        else
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: invalid map id") end
        end
    end)
    -- Test textures button: runs diagnostics for each packaged texture and reports concise results to chat
    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(120, 22)
    testBtn:SetPoint("TOPLEFT", setBtn, "BOTTOMLEFT", 0, -8)
    testBtn:SetText("Test textures")
    testBtn:SetScript("OnClick", function()
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: running texture diagnostics...") end
        for _, f in ipairs(addon.availableTextures) do
            local exists = FileExists(f)
            local ok, err = DiagnosticCheckTexture(f)
            if exists and ok then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, " - "..f.." : OK") end
            elseif exists and not ok then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, " - "..f.." : EXISTS but SetTexture failed: "..tostring(err)) end
            else
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, " - "..f.." : missing or unreadable") end
            end
        end
    end)
    -- Quick force-texture buttons (help debug visual corruption by forcing a specific shipped file)
    local function setAndApplyMode(mode)
        addon.forcedTexture = mode or "auto"
        DCMapExtensionDB = DCMapExtensionDB or {}
        DCMapExtensionDB.forcedTexture = addon.forcedTexture
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: forcing texture mode -> "..tostring(addon.forcedTexture)) end
        -- Clear any previous bg texture then re-create/apply immediately
        if addon.bgTex and addon.bgTex.SetTexture then pcall(addon.bgTex.SetTexture, addon.bgTex, nil) end
        EnsureMapBackgroundFrame()
    end
    local btnAuto = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnAuto:SetSize(60, 20)
    btnAuto:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)
    btnAuto:SetText("Auto")
    btnAuto:SetScript("OnClick", function() setAndApplyMode("auto") end)
    local btnPNGpot = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnPNGpot:SetSize(60, 20)
    btnPNGpot:SetPoint("LEFT", btnAuto, "RIGHT", 6, 0)
    btnPNGpot:SetText("PNG1024")
    -- Force the POT/1024 PNG specifically
    btnPNGpot:SetScript("OnClick", function() setAndApplyMode("png1024") end)
    local btnPNG = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnPNG:SetSize(60, 20)
    btnPNG:SetPoint("LEFT", btnPNGpot, "RIGHT", 6, 0)
    btnPNG:SetText("PNG")
    btnPNG:SetScript("OnClick", function() setAndApplyMode("png") end)
    local btnBLP = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnBLP:SetSize(60, 20)
    btnBLP:SetPoint("LEFT", btnPNG, "RIGHT", 6, 0)
    btnBLP:SetText("BLP")
    btnBLP:SetScript("OnClick", function() setAndApplyMode("blp") end)
    -- Fullscreen test button: apply each available texture to a temporary full-screen texture
    local fullBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    fullBtn:SetSize(120, 22)
    fullBtn:SetPoint("TOPLEFT", btnAuto, "BOTTOMLEFT", 0, -28)
    fullBtn:SetText("Fullscreen Test")
    fullBtn:SetScript("OnClick", function()
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: starting fullscreen texture test...") end
        -- create or reuse frame
        local fs = _G["DCMap_FullscreenTestFrame"]
        if not fs then
            fs = CreateFrame("Frame", "DCMap_FullscreenTestFrame", UIParent)
            fs:SetAllPoints(UIParent)
            fs.tex = fs:CreateTexture(nil, "FULLSCREEN")
            fs.tex:SetAllPoints(fs)
            fs.tex:SetDrawLayer("ARTWORK", 9999)
        end
        fs:Show()
        local idx = 1
        local function applyNext()
            local path = addon.availableTextures[idx]
            if not path then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: fullscreen test finished") end
                if fs then fs:Hide() end
                return
            end
            local ok, err = DiagnosticCheckTexture(path)
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                if ok then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, " - testing: "..path.."  => Diagnostic OK")
                else pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, " - testing: "..path.."  => Diagnostic failed: "..tostring(err)) end
            end
            -- apply to fullscreen texture (use pcall to avoid hard errors)
            if fs and fs.tex then pcall(fs.tex.SetTexture, fs.tex, path) end
            idx = idx + 1
            if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                C_Timer.After(1.0, applyNext)
            else
                -- fallback: short OnUpdate timer
                local t = 0
                fs:SetScript("OnUpdate", function(self, elapsed)
                    t = t + elapsed
                    if t >= 1.0 then self:SetScript("OnUpdate", nil); applyNext() end
                end)
            end
        end
        applyNext()
    end)
    -- Test Azshara tiled BLPs specifically (cycles the AzsharaCrater*.blp files)
    local azBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    azBtn:SetSize(140, 22)
    azBtn:SetPoint("LEFT", fullBtn, "RIGHT", 8, 0)
    azBtn:SetText("Test Azshara BLPs")
    azBtn:SetScript("OnClick", function()
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: starting Azshara BLP tiled test...") end
        local fs = _G["DCMap_FullscreenTestFrame"]
        if not fs then
            fs = CreateFrame("Frame", "DCMap_FullscreenTestFrame", UIParent)
            fs:SetAllPoints(UIParent)
            fs.tex = fs:CreateTexture(nil, "FULLSCREEN")
            fs.tex:SetAllPoints(fs)
            fs.tex:SetDrawLayer("ARTWORK", 9999)
        end
        fs:Show()
        local idx = 1
        local function applyNextAz()
            local path = azsharaBLPs[idx]
            if not path then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: Azshara BLP test finished") end
                if fs then fs:Hide() end
                return
            end
            local ok, err = DiagnosticCheckTexture(path)
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                if ok then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, " - "..path.." : Diagnostic OK")
                else pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, " - "..path.." : Diagnostic failed: "..tostring(err)) end
            end
            if fs and fs.tex then pcall(fs.tex.SetTexture, fs.tex, path) end
            -- also attempt to set map background immediately if available
            if addon and addon.bgTex and addon.bgTex.SetTexture then pcall(addon.bgTex.SetTexture, addon.bgTex, path) end
            idx = idx + 1
            if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                C_Timer.After(1.0, applyNextAz)
            else
                local t = 0
                fs:SetScript("OnUpdate", function(self, elapsed)
                    t = t + elapsed
                    if t >= 1.0 then self:SetScript("OnUpdate", nil); applyNextAz() end
                end)
            end
        end
        applyNextAz()
    end)
    -- Stitch Azshara tiles into a grid on the map or fullscreen for testing
    local stitchBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    stitchBtn:SetSize(120, 22)
    stitchBtn:SetPoint("LEFT", azBtn, "RIGHT", 8, 0)
    stitchBtn:SetText("Stitch Azshara")
    stitchBtn:SetScript("OnClick", function()
        -- default grid: 4 columns x 3 rows (matches 12 files)
        local cols, rows = 4, 3
        -- Prefer to parent the stitch to the world map detail frame when the world map is open
        local parent
            if type(WorldMapFrame) == "table" and WorldMapFrame:IsShown() and WorldMapDetailFrame then
                parent = WorldMapDetailFrame
            else
                if DCMapExtensionDB and DCMapExtensionDB.fullscreen then
                    parent = UIParent
                else
                    parent = addon.background or WorldMapDetailFrame or UIParent
                end
            end
        local pw = SafeGetWidth(parent)
        local ph = SafeGetHeight(parent)
        if not pw or not ph then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: unable to determine parent size for stitching") end
            return
        end
        -- create container
        local container = _G["DCMap_StitchFrame"]
        if container and container.Destroy then
            pcall(container.Hide, container)
        end
    container = GetOrCreateStitchFrame(parent, cols, rows)
    if DCMapExtensionDB and DCMapExtensionDB.interactable then
        if container.EnableMouse then pcall(container.EnableMouse, container, true) end
        if container.SetScript then
            pcall(container.SetScript, container, "OnEnter", function(self) if GameTooltip and GameTooltip.SetOwner then pcall(GameTooltip.SetOwner, GameTooltip, self, "ANCHOR_RIGHT"); pcall(GameTooltip.SetText, GameTooltip, "Stitched Map") ; pcall(GameTooltip.Show, GameTooltip) end end)
            pcall(container.SetScript, container, "OnLeave", function(self) if GameTooltip and GameTooltip.Hide then pcall(GameTooltip.Hide, GameTooltip) end end)
            pcall(container.SetScript, container, "OnMouseDown", function(self, button) pcall(ReportClickToChatWithMapCoords, self, button) end)
        end
    end
    -- respect fullscreen scale override
    local scale = tonumber(DCMapExtensionDB and DCMapExtensionDB.fullscreenScale) or 1.0
    if parent == UIParent and DCMapExtensionDB and DCMapExtensionDB.fullscreen and scale and scale < 1.0 then
        local sw = SafeGetWidth(parent) or 0
        local sh = SafeGetHeight(parent) or 0
        container:SetSize(sw * scale, sh * scale)
        container:ClearAllPoints()
        container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    else
        container:SetAllPoints(parent)
    end
                    container:SetFrameStrata("HIGH")
                    local pLevel = (parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 0
                    container:SetFrameLevel(pLevel + 50)
                    if parent == UIParent then
                        local cbtn = CreateFrame("Button", nil, container, "UIPanelCloseButton")
                        if cbtn and cbtn.SetPoint then cbtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", -6, -6) end
                        if cbtn and cbtn.SetScript then cbtn:SetScript("OnClick", function() pcall(container.Hide, container) end) end
                    end
        -- helper: reflow tiles when container/parent size changes
        container._cols = cols
        container._rows = rows
        container._order = nil
        container._paths = azsharaBLPs
            function container:Reflow()
                -- compute sizes from the container so texture anchors align to the canvas
                local cw = SafeGetWidth(self)
                local ch = SafeGetHeight(self)
                if not cw or not ch then return end
                local cols = tonumber(self._cols) or 1
                local rows = tonumber(self._rows) or 1
                if cols <= 0 or rows <= 0 then return end
                -- integer-safe reflow: round container size and distribute remainder pixels
                local cw_i = math.floor((cw or 0) + 0.5)
                local ch_i = math.floor((ch or 0) + 0.5)
                local tileWBase = (cols > 0) and math.floor(cw_i / cols) or 0
                local extraW = cw_i - tileWBase * cols
                local tileHBase = (rows > 0) and math.floor(ch_i / rows) or 0
                local extraH = ch_i - tileHBase * rows
                for idx, tex in ipairs(self._tiles or {}) do
                    if tex then
                        local c = ((idx - 1) % cols) + 1
                        local r = math.floor((idx - 1) / cols) + 1
                        local w = tileWBase + ((c <= extraW) and 1 or 0)
                        local h = tileHBase + ((r <= extraH) and 1 or 0)
                        local left = (c - 1) * tileWBase + math.min(c - 1, extraW)
                        local top = (r - 1) * tileHBase + math.min(r - 1, extraH)
                        tex:SetSize(w, h)
                        tex:ClearAllPoints()
                        tex:SetPoint("TOPLEFT", self, "TOPLEFT", left, -top)
                    end
                end
                -- reposition player marker if present
                if self._playerMarker then
                    if type(GetPlayerMapPosition) == "function" then
                        local nx, ny = GetPlayerMapPosition("player")
                        if nx and ny then
                            local px = nx * cw
                            local py = ny * ch
                            self._playerMarker:ClearAllPoints()
                            self._playerMarker:SetPoint("CENTER", self, "TOPLEFT", px, -py)
                        end
                    end
                end
                -- one-shot diagnostic snapshot for alignment troubleshooting
                pcall(PrintReflowSnapshot, self, parent)
            end
    container:SetScript("OnSizeChanged", function(self, w, h) if self.Reflow then pcall(self.Reflow, self) end end)
        -- lightweight OnUpdate to update player marker periodically
        container._playerTimer = 0
        container:SetScript("OnUpdate", function(self, elapsed)
            self._playerTimer = (self._playerTimer or 0) + elapsed
            if self._playerTimer < 0.2 then return end
            self._playerTimer = 0
            if self._playerMarker then
                if type(GetPlayerMapPosition) == "function" then
                    local nx, ny = GetPlayerMapPosition("player")
                    if nx and ny then
                        local pw = SafeGetWidth(self)
                        local ph = SafeGetHeight(self)
                        local px = nx * pw
                        local py = ny * ph
                        pcall(self._playerMarker.ClearAllPoints, self._playerMarker)
                        pcall(self._playerMarker.SetPoint, self._playerMarker, "CENTER", self, "TOPLEFT", px, -py)
                    end
                end
            end
        end)
        -- remove old tiles if present
        if container._tiles then
            for i, t in ipairs(container._tiles) do if t and t.SetTexture then pcall(t.SetTexture, t, nil); pcall(t.Hide, t) end end
        end
    container._tiles = {}
        -- integer-safe initial tile creation: round container size and distribute remainder pixels
        local cw = SafeGetWidth(container) or pw
        local ch = SafeGetHeight(container) or ph
        local cw_i = math.floor((cw or 0) + 0.5)
        local ch_i = math.floor((ch or 0) + 0.5)
        local tileWBase = (cols > 0) and math.floor(cw_i / cols) or 0
        local extraW = cw_i - tileWBase * cols
        local tileHBase = (rows > 0) and math.floor(ch_i / rows) or 0
        local extraH = ch_i - tileHBase * rows
        local _tileSuccess = 0
        local _tileTotal = 0
        for r = 1, rows do
            for c = 1, cols do
                local idx = (r - 1) * cols + c
                local path = azsharaBLPs[idx]
                if not path then break end
                local tex = container:CreateTexture(nil, "ARTWORK")
                local w = tileWBase + ((c <= extraW) and 1 or 0)
                local h = tileHBase + ((r <= extraH) and 1 or 0)
                local left = (c - 1) * tileWBase + math.min(c - 1, extraW)
                local top = (r - 1) * tileHBase + math.min(r - 1, extraH)
                tex:SetSize(w, h)
                -- anchor by TOPLEFT offset (use integer offsets)
                tex:SetPoint("TOPLEFT", container, "TOPLEFT", left, -top)
                tex:SetTexCoord(0, 1, 0, 1)
                local ok = pcall(function() tex:SetTexture(path) end)
                _tileTotal = _tileTotal + 1
                if ok then _tileSuccess = _tileSuccess + 1 end
                table.insert(container._tiles, tex)
            end
        end
        if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: stitch applied %d/%d tiles", _tileSuccess, _tileTotal))
        end
        -- create or update player marker on the stitched container
        if not container._playerMarker then
            local pm = container:CreateTexture(nil, "OVERLAY")
            pm:SetSize(16, 16)
            if pm.SetColorTexture then pcall(pm.SetColorTexture, pm, 1, 0, 0, 1) else pcall(pm.SetTexture, pm, "Interface\\Icons\\INV_Misc_Map_02"); pcall(pm.SetVertexColor, pm, 1, 0, 0) end
            pm:SetDrawLayer("OVERLAY", 9999)
            container._playerMarker = pm
        end
        if container.Reflow then pcall(container.Reflow, container) end
        -- auto-hide/show when world map toggles
        if type(WorldMapFrame) == "table" and WorldMapFrame:IsShown() and WorldMapDetailFrame then
            pcall(container.Show, container)
        else
            -- keep visible as overlay for quick testing
            pcall(container.Show, container)
        end
        -- persist chosen grid and enable stitched-map mode as the default
        DCMapExtensionDB = DCMapExtensionDB or {}
        DCMapExtensionDB.stitchCols = cols
        DCMapExtensionDB.stitchRows = rows
        DCMapExtensionDB.useStitchedMap = true
        if type(EnsureMapsterIntegration) == "function" then pcall(EnsureMapsterIntegration) end
        if type(ResilientShowStitch) == "function" then pcall(ResilientShowStitch) end
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: Azshara stitch applied ("..tostring(cols).."x"..tostring(rows)..") and saved as default") end
    end)
    local clearStitchBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearStitchBtn:SetSize(80, 22)
    clearStitchBtn:SetPoint("LEFT", stitchBtn, "RIGHT", 8, 0)
    clearStitchBtn:SetText("Clear")
    clearStitchBtn:SetScript("OnClick", function()
        local container = _G["DCMap_StitchFrame"]
        if container and container._tiles then
            for i, t in ipairs(container._tiles) do if t and t.SetTexture then pcall(t.SetTexture, t, nil); pcall(t.Hide, t) end end
            container._tiles = nil
            if container._playerMarker then pcall(container._playerMarker.SetTexture, container._playerMarker, nil); pcall(container._playerMarker.Hide, container._playerMarker); container._playerMarker = nil end
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: Azshara stitch cleared") end
        else
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: no Azshara stitch present") end
        end
    end)
    -- Grid options: allow custom columns/rows and per-tile ordering
    local gridLbl = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    gridLbl:SetPoint("TOPLEFT", fullBtn, "BOTTOMLEFT", 0, -36)
    gridLbl:SetText("Stitch grid (cols x rows):")
    local colsEdit = CreateFrame("EditBox", "DCMap_StitchCols", panel, "InputBoxTemplate")
    colsEdit:SetSize(40, 22)
    colsEdit:SetPoint("LEFT", gridLbl, "RIGHT", 8, 0)
    colsEdit:SetAutoFocus(false)
    colsEdit:SetNumeric(true)
    colsEdit:SetText("4")
    local rowsEdit = CreateFrame("EditBox", "DCMap_StitchRows", panel, "InputBoxTemplate")
    rowsEdit:SetSize(40, 22)
    rowsEdit:SetPoint("LEFT", colsEdit, "RIGHT", 8, 0)
    rowsEdit:SetAutoFocus(false)
    rowsEdit:SetNumeric(true)
    rowsEdit:SetText("3")
    local orderLbl = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    orderLbl:SetPoint("TOPLEFT", gridLbl, "BOTTOMLEFT", 0, -8)
    orderLbl:SetText("Tile order (comma-separated indices, optional):")
    local orderEdit = CreateFrame("EditBox", "DCMap_StitchOrder", panel, "InputBoxTemplate")
    orderEdit:SetSize(360, 22)
    orderEdit:SetPoint("LEFT", orderLbl, "RIGHT", 8, 0)
    orderEdit:SetAutoFocus(false)
    orderEdit:SetText("")
    local stitchCustomBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    stitchCustomBtn:SetSize(120, 22)
    stitchCustomBtn:SetPoint("TOPLEFT", orderLbl, "BOTTOMLEFT", 0, -8)
    stitchCustomBtn:SetText("Stitch Custom")
    stitchCustomBtn:SetScript("OnClick", function()
        local cols = tonumber(colsEdit:GetText()) or 4
        local rows = tonumber(rowsEdit:GetText()) or 3
        if cols <= 0 or rows <= 0 then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: invalid cols/rows") end
            return
        end
        -- parse order string
        local orderStr = orderEdit:GetText() or ""
        local order = {}
        if orderStr and orderStr:match('%S') then
            for token in orderStr:gmatch("([^,%s]+)") do
                local n = tonumber(token)
                if n then table.insert(order, n) end
            end
        end
        -- build stitch using specified cols/rows and optional order
        -- Prefer to parent the stitch to the world map detail frame when the world map is open
        -- allow explicit fullscreen override via saved-vars
        local parent
        if DCMapExtensionDB and DCMapExtensionDB.fullscreen then
            parent = UIParent
        elseif type(WorldMapFrame) == "table" and WorldMapFrame:IsShown() and WorldMapDetailFrame then
            parent = WorldMapDetailFrame
        else
            if DCMapExtensionDB and DCMapExtensionDB.fullscreen then
                parent = UIParent
            else
                parent = addon.background or WorldMapDetailFrame or UIParent
            end
        end
    local pw = SafeGetWidth(parent)
    local ph = SafeGetHeight(parent)
        if not pw or not ph then
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: unable to determine parent size for stitching") end
            return
        end
        local container = _G["DCMap_StitchFrame"]
        if container and container.Destroy then pcall(container.Hide, container) end
    container = GetOrCreateStitchFrame(parent, cols, rows)
        if DCMapExtensionDB and DCMapExtensionDB.interactable then
            if container.EnableMouse then pcall(container.EnableMouse, container, true) end
            if container.SetScript then
                pcall(container.SetScript, container, "OnEnter", function(self) if GameTooltip and GameTooltip.SetOwner then pcall(GameTooltip.SetOwner, GameTooltip, self, "ANCHOR_RIGHT"); pcall(GameTooltip.SetText, GameTooltip, "Stitched Map") ; pcall(GameTooltip.Show, GameTooltip) end end)
                pcall(container.SetScript, container, "OnLeave", function(self) if GameTooltip and GameTooltip.Hide then pcall(GameTooltip.Hide, GameTooltip) end end)
                pcall(container.SetScript, container, "OnMouseDown", function(self, button) pcall(ReportClickToChatWithMapCoords, self, button) end)
            end
        end
    local scale = tonumber(DCMapExtensionDB and DCMapExtensionDB.fullscreenScale) or 1.0
    if parent == UIParent and DCMapExtensionDB and DCMapExtensionDB.fullscreen and scale and scale < 1.0 then
        local sw = SafeGetWidth(parent) or 0
        local sh = SafeGetHeight(parent) or 0
        container:SetSize(sw * scale, sh * scale)
        container:ClearAllPoints()
        container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    else
        container:SetAllPoints(parent)
    end
    container:SetFrameStrata("HIGH")
    local pLevel = (parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 0
    container:SetFrameLevel(pLevel + 50)
    if parent == UIParent then
        local cbtn = CreateFrame("Button", nil, container, "UIPanelCloseButton")
        if cbtn and cbtn.SetPoint then cbtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", -6, -6) end
        if cbtn and cbtn.SetScript then cbtn:SetScript("OnClick", function() pcall(container.Hide, container) end) end
    end
        container._cols = cols
        container._rows = rows
        container._paths = azsharaBLPs
        function container:Reflow()
            -- compute sizes from the container so texture anchors align to the canvas
            local cw = SafeGetWidth(self)
            local ch = SafeGetHeight(self)
            if not cw or not ch then return end
            local cols = tonumber(self._cols) or 1
            local rows = tonumber(self._rows) or 1
            if cols <= 0 or rows <= 0 then return end
            -- integer-safe reflow: round container size and distribute remainder pixels
            local cw_i = math.floor((cw or 0) + 0.5)
            local ch_i = math.floor((ch or 0) + 0.5)
            local tileWBase = (cols > 0) and math.floor(cw_i / cols) or 0
            local extraW = cw_i - tileWBase * cols
            local tileHBase = (rows > 0) and math.floor(ch_i / rows) or 0
            local extraH = ch_i - tileHBase * rows
            for idx, tex in ipairs(self._tiles or {}) do
                if tex then
                    local c = ((idx - 1) % cols) + 1
                    local r = math.floor((idx - 1) / cols) + 1
                    local w = tileWBase + ((c <= extraW) and 1 or 0)
                    local h = tileHBase + ((r <= extraH) and 1 or 0)
                    local left = (c - 1) * tileWBase + math.min(c - 1, extraW)
                    local top = (r - 1) * tileHBase + math.min(r - 1, extraH)
                    tex:SetSize(w, h)
                    tex:ClearAllPoints()
                    tex:SetPoint("TOPLEFT", self, "TOPLEFT", left, -top)
                end
            end
            if self._playerMarker then
                if type(GetPlayerMapPosition) == "function" then
                    local nx, ny = GetPlayerMapPosition("player")
                    if nx and ny then
                        local px = nx * cw
                        local py = ny * ch
                        self._playerMarker:ClearAllPoints()
                        self._playerMarker:SetPoint("CENTER", self, "TOPLEFT", px, -py)
                    end
                end
            end
            -- one-shot diagnostic snapshot for alignment troubleshooting
            pcall(PrintReflowSnapshot, self, parent)
        end
        container:SetScript("OnSizeChanged", function(self, w, h) if self.Reflow then pcall(self.Reflow, self) end end)
        container._playerTimer = 0
        container:SetScript("OnUpdate", function(self, elapsed)
            self._playerTimer = (self._playerTimer or 0) + elapsed
            if self._playerTimer < 0.2 then return end
            self._playerTimer = 0
            if self._playerMarker then
                if type(GetPlayerMapPosition) == "function" then
                    local nx, ny = GetPlayerMapPosition("player")
                    if nx and ny then
                        local pw = SafeGetWidth(self)
                        local ph = SafeGetHeight(self)
                        local px = nx * pw
                        local py = ny * ph
                        pcall(self._playerMarker.ClearAllPoints, self._playerMarker)
                        pcall(self._playerMarker.SetPoint, self._playerMarker, "CENTER", self, "TOPLEFT", px, -py)
                    end
                end
            end
        end)
        if container._tiles then
            for i, t in ipairs(container._tiles) do if t and t.SetTexture then pcall(t.SetTexture, t, nil); pcall(t.Hide, t) end end
        end
    container._tiles = {}
    local cw = SafeGetWidth(container) or pw
    local ch = SafeGetHeight(container) or ph
    -- integer-safe sizing for custom stitch as well
    local cw_i = math.floor((cw or 0) + 0.5)
    local ch_i = math.floor((ch or 0) + 0.5)
    local tileWBase = (cols > 0) and math.floor(cw_i / cols) or 0
    local extraW = cw_i - tileWBase * cols
    local tileHBase = (rows > 0) and math.floor(ch_i / rows) or 0
    local extraH = ch_i - tileHBase * rows
        local total = cols * rows
        for idx = 1, total do
            local useIndex = order[idx] or idx
            local path = azsharaBLPs[useIndex]
            local c = ((idx - 1) % cols) + 1
            local r = math.floor((idx - 1) / cols) + 1
            local w = tileWBase + ((c <= extraW) and 1 or 0)
            local h = tileHBase + ((r <= extraH) and 1 or 0)
            local left = (c - 1) * tileWBase + math.min(c - 1, extraW)
            local top = (r - 1) * tileHBase + math.min(r - 1, extraH)
            if not path then
                if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: no tile for index %d (requested %d)", idx, useIndex)) end
                -- create an empty placeholder to keep layout consistent
                local tex = container:CreateTexture(nil, "ARTWORK")
                tex:SetSize(w, h)
                tex:SetPoint("TOPLEFT", container, "TOPLEFT", left, -top)
                tex:Hide()
                table.insert(container._tiles, tex)
            else
                local tex = container:CreateTexture(nil, "ARTWORK")
                tex:SetSize(w, h)
                tex:SetPoint("TOPLEFT", container, "TOPLEFT", left, -top)
                tex:SetTexCoord(0, 1, 0, 1)
                local ok, err = pcall(function() tex:SetTexture(path) end)
                if ok then
                    container._tileSuccess = (container._tileSuccess or 0) + 1
                end
                container._tileTotal = (container._tileTotal or 0) + 1
                table.insert(container._tiles, tex)
            end
        end
        if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            local s = container._tileSuccess or 0
            local t = container._tileTotal or 0
            pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: custom stitch applied %d/%d tiles", s, t))
        end
        -- create or update player marker on the stitched container
        if not container._playerMarker then
            local pm = container:CreateTexture(nil, "OVERLAY")
            pm:SetSize(16, 16)
            if pm.SetColorTexture then pcall(pm.SetColorTexture, pm, 1, 0, 0, 1) else pcall(pm.SetTexture, pm, "Interface\\Icons\\INV_Misc_Map_02"); pcall(pm.SetVertexColor, pm, 1, 0, 0) end
            pm:SetDrawLayer("OVERLAY", 9999)
            container._playerMarker = pm
        end
        if container.Reflow then pcall(container.Reflow, container) end
        if type(WorldMapFrame) == "table" and WorldMapFrame:IsShown() and WorldMapDetailFrame then pcall(container.Show, container) else pcall(container.Show, container) end
        -- persist custom grid and enable stitched-map mode as default
        DCMapExtensionDB = DCMapExtensionDB or {}
        DCMapExtensionDB.stitchCols = cols
        DCMapExtensionDB.stitchRows = rows
        DCMapExtensionDB.useStitchedMap = true
        if type(EnsureMapsterIntegration) == "function" then pcall(EnsureMapsterIntegration) end
        if type(ResilientShowStitch) == "function" then pcall(ResilientShowStitch) end
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("DC-MapExtension: custom stitch applied (%dx%d) and saved as default", cols, rows)) end
    end)
    panel.refresh = function(self)
        DCMapExtensionDB = DCMapExtensionDB or {}
        debugCB:SetChecked(DCMapExtensionDB.debug and true)
        edit:SetText(tostring(DCMapExtensionDB.mapId or MAP_ID_AZSHARA_CRATER))
        stitchUseCB:SetChecked(DCMapExtensionDB.useStitchedMap and true)
        fullscreenCB:SetChecked(DCMapExtensionDB.fullscreen and true)
        interactCB:SetChecked(DCMapExtensionDB.interactable and true)
        colsEdit:SetText(tostring(DCMapExtensionDB.stitchCols or 4))
        rowsEdit:SetText(tostring(DCMapExtensionDB.stitchRows or 3))
        -- refresh scale box
        local s = tonumber(DCMapExtensionDB.fullscreenScale) or 1.0
        local scBox = _G["DCMapExtensionFullscreenScale"]
        if scBox and scBox.SetText then scBox:SetText(tostring(s)) end
    end
    panel.default = function(self)
        DCMapExtensionDB = DCMapExtensionDB or {}
        DCMapExtensionDB.debug = nil
        DCMapExtensionDB.mapId = MAP_ID_AZSHARA_CRATER
        DCMapExtensionDB.useStitchedMap = nil
        DCMapExtensionDB.fullscreen = nil
        DCMapExtensionDB.fullscreenScale = 1.0
        DCMapExtensionDB.interactable = nil
        DCMapExtensionDB.stitchCols = 4
        DCMapExtensionDB.stitchRows = 3
        panel.refresh()
    end
    InterfaceOptions_AddCategory(panel)
end

