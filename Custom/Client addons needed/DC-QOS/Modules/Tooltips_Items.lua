-- ============================================================
-- DC-QoS: Tooltips Module - Items
-- Split out of Tooltips.lua; state is shared via DCQOS.TooltipsNS
-- ============================================================

local addon = DCQOS
local TT = addon.TooltipsNS
local Tooltips = TT.module

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
    
    addon:Debug("Item tooltip hooks installed")
end
