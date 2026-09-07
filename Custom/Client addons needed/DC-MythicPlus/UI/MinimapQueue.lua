-- DC-MythicPlus/UI/MinimapQueue.lua
-- The blizzlike queue eye on the minimap.
--
-- 3.3.5's own "you are in a queue" indicator is MiniMapMeetingStoneFrame: a
-- 33x33 minimap button wearing MiniMap-TrackingBorder with the animated
-- Interface\LFGFrame\LFG-Eye flipbook inside it, shown while IsInLFGQueue().
-- The DC matchmaking queue shares nothing with stock sLFGMgr, so that frame
-- never lights up for it -- see dc_addon_matchmaking.cpp. This rebuilds the
-- same indicator out of the same art and drives it from the DC queue's own
-- state, so queueing through the DC Dungeon Finder looks like queueing on
-- retail: an eye spins on the minimap for as long as you are waiting, and it
-- flips to "Group Found!" the moment the ready check goes out.
--
-- Everything the eye reads is set by UI/MatchmakingQueue.lua:
--   GF.queueInProgress    the server says this character is queued
--   GF.queueJoinedAt      GetTime() the queue started (resynced by the server)
--   GF._queueStatus       last SMSG_QUEUE_STATUS payload (role tally, ETAs)
--   GF._queueLabel        what was queued for ("Random Heroic Dungeon", ...)
--   GF._proposalActive    a ready check is out
--   GF._proposalAccepted  we already clicked Enter and are waiting on others

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

namespace.GroupFinder = namespace.GroupFinder or {}
local GF = namespace.GroupFinder

local QUEUE_CAT_RAID = 2

-- Stock minimap-button art (MiniMapMeetingStoneFrame uses exactly these).
local BORDER_TEXTURE    = "Interface\\Minimap\\MiniMap-TrackingBorder"
local HIGHLIGHT_TEXTURE = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

local BUTTON_SIZE = 33
local EYE_SIZE    = 30
local BORDER_SIZE = 52

-- Bottom-left of the minimap ring, where retail parks the queue status button.
local DEFAULT_ANGLE = 218

local function fmtClock(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 0 then seconds = 0 end
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function fmtEta(value)
    value = tonumber(value)
    if not value or value < 0 then return "--" end
    return fmtClock(value)
end

local function GetCharKey()
    local name = UnitName("player") or "?"
    local realm = (type(GetRealmName) == "function" and GetRealmName()) or ""
    if realm ~= "" then return name .. "-" .. realm end
    return name
end

local function EnsureDB()
    DCMythicPlusHUDDB = DCMythicPlusHUDDB or {}
    local db = DCMythicPlusHUDDB.minimapQueue
    if type(db) ~= "table" then
        db = {}
        DCMythicPlusHUDDB.minimapQueue = db
    end
    if type(db.angle) ~= "number" then db.angle = DEFAULT_ANGLE end
    if db.enabled == nil then db.enabled = true end
    return db
end

-- =====================================================================
-- Placement
-- =====================================================================

-- Minimap buttons ride the ring, so a saved angle survives the minimap being
-- resized (DC-QOS's skin does exactly that) where a saved x/y would not.
function GF:PositionMinimapQueueEye()
    local eye = self.minimapQueueEye
    if not eye or not Minimap then return end

    local db = EnsureDB()
    local angle = math.rad(db.angle or DEFAULT_ANGLE)
    local radius = ((Minimap:GetWidth() or 140) / 2) + 10

    eye:ClearAllPoints()
    eye:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate(eye)
    if not Minimap then return end
    local scale = Minimap:GetEffectiveScale()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    if not mx or not cx or not scale or scale == 0 then return end

    EnsureDB().angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    GF:PositionMinimapQueueEye()
end

-- =====================================================================
-- Tooltip
-- =====================================================================

function GF:MinimapQueueTitle()
    if (tonumber(self._queueCategory) or 0) == QUEUE_CAT_RAID then
        return "Raid Finder"
    end
    return "Dungeon Finder"
end

function GF:ShowMinimapQueueTooltip(eye)
    GameTooltip:SetOwner(eye, "ANCHOR_LEFT")
    GameTooltip:SetText(self:MinimapQueueTitle(), 1, 0.82, 0)

    local label = self._queueLabel
    if label and label ~= "" then
        GameTooltip:AddLine(label, 1, 1, 1)
    end

    if self._proposalActive then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Group Found!", 0.1, 1, 0.1)
        if self._proposalRole then
            GameTooltip:AddLine(string.format("Your role: %s",
                tostring(self._proposalRole)), 1, 0.82, 0)
        end
        local accepted = tonumber(self._proposalAcceptedCount)
        local total = tonumber(self._proposalTotal)
        if accepted and total then
            GameTooltip:AddLine(string.format("%d of %d players have accepted.",
                accepted, total), 1, 1, 1)
        end
        local remain = (self._proposalDeadline or 0) - GetTime()
        if remain > 0 then
            GameTooltip:AddLine(string.format("Expires in %s.", fmtClock(remain)),
                0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(" ")
        if self._proposalAccepted then
            GameTooltip:AddLine("Waiting for the rest of the group.", 0.6, 0.8, 1)
        else
            GameTooltip:AddLine("Click to bring the ready check back.", 0.6, 0.8, 1)
        end
    else
        if self.queueJoinedAt then
            GameTooltip:AddLine(string.format("Time in Queue: %s",
                fmtClock(GetTime() - self.queueJoinedAt)), 0.8, 0.8, 0.8)
        end

        local status = self._queueStatus
        if status then
            local avg = tonumber(status.waitAvg)
            if avg and avg >= 0 then
                GameTooltip:AddLine(string.format("Average Wait: %s", fmtEta(avg)),
                    0.8, 0.8, 0.8)
                GameTooltip:AddLine(string.format("Tank %s   Healer %s   DPS %s",
                    fmtEta(status.waitTank), fmtEta(status.waitHealer),
                    fmtEta(status.waitDps)), 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine("Average Wait: calculating...", 0.8, 0.8, 0.8)
            end
            GameTooltip:AddLine(string.format("In Queue: %d Tanks  %d Healers  %d DPS",
                tonumber(status.tanks) or 0, tonumber(status.healers) or 0,
                tonumber(status.dps) or 0), 0.6, 0.6, 0.6)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to open the Group Finder.", 0.6, 0.8, 1)
        GameTooltip:AddLine("Right-click for queue options.", 0.6, 0.8, 1)
        GameTooltip:AddLine("Drag to move around the minimap.", 0.6, 0.8, 1)
    end

    GameTooltip:Show()
end

-- =====================================================================
-- Right-click menu
-- =====================================================================

local function InitQueueMenu(_, level)
    if level ~= 1 then return end

    local info = UIDropDownMenu_CreateInfo()
    info.isTitle, info.notCheckable = true, true
    info.text = GF:MinimapQueueTitle()
    UIDropDownMenu_AddButton(info, level)

    info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    info.text = "Open Group Finder"
    info.func = function() GF:Show() end
    UIDropDownMenu_AddButton(info, level)

    if GF._proposalActive and not GF._proposalAccepted then
        info = UIDropDownMenu_CreateInfo()
        info.notCheckable = true
        info.text = "Show Ready Check"
        info.func = function()
            if GF.queueProposalFrame then GF.queueProposalFrame:Show() end
        end
        UIDropDownMenu_AddButton(info, level)
    end

    info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    info.text = "Leave Queue"
    info.func = function() GF:LeaveMatchmakingQueue() end
    UIDropDownMenu_AddButton(info, level)

    info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    info.text = "Reset Icon Position"
    info.func = function()
        EnsureDB().angle = DEFAULT_ANGLE
        GF:PositionMinimapQueueEye()
    end
    UIDropDownMenu_AddButton(info, level)
end

-- =====================================================================
-- The eye
-- =====================================================================

function GF:CreateMinimapQueueEye()
    if self.minimapQueueEye then return self.minimapQueueEye end
    if not Minimap then return nil end

    -- Named without "MinimapButton"/"MiniMapIcon" on purpose: DC-QOS's minimap
    -- skin sweeps every child matching those names into its own button column,
    -- which would drag the eye off the ring the moment that module is enabled.
    local eye = CreateFrame("Button", "DCMatchmakingQueueEye", Minimap)
    eye:SetWidth(BUTTON_SIZE)
    eye:SetHeight(BUTTON_SIZE)
    eye:SetFrameStrata(Minimap:GetFrameStrata() or "MEDIUM")
    eye:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    eye:Hide()

    local glow = eye:CreateTexture(nil, "BACKGROUND")
    glow:SetWidth(46)
    glow:SetHeight(46)
    glow:SetPoint("CENTER")
    if not (namespace.SetGFAtlas and namespace.SetGFAtlas(glow, "eye-highlight")) then
        glow:Hide()
        glow = nil
    end
    eye.glow = glow

    local icon = eye:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(EYE_SIZE)
    icon:SetHeight(EYE_SIZE)
    icon:SetPoint("CENTER")
    icon:SetTexture(namespace.LFG_EYE_TEXTURE or "Interface\\LFGFrame\\LFG-Eye")
    eye.icon = icon
    if namespace.SetLFGEyeFrame then
        namespace.SetLFGEyeFrame(icon, 0)
    end

    local border = eye:CreateTexture(nil, "OVERLAY")
    border:SetWidth(BORDER_SIZE)
    border:SetHeight(BORDER_SIZE)
    border:SetTexture(BORDER_TEXTURE)
    border:SetPoint("TOPLEFT", eye, "TOPLEFT", 1, -1)
    eye.border = border

    -- Ready-check badge: the same green check the proposal popup uses.
    local mark = eye:CreateTexture(nil, "OVERLAY", nil, 2)
    mark:SetWidth(20)
    mark:SetHeight(20)
    mark:SetPoint("BOTTOMRIGHT", eye, "BOTTOMRIGHT", 4, -3)
    if not (namespace.SetGFAtlas and namespace.SetGFAtlas(mark, "readymark")) then
        mark:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    end
    mark:Hide()
    eye.mark = mark

    eye:SetHighlightTexture(HIGHLIGHT_TEXTURE, "ADD")

    eye:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    eye:RegisterForDrag("LeftButton")

    eye:SetScript("OnDragStart", function(self_)
        self_.isDragging = true
        self_._eyeSuspended = true
        GameTooltip:Hide()
        self_:SetScript("OnUpdate", function(f) OnDragUpdate(f) end)
    end)

    eye:SetScript("OnDragStop", function(self_)
        self_.isDragging = nil
        self_._eyeSuspended = nil
        self_:SetScript("OnUpdate", nil)
        GF:StartMinimapQueueEyeAnimation()
    end)

    eye:SetScript("OnEnter", function(self_)
        if self_.isDragging then return end
        GF:ShowMinimapQueueTooltip(self_)
    end)
    eye:SetScript("OnLeave", function() GameTooltip:Hide() end)

    eye:SetScript("OnClick", function(self_, button)
        if button == "RightButton" then
            if not GF.minimapQueueMenu then
                GF.minimapQueueMenu = CreateFrame("Frame", "DCMatchmakingQueueEyeMenu",
                    UIParent, "UIDropDownMenuTemplate")
            end
            UIDropDownMenu_Initialize(GF.minimapQueueMenu, InitQueueMenu, "MENU")
            ToggleDropDownMenu(1, nil, GF.minimapQueueMenu, self_, 0, 0)
            return
        end

        -- A ready check that was dismissed (or lost to a /reload) is what the
        -- player most likely wants back; otherwise open the finder.
        if GF._proposalActive and not GF._proposalAccepted
            and GF.queueProposalFrame then
            GF.queueProposalFrame:Show()
            return
        end
        GF:Toggle()
    end)

    self.minimapQueueEye = eye
    self:PositionMinimapQueueEye()
    return eye
end

-- Spin the LFG-Eye flipbook, and pulse the glow while a ready check is out.
function GF:StartMinimapQueueEyeAnimation()
    local eye = self.minimapQueueEye
    if not eye then return end

    local frames = namespace.LFG_EYE_FRAMES or 29
    local frameTime = namespace.LFG_EYE_FRAME_TIME or 0.05

    eye:SetScript("OnUpdate", function(self_, elapsed)
        if self_._eyeSuspended then return end

        -- The eye freezes on a match, exactly like the searching animation
        -- stopping in the finder window: motion means "still looking".
        if not GF._proposalActive then
            self_._acc = (self_._acc or 0) + elapsed
            while self_._acc >= frameTime do
                self_._acc = self_._acc - frameTime
                self_._frame = ((self_._frame or 0) + 1) % frames
            end
            if namespace.SetLFGEyeFrame then
                namespace.SetLFGEyeFrame(self_.icon, self_._frame or 0)
            end
            return
        end

        if self_.glow then
            self_._pulse = (self_._pulse or 0) + elapsed
            self_.glow:SetAlpha(0.55 + 0.45 * math.abs(math.sin(self_._pulse * 2.4)))
        end
    end)
end

-- =====================================================================
-- State
-- =====================================================================

-- Called from every queue transition in UI/MatchmakingQueue.lua (this replaces
-- the no-op stub declared there).
function GF:UpdateMinimapQueueEye()
    local db = EnsureDB()

    if not self.queueInProgress or not db.enabled then
        if self.minimapQueueEye then
            self.minimapQueueEye:SetScript("OnUpdate", nil)
            self.minimapQueueEye:Hide()
        end
        db.label = nil
        db.charKey = nil
        return
    end

    local eye = self:CreateMinimapQueueEye()
    if not eye then return end

    -- A /reload keeps the server-side queue but loses every client-side detail
    -- of it, and the restore status carries no dungeon name. Park the label so
    -- the tooltip after a reload still says what is being queued for.
    if self._queueLabel then
        db.label, db.charKey = self._queueLabel, GetCharKey()
    elseif db.label and db.charKey == GetCharKey() then
        self._queueLabel = db.label
    end

    if self._proposalActive then
        eye.icon:SetVertexColor(0.6, 1, 0.6)
        eye.mark:Show()
    else
        eye.icon:SetVertexColor(1, 1, 1)
        eye.mark:Hide()
        if eye.glow then eye.glow:SetAlpha(0.85) end
    end

    self:PositionMinimapQueueEye()
    eye:Show()
    self:StartMinimapQueueEyeAnimation()
end

-- Re-anchor after anything that can resize the minimap (DC-QOS's skin applies
-- its scale on login, well after this file has run).
do
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(5, function()
                if GF.minimapQueueEye then
                    GF:PositionMinimapQueueEye()
                end
            end)
        end
    end)
end
