-- HotspotDisplay (Wrath 3.3.5a polished)
-- Defensive, uses Astrolabe when available for accurate pin placement
-- Minimal dependencies, robust parsing of server HOTSPOT messages

local ADDON_NAME = "HotspotDisplayWrath"
local ADDON_VERSION = "1.0"

-- Saved variables
HotspotDisplayDB = HotspotDisplayDB or { enabled = true, showMapList = true, textSize = 16, showMinimapPins = true, showWorldLabels = true }

local activeHotspots = {} -- [id] = {map, zone, x, y, nx, ny, expire, icon, bonus}
local worldPins = {} -- [id] = frame
local worldLabels = {} -- [id] = FontString for XP+ text
local minimapPins = {} -- [id] = frame
local linePool = {} -- reusable UI lines for hotspot list

-- Try to use Astrolabe library if present (common on Wrath clients)
local Astrolabe = nil
if IsAddOnLoaded and IsAddOnLoaded("Astrolabe") then
    Astrolabe = Astrolabe or _G.Astrolabe
end

local function DefensiveToNumber(s)
    if not s then return nil end
    local n = tonumber(s)
    return n
end

local function ParsePayload(msg)
    local data = {}
    if not msg or type(msg) ~= "string" then return data end
    -- If the message starts with prefix, strip it
    if msg:sub(1,12) == "HOTSPOT_ADDON" then
        msg = msg:sub(13)
    end
    for token in string.gmatch(msg, "[^|]+") do
        local k,v = string.match(token, "([^:]+):(.+)")
        if k and v then data[k] = v end
    end
    return data
end

local function CreateWorldPin(id, info)
    if worldPins[id] then return worldPins[id] end
    if not WorldMapFrame then return end
    local pin = CreateFrame("Button", "HotspotWorldPin"..id, WorldMapFrame)
    pin:SetSize(20,20)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin.texture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Hotspot #"..tostring(id))
        if info.zone then GameTooltip:AddLine("Zone: "..tostring(info.zone)) end
        if info.x and info.y then GameTooltip:AddLine(string.format("Coords: %.1f, %.1f", info.x, info.y)) end
        if info.expire then GameTooltip:AddLine("Expires in "..tostring(math.max(0, math.floor(info.expire - GetTime()))).."s") end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin:SetScript("OnClick", function()
        if not WorldMapFrame:IsShown() then ToggleWorldMap() end
    end)
    worldPins[id] = pin
    return pin
end

local function CreateWorldLabel(id, info)
    if worldLabels[id] then return worldLabels[id] end
    if not WorldMapFrame then return end
    local lbl = WorldMapFrame:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", HotspotDisplayDB.textSize, "OUTLINE")
    lbl:SetTextColor(1, 0.84, 0)
    lbl:Hide()
    worldLabels[id] = lbl
    return lbl
end

local function CreateMinimapPin(id, info)
    if minimapPins[id] then return minimapPins[id] end
    if not Minimap then return end
    local pin = CreateFrame("Frame", "HotspotMinimapPin"..id, Minimap)
    pin:SetSize(14,14)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin.texture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    pin:Hide()
    minimapPins[id] = pin
    return pin
end

local function PositionWorldPin(pin, info)
    if not pin or not info then return end
    if Astrolabe and info.nx and info.ny then
        local px, py
        do
            local ok1, a1, b1 = pcall(function() return Astrolabe.WorldToMapPixels(WorldMapFrame, info.nx, info.ny) end)
            if ok1 and a1 and b1 then px, py = a1, b1 end
            if not px then
                local ok2, a2, b2 = pcall(function() return Astrolabe.WorldToMapPixels(Astrolabe, WorldMapFrame, info.nx, info.ny) end)
                if ok2 and a2 and b2 then px, py = a2, b2 end
            end
        end
        if px and py then
            pcall(function()
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", px, py)
                pin:Show()
            end)
            return
        end
    end
    -- fallback: crude normalization
    if info.x and info.y and WorldMapFrame then
        local nx = info.x
        local ny = info.y
        if nx > 1 then nx = nx / 100 end
        if ny > 1 then ny = ny / 100 end
        local w = WorldMapFrame:GetWidth()
        local h = WorldMapFrame:GetHeight()
        pcall(function()
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", nx * w, -ny * h)
            pin:Show()
        end)
    end
end

local function PositionMinimapPin(pin, info)
    if not pin or not info then return end
    -- Prefer a simple, robust normalized placement instead of relying solely on Astrolabe signatures
    local nx = info.nx or info.x
    local ny = info.ny or info.y
    if nx and ny then
        -- convert large coordinates (0..1000 / >1) to normalized 0..1 scale
        if type(nx) == "number" and type(ny) == "number" then
            if nx > 1 then nx = nx / 100 end
            if ny > 1 then ny = ny / 100 end
            -- Ensure Minimap exists and has dimensions
            if Minimap and Minimap.GetWidth and Minimap.GetHeight then
                local mw = Minimap:GetWidth()
                local mh = Minimap:GetHeight()
                -- compute offset relative to Minimap center
                local ox = (nx - 0.5) * mw
                local oy = (0.5 - ny) * mh
                pcall(function()
                    pin:ClearAllPoints()
                    pin:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
                    if HotspotDisplayDB.showMinimapPins then pin:Show() else pin:Hide() end
                end)
                return
            end
        end
    end
    -- Last-resort: show pin but don't try to position it (prevents crash)
    pcall(function() if HotspotDisplayDB.showMinimapPins then pin:Show() else pin:Hide() end end)
end

local function RegisterHotspotFromData(data)
    local id = DefensiveToNumber(data.id) or nil
    if not id then return end
    local dur = DefensiveToNumber(data.dur) or 0
    local map = DefensiveToNumber(data.map)
    local zone = data.zone
    local x = DefensiveToNumber(data.x) or 0
    local y = DefensiveToNumber(data.y) or 0
    local nx = DefensiveToNumber(data.nx)
    local ny = DefensiveToNumber(data.ny)
    local icon = DefensiveToNumber(data.icon)
    local bonus = DefensiveToNumber(data.icon) and nil or DefensiveToNumber(data.bonus)
    -- server sends bonus in announce text as experienceBonus; prefer explicit 'bonus' key if present
    if data.bonus then bonus = DefensiveToNumber(data.bonus) end
    activeHotspots[id] = { map = map, zone = zone, x = x, y = y, nx = nx, ny = ny, expire = GetTime() + dur, icon = icon, bonus = bonus }
    -- If this looks like a synthetic/test hotspot (IDs reserved >=9000), don't create UI — register-only mode
    local isTestHotspot = (id and type(id) == "number" and id >= 9000)
    if not isTestHotspot then
        -- Defer UI work: create pins/labels in a safe, pcall-wrapped function after a short delay
        local function SafeCreatePins(hotspotId)
            pcall(function()
                local info = activeHotspots[hotspotId]
                if not info then return end
                local wpin = CreateWorldPin(hotspotId, info)
                if wpin then PositionWorldPin(wpin, info) end
                local mpin = CreateMinimapPin(hotspotId, info)
                if mpin then PositionMinimapPin(mpin, info) end
                local lbl = CreateWorldLabel(hotspotId, info)
                if lbl then
                    if info.bonus then lbl:SetText("XP+"..tostring(info.bonus).."%") else lbl:SetText("XP+") end
                    -- position label defensively
                    local ok, px, py = pcall(function() return (Astrolabe and Astrolabe.WorldToMapPixels and Astrolabe.WorldToMapPixels(WorldMapFrame, info.nx, info.ny)) end)
                    if ok and px and py then lbl:ClearAllPoints(); lbl:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", px, py - 14); end
                    if HotspotDisplayDB.showWorldLabels then lbl:Show() else lbl:Hide() end
                end
                if mpin then if HotspotDisplayDB.showMinimapPins then mpin:Show() else mpin:Hide() end end
            end)
        end

        -- Schedule with a short delay so UI globals are initialized and race conditions avoided
        C_Timer.After(0.05, function() SafeCreatePins(id) end)
    else
        -- For test hotspots, just log minimal info to chat for visibility (no UI)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[Hotspot]|r (test) Hotspot #"..id.." registered (no UI created)")
    end
    -- Announce to chat
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[Hotspot]|r Hotspot #"..id.." registered")
    -- Note: visibility and creation are handled by SafeCreatePins scheduled above
    -- Update world list UI if open
    if HotspotListFrame and HotspotListFrame:IsShown() and HotspotListFrame.refresh then
        HotspotListFrame:refresh()
    end
end

-- Create a simple clickable hotspot list on the world map
local HotspotListFrame = nil
local function EnsureHotspotList()
    if HotspotListFrame then return HotspotListFrame end
    HotspotListFrame = CreateFrame("Frame", "HotspotListFrame", UIParent, "BackdropTemplate")
    HotspotListFrame:SetSize(300, 200)
    HotspotListFrame:SetPoint("CENTER", UIParent, "CENTER")
    HotspotListFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "", tile = true, tileSize = 16, edgeSize = 16 })
    HotspotListFrame:Hide()

    HotspotListFrame.title = HotspotListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    HotspotListFrame.title:SetPoint("TOP", HotspotListFrame, "TOP", 0, -10)
    HotspotListFrame.title:SetText("Active Hotspots")

    HotspotListFrame.scroll = CreateFrame("ScrollFrame", "HotspotListScroll", HotspotListFrame, "UIPanelScrollFrameTemplate")
    HotspotListFrame.scroll:SetPoint("TOPLEFT", HotspotListFrame, "TOPLEFT", 10, -40)
    HotspotListFrame.scroll:SetPoint("BOTTOMRIGHT", HotspotListFrame, "BOTTOMRIGHT", -30, 10)

    HotspotListFrame.content = CreateFrame("Frame", nil, HotspotListFrame.scroll)
    HotspotListFrame.content:SetSize(260, 160)
    HotspotListFrame.scroll:SetScrollChild(HotspotListFrame.content)

    -- checkbox toggles
    HotspotListFrame.minimapToggle = CreateFrame("CheckButton", nil, HotspotListFrame, "UICheckButtonTemplate")
    HotspotListFrame.minimapToggle:SetPoint("TOPLEFT", HotspotListFrame, "TOPLEFT", 10, -16)
    HotspotListFrame.minimapToggleText = HotspotListFrame.minimapToggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HotspotListFrame.minimapToggleText:SetPoint("LEFT", HotspotListFrame.minimapToggle, "RIGHT", 4, 1)
    HotspotListFrame.minimapToggleText:SetText("Show Minimap Pins")
    HotspotListFrame.minimapToggle:SetChecked(HotspotDisplayDB.showMinimapPins)
    HotspotListFrame.minimapToggle:SetScript("OnClick", function(self)
        HotspotDisplayDB.showMinimapPins = self:GetChecked()
        for id,p in pairs(minimapPins) do if p then if HotspotDisplayDB.showMinimapPins then p:Show() else p:Hide() end end end
    end)

    HotspotListFrame.worldLabelToggle = CreateFrame("CheckButton", nil, HotspotListFrame, "UICheckButtonTemplate")
    HotspotListFrame.worldLabelToggle:SetPoint("TOPLEFT", HotspotListFrame, "TOPLEFT", 150, -16)
    HotspotListFrame.worldLabelToggleText = HotspotListFrame.worldLabelToggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    HotspotListFrame.worldLabelToggleText:SetPoint("LEFT", HotspotListFrame.worldLabelToggle, "RIGHT", 4, 1)
    HotspotListFrame.worldLabelToggleText:SetText("Show World Labels")
    HotspotListFrame.worldLabelToggle:SetChecked(HotspotDisplayDB.showWorldLabels)
    HotspotListFrame.worldLabelToggle:SetScript("OnClick", function(self)
        HotspotDisplayDB.showWorldLabels = self:GetChecked()
        for id,l in pairs(worldLabels) do if l then if HotspotDisplayDB.showWorldLabels then l:Show() else l:Hide() end end end
    end)

    HotspotListFrame.linePool = linePool
    HotspotListFrame.maxLines = 64
    HotspotListFrame.usedLines = {}
    HotspotListFrame.getLine = function()
        for i=1,HotspotListFrame.maxLines do
            if not HotspotListFrame.linePool[i] then
                local line = CreateFrame("Frame", nil, HotspotListFrame.content)
                line:SetSize(240, 24)
                line.text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                line.text:SetPoint("LEFT", line, "LEFT", 0, 0)
                line.button = CreateFrame("Button", nil, line, "UIPanelButtonTemplate")
                line.button:SetSize(60, 20)
                line.button:SetPoint("RIGHT", line, "RIGHT", 0, 0)
                line.button:SetText("Center")
                HotspotListFrame.linePool[i] = line
            end
            if not HotspotListFrame.usedLines[i] then
                HotspotListFrame.usedLines[i] = HotspotListFrame.linePool[i]
                HotspotListFrame.usedLines[i]:Show()
                return HotspotListFrame.usedLines[i]
            end
        end
        return nil
    end

    HotspotListFrame.releaseAllLines = function()
        for i,l in pairs(HotspotListFrame.usedLines) do l:Hide(); HotspotListFrame.usedLines[i] = nil end
    end

    HotspotListFrame.refresh = function()
        HotspotListFrame:releaseAllLines()
        local y = -5
        local ids = {}
        for id,info in pairs(activeHotspots) do table.insert(ids, id) end
        table.sort(ids)
        for _,id in ipairs(ids) do
            local info = activeHotspots[id]
            local line = HotspotListFrame.getLine()
            if not line then break end
            line:SetPoint("TOPLEFT", HotspotListFrame.content, "TOPLEFT", 0, y)
            local rem = math.max(0, math.floor((info.expire or 0) - GetTime()))
            line.text:SetText(string.format("#%d - %s - %ds", id, tostring(info.zone or "?"), rem))
            line.button:SetScript("OnClick", function()
                -- improved centering logic with multiple fallbacks
                if info.map and type(SetMapByID) == "function" then pcall(SetMapByID, info.map) end
                if not WorldMapFrame:IsShown() then ToggleWorldMap() end
                local nx = info.nx or info.x
                local ny = info.ny or info.y
                if nx and ny then
                    if nx > 1 then nx = nx / 100 end; if ny > 1 then ny = ny / 100 end
                    pcall(function()
                        if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.ScrollTo then
                            WorldMapFrame.ScrollContainer:ScrollTo(nx, 1-ny)
                            return
                        end
                        if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.SetHorizontalScroll then
                            local canvas = WorldMapFrame.ScrollContainer:GetCanvas()
                            local width = canvas:GetWidth()
                            local height = canvas:GetHeight()
                            local targetX = (nx * width) - (WorldMapFrame:GetWidth() / 2)
                            local targetY = (ny * height) - (WorldMapFrame:GetHeight() / 2)
                            WorldMapFrame.ScrollContainer:SetHorizontalScroll(math.max(0, targetX))
                            WorldMapFrame.ScrollContainer:SetVerticalScroll(math.max(0, targetY))
                            return
                        end
                    end)
                end
                if Astrolabe and nx and ny then
                    pcall(function()
                        local ok, px, py = pcall(function() return Astrolabe.WorldToMapPixels(WorldMapFrame, nx, ny) end)
                        if ok and px and py and WorldMapFrame and WorldMapFrame.ScrollContainer then
                            if WorldMapFrame.ScrollContainer.SetHorizontalScroll then
                                local targetX = px - (WorldMapFrame:GetWidth() / 2)
                                local targetY = py - (WorldMapFrame:GetHeight() / 2)
                                WorldMapFrame.ScrollContainer:SetHorizontalScroll(math.max(0, targetX))
                                WorldMapFrame.ScrollContainer:SetVerticalScroll(math.max(0, targetY))
                            end
                        end
                    end)
                end
            end)
            y = y - 28
        end
    end

    return HotspotListFrame
end

-- slash command to toggle list
SLASH_HOTSPOTLIST1 = "/hotspotlist"
SlashCmdList["HOTSPOTLIST"] = function()
    local f = EnsureHotspotList()
    if f:IsShown() then f:Hide() else f:Show(); f.refresh() end
end

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:SetScript("OnEvent", function(self, event, ...)
    -- Capture varargs up-front (can't use '...' inside the inner non-vararg function)
    local v1, v2, v3 = ...
    -- Wrap all incoming processing in pcall to avoid Lua runtime crashes in the wild
    local ok, err = pcall(function()
        if event == "CHAT_MSG_ADDON" then
            local prefix, msg = v1, v2
            if prefix == "HOTSPOT" and msg then
                local data = ParsePayload(msg)
                if data and type(data) == "table" then
                    pcall(function() RegisterHotspotFromData(data) end)
                end
            end
        elseif event == "CHAT_MSG_SYSTEM" then
            local msg = v1
            if type(msg) == "string" and msg:sub(1,12) == "HOTSPOT_ADDON" then
                local data = ParsePayload(msg)
                if data and type(data) == "table" then
                    pcall(function() RegisterHotspotFromData(data) end)
                end
            end
        end
    end)
    if not ok then
        -- Log minimal diagnostic to chat without spamming; sanitize error
        local errMsg = tostring(err or "unknown error")
        errMsg = errMsg:gsub("\n"," "):gsub("\r"," ")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HotspotDisplay]|r handler error: "..errMsg)
    end
end)

-- Cleanup expired hotspots periodically
-- Wrath-compatible ticker using frame OnUpdate instead of C_Timer (which doesn't exist in Wrath)
local tickerFrame = CreateFrame("Frame")
local tickerElapsed = 0
tickerFrame:SetScript("OnUpdate", function(self, elapsed)
    tickerElapsed = tickerElapsed + elapsed
    if tickerElapsed < 5 then return end
    tickerElapsed = 0
    local now = GetTime()
    for id,info in pairs(activeHotspots) do
        if info.expire and info.expire <= now then
            activeHotspots[id] = nil
            if worldPins[id] then worldPins[id]:Hide(); worldPins[id] = nil end
            if minimapPins[id] then minimapPins[id]:Hide(); minimapPins[id] = nil end
            if worldLabels[id] then worldLabels[id]:Hide(); worldLabels[id] = nil end
            -- refresh list UI if open
            if HotspotListFrame and HotspotListFrame:IsShown() and HotspotListFrame.refresh then HotspotListFrame:refresh() end
        else
            if worldPins[id] then PositionWorldPin(worldPins[id], info) end
            if minimapPins[id] then PositionMinimapPin(minimapPins[id], info) end
            if worldLabels[id] then
                -- reposition label
                local lbl = worldLabels[id]
                if lbl and WorldMapFrame then
                    local nx = info.nx or info.x
                    local ny = info.ny or info.y
                    if nx and ny then
                        if nx > 1 then nx = nx / 100 end; if ny > 1 then ny = ny / 100 end
                        local w = WorldMapFrame:GetWidth(); local h = WorldMapFrame:GetHeight()
                        lbl:ClearAllPoints(); lbl:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", nx * w, -ny * h - 14); lbl:Show()
                    end
                end
            end
        end
    end
end)

-- Reposition labels on map show/resize for immediate feedback
if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", function() for id, info in pairs(activeHotspots) do if worldLabels[id] then local nx = info.nx or info.x; local ny = info.ny or info.y; if nx and ny then if nx > 1 then nx = nx/100 end; if ny > 1 then ny = ny/100 end; local w = WorldMapFrame:GetWidth(); local h = WorldMapFrame:GetHeight(); worldLabels[id]:ClearAllPoints(); worldLabels[id]:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", nx * w, -ny * h - 14); worldLabels[id]:Show(); end end end end)
    WorldMapFrame:HookScript("OnSizeChanged", function() for id, info in pairs(activeHotspots) do if worldLabels[id] then local nx = info.nx or info.x; local ny = info.ny or info.y; if nx and ny then if nx > 1 then nx = nx/100 end; if ny > 1 then ny = ny/100 end; local w = WorldMapFrame:GetWidth(); local h = WorldMapFrame:GetHeight(); worldLabels[id]:ClearAllPoints(); worldLabels[id]:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", nx * w, -ny * h - 14); worldLabels[id]:Show(); end end end end)
end

DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplayWrath]|r loaded v"..ADDON_VERSION)
