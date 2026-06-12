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

    SMSG_CATALOG       = 0x10,
    SMSG_PLACE_RESULT  = 0x11,
    SMSG_MOVE_RESULT   = 0x12,
    SMSG_REMOVE_RESULT = 0x13,
    SMSG_BUDGET        = 0x14,
    SMSG_SELECT_RESULT = 0x15,
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
                DC:Print("Decoration placed.")
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

    self:RequestBudget()
end

function Protocol:RequestBudget()
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_GET_BUDGET)
end

-- entry placed at the player's position when coords are omitted.
function Protocol:Place(entry, x, y, z, o)
    local data = { entry = entry }
    if x then
        data.x, data.y, data.z, data.o = x, y, z, o or 0
    end
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_PLACE, data)
end

function Protocol:MoveTo(lowguid, x, y, z, o)
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_MOVE,
        { lowguid = lowguid, mode = "to", x = x, y = y, z = z, o = o or 0 })
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

function Protocol:Remove(lowguid)
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_REMOVE,
        { lowguid = lowguid })
end

function Protocol:Select(guidHex)
    DCAddonProtocol:Request(DC.MODULE_ID, self.Opcodes.CMSG_SELECT,
        { guid = guidHex })
end
