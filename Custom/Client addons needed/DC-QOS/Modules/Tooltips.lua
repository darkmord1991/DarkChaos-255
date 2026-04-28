-- ============================================================
-- DC-QoS: Tooltips Module
-- ============================================================
-- Enhanced tooltip functionality for items, NPCs, and spells
-- Adapted from Leatrix Plus for WoW 3.3.5a compatibility
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local Tooltips = {
    displayName = "Tooltips",
    settingKey = "tooltips",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
}

-- ============================================================
-- Local Variables
-- ============================================================
-- Match DC-Leaderboards UI style across DC addons
local BG_FELLEATHER = "Interface\\AddOns\\DC-QOS\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyle then return end
    frame.__dcLeaderboardsStyle = true

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

    frame.__dcBg = bg
    frame.__dcTint = tint
end

local itemInfoCache = {}  -- Cache GetItemInfo results
local ITEM_INFO_CACHE_DURATION = 60  -- 1 minute

-- ============================================================
-- Item Upgrade/Tier Info Cache
-- ============================================================
-- Cache for item upgrade data from server
local itemUpgradeCache = {}
local pendingUpgradeRequests = {}
local UPGRADE_CACHE_DURATION = 300  -- 5 minutes

-- Tier color definitions (matches DC-ItemUpgrade)
local TIER_COLORS = {
    [0] = "|cff888888",  -- No tier (gray)
    [1] = "|cff00ff00",  -- Tier 1 (green)
    [2] = "|cff0070dd",  -- Tier 2 (blue)
    [3] = "|cffa335ee",  -- Tier 3 (purple/heirloom)
    [4] = "|cffff8000",  -- Tier 4 (orange/legendary)
    [5] = "|cffe6cc80",  -- Tier 5 (artifact)
}

-- Build item location key for caching
local function BuildLocationKey(bag, slot)
    return string.format("%d:%d", bag or 0, slot or 0)
end

-- Convert client bag to server bag ID
local function GetServerBagFromClient(bag)
    -- Backpack is 0, other bags are 1-4 for regular, -1 for bank, 5-11 for bank bags
    if bag == 0 then return 255 end  -- INVENTORY_SLOT_BAG_0
    if bag >= 1 and bag <= 4 then return 18 + bag end  -- Regular bags (19-22)
    if bag == -1 then return 255 end  -- Bank main
    if bag >= 5 and bag <= 11 then return 62 + (bag - 5) end  -- Bank bags
    return bag
end

-- Convert client slot to server slot ID  
local function GetServerSlotFromClient(bag, slot)
    if bag == 0 then
        return 22 + slot  -- Backpack slots start at 23
    end
    return slot - 1  -- Other bags are 0-indexed on server
end

-- Cached GetItemInfo to reduce API calls
local function GetCachedItemInfo(itemLink)
    if not itemLink then return nil end
    
    local cached = itemInfoCache[itemLink]
    if cached and (GetTime() - cached.time) < ITEM_INFO_CACHE_DURATION then
        return cached.name, cached.link, cached.quality, cached.level, cached.minLevel, 
               cached.type, cached.subType, cached.stackCount, cached.equipLoc
    end
    
    local name, link, quality, level, minLevel, itemType, subType, stackCount, equipLoc = GetItemInfo(itemLink)
    if name then
        itemInfoCache[itemLink] = {
            time = GetTime(),
            name = name,
            link = link,
            quality = quality,
            level = level,
            minLevel = minLevel,
            type = itemType,
            subType = subType,
            stackCount = stackCount,
            equipLoc = equipLoc
        }
    end
    
    return name, link, quality, level, minLevel, itemType, subType, stackCount, equipLoc
end

-- Request upgrade info from server (throttled)
local lastUpgradeRequest = 0
local UPGRADE_REQUEST_THROTTLE = 0.1  -- 100ms between requests
local UPGRADE_PENDING_TTL = 10  -- give up after 10 s with no server reply

local function RequestUpgradeInfo(bag, slot)
    if not addon.protocol or not addon.protocol.connected then
        return
    end
    
    -- Throttle requests
    local now = GetTime()
    if (now - lastUpgradeRequest) < UPGRADE_REQUEST_THROTTLE then
        return
    end
    
    local serverBag = GetServerBagFromClient(bag)
    local serverSlot = GetServerSlotFromClient(bag, slot)
    local locationKey = BuildLocationKey(serverBag, serverSlot)
    
    -- Don't re-request if pending and not yet timed out
    if pendingUpgradeRequests[locationKey] then
        if (now - pendingUpgradeRequests[locationKey]) < UPGRADE_PENDING_TTL then
            return
        end
        -- Previous request timed out – retry
        pendingUpgradeRequests[locationKey] = nil
    end
    
    -- Check cache
    local cached = itemUpgradeCache[locationKey]
    if cached and (now - cached.timestamp) < UPGRADE_CACHE_DURATION then
        return
    end
    
    pendingUpgradeRequests[locationKey] = now  -- store timestamp for TTL tracking
    lastUpgradeRequest = now
    
    -- Request via protocol
    addon.protocol:RequestItemUpgradeInfo(serverBag, serverSlot)
end

-- Handle upgrade info from server
local function OnUpgradeInfoReceived(data)
    if not data then return end
    
    local locationKey = BuildLocationKey(data.bag, data.slot)
    pendingUpgradeRequests[locationKey] = nil
    
    itemUpgradeCache[locationKey] = {
        timestamp = GetTime(),
        upgradeLevel = data.upgradeLevel or 0,
        maxUpgrade = data.maxUpgrade or 0,
        tier = data.tier or 0,
        statMultiplier = data.statMultiplier or 1.0,
        baseEntry = data.baseEntry,
        currentEntry = data.currentEntry,
        baseIlvl = data.baseIlvl,
        upgradedIlvl = data.upgradedIlvl,
    }
    
    -- Don't force refresh to avoid lag cascade
    -- Data will appear on next natural tooltip update
end

-- Register for upgrade info events
addon:RegisterEvent("ITEM_UPGRADE_INFO_RECEIVED", OnUpgradeInfoReceived)

-- Add upgrade/tier info to tooltip
local function AddUpgradeInfo(tooltip, bag, slot, itemLink)
    if not addon.settings.tooltips.showUpgradeInfo then return end
    if not itemLink then return end
    
    -- Skip if DC-ItemUpgrade is handling this tooltip
    if tooltip.__dcUpgradeProcessing or tooltip._dcItemUpgradeShown then
        return
    end
    
    -- Skip if DarkChaos_ItemUpgrade addon is loaded (it has its own tooltip handling)
    if DarkChaos_ItemUpgradeFrame then
        return
    end
    
    -- Only show for armor/weapons (use cached GetItemInfo)
    local _, _, quality, _, _, itemType, _, _, equipLoc = GetCachedItemInfo(itemLink)
    if not itemType then return end  -- Item not loaded yet
    if quality == 7 then return end  -- Skip heirlooms (handled separately)
    if itemType ~= "Armor" and itemType ~= "Weapon" then return end
    if equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_QUIVER" then return end
    
    local serverBag = GetServerBagFromClient(bag)
    local serverSlot = GetServerSlotFromClient(bag, slot)
    local locationKey = BuildLocationKey(serverBag, serverSlot)
    
    -- Check cache
    local cached = itemUpgradeCache[locationKey]
    if not cached then
        -- Request from server
        RequestUpgradeInfo(bag, slot)
        return
    end
    
    -- Don't show if no upgrades possible
    if cached.maxUpgrade <= 0 and cached.upgradeLevel <= 0 then
        return
    end
    
    -- Prevent duplicate lines
    if tooltip._dcqosUpgradeShown == locationKey then
        return
    end
    tooltip._dcqosUpgradeShown = locationKey
    
    local current = cached.upgradeLevel or 0
    local maxUpgrade = cached.maxUpgrade or 0
    local tier = cached.tier or 0
    local statMultiplier = cached.statMultiplier or 1.0
    local totalBonus = (statMultiplier - 1.0) * 100
    
    -- Add separator
    tooltip:AddLine(" ")
    
    -- Show upgrade level with progress color
    local progressColor = TIER_COLORS[tier] or "|cffffcc00"
    if current >= maxUpgrade then
        progressColor = "|cff00ff00"  -- Green for maxed
    elseif current == 0 then
        progressColor = "|cff888888"  -- Gray for not upgraded
    end
    
    tooltip:AddLine(string.format("%sUpgrade Level %d / %d  Tier %d|r", progressColor, current, maxUpgrade, tier))
    
    -- Show stat bonus if upgraded
    if totalBonus > 0 then
        tooltip:AddLine(string.format("|cff00ff00+%.1f%% All Stats|r", totalBonus))
    end
    
    -- Show item level difference if available
    if cached.baseIlvl and cached.upgradedIlvl and cached.upgradedIlvl > cached.baseIlvl then
        tooltip:AddLine(string.format("|cff888888Base iLvl: %d -> Upgraded: %d|r", cached.baseIlvl, cached.upgradedIlvl))
    end
    
    -- Show current entry if different from base (indicates modified item)
    if cached.currentEntry and cached.baseEntry and cached.currentEntry ~= cached.baseEntry then
        tooltip:AddLine(string.format("|cff666666Upgraded Entry: %d|r", cached.currentEntry))
    end
end

-- Clear upgrade cache for a slot (call when item moves/changes)
local function ClearUpgradeCache(bag, slot)
    local serverBag = GetServerBagFromClient(bag)
    local serverSlot = GetServerSlotFromClient(bag, slot)
    local locationKey = BuildLocationKey(serverBag, serverSlot)
    itemUpgradeCache[locationKey] = nil
    pendingUpgradeRequests[locationKey] = nil
end

-- Export functions for other modules
Tooltips.ClearUpgradeCache = ClearUpgradeCache
Tooltips.RequestUpgradeInfo = RequestUpgradeInfo

-- ============================================================
-- Tooltip Position Anchor
-- ============================================================
local TipDrag = nil  -- Drag frame for positioning

local function CreateTipDragFrame()
    if TipDrag then return end
    
    TipDrag = CreateFrame("Frame", "DCQoSTipDrag", UIParent)
    TipDrag:SetToplevel(true)
    TipDrag:SetClampedToScreen(true)
    TipDrag:SetSize(130, 64)
    TipDrag:Hide()
    TipDrag:SetFrameStrata("TOOLTIP")
    TipDrag:SetMovable(true)
    TipDrag:EnableMouse(true)
    TipDrag:RegisterForDrag("LeftButton")
    TipDrag:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    ApplyLeaderboardsStyle(TipDrag)
    
    -- Title text
    TipDrag.text = TipDrag:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    TipDrag.text:SetPoint("CENTER", 0, 0)
    TipDrag.text:SetText("Tooltip")
    
    -- Background handled by ApplyLeaderboardsStyle
    
    -- Drag handlers
    local startX, startY
    TipDrag:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then
            startX, startY = self:GetCenter()
            self:StartMoving()
        elseif btn == "RightButton" then
            self:Hide()
        end
    end)
    
    TipDrag:SetScript("OnMouseUp", function(self, btn)
        if btn == "LeftButton" then
            self:StopMovingOrSizing()
            local endX, endY = self:GetCenter()
            local settings = addon.settings.tooltips
            settings.cursorOffsetX = (settings.cursorOffsetX or 0) + (endX - startX)
            settings.cursorOffsetY = (settings.cursorOffsetY or 0) + (endY - startY)
            addon:SaveSettings()
        end
    end)
end

-- ============================================================
-- Tooltip Anchor Positioning
-- ============================================================
local function SetTooltipAnchor()
    if addon._dcqosTooltipAnchorHooked then
        return
    end

    if type(GameTooltip_SetDefaultAnchor) ~= "function" then
        return
    end

    addon._dcqosTooltipAnchorHooked = true
    local origGameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
    GameTooltip_SetDefaultAnchor = function(tooltip, parent)
        local settings = addon.settings and addon.settings.tooltips or {}
        local anchor = settings.anchor or 1
        
        if anchor == 1 then
            -- Default positioning
            origGameTooltip_SetDefaultAnchor(tooltip, parent)
        elseif anchor == 2 then
            -- Fixed overlay position
            origGameTooltip_SetDefaultAnchor(tooltip, parent) -- Set owner/default first
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 
                settings.cursorOffsetX or -13, 
                settings.cursorOffsetY or 94)
        elseif anchor == 3 then
            -- Cursor attached
            tooltip:SetOwner(parent, "ANCHOR_CURSOR")
        elseif anchor == 4 then
            -- Cursor right with offset (Use ANCHOR_CURSOR with offsets)
            tooltip:SetOwner(parent, "ANCHOR_CURSOR", 
                settings.cursorOffsetX or 0, 
                settings.cursorOffsetY or 0)
        end
    end
end

-- ============================================================
-- Tooltip Scale
-- ============================================================
local function SetTooltipScale()
    local settings = addon.settings.tooltips
    local scale = settings.scale or 1.0
    
    -- Apply scale to various tooltip frames
    local tooltipFrames = {
        GameTooltip,
        FriendsTooltip,
        ItemRefTooltip,
        ItemRefShoppingTooltip1,
        ItemRefShoppingTooltip2,
        ShoppingTooltip1,
        ShoppingTooltip2,
        AutoCompleteBox,
    }
    
    for _, frame in ipairs(tooltipFrames) do
        if frame then
            frame:SetScale(scale)
        end
    end
    
    if TipDrag then
        TipDrag:SetScale(scale)
    end
end

-- ============================================================
-- Item ID in Tooltips
-- ============================================================
local function AddItemId(tooltip, itemLink)
    if not addon.settings.tooltips.showItemId then return end
    if not itemLink then return end
    
    -- Extract item ID from link
    local itemId = itemLink:match("item:(%d+)")
    if itemId then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Item ID:", "|cffffffff" .. itemId .. "|r", 0.5, 0.5, 0.5)
    end
end

-- ============================================================
-- Item Level in Tooltips
-- ============================================================
local function AddItemLevel(tooltip, itemLink)
    if not addon.settings.tooltips.showItemLevel then return end
    if not itemLink then return end

    local localizedItemLevelToken = ITEM_LEVEL and ITEM_LEVEL:gsub("%%d", "") or ""
    localizedItemLevelToken = localizedItemLevelToken:gsub("^%s+", ""):gsub("%s+$", "")

    -- If the tooltip already shows item level (client or another addon), don't add a duplicate.
    local tipName = tooltip and tooltip.GetName and tooltip:GetName()
    if tipName and tooltip.NumLines then
        for i = 1, tooltip:NumLines() do
            local left = _G[tipName .. "TextLeft" .. i]
            if left and left.GetText then
                local text = left:GetText()
                if text then
                    -- Keep this intentionally simple: WotLK strings are typically "Item Level".
                    if string.find(text, "Item Level", 1, true)
                        or (localizedItemLevelToken ~= "" and string.find(text, localizedItemLevelToken, 1, true)) then
                        return
                    end
                end
            end
        end
    end
    
    local _, _, _, itemLevel = GetCachedItemInfo(itemLink)
    if itemLevel and itemLevel > 0 then
        tooltip:AddDoubleLine("Item Level:", "|cffffffff" .. itemLevel .. "|r", 0.5, 0.5, 0.5)
    end
end

-- ============================================================
-- Spell ID in Tooltips
-- ============================================================
local function AddSpellId(tooltip, spellId)
    if not addon.settings.tooltips.showSpellId then return end
    if not spellId then return end

    -- Prevent duplicates when multiple hooks fire for the same tooltip.
    local sid = tonumber(spellId)
    if not sid then return end
    if tooltip._dcqosSpellIdShown == sid then
        return
    end
    tooltip._dcqosSpellIdShown = sid
    
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("Spell ID:", "|cffffffff" .. sid .. "|r", 0.5, 0.5, 0.5)
end

local SPELL_TOOLTIP_CONTEXT_SEED = 2166136261
local SPELL_TOOLTIP_CONTEXT_PRIME = 16777619
local SPELL_TOOLTIP_HASH_MOD = 4294967296
local SPELL_TOOLTIP_ENRICHMENT_OK_TTL = 300 -- 5 min; data is semi-static (rank/cast/range)
local SPELL_TOOLTIP_ENRICHMENT_ERR_TTL = 6
local SPELL_TOOLTIP_ENRICHMENT_PENDING_TTL = 1.5

local spellEnrichmentRequestCounter = 0
local pendingSpellEnrichment = {}

local function BuildSpellEnrichmentKey(spellId, contextHash)
    return tostring(tonumber(spellId) or 0) .. ":" .. tostring(tonumber(contextHash) or 0)
end

local function MixSpellTooltipContext(hash, value)
    hash = (hash + (tonumber(value) or 0)) % SPELL_TOOLTIP_HASH_MOD
    -- Lua 5.1 doubles can only represent integers exactly up to 2^53.
    -- hash (up to 2^32-1) * prime (~2^24) = product up to ~2^56, which exceeds
    -- 2^53 and loses precision.  Use 16-bit halves to keep each intermediate
    -- product under 2^41, which is safely representable:
    --   hash = hi*2^16 + lo
    --   (hash * prime) mod 2^32
    --     = ((hi*prime mod 2^16)*2^16 + lo*prime) mod 2^32
    local lo = hash % 65536
    local hi = math.floor(hash / 65536)
    hash = (((hi * SPELL_TOOLTIP_CONTEXT_PRIME) % 65536) * 65536
            + lo * SPELL_TOOLTIP_CONTEXT_PRIME) % SPELL_TOOLTIP_HASH_MOD
    return hash
end

local function BuildSpellTooltipContextHash(spellId)
    local hash = SPELL_TOOLTIP_CONTEXT_SEED
    local _, _, classId = UnitClass("player")

    hash = MixSpellTooltipContext(hash, spellId)
    hash = MixSpellTooltipContext(hash, UnitLevel("player") or 0)
    hash = MixSpellTooltipContext(hash, classId or 0)
    hash = MixSpellTooltipContext(hash, (GetShapeshiftForm and GetShapeshiftForm()) or 0)
    hash = MixSpellTooltipContext(hash, (GetActiveTalentGroup and GetActiveTalentGroup()) or 0)

    if hash == 0 then
        hash = 1
    end

    return hash
end

local function NextSpellEnrichmentRequestId()
    spellEnrichmentRequestCounter = spellEnrichmentRequestCounter + 1
    if spellEnrichmentRequestCounter > 2147483000 then
        spellEnrichmentRequestCounter = 1
    end
    return spellEnrichmentRequestCounter
end

-- Helpers used by AddSpellTooltipEnrichmentPayload.
-- Defined at module scope so they are not re-created as closures on every call.
local function NormalizeTooltipText(text)
    local value = tostring(text or "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("|T.-|t", "")
    value = value:gsub("%s+", " ")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return string.lower(value)
end

local function ClassifySpellTooltipLine(leftText, rightText)
    local leftNorm = NormalizeTooltipText(leftText)
    local rightNorm = NormalizeTooltipText(rightText)
    local merged = NormalizeTooltipText((leftText or "") .. " " .. (rightText or ""))

    if merged == "" then
        return nil
    end

    if leftNorm == "spell id:" then
        return "spell-id"
    end

    if leftNorm == "server:" or merged:find("^server:") then
        return "server-meta"
    end

    if leftNorm == "spell" then
        return "spell-meta"
    end

    if merged == "instant cast" or merged:find(" sec cast$") or merged:find(" min cast$") then
        return "cast"
    end

    if merged:find(" yd range$") then
        return "range"
    end

    if leftNorm == "cooldown" or merged:find(" cooldown$") then
        return "cooldown"
    end

    if leftNorm == "duration" or merged:find(" duration$") then
        return "duration"
    end

    if merged:find(" mana$") or merged:find(" rage$") or merged:find(" focus$")
        or merged:find(" energy$") or merged:find(" happiness$")
        or merged:find(" rune$") or merged:find(" runic power$")
        or merged:find(" health$") then
        return "cost"
    end

    if merged:find("^rank ") or merged == "passive" then
        return "rank"
    end

    return nil
end

local function BuildTooltipLineRefs(frame)
    local refs = {}
    if type(frame.GetName) ~= "function" or type(frame.NumLines) ~= "function" then
        return refs
    end

    local tipName = frame:GetName()
    if not tipName or tipName == "" then
        return refs
    end

    for i = 1, frame:NumLines() do
        local leftLine = _G[tipName .. "TextLeft" .. i]
        local rightLine = _G[tipName .. "TextRight" .. i]
        local leftText = leftLine and leftLine.GetText and leftLine:GetText() or ""
        local rightText = rightLine and rightLine.GetText and rightLine:GetText() or ""

        refs[#refs + 1] = {
            index = i,
            leftLine = leftLine,
            rightLine = rightLine,
            leftText = leftText,
            rightText = rightText,
            category = ClassifySpellTooltipLine(leftText, rightText),
        }
    end

    return refs
end

local function FindTooltipLineByCategory(lineRefs, category)
    if not category then
        return nil
    end

    for _, ref in ipairs(lineRefs) do
        if ref.category == category then
            return ref
        end
    end

    return nil
end

local function IsSpellTooltipBodyLine(ref)
    if type(ref) ~= "table" then
        return false
    end

    if ref.index == 1 or ref.category ~= nil then
        return false
    end

    local leftNorm = NormalizeTooltipText(ref.leftText)
    local rightNorm = NormalizeTooltipText(ref.rightText)
    if leftNorm == "" or rightNorm ~= "" then
        return false
    end

    if leftNorm:find("^requires ") or leftNorm:find("^reagents:")
        or leftNorm:find("^tools:") or leftNorm:find("^chance on hit:") then
        return false
    end

    return true
end

local function FindNextTooltipBodyLine(lineRefs, startIndex)
    local index = tonumber(startIndex) or 1
    for i = index, #lineRefs do
        local ref = lineRefs[i]
        if IsSpellTooltipBodyLine(ref) then
            return ref, i + 1
        end
    end

    return nil, index
end

local function SetTooltipLineTextColor(fontString, r, g, b)
    if fontString and fontString.SetTextColor then
        fontString:SetTextColor(r or 0.8, g or 0.8, b or 0.8)
    end
end

local function ReplaceTooltipLine(ref, leftText, rightText, r, g, b)
    if not ref or not ref.leftLine or type(ref.leftLine.SetText) ~= "function" then
        return false
    end

    ref.leftLine:SetText(leftText or "")
    SetTooltipLineTextColor(ref.leftLine, r, g, b)

    if ref.rightLine and ref.rightLine.SetText then
        ref.rightLine:SetText(rightText or "")
        SetTooltipLineTextColor(ref.rightLine, r, g, b)
    end

    ref.leftText = leftText or ""
    ref.rightText = rightText or ""
    ref.category = ClassifySpellTooltipLine(leftText, rightText)
    return true
end

local function GetSpellBodyWrapWidth()
    local parentWidth = 1024
    if UIParent and UIParent.GetWidth then
        local w = UIParent:GetWidth()
        if type(w) == "number" and w > 0 then
            parentWidth = w
        end
    end

    -- Keep spell tooltips compact on all resolutions.
    local dynamicWidth = math.floor(parentWidth * 0.17)
    if dynamicWidth < 180 then dynamicWidth = 180 end
    if dynamicWidth > 260 then dynamicWidth = 260 end
    return dynamicWidth
end

local function WrapSpellTooltipBodyLines(tooltip)
    if not tooltip or type(tooltip.GetName) ~= "function" or type(tooltip.NumLines) ~= "function" then
        return
    end

    local wrapWidth = GetSpellBodyWrapWidth()
    local refs = BuildTooltipLineRefs(tooltip)
    for _, ref in ipairs(refs) do
        if IsSpellTooltipBodyLine(ref) and ref.leftLine then
            if ref.leftLine.SetWidth then
                ref.leftLine:SetWidth(wrapWidth)
            end
            if ref.leftLine.SetWordWrap then
                ref.leftLine:SetWordWrap(true)
            end
        end
    end
end

local function NormalizeSpellEnrichmentEntry(entry)
    local left = tostring(entry.left or "")
    local right = entry.right ~= nil and tostring(entry.right) or nil
    local leftNorm = NormalizeTooltipText(left)

    if leftNorm == "server:" or leftNorm == "spell" then
        return nil
    end

    if leftNorm == "cooldown" and right and right ~= "" then
        left = right .. " cooldown"
        right = nil
    elseif leftNorm == "duration" and right and right ~= "" then
        left = right .. " duration"
        right = nil
    end

    return {
        left = left,
        right = right,
        r = tonumber(entry.r),
        g = tonumber(entry.g),
        b = tonumber(entry.b),
        kind = entry.kind,
    }
end

local function BuildExistingTooltipLineSet(frame)
    local existing = {}
    if type(frame.GetName) ~= "function" or type(frame.NumLines) ~= "function" then
        return existing
    end

    local tipName = frame:GetName()
    if not tipName or tipName == "" then
        return existing
    end

    for i = 1, frame:NumLines() do
        local leftLine = _G[tipName .. "TextLeft" .. i]
        local rightLine = _G[tipName .. "TextRight" .. i]
        local leftText = leftLine and leftLine.GetText and leftLine:GetText() or ""
        local rightText = rightLine and rightLine.GetText and rightLine:GetText() or ""

        local leftNorm = NormalizeTooltipText(leftText)
        local rightNorm = NormalizeTooltipText(rightText)

        if leftNorm ~= "" then
            existing[leftNorm] = true
        end
        if rightNorm ~= "" then
            existing[rightNorm] = true
        end
        if leftNorm ~= "" or rightNorm ~= "" then
            existing[leftNorm .. "||" .. rightNorm] = true
        end
    end

    return existing
end

local function IsRawServerMetadata(text)
    local norm = NormalizeTooltipText(text)
    if norm == "" then return false end
    if norm:find("^server%-v%d") then return true end
    if norm:find("ctx=") and norm:find("spell=") then return true end
    return false
end

local function AddSpellTooltipEnrichmentPayload(tooltip, enrichment)
    if not tooltip or type(enrichment) ~= "table" then return false end
    if type(tooltip.AddLine) ~= "function" then return false end

    local existingLines = BuildExistingTooltipLineSet(tooltip)
    local lineRefs = BuildTooltipLineRefs(tooltip)

    local lines = enrichment.lines
    local lineColor = enrichment.lineColor or "|cff9bd0ff"

    if type(lines) ~= "table" or #lines == 0 then
        local line = tostring(enrichment.line or "")
        if line == "" then
            return false
        end

        if IsRawServerMetadata(line) then
            -- Avoid rendering transport metadata that causes very wide tooltips.
            return false
        end

        tooltip:AddLine(" ")
        tooltip:AddLine(lineColor .. line .. "|r", 0.5, 0.7, 1.0, true)
        return true
    end

    local addedAny = false
    local nextBodyLineIndex = 1

    for index, entry in ipairs(lines) do
        local entryData = entry
        if type(entryData) ~= "table" then
            entryData = { left = tostring(entryData or "") }
        end

        local left = ""
        local right = nil
        local r = nil
        local g = nil
        local b = nil

        entryData = NormalizeSpellEnrichmentEntry(entryData)
        if not entryData then
            left = ""
            right = nil
        else
            left = tostring(entryData.left or "")
            right = entryData.right ~= nil and tostring(entryData.right) or nil
            r = tonumber(entryData.r)
            g = tonumber(entryData.g)
            b = tonumber(entryData.b)
        end

        local leftNorm = NormalizeTooltipText(left)
        local rightNorm = NormalizeTooltipText(right or "")
        local category = ClassifySpellTooltipLine(left, right)
        local kind = entryData and entryData.kind or nil

        if IsRawServerMetadata(left) or IsRawServerMetadata(right or "") then
            -- Skip raw payload line such as "server-v1 spell=... ctx=...".
            left = ""
            right = nil
            leftNorm = ""
            rightNorm = ""
            category = nil
        end

        local isDuplicate = false
        if right and right ~= "" then
            if existingLines[leftNorm .. "||" .. rightNorm] then
                isDuplicate = true
            end
        elseif leftNorm ~= "" and existingLines[leftNorm] then
            isDuplicate = true
        end

        if not isDuplicate and leftNorm ~= "" then
            if leftNorm == "spell" or leftNorm == "duration" or leftNorm == "summon" then
                isDuplicate = true
            end
        end

        if not isDuplicate and kind == "body" then
            local existingRef
            existingRef, nextBodyLineIndex = FindNextTooltipBodyLine(lineRefs, nextBodyLineIndex)
            if existingRef and ReplaceTooltipLine(existingRef, left, right, r, g, b) then
                addedAny = true
                isDuplicate = true
            end
        end

        if not isDuplicate and category then
            local existingRef = FindTooltipLineByCategory(lineRefs, category)
            if existingRef then
                if ReplaceTooltipLine(existingRef, left, right, r, g, b) then
                    addedAny = true
                    existingLines[leftNorm] = leftNorm ~= "" and true or existingLines[leftNorm]
                    if right and right ~= "" then
                        existingLines[rightNorm] = rightNorm ~= "" and true or existingLines[rightNorm]
                        existingLines[leftNorm .. "||" .. rightNorm] = true
                    end
                end
                isDuplicate = true
            end
        end

        local shouldRender = not isDuplicate or (index == 1 and leftNorm == "")
        if shouldRender then
            if index == 1 and left == "" then
                left = " "
            end

            if right and right ~= "" and type(tooltip.AddDoubleLine) == "function" then
                if not addedAny then
                    tooltip:AddLine(" ")
                end
                tooltip:AddDoubleLine(left ~= "" and left or " ", right, r or 0.5, g or 0.7, b or 1.0)
                addedAny = true
                existingLines[leftNorm .. "||" .. rightNorm] = true
            elseif left ~= "" then
                if not addedAny then
                    tooltip:AddLine(" ")
                end
                tooltip:AddLine(left, r or 0.8, g or 0.8, b or 0.8, true)
                addedAny = true
                existingLines[leftNorm] = true
            end
        end
    end

    WrapSpellTooltipBodyLines(tooltip)

    return addedAny
end

local function AddSpellTooltipEnrichment(tooltip, spellId)
    if not tooltip or not spellId then return end
    if not addon.settings or not addon.settings.tooltips or not addon.settings.tooltips.enabled then return end
    if not addon.settings.communication or not addon.settings.communication.enabled then return end
    if not addon.protocol or not addon.protocol.connected then return end

    local sid = tonumber(spellId)
    if not sid or sid <= 0 then return end

    local contextHash = BuildSpellTooltipContextHash(sid)
    local key = BuildSpellEnrichmentKey(sid, contextHash)
    local now = GetTime()

    tooltip._dcqosActiveSpellKey = key

    if tooltip._dcqosSpellEnrichmentShownKey == key then
        return
    end

    local cached = addon.GetSpellTooltipEnrichment and addon:GetSpellTooltipEnrichment(sid, contextHash) or nil
    local cachedAge = cached and (now - (tonumber(cached.receivedAt) or now)) or nil

    local lineText = nil
    local lineColor = "|cff9bd0ff"
    local enrichmentPayload = nil

    if cached and cached.status == 0 and cached.line and cached.line ~= "" and cachedAge and cachedAge <= SPELL_TOOLTIP_ENRICHMENT_OK_TTL then
        lineText = cached.line
        enrichmentPayload = cached
    elseif cached and cached.status == 0 and type(cached.lines) == "table" and cachedAge and cachedAge <= SPELL_TOOLTIP_ENRICHMENT_OK_TTL then
        enrichmentPayload = cached
    elseif cached and cached.status and cached.status ~= 0 and cachedAge and cachedAge <= SPELL_TOOLTIP_ENRICHMENT_ERR_TTL then
        lineColor = "|cff888888"
        if cached.status == 1 then
            lineText = "Spell enrichment unavailable"
        elseif cached.status == 2 then
            lineText = "Spell enrichment request invalid"
        elseif cached.status == 3 then
            lineText = "No additional server details"
        else
            lineText = "Spell enrichment unavailable"
        end
    end

    if not lineText then
        local pending = pendingSpellEnrichment[key]
        if pending and (now - (pending.sentAt or 0)) > SPELL_TOOLTIP_ENRICHMENT_PENDING_TTL then
            pendingSpellEnrichment[key] = nil
            pending = nil
        end

        if not pending then
            local requestId = NextSpellEnrichmentRequestId()
            pendingSpellEnrichment[key] = {
                requestId = requestId,
                sentAt = now,
            }

            local ok = addon:RequestSpellTooltipEnrichment(requestId, sid, contextHash, false)
            if not ok then
                pendingSpellEnrichment[key] = nil
            end
        end
        return
    end

    if enrichmentPayload then
        enrichmentPayload.lineColor = lineColor
        AddSpellTooltipEnrichmentPayload(tooltip, enrichmentPayload)
    else
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Server:", lineColor .. lineText .. "|r", 0.5, 0.7, 1.0)
    end
    tooltip._dcqosSpellEnrichmentShownKey = key
end

local function OnSpellTooltipEnrichmentReceived(data)
    if type(data) ~= "table" then return end

    local sid = tonumber(data.spellId) or 0
    local contextHash = tonumber(data.contextHash) or 0
    if sid <= 0 or contextHash <= 0 then return end

    local key = BuildSpellEnrichmentKey(sid, contextHash)
    local pending = pendingSpellEnrichment[key]
    if pending then
        local responseReqId = tonumber(data.requestId) or 0
        if responseReqId > 0 and responseReqId ~= pending.requestId then
            return
        end
        pendingSpellEnrichment[key] = nil
    end

    if GameTooltip and GameTooltip:IsShown() and GameTooltip._dcqosActiveSpellKey == key then
        if GameTooltip._dcqosSpellEnrichmentShownKey ~= key then
            AddSpellTooltipEnrichment(GameTooltip, sid)
            GameTooltip:Show()
        end
    end
end

addon:RegisterEvent("SPELL_TOOLTIP_ENRICHMENT_RECEIVED", OnSpellTooltipEnrichmentReceived)

local function EnhanceSpellTooltip(tooltip, spellId)
    AddSpellId(tooltip, spellId)
    AddSpellTooltipEnrichment(tooltip, spellId)
    WrapSpellTooltipBodyLines(tooltip)
end

-- ============================================================
-- NPC ID in Tooltips (with DB GUID from server)
-- ============================================================
local npcInfoCache = {}       -- Cache server-provided NPC info
local pendingNpcRequests = {} -- Track pending requests
local killTrackerFrame = nil

-- Parse NPC IDs from GUID (3.3.5a format)
local function ParseNpcFromGuid(guid)
    if not guid or type(guid) ~= "string" then
        return nil, nil
    end
    
    -- Handle 3.3.5a Hex GUIDs (e.g., 0xF130001234005678)
    if guid:find("^0x") then
        local hex = guid:sub(3)
        if #hex >= 12 then
            -- 3.3.5a Layout: High(variable) - Entry(24 bits) - Low(24 bits)
            -- Last 6 chars = Low GUID (Spawn ID)
            -- Previous 6 chars = Entry ID
            local spawnHex = hex:sub(-6)
            local entryHex = hex:sub(-12, -7)
            local highHex = hex:sub(1, -13)
            
            -- Check for Creature (F130), Vehicle (F150), or Pet (F140)
            if highHex:find("^F1") then
                local entry = tonumber(entryHex, 16)
                local spawnId = tonumber(spawnHex, 16)
                return entry, spawnId
            end
        end
    end
    
    -- Fallback: string-based parsing (Creature-0-0000-0-0000-Entry-SpawnId)
    local parts = {}
    for token in string.gmatch(guid, "[^%-]+") do
        parts[#parts + 1] = token
    end
    
    local unitType = parts[1]
    if unitType ~= "Creature" and unitType ~= "Vehicle" and unitType ~= "Pet" then
        return nil, nil
    end
    
    local entry = tonumber(parts[#parts - 1])
    local spawnHex = parts[#parts]
    local spawnId = tonumber(spawnHex, 16) or tonumber(spawnHex)
    
    return entry, spawnId
end

local function NormalizeNpcName(name)
    name = tostring(name or "")
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    name = name:gsub("|T.-|t", "")
    return string.lower(name)
end

local function GetKillStores()
    if addon and addon.db and addon.db.npcKillStats then
        local stats = addon.db.npcKillStats
        local account = stats.account
        local charKey = addon.GetCharacterKey and addon:GetCharacterKey() or (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Unknown")
        local character = stats.characters and stats.characters[charKey]
        if not account then
            account = { byEntry = {}, byName = {}, nameByEntry = {} }
            stats.account = account
        end
        if not stats.characters then
            stats.characters = {}
        end
        if not character then
            character = { byEntry = {}, byName = {}, nameByEntry = {} }
            stats.characters[charKey] = character
        end
        return account, character
    end
    return nil, nil
end

local function CacheNpcNameByEntry(entry, name)
    if not entry or not name or name == "" then return end
    local account, character = GetKillStores()
    if not account or not character then return end
    account.nameByEntry[entry] = name
    character.nameByEntry[entry] = name
end

local function IncrementNpcKill(entry, name)
    local account, character = GetKillStores()
    if not account or not character then
        return
    end

    if entry then
        account.byEntry[entry] = (account.byEntry[entry] or 0) + 1
        character.byEntry[entry] = (character.byEntry[entry] or 0) + 1
        if name and name ~= "" then
            account.nameByEntry[entry] = name
            character.nameByEntry[entry] = name
        end
    end

    if name and name ~= "" then
        local key = NormalizeNpcName(name)
        if key ~= "" then
            account.byName[key] = (account.byName[key] or 0) + 1
            character.byName[key] = (character.byName[key] or 0) + 1
        end
    end
end

local function GetNpcKillCounts(entry, name)
    local account, character = GetKillStores()
    if not account or not character then
        return 0, 0
    end

    local key = (name and name ~= "") and NormalizeNpcName(name) or nil

    local charCount = 0
    local acctCount = 0

    if entry then
        charCount = character.byEntry[entry] or 0
        acctCount = account.byEntry[entry] or 0
    elseif key and key ~= "" then
        charCount = character.byName[key] or 0
        acctCount = account.byName[key] or 0
    end

    return charCount, acctCount
end

local function HandleCombatLogEvent(...)
    if not addon.settings.tooltips.showNpcKillCount then
        return
    end

    local subevent = select(2, ...)
    if subevent ~= "PARTY_KILL" then
        return
    end

    local sourceGUID, sourceName, sourceFlags
    local destGUID, destName, destFlags

    -- 3.3.5a layout: timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags
    -- Modern layout: timestamp, subevent, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags
    if type(select(3, ...)) == "boolean" then
        sourceGUID = select(4, ...)
        sourceName = select(5, ...)
        sourceFlags = select(6, ...)
        destGUID = select(8, ...)
        destName = select(9, ...)
        destFlags = select(10, ...)
    else
        sourceGUID = select(3, ...)
        sourceName = select(4, ...)
        sourceFlags = select(5, ...)
        destGUID = select(6, ...)
        destName = select(7, ...)
        destFlags = select(8, ...)
    end

    if not destGUID then return end

    local playerGUID = UnitGUID("player")
    local petGUID = UnitGUID("pet")
    local vehicleGUID = UnitGUID("vehicle")

    local isMine = (sourceGUID and (sourceGUID == playerGUID or sourceGUID == petGUID or sourceGUID == vehicleGUID))
    if not isMine and sourceFlags and COMBATLOG_OBJECT_AFFILIATION_MINE and bit and bit.band then
        isMine = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0)
    end
    if not isMine and sourceName then
        local playerName = UnitName("player")
        local petName = UnitName("pet")
        local vehicleName = UnitName("vehicle")
        if (playerName and sourceName == playerName)
            or (petName and sourceName == petName)
            or (vehicleName and sourceName == vehicleName) then
            isMine = true
        end
    end
    if not isMine then return end

    local entry = ParseNpcFromGuid(destGUID)
    IncrementNpcKill(entry, destName)
end

-- NPC info request pending state: stores the timestamp the request was sent.
-- Cleared on response or after NPC_PENDING_TTL seconds (prevents "Fetching..." forever).
local NPC_PENDING_TTL = 8

-- Request NPC info from server
local function RequestNpcInfo(guid)
    if not guid then return end
    local now = GetTime()
    -- Re-allow if previous request timed out
    if pendingNpcRequests[guid] and (now - pendingNpcRequests[guid]) < NPC_PENDING_TTL then
        return
    end
    if npcInfoCache[guid] then return end

    pendingNpcRequests[guid] = now

    -- Use DC-QoS protocol to request NPC info
    if addon.protocol and addon.protocol.connected then
        addon.protocol:RequestNpcInfo(guid)
    end
end

-- Handle NPC info received from server
local function OnNpcInfoReceived(npcData)
    if not npcData or not npcData.guid then return end
    
    local guid = npcData.guid
    -- Normalize GUID to match UnitGUID format (0x prefix)
    if string.sub(guid, 1, 2) ~= "0x" then
        guid = "0x" .. guid
    end
    
    pendingNpcRequests[guid] = nil
    npcInfoCache[guid] = {
        spawnId = npcData.spawnId,
        entry = npcData.entry,
        dbGuid = npcData.dbGuid,
    }
    
    -- Don't force refresh to avoid lag
    -- Data will appear on next natural tooltip update
end

-- Register for NPC info events
addon:RegisterEvent("NPC_INFO_RECEIVED", OnNpcInfoReceived)

local function AddNpcId(tooltip, unit)
    if not addon.settings.tooltips.showNpcId then return end
    if not unit then return end
    if UnitIsPlayer(unit) then return end
    
    local guid = UnitGUID(unit)
    if not guid then return end
    
    -- Avoid duplicate lines
    if tooltip._dcqosNpcGuid == guid then return end
    tooltip._dcqosNpcGuid = guid
    
    -- Parse local NPC info
    local entry, localSpawnId = ParseNpcFromGuid(guid)
    local unitName = UnitName(unit)
    if entry and unitName then
        CacheNpcNameByEntry(entry, unitName)
    end
    
    -- Check server cache for more accurate info
    local cachedInfo = npcInfoCache[guid]
    local dbGuid = nil
    
    if cachedInfo then
        if cachedInfo.entry then entry = cachedInfo.entry end
        if cachedInfo.spawnId then localSpawnId = cachedInfo.spawnId end
        dbGuid = cachedInfo.dbGuid or cachedInfo.spawnId
    else
        -- Request from server
        RequestNpcInfo(guid)
    end
    
    -- Add separator
    tooltip:AddLine(" ")
    
    -- Show Entry ID
    if entry then
        tooltip:AddDoubleLine("Entry:", "|cffffffff" .. entry .. "|r", 0.5, 0.5, 0.5)
    end
    
    -- Show Spawn (from server or parsed)
    local isPending = pendingNpcRequests[guid] and (GetTime() - pendingNpcRequests[guid]) < NPC_PENDING_TTL
    if dbGuid then
        tooltip:AddDoubleLine("Spawn:", "|cffffffff" .. dbGuid .. "|r", 0.5, 0.5, 0.5)
    elseif isPending then
        tooltip:AddDoubleLine("Spawn:", "|cff888888Fetching...|r", 0.5, 0.5, 0.5)
    elseif localSpawnId then
        tooltip:AddDoubleLine("Spawn:", "|cffffff88~" .. localSpawnId .. "|r", 0.5, 0.5, 0.5)
    end
    
    -- Show raw GUID if debug mode
    if addon.settings.communication and addon.settings.communication.debugMode then
        tooltip:AddDoubleLine("GUID:", "|cff666666" .. guid .. "|r", 0.3, 0.3, 0.3)
    end
end

local function AddNpcKillCount(tooltip, unit)
    if not addon.settings.tooltips.showNpcKillCount then return end
    if not unit then return end
    if UnitIsPlayer(unit) then return end

    local canAttack = UnitCanAttack("player", unit)
    local reaction = UnitReaction(unit, "player")
    if not canAttack and (reaction == nil or reaction >= 5) then
        return
    end

    local guid = UnitGUID(unit)
    if not guid then return end

    local entry = ParseNpcFromGuid(guid)
    local name = UnitName(unit)
    local charCount, acctCount = GetNpcKillCounts(entry, name)

    local key = entry or name or guid
    if tooltip._dcqosNpcKillShown == key then return end
    tooltip._dcqosNpcKillShown = key

    tooltip:AddDoubleLine("Kills (Char):", "|cffffffff" .. tostring(charCount or 0) .. "|r", 0.5, 0.5, 0.5)
    tooltip:AddDoubleLine("Kills (Account):", "|cffffffff" .. tostring(acctCount or 0) .. "|r", 0.5, 0.5, 0.5)
end

-- ============================================================
-- Unit Tooltip Enhancement
-- ============================================================
local function EnhanceUnitTooltip(tooltip, unit)
    local settings = addon.settings.tooltips
    if not settings.enabled then return end
    
    -- Hide in combat if enabled
    if settings.hideInCombat and UnitAffectingCombat("player") then
        if not settings.showWithShift or not IsShiftKeyDown() then
            tooltip:Hide()
            return
        end
    end
    
    local name = UnitName(unit)
    local isPlayer = UnitIsPlayer(unit)

    -- Show NPC ID for non-players
    if not isPlayer then
        AddNpcId(tooltip, unit)
        AddNpcKillCount(tooltip, unit)
    end
    
    -- Show target if enabled
    if settings.showTarget then
        local target = unit .. "target"
        if UnitExists(target) then
            local targetName = UnitName(target)
            local targetReaction = UnitReaction(target, "player")
            
            local targetColor = "|cffffffff"
            if UnitIsUnit(target, "player") then
                targetColor = "|cffff0000"
                targetName = ">> YOU <<"
            elseif targetReaction then
                if targetReaction >= 5 then
                    targetColor = "|cff00ff00"  -- Friendly
                elseif targetReaction <= 2 then
                    targetColor = "|cffff0000"  -- Hostile
                else
                    targetColor = "|cffffff00"  -- Neutral
                end
            end
            
            tooltip:AddLine(" ")
            tooltip:AddDoubleLine("Target:", targetColor .. (targetName or "Unknown") .. "|r", 0.5, 0.5, 0.5)
        end
    end
    
    tooltip:Show()
end

-- ============================================================
-- Item Tooltip Hooks
-- ============================================================
local function HookItemTooltips()
    local function AddItemTooltipDetails(self, itemLink)
        if not itemLink then
            return
        end

        AddItemId(self, itemLink)
        AddItemLevel(self, itemLink)
        self:Show()
    end

    local function HookTooltipMethodOnce(flagName, methodName, handler)
        if GameTooltip[flagName] then
            return
        end
        if not hooksecurefunc or not GameTooltip[methodName] then
            return
        end

        GameTooltip[flagName] = true
        hooksecurefunc(GameTooltip, methodName, handler)
    end

    HookTooltipMethodOnce("_dcqosHookedSetBagItem", "SetBagItem", function(self, bag, slot, ...)
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
            AddItemTooltipDetails(self, itemLink)
            AddUpgradeInfo(self, bag, slot, itemLink)
        end
    end)

    HookTooltipMethodOnce("_dcqosHookedSetInventoryItem", "SetInventoryItem", function(self, unit, slot, ...)
        local itemLink = GetInventoryItemLink(unit, slot)
        if itemLink then
            AddItemTooltipDetails(self, itemLink)
            if unit == "player" then
                AddUpgradeInfo(self, -2, slot, itemLink)  -- -2 = equipment
            end
        end
    end)

    HookTooltipMethodOnce("_dcqosHookedSetHyperlink", "SetHyperlink", function(self, link, ...)
        if link and link:find("item:") then
            AddItemTooltipDetails(self, link)
        elseif link and link:find("spell:") then
            local spellId = link:match("spell:(%d+)")
            EnhanceSpellTooltip(self, spellId)
            self:Show()
        end
    end)

    HookTooltipMethodOnce("_dcqosHookedSetMerchantItem", "SetMerchantItem", function(self, slot, ...)
        AddItemTooltipDetails(self, GetMerchantItemLink(slot))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetLootItem", "SetLootItem", function(self, slot, ...)
        AddItemTooltipDetails(self, GetLootSlotLink(slot))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetQuestItem", "SetQuestItem", function(self, questType, slot, ...)
        AddItemTooltipDetails(self, GetQuestItemLink(questType, slot))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetQuestLogItem", "SetQuestLogItem", function(self, questType, slot, ...)
        AddItemTooltipDetails(self, GetQuestLogItemLink(questType, slot))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetAuctionItem", "SetAuctionItem", function(self, auctionType, index, ...)
        AddItemTooltipDetails(self, GetAuctionItemLink(auctionType, index))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetCraftItem", "SetCraftItem", function(self, skill, slot, ...)
        AddItemTooltipDetails(self, GetCraftItemLink(slot))
    end)

    HookTooltipMethodOnce("_dcqosHookedSetTradeSkillItem", "SetTradeSkillItem", function(self, skill, slot, ...)
        local itemLink
        if slot then
            itemLink = GetTradeSkillReagentItemLink(skill, slot)
        else
            itemLink = GetTradeSkillItemLink(skill)
        end
        AddItemTooltipDetails(self, itemLink)
    end)
    
    addon:Debug("Item tooltip hooks installed")
end

-- ============================================================
-- Unit Tooltip Hooks
-- ============================================================
local function HookUnitTooltips()
    if GameTooltip._dcqosHookedOnTooltipSetUnit and GameTooltip._dcqosHookedOnTooltipCleared then
        return
    end

    -- Hook OnTooltipSetUnit
    if not GameTooltip._dcqosHookedOnTooltipSetUnit then
        GameTooltip._dcqosHookedOnTooltipSetUnit = true
        GameTooltip:HookScript("OnTooltipSetUnit", function(self)
            local _, unit = self:GetUnit()

            -- Fallback: mouseover when GetUnit returns nil
            if not unit or not UnitExists(unit) then
                if UnitExists("mouseover") then
                    unit = "mouseover"
                end
            end

            -- Fallback: mouse focus attribute
            if not unit or not UnitExists(unit) then
                local focus = GetMouseFocus and GetMouseFocus()
                if focus and focus.GetAttribute then
                    local u = focus:GetAttribute("unit")
                    if u and UnitExists(u) then
                        unit = u
                    end
                end
            end

            if unit then
                EnhanceUnitTooltip(self, unit)
            end
        end)
    end
    
    -- Reset NPC GUID flag and upgrade flag when tooltip is cleared
    if not GameTooltip._dcqosHookedOnTooltipCleared then
        GameTooltip._dcqosHookedOnTooltipCleared = true
        GameTooltip:HookScript("OnTooltipCleared", function(self)
            self._dcqosNpcGuid = nil
            self._dcqosUpgradeShown = nil
            self._dcqosSpellIdShown = nil
            self._dcqosActiveSpellKey = nil
            self._dcqosSpellEnrichmentShownKey = nil
            self._dcqosNpcKillShown = nil
        end)
    end
    
    addon:Debug("Unit tooltip hooks installed")
end

-- ============================================================
-- Spell Tooltip Hooks
-- ============================================================
local function ResolveTooltipMethod(tooltipFrame, methodName)
    if not tooltipFrame or type(methodName) ~= "string" then
        return nil
    end

    if type(tooltipFrame[methodName]) == "function" then
        return tooltipFrame[methodName]
    end

    local mt = getmetatable(tooltipFrame)
    local indexTable = mt and mt.__index
    if type(indexTable) == "table" then
        local candidate = indexTable[methodName]
        if type(candidate) == "function" then
            return candidate
        end
    elseif type(indexTable) == "function" then
        local ok, fn = pcall(indexTable, tooltipFrame, methodName)
        if ok and type(fn) == "function" then
            return fn
        end
    end

    return nil
end

local stableTooltipMethods = {}
local nativeTooltipMethods = {}
local guardedTooltipWrappers = {}
local actionSpellScratchTooltip = nil

local function SafeInvokeTooltipMethod(tooltip, methodName, ...)
    if not tooltip or type(methodName) ~= "string" then
        return false
    end

    local ok, called = pcall(function(...)
        local method = tooltip[methodName]
        if type(method) ~= "function" then
            return false
        end

        method(tooltip, ...)
        return true
    end, ...)

    return ok and called == true
end

local function SafeInvokeCallable(callable, ...)
    if type(callable) ~= "function" then
        return false, "callable-not-function"
    end

    if type(pcall) ~= "function" then
        return false, "pcall-missing"
    end

    local ok, result = pcall(callable, ...)
    if not ok then
        return false, result
    end

    return true, result
end

local function EnsureActionSpellScratchTooltip()
    if actionSpellScratchTooltip then
        return actionSpellScratchTooltip
    end

    if type(CreateFrame) ~= "function" or not UIParent then
        return nil
    end

    local tooltip = CreateFrame("GameTooltip", "DCQOSActionSpellScratchTooltip", UIParent, "GameTooltipTemplate")
    if not tooltip then
        return nil
    end

    if type(tooltip.SetOwner) == "function" then
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    actionSpellScratchTooltip = tooltip
    return actionSpellScratchTooltip
end

local function ResolveSpellBookSlotBySpellId(spellId)
    if type(spellId) ~= "number" or spellId <= 0 then
        return nil
    end

    if type(FindSpellBookSlotBySpellID) == "function" then
        local slot = FindSpellBookSlotBySpellID(spellId)
        if type(slot) == "number" and slot > 0 then
            return slot
        end
    end

    if type(GetNumSpellTabs) ~= "function"
        or type(GetSpellTabInfo) ~= "function"
        or type(GetSpellBookItemInfo) ~= "function" then
        return nil
    end

    local bookType = BOOKTYPE_SPELL or "spell"
    local numTabs = GetNumSpellTabs() or 0
    for tab = 1, numTabs do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        if type(offset) == "number" and type(numSpells) == "number" and numSpells > 0 then
            for slot = offset + 1, offset + numSpells do
                local _, bookSpellId = GetSpellBookItemInfo(slot, bookType)
                if type(bookSpellId) == "number" and bookSpellId == spellId then
                    return slot
                end
            end
        end
    end

    return nil
end

local function CopyTooltipContents(sourceTooltip, targetTooltip)
    if not sourceTooltip or not targetTooltip then
        return false
    end

    if type(sourceTooltip.NumLines) ~= "function" or type(sourceTooltip.GetName) ~= "function" then
        return false
    end

    local sourceName = sourceTooltip:GetName()
    if not sourceName or sourceName == "" then
        return false
    end

    if type(targetTooltip.ClearLines) == "function" then
        targetTooltip:ClearLines()
    end

    local targetName = targetTooltip.GetName and targetTooltip:GetName()
    local copiedAny = false

    for lineIndex = 1, sourceTooltip:NumLines() do
        local leftLine = _G[sourceName .. "TextLeft" .. lineIndex]
        local rightLine = _G[sourceName .. "TextRight" .. lineIndex]
        local leftText = leftLine and leftLine.GetText and leftLine:GetText() or nil
        local rightText = rightLine and rightLine.GetText and rightLine:GetText() or nil

        if leftText and leftText ~= "" or rightText and rightText ~= "" then
            local leftR, leftG, leftB = 1, 1, 1
            local rightR, rightG, rightB = 1, 1, 1

            if leftLine and leftLine.GetTextColor then
                leftR, leftG, leftB = leftLine:GetTextColor()
            end

            if rightLine and rightLine.GetTextColor then
                rightR, rightG, rightB = rightLine:GetTextColor()
            end

            if lineIndex == 1 and type(targetTooltip.SetText) == "function" and leftText and leftText ~= "" then
                targetTooltip:SetText(leftText)
                copiedAny = true

                if targetName and rightText and rightText ~= "" then
                    local targetRight = _G[targetName .. "TextRight1"]
                    if targetRight and targetRight.SetText then
                        targetRight:SetText(rightText)
                        if targetRight.SetTextColor then
                            targetRight:SetTextColor(rightR, rightG, rightB)
                        end
                    end
                end
            elseif rightText and rightText ~= "" and type(targetTooltip.AddDoubleLine) == "function" then
                targetTooltip:AddDoubleLine(leftText or " ", rightText, leftR, leftG, leftB, rightR, rightG, rightB)
                copiedAny = true
            elseif leftText and leftText ~= "" and type(targetTooltip.AddLine) == "function" then
                targetTooltip:AddLine(leftText, leftR, leftG, leftB)
                copiedAny = true
            end
        end
    end

    return copiedAny
end

local function TryCopySpellTooltipFromScratch(targetTooltip, spellId)
    local scratchTooltip = EnsureActionSpellScratchTooltip()
    if not scratchTooltip or not spellId then
        return false
    end

    if type(scratchTooltip.ClearLines) == "function" then
        scratchTooltip:ClearLines()
    end

    if type(scratchTooltip.SetOwner) == "function" then
        scratchTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    -- Render on a hidden scratch tooltip first, then copy lines into the live tooltip.
    -- This avoids calling SetHyperlink directly on the live action-button tooltip,
    -- which is where the non-catchable crash path was observed.
    local rendered = false

    local slot = ResolveSpellBookSlotBySpellId(spellId)
    if slot then
        rendered = SafeInvokeTooltipMethod(scratchTooltip, "SetSpell", slot, BOOKTYPE_SPELL or "spell")
    end

    if not rendered and type(GetSpellInfo) == "function" then
        local spellName = GetSpellInfo(spellId)
        if spellName and spellName ~= "" then
            local hyperlink = "|cff71d5ff|Hspell:" .. tostring(spellId) .. "|h[" .. spellName .. "]|h|r"
            rendered = SafeInvokeTooltipMethod(scratchTooltip, "SetHyperlink", hyperlink)
        end
    end

    if not rendered or type(scratchTooltip.NumLines) ~= "function" or scratchTooltip:NumLines() <= 0 then
        return false
    end

    return CopyTooltipContents(scratchTooltip, targetTooltip)
end

local function ShouldForceTooltipFallback(methodName)
    return methodName == "SetAction" or methodName == "SetShapeshift"
end

local function ApplyTooltipMethodHardGuard(methodName, methodFn)
    if not GameTooltip or type(methodName) ~= "string" or type(methodFn) ~= "function" then
        return
    end

    rawset(GameTooltip, methodName, methodFn)

    local mt = getmetatable(GameTooltip)
    local indexTable = mt and mt.__index
    if type(indexTable) == "table" then
        indexTable[methodName] = methodFn
    end
end

local function InstallGuardedTooltipMethod(methodName, fallback)
    if not GameTooltip or type(methodName) ~= "string" then
        return
    end

    if guardedTooltipWrappers[methodName] then
        ApplyTooltipMethodHardGuard(methodName, guardedTooltipWrappers[methodName])
        return
    end

    local nativeMethod = nil
    if not ShouldForceTooltipFallback(methodName) then
        nativeMethod = nativeTooltipMethods[methodName]
            or ResolveTooltipMethod(EnsureActionSpellScratchTooltip(), methodName)
            or ResolveTooltipMethod(GameTooltip, methodName)
            or ResolveTooltipMethod(ItemRefTooltip, methodName)
            or ResolveTooltipMethod(ShoppingTooltip1, methodName)
            or ResolveTooltipMethod(ShoppingTooltip2, methodName)
    end

    if nativeMethod == guardedTooltipWrappers[methodName] then
        nativeMethod = nil
    end

    if type(nativeMethod) == "function" then
        nativeTooltipMethods[methodName] = nativeMethod
        stableTooltipMethods[methodName] = nativeMethod
    end

    local wrapped = function(self, ...)
        if ShouldForceTooltipFallback(methodName) then
            if type(fallback) == "function" then
                return fallback(self, ...)
            end
            return nil
        end

        local method = nativeTooltipMethods[methodName] or stableTooltipMethods[methodName]
        if type(method) == "function" then
            local ok, result = SafeInvokeCallable(method, self, ...)
            if ok then
                return result
            end
            addon:Debug("GameTooltip." .. methodName .. " native call failed, using fallback: " .. tostring(result))
        end

        if type(fallback) == "function" then
            return fallback(self, ...)
        end

        return nil
    end

    guardedTooltipWrappers[methodName] = wrapped
    ApplyTooltipMethodHardGuard(methodName, wrapped)
end

local function SafeFallbackSetAction(self, action, button)
    if not self then
        return
    end

    local function TooltipHasSpellBody(tooltip)
        if not tooltip or type(tooltip.NumLines) ~= "function" or type(tooltip.GetName) ~= "function" then
            return false
        end

        local tipName = tooltip:GetName()
        if not tipName or tipName == "" then
            return false
        end

        local nonEmptyLines = 0
        for lineIndex = 2, tooltip:NumLines() do
            local leftLine = _G[tipName .. "TextLeft" .. lineIndex]
            if leftLine and type(leftLine.GetText) == "function" then
                local text = leftLine:GetText()
                if type(text) == "string" and text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("%S") then
                    nonEmptyLines = nonEmptyLines + 1
                    if nonEmptyLines >= 2 then
                        return true
                    end
                end
            end
        end

        return false
    end

    local function AddSpellFallbackDetails(tooltip, spellId, spellRank, companionName, companionTypeLabel)
        if not tooltip or type(tooltip.AddLine) ~= "function" or type(GetSpellInfo) ~= "function" then
            return false
        end

        local _, _, _, castTime, minRange, maxRange = GetSpellInfo(spellId)
        local added = false

        if spellRank and spellRank ~= "" then
            tooltip:AddLine(spellRank, 0.8, 0.8, 0.8)
            added = true
        end

        if type(castTime) == "number" then
            if castTime <= 0 then
                tooltip:AddLine("Instant cast", 0.8, 0.8, 0.8)
                added = true
            else
                tooltip:AddLine(string.format("%.1f sec cast", castTime / 1000), 0.8, 0.8, 0.8)
                added = true
            end
        end

        if type(maxRange) == "number" and maxRange > 0 then
            if type(minRange) == "number" and minRange > 0 then
                tooltip:AddLine(string.format("%d-%d yd range", minRange, maxRange), 0.8, 0.8, 0.8)
            else
                tooltip:AddLine(string.format("%d yd range", maxRange), 0.8, 0.8, 0.8)
            end
            added = true
        end

        if companionName and companionName ~= "" then
            tooltip:AddLine(companionName, 0.8, 0.8, 0.8)
            added = true
        end

        if companionTypeLabel and companionTypeLabel ~= "" then
            tooltip:AddLine(companionTypeLabel, 0.6, 0.6, 0.6)
            added = true
        end

        return added
    end

    local actionId = tonumber(action)
    if (not actionId or actionId <= 0) and type(button) == "table" and tonumber(button.action) then
        actionId = tonumber(button.action)
    end

    if (not actionId or actionId <= 0) and type(ActionButton_GetPagedID) == "function" and type(button) == "table" then
        local ok, pagedAction = pcall(ActionButton_GetPagedID, button)
        if ok and type(pagedAction) == "number" and pagedAction > 0 then
            actionId = pagedAction
        end
    end

    if not actionId or actionId <= 0 then
        if type(self.Hide) == "function" then
            self:Hide()
        end
        return
    end

    if type(self.SetOwner) == "function" then
        if GameTooltip_SetDefaultAnchor and GetCVar and GetCVar("UberTooltips") == "1" and button then
            GameTooltip_SetDefaultAnchor(self, button)
        elseif button then
            self:SetOwner(button, "ANCHOR_RIGHT")
        end
    end

    local actionType, id, subType
    if type(GetActionInfo) == "function" then
        actionType, id, subType = GetActionInfo(actionId)
    end

    local spellId = nil
    local companionName = nil
    local companionTypeLabel = nil
    if actionType == "companion" and type(id) == "number" and id > 0 and type(GetCompanionInfo) == "function" then
        local companionType = (type(subType) == "string" and subType ~= "") and subType or "MOUNT"
        local _, resolvedCompanionName, companionSpellId = GetCompanionInfo(companionType, id)
        if type(resolvedCompanionName) == "string" and resolvedCompanionName ~= "" then
            companionName = resolvedCompanionName
        end
        companionTypeLabel = companionType
        if type(companionSpellId) == "number" and companionSpellId > 0 then
            spellId = companionSpellId
            actionType = "spell"
        end
    end

    if actionType == "spell" then
        if type(GetActionSpell) == "function" then
            local ok, resolvedSpellId = pcall(GetActionSpell, actionId)
            if ok and type(resolvedSpellId) == "number" and resolvedSpellId > 0 then
                spellId = resolvedSpellId
            end
        end

        if not spellId and type(id) == "number" and id > 0 and type(GetSpellLink) == "function" then
            local bookType = BOOKTYPE_SPELL or "spell"
            local link = GetSpellLink(id, bookType)
            if type(link) == "string" then
                local linkSpellId = tonumber(link:match("spell:(%d+)"))
                if linkSpellId and linkSpellId > 0 then
                    spellId = linkSpellId
                end
            end
        end

        if not spellId and type(id) == "number" and id > 0 and type(GetSpellBookItemInfo) == "function" then
            local bookType = BOOKTYPE_SPELL or "spell"
            local _, bookSpellId = GetSpellBookItemInfo(id, bookType)
            if type(bookSpellId) == "number" and bookSpellId > 0 then
                spellId = bookSpellId
            end
        end

        if not spellId and type(id) == "number" and id > 0 then
            spellId = id
        end
    end

    local wroteText = false

    if actionType == "spell" and spellId then
        -- Prefer native SetSpell on the live tooltip when we can resolve a
        -- spellbook slot. This keeps Blizzard's normal wrapping/width behavior.
        do
            local slot = ResolveSpellBookSlotBySpellId(spellId)
            if slot then
                wroteText = SafeInvokeTooltipMethod(self, "SetSpell", slot, BOOKTYPE_SPELL or "spell")
            end
        end

        -- Backup path: render spell data on a scratch tooltip and copy lines.
        if not wroteText then
            wroteText = TryCopySpellTooltipFromScratch(self, spellId)
        end

        -- Last-resort: show spell name only. Do NOT call AddLine/AddSpellFallbackDetails —
        -- those use non-wrapping AddLine and expand the tooltip to screen width.
        if not wroteText and type(GetSpellInfo) == "function" and type(self.SetText) == "function" then
            local spellName = GetSpellInfo(spellId)
            if spellName and spellName ~= "" then
                self:SetText(spellName)
                wroteText = true
            end
        end

        -- EnhanceSpellTooltip appends SpellID + server enrichment.
        -- When SetHyperlink succeeded, the hooksecurefunc hook already fires
        -- EnhanceSpellTooltip; this call is guarded by _dcqosSpellIdShown so
        -- it is safe (a no-op if already done).
        if wroteText then
            EnhanceSpellTooltip(self, spellId)
        end
    elseif actionType == "item" and id then
        wroteText = SafeInvokeTooltipMethod(self, "SetHyperlink", "item:" .. tostring(id))
    elseif actionType == "macro" and id and type(GetMacroInfo) == "function" and type(self.SetText) == "function" then
        local macroName = GetMacroInfo(id)
        if macroName and macroName ~= "" then
            self:SetText(macroName)
            wroteText = true
        end
    end

    if not wroteText and type(GetActionText) == "function" and type(self.SetText) == "function" then
        local actionText = GetActionText(actionId)
        if actionText and actionText ~= "" then
            self:SetText(actionText)
            wroteText = true
        end
    end

    if not wroteText and type(self.SetText) == "function" then
        self:SetText(ACTIONBAR_LABEL or "Action")
    end

    if type(button) == "table" then
        button.updateTooltip = TOOLTIP_UPDATE_TIME
        if type(button.UpdateTooltip) == "number" then
            button.UpdateTooltip = nil
        end
    end

    if type(self.Show) == "function" then
        self:Show()
    end
end

local function SafeFallbackSetShapeshift(self, index)
    if self and self.SetText and GetShapeshiftFormInfo and type(index) == "number" then
        local _, formName = GetShapeshiftFormInfo(index)
        if formName and formName ~= "" then
            self:SetText(formName)
            return
        end
    end

    if self and self.Hide then
        self:Hide()
    end
end

local function EnsureGameTooltipMethod(methodName, fallback)
    if not GameTooltip or type(methodName) ~= "string" then
        return
    end

    local wrappedFlagName = "_dcqosWrapped" .. methodName
    local currentMethod = GameTooltip[methodName]

    if type(currentMethod) == "function"
        and currentMethod ~= guardedTooltipWrappers[methodName]
        and not rawget(GameTooltip, wrappedFlagName) then
        nativeTooltipMethods[methodName] = currentMethod
        stableTooltipMethods[methodName] = currentMethod
        return
    end

    local recovered = nativeTooltipMethods[methodName]
        or stableTooltipMethods[methodName]
        or ResolveTooltipMethod(EnsureActionSpellScratchTooltip(), methodName)
        or ResolveTooltipMethod(GameTooltip, methodName)
        or ResolveTooltipMethod(ItemRefTooltip, methodName)
        or ResolveTooltipMethod(ShoppingTooltip1, methodName)
        or ResolveTooltipMethod(ShoppingTooltip2, methodName)

    if recovered == guardedTooltipWrappers[methodName] then
        recovered = nil
    end

    if type(recovered) == "function" then
        nativeTooltipMethods[methodName] = recovered
        stableTooltipMethods[methodName] = recovered
        rawset(GameTooltip, wrappedFlagName, nil)
        ApplyTooltipMethodHardGuard(methodName, recovered)
        addon:Debug("Recovered GameTooltip." .. methodName)
        return
    end

    if type(fallback) == "function" then
        stableTooltipMethods[methodName] = fallback
        rawset(GameTooltip, wrappedFlagName, true)
        ApplyTooltipMethodHardGuard(methodName, fallback)
        addon:Debug("GameTooltip." .. methodName .. " missing; installed safe fallback")
    end
end

local function SetFallbackShapeshiftTooltip(button)
    if not GameTooltip then
        return
    end

    local formIndex
    if button and type(button.GetID) == "function" then
        formIndex = button:GetID()
    elseif type(this) == "table" and type(this.GetID) == "function" then
        formIndex = this:GetID()
    end

    if not formIndex or formIndex <= 0 then
        return
    end

    if type(GameTooltip.SetOwner) == "function" then
        if GameTooltip_SetDefaultAnchor and GetCVar and GetCVar("UberTooltips") == "1" and button then
            GameTooltip_SetDefaultAnchor(GameTooltip, button)
        elseif button then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        end
    end

    SafeFallbackSetShapeshift(GameTooltip, formIndex)

    GameTooltip:Show()
end

local function EnsureSetShapeshiftFallback()
    if not GameTooltip or type(GameTooltip.SetShapeshift) == "function" then
        return
    end

    GameTooltip.SetShapeshift = function(self, index, button)
        local tooltip = self
        if type(tooltip) ~= "table" then
            tooltip = GameTooltip
        end

        local formIndex = tonumber(index)
        if (not formIndex or formIndex <= 0) and button and type(button.GetID) == "function" then
            formIndex = button:GetID()
        end
        if (not formIndex or formIndex <= 0) and type(this) == "table" and type(this.GetID) == "function" then
            formIndex = this:GetID()
        end

        if not formIndex or formIndex <= 0 then
            if tooltip and type(tooltip.Hide) == "function" then
                tooltip:Hide()
            end
            return
        end

        local owner = button or _G["ShapeshiftButton" .. tostring(formIndex)]
        if tooltip and type(tooltip.SetOwner) == "function" then
            if GameTooltip_SetDefaultAnchor and GetCVar and GetCVar("UberTooltips") == "1" and owner then
                GameTooltip_SetDefaultAnchor(tooltip, owner)
            elseif owner then
                tooltip:SetOwner(owner, "ANCHOR_RIGHT")
            end
        end

        SafeFallbackSetShapeshift(tooltip, formIndex)

        if tooltip and type(tooltip.Show) == "function" then
            tooltip:Show()
        end
    end

    addon:Debug("Installed GameTooltip.SetShapeshift fallback")
end

local function HookSpellTooltips()
    EnsureSetShapeshiftFallback()

    -- Replace ActionButton_SetTooltip entirely to prevent the non-catchable
    -- GameTooltip:SetAction nil crash (Blizzard's ActionButton.lua:430).
    -- Even pcall cannot suppress WoW's UI error reporter for this crash in
    -- protected script contexts, so we never call the native path at all.
    if type(ActionButton_SetTooltip) == "function" and not addon._dcqosWrappedActionButtonSetTooltip then
        addon._dcqosWrappedActionButtonSetTooltip = true
        ActionButton_SetTooltip = function(button)
            if not GameTooltip or not button then return end

            local actionId = tonumber(button.action)
            if (not actionId or actionId <= 0) and type(ActionButton_GetPagedID) == "function" then
                local ok, pagedAction = pcall(ActionButton_GetPagedID, button)
                if ok and type(pagedAction) == "number" and pagedAction > 0 then
                    actionId = pagedAction
                end
            end

            if actionId and actionId > 0 then
                SafeFallbackSetAction(GameTooltip, actionId, button)
            else
                GameTooltip:Hide()
            end

            if type(button.UpdateTooltip) == "number" then
                button.UpdateTooltip = nil
            end
        end
    end

    if type(ShapeshiftButton_OnEnter) == "function" and not addon._dcqosWrappedShapeshiftButtonOnEnter then
        addon._dcqosWrappedShapeshiftButtonOnEnter = true
        ShapeshiftButton_OnEnter = function(...)
            addon:Debug("ShapeshiftButton_OnEnter fallback path")
            local button = select(1, ...)
            if type(button) ~= "table" then
                button = this
            end
            SetFallbackShapeshiftTooltip(button)
        end
    end

    -- Most spell tooltips (action buttons, racials, etc.) fire this script.
    -- This is the most reliable way to capture spell IDs in 3.3.5a.
    if not GameTooltip._dcqosHookedOnTooltipSetSpell then
        GameTooltip._dcqosHookedOnTooltipSetSpell = true
        GameTooltip:HookScript("OnTooltipSetSpell", function(self)
            local name, rank, spellId = self:GetSpell()
            if not spellId and name then
                -- WotLK fallback: resolve by name.
                spellId = select(7, GetSpellInfo(name))
            end
            EnhanceSpellTooltip(self, spellId)
            self:Show()
        end)
    end

    -- Hook SetSpell (action bar) without overriding the native method,
    -- to avoid breaking ActionButton tooltip internals.
    if not GameTooltip._dcqosHookedSetSpell and hooksecurefunc and GameTooltip.SetSpell then
        GameTooltip._dcqosHookedSetSpell = true
        hooksecurefunc(GameTooltip, "SetSpell", function(self, spellBook, spellBookType, ...)
            -- In 3.3.5a, spellBook/spellBookType are usually spellbook indices.
            local spellName
            if spellBook and spellBookType and GetSpellBookItemName then
                spellName = GetSpellBookItemName(spellBook, spellBookType)
            end

            local spellId
            if spellName then
                spellId = select(7, GetSpellInfo(spellName))
            end

            if not spellId then
                local name, _, id = self:GetSpell()
                spellId = id or (name and select(7, GetSpellInfo(name)))
            end

            EnhanceSpellTooltip(self, spellId)
            self:Show()
        end)
    end
    
    -- Hook SetUnitBuff without replacing native function.
    if not GameTooltip._dcqosHookedSetUnitBuff and hooksecurefunc and GameTooltip.SetUnitBuff then
        GameTooltip._dcqosHookedSetUnitBuff = true
        hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, unit, index, filter, ...)
            -- WotLK UnitBuff doesn't reliably return spellId; resolve via tooltip spell.
            local name, _, spellId = self:GetSpell()
            if not spellId and name then
                spellId = select(7, GetSpellInfo(name))
            end
            EnhanceSpellTooltip(self, spellId)
            self:Show()
        end)
    end
    
    -- Hook SetUnitDebuff without replacing native function.
    if not GameTooltip._dcqosHookedSetUnitDebuff and hooksecurefunc and GameTooltip.SetUnitDebuff then
        GameTooltip._dcqosHookedSetUnitDebuff = true
        hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, unit, index, filter, ...)
            -- WotLK UnitDebuff doesn't reliably return spellId; resolve via tooltip spell.
            local name, _, spellId = self:GetSpell()
            if not spellId and name then
                spellId = select(7, GetSpellInfo(name))
            end
            EnhanceSpellTooltip(self, spellId)
            self:Show()
        end)
    end
    
    addon:Debug("Spell tooltip hooks installed")
end

-- ============================================================
-- Health Bar Hiding
-- ============================================================
local function SetupHealthBarHiding()
    if addon._dcqosHealthBarHidingSetup then return end
    if addon.settings.tooltips.hideHealthBar then
        addon._dcqosHealthBarHidingSetup = true
        GameTooltipStatusBar:HookScript("OnShow", function()
            GameTooltipStatusBar:Hide()
        end)
        GameTooltipStatusBar:Hide()
    end
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function Tooltips.OnInitialize()
    addon:Debug("Tooltips module initializing")
    
    -- Create drag frame for positioning
    CreateTipDragFrame()
    
    -- Set initial scale
    SetTooltipScale()
end

function Tooltips.OnEnable()
    addon:Debug("Tooltips module enabling")
    
    -- Setup tooltip anchor positioning
    SetTooltipAnchor()
    
    -- Hook item tooltips
    HookItemTooltips()
    
    -- Hook unit tooltips
    HookUnitTooltips()
    
    -- Hook spell tooltips
    HookSpellTooltips()
    
    -- Setup health bar hiding
    SetupHealthBarHiding()

    -- Kill tracker (NPC tooltips)
    if not killTrackerFrame then
        killTrackerFrame = CreateFrame("Frame")
        killTrackerFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "COMBAT_LOG_EVENT_UNFILTERED" then
                HandleCombatLogEvent(...)
            end
        end)
    end
    killTrackerFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    
    -- Listen for scale changes
    if not addon._dcqosTooltipSettingChangedHooked then
        addon._dcqosTooltipSettingChangedHooked = true
        addon:RegisterEvent("SETTING_CHANGED", function(path, value)
            if path == "tooltips.scale" then
                SetTooltipScale()
            end
        end)
    end
end

function Tooltips.OnDisable()
    addon:Debug("Tooltips module disabling")
    -- Note: Hooks cannot be removed, but we check enabled state in each hook
    if killTrackerFrame then
        killTrackerFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================

-- Helper function to add tooltip explanation to a checkbox
local function AddSettingTooltip(checkbox, title, description)
    checkbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        GameTooltip:AddLine(description, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    checkbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function Tooltips.CreateSettings(parent)
    local settings = addon.settings.tooltips
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Tooltip Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure tooltip enhancements including item IDs, NPC IDs, upgrade info, and positioning.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- ID Display Section
    -- ============================================================
    local idHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    idHeader:SetPoint("TOPLEFT", 16, yOffset)
    idHeader:SetText("ID Display")
    yOffset = yOffset - 25
    
    -- Show Item ID
    local itemIdCb = addon:CreateCheckbox(parent)
    itemIdCb:SetPoint("TOPLEFT", 16, yOffset)
    itemIdCb.Text:SetText("Show Item ID")
    itemIdCb:SetChecked(settings.showItemId)
    itemIdCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showItemId", self:GetChecked())
    end)
    AddSettingTooltip(itemIdCb, "Show Item ID", 
        "Displays the item's database ID in tooltips. Useful for database lookups, bug reports, and item identification. Item IDs are unique identifiers used by the game engine.")
    yOffset = yOffset - 25
    
    -- Show Item Level
    local itemLevelCb = addon:CreateCheckbox(parent)
    itemLevelCb:SetPoint("TOPLEFT", 16, yOffset)
    itemLevelCb.Text:SetText("Show Item Level")
    itemLevelCb:SetChecked(settings.showItemLevel)
    itemLevelCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showItemLevel", self:GetChecked())
    end)
    AddSettingTooltip(itemLevelCb, "Show Item Level",
        "Shows the item level (ilvl) in tooltips. Item level indicates the power level of gear and is used to calculate stats. Higher ilvl generally means better stats.")
    yOffset = yOffset - 25
    
    -- Show Upgrade Info
    local upgradeInfoCb = addon:CreateCheckbox(parent)
    upgradeInfoCb:SetPoint("TOPLEFT", 16, yOffset)
    upgradeInfoCb.Text:SetText("Show Upgrade Info")
    upgradeInfoCb:SetChecked(settings.showUpgradeInfo ~= false)
    upgradeInfoCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showUpgradeInfo", self:GetChecked())
    end)
    AddSettingTooltip(upgradeInfoCb, "Show Upgrade Info",
        "Displays upgrade tier and level information for items. Shows current upgrade progress (e.g. 'Level 5/15 Tier 2'), stat bonuses from upgrades (+X% All Stats), and modified item level. Requires server communication.")
    yOffset = yOffset - 25
    
    -- Show NPC ID
    local npcIdCb = addon:CreateCheckbox(parent)
    npcIdCb:SetPoint("TOPLEFT", 16, yOffset)
    npcIdCb.Text:SetText("Show NPC ID")
    npcIdCb:SetChecked(settings.showNpcId)
    npcIdCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showNpcId", self:GetChecked())
    end)
    AddSettingTooltip(npcIdCb, "Show NPC ID",
        "Shows the Entry ID and Spawn for NPCs in tooltips. Entry ID identifies the NPC type, while Spawn identifies the specific creature spawn. Useful for reporting bugs or referencing specific creatures.")
    yOffset = yOffset - 25

    -- Show NPC Kill Count
    local npcKillCb = addon:CreateCheckbox(parent)
    npcKillCb:SetPoint("TOPLEFT", 16, yOffset)
    npcKillCb.Text:SetText("Show NPC Kill Count")
    npcKillCb:SetChecked(settings.showNpcKillCount)
    npcKillCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showNpcKillCount", self:GetChecked())
    end)
    AddSettingTooltip(npcKillCb, "Show NPC Kill Count",
        "Displays how many of the same NPC you have killed (per-character and per-account). Counts only kills credited to you (including your pet/vehicle). Tracked by entry ID when available and caches names per entry.")
    yOffset = yOffset - 25
    
    -- Show Spell ID
    local spellIdCb = addon:CreateCheckbox(parent)
    spellIdCb:SetPoint("TOPLEFT", 16, yOffset)
    spellIdCb.Text:SetText("Show Spell ID")
    spellIdCb:SetChecked(settings.showSpellId)
    spellIdCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showSpellId", self:GetChecked())
    end)
    AddSettingTooltip(spellIdCb, "Show Spell ID",
        "Displays the spell's database ID in tooltips. Useful for macro creation, WeakAuras, and identifying custom server spells. Shown for abilities, buffs, debuffs, and item enchants.")
    yOffset = yOffset - 35

    -- Show Spell Family Metadata (diagnostic)
    local spellFamilyMetaCb = addon:CreateCheckbox(parent)
    spellFamilyMetaCb:SetPoint("TOPLEFT", 16, yOffset)
    spellFamilyMetaCb.Text:SetText("Show Spell Family Metadata (Diagnostics)")
    spellFamilyMetaCb:SetChecked(settings.showSpellFamilyMetadata)
    spellFamilyMetaCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showSpellFamilyMetadata", self:GetChecked())
    end)
    AddSettingTooltip(spellFamilyMetaCb, "Show Spell Family Metadata",
        "Shows spell family diagnostics in spell tooltips (family name/id and family flags). Keep disabled for regular gameplay; enable for admin/dev debugging and scripted spell investigations.")
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Unit Tooltip Section
    -- ============================================================
    local unitHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    unitHeader:SetPoint("TOPLEFT", 16, yOffset)
    unitHeader:SetText("Unit Tooltips")
    yOffset = yOffset - 25
    
    -- Show Guild Rank
    local guildRankCb = addon:CreateCheckbox(parent)
    guildRankCb:SetPoint("TOPLEFT", 16, yOffset)
    guildRankCb.Text:SetText("Show Guild Ranks")
    guildRankCb:SetChecked(settings.showGuildRank)
    guildRankCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showGuildRank", self:GetChecked())
    end)
    AddSettingTooltip(guildRankCb, "Show Guild Ranks",
        "Displays the guild rank of players in their tooltips. Shows the player's position in their guild hierarchy. Useful for identifying guild officers and members.")
    yOffset = yOffset - 25
    
    -- Show Target
    local targetCb = addon:CreateCheckbox(parent)
    targetCb:SetPoint("TOPLEFT", 16, yOffset)
    targetCb.Text:SetText("Show Unit Target")
    targetCb:SetChecked(settings.showTarget)
    targetCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showTarget", self:GetChecked())
    end)
    AddSettingTooltip(targetCb, "Show Unit Target",
        "Shows who or what the moused-over unit is currently targeting. Color-coded: Green for friendly targets, Red for hostile targets, Yellow for neutral. Displays '>> YOU <<' in red if the unit is targeting you.")
    yOffset = yOffset - 25
    
    -- Hide Health Bar
    local healthBarCb = addon:CreateCheckbox(parent)
    healthBarCb:SetPoint("TOPLEFT", 16, yOffset)
    healthBarCb.Text:SetText("Hide Health Bar")
    healthBarCb:SetChecked(settings.hideHealthBar)
    healthBarCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.hideHealthBar", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    AddSettingTooltip(healthBarCb, "Hide Health Bar",
        "Removes the health bar from unit tooltips for a cleaner look. The health percentage will still be shown as text. Requires a UI reload (/reload) to take effect.")
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Combat Section
    -- ============================================================
    local combatHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    combatHeader:SetPoint("TOPLEFT", 16, yOffset)
    combatHeader:SetText("Combat Behavior")
    yOffset = yOffset - 25
    
    -- Hide in Combat
    local hideCombatCb = addon:CreateCheckbox(parent)
    hideCombatCb:SetPoint("TOPLEFT", 16, yOffset)
    hideCombatCb.Text:SetText("Hide Tooltips in Combat")
    hideCombatCb:SetChecked(settings.hideInCombat)
    hideCombatCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.hideInCombat", self:GetChecked())
    end)
    AddSettingTooltip(hideCombatCb, "Hide Tooltips in Combat",
        "Automatically hides unit tooltips while you are in combat. Reduces screen clutter during fights and can improve performance. Use with 'Show with Shift' to override when needed.")
    yOffset = yOffset - 25
    
    -- Show with Shift
    local shiftCb = addon:CreateCheckbox(parent)
    shiftCb:SetPoint("TOPLEFT", 36, yOffset)
    shiftCb.Text:SetText("Show with Shift key in combat")
    shiftCb:SetChecked(settings.showWithShift)
    shiftCb:SetScript("OnClick", function(self)
        addon:SetSetting("tooltips.showWithShift", self:GetChecked())
    end)
    AddSettingTooltip(shiftCb, "Show with Shift in Combat",
        "When 'Hide in Combat' is enabled, holding Shift will temporarily show tooltips. This allows you to check enemy info during fights when you need it.")
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Scale Slider
    -- ============================================================
    local scaleHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleHeader:SetPoint("TOPLEFT", 16, yOffset)
    scaleHeader:SetText("Tooltip Scale")
    yOffset = yOffset - 25
    
    local scaleSlider = addon:CreateSlider(parent, "DCQoSTooltipScaleSlider")
    scaleSlider:SetPoint("TOPLEFT", 20, yOffset)
    scaleSlider:SetWidth(200)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetValue(settings.scale or 1.0)
    scaleSlider.Low:SetText("50%")
    scaleSlider.High:SetText("200%")
    scaleSlider.Text:SetText(string.format("%.0f%%", (settings.scale or 1.0) * 100))
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        self.Text:SetText(string.format("%.0f%%", value * 100))
        addon:SetSetting("tooltips.scale", value)
    end)
    scaleSlider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Tooltip Scale", 1, 0.82, 0)
        GameTooltip:AddLine("Adjusts the size of all tooltips. 100% is the default size. Increase for larger, easier to read tooltips, or decrease to reduce screen clutter.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    scaleSlider:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("Tooltips", Tooltips)
