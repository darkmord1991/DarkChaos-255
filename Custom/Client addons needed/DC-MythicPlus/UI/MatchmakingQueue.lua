-- DC-MythicPlus/UI/MatchmakingQueue.lua
-- LFG-style auto-matchmaking queue: status panel + ready-check popup + handlers.
-- Pairs with the server-side DCAddon::Matchmaking queue (GRPF queue opcodes).

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

namespace.GroupFinder = namespace.GroupFinder or {}
local GF = namespace.GroupFinder

-- Server enum mirrors
local QUEUE_CAT_DUNGEON = 1
local QUEUE_CAT_RAID    = 2
-- Dungeon "Mythic" maps to DUNGEON_DIFFICULTY_EPIC on the server.
local DUNGEON_DIFFICULTY_MYTHIC = 2

local function GetDC()
    return rawget(_G, "DCAddonProtocol")
end

local function fmtClock(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 0 then seconds = 0 end
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Entry requirement for a catalog dungeon at one difficulty. The server sends
-- reqLevel/reqItemLevel as a 3-slot array (Normal, Heroic, Mythic) sourced from
-- dungeon_access_template; `level` is the legacy Normal-only field, kept as a
-- fallback for a catalog sent by an older core build.
local function DungeonReqValue(dungeon, list, difficulty, legacy)
    if type(dungeon) ~= "table" then return 0 end
    local values = dungeon[list]
    if type(values) == "table" then
        local v = tonumber(values[(tonumber(difficulty) or 0) + 1])
        if v then return v end
    end
    return (legacy and tonumber(dungeon[legacy])) or 0
end

local function DungeonReqLevel(dungeon, difficulty)
    return DungeonReqValue(dungeon, "reqLevel", difficulty, "level")
end

local function DungeonReqItemLevel(dungeon, difficulty)
    return DungeonReqValue(dungeon, "reqItemLevel", difficulty)
end

-- Top of the dungeon's level bracket (0 = no upper bound).
local function DungeonMaxLevel(dungeon, difficulty)
    return DungeonReqValue(dungeon, "maxLevel", difficulty)
end

-- Server-evaluated lock reason for THIS character at one difficulty ("" or nil
-- when open). Covers everything the instance door checks -- level, item level,
-- attunement quests/items/achievements, deserter -- so it supersedes the
-- level-only fallback below whenever the catalog carries it.
local function DungeonLockReason(dungeon, difficulty)
    if type(dungeon) ~= "table" or type(dungeon.lock) ~= "table" then
        return nil
    end
    local reason = dungeon.lock[(tonumber(difficulty) or 0) + 1]
    if type(reason) == "string" and reason ~= "" then
        return reason
    end
    return nil
end

-- Retail greys out content you cannot enter yet and says why, so tag the row
-- instead of dropping it from the list.
local function AddLockState(entry, playerLevel, serverReason)
    if serverReason then
        entry.locked = true
        entry.lockReason = serverReason
        return entry
    end
    local reqLevel = tonumber(entry.reqLevel) or 0
    if reqLevel > 0 and playerLevel < reqLevel then
        entry.locked = true
        entry.lockReason = "Requires level " .. reqLevel
    end
    return entry
end

-- =====================================================================
-- Outgoing actions
-- =====================================================================

-- Build queue parameters from the current finder selection and join.
function GF:QueueForCurrent()
    local DC = GetDC()
    if not (DC and DC.GroupFinder and DC.GroupFinder.JoinQueue) then
        self:SetStatusMessage("Matchmaking is unavailable (server protocol not connected).")
        return false
    end

    local kind = self.compactSelectedKind or "mythic"
    local roles = (self.GetCompactRoleMask and self:GetCompactRoleMask()) or 4
    if roles == 0 then roles = 4 end

    -- Adopt the picked row (raid picker) into the queue selection. Dungeons use
    -- the blizzlike tick list instead of a single selection.
    local entry = self.compactSelectedEntry
    if entry and entry.locked then
        self:SetStatusMessage((entry.lockReason or "You cannot queue for that yet")
            .. " - " .. (entry.dungeonName or entry.name or "this content") .. ".")
        return false
    end
    if entry and entry.isQueueTarget and entry.queueCategory == QUEUE_CAT_RAID then
        self.queueRaidSelection = {
            mapId = entry.queueMapId,
            size = entry.queueSize,
            difficulty = entry.queueDifficulty,
        }
    end

    if kind == "raid" then
        local sel = self.queueRaidSelection
        if not sel or not sel.mapId then
            self:SetStatusMessage("Pick a raid from the list, then click Find Group.")
            return false
        end
        self._queueCategory = QUEUE_CAT_RAID
        DC.GroupFinder.JoinQueue(QUEUE_CAT_RAID, roles, sel.mapId,
            sel.difficulty or 0, sel.size or 10)
    else
        -- Dungeons: the ticked set, or empty for the random queue. "Specific
        -- Dungeons" queues at the Difficulty button's Normal/Heroic; the
        -- "Mythic+" type is always Mythic.
        local dungeonIds = (self.GetDungeonTickList and self:GetDungeonTickList()) or {}
        local difficulty = DUNGEON_DIFFICULTY_MYTHIC
        if kind == "dungeons" then
            difficulty = tonumber(self.queueDungeonDifficulty) or 0
        end

        -- The difficulty button can change under ticks made earlier, so re-check
        -- every picked dungeon against the catalog rather than trusting the lock
        -- state the rows carried when they were clicked.
        if #dungeonIds > 0 and self.queueCatalog then
            local playerLevel = UnitLevel("player") or 1
            local byMap = {}
            for _, d in ipairs(self.queueCatalog.dungeons or {}) do
                byMap[tonumber(d.mapId) or 0] = d
            end
            for _, mapId in ipairs(dungeonIds) do
                local d = byMap[mapId]
                if d then
                    local serverReason = DungeonLockReason(d, difficulty)
                    if serverReason then
                        self:SetStatusMessage(string.format("%s: %s.",
                            d.name or "That dungeon", serverReason))
                        return false
                    end
                    local reqLevel = DungeonReqLevel(d, difficulty)
                    if reqLevel > 0 and playerLevel < reqLevel then
                        self:SetStatusMessage(string.format(
                            "%s requires level %d at %s difficulty.",
                            d.name or "That dungeon", reqLevel,
                            (self.DUNGEON_DIFFICULTY_LABELS
                                and self.DUNGEON_DIFFICULTY_LABELS[difficulty])
                                or tostring(difficulty)))
                        return false
                    end
                end
            end
        end
        self._queueCategory = QUEUE_CAT_DUNGEON
        DC.GroupFinder.JoinQueue(QUEUE_CAT_DUNGEON, roles, dungeonIds,
            difficulty, 0)
    end

    -- Do NOT show the queue panel yet. The server can still refuse the join
    -- (cooldown, deserter, level, group too large), and showing it here left a
    -- "Finding Group... 0:37" timer ticking over a queue that was never joined.
    -- SMSG_QUEUE_JOINED is the confirmation; SMSG_ERROR clears the attempt.
    self._queuePending = true
    self:SetStatusMessage("Joining the queue...")
    return true
end

-- =====================================================================
-- Queue target picker (rows shown in the finder list)
-- =====================================================================

local EXP_TAG = { [0] = "|cffffd100[Classic]|r ", [1] = "|cff1eff00[TBC]|r ", [2] = "|cff0070dd[WotLK]|r " }

local function CompositionForSize(size)
    if size >= 40 then return 3, 8, 29 end
    if size >= 25 then return 2, 6, 17 end
    return 2, 3, 5  -- 10-man
end

local function RaidDiffLabel(diff, size)
    local heroic = (diff == 2 or diff == 3)
    return string.format("%d %s", size, heroic and "Heroic" or "Normal")
end

-- Request the full dynamic catalog (mythic dungeons + raids) from the server.
function GF:RequestQueueCatalog()
    if self.queueCatalog then return end
    local DC = GetDC()
    if DC and DC.GroupFinder and DC.GroupFinder.GetQueueCatalog then
        DC.GroupFinder.GetQueueCatalog()
    end
end

-- Server pushed the catalog (dungeons + raids, sourced from MapDifficulty).
function GF:OnQueueCatalog(data)
    local DC = GetDC()
    local function decode(v)
        if type(v) == "table" then return v end
        if type(v) == "string" and DC and DC.DecodeJSON then
            return DC:DecodeJSON(v) or {}
        end
        return {}
    end

    self.queueCatalog = {
        dungeons = decode(data and data.dungeons),
        raids = decode(data and data.raids),
    }

    -- Refresh the picker if a finder list is currently shown.
    if self.compactMode and self.retailNavContext ~= "premade"
        and (self.compactSelectedKind == "dungeons"
            or self.compactSelectedKind == "mythic"
            or self.compactSelectedKind == "raid") then
        self:SelectCompactType(self.compactSelectedKind)
    end

    -- Fill the Mythic+ panel if it opened before any dungeon data arrived.
    if self.TrySeedPendingMythicPortal then
        self:TrySeedPendingMythicPortal()
    end
end

-- Build the selectable list of queue targets for the current finder category.
-- Prefers the dynamic server catalog (all dungeons/raids, grouped by expansion);
-- falls back to the older local lists and requests the catalog if not cached.
function GF:GetQueueTargets(kind)
    local targets = {}
    local cat = self.queueCatalog

    if kind == "raid" then
        local raids = cat and cat.raids
        if type(raids) == "table" and #raids > 0 then
            for _, r in ipairs(raids) do
                local exp = tonumber(r.expansion) or 2
                for _, opt in ipairs(r.options or {}) do
                    local d = tonumber(opt.d) or 0
                    local s = tonumber(opt.s) or 10
                    local t, h, dd = CompositionForSize(s)
                    table.insert(targets, {
                        isQueueTarget = true, queueCategory = QUEUE_CAT_RAID,
                        queueMapId = r.mapId, queueSize = s, queueDifficulty = d,
                        _exp = exp, _name = r.name or ("Map " .. tostring(r.mapId)),
                        name = (EXP_TAG[exp] or "") .. (r.name or "Raid"),
                        dungeonName = r.name, mapId = r.mapId,
                        difficultyName = RaidDiffLabel(d, s),
                        needTank = t, needHealer = h, needDps = dd,
                    })
                end
            end
            table.sort(targets, function(a, b)
                if a._exp ~= b._exp then return a._exp < b._exp end
                if a._name ~= b._name then return a._name < b._name end
                return (a.queueSize or 0) < (b.queueSize or 0)
            end)
        else
            self:RequestQueueCatalog()
            -- Fallback: the older RaidTab catalog (WotLK-centric).
            local catalog = (self.GetRaidCatalog and self:GetRaidCatalog()) or {}
            for _, raid in ipairs(catalog) do
                local s = (raid.era == 0 and 40) or 25
                local t, h, dd = CompositionForSize(s)
                table.insert(targets, {
                    isQueueTarget = true, queueCategory = QUEUE_CAT_RAID,
                    queueMapId = raid.mapId, queueSize = s,
                    queueDifficulty = tonumber(raid.minDiff) or 0,
                    name = raid.name, dungeonName = raid.name, mapId = raid.mapId,
                    difficultyName = RaidDiffLabel(tonumber(raid.minDiff) or 0, s),
                    needTank = t, needHealer = h, needDps = dd,
                })
            end
        end
    else
        -- Dungeons: an "Any" option plus every dungeon from the catalog.
        -- "Specific Dungeons" shows the Difficulty button's Normal/Heroic;
        -- the "Mythic+" type is locked to Mythic.
        local queueDiff = DUNGEON_DIFFICULTY_MYTHIC
        if kind == "dungeons" then
            queueDiff = tonumber(self.queueDungeonDifficulty) or 0
        end
        local diffName = (self.DUNGEON_DIFFICULTY_LABELS
            and self.DUNGEON_DIFFICULTY_LABELS[queueDiff]) or "Mythic"

        local playerLevel = UnitLevel("player") or 1

        -- Blizzlike LFD shows the bracket, not just the entry level.
        local function DiffLabelFor(reqLevel, maxLevel)
            if reqLevel and reqLevel > 0 then
                if maxLevel and maxLevel > reqLevel then
                    return string.format("%s  -  Lv %d-%d", diffName, reqLevel, maxLevel)
                end
                return diffName .. "  -  Lv " .. reqLevel
            end
            return diffName
        end

        local dungeons = cat and cat.dungeons
        local anyReqLevel = 0
        local anyOpen = true
        local anyLockReason = nil
        if type(dungeons) == "table" and #dungeons > 0 then
            -- "Any Dungeon" is open as soon as ONE catalog dungeon is open to
            -- this character; otherwise surface the first reason we saw.
            anyReqLevel = 255
            anyOpen = false
            for _, d in ipairs(dungeons) do
                local r = DungeonReqLevel(d, queueDiff)
                if r < anyReqLevel then anyReqLevel = r end
                local reason = DungeonLockReason(d, queueDiff)
                if not reason and playerLevel >= r then
                    anyOpen = true
                elseif reason and not anyLockReason then
                    anyLockReason = reason
                end
            end
            if anyReqLevel == 255 then anyReqLevel = 0 end
        end

        table.insert(targets, AddLockState({
            isQueueTarget = true, queueCategory = QUEUE_CAT_DUNGEON,
            queueMapId = 0, queueDifficulty = queueDiff,
            name = "Any Dungeon", dungeonName = "Any Dungeon", mapId = 0,
            reqLevel = anyReqLevel,
            difficultyName = DiffLabelFor(anyReqLevel),
            needTank = 1, needHealer = 1, needDps = 3,
        }, playerLevel, (not anyOpen) and (anyLockReason or "No dungeon available yet") or nil))

        if type(dungeons) == "table" and #dungeons > 0 then
            local sorted = {}
            for _, d in ipairs(dungeons) do table.insert(sorted, d) end
            -- Sort by expansion (addon) -> difficulty tier (required level) ->
            -- name, so the long list reads Classic -> TBC -> WotLK, low -> high.
            table.sort(sorted, function(a, b)
                local ea, eb = tonumber(a.expansion) or 2, tonumber(b.expansion) or 2
                if ea ~= eb then return ea < eb end
                local la = DungeonReqLevel(a, queueDiff)
                local lb = DungeonReqLevel(b, queueDiff)
                if la ~= lb then return la < lb end
                return (a.name or "") < (b.name or "")
            end)
            for _, d in ipairs(sorted) do
                local exp = tonumber(d.expansion) or 2
                local reqLevel = DungeonReqLevel(d, queueDiff)
                table.insert(targets, AddLockState({
                    isQueueTarget = true, queueCategory = QUEUE_CAT_DUNGEON,
                    queueMapId = d.mapId, queueDifficulty = queueDiff,
                    _exp = exp, _level = reqLevel,
                    name = (EXP_TAG[exp] or "") .. (d.name or ("Map " .. tostring(d.mapId))),
                    dungeonName = d.name, mapId = d.mapId,
                    reqLevel = reqLevel,
                    reqItemLevel = DungeonReqItemLevel(d, queueDiff),
                    maxLevel = DungeonMaxLevel(d, queueDiff),
                    difficultyName = DiffLabelFor(reqLevel, DungeonMaxLevel(d, queueDiff)),
                    needTank = 1, needHealer = 1, needDps = 3,
                }, playerLevel, DungeonLockReason(d, queueDiff)))
            end
        else
            self:RequestQueueCatalog()
            -- Fallback: the curated M+ dungeon list until the catalog arrives.
            -- It carries no requirement data, so nothing is locked here; the
            -- real list replaces it as soon as OnQueueCatalog lands.
            local list = namespace.GetMythicPlusDungeonList and namespace.GetMythicPlusDungeonList() or {}
            for _, d in ipairs(list) do
                table.insert(targets, {
                    isQueueTarget = true, queueCategory = QUEUE_CAT_DUNGEON,
                    queueMapId = d.mapId, queueDifficulty = queueDiff,
                    name = d.name or ("Map " .. tostring(d.mapId)),
                    dungeonName = d.name, mapId = d.mapId,
                    difficultyName = DiffLabelFor(nil),
                    needTank = 1, needHealer = 1, needDps = 3,
                })
            end
        end
    end

    return targets
end

function GF:LeaveMatchmakingQueue()
    local DC = GetDC()
    if DC and DC.GroupFinder and DC.GroupFinder.LeaveQueue then
        DC.GroupFinder.LeaveQueue()
    end
    self:HideQueueStatus()
end

-- =====================================================================
-- Queue status panel (overlays the results area while queued)
-- =====================================================================

-- The animated searching eye: the stock 3.3.5 LFG-Eye flipbook
-- (512x256, 64x64 cells, 29 frames — the same animation the minimap LFG
-- icon plays while you are queued).
local EYE_TEXTURE = "Interface\\LFGFrame\\LFG-Eye"
local EYE_FRAMES, EYE_COLS = 29, 8
local EYE_FRAME_TIME = 0.05

local function SetEyeAnimationFrame(tex, frameIndex)
    local col = frameIndex % EYE_COLS
    local row = math.floor(frameIndex / EYE_COLS)
    tex:SetTexCoord(col * 64 / 512, (col + 1) * 64 / 512,
        row * 64 / 256, (row + 1) * 64 / 256)
end

local function CreateStyledButton(parent, width, height, label)
    if namespace.CreateRetailButton then
        return namespace.CreateRetailButton(parent, width, height, label)
    end
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, height)
    if label then btn:SetText(label) end
    return btn
end

function GF:CreateQueueStatusFrame()
    if self.queueStatusFrame then return self.queueStatusFrame end
    if not self.compactListFrame then return nil end

    local frame = CreateFrame("Frame", nil, self.compactListFrame)
    frame:SetAllPoints(self.compactListFrame)
    frame:SetFrameLevel(self.compactListFrame:GetFrameLevel() + 5)
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.03, 0.05, 0.11, 0.92)
    if bg.SetColorTexture then bg:SetColorTexture(0.03, 0.05, 0.11, 0.92) end

    -- Animated searching eye (golden atlas glow behind the spinning eye).
    local eyeGlow = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    eyeGlow:SetSize(72, 72)
    eyeGlow:SetPoint("TOP", 0, -14)
    if not (namespace.SetGFAtlas and namespace.SetGFAtlas(eyeGlow, "eye-highlight")) then
        eyeGlow:Hide()
    end

    local eye = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    eye:SetSize(48, 48)
    eye:SetPoint("CENTER", eyeGlow, "CENTER", 0, 0)
    eye:SetTexture(EYE_TEXTURE)
    SetEyeAnimationFrame(eye, 0)
    frame.eye = eye

    local etaLine = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    etaLine:SetPoint("BOTTOM", 0, 52)
    etaLine:SetText("")
    frame.etaLine = etaLine

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", eyeGlow, "BOTTOM", 0, -6)
    title:SetText("Finding Group...")
    title:SetTextColor(1, 0.82, 0)
    frame.title = title

    local roleLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    roleLine:SetPoint("TOP", title, "BOTTOM", 0, -14)
    roleLine:SetText("")
    frame.roleLine = roleLine

    local waitLine = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    waitLine:SetPoint("TOP", roleLine, "BOTTOM", 0, -8)
    waitLine:SetText("Time in queue: 0:00")
    frame.waitLine = waitLine

    local leaveBtn = CreateStyledButton(frame, 120, 24, "Leave Queue")
    leaveBtn:SetPoint("BOTTOM", 0, 18)
    leaveBtn:SetScript("OnClick", function() GF:LeaveMatchmakingQueue() end)
    frame.leaveBtn = leaveBtn

    self.queueStatusFrame = frame
    return frame
end

function GF:ShowQueueStatus()
    local frame = self:CreateQueueStatusFrame()
    if not frame then return end
    self.queueActive = true
    -- Keep an existing join time: OnQueueStatus seeds it from the server's
    -- waitSeconds, and overwriting it here restarted the timer at 0:00.
    self.queueJoinedAt = self.queueJoinedAt or GetTime()
    frame.title:SetText("Finding Group...")
    frame.roleLine:SetText("")
    frame:Show()

    -- Live tick: eye flipbook animation + wait timer.
    frame:SetScript("OnUpdate", function(self_, elapsed)
        if self_.eye then
            self_._eyeAcc = (self_._eyeAcc or 0) + elapsed
            while self_._eyeAcc >= EYE_FRAME_TIME do
                self_._eyeAcc = self_._eyeAcc - EYE_FRAME_TIME
                self_._eyeFrame = ((self_._eyeFrame or 0) + 1) % EYE_FRAMES
            end
            SetEyeAnimationFrame(self_.eye, self_._eyeFrame or 0)
        end

        self_._acc = (self_._acc or 0) + elapsed
        if self_._acc < 0.5 then return end
        self_._acc = 0
        if GF.queueJoinedAt then
            self_.waitLine:SetText("Time in queue: " .. fmtClock(GetTime() - GF.queueJoinedAt))
        end
    end)
end

function GF:HideQueueStatus()
    self.queueActive = false
    self._queuePending = nil
    self.queueJoinedAt = nil
    if self.queueStatusFrame then
        self.queueStatusFrame:SetScript("OnUpdate", nil)
        self.queueStatusFrame:Hide()
    end
end

-- =====================================================================
-- Ready-check popup (match found)
-- =====================================================================

-- Retail role-check dialog: assigned-role icon up top, one ready-mark per
-- group member (pending hourglass flips to a green check as members accept),
-- countdown bar, styled Enter/Decline buttons.
local PROPOSAL_ROLE_ATLAS = {
    tank = "role-tank", healer = "role-healer", heal = "role-healer",
    dps = "role-dps", damage = "role-dps",
}

function GF:CreateQueueProposalFrame()
    if self.queueProposalFrame then return self.queueProposalFrame end

    local frame = CreateFrame("Frame", "DCMatchmakingProposalFrame", UIParent)
    frame:SetSize(340, 240)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:Hide()
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("Group Found!")
    title:SetTextColor(1, 0.82, 0)
    frame.title = title

    -- Assigned-role icon (retail LFG prompt art).
    local roleIcon = frame:CreateTexture(nil, "ARTWORK")
    roleIcon:SetSize(48, 48)
    roleIcon:SetPoint("TOP", title, "BOTTOM", 0, -6)
    roleIcon:Hide()
    frame.roleIcon = roleIcon

    local info = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOP", roleIcon, "BOTTOM", 0, -6)
    info:SetWidth(300)
    info:SetJustifyH("CENTER")
    info:SetText("")
    frame.info = info

    -- Per-member accept indicators (created on demand in OnQueueProposal).
    local marksAnchor = CreateFrame("Frame", nil, frame)
    marksAnchor:SetSize(300, 18)
    marksAnchor:SetPoint("TOP", info, "BOTTOM", 0, -6)
    frame.marksAnchor = marksAnchor
    frame.marks = {}

    local accepted = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    accepted:SetPoint("TOP", marksAnchor, "BOTTOM", 0, -4)
    accepted:SetText("")
    frame.accepted = accepted

    -- Countdown bar
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetSize(280, 14)
    bar:SetPoint("TOP", accepted, "BOTTOM", 0, -8)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.7, 0.2)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    if barBg.SetColorTexture then barBg:SetColorTexture(0, 0, 0, 0.5) end
    frame.bar = bar

    local acceptBtn = CreateStyledButton(frame, 110, 26, "Enter Dungeon")
    acceptBtn:SetPoint("BOTTOMLEFT", 38, 18)
    acceptBtn:SetScript("OnClick", function()
        GF:RespondToQueueProposal(true)
    end)
    frame.acceptBtn = acceptBtn

    local declineBtn = CreateStyledButton(frame, 110, 26, "Decline")
    declineBtn:SetPoint("BOTTOMRIGHT", -38, 18)
    declineBtn:SetScript("OnClick", function()
        GF:RespondToQueueProposal(false)
    end)
    frame.declineBtn = declineBtn

    self.queueProposalFrame = frame
    return frame
end

-- Lay out one pending/ready mark per member (rows of 10 for raid sizes).
function GF:SetProposalMarks(total, acceptedCount)
    local frame = self.queueProposalFrame
    if not frame or not frame.marksAnchor then return end

    total = math.max(tonumber(total) or 0, 0)
    acceptedCount = math.max(tonumber(acceptedCount) or 0, 0)

    for i, mark in ipairs(frame.marks) do
        mark:Hide()
    end

    local perRow = 10
    local size, pad = 16, 4
    for i = 1, math.min(total, 40) do
        local mark = frame.marks[i]
        if not mark then
            mark = frame.marksAnchor:CreateTexture(nil, "ARTWORK")
            mark:SetSize(size, size)
            frame.marks[i] = mark
        end
        local row = math.floor((i - 1) / perRow)
        local col = (i - 1) % perRow
        local rowCount = math.min(total - row * perRow, perRow)
        local rowWidth = rowCount * (size + pad) - pad
        mark:ClearAllPoints()
        mark:SetPoint("TOPLEFT", frame.marksAnchor, "TOP",
            -rowWidth / 2 + col * (size + pad), -row * (size + pad))

        local key = (i <= acceptedCount) and "readymark" or "pendingmark"
        if namespace.SetGFAtlas and namespace.SetGFAtlas(mark, key) then
            mark:Show()
        else
            mark:Hide()
        end
    end

    -- Grow the anchor for multi-row raid marks so the text below moves down.
    local rows = math.max(1, math.ceil(math.min(total, 40) / perRow))
    frame.marksAnchor:SetHeight(rows * (size + pad) - pad)
end

function GF:RespondToQueueProposal(accept)
    local DC = GetDC()
    if DC and DC.GroupFinder and DC.GroupFinder.RespondToProposal and self.currentProposalId then
        DC.GroupFinder.RespondToProposal(self.currentProposalId, accept)
    end
    local frame = self.queueProposalFrame
    if frame then
        if accept then
            frame.acceptBtn:Disable()
            frame.declineBtn:Disable()
            frame.info:SetText("Waiting for the rest of the group...")
        else
            frame:SetScript("OnUpdate", nil)
            frame:Hide()
        end
    end
end

-- =====================================================================
-- Incoming handlers (called from Core.lua GRPF handlers)
-- =====================================================================

function GF:OnQueueJoined(data)
    self._queuePending = nil
    self._queueCategory = tonumber(data.category) or self._queueCategory
    self:ShowQueueStatus()
    self:SetStatusMessage("You are in the queue. Searching for a group...")
end

-- A Group Finder error while a join was in flight means the join was refused,
-- so drop the pending state instead of leaving a phantom queue on screen. An
-- error that arrives at any other time (a listing problem, say) must not tear
-- down a queue that really is active.
function GF:OnQueueError(err)
    if not self._queuePending then
        return
    end
    self._queuePending = nil
    self:HideQueueStatus()
    if err and err ~= "" then
        self:SetStatusMessage(err)
    end
end

function GF:OnQueueLeft(data)
    self:HideQueueStatus()
    if data and data.matched then
        self:SetStatusMessage("Group formed! Teleporting...")
        if self.queueProposalFrame then
            self.queueProposalFrame:SetScript("OnUpdate", nil)
            self.queueProposalFrame:Hide()
        end
    else
        self:SetStatusMessage("You left the queue.")
    end
end

function GF:OnQueueStatus(data)
    if not data.queued then
        self:HideQueueStatus()
        return
    end

    local frame = self:CreateQueueStatusFrame()
    if not frame then return end
    -- Always resync the wait timer to the server's authoritative value —
    -- this also restores the correct elapsed time after a /reload.
    if data.waitSeconds ~= nil then
        self.queueJoinedAt = GetTime() - (tonumber(data.waitSeconds) or 0)
    end
    if not self.queueActive then
        self:ShowQueueStatus()
    end

    -- While a ready-check is out we are no longer counted among the waiting,
    -- so the role tally is legitimately zero -- show the real state instead of
    -- "Tanks: 0  Healers: 0  DPS: 0", which reads like the queue emptied out.
    if data.proposalPending then
        frame.roleLine:SetText("|cffffd200Group found|r  -  waiting for everyone to accept")
    else
        frame.roleLine:SetText(string.format(
            "In queue  -  Tanks: %d   Healers: %d   DPS: %d",
            tonumber(data.tanks) or 0, tonumber(data.healers) or 0, tonumber(data.dps) or 0))
    end

    -- Per-role average wait (server rolling average, -1 = no data yet): the
    -- same estimate line the stock Dungeon Finder shows under the eye.
    if frame.etaLine then
        local function eta(v)
            v = tonumber(v)
            if not v or v < 0 then return "--" end
            return fmtClock(v)
        end
        local avg = tonumber(data.waitAvg)
        if data.proposalPending then
            frame.etaLine:SetText("")
        elseif avg and avg >= 0 then
            frame.etaLine:SetText(string.format(
                "Average wait: %s   (Tank %s  Healer %s  DPS %s)",
                eta(avg), eta(data.waitTank), eta(data.waitHealer), eta(data.waitDps)))
        else
            frame.etaLine:SetText("Average wait: calculating...")
        end
    end
end

function GF:OnQueueProposal(data)
    self.currentProposalId = tonumber(data.proposalId)
    local frame = self:CreateQueueProposalFrame()

    -- Assigned-role icon (retail prompt art), keyed by the server role name.
    local roleKey = PROPOSAL_ROLE_ATLAS[string.lower(tostring(data.role or ""))]
    if roleKey and namespace.SetGFAtlas
        and namespace.SetGFAtlas(frame.roleIcon, roleKey) then
        frame.roleIcon:Show()
    else
        frame.roleIcon:Hide()
    end

    local roleText = data.role and (" as |cffffd200" .. tostring(data.role) .. "|r") or ""
    frame.info:SetText("Your group is ready" .. roleText .. ".\nAccept to join!")
    local totalSize = tonumber(data.size) or 5
    -- Backfilled bots arrive already accepted, so the tally starts above zero.
    local acceptedCount = tonumber(data.accepted) or 0
    frame._proposalSize = totalSize
    self:SetProposalMarks(totalSize, acceptedCount)
    frame.accepted:SetText(string.format("%d / %d accepted", acceptedCount, totalSize))
    frame.acceptBtn:Enable()
    frame.declineBtn:Enable()

    local timeout = tonumber(data.timeout) or 40
    self._proposalDeadline = GetTime() + timeout
    frame.bar:SetMinMaxValues(0, timeout)
    frame.bar:SetValue(timeout)
    frame:Show()

    if PlaySound then
        -- Ready-check sound
        pcall(PlaySound, "ReadyCheck")
    end

    frame:SetScript("OnUpdate", function(self_)
        local remain = (GF._proposalDeadline or 0) - GetTime()
        if remain <= 0 then
            self_.bar:SetValue(0)
            self_:SetScript("OnUpdate", nil)
            self_:Hide()
            return
        end
        self_.bar:SetValue(remain)
    end)
end

function GF:OnQueueProposalUpdate(data)
    local frame = self.queueProposalFrame
    if frame and frame:IsShown() then
        local acceptedCount = tonumber(data.accepted) or 0
        local total = tonumber(data.total) or frame._proposalSize or 5
        self:SetProposalMarks(total, acceptedCount)
        frame.accepted:SetText(string.format("%d / %d accepted",
            acceptedCount, total))
    end
end

function GF:OnQueueProposalFailed(data)
    if self.queueProposalFrame then
        self.queueProposalFrame:SetScript("OnUpdate", nil)
        self.queueProposalFrame:Hide()
    end
    self.currentProposalId = nil

    local reason = (data and data.reason) or "The match was cancelled."
    if data and data.requeued then
        self:SetStatusMessage(reason .. " You are still in the queue.")
        self:ShowQueueStatus()
    else
        self:SetStatusMessage(reason)
        self:HideQueueStatus()
    end
end

-- Allow other tabs (raid finder) to set the queue target.
function GF:SetQueueRaidSelection(mapId, size, difficulty)
    self.queueRaidSelection = { mapId = mapId, size = size, difficulty = difficulty }
end

function GF:SetQueueDungeonSelection(mapId)
    self.queueDungeonSelection = mapId or 0
end

-- =====================================================================
-- Vote kick (blizzlike LFD boot)
-- =====================================================================
-- The server owns the rules (120s, 3 votes, kicker auto-yes / victim auto-no,
-- limited kicks per group); this is just the dialog. It mirrors the stock
-- "Vote to kick <name>?" popup rather than reusing it, because the stock frame
-- is driven by LFG_BOOT_PROPOSAL_UPDATE which this custom queue never sends.

function GF:CreateBootFrame()
    if self.bootFrame then return self.bootFrame end

    local frame = CreateFrame("Frame", "DCGroupFinderBootFrame", UIParent)
    frame:SetSize(340, 150)
    frame:SetPoint("TOP", 0, -180)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Vote to Kick")
    title:SetTextColor(1, 0.82, 0)
    frame.title = title

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOP", title, "BOTTOM", 0, -8)
    body:SetWidth(300)
    body:SetJustifyH("CENTER")
    frame.body = body

    local tally = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tally:SetPoint("TOP", body, "BOTTOM", 0, -6)
    frame.tally = tally

    local yes = CreateStyledButton(frame, 110, 24, "Yes")
    yes:SetPoint("BOTTOMLEFT", 32, 18)
    yes:SetScript("OnClick", function() GF:SendBootVote(true) end)
    frame.yes = yes

    local no = CreateStyledButton(frame, 110, 24, "No")
    no:SetPoint("BOTTOMRIGHT", -32, 18)
    no:SetScript("OnClick", function() GF:SendBootVote(false) end)
    frame.no = no

    self.bootFrame = frame
    return frame
end

function GF:SendBootVote(agree)
    local DC = GetDC()
    if DC and DC.GroupFinder and DC.GroupFinder.VoteKick then
        DC.GroupFinder.VoteKick(agree)
    end
    local frame = self.bootFrame
    if frame then
        frame.yes:Disable()
        frame.no:Disable()
    end
end

-- Ask the server to open a vote on a group member (party right-click, or the
-- /dckick slash command). The server refuses when the group is not one it
-- formed, so this is safe to offer unconditionally.
function GF:RequestVoteKick(name, reason)
    local DC = GetDC()
    if not (DC and DC.GroupFinder and DC.GroupFinder.StartVoteKick) then return end
    if not name or name == "" then return end
    DC.GroupFinder.StartVoteKick(name, reason or "")
end

function GF:OnBootUpdate(data)
    if not data then return end

    -- Vote finished: report and close.
    if data.active == false or data.active == nil then
        local frame = self.bootFrame
        if frame then
            frame:SetScript("OnUpdate", nil)
            frame:Hide()
        end
        local who = tostring(data.victim or "The player")
        if data.passed then
            self:PrintImportant(who .. " was removed from the group by vote.")
        else
            self:PrintImportant("Vote to kick " .. who .. " failed"
                .. (data.reason and (" (" .. tostring(data.reason) .. ")") or "") .. ".")
        end
        return
    end

    local frame = self:CreateBootFrame()
    local victim = tostring(data.victim or "?")
    frame.body:SetText(string.format("Kick |cffffd200%s|r from the group?\n|cff999999%s|r",
        victim, tostring(data.reason or "No reason given")))

    local agree = tonumber(data.agree) or 0
    local needed = tonumber(data.needed) or 3
    frame.tally:SetText(string.format("Votes: %d / %d", agree, needed))

    -- The victim watches, everyone else votes; a cast vote locks the buttons.
    local myVote = tonumber(data.myVote) or 0
    local canVote = not data.isVictim and myVote == 0
    if canVote then frame.yes:Enable() else frame.yes:Disable() end
    if canVote then frame.no:Enable() else frame.no:Disable() end

    self._bootDeadline = GetTime() + (tonumber(data.timeLeft) or 120)
    frame:Show()
    frame:SetScript("OnUpdate", function(self_)
        if (GF._bootDeadline or 0) - GetTime() <= 0 then
            self_:SetScript("OnUpdate", nil)
            self_:Hide()
            return
        end
        self_.title:SetText(string.format("Vote to Kick  (%s)",
            fmtClock((GF._bootDeadline or 0) - GetTime())))
    end)
end

-- No client hook is needed for the party right-click: the server intercepts a
-- leader's kick on a matchmade group (Group::RemoveMember) and opens a vote
-- instead of removing, so the stock "Remove from Party" menu entry already
-- behaves the blizzlike way. This slash command is just a convenience for
-- opening a vote without the menu.
SLASH_DCVOTEKICK1 = "/dckick"
SlashCmdList["DCVOTEKICK"] = function(msg)
    local name, reason = string.match(msg or "", "^(%S+)%s*(.*)$")
    if not name or name == "" then
        print("|cff00ccffDC|r Usage: /dckick <player> [reason]")
        return
    end
    GF:RequestVoteKick(name, reason)
end

-- =====================================================================
-- Queue state restore after /reload
-- =====================================================================
-- The server keeps the player queued through a UI reload, but the client
-- state is lost. Ask for the authoritative status once the world (and the
-- protocol handshake) is up; the reply is SMSG_QUEUE_STATUS either way
-- ({queued:false} when not in queue), so this is safe to send always.

do
    local restoreFrame = CreateFrame("Frame")
    restoreFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    restoreFrame:SetScript("OnEvent", function(self_)
        self_._delay = 3  -- give DC-AddonProtocol time to finish its handshake
        self_:SetScript("OnUpdate", function(f, elapsed)
            f._delay = f._delay - elapsed
            if f._delay > 0 then return end
            f:SetScript("OnUpdate", nil)
            local DC = GetDC()
            if DC and DC.GroupFinder and DC.GroupFinder.GetQueueStatus then
                DC.GroupFinder.GetQueueStatus()
            end
        end)
    end)
end
