--[[
    DC-Collection UI/Wardrobe/WardrobeShare.lua
    ===========================================

    Share saved outfits with other players "via chat".

    Transport: a hidden addon-message whisper (prefix "DCOUTFIT"), NOT a raw
    custom chat hyperlink. AzerothCore validates visible chat hyperlinks and can
    drop the message (or kick) for unknown link types, so a |Hdcoutfit:...|h link
    is unsafe to broadcast. Addon messages are relayed verbatim and carry no such
    risk. The recipient already has DC-Collection, so they get a popup to preview,
    apply, or save the shared look.

    Wire format (single addon message, <= ~240 bytes):
        "1|<eqSlot>.<displayId>-<eqSlot>.<displayId>...|<name>"
    Field 1 = version, field 2 = pairs (digits/./-), field 3 = name (no '|').
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

local ADDON_PREFIX = "DCOUTFIT"
local WIRE_VERSION = 1
local MAX_PAIRS = 25
local MAX_MSG_LEN = 240

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

function Wardrobe:_SanitizeOutfitName(name)
    name = tostring(name or "")
    -- Strip characters that would break the wire format or chat rendering.
    name = name:gsub("[|%[%]%c]", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        name = "Shared Outfit"
    end
    if #name > 40 then
        name = name:sub(1, 40)
    end
    return name
end

-- Resolve a stored slot value (which may be an itemId or a displayId) to a
-- displayId for sharing, so recipients render the right appearance.
function Wardrobe:_ResolveShareDisplayId(val)
    val = tonumber(val) or 0
    if val <= 0 then
        return 0
    end
    if type(self.GetAppearanceDisplayIdForItemId) == "function" then
        local d = self:GetAppearanceDisplayIdForItemId(val)
        if d and d > 0 then
            return d
        end
    end
    return val
end

-- Turn an outfit's slot table into the wire "eqSlot.displayId-..." string.
function Wardrobe:SerializeOutfitForLink(outfit)
    local slots = outfit and (outfit.slots or outfit.items)
    if type(slots) ~= "table" then
        return nil
    end

    local parts = {}
    for slotKey, val in pairs(slots) do
        local invSlotId
        if type(slotKey) == "number" or tonumber(slotKey) then
            local n = tonumber(slotKey)
            if n and n >= 1 and n <= 19 then
                invSlotId = n
            elseif n and n >= 0 and n <= 18 then
                invSlotId = n + 1
            end
        elseif type(slotKey) == "string" then
            invSlotId = GetInventorySlotInfo(slotKey)
        end

        if invSlotId then
            local displayId = self:_ResolveShareDisplayId(val)
            if displayId and displayId > 0 then
                parts[#parts + 1] = (invSlotId - 1) .. "." .. displayId
            end
        end
    end

    if #parts == 0 then
        return nil
    end
    return table.concat(parts, "-")
end

-- Parse a received wire string back into an outfit table with slot-key strings.
function Wardrobe:DeserializeSharedOutfit(message)
    if type(message) ~= "string" then
        return nil
    end

    local version, data, name = message:match("^(%d+)|([%d%.%-]*)|(.*)$")
    version = tonumber(version)
    if not version or version > WIRE_VERSION or not data or data == "" then
        return nil
    end

    -- Map 0-based equipment slot -> inventory slot key for this character.
    local eqSlotToKey = {}
    for _, def in ipairs(self.EQUIPMENT_SLOTS or {}) do
        local inv = GetInventorySlotInfo(def.key)
        if inv then
            eqSlotToKey[inv - 1] = def.key
        end
    end

    local slots = {}
    local count = 0
    for pair in data:gmatch("[^%-]+") do
        if count >= MAX_PAIRS then
            break
        end
        local eq, disp = pair:match("^(%d+)%.(%d+)$")
        eq, disp = tonumber(eq), tonumber(disp)
        if eq and disp and disp > 0 then
            local key = eqSlotToKey[eq]
            if key then
                slots[key] = disp
                count = count + 1
            end
        end
    end

    if count == 0 then
        return nil
    end

    return { name = self:_SanitizeOutfitName(name), slots = slots, __shared = true }
end

-- ============================================================================
-- DISPLAY-ID -> ITEM-ID (for client-side preview via TryOn)
-- ============================================================================

function Wardrobe:GetRepresentativeItemIdForDisplayId(displayId)
    displayId = tonumber(displayId)
    if not displayId or displayId <= 0 or not DC then
        return nil
    end

    if not self._displayIdToItemId then
        self._displayIdToItemId = {}
        local defs = DC.definitions and (DC.definitions.transmog or DC.definitions.wardrobe)
        if type(defs) == "table" then
            for id, raw in pairs(defs) do
                local def = raw
                if type(raw) == "string" then
                    if type(DC._GetUnpackedTransmogDefinition) == "function" then
                        def = DC:_GetUnpackedTransmogDefinition(id, raw)
                    elseif type(DC.ParsePackedTransmogDefinition) == "function" then
                        local _, _, _, pDisplayId, _, _, _, _, pItemId = DC:ParsePackedTransmogDefinition(raw)
                        def = { displayId = tonumber(pDisplayId), itemId = tonumber(pItemId) }
                    end
                end
                if type(def) == "table" then
                    local d = tonumber(def.displayId or def.displayID or def.display_id
                        or def.appearanceId or def.appearance_id)
                    local iid = tonumber(def.itemId or def.item_id)
                        or (type(id) == "number" and id) or tonumber(id)
                    if d and d > 0 and iid and not self._displayIdToItemId[d] then
                        self._displayIdToItemId[d] = iid
                    end
                end
            end
        end
    end

    return self._displayIdToItemId[displayId]
end

-- Invalidate the displayId->itemId cache when definitions change.
function Wardrobe:ClearDisplayIdToItemIdCache()
    self._displayIdToItemId = nil
end

-- ============================================================================
-- PREVIEW
-- ============================================================================

function Wardrobe:PreviewSharedOutfit(outfit)
    local model = self.frame and self.frame.model
    if not model or not outfit or type(outfit.slots) ~= "table" then
        return
    end

    model:SetUnit(Wardrobe.previewUnit or "player")
    for _, displayId in pairs(outfit.slots) do
        local iid = self:GetRepresentativeItemIdForDisplayId(displayId)
        if iid then
            pcall(function()
                model:TryOn("item:" .. tostring(iid) .. ":0:0:0:0:0:0:0")
            end)
        end
    end

    -- Frame full-body so the whole shared look is visible.
    local fb = self.MODEL_FULLBODY or { x = 1.8, y = 0, z = -0.2, facing = 0 }
    model.cameraX, model.cameraY, model.cameraZ = fb.x, fb.y, fb.z
    model.rotation = fb.facing or 0
    model._zoomTarget = nil
    if type(self._ApplyModelCamera) == "function" then
        self:_ApplyModelCamera(model)
    end
end

-- ============================================================================
-- SENDING
-- ============================================================================

function Wardrobe:SendOutfitToPlayer(outfit, targetName)
    targetName = tostring(targetName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if targetName == "" then
        if DC and DC.Print then DC:Print("Enter a player name to send the outfit to.") end
        return
    end

    local data = self:SerializeOutfitForLink(outfit)
    if not data then
        if DC and DC.Print then DC:Print("This outfit has no appearances to share.") end
        return
    end

    local name = self:_SanitizeOutfitName(outfit.name)
    local msg = string.format("%d|%s|%s", WIRE_VERSION, data, name)
    if #msg > MAX_MSG_LEN then
        -- Drop the name before truncating pairs (pairs are what matter).
        msg = string.format("%d|%s|", WIRE_VERSION, data):sub(1, MAX_MSG_LEN)
    end

    SendAddonMessage(ADDON_PREFIX, msg, "WHISPER", targetName)
    if DC and DC.Print then
        DC:Print(string.format("Sent outfit '%s' to %s.", name, targetName))
    end
end

function Wardrobe:ShowSendOutfitDialog(outfit)
    if not outfit then return end
    Wardrobe._pendingSendOutfit = outfit

    if not StaticPopupDialogs["DC_WARDROBE_SEND_OUTFIT"] then
        StaticPopupDialogs["DC_WARDROBE_SEND_OUTFIT"] = {
            text = "Send outfit to which player?",
            button1 = "Send",
            button2 = (CANCEL or "Cancel"),
            hasEditBox = true,
            maxLetters = 24,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            OnShow = function(self)
                local eb = self.editBox or (self.GetName and _G[self:GetName() .. "EditBox"])
                if eb then
                    local prefill = ""
                    if UnitExists("target") and UnitIsPlayer("target") then
                        prefill = UnitName("target") or ""
                    end
                    eb:SetText(prefill)
                    eb:HighlightText()
                    eb:SetFocus()
                end
            end,
            OnAccept = function(self)
                local eb = self.editBox or (self.GetName and _G[self:GetName() .. "EditBox"])
                local nameText = eb and eb:GetText() or ""
                if Wardrobe._pendingSendOutfit then
                    Wardrobe:SendOutfitToPlayer(Wardrobe._pendingSendOutfit, nameText)
                end
            end,
            EditBoxOnEnterPressed = function(self)
                local parent = self:GetParent()
                local nameText = self:GetText() or ""
                if Wardrobe._pendingSendOutfit then
                    Wardrobe:SendOutfitToPlayer(Wardrobe._pendingSendOutfit, nameText)
                end
                parent:Hide()
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide()
            end,
        }
    end

    StaticPopup_Show("DC_WARDROBE_SEND_OUTFIT")
end

-- ============================================================================
-- RECEIVING
-- ============================================================================

function Wardrobe:OnOutfitReceived(message, sender)
    local outfit = self:DeserializeSharedOutfit(message)
    if not outfit then
        return
    end

    sender = tostring(sender or "Someone"):gsub("%-.*$", "")  -- strip realm suffix
    outfit.from = sender
    Wardrobe._pendingSharedOutfit = outfit

    if not StaticPopupDialogs["DC_WARDROBE_IMPORT_OUTFIT"] then
        StaticPopupDialogs["DC_WARDROBE_IMPORT_OUTFIT"] = {
            -- text is set per-show via the format args.
            text = "%s shared the outfit '%s' with you.",
            button1 = "Apply",
            button2 = "Preview",
            button3 = (IGNORE or "Ignore"),
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            OnAccept = function()  -- Apply
                local o = Wardrobe._pendingSharedOutfit
                if o and type(Wardrobe.LoadOutfit) == "function" then
                    Wardrobe:LoadOutfit(o)
                end
            end,
            OnCancel = function()  -- Preview
                local o = Wardrobe._pendingSharedOutfit
                if not o then return end
                if type(Wardrobe.Show) == "function"
                    and not (Wardrobe.frame and Wardrobe.frame:IsShown()) then
                    Wardrobe:Show()
                end
                Wardrobe:PreviewSharedOutfit(o)
                if DC and DC.Print then
                    DC:Print(string.format("Previewing '%s'. Use the wardrobe to Apply or Save it.", o.name or ""))
                end
            end,
            OnAlt = function() end,  -- Ignore
        }
    end

    StaticPopup_Show("DC_WARDROBE_IMPORT_OUTFIT", sender, outfit.name or "Outfit")
end

-- ============================================================================
-- ADDON MESSAGE LISTENER
-- ============================================================================

if not Wardrobe._shareListener then
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:SetScript("OnEvent", function(_, _, prefix, message, _, sender)
        if prefix == ADDON_PREFIX then
            Wardrobe:OnOutfitReceived(message, sender)
        end
    end)
    Wardrobe._shareListener = f
end
