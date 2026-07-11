-- ============================================================
-- DC-QoS: Tooltips Module - Items
-- Split out of Tooltips.lua; state is shared via DCQOS.TooltipsNS
-- ============================================================

local addon = DCQOS
local TT = addon.TooltipsNS
local Tooltips = TT.module

-- ============================================================
-- Equipped-item comparison (side-by-side ShoppingTooltips)
-- ============================================================
-- On stock 3.3.5 the FrameXML handler GameTooltip_OnTooltipSetItem pops the
-- equipped comparison (ShoppingTooltip1/2) whenever an item tooltip is set and
-- the COMPAREITEMS modifier is held (or alwaysCompareItems is on). On patched
-- native clients the C++ item renderer fills the tooltip WITHOUT firing the
-- Lua OnTooltipSetItem script, so that handler never runs and the equipped
-- comparison never appears. Reproduce it here from our own Set* hooks.
--
-- Gated to native clients only: on stock clients the FrameXML handler already
-- does this, so we must not fight it.
-- Maps a hovered item's equip location to the equipped inventory slot(s) it
-- should be compared against (1-indexed INVSLOT_* ids).
local INVTYPE_COMPARE_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

-- Resolve the item link for the item a tooltip is currently showing, from the
-- refresh info our Set* hooks stashed. Reliable even when GetItem() isn't.
function TT.GetTrackedItemLink(tooltip)
    if not tooltip then return nil end
    local kind = tooltip._dcqosRefreshKind
    if kind == "bag" then
        local bag = tonumber(tooltip._dcqosRefreshBag)
        local slot = tonumber(tooltip._dcqosRefreshSlot)
        if bag ~= nil and slot ~= nil then
            return GetContainerItemLink(bag, slot)
        end
    elseif kind == "inventory" then
        local unit = tooltip._dcqosRefreshUnit
        local slot = tonumber(tooltip._dcqosRefreshSlot)
        if unit and slot ~= nil and UnitExists(unit) then
            return GetInventoryItemLink(unit, slot)
        end
    end
    return nil
end

-- Fallback comparison for "phantom" equipped items -- dynamically-generated
-- item-upgrade clones that have a display (texture) but NO client item id/link,
-- so the stock link-based SetCompareItem can't render them. We render each
-- target equipped slot directly from its slot via SetInventoryItem, which the
-- native tooltip path resolves from the server. Returns true if anything shown.
-- Lay out whichever shopping tooltips are currently shown alongside the main
-- tooltip, tops aligned (stock offsets them ~10px lower, which reads as a bug
-- next to our own rendering). Anchors to whichever side has more room.
local function LayoutShoppingTooltips(main)
    local shoppingTooltips = main.shoppingTooltips
    if not shoppingTooltips then return end

    local side = "right"
    local mainRight = main:GetRight()
    if mainRight and mainRight > (GetScreenWidth() / 2) then
        side = "left"
    end

    local prev = nil
    for i = 1, #shoppingTooltips do
        local st = shoppingTooltips[i]
        if st and st:IsShown() then
            st:ClearAllPoints()
            if side == "left" then
                st:SetPoint("TOPRIGHT", prev or main, "TOPLEFT", -3, 0)
            else
                st:SetPoint("TOPLEFT", prev or main, "TOPRIGHT", 3, 0)
            end
            prev = st
        end
    end
end

local function ShowSlotBasedCompare(main, equipLoc)
    if not equipLoc then return false end
    local slots = INVTYPE_COMPARE_SLOTS[equipLoc]
    if not slots then return false end
    local shoppingTooltips = main.shoppingTooltips
    if not shoppingTooltips then return false end

    for _, st in pairs(shoppingTooltips) do
        st:Hide()
    end

    local shown = 0
    for _, slot in ipairs(slots) do
        -- Texture (not id/link) is what's reliable for phantom items.
        if GetInventoryItemTexture("player", slot) then
            local st = shoppingTooltips[shown + 1]
            if st then
                st:SetOwner(main, "ANCHOR_NONE")
                st:SetInventoryItem("player", slot)
                st:Show()
                shown = shown + 1
            end
        end
    end

    if shown > 0 then
        LayoutShoppingTooltips(main)
    end
    main._dcqosSlotCompareShown = (shown > 0) and true or nil
    return shown > 0
end

local function TryShowCompareItem(tooltip, itemLink)
    if type(GetDCClientCapabilities) ~= "function" then return end
    if not tooltip or not tooltip.shoppingTooltips then return end

    if not (IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems")) then
        for _, frame in pairs(tooltip.shoppingTooltips) do
            frame:Hide()
        end
        tooltip._dcqosSlotCompareShown = nil
        return
    end

    -- Stock path first: renders items that have resolvable client data.
    if type(GameTooltip_ShowCompareItem) == "function" then
        GameTooltip_ShowCompareItem(tooltip)
    end

    local st1 = tooltip.shoppingTooltips[1]
    if st1 and st1:IsShown() then
        -- Stock rendered the comparison; re-align its tops with the main tooltip.
        LayoutShoppingTooltips(tooltip)
        return
    end

    -- Nothing rendered (phantom upgrade items): fall back to slot-based
    -- rendering keyed off the hovered item's equip location.
    local link = itemLink or TT.GetTrackedItemLink(tooltip)
    local equipLoc = link and select(9, GetItemInfo(link)) or nil
    if equipLoc then
        ShowSlotBasedCompare(tooltip, equipLoc)
    end
end
TT.TryShowCompareItem = TryShowCompareItem

-- ============================================================
-- Item ID in Tooltips
-- ============================================================
local function AddItemId(tooltip, itemLink)
    if not addon.settings.tooltips.showItemId then return end
    if not itemLink then return end

    -- On patched native clients, item IDs are rendered from C++ tooltip code.
    -- Appending a second Lua-owned line here can visibly blink when the native
    -- async item snapshot path redraws the tooltip without re-entering these hooks.
    if type(GetDCClientCapabilities) == "function" then
        return
    end
    
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

    -- On patched native clients the C++ tooltip owns item rendering and redraws
    -- asynchronously (item-upgrade snapshots) without re-entering these Lua
    -- hooks. A Lua-owned line here gets wiped by that redraw and re-added on the
    -- next refresh, which flickers below the item. Defer to the native renderer
    -- exactly like AddItemId does. (Upgraded items show their item level via the
    -- native upgrade snapshot.)
    if type(GetDCClientCapabilities) == "function" then
        return
    end

    -- If the tooltip already shows item level (client or another addon), don't add a duplicate.
    local tipName = tooltip and tooltip.GetName and tooltip:GetName()
    if tipName and tooltip.NumLines then
        for i = 1, tooltip:NumLines() do
            local left = _G[tipName .. "TextLeft" .. i]
            if left and left.GetText then
                local text = left:GetText()
                if text then
                    -- Keep this intentionally simple: WotLK strings are typically "Item Level".
                    if string.find(text, "Item Level", 1, true) then
                        return
                    end
                end
            end
        end
    end
    
    local _, _, _, itemLevel = TT.GetCachedItemInfo(itemLink)
    if itemLevel and itemLevel > 0 then
        tooltip:AddDoubleLine("Item Level:", "|cffffffff" .. itemLevel .. "|r", 0.5, 0.5, 0.5)
    end
end

-- ============================================================
-- Mount Info in Tooltips
-- ============================================================
function TT.AddMountInfo(tooltip, spellId)
    if not addon.settings.tooltips.showMountInfo then return end
    if not spellId then return end
    local sid = tonumber(spellId)
    if not sid or sid <= 0 then return end

    if type(DCCollection) ~= "table" then return end
    local defs = type(DCCollection.definitions) == "table" and DCCollection.definitions.mounts
    if not defs then return end
    local def = defs[sid]
    if not def then return end

    -- Dedupe against the actual tooltip content. Action-button tooltips
    -- rebuild their lines on the periodic refresh tick; a sticky per-spell
    -- flag (the old guard) blocked re-adding the line after the first
    -- rebuild, so it vanished on action bars while surviving in the
    -- (non-refreshing) mount journal.
    local tipName = tooltip.GetName and tooltip:GetName()
    if tipName and tooltip.NumLines then
        for i = 1, tooltip:NumLines() do
            local left = _G[tipName .. "TextLeft" .. i]
            local text = left and left.GetText and left:GetText()
            if text and text:find("Mount:", 1, true) then
                return
            end
        end
    end

    -- Still recorded for the enrichment renderer, which skips the server's
    -- own mount meta lines when this line is present.
    tooltip._dcqosMountInfoShownSpellId = sid

    local mountTypeLabels = {
        [0] = "|cffffff00Ground|r",
        [1] = "|cff00aaffFlying|r",
        [2] = "|cff00ffffAquatic|r",
        [3] = "|cffffff00Ground|r + |cff00aaffFlying|r",
    }
    local mountType = tonumber(def.mountType) or 0

    local groundSpeed = tonumber(def.groundSpeed)
    local flySpeed    = tonumber(def.flySpeed)
    local baseSpeed   = tonumber(def.speed)

    -- The aura-derived speeds are more reliable than the CDBC mountType
    -- column (flying mounts are sometimes typed "Ground" there); classify
    -- from the speeds when they're available. Speeds go on their own line
    -- below the type so the tooltip doesn't widen.
    if groundSpeed and flySpeed then
        tooltip:AddLine("Mount: " .. mountTypeLabels[3], 0.5, 0.5, 0.5)
        tooltip:AddLine(
            "|cffffff00" .. groundSpeed .. "%|r ground  |cff00aaff"
                .. flySpeed .. "%|r fly",
            0.9, 0.9, 0.9)
    elseif flySpeed then
        tooltip:AddLine("Mount: " .. mountTypeLabels[1], 0.5, 0.5, 0.5)
        tooltip:AddLine("|cff00aaff" .. flySpeed .. "%|r fly", 0.9, 0.9, 0.9)
    elseif groundSpeed or (baseSpeed and baseSpeed > 0) then
        local typeLabel = mountTypeLabels[mountType] or mountTypeLabels[0]
        tooltip:AddLine("Mount: " .. typeLabel, 0.5, 0.5, 0.5)
        tooltip:AddLine(
            "|cffffffff" .. (groundSpeed or baseSpeed) .. "%|r speed",
            0.9, 0.9, 0.9)
    else
        local typeLabel = mountTypeLabels[mountType] or mountTypeLabels[0]
        tooltip:AddLine("Mount: " .. typeLabel, 0.5, 0.5, 0.5)
    end
    tooltip:Show()
end

-- ============================================================
-- Item Tooltip Hooks
-- ============================================================
function TT.HookItemTooltips()
    local function AddItemTooltipDetails(self, itemLink)
        if not itemLink then
            return
        end

        AddItemId(self, itemLink)
        AddItemLevel(self, itemLink)
        TryShowCompareItem(self, itemLink)
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
        self._dcqosRefreshKind = "bag"
        self._dcqosRefreshBag = bag
        self._dcqosRefreshSlot = slot
        self._dcqosRefreshUnit = nil
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
            AddItemTooltipDetails(self, itemLink)
            TT.AddUpgradeInfo(self, bag, slot, itemLink)
        end
    end)

    HookTooltipMethodOnce("_dcqosHookedSetInventoryItem", "SetInventoryItem", function(self, unit, slot, ...)
        self._dcqosRefreshKind = "inventory"
        self._dcqosRefreshUnit = unit
        self._dcqosRefreshBag = nil
        self._dcqosRefreshSlot = slot
        local itemLink = GetInventoryItemLink(unit, slot)
        if itemLink then
            AddItemTooltipDetails(self, itemLink)
            if unit == "player" then
                TT.AddUpgradeInfo(self, -2, slot, itemLink)  -- -2 = equipment
            end
        end
    end)

    HookTooltipMethodOnce("_dcqosHookedSetHyperlink", "SetHyperlink", function(self, link, ...)
        if link and link:find("item:") then
            AddItemTooltipDetails(self, link)
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

    -- Toggle the equipped comparison when the COMPAREITEMS modifier changes while
    -- a tooltip is already up. Stock does this via GameTooltip_OnUpdate polling;
    -- on the native path our Set* hooks don't re-fire on a bare key press, so we
    -- react to the key event directly. (Native-only path -- TryShowCompareItem
    -- no-ops on stock clients where the FrameXML OnUpdate already handles it.)
    if not TT.compareModifierFrame and type(GetDCClientCapabilities) == "function" then
        local f = CreateFrame("Frame")
        f:RegisterEvent("MODIFIER_STATE_CHANGED")
        f:SetScript("OnEvent", function(_, _, key)
            -- COMPAREITEMS defaults to SHIFT but can be rebound to ALT/CTRL;
            -- MODIFIER_STATE_CHANGED only fires for modifier keys, so react to any.
            if not GameTooltip:IsShown() then
                return
            end
            local kind = GameTooltip._dcqosRefreshKind
            local _, link = GameTooltip:GetItem()
            if link or kind == "bag" or kind == "inventory" then
                TryShowCompareItem(GameTooltip)
            end
        end)
        TT.compareModifierFrame = f
    end

    -- Guaranteed cleanup: when the tooltip hides (mouse leaves), hide any
    -- slot-based comparison we rendered so it can't linger if OnTooltipCleared
    -- doesn't fire on the native path.
    if not GameTooltip._dcqosHookedCompareOnHide then
        GameTooltip._dcqosHookedCompareOnHide = true
        GameTooltip:HookScript("OnHide", function(self)
            if self._dcqosSlotCompareShown and self.shoppingTooltips then
                for _, st in pairs(self.shoppingTooltips) do
                    st:Hide()
                end
            end
            self._dcqosSlotCompareShown = nil
        end)
    end

    addon:Debug("Item tooltip hooks installed")
end
