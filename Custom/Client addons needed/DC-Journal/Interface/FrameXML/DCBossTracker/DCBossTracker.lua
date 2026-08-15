--[[--------------------------------------------------------------------------
    DC Boss Tracker - retail-style dungeon/raid encounter checklist
    ---------------------------------------------------------------------------

    Draws the "Dungeon / <instance> / 0/1 <boss> defeated" block that retail
    shows at the top of the objective tracker, driven entirely by the server's
    DENC module (src/server/scripts/DC/AddonExtension/dc_addon_encounters.cpp).

    Visuals are a faithful downport of retail's ObjectiveTracker module header
    and the scenario Stage Block, using the REAL retail textures (extracted
    from 12.0.7 and shipped in the DC client patch) with texcoords taken from
    the 11.2.7 AtlasInfo.lua, and layout offsets from
    Blizzard_ObjectiveTrackerModule.xml / Blizzard_ScenarioObjectiveTracker.xml.

    Position matches retail semantics: the block claims the top of the tracker
    column (where UIParent's manager puts WatchFrame: TOPRIGHT of MinimapCluster
    at (-CONTAINER_OFFSET_X, anchorY)) and WatchFrame's quests flow below it.
    Implemented by hooking WatchFrame:SetPoint - the stock manager re-anchors
    WatchFrame on every UIParent_ManageFramePositions, so the hook re-applies
    the split each time. If WatchFrame:IsUserPlaced() (stock drag or DC-QOS
    FrameMover, which calls SetUserPlaced(true)), the manager never fires and
    the block quietly falls back to sitting above WatchFrame's custom spot.

    Protocol (module "DENC"), keyed by DungeonEncounter.dbc entry id:
        CMSG_REQUEST   0x01  ask for the current instance's list
        SMSG_LIST      0x10  {m, d, r, n, b:[{e, t, k}]}  full list + state
        SMSG_ENCOUNTER 0x11  {m, d, e, k}                 one boss changed
        SMSG_CLEAR     0x12  {}                           hide the block

    The server pushes on instance entry and on every boss kill; the only
    client-initiated request is a re-sync after a UI reload. That request is
    cooldown-gated rather than latch-gated: a reply-dependent request behind a
    disabled server module would otherwise re-fire forever (QNAV lesson).
--------------------------------------------------------------------------]]--

local T = {}

T.MODULE          = "DENC"
T.CMSG_REQUEST    = 0x01
T.SMSG_LIST       = 0x10
T.SMSG_ENCOUNTER  = 0x11
T.SMSG_CLEAR      = 0x12

-- ---------------------------------------------------------------------------
-- Retail art (paths + atlas texcoords)
-- ---------------------------------------------------------------------------
-- Texcoords are the 1x atlas entries from 11.2.7 Helix/AtlasInfo.lua for the
-- files shipped in the DC client patch. Format: {w, h, l, r, t, b}.
T.TEX_TRACKER   = "Interface\\QuestFrame\\QuestTracker"       -- 512x256
T.TEX_SCENARIO  = "Interface\\Scenarios\\ScenarioParts"       -- 512x512
T.TEX_OBJICONS  = "Interface\\Minimap\\ObjectIconsAtlas"      -- 1024x1024
T.TEX_CHALLENGE = "Interface\\Challenges\\ChallengeModeHud"   -- 1024x512
T.TEX_AFFIXRING = "Interface\\Challenges\\ChallengeMode"      -- 1024x1024

T.ATLAS = {
    -- UI-QuestTracker-Secondary-Objective-Header (the "Dungeon" module bar)
    header        = { 300, 30, 0.00195312, 0.587891, 0.644531, 0.761719 },
    -- ui-questtrackerbutton-secondary-collapse / -pressed / -expand / highlight
    btnCollapse   = { 16, 16, 0.894531, 0.925781, 0.40625, 0.46875 },
    btnPressed    = { 16, 16, 0.933594, 0.964844, 0.40625, 0.46875 },
    btnExpand     = { 16, 16, 0.630859, 0.662109, 0.480469, 0.542969 },
    btnHighlight  = { 16, 16, 0.666016, 0.697266, 0.480469, 0.542969 },
    -- ScenarioTrackerToast (the stage-block plate behind the instance name). The
    -- plate has an ornate icon panel baked into its right end (crossed swords),
    -- at x 174..235, y 9..56 of the 243x78 art - that is the instance-icon slot.
    toast         = { 243, 77, 0.00195312, 0.476562, 0.345703, 0.496094 },

    -- Challenge Mode block (Blizzard_ScenarioObjectiveTracker.xml), all from
    -- Interface/Challenges/ChallengeModeHud unless noted
    cmBorder      = { 261, 87, 0.606445, 0.861328, 0.220703, 0.390625 },   -- challengemode-timer
    cmTimerBGBack = { 223, 11, 0.633789, 0.851562, 0.183594, 0.205078 },   -- ChallengeMode-TimerBG-Back
    cmTimerBG     = { 223, 11, 0.633789, 0.851562, 0.158203, 0.179688 },   -- ChallengeMode-TimerBG
    cmTimerFill   = { 223, 11, 0.606445, 0.824219, 0.394531, 0.416016 },   -- ChallengeMode-TimerFill
    cmAffixRing   = { 34, 34, 0.964844, 0.998047, 0.000976562, 0.0341797 },-- ChallengeMode-AffixRing-Sm (TEX_AFFIXRING)
    cmSkull       = { 12, 16, 0.591797, 0.603516, 0.104492, 0.120117 },    -- poi-graveyard-neutral (TEX_OBJICONS)
}

-- DC affix name -> 3.3.5 icon. Retail resolves these via C_ChallengeMode
-- FileDataIDs which do not exist here; the ring border is the retail atlas.
T.AFFIX_ICONS = {
    ["tyrannical"] = "Interface\\Icons\\Achievement_Boss_Archaedas",
    ["fortified"]  = "Interface\\Icons\\Ability_Toughness",
    ["bolstering"] = "Interface\\Icons\\Ability_Warrior_BattleShout",
    ["necrotic"]   = "Interface\\Icons\\Spell_Shadow_DeathAndDecay",
    ["grievous"]   = "Interface\\Icons\\Ability_BackStab",
}
T.AFFIX_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

T.ICON_CHECK = "Interface\\Scenarios\\ScenarioIcon-Check"
T.ICON_DASH  = "Interface\\Scenarios\\ScenarioIcon-Dash"

-- Per-instance thumbnail for the stage plate: the same Interface\LFGFrame\
-- lfgicon-<key> art the Mythic+ statistics list and the dungeon teleporter use.
T.LFG_ICON_PATH = "Interface\\LFGFrame\\lfgicon-"

-- Retail layout constants (Blizzard_ObjectiveTracker XML)
T.WIDTH         = 260   -- ObjectiveTrackerModuleHeaderTemplate width (fallback; live width follows WatchFrame)
T.COLUMN_OFFSET_X = -20 -- extra shift applied to the manager's column point: keeps the
                        -- header art's +20 right overhang out of the action-bar area
T.HEADER_HEIGHT = 26
T.STAGE_WIDTH   = 201   -- StageBlock size
T.STAGE_HEIGHT  = 83
T.CM_WIDTH      = 251   -- Mythic+ timer block (ChallengeMode art); wider than the
                        -- StageBlock, so the two need a half-difference nudge to
                        -- share a left edge - see EnsureFrame's stage anchor.
T.LINE_HEIGHT   = 18
T.LINE_INDENT   = 10
T.MAX_LINES     = 16

-- Retail objective colours: outstanding objectives gold, cleared ones dim.
T.COLOR_DONE    = { 0.60, 0.60, 0.60 }
T.COLOR_PENDING = { 1.00, 0.78, 0.20 }
T.COLOR_STAGE   = { 1.00, 0.914, 0.682 }  -- StageBlock.Stage
T.COLOR_NAME    = { 1.00, 0.831, 0.380 }  -- StageBlock.Name

T.DIFF_DUNGEON = { [0] = "", [1] = "Heroic", [2] = "Mythic" }
T.DIFF_RAID    = { [0] = "10 Player", [1] = "25 Player",
                   [2] = "10 Player (Heroic)", [3] = "25 Player (Heroic)" }

T.state = {
    mapId        = nil,
    difficulty   = nil,
    isRaid       = false,
    name         = nil,
    bosses       = {},   -- ordered array of { id, name, killed }
    byId         = {},   -- dbc entry -> index into bosses
    collapsed    = false,
    lastRequest  = 0,
    replySeen    = false,
    requestsMade = 0,
}

T.lines = {}

-- mapId -> resolved icon path, or false when nothing resolved. Probing a texture
-- means actually loading it, and Layout re-runs on every boss kill, so the
-- verdict is cached per instance rather than re-tested each frame.
T.iconCache = {}

-- ---------------------------------------------------------------------------
-- Instance thumbnail
-- ---------------------------------------------------------------------------
-- DC-MythicPlus owns the canonical mapId -> lfgicon key table (it needs it for
-- the group finder, the statistics list and the teleporter), so reuse its
-- resolver whenever that addon is loaded and the two UIs stay in sync. The
-- name-derived fallback covers a client running DC-Journal on its own: the DENC
-- payload carries the instance name, and "Gundrak" -> lfgicon-gundrak is the
-- same normalisation DC-MythicPlus applies.
function T.IconCandidates(mapId, name, isRaid)
    local mplus = rawget(_G, "DCMythicPlusHUD")
    if type(mplus) == "table" and type(mplus.ResolveLFGIconCandidates) == "function" then
        local ok, list = pcall(mplus.ResolveLFGIconCandidates,
            { mapId = mapId, name = name }, isRaid, true)
        if ok and type(list) == "table" and #list > 0 then
            return list
        end
    end

    local candidates = {}
    if type(name) == "string" and name ~= "" then
        local key = string.gsub(string.lower(name), "^the%s+", "")
        key = string.gsub(key, "[^a-z0-9]", "")
        if key ~= "" then
            table.insert(candidates, T.LFG_ICON_PATH .. key)
        end
    end
    table.insert(candidates, T.LFG_ICON_PATH .. (isRaid and "raid" or "dungeon"))
    return candidates
end

-- Drop the thumbnail into the plate's baked icon panel. Nothing resolved (a
-- custom instance with no shipped art) hides the texture, which leaves the
-- plate's own crossed-swords panel showing - the generic instance icon.
function T.ApplyInstanceIcon()
    local icon = T.stage and T.stage.icon
    if not icon then
        return
    end

    local mapId = T.state.mapId
    local resolved = mapId and T.iconCache[mapId]

    if resolved == nil then
        resolved = false
        for _, path in ipairs(T.IconCandidates(mapId, T.state.name, T.state.isRaid)) do
            icon:SetTexture(path)
            if icon:GetTexture() then
                resolved = path
                break
            end
        end
        if mapId then
            T.iconCache[mapId] = resolved
        end
    end

    if resolved then
        icon:SetTexture(resolved)
        icon:Show()
    else
        icon:Hide()
    end
end

local function SetAtlas(texture, texPath, atlas)
    texture:SetTexture(texPath)
    texture:SetWidth(atlas[1])
    texture:SetHeight(atlas[2])
    texture:SetTexCoord(atlas[3], atlas[4], atlas[5], atlas[6])
end

-- ---------------------------------------------------------------------------
-- Column width: follow WatchFrame so the two modules share BOTH edges
-- ---------------------------------------------------------------------------
-- WatchFrame is 204 or 306 wide (the "wider quest tracker" option) while the
-- retail module header is 260; with a fixed-width block the quest lines jut
-- out past the boss block on one side. Since both frames share the column's
-- TOPRIGHT, matching WatchFrame's width lines their left edges up too. The
-- header ART stays 300 wide and right-anchored (never stretched) - on any
-- width the filigree just fades out toward the left, like retail.
function T.SyncColumnWidth()
    local width = T.WIDTH
    if WatchFrame and WatchFrame.GetWidth then
        local watchWidth = WatchFrame:GetWidth() or 0
        -- Ignore the collapsed width so a collapsed quest tracker does not
        -- squeeze the boss block.
        if watchWidth > 190 then
            width = math.floor(watchWidth + 0.5)
        end
    end

    if width == T.columnWidth then
        return
    end
    T.columnWidth = width

    if not T.frame then
        return
    end
    T.frame:SetWidth(width)
    T.frame.header:SetWidth(width)
    for index = 1, #T.lines do
        T.lines[index].text:SetWidth(width - 34)
    end
end

-- ---------------------------------------------------------------------------
-- Frame construction
-- ---------------------------------------------------------------------------
function T.CreateLine(index)
    local icon = T.frame:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(16)
    icon:SetHeight(16)

    local text = T.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetJustifyH("LEFT")
    text:SetWidth((T.columnWidth or T.WIDTH) - 34)

    if index == 1 then
        -- The stack above line 1 differs by mode (stage plate alone vs stage
        -- plate + challenge block); each Layout sets T.firstLineY first.
        icon:SetPoint("TOPLEFT", T.frame, "TOPLEFT", T.LINE_INDENT,
            T.firstLineY or -(T.HEADER_HEIGHT + T.STAGE_HEIGHT + 2))
    else
        icon:SetPoint("TOPLEFT", T.lines[index - 1].icon, "BOTTOMLEFT", 0, -2)
    end
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)

    T.lines[index] = { icon = icon, text = text }
    return T.lines[index]
end

function T.EnsureFrame()
    if T.frame then
        return T.frame
    end

    local frame = CreateFrame("Frame", "DCBossTrackerFrame", UIParent)
    frame:SetWidth(T.WIDTH)
    frame:SetHeight(T.HEADER_HEIGHT + T.STAGE_HEIGHT)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- ============ Module header (ObjectiveTrackerModuleHeaderTemplate) ======
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetWidth(T.WIDTH)
    header:SetHeight(T.HEADER_HEIGHT)

    -- Background atlas is 300x30, CENTER-anchored on retail's fixed 260 header
    -- (= 20px overhang each side). Our header width follows WatchFrame, so both
    -- edges are pinned at +/-20 instead of only the right one. That keeps the
    -- retail geometry at 260 and reproduces it at any other width: the bar's
    -- visible gold line fades in ~20/300 into the art, so with the art starting
    -- at -20 the line always begins right about the frame's own left edge, which
    -- is where the header text (LEFT+7) and the boss lines (LEFT+10) sit. Pinned
    -- to the right edge alone the art started 26px INSIDE a 306-wide frame and
    -- the "Dungeon (0/5)" label hung out to the left of its own line.
    local headerBG = header:CreateTexture(nil, "BACKGROUND")
    SetAtlas(headerBG, T.TEX_TRACKER, T.ATLAS.header)
    headerBG:SetPoint("LEFT", header, "LEFT", -20, 0)
    headerBG:SetPoint("RIGHT", header, "RIGHT", 20, 0)

    -- ObjectiveTrackerHeaderFont: Friz 15, gold, LEFT x=7
    local headerText = header:CreateFontString(nil, "ARTWORK")
    headerText:SetFont("Fonts\\FRIZQT__.TTF", 15)
    headerText:SetShadowOffset(1, -1)
    headerText:SetShadowColor(0, 0, 0)
    headerText:SetTextColor(1.0, 0.82, 0.0)
    headerText:SetJustifyH("LEFT")
    headerText:SetPoint("LEFT", header, "LEFT", 7, 0)
    headerText:SetText("Dungeon")

    -- MinimizeButton: 16x16 at RIGHT x=1, retail button atlases.
    local toggle = CreateFrame("Button", nil, header)
    toggle:SetWidth(16)
    toggle:SetHeight(16)
    toggle:SetPoint("RIGHT", header, "RIGHT", 1, 0)

    local btnNormal = toggle:CreateTexture(nil, "ARTWORK")
    SetAtlas(btnNormal, T.TEX_TRACKER, T.ATLAS.btnCollapse)
    btnNormal:SetAllPoints(toggle)
    toggle:SetNormalTexture(btnNormal)

    local btnPushed = toggle:CreateTexture(nil, "ARTWORK")
    SetAtlas(btnPushed, T.TEX_TRACKER, T.ATLAS.btnPressed)
    btnPushed:SetAllPoints(toggle)
    toggle:SetPushedTexture(btnPushed)

    local btnHi = toggle:CreateTexture(nil, "HIGHLIGHT")
    SetAtlas(btnHi, T.TEX_TRACKER, T.ATLAS.btnHighlight)
    btnHi:SetAllPoints(toggle)
    btnHi:SetBlendMode("ADD")
    toggle:SetHighlightTexture(btnHi)

    toggle:RegisterForClicks("LeftButtonUp")
    toggle:SetScript("OnClick", function() T.ToggleCollapsed() end)

    -- The whole header doubles as the drag handle (right-drag).
    header:EnableMouse(true)
    frame:SetMovable(true)
    header:RegisterForDrag("RightButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        T.SavePosition()
    end)

    frame.header     = header
    frame.headerText = headerText
    frame.toggle     = toggle
    frame.btnNormal  = btnNormal

    -- ============ Stage block (ScenarioObjectiveTracker StageBlock) =========
    -- Centred like the Mythic+ timer block, then nudged by half the width
    -- difference so the two share a LEFT edge (which is what the eye reads, and
    -- what the boss lines below are aligned to).
    --
    -- The frame's live width follows WatchFrame rather than T.WIDTH, so both
    -- blocks must be centre-anchored or they drift apart as the tracker resizes.
    -- Centring alone is not enough: the blocks are 201 vs 251 wide, which leaves
    -- their left edges 25px apart. Deriving the offset from the two constants
    -- keeps them aligned no matter what the frame width does.
    local stage = CreateFrame("Frame", nil, frame)
    stage:SetPoint("TOP", header, "BOTTOM", (T.STAGE_WIDTH - T.CM_WIDTH) / 2, 0)
    stage:SetWidth(T.STAGE_WIDTH)
    stage:SetHeight(T.STAGE_HEIGHT)

    -- ScenarioTrackerToast plate: 243x77 at TOPLEFT (0,0); art wider than the
    -- 201-wide block on purpose (right side fades out).
    local toast = stage:CreateTexture(nil, "BACKGROUND")
    SetAtlas(toast, T.TEX_SCENARIO, T.ATLAS.toast)
    toast:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, 0)

    -- Stage title (retail Game18Font, TOPLEFT 15,-10): the instance name.
    local title = stage:CreateFontString(nil, "ARTWORK")
    title:SetFont("Fonts\\FRIZQT__.TTF", 15)
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0)
    title:SetTextColor(T.COLOR_STAGE[1], T.COLOR_STAGE[2], T.COLOR_STAGE[3])
    title:SetJustifyH("LEFT")
    title:SetWidth(150)
    title:SetHeight(36)
    title:SetPoint("TOPLEFT", stage, "TOPLEFT", 15, -12)
    stage.title = title

    -- Subtitle (retail StageBlock.Name position/colour): difficulty label.
    local sub = stage:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    sub:SetTextColor(T.COLOR_NAME[1], T.COLOR_NAME[2], T.COLOR_NAME[3])
    sub:SetJustifyH("LEFT")
    sub:SetWidth(150)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    stage.sub = sub

    -- Instance thumbnail, dropped into the ornate panel baked into the plate's
    -- right end. Centred on that panel's measured bounds (x 174..235, y 9..56 of
    -- the 243x78 art), inset far enough that the panel still frames it. Filled
    -- in by ApplyInstanceIcon once the instance is known.
    local icon = stage:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(38)
    icon:SetHeight(38)
    -- Tight crop: the lfgicon art runs edge to edge, so trimming the outermost
    -- pixels keeps the panel's inner bevel clean.
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    icon:SetPoint("CENTER", toast, "TOPLEFT", 204, -32)
    icon:Hide()
    stage.icon = icon

    -- Live M+ countdown between server pushes; runs only while the frame is
    -- shown, and OnUpdateTick bails instantly outside Mythic+ mode.
    frame:SetScript("OnUpdate", function(_, elapsed)
        T.OnUpdateTick(elapsed)
    end)

    T.frame = frame
    T.stage = stage
    T.RestorePosition()
    return frame
end

-- ---------------------------------------------------------------------------
-- Position: retail semantics - top of the tracker column, quests below
-- ---------------------------------------------------------------------------
-- UIParent_ManageFramePositions anchors WatchFrame's TOPRIGHT to MinimapCluster
-- (offset by durability/vehicle/arena frames) unless it IsUserPlaced(). The
-- hook below runs after every such SetPoint: the tracker takes the manager's
-- point and WatchFrame's TOP anchor is replaced to hang below the tracker (its
-- BOTTOMRIGHT stretch anchor stays untouched, so quest text still fills down).
T.anchoring = false

function T.HasUserPosition()
    return type(DCBossTrackerDB) == "table"
        and type(DCBossTrackerDB.pos) == "table"
        and DCBossTrackerDB.pos.point ~= nil
end

function T.ClaimColumnTop(point, relTo, relPoint, x, y)
    if not T.frame then
        return
    end

    T.SyncColumnWidth()

    T.anchoring = true
    T.frame:ClearAllPoints()
    -- COLUMN_OFFSET_X shifts the whole column (WatchFrame hangs below us, so
    -- the quest block moves with it) left of the manager's stock point.
    T.frame:SetPoint(point, relTo, relPoint, (x or 0) + T.COLUMN_OFFSET_X, y)
    -- Re-SetPoint with the same point name REPLACES only that anchor:
    -- WatchFrame keeps its BOTTOMRIGHT stretch anchor.
    WatchFrame:SetPoint("TOPRIGHT", T.frame, "BOTTOMRIGHT", 0, -6)
    -- The manager's BOTTOMRIGHT stretch anchor still points at the UNSHIFTED
    -- column x; two right-edge constraints at different x are undefined
    -- behaviour, so move it by the same offset (globals from UIParent.lua).
    WatchFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
        -(CONTAINER_OFFSET_X or 70) + T.COLUMN_OFFSET_X, CONTAINER_OFFSET_Y or 30)
    T.anchoring = false
end

function T.HookWatchFrame()
    if T.watchHooked or not WatchFrame then
        return
    end

    hooksecurefunc(WatchFrame, "SetPoint", function(self, point, relTo, relPoint, x, y)
        if T.anchoring then
            return
        end
        if not (T.frame and T.frame:IsShown()) then
            return
        end
        if T.HasUserPosition() then
            return
        end
        -- Only intercept the manager's column anchor, not the stretch anchor
        -- or an arena-frames layout.
        if point ~= "TOPRIGHT" then
            return
        end
        if relTo ~= MinimapCluster and relTo ~= "MinimapCluster" then
            return
        end

        T.ClaimColumnTop(point, relTo, relPoint or point, x or 0, y or 0)
    end)

    T.watchHooked = true
end

function T.SavePosition()
    if not T.frame then
        return
    end

    local point, _, relPoint, x, y = T.frame:GetPoint()
    DCBossTrackerDB = DCBossTrackerDB or {}
    DCBossTrackerDB.pos = { point = point, relPoint = relPoint or point, x = x, y = y }
    T.ReleaseWatchFrame()
end

-- Give WatchFrame back to the stock manager (it re-anchors on the next
-- UIParent_ManageFramePositions; call it directly so the fix is immediate).
function T.ReleaseWatchFrame()
    if T.anchoring then
        return
    end
    if type(UIParent_ManageFramePositions) == "function" then
        pcall(UIParent_ManageFramePositions)
    end
end

function T.RestorePosition()
    if not T.frame then
        return
    end

    if T.HasUserPosition() then
        local saved = DCBossTrackerDB.pos
        T.frame:ClearAllPoints()
        T.frame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x or 0, saved.y or 0)
        return
    end

    -- Default: the manager's column spot. Nudge the manager to fire once so
    -- the hook can claim it; until then sit above WatchFrame as a placeholder.
    if WatchFrame then
        T.frame:ClearAllPoints()
        T.frame:SetPoint("BOTTOMRIGHT", WatchFrame, "TOPRIGHT", 0, 6)
        T.ReleaseWatchFrame()
    else
        T.frame:ClearAllPoints()
        T.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -240)
    end
end

-- ---------------------------------------------------------------------------
-- Mythic+ mode: the retail Challenge Mode block, fed by DC-MythicPlus
-- ---------------------------------------------------------------------------
-- During a keystone run the server-side DENC module stands down and the DC
-- MythicPlus addon pushes its HUD state here instead (DCBossTracker.SetMythicPlus
-- from Core.lua). The block is retail's ChallengeModeBlock (251x87,
-- Blizzard_ScenarioObjectiveTracker.xml): ornate border, "Level %d", live
-- countdown, draining timer bar, affix rings, death skull - stacked with the
-- same stage plate and boss checklist the dungeon tracker uses.
T.mplus = { active = false }

function T.FormatClock(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function T.EnsureMythicBlock()
    if T.cm then
        return T.cm
    end

    local cm = CreateFrame("Frame", nil, T.frame)
    cm:SetWidth(T.CM_WIDTH)
    cm:SetHeight(87)

    -- TimerBG pair sits UNDER the border art (BACKGROUND sublevels in retail).
    local bgBack = cm:CreateTexture(nil, "BACKGROUND")
    SetAtlas(bgBack, T.TEX_CHALLENGE, T.ATLAS.cmTimerBGBack)
    bgBack:SetPoint("BOTTOM", cm, "BOTTOM", 0, 13)

    local bg = cm:CreateTexture(nil, "BORDER")
    SetAtlas(bg, T.TEX_CHALLENGE, T.ATLAS.cmTimerBG)
    bg:SetPoint("BOTTOM", cm, "BOTTOM", 0, 13)

    -- Fill: retail is a 207x13 StatusBar; a manual left-anchored crop (width
    -- AND right texcoord scaled by the same fraction) keeps the art unwarped.
    local fill = cm:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(T.TEX_CHALLENGE)
    fill:SetHeight(11)
    fill:SetPoint("LEFT", cm, "BOTTOM", -103, 16)
    cm.fill = fill

    -- Ornate border art drawn over the bar (OVERLAY in retail). 261 wide on
    -- the 251 block - retail stretches; we center it unstretched instead.
    local border = cm:CreateTexture(nil, "OVERLAY")
    SetAtlas(border, T.TEX_CHALLENGE, T.ATLAS.cmBorder)
    border:SetPoint("CENTER", cm, "CENTER", 0, 0)

    -- "Level %d" (GameFontNormalMed2 = Friz 14 gold), TOPLEFT 28,-18
    local level = cm:CreateFontString(nil, "OVERLAY")
    level:SetFont("Fonts\\FRIZQT__.TTF", 14)
    level:SetShadowOffset(1, -1)
    level:SetShadowColor(0, 0, 0)
    level:SetTextColor(1.0, 0.82, 0.0)
    level:SetPoint("TOPLEFT", cm, "TOPLEFT", 28, -18)
    cm.level = level

    -- Big time left (GameFontHighlightHuge = Friz 20 white), below Level
    local timeLeft = cm:CreateFontString(nil, "OVERLAY")
    timeLeft:SetFont("Fonts\\FRIZQT__.TTF", 20)
    timeLeft:SetShadowOffset(1, -1)
    timeLeft:SetShadowColor(0, 0, 0)
    timeLeft:SetTextColor(1, 1, 1)
    timeLeft:SetPoint("TOPLEFT", level, "BOTTOMLEFT", 0, -8)
    cm.timeLeft = timeLeft

    -- Death counter (skull + count) near the bottom-right, retail offsets.
    local skull = cm:CreateTexture(nil, "OVERLAY")
    SetAtlas(skull, T.TEX_OBJICONS, T.ATLAS.cmSkull)
    skull:SetPoint("TOPLEFT", cm, "BOTTOMRIGHT", -47, 43)
    cm.skull = skull

    local deaths = cm:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    deaths:SetPoint("LEFT", skull, "RIGHT", 1, 0)
    cm.deaths = deaths

    cm.affixes = {}
    T.cm = cm
    return cm
end

-- Affix rings, retail geometry: 22x22 frames, 4px spacing, the ROW is
-- right-aligned so it ends 28px short of the block's right edge, at y=-18
-- (level-line height).
function T.LayoutAffixes(list)
    local cm = T.cm
    local count = type(list) == "table" and #list or 0

    for index = 1, math.max(count, #cm.affixes) do
        local affix = cm.affixes[index]
        if index <= count then
            if not affix then
                affix = CreateFrame("Frame", nil, cm)
                affix:SetWidth(22)
                affix:SetHeight(22)

                local icon = affix:CreateTexture(nil, "ARTWORK")
                icon:SetWidth(20)
                icon:SetHeight(20)
                icon:SetPoint("CENTER", affix, "CENTER", 0, 0)
                -- Tight crop so the square icon reads as a disc inside the
                -- ring (3.3.5 has no circular masking).
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                affix.icon = icon

                local ring = affix:CreateTexture(nil, "OVERLAY")
                SetAtlas(ring, T.TEX_AFFIXRING, T.ATLAS.cmAffixRing)
                ring:SetAllPoints(affix)

                cm.affixes[index] = affix
            end

            if index == 1 then
                local rowWidth = 28 + 4 * (count - 1) + 22 * count
                affix:ClearAllPoints()
                affix:SetPoint("TOPLEFT", cm, "TOPRIGHT", -rowWidth, -18)
            else
                affix:ClearAllPoints()
                affix:SetPoint("LEFT", cm.affixes[index - 1], "RIGHT", 4, 0)
            end

            local name = string.lower(tostring(list[index].name or list[index] or ""))
            affix.icon:SetTexture(T.AFFIX_ICONS[name] or T.AFFIX_ICON_FALLBACK)
            affix:Show()
        elseif affix then
            affix:Hide()
        end
    end
end

-- Live countdown between HUD pushes (the server snapshots arrive ~1.5s apart;
-- retail ticks every frame). Extrapolates from the last push's remaining time.
function T.OnUpdateTick(elapsed)
    local m = T.mplus
    if not m.active or not T.cm then
        return
    end

    m.tickAccum = (m.tickAccum or 0) + elapsed
    if m.tickAccum < 0.1 then
        return
    end
    m.tickAccum = 0

    local timeLeft
    if m.completed or m.failed then
        timeLeft = m.remaining
    elseif m.countdown and m.countdown > 0 then
        -- Pre-start countdown: full bar, yellow count.
        local cd = math.max(0, m.countdown - (GetTime() - m.basisAt))
        T.cm.timeLeft:SetText(T.FormatClock(cd))
        T.cm.timeLeft:SetTextColor(1.0, 0.82, 0.0)
        T.SetTimerFill(1)
        return
    else
        timeLeft = math.max(0, (m.remaining or 0) - (GetTime() - m.basisAt))
    end

    T.cm.timeLeft:SetText(T.FormatClock(timeLeft))
    if m.failed or timeLeft <= 0 then
        T.cm.timeLeft:SetTextColor(1.0, 0.13, 0.13)
    elseif m.completed then
        T.cm.timeLeft:SetTextColor(0.1, 1.0, 0.1)
    else
        T.cm.timeLeft:SetTextColor(1, 1, 1)
    end

    T.SetTimerFill((m.duration and m.duration > 0) and (timeLeft / m.duration) or 0)
end

function T.SetTimerFill(fraction)
    fraction = math.max(0, math.min(1, fraction))
    local fill = T.cm.fill
    if fraction <= 0.001 then
        fill:Hide()
        return
    end

    local atlas = T.ATLAS.cmTimerFill
    fill:SetWidth(207 * fraction)
    fill:SetTexCoord(atlas[3], atlas[3] + (atlas[4] - atlas[3]) * fraction, atlas[5], atlas[6])
    fill:Show()
end

-- Public API for DC-MythicPlus (Core.lua): push the normalized HUD state.
function T.SetMythicPlus(data)
    if type(data) ~= "table" then
        return
    end

    local m = T.mplus
    m.active     = true
    m.name       = tostring(data.mapName or "")
    m.level      = tonumber(data.keystone) or 0
    m.duration   = tonumber(data.duration) or 0
    m.remaining  = tonumber(data.remaining) or 0
    m.deaths     = tonumber(data.deaths) or 0
    m.countdown  = tonumber(data.countdown) or 0
    m.completed  = (data.completed == 1 or data.completed == true)
    m.failed     = (data.failed == 1 or data.failed == true)
    m.affixes    = type(data.affixes) == "table" and data.affixes or {}
    m.bosses     = type(data.bosses) == "table" and data.bosses or {}
    m.enemies    = tonumber(data.enemiesKilled) or 0
    m.basisAt    = GetTime() or 0
    m.tickAccum  = 1 -- force an immediate tick

    T.Layout()
end

function T.ClearMythicPlus()
    if not T.mplus.active then
        return
    end
    T.mplus.active = false
    T.Layout()
end

-- ---------------------------------------------------------------------------
-- WatchFrame skin: make the quest module look like part of the same tracker
-- ---------------------------------------------------------------------------
-- Retail draws every module (Dungeon, Quests, ...) with the same header bar;
-- stock 3.3.5 WatchFrame just has a bare gold FontString, which is why the two
-- blocks read as separate UIs. This dresses WatchFrame's header in the same
-- atlas chrome, aligned so both bars share the column's right edge, the same
-- text indent and the same 16x16 collapse button.
--
-- Alignment math: the DENC header art is pinned 20px outside its frame on BOTH
-- sides (retail's 300-wide art on a 260-wide header). Pinning WatchFrame's bar
-- the same way puts both bars' edges - and therefore the text at LEFT+7 and the
-- button at RIGHT-19 - on identical column x positions, regardless of
-- WatchFrame's own width (204 or 306), and keeps the gold line's fade-in
-- starting at the frame's left edge where the header text begins.
-- WatchFrameLines starts at y=-30, so the 30px bar fits without touching it.
function T.ApplyWatchButtonArt()
    local btn = WatchFrameCollapseExpandButton
    if not btn or not T.watchBar then
        return
    end

    local normalAtlas = WatchFrame.collapsed and T.ATLAS.btnExpand or T.ATLAS.btnCollapse

    -- Stock WatchFrame_Collapse/Expand stomp these with UI-Panel-*Button art
    -- every click; this runs as a post-hook and stomps them right back.
    btn:SetNormalTexture(T.TEX_TRACKER)
    btn:GetNormalTexture():SetTexCoord(normalAtlas[3], normalAtlas[4], normalAtlas[5], normalAtlas[6])
    btn:SetPushedTexture(T.TEX_TRACKER)
    btn:GetPushedTexture():SetTexCoord(T.ATLAS.btnPressed[3], T.ATLAS.btnPressed[4], T.ATLAS.btnPressed[5], T.ATLAS.btnPressed[6])
    btn:SetDisabledTexture(T.TEX_TRACKER)
    btn:GetDisabledTexture():SetTexCoord(normalAtlas[3], normalAtlas[4], normalAtlas[5], normalAtlas[6])
    btn:SetHighlightTexture(T.TEX_TRACKER)
    local hi = btn:GetHighlightTexture()
    hi:SetTexCoord(T.ATLAS.btnHighlight[3], T.ATLAS.btnHighlight[4], T.ATLAS.btnHighlight[5], T.ATLAS.btnHighlight[6])
    hi:SetBlendMode("ADD")
end

function T.SkinWatchFrame()
    if T.watchSkinned then
        return
    end
    if not (WatchFrame and WatchFrameTitle and WatchFrameCollapseExpandButton) then
        return
    end
    if DCBossTrackerDB and DCBossTrackerDB.skinWatchFrame == false then
        return
    end

    local bar = WatchFrame:CreateTexture(nil, "BACKGROUND")
    SetAtlas(bar, T.TEX_TRACKER, T.ATLAS.header)
    bar:SetPoint("TOPLEFT", WatchFrame, "TOPLEFT", -20, 2)
    bar:SetPoint("TOPRIGHT", WatchFrame, "TOPRIGHT", 20, 2)
    T.watchBar = bar

    WatchFrameTitle:SetFont("Fonts\\FRIZQT__.TTF", 15)
    WatchFrameTitle:SetShadowOffset(1, -1)
    WatchFrameTitle:SetShadowColor(0, 0, 0)
    WatchFrameTitle:SetTextColor(1.0, 0.82, 0.0)
    WatchFrameTitle:SetJustifyH("LEFT")
    WatchFrameTitle:ClearAllPoints()
    -- Same indent as the boss block's header text: 7px from the FRAME's left
    -- edge (both frames share their left edge now that widths are synced).
    -- y=-7 vertically centers the ~15px text on the bar (bar spans +2..-28).
    WatchFrameTitle:SetPoint("TOPLEFT", WatchFrame, "TOPLEFT", 7, -7)

    local btn = WatchFrameCollapseExpandButton
    btn:SetWidth(16)
    btn:SetHeight(16)
    btn:ClearAllPoints()
    btn:SetPoint("RIGHT", bar, "RIGHT", -19, 0)

    T.ApplyWatchButtonArt()
    hooksecurefunc("WatchFrame_Collapse", T.ApplyWatchButtonArt)
    hooksecurefunc("WatchFrame_Expand", T.ApplyWatchButtonArt)

    T.watchSkinned = true
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------
function T.DifficultyLabel()
    local d = T.state.difficulty
    if not d then
        return ""
    end

    if T.state.isRaid then
        -- Player cap comes from the server (MapDifficulty.dbc maxPlayers):
        -- custom raids do not follow the stock 10/25 pattern (Timbermaw Hold
        -- is 20-player). The enum table is only the no-data fallback.
        local cap = tonumber(T.state.maxPlayers) or 0
        if cap > 0 then
            local label = string.format("%d Player", cap)
            if d == 2 or d == 3 then
                label = label .. " (Heroic)"
            end
            return label
        end
        return T.DIFF_RAID[d] or ""
    end

    return T.DIFF_DUNGEON[d] or ""
end

-- One checklist line, shared by both modes. Re-anchors line 1 because the
-- dungeon mode hangs lines off the stage plate while M+ hangs them off the
-- challenge block.
function T.SetLine(index, iconTexture, text, r, g, b)
    local line = T.lines[index] or T.CreateLine(index)

    if index == 1 then
        line.icon:ClearAllPoints()
        line.icon:SetPoint("TOPLEFT", T.frame, "TOPLEFT", T.LINE_INDENT, T.firstLineY)
    end

    line.icon:SetTexture(iconTexture)
    line.icon:Show()
    line.text:SetText(text)
    line.text:SetTextColor(r, g, b)
    line.text:Show()
end

function T.LayoutMythicPlus()
    local frame = T.frame
    local m = T.mplus
    local cm = T.EnsureMythicBlock()

    -- Single-block layout. The stage plate carried nothing the challenge block
    -- cannot: it showed the dungeon name plus "Keystone Level N", and the block
    -- below already repeated the level. So the plate is retired here, the name
    -- moves into the block, and the level rides in the header where there is
    -- spare width - the block has no vertical room for a third text row without
    -- pushing the timer into the progress bar.
    -- NOTE: the stage plate is still used by the non-Mythic+ (DENC) layout.
    frame.headerText:SetText(string.format("Mythic+  |cffffd200Level %d|r", m.level or 0))
    SetAtlas(frame.btnNormal, T.TEX_TRACKER,
        T.state.collapsed and T.ATLAS.btnExpand or T.ATLAS.btnCollapse)
    frame.btnNormal:SetAllPoints(frame.toggle)

    local shown = 0
    if not T.state.collapsed then
        T.stage:Hide()

        cm:ClearAllPoints()
        cm:SetPoint("TOP", frame, "TOP", 0, -T.HEADER_HEIGHT)
        cm:Show()
        T.firstLineY = -(T.HEADER_HEIGHT + 87 + 4)

        -- Truncated rather than width-limited: a WotLK FontString wraps to a
        -- second line when it overflows its width, and that line would land on
        -- top of the timer. Clipping in Lua keeps it to one row.
        local dungeonName = tostring(m.name or "")
        if string.len(dungeonName) > 24 then
            dungeonName = string.sub(dungeonName, 1, 23) .. "..."
        end
        cm.level:SetText(dungeonName)
        if m.deaths > 0 then
            cm.skull:Show()
            cm.deaths:SetText(m.deaths)
            cm.deaths:Show()
        else
            cm.skull:Hide()
            cm.deaths:Hide()
        end
        T.LayoutAffixes(m.affixes)

        -- Lines hang off the challenge block. The block is CENTERED while
        -- lines are frame-left aligned, so line 1 anchors to the frame; the
        -- SetLine anchor param is only used for its BOTTOM edge via the fixed
        -- stack height below.
        for index = 1, math.min(#m.bosses, T.MAX_LINES) do
            local boss = m.bosses[index]
            local killed = (boss.killed == 1 or boss.killed == true)
            local text = string.format("%d/1 %s defeated", killed and 1 or 0, tostring(boss.name or ""))
            local at = tonumber(boss.at)
            if killed and at then
                text = string.format("%s |cff808080(%s)|r", text, T.FormatClock(at))
            end
            local color = killed and T.COLOR_DONE or T.COLOR_PENDING
            shown = shown + 1
            T.SetLine(shown, killed and T.ICON_CHECK or T.ICON_DASH, text, color[1], color[2], color[3])
        end

        if m.enemies > 0 and shown < T.MAX_LINES then
            shown = shown + 1
            T.SetLine(shown, T.ICON_DASH,
                string.format("Enemies slain: %d", m.enemies),
                T.COLOR_PENDING[1], T.COLOR_PENDING[2], T.COLOR_PENDING[3])
        end
    else
        T.stage:Hide()
        cm:Hide()
    end

    for index = shown + 1, #T.lines do
        T.lines[index].icon:Hide()
        T.lines[index].text:Hide()
    end

    local height = T.HEADER_HEIGHT
    if not T.state.collapsed then
        -- No STAGE_HEIGHT term any more: the plate is hidden in this layout.
        height = height + 87 + 4
        if shown > 0 then
            height = height + shown * T.LINE_HEIGHT
        end
    end

    local wasShown = frame:IsShown()
    frame:SetHeight(height)
    frame:Show()

    if not T.HasUserPosition() and (not wasShown or height ~= T.lastHeight) then
        T.lastHeight = height
        T.ReleaseWatchFrame()
    end
end

function T.Layout()
    local frame = T.EnsureFrame()
    local state = T.state

    T.SyncColumnWidth()

    if T.mplus.active then
        T.LayoutMythicPlus()
        return
    end

    if T.cm then
        T.cm:Hide()
    end

    if not state.mapId or #state.bosses == 0 then
        if frame:IsShown() then
            frame:Hide()
            T.ReleaseWatchFrame()
        end
        return
    end

    frame.headerText:SetText(state.isRaid and "Raid" or "Dungeon")
    T.stage.title:SetText(state.name or "")
    T.stage.sub:SetText(T.DifficultyLabel())

    -- Collapse button art follows the state (retail swaps collapse<->expand).
    SetAtlas(frame.btnNormal, T.TEX_TRACKER,
        state.collapsed and T.ATLAS.btnExpand or T.ATLAS.btnCollapse)
    frame.btnNormal:SetAllPoints(frame.toggle)

    local shown = 0
    if not state.collapsed then
        T.stage:Show()
        T.ApplyInstanceIcon()
        T.firstLineY = -(T.HEADER_HEIGHT + T.STAGE_HEIGHT + 2)
        for index = 1, math.min(#state.bosses, T.MAX_LINES) do
            local boss = state.bosses[index]
            local line = T.lines[index] or T.CreateLine(index)

            if index == 1 then
                line.icon:ClearAllPoints()
                line.icon:SetPoint("TOPLEFT", T.frame, "TOPLEFT", T.LINE_INDENT, T.firstLineY)
            end

            line.icon:SetTexture(boss.killed and T.ICON_CHECK or T.ICON_DASH)
            line.icon:Show()

            line.text:SetFormattedText("%d/1 %s defeated", boss.killed and 1 or 0, boss.name or "")

            local color = boss.killed and T.COLOR_DONE or T.COLOR_PENDING
            line.text:SetTextColor(color[1], color[2], color[3])
            line.text:Show()

            shown = index
        end
    else
        T.stage:Hide()
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
    frame.headerText:SetText(string.format("%s (%d/%d)",
        state.isRaid and "Raid" or "Dungeon", killed, #state.bosses))

    local height = T.HEADER_HEIGHT
    if not state.collapsed then
        height = height + T.STAGE_HEIGHT
        if shown > 0 then
            height = height + shown * T.LINE_HEIGHT
        end
    end

    local wasShown = frame:IsShown()
    frame:SetHeight(height)
    frame:Show()

    -- Height/visibility changes move WatchFrame's hang point; kick the manager
    -- so the hook re-applies the split with the new geometry.
    if not T.HasUserPosition() and (not wasShown or height ~= T.lastHeight) then
        T.lastHeight = height
        T.ReleaseWatchFrame()
    end
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
    state.isRaid = false
    state.maxPlayers = 0
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
    T.state.zoneReplySeen = true

    if type(data) ~= "table" or type(data.b) ~= "table" then
        T.Clear()
        return
    end

    local state = T.state
    state.mapId      = tonumber(data.m)
    state.difficulty = tonumber(data.d)
    state.isRaid     = (data.r == true or data.r == 1)
    state.maxPlayers = tonumber(data.p) or 0
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
    T.state.zoneReplySeen = true

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
    T.state.zoneReplySeen = true
    T.Clear()
end

-- Cooldown-gated, not latch-gated: against a server with the DENC module
-- disabled every reply-dependent path would otherwise retry forever.
-- requestsMade resets on every PLAYER_ENTERING_WORLD, so the cap is per
-- zone-in, never a session-wide give-up (which once disarmed the tracker for
-- the whole session after three lost messages at login).
function T.Request(force)
    local DC = rawget(_G, "DCAddonProtocol")
    if not DC or type(DC.Send) ~= "function" then
        return
    end

    if T.state.requestsMade >= 8 then
        return
    end

    -- Nudge the protocol handshake if it has not established yet (same
    -- pattern as DC-QOS Graveyard); the request itself still goes out.
    if type(DC.EnsureConnected) == "function" then
        pcall(DC.EnsureConnected, DC)
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
    -- the server pushes on its own map-change hook - but that push is sent
    -- while the client is still on the LOADING SCREEN, where 3.3.5 drops
    -- incoming chat, so it is routinely lost. This request is the reliable
    -- activation path; the OnUpdate pump below retries it until any DENC
    -- reply arrives for this zone-in.
    --
    -- Deliberately NOT clearing first: a push can land before this event, and
    -- wiping it would leave the block hidden until the request cooldown
    -- expired. An instance with nothing to track answers SMSG_CLEAR.
    T.LoadSettings()
    T.EnsureFrame()
    T.HookWatchFrame()
    T.SkinWatchFrame()

    T.state.requestsMade = 0
    T.state.zoneReplySeen = false
    T.state.retriesLeft = 4
    T.state.nextRetryAt = (GetTime() or 0) + 4
    T.Request(true)
end)

-- Retry pump. Lives on the always-shown events frame, NOT the tracker frame:
-- the tracker is hidden exactly when nothing arrived, which would kill an
-- OnUpdate hung off it. Stops the moment any DENC message lands (including
-- SMSG_CLEAR - "nothing to track" is also an answer).
events:SetScript("OnUpdate", function()
    local s = T.state
    if s.zoneReplySeen or (s.retriesLeft or 0) <= 0 then
        return
    end

    local now = GetTime() or 0
    if now < (s.nextRetryAt or 0) then
        return
    end

    s.retriesLeft = s.retriesLeft - 1
    s.nextRetryAt = now + 4

    -- Handler registration may also have missed its window if the protocol
    -- addon loaded late; it latches internally, so retrying here is free.
    T.RegisterHandlers()
    T.Request(true)
end)

SLASH_DCBOSSES1 = "/dcbosses"
SlashCmdList["DCBOSSES"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "reset" then
        DCBossTrackerDB = DCBossTrackerDB or {}
        DCBossTrackerDB.pos = nil
        T.RestorePosition()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Boss tracker position reset to the tracker column.")
        return
    end

    if msg == "refresh" then
        T.state.requestsMade = 0
        T.Request(true)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Boss tracker refresh requested.")
        return
    end

    if msg == "skin" then
        DCBossTrackerDB = DCBossTrackerDB or {}
        DCBossTrackerDB.skinWatchFrame = (DCBossTrackerDB.skinWatchFrame == false)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Quest tracker skin "
            .. (DCBossTrackerDB.skinWatchFrame and "enabled" or "disabled")
            .. " - takes effect after /reload.")
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC]|r Boss tracker: right-drag the header to move, click the button to collapse.")
    DEFAULT_CHAT_FRAME:AddMessage("  /dcbosses reset   - snap back to the objective-tracker column")
    DEFAULT_CHAT_FRAME:AddMessage("  /dcbosses refresh - ask the server for the list again")
    DEFAULT_CHAT_FRAME:AddMessage("  /dcbosses skin    - toggle the matching quest-tracker header skin")
end

DCBossTracker = T
