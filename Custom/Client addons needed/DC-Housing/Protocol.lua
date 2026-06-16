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

    SMSG_CATALOG       = 0x10,
    SMSG_PLACE_RESULT  = 0x11,
    SMSG_MOVE_RESULT   = 0x12,
    SMSG_REMOVE_RESULT = 0x13,
    SMSG_BUDGET        = 0x14,
    SMSG_SELECT_RESULT = 0x15,
    SMSG_OPEN_UI       = 0x16,
    SMSG_LIST          = 0x17,
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
            end
        end)

    DCAddonProtocol:RegisterJSONHandler(DC.MODULE_ID, O.SMSG_REMOVE_RESULT,
        function(data)
            data = data or {}
            if data.success then
                local refund = tonumber(data.refund) or 0
                DC:Print(string.format("Decoration removed (%dg refunded).",
                    math.floor(refund / 10000)))
                if DC.EditMode then
                    DC.EditMode:ClearSelection()
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
            DC.Catalog:Show()
        end)

    DCAddonProtocol:RegisterJSONHandler(DC.MODULE_ID, O.SMSG_LIST,
        function(data)
            DC.placed = (data and data.items) or {}
            if DC.Catalog then
                DC.Catalog:OnPlacedUpdate()
            end
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
-- decorations ConsumeMoveRateLimit). The gizmo commits one move per release,
-- so rapid drag-releases would flood the server with rejected requests
-- ("You are moving decorations too quickly."). Coalesce: send immediately if
-- the cooldown has elapsed, otherwise remember only the LATEST target and
-- flush it once the cooldown passes. The object already moved client-side via
-- the gizmo, so persisting just the final position is correct.
local MOVE_MIN_INTERVAL = 0.55
local lastMoveSent = 0
local pendingMove
local moveFlushFrame

local function SendMoveNow(m)
    DCAddonProtocol:Request(DC.MODULE_ID, Protocol.Opcodes.CMSG_MOVE,
        { lowguid = m.lowguid, mode = "to", x = m.x, y = m.y, z = m.z,
          o = m.o or 0 })
    lastMoveSent = GetTime()
end

function Protocol:MoveTo(lowguid, x, y, z, o)
    local m = { lowguid = lowguid, x = x, y = y, z = z, o = o or 0 }
    if GetTime() - lastMoveSent >= MOVE_MIN_INTERVAL then
        pendingMove = nil
        SendMoveNow(m)
        return
    end

    pendingMove = m
    if not moveFlushFrame then
        moveFlushFrame = CreateFrame("Frame")
        moveFlushFrame:Hide()
        moveFlushFrame:SetScript("OnUpdate", function(self)
            if not pendingMove then
                self:Hide()
                return
            end
            if GetTime() - lastMoveSent >= MOVE_MIN_INTERVAL then
                local m2 = pendingMove
                pendingMove = nil
                SendMoveNow(m2)
                self:Hide()
            end
        end)
    end
    moveFlushFrame:Show()
end

function Protocol:Nudge(lowguid, dx, dy, dz, dOrientation)
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_MOVE,
        { lowguid = lowguid, mode = "nudge",
          dx = dx or 0, dy = dy or 0, dz = dz or 0, ["do"] = dOrientation or 0 })
end

function Protocol:Rotate(lowguid)
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_MOVE,
        { lowguid = lowguid, mode = "rotate" })
end

-- Move the decoration to the player's current position (server reads it).
function Protocol:MoveHere(lowguid)
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_MOVE,
        { lowguid = lowguid, mode = "here" })
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
