--[[
    DC-Collection Modules/CollectionLinks.lua
    =========================================

    Chat links for mounts and pets.

    Mirrors the outfit link plumbing in Modules/TransmogModule.lua: a custom
    |Hdc:mount:...|h / |Hdc:pet:...|h hyperlink is inserted into the chat edit
    box, and Core.lua's SetItemRef hook routes clicks back here.

    Link format (name is last so stray separators cannot break parsing):
        dc:mount:<ver>:<spellId>:<altId>:<name>
        dc:pet:<ver>:<petId>:<altId>:<name>

    where <altId> is a tagged secondary key ("i12345" = itemId, "s12345" =
    spellId, "c12345" = creatureId) or "0" when there is none.

    Mount/pet definitions are server-provided and identical for every client,
    so the id alone is enough for a receiver that has already loaded them; the
    alt id and the name are carried for receivers whose definitions are keyed
    differently or not loaded yet.

    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

local LINK_VER = "1"
local MOUNT_PREFIX = "dc:mount"
local PET_PREFIX = "dc:pet"
local MAX_LINK_NAME = 60

local MOUNT_TYPE_NAMES = {
    [1] = "Ground",
    [2] = "Flying",
    [3] = "Aquatic",
}

-- ============================================================================
-- HELPERS
-- ============================================================================

local function LT(key, fallback)
    local v = L and (L[key] or L[string.upper(key)])
    if type(v) ~= "string" or v == "" then
        return fallback
    end
    return v
end

local function ToPositiveNumber(value)
    local n = tonumber(value)
    if n and n > 0 then
        return n
    end
    return nil
end

-- Strip everything the hyperlink grammar treats as structure. A name that kept
-- a "|" would terminate the link early and the client would render garbage,
-- and a ":" would shift every field the parser reads back out.
local function SanitizeName(name)
    if type(name) ~= "string" then
        name = tostring(name or "")
    end

    -- Colour escapes come out whole, so an already-coloured name does not leave
    -- its "cffff0000" behind as text.
    name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
    name = string.gsub(name, "|r", "")
    name = string.gsub(name, "|", "")
    name = string.gsub(name, ":", " ")
    name = string.gsub(name, "%[", "")
    name = string.gsub(name, "%]", "")
    name = string.gsub(name, "%s+", " ")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")

    if string.len(name) > MAX_LINK_NAME then
        name = string.sub(name, 1, MAX_LINK_NAME)
    end

    return name
end

local function RarityHex(rarity)
    local color = (type(DC.GetRarityColor) == "function") and DC:GetRarityColor(rarity or 1) or nil
    return (color and color.hex) or "|cffffffff"
end

local function ResolveDefinition(collType, id)
    if type(DC.GetDefinition) == "function" then
        local ok, def = pcall(DC.GetDefinition, DC, collType, id)
        if ok and type(def) == "table" then
            return def
        end
    end

    local defs = DC.definitions and DC.definitions[collType]
    if type(defs) ~= "table" then
        return nil
    end

    if type(defs[id]) == "table" then
        return defs[id]
    end

    local n = tonumber(id)
    if n and type(defs[n]) == "table" then
        return defs[n]
    end

    local s = tostring(id)
    if type(defs[s]) == "table" then
        return defs[s]
    end

    return nil
end

-- The alt id gives the receiver a second key to match on when their
-- definitions are keyed by something other than the sender's key. It is
-- tagged with the field it came from ("s12345" = spellId, "i" = itemId,
-- "c" = creatureId) so the receiver matches it against that field only
-- instead of against any numeric id it happens to equal.
local ALT_KIND_TAGS = {
    s = "spellId",
    i = "itemId",
    c = "creatureId",
}

local function ResolveAltId(collType, id, def)
    def = def or ResolveDefinition(collType, id)
    if type(def) ~= "table" then
        return "0"
    end

    local alt, tag
    if collType == "mounts" then
        alt, tag = ToPositiveNumber(def.itemId or def.item_id), "i"
    else
        alt, tag = ToPositiveNumber(def.spellId or def.spell_id), "s"
        if not alt then
            alt, tag = ToPositiveNumber(def.itemId or def.item_id), "i"
        end
        if not alt then
            alt, tag = ToPositiveNumber(def.creatureId or def.creature_id), "c"
        end
    end

    if not alt or tostring(alt) == tostring(id) then
        return "0"
    end
    return tag .. tostring(alt)
end

local function IsCollected(collType, id)
    if collType == "mounts" then
        if DC.MountModule and type(DC.MountModule.IsMountCollected) == "function" then
            local ok, collected = pcall(DC.MountModule.IsMountCollected, DC.MountModule, id)
            if ok then
                return collected and true or false
            end
        end
    elseif collType == "pets" then
        if DC.PetModule and type(DC.PetModule.IsPetCollected) == "function" then
            local ok, collected = pcall(DC.PetModule.IsPetCollected, DC.PetModule, id)
            if ok then
                return collected and true or false
            end
        end
    end

    local coll = DC.collections and DC.collections[collType]
    if type(coll) ~= "table" then
        return false
    end

    local n = tonumber(id)
    return (coll[id] ~= nil) or (n ~= nil and coll[n] ~= nil) or (coll[tostring(id)] ~= nil)
end

-- ============================================================================
-- LINK GENERATION
-- ============================================================================

-- collType is "mounts" or "pets"; id is the key used by DC.definitions[collType].
function DC:GenerateCollectionLink(collType, id, def)
    if collType ~= "mounts" and collType ~= "pets" then
        return nil
    end
    if id == nil or tostring(id) == "" then
        return nil
    end

    def = def or ResolveDefinition(collType, id)

    local name = SanitizeName((def and def.name) or "")
    if name == "" then
        name = (collType == "mounts") and "Mount" or "Pet"
    end

    local prefix = (collType == "mounts") and MOUNT_PREFIX or PET_PREFIX
    local linkData = string.format("%s:%s:%s:%s:%s",
        prefix, LINK_VER, tostring(id), tostring(ResolveAltId(collType, id, def)), name)

    return string.format("%s|H%s|h[%s]|h|r", RarityHex(def and def.rarity), linkData, name)
end

function DC:GenerateMountLink(spellId, def)
    return self:GenerateCollectionLink("mounts", spellId, def)
end

function DC:GeneratePetLink(petId, def)
    return self:GenerateCollectionLink("pets", petId, def)
end

-- ============================================================================
-- LINK PARSING
-- ============================================================================

-- Returns collType, id, altId, altField, name.
function DC:ParseCollectionLink(linkData)
    if type(linkData) ~= "string" then
        return nil
    end

    local collType
    if string.sub(linkData, 1, string.len(MOUNT_PREFIX)) == MOUNT_PREFIX then
        collType = "mounts"
    elseif string.sub(linkData, 1, string.len(PET_PREFIX)) == PET_PREFIX then
        collType = "pets"
    else
        return nil
    end

    -- parts: dc, mount|pet, ver, id, altId, name...
    local parts = { strsplit(":", linkData) }
    if #parts < 5 then
        return nil
    end

    local id = parts[4]
    if id == nil or id == "" then
        return nil
    end

    local altId, altField
    local altRaw = parts[5] or "0"
    local altTag = string.sub(altRaw, 1, 1)
    if ALT_KIND_TAGS[altTag] then
        altId = ToPositiveNumber(string.sub(altRaw, 2))
        altField = altId and ALT_KIND_TAGS[altTag] or nil
    end

    local name = ""
    if #parts >= 6 then
        local nameParts = {}
        for i = 6, #parts do
            table.insert(nameParts, parts[i])
        end
        name = table.concat(nameParts, ":")
    end

    return collType, tonumber(id) or id, altId, altField, name
end

-- ============================================================================
-- INSERTING LINKS INTO CHAT
-- ============================================================================

function DC:InsertLinkToChat(link)
    if type(link) ~= "string" or link == "" then
        return false
    end

    if type(ChatEdit_InsertLink) ~= "function" then
        return false
    end

    -- ChatEdit_InsertLink only writes into the *active* (focused) edit box, so
    -- open one first when the player has chat closed.
    if type(ChatEdit_GetActiveWindow) == "function" and not ChatEdit_GetActiveWindow() then
        if type(ChatFrame_OpenChat) == "function" then
            ChatFrame_OpenChat("", DEFAULT_CHAT_FRAME)
        elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then
            DEFAULT_CHAT_FRAME.editBox:Show()
            DEFAULT_CHAT_FRAME.editBox:SetFocus()
        end
    end

    return ChatEdit_InsertLink(link) ~= false
end

-- Convenience wrapper used by the collection UIs.
function DC:LinkCollectionEntryToChat(collType, id, def)
    local link = self:GenerateCollectionLink(collType, id, def)
    if not link then
        return false
    end
    return self:InsertLinkToChat(link)
end

-- ============================================================================
-- OPENING A LINKED ENTRY IN THE COLLECTION UI
-- ============================================================================

local ALT_FIELD_ALIASES = {
    spellId = { "spellId", "spell_id" },
    itemId = { "itemId", "item_id" },
    creatureId = { "creatureId", "creature_id" },
}

local function EntryMatchesLink(entry, id, altId, altField)
    if type(entry) ~= "table" then
        return false
    end

    if tostring(entry.id or "") == tostring(id) then
        return true
    end

    if not altId or not altField then
        return false
    end

    local def = entry.definition or {}
    for _, key in ipairs(ALT_FIELD_ALIASES[altField] or {}) do
        if ToPositiveNumber(entry[key]) == altId or ToPositiveNumber(def[key]) == altId then
            return true
        end
    end

    return false
end

local function GetVisibleList(collType)
    if collType == "pets" then
        local journal = DC.PetJournal
        if journal and type(journal.UpdatePetList) == "function" then
            journal:UpdatePetList()
        end
        return (journal and journal.filteredPets) or {}
    end

    if type(DC.GetFilteredItems) == "function" then
        return DC:GetFilteredItems() or {}
    end
    return {}
end

local function IsLinkTargetVisible(collType, id, altId, altField)
    for _, entry in ipairs(GetVisibleList(collType)) do
        if EntryMatchesLink(entry, id, altId, altField) then
            return true
        end
    end
    return false
end

-- A linked entry the receiver has filtered out (search text, a cleared
-- collected/not-collected box, a narrowed expansion filter) would silently do
-- nothing on click, so widen the filters before giving up on it.
local function RelaxFilters()
    local fb = DC.MainFrame and DC.MainFrame.FilterBar
    if not fb then
        return false
    end

    local changed = false

    if fb.searchBox and (fb.searchBox:GetText() or "") ~= "" then
        fb.searchBox:SetText("")
        changed = true
    end
    if fb.collectedCheck and not fb.collectedCheck:GetChecked() then
        fb.collectedCheck:SetChecked(true)
        changed = true
    end
    if fb.notCollectedCheck and not fb.notCollectedCheck:GetChecked() then
        fb.notCollectedCheck:SetChecked(true)
        changed = true
    end
    if (DC.selectedExpansionFilter or "all") ~= "all" then
        DC.selectedExpansionFilter = "all"
        if fb.expansionDropdown and type(UIDropDownMenu_SetText) == "function"
            and DC.EXPANSION_FILTERS and DC.EXPANSION_FILTERS[1] then
            UIDropDownMenu_SetText(fb.expansionDropdown, DC.EXPANSION_FILTERS[1].text)
        end
        changed = true
    end

    if changed and type(DC.OnFilterChanged) == "function" then
        DC:OnFilterChanged()
    end

    return changed
end

local function FocusLinkTarget(collType, id, altId, altField, name)
    if type(DC.FocusCollectionEntry) ~= "function" then
        return false
    end

    if not IsLinkTargetVisible(collType, id, altId, altField) then
        RelaxFilters()
        if not IsLinkTargetVisible(collType, id, altId, altField) then
            return false
        end
    end

    local data = {
        type = collType,
        id = id,
        name = (name ~= "" and name) or nil,
    }
    if altId and altField then
        data[altField] = altId
    end

    DC:FocusCollectionEntry(data)
    return true
end

-- Definitions arrive asynchronously; a link clicked before the first sync has
-- nothing to focus yet, so request them and retry a few times.
local function OpenLinkTarget(collType, id, altId, altField, name, attemptsLeft)
    attemptsLeft = attemptsLeft or 6

    if FocusLinkTarget(collType, id, altId, altField, name) then
        return
    end

    if attemptsLeft <= 1 then
        local label = (name ~= "" and name) or tostring(id)
        local tabName = (collType == "mounts") and LT("TAB_MOUNTS", "Mounts") or LT("TAB_PETS", "Pets")
        DC:Print(string.format(LT("LINK_NOT_FOUND",
            "%s is not in your collection list yet - open the %s tab once so its data loads, then click the link again."),
            label, tabName))
        return
    end

    local defs = DC.definitions and DC.definitions[collType]
    if (type(defs) ~= "table" or not next(defs)) and type(DC.RequestDefinitions) == "function" then
        DC:RequestDefinitions(collType)
    end

    if type(DC.After) == "function" then
        DC.After(0.4, function()
            OpenLinkTarget(collType, id, altId, altField, name, attemptsLeft - 1)
        end)
    else
        -- No timer to retry on: report now rather than dropping the click.
        OpenLinkTarget(collType, id, altId, altField, name, 1)
    end
end

-- ============================================================================
-- CLICK HANDLING (called from Core.lua's SetItemRef hook)
-- ============================================================================

function DC:HandleCollectionLinkClick(linkData, button)
    local collType, id, altId, altField, name = self:ParseCollectionLink(linkData)
    if not collType then
        return false
    end

    -- Shift-click re-links, exactly like an item link.
    if type(IsModifiedClick) == "function" and IsModifiedClick("CHATLINK") then
        local link = self:GenerateCollectionLink(collType, id, ResolveDefinition(collType, id))
        if not link and name ~= "" then
            link = string.format("%s|H%s|h[%s]|h|r", RarityHex(1), linkData, name)
        end
        if link and self:InsertLinkToChat(link) then
            return true
        end
    end

    if type(self.ShowMainFrame) == "function" then
        self:ShowMainFrame()
    end

    OpenLinkTarget(collType, id, altId, altField, name)
    return true
end

-- ============================================================================
-- HOVER TOOLTIP IN CHAT
-- ============================================================================

function DC:ShowCollectionLinkTooltip(anchor, linkData)
    local collType, id, altId, _, name = self:ParseCollectionLink(linkData)
    if not collType then
        return false
    end

    local def = ResolveDefinition(collType, id)
    if not def and altId then
        def = ResolveDefinition(collType, altId)
    end

    local displayName = (def and def.name) or ((name ~= "") and name) or tostring(id)
    local color = (type(self.GetRarityColor) == "function") and self:GetRarityColor((def and def.rarity) or 1) or nil

    GameTooltip:SetOwner(anchor or UIParent, "ANCHOR_CURSOR")
    GameTooltip:AddLine(displayName, (color and color.r) or 1, (color and color.g) or 1, (color and color.b) or 1)

    if collType == "mounts" then
        local mountType = tonumber(def and (def.mountType or def.mount_type))
        local typeName = mountType and MOUNT_TYPE_NAMES[mountType]
        GameTooltip:AddLine(typeName and (typeName .. " Mount") or "Mount", 1, 1, 1)
    else
        GameTooltip:AddLine("Companion Pet", 1, 1, 1)
    end

    if def then
        local sourceText = (type(self.FormatSource) == "function") and self:FormatSource(def.source) or nil
        if sourceText and sourceText ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(LT("SOURCE", "Source") .. ": " .. tostring(sourceText), 0.7, 0.7, 0.7)
        end

        GameTooltip:AddLine(" ")
        if IsCollected(collType, id) then
            GameTooltip:AddLine(LT("COLLECTED", "Collected"), 0, 1, 0)
        else
            GameTooltip:AddLine(LT("NOT_COLLECTED", "Not collected"), 1, 0, 0)
        end
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(LT("LINK_DATA_NOT_LOADED", "Collection data not loaded yet."), 0.7, 0.7, 0.7)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LT("LINK_CLICK_TO_VIEW", "Click to view in your Collection"), 0.5, 0.5, 0.5)

    -- Staff only (DC.isGM comes from the stats push): the link carries the very
    -- id ".collection grant" wants -- mount spell id / pet teaching item id --
    -- but the chat frame shows only the name, so spell it out here.
    if self.isGM then
        GameTooltip:AddLine(string.format(".collection grant %s %s",
            (collType == "mounts") and "mount" or "pet", tostring(id)), 0.4, 0.8, 1)
    end

    GameTooltip:Show()

    return true
end

-- Chat frames have no hyperlink hover handler in 3.3.5a, so install one. Any
-- existing handler (another addon's) is preserved and still runs -- we only add
-- behaviour for dc: links.
local function HookChatFrameHover(frame)
    if not frame or frame._dcCollectionLinkHooked then
        return
    end
    if type(frame.SetScript) ~= "function" or type(frame.GetScript) ~= "function" then
        return
    end

    frame._dcCollectionLinkHooked = true

    local prevEnter = frame:GetScript("OnHyperlinkEnter")
    frame:SetScript("OnHyperlinkEnter", function(self, linkData, link, ...)
        if prevEnter then
            pcall(prevEnter, self, linkData, link, ...)
        end
        if type(linkData) == "string" and string.sub(linkData, 1, 3) == "dc:" then
            pcall(DC.ShowCollectionLinkTooltip, DC, self, linkData)
        end
    end)

    local prevLeave = frame:GetScript("OnHyperlinkLeave")
    frame:SetScript("OnHyperlinkLeave", function(self, linkData, link, ...)
        if prevLeave then
            pcall(prevLeave, self, linkData, link, ...)
        end
        if type(linkData) == "string" and string.sub(linkData, 1, 3) == "dc:" then
            GameTooltip:Hide()
        end
    end)
end

local function HookChatFrames()
    local count = tonumber(NUM_CHAT_WINDOWS) or 7
    for i = 1, count do
        HookChatFrameHover(_G["ChatFrame" .. i])
    end
end

local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:SetScript("OnEvent", function()
    HookChatFrames()
    -- Temporary chat windows (whisper tabs, pop-outs) are created on demand;
    -- catch them as they are opened.
    if type(hooksecurefunc) == "function" and type(FCF_OpenTemporaryWindow) == "function" then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            HookChatFrames()
        end)
    end
end)
