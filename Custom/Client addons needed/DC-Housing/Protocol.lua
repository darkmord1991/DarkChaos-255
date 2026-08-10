-- DC-Housing Protocol: DECO module mirror over DC-AddonProtocol.
local DC = DCHousing
local L = DCHousingLocale

DC.Protocol = DC.Protocol or {}
local Protocol = DC.Protocol

Protocol.Opcodes = {
    CMSG_GET_CATALOG   = 0x01,
    CMSG_PLACE         = 0x02,
    CMSG_MOVE          = 0x03,
    CMSG_REMOVE        = 0x04,
    CMSG_GET_BUDGET    = 0x05,
    CMSG_SELECT        = 0x06,
    CMSG_LIST          = 0x07,

    CMSG_RESET_ALL     = 0x08,

    SMSG_CATALOG           = 0x10,
    SMSG_PLACE_RESULT      = 0x11,
    SMSG_MOVE_RESULT       = 0x12,
    SMSG_REMOVE_RESULT     = 0x13,
    SMSG_BUDGET            = 0x14,
    SMSG_SELECT_RESULT     = 0x15,
    SMSG_OPEN_UI           = 0x16,
    SMSG_LIST              = 0x17,
    SMSG_RESET_ALL_RESULT  = 0x18,
}

function Protocol:Init()
    local O = self.Opcodes

    DCAddonProtocol:RegisterJSONHandler(DC.MODULE_ID, O.SMSG_BUDGET,
        function(data)
            data = data or {}
            DC.budget.used = tonumber(data.used) or 0
            DC.budget.cap = tonumber(data.cap) or 0
            DC.budget.houseLevel = tonumber(data.houseLevel) or 0
            DC.budget.canSpawn = data.canSpawn and true or false
            DC.budget.canMove = data.canMove and true or false
            DC.budget.canDelete = data.canDelete and true or false
            if DC.Catalog then
                DC.Catalog:OnBudgetUpdate()
            end
        end)

    DCAddonProtocol:RegisterJSONHandler(DC.MODULE_ID, O.SMSG_PLACE_RESULT,
        function(data)
            data = data or {}
            if data.success then
                local entry = self._lastPlaceEntry
                local item = entry and DC:GetItem(entry)
                local name = (item and item.name)
                    or (entry and ("Entry " .. entry)) or "Decoration"
                local spawn = tonumber(data.lowguid)
                if entry and spawn then
                    DC:Print(string.format(
                        "Placed |cffffd700%s|r (entry %d, spawn %d).",
                        name, entry, spawn))
                elseif entry then
                    DC:Print(string.format(
                        "Placed |cffffd700%s|r (entry %d).", name, entry))
                else
                    DC:Print("Decoration placed.")
                end

                -- Gizmo-first: auto-select the freshly placed object so its
                -- toolbar (and the in-world gizmo, once its render is fixed)
                -- appear immediately. Enter edit mode so it is draggable.
                if data.guid and DC.EditMode and DC.EditMode.AutoSelect then
                    if DC.EditMode.IsActive and not DC.EditMode:IsActive() then
                        DC.EditMode:Toggle()
                    end
                    DC.EditMode:AutoSelect(data.guid)
                end
            else
                DC:Print("|cffff0000" .. (data.error or "Place failed.") .. "|r")
            end
            self:RequestBudget()
        end)

    DCAddonProtocol:RegisterJSONHandler(DC.MODULE_ID, O.SMSG_MOVE_RESULT,
        function(data)
            data = data or {}
            if not data.success then
                DC:Print("|cffff0000" .. (data.error or "Move failed.") .. "|r")
                return
            end
            -- GOMove respawned the object under a new GUID; re-attach the
            -- in-world gizmo to it (the old GUID is now dead, which is why the
            -- gizmo otherwise vanished after the first move).
            if data.guid and DC.EditMode and DC.EditMode.OnMoved then
                DC.EditMode:OnMoved(tonumber(data.lowguid), data.guid)
            end
            -- Refresh the manage list only now that the server has applied
            -- the move (a click-time refresh could race the coalescer queue).
            if DC.Catalog and DC.Catalog.OnDecorationMoved then
                DC.Catalog:OnDecorationMoved()
            end
        end)

    DCAddonProtocol:RegisterJSONHandler(DC.MODULE_ID, O.SMSG_REMOVE_RESULT,
        function(data)
            data = data or {}
            if data.success then
                local refund = tonumber(data.refund) or 0
                -- Only decorations you placed yourself are refunded to you
                -- personally; others' go to the guild bank (refundToBank).
                if data.refundToBank then
                    DC:Print(string.format(
                        "Decoration removed (%dg refunded to the guild bank).",
                        math.floor(refund / 10000)))
                else
                    DC:Print(string.format(
                        "Decoration removed (%dg refunded).",
                        math.floor(refund / 10000)))
                end
                if DC.EditMode then
                    DC.EditMode:ClearSelection()
                end
                -- Drop a now-dead placed-list selection and refresh the list
                -- so the manage UI doesn't keep a removed row selected.
                if DC.Catalog and DC.Catalog.OnDecorationRemoved then
                    DC.Catalog:OnDecorationRemoved(tonumber(data.lowguid))
                end
            else
                DC:Print("|cffff0000" .. (data.error or "Remove failed.") .. "|r")
            end
            self:RequestBudget()
        end)

    DCAddonProtocol:RegisterJSONHandler(DC.MODULE_ID, O.SMSG_SELECT_RESULT,
        function(data)
            if DC.EditMode then
                DC.EditMode:OnSelectResult(data or {})
            end
        end)

    -- Decorator NPC pushes this instead of its gossip menu.
    DCAddonProtocol:RegisterJSONHandler(DC.MODULE_ID, O.SMSG_OPEN_UI,
        function()
            if DC.Catalog then
                DC.Catalog:Show()
            end
        end)

    DCAddonProtocol:RegisterJSONHandler(DC.MODULE_ID, O.SMSG_LIST,
        function(data)
            DC.placed = (data and data.items) or {}
            if DC.Catalog then
                DC.Catalog:OnPlacedUpdate()
            end
        end)

    DCAddonProtocol:RegisterJSONHandler(DC.MODULE_ID, O.SMSG_RESET_ALL_RESULT,
        function(data)
            data = data or {}
            if data.success then
                local removed = tonumber(data.removed) or 0
                local refund = tonumber(data.refund) or 0
                -- refundBank = the part of the total that went to the guild
                -- bank (decorations placed by others); the rest is personal.
                local refundBank = tonumber(data.refundBank) or 0
                if refundBank > 0 then
                    DC:Print(string.format(
                        "Removed %d decoration(s). %dg refunded "
                        .. "(%dg to the guild bank, %dg to you).",
                        removed, math.floor(refund / 10000),
                        math.floor(refundBank / 10000),
                        math.floor((refund - refundBank) / 10000)))
                else
                    DC:Print(string.format(
                        "Removed %d decoration(s). %dg refunded.",
                        removed, math.floor(refund / 10000)))
                end
                if DC.EditMode then
                    DC.EditMode:ClearSelection()
                end
                self:RequestList()
            else
                DC:Print("|cffff0000"
                    .. (data.error or "Reset failed.") .. "|r")
            end
            self:RequestBudget()
        end)

    self:RequestBudget()
end

function Protocol:RequestBudget()
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_GET_BUDGET)
end

-- entry placed at the player's position when coords are omitted.
function Protocol:Place(entry, x, y, z, o)
    -- Remembered so SMSG_PLACE_RESULT can name the placed decoration (the
    -- result only carries success + the new spawn lowguid).
    self._lastPlaceEntry = entry
    local data = { entry = entry }
    if x then
        data.x, data.y, data.z, data.o = x, y, z, o or 0
    end
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_PLACE, data)
end

-- The server caps moves at 1 / 500ms per player (see dc_guildhouse_
-- decorations ConsumeMoveRateLimit) and EVERY CMSG_MOVE mode (to / here /
-- rotate / nudge / scale) consumes that budget, so rapid clicks would flood
-- the server with rejected requests ("You are moving decorations too
-- quickly.") and lose operations. Coalesce all of them: send immediately if
-- the cooldown has elapsed and nothing is queued, otherwise queue and flush
-- one message per cooldown window. Merging: consecutive nudges of the same
-- lowguid sum their deltas; a newer absolute op (to/here/rotate/scale)
-- replaces a queued one of the same lowguid + mode.
local MOVE_MIN_INTERVAL = 0.55
local lastMoveSent = 0
local moveQueue = {}
local moveFlushFrame

local function SendMoveNow(msg)
    DCAddonProtocol:Request(DC.MODULE_ID, Protocol.Opcodes.CMSG_MOVE, msg)
    lastMoveSent = GetTime()
end

local function QueueMove(msg)
    if not moveQueue[1]
        and GetTime() - lastMoveSent >= MOVE_MIN_INTERVAL then
        SendMoveNow(msg)
        return
    end

    for i, queued in ipairs(moveQueue) do
        if queued.lowguid == msg.lowguid and queued.mode == msg.mode then
            if msg.mode == "nudge" then
                queued.dx = (queued.dx or 0) + (msg.dx or 0)
                queued.dy = (queued.dy or 0) + (msg.dy or 0)
                queued.dz = (queued.dz or 0) + (msg.dz or 0)
                queued["do"] = (queued["do"] or 0) + (msg["do"] or 0)
            else
                moveQueue[i] = msg
            end
            return
        end
    end

    table.insert(moveQueue, msg)
    if not moveFlushFrame then
        moveFlushFrame = CreateFrame("Frame")
        moveFlushFrame:SetScript("OnUpdate", function(self)
            if not moveQueue[1] then
                self:Hide()
                return
            end
            if GetTime() - lastMoveSent >= MOVE_MIN_INTERVAL then
                SendMoveNow(table.remove(moveQueue, 1))
            end
        end)
    end
    moveFlushFrame:Show()
end

function Protocol:MoveTo(lowguid, x, y, z, o)
    QueueMove({ lowguid = lowguid, mode = "to", x = x, y = y, z = z,
        o = o or 0 })
end

function Protocol:Nudge(lowguid, dx, dy, dz, dOrientation)
    QueueMove({ lowguid = lowguid, mode = "nudge",
        dx = dx or 0, dy = dy or 0, dz = dz or 0,
        ["do"] = dOrientation or 0 })
end

function Protocol:Rotate(lowguid)
    QueueMove({ lowguid = lowguid, mode = "rotate" })
end

-- Set the decoration's visual scale (server clamps to 0.2..5.0, persists it,
-- and replicates the new size to every nearby player).
function Protocol:Scale(lowguid, scale)
    QueueMove({ lowguid = lowguid, mode = "scale", scale = scale or 1 })
end

-- Move the decoration to the player's current position (server reads it).
function Protocol:MoveHere(lowguid)
    QueueMove({ lowguid = lowguid, mode = "here" })
end

function Protocol:RequestList()
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_LIST)
end

function Protocol:Remove(lowguid)
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_REMOVE,
        { lowguid = lowguid })
end

function Protocol:Select(guidHex)
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_SELECT,
        { guid = guidHex })
end

-- Select a placed decoration by its spawn id (used by the manage list, which
-- knows the lowguid but not the live client GUID). The server resolves the
-- gameobject and returns its full GUID in SMSG_SELECT_RESULT.
function Protocol:SelectByLowguid(lowguid)
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_SELECT,
        { lowguid = lowguid })
end

function Protocol:ResetAll()
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_RESET_ALL)
end
