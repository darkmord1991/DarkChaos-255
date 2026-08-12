--[[--------------------------------------------------------------------------
    DC Boss Tracker - retail-style dungeon/raid encounter checklist
    ---------------------------------------------------------------------------

    Draws the "Dungeon / <instance> / N/1 <boss> defeated" block that retail
    shows above the quest tracker, driven entirely by the server's DENC module
    (src/server/scripts/DC/AddonExtension/dc_addon_encounters.cpp).

    Why it lives in DC-Journal: the journal already owns the per-instance art
    (JOURNALINSTANCE carries the LFG icon keyed by real map id), so the banner
    icon comes free and stays consistent with the Adventure Guide.

    Protocol (module "DENC"), keyed by DungeonEncounter.dbc entry id:
        CMSG_REQUEST   0x01  ask for the current instance's list
        SMSG_LIST      0x10  {m, d, n, b:[{e, t, k}]}  full list + state
        SMSG_ENCOUNTER 0x11  {m, d, e, k}              one boss changed
        SMSG_CLEAR     0x12  {}                        hide the block

    The server pushes on instance entry and on every boss kill, so the only
    client-initiated request is a re-sync after a UI reload (where the entry
    push is long gone). That request is cooldown-gated rather than latch-gated:
    a reply-dependent request behind a disabled server module would otherwise
    re-fire forever. See the QNAV anti-DoS note in the WXL tracker port.
--------------------------------------------------------------------------]]--

local T = {}

T.MODULE          = "DENC"
T.CMSG_REQUEST    = 0x01
T.SMSG_LIST       = 0x10
T.SMSG_ENCOUNTER  = 0x11
T.SMSG_CLEAR      = 0x12

T.ICON_CHECK = "Interface\\Scenarios\\ScenarioIcon-Check"
T.ICON_DASH  = "Interface\\Scenarios\\ScenarioIcon-Dash"

T.WIDTH        = 210
T.LINE_HEIGHT  = 18
T.PADDING      = 10
T.MAX_LINES    = 16

-- Retail objective-tracker colours: a cleared objective dims to grey, an
-- outstanding one stays gold. The check/dash icon carries the colour cue.
T.COLOR_DONE    = { 0.60, 0.60, 0.60 }
T.COLOR_PENDING = { 1.00, 0.78, 0.20 }

T.state = {
    mapId       = nil,
    difficulty  = nil,
    name        = nil,
    bosses      = {},   -- ordered array of { id = <dbc entry>, name = <string>, killed = <bool> }
    byId        = {},   -- dbc entry -> index into bosses
    collapsed   = false,
    lastRequest = 0,
    replySeen   = false,
    requestsMade = 0,
}

T.lines = {}

-- ---------------------------------------------------------------------------
-- Instance icon lookup
-- ---------------------------------------------------------------------------
-- JOURNALINSTANCE rows are {name, lore, btnIcon, smallIcon, bg, loreBg, mapID,
-- areaID, order, flags, id, worldMapAreaID}. Field 4 (smallIcon) is the LFG
-- dungeon icon - the same crossed-swords art retail puts on the banner. Built
-- once on first use; the table is static addon data.
T.iconByMap = nil

function T.GetInstanceIcon(mapId)
    if not mapId then
        return nil
    end

    if not T.iconByMap then
        T.iconByMap = {}
        local instances = rawget(_G, "JOURNALINSTANCE")
        if type(instances) == "table" then
            for _, row in pairs(instances) do
                if type(row) == "table" and row[7] and row[4] and row[4] ~= "" then
                    -- First writer wins: several journal entries can share a map
                    -- (difficulty variants), and their icons are identical.
                    if not T.iconByMap[row[7]] then
                        T.iconByMap[row[7]] = row[4]
                    end
                end
            end
        end
    end

    return T.iconByMap[mapId]
end

-- ---------------------------------------------------------------------------
-- Frame construction
-- ---------------------------------------------------------------------------
function T.CreateLine(index)
    local line = T.frame:CreateTexture(nil, "ARTWORK")
    line:SetWidth(16)
    line:SetHeight(16)

    local text = T.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetJustifyH("LEFT")
    text:SetWidth(T.WIDTH - T.PADDING * 2 - 20)

    if index == 1 then
        line:SetPoint("TOPLEFT", T.banner, "BOTTOMLEFT", 0, -6)
    else
        line:SetPoint("TOPLEFT", T.lines[index - 1].icon, "BOTTOMLEFT", 0, -2)
    end
    text:SetPoint("LEFT", line, "RIGHT", 4, 0)

    T.lines[index] = { icon = line, text = text }
    return T.lines[index]
end

function T.EnsureFrame()
    if T.frame then
        return T.frame
    end

    local frame = CreateFrame("Frame", "DCBossTrackerFrame", UIParent)
    frame:SetWidth(T.WIDTH)
    frame:SetHeight(60)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.55)
    frame:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.8)

    -- Header ("Dungeon") doubles as the collapse toggle and the drag handle.
    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", T.PADDING, -T.PADDING)
    header:SetText("Dungeon")
    header:SetTextColor(1.0, 0.82, 0.0)
    frame.header = header

    local toggle = CreateFrame("Button", nil, frame)
    toggle:SetAllPoints(header)
    toggle:RegisterForClicks("LeftButtonUp")
    toggle:SetScript("OnClick", function() T.ToggleCollapsed() end)

    -- The button covers the header, so it would otherwise swallow the drag that
    -- starts over the most natural grab point. Forward it to the frame.
    toggle:RegisterForDrag("RightButton")
    toggle:SetScript("OnDragStart", function() frame:StartMoving() end)
    toggle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        T.SavePosition()
    end)

    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("RightButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        T.SavePosition()
    end)

    -- Banner: instance name on the left, its LFG icon on the right.
    local banner = CreateFrame("Frame", nil, frame)
    banner:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    banner:SetWidth(T.WIDTH - T.PADDING * 2)
    banner:SetHeight(24)
    frame.banner = banner

    local title = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", banner, "LEFT", 0, 0)
    title:SetWidth(T.WIDTH - T.PADDING * 2 - 28)
    title:SetJustifyH("LEFT")
    banner.title = title

    local icon = banner:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("RIGHT", banner, "RIGHT", 0, 0)
    icon:SetWidth(22)
    icon:SetHeight(22)
    banner.icon = icon

    T.frame  = frame
    T.banner = banner

    T.RestorePosition()
    return frame
end

-- ---------------------------------------------------------------------------
-- Position
-- ---------------------------------------------------------------------------
-- Default: hugging the quest tracker's top-right, so the two read as one
-- column exactly like retail. Right-drag overrides it; the override is kept in
-- SavedVariables and wins from then on, which is also the escape hatch when
-- DC-QOS's FrameMover has relocated WatchFrame.
function T.SavePosition()
    if not T.frame then
        return
    end

    local point, _, relPoint, x, y = T.frame:GetPoint()
    DCBossTrackerDB = DCBossTrackerDB or {}
    DCBossTrackerDB.pos = { point = point, relPoint = relPoint or point, x = x, y = y }
end

function T.RestorePosition()
    if not T.frame then
        return
    end

    T.frame:ClearAllPoints()

    local saved = type(DCBossTrackerDB) == "table" and DCBossTrackerDB.pos or nil
    if saved and saved.point then
        T.frame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x or 0, saved.y or 0)
        return
    end

    local watch = rawget(_G, "WatchFrame")
    if watch then
        T.frame:SetPoint("BOTTOMRIGHT", watch, "TOPRIGHT", 0, 4)
    else
        T.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -240)
    end
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------
function T.Layout()
    local frame = T.EnsureFrame()
    local state = T.state

    if not state.mapId or #state.bosses == 0 then
        frame:Hide()
        return
    end

    frame.banner.title:SetText(state.name or "")

    local iconPath = T.GetInstanceIcon(state.mapId)
    if iconPath then
        frame.banner.icon:SetTexture(iconPath)
        frame.banner.icon:Show()
    else
        frame.banner.icon:Hide()
    end

    local shown = 0
    if not state.collapsed then
        for index = 1, math.min(#state.bosses, T.MAX_LINES) do
            local boss = state.bosses[index]
            local line = T.lines[index] or T.CreateLine(index)

            line.icon:SetTexture(boss.killed and T.ICON_CHECK or T.ICON_DASH)
            line.icon:Show()

            -- Matches retail's phrasing: each encounter is a 0/1 objective.
            line.text:SetFormattedText("%d/1 %s defeated", boss.killed and 1 or 0, boss.name or "")

            local color = boss.killed and T.COLOR_DONE or T.COLOR_PENDING
            line.text:SetTextColor(color[1], color[2], color[3])
            line.text:Show()

            shown = index
        end
    end

    for index = shown + 1, #T.lines do
        T.lines[index].icon:Hide()
        T.lines[index].text:Hide()
    end

    local killed = 0
    for _, boss in ipairs(state.bosses) do
        if boss.killed then
            killed = killed + 1
        end
    end
    frame.header:SetText(state.collapsed
        and string.format("Dungeon (%d/%d)", killed, #state.bosses)
        or "Dungeon")

    -- header + banner + lines + padding, all measured off the same constants
    -- the lines are anchored with, so collapsing does not leave dead space.
    local height = T.PADDING * 2 + 14 + 6 + 24
    if shown > 0 then
        height = height + 6 + shown * T.LINE_HEIGHT
    end
    frame:SetHeight(height)
    frame:Show()
end

function T.ToggleCollapsed()
    T.state.collapsed = not T.state.collapsed
    DCBossTrackerDB = DCBossTrackerDB or {}
    DCBossTrackerDB.collapsed = T.state.collapsed
    T.Layout()
end

function T.Clear()
    local state = T.state
    state.mapId = nil
    state.difficulty = nil
    state.name = nil
    state.bosses = {}
    state.byId = {}
    T.Layout()
end

-- ---------------------------------------------------------------------------
-- Protocol
-- ---------------------------------------------------------------------------
function T.OnList(data)
    T.state.replySeen = true

    if type(data) ~= "table" or type(data.b) ~= "table" then
        T.Clear()
        return
    end

    local state = T.state
    state.mapId      = tonumber(data.m)
    state.difficulty = tonumber(data.d)
    state.name       = tostring(data.n or "")
    state.bosses     = {}
    state.byId       = {}

    -- The server already sorted by DungeonEncounter.orderIndex; keep its order.
    for _, entry in ipairs(data.b) do
        if type(entry) == "table" and tonumber(entry.e) then
            local boss = {
                id     = tonumber(entry.e),
                name   = tostring(entry.t or ""),
                killed = (entry.k == true or entry.k == 1),
            }
            table.insert(state.bosses, boss)
            state.byId[boss.id] = #state.bosses
        end
    end

    T.Layout()
end

function T.OnEncounter(data)
    T.state.replySeen = true

    if type(data) ~= "table" then
        return
    end

    local encounterId = tonumber(data.e)
    local index = encounterId and T.state.byId[encounterId] or nil
    if not index then
        -- A delta for an instance we have no list for (entered before the addon
        -- loaded, or a stale push mid-teleport): ask for the whole list instead
        -- of rendering a partial one.
        T.Request(true)
        return
    end

    T.state.bosses[index].killed = (data.k ~= false)
    T.Layout()
end

function T.OnClear()
    T.state.replySeen = true
    T.Clear()
end

-- Cooldown-gated, not latch-gated: against a server with the DENC module
-- disabled every reply-dependent path would otherwise retry forever.
function T.Request(force)
    local DC = rawget(_G, "DCAddonProtocol")
    if not DC or type(DC.Send) ~= "function" then
        return
    end

    if not T.state.replySeen and T.state.requestsMade >= 3 then
        return
    end

    local now = GetTime() or 0
    if not force and (now - T.state.lastRequest) < 2.0 then
        return
    end
    if force and (now - T.state.lastRequest) < 1.0 then
        return
    end

    T.state.lastRequest = now
    T.state.requestsMade = T.state.requestsMade + 1
    pcall(DC.Send, DC, T.MODULE, T.CMSG_REQUEST)
end

function T.RegisterHandlers()
    if T.registered then
        return
    end

    local DC = rawget(_G, "DCAddonProtocol")
    if not DC or type(DC.RegisterHandler) ~= "function" then
        return
    end

    DC:RegisterHandler(T.MODULE, T.SMSG_LIST, T.OnList)
    DC:RegisterHandler(T.MODULE, T.SMSG_ENCOUNTER, T.OnEncounter)
    DC:RegisterHandler(T.MODULE, T.SMSG_CLEAR, T.OnClear)
    T.registered = true
end

-- ---------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------
function T.LoadSettings()
    DCBossTrackerDB = DCBossTrackerDB or {}
    T.state.collapsed = DCBossTrackerDB.collapsed == true
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event)
    -- Handler registration is retried on every event: DC-AddonProtocol may not
    -- have finished loading when the journal's own ADDON_LOADED fires, and
    -- RegisterHandlers latches once it succeeds.
    T.RegisterHandlers()

    if event == "ADDON_LOADED" then
        return
    end

    -- PLAYER_ENTERING_WORLD: SavedVariables are guaranteed loaded by now, and
    -- the server pushes on its own map-change hook - but a /reload inside an
    -- instance misses that push, so re-sync here.
    --
    -- Deliberately NOT clearing first: the server's push can land before this
    -- event, and wiping it would leave the block hidden until the request
    -- cooldown expired. An instance with nothing to track answers SMSG_CLEAR.
    T.LoadSettings()
    T.EnsureFrame()
    T.Request(false)
end)

SLASH_DCBOSSES1 = "/dcbosses"
SlashCmdList["DCBOSSES"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "reset" then
        DCBossTrackerDB = DCBossTrackerDB or {}
        DCBossTrackerDB.pos = nil
        T.RestorePosition()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Boss tracker position reset.")
        return
    end

    if msg == "refresh" then
        T.state.requestsMade = 0
        T.Request(true)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Boss tracker refresh requested.")
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Boss tracker: right-drag to move, click the header to collapse.")
    DEFAULT_CHAT_FRAME:AddMessage("  /dcbosses reset   - restore the default position")
    DEFAULT_CHAT_FRAME:AddMessage("  /dcbosses refresh - ask the server for the list again")
end

DCBossTracker = T
