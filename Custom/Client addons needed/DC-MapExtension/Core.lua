
local MAP_ID_AZSHARA_CRATER = 37

local BLP_TEXTURE = "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater.blp"
local PNG_TEXTURE = "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater.png"
local PNG_POT_TEXTURE = "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater_1024.png"

-- Known textures packaged with the addon (used for one-time diagnostics)
-- lightweight addon table must be defined before any addon.* fields are used
local addon = {}

-- Known textures packaged with the addon (used for one-time diagnostics)
addon.availableTextures = {
    "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater_1024.png",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater.png",
    "Interface\\AddOns\\DC-MapExtension\\Textures\\azshara_crater.blp",
}

DCMap_HotspotsSaved = DCMap_HotspotsSaved or {}

addon.forcedTexture = addon.forcedTexture or "auto" -- "auto", "png", "blp"

DCMapExtensionDB = DCMapExtensionDB or {}
-- Allow admin/users to override the map id for the background via saved-vars
if DCMapExtensionDB.mapId == nil then DCMapExtensionDB.mapId = MAP_ID_AZSHARA_CRATER end
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
    -- Support explicit modes: "png1024" (prefer 1024 PNG), "png" (prefer regular png), "blp", or "auto"
    if addon.forcedTexture == "png1024" then
        if FileExists(PNG_POT_TEXTURE) then return PNG_POT_TEXTURE end
        if FileExists(PNG_TEXTURE) then return PNG_TEXTURE end
    elseif addon.forcedTexture == "png" then
        if FileExists(PNG_TEXTURE) then return PNG_TEXTURE end
        if FileExists(PNG_POT_TEXTURE) then return PNG_POT_TEXTURE end
    elseif addon.forcedTexture == "blp" then
        if FileExists(BLP_TEXTURE) then return BLP_TEXTURE end
    else
        if FileExists(PNG_POT_TEXTURE) then return PNG_POT_TEXTURE end
        if FileExists(PNG_TEXTURE) then return PNG_TEXTURE end
        if FileExists(BLP_TEXTURE) then return BLP_TEXTURE end
    end
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

        local function trySetTexture(path)
            if not path then return false end
            if not (addon.bgTex and addon.bgTex.SetTexture) then return false end
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

            if IsDebugEnabled() and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                local ts = Timestamp()
                local mode = tostring(addon.forcedTexture or "auto")
                if ok then
                    pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format("%s | mode=%s | SetTexture OK -> %s | %s", ts, mode, tostring(path), sizeInfo))
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
                pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension: using texture -> "..tostring(chosen))
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
    else
        addon.background:Hide()
        RestoreDetailTextures()
    end
end

-- POI simple rendering (keeps minimal feature parity)
addon.poiFrames = addon.poiFrames or {}
local function CreatePOI(mapFrame, nx, ny, label, id)
    if not nx or not ny or not mapFrame then return end
    local w = mapFrame:GetWidth() or 512
    local h = mapFrame:GetHeight() or 512
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
    return poi
end

local function ClearAllPOIs()
    for id, frame in pairs(addon.poiFrames) do if frame and frame.Hide then frame:Hide() end; addon.poiFrames[id] = nil end
end

local function RenderHotspotsForMap(mapId)
    ClearAllPOIs()
    if not DCMap_HotspotsSaved[mapId] then return end
    for _, hs in ipairs(DCMap_HotspotsSaved[mapId]) do
        if hs.nx and hs.ny then
            local label = hs.label or ("Hotspot #" .. tostring(hs.id))
            local poi = CreatePOI(WorldMapDetailFrame, hs.nx, hs.ny, label, hs.id)
            if poi then addon.poiFrames[hs.id] = poi end
        end
    end
end

local function ParseHotspotPayload(payload)
    local result = {}
    if not payload then return result end
    local start = payload:find("HOTSPOT_ADDON")
    if start then payload = payload:sub(start) end
    if payload:sub(1,13) == "HOTSPOT_ADDON|" then payload = payload:sub(14) end
    for token in payload:gmatch("([^|]+)") do
        local k, v = token:match("^([^:]+):(.+)$")
        if k and v then result[k] = v end
    end
    if result.map then result.map = tonumber(result.map) end
    if result.nx then result.nx = tonumber(result.nx) end
    if result.ny then result.ny = tonumber(result.ny) end
    if result.id then result.id = tonumber(result.id) end
    return result
end

local function HandleIncomingHotspot(rawPayload)
    if not rawPayload then return end
    local parsed = ParseHotspotPayload(tostring(rawPayload))
    if not parsed or not parsed.map or not parsed.id then return end
    DCMap_HotspotsSaved[parsed.map] = DCMap_HotspotsSaved[parsed.map] or {}
    local found = false
    for i, hs in ipairs(DCMap_HotspotsSaved[parsed.map]) do
        if hs.id == parsed.id then DCMap_HotspotsSaved[parsed.map][i] = parsed; found = true; break end
    end
    if not found then table.insert(DCMap_HotspotsSaved[parsed.map], parsed) end
    local currentMapID = GetCurrentMapAreaID() or 0
    if currentMapID == parsed.map then RenderHotspotsForMap(parsed.map) end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("WORLD_MAP_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then EnsureMapBackgroundFrame(); PrintTextureDiagnosticsOnce()
    elseif event == "WORLD_MAP_UPDATE" then
        local currentMapID = GetCurrentMapAreaID() or 0
        ShowMapBackgroundIfNeeded(currentMapID)
        RenderHotspotsForMap(currentMapID)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix = arg1; local message = arg2
        if message == nil and prefix ~= nil then message = prefix; prefix = nil end
        if (prefix == "HOTSPOT" or (message and message:find("HOTSPOT_ADDON"))) then HandleIncomingHotspot(message) end
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = arg1
        if message and message:find("HOTSPOT_ADDON") then HandleIncomingHotspot(message) end
    end
end)

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

if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "DC-MapExtension loaded") end

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

-- Interface Options Panel --------------------------------------------------
do
    local panel = CreateFrame("Frame", "DCMapExtensionOptionsPanel", UIParent)
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

    panel.refresh = function(self)
        DCMapExtensionDB = DCMapExtensionDB or {}
        debugCB:SetChecked(DCMapExtensionDB.debug and true)
        edit:SetText(tostring(DCMapExtensionDB.mapId or MAP_ID_AZSHARA_CRATER))
    end

    panel.default = function(self)
        DCMapExtensionDB = DCMapExtensionDB or {}
        DCMapExtensionDB.debug = nil
        DCMapExtensionDB.mapId = MAP_ID_AZSHARA_CRATER
        panel.refresh()
    end

    InterfaceOptions_AddCategory(panel)
end
