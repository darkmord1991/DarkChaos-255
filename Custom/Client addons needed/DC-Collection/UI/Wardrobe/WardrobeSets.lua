--[[
    DC-Collection UI/Wardrobe/WardrobeSets.lua
    =========================================

    Sets tab: set list rendering using the shared grid.
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

function Wardrobe:RefreshSetsGrid()
    if not self.frame then return end

    for _, btn in ipairs(self.frame.gridButtons) do
        btn:Hide()
    end

    local sets = DC.definitions and (DC.definitions.itemsets or DC.definitions.itemSets or DC.definitions.sets) or {}
    local list = {}
    for id, set in pairs(sets) do
        if type(set) == "table" then
            set.id = set.id or id
            table.insert(list, set)
        end
    end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)

    local collectedSets = 0
    local totalSets = #list

    local startIdx = (self.currentPage - 1) * self.ITEMS_PER_PAGE + 1

    for i, btn in ipairs(self.frame.gridButtons) do
        local idx = startIdx + (i - 1)
        local set = list[idx]

        if set then
            btn:Show()
            btn.itemData = set

            local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
            if set.items and set.items[1] then
                local itemId = set.items[1]
                if GetItemIcon then
                    icon = GetItemIcon(itemId) or icon
                elseif GetItemInfo then
                    icon = select(10, GetItemInfo(itemId)) or icon
                end
            elseif set.icon then
                icon = set.icon
            end

            btn.icon:SetTexture(icon)

            local collectedCount = 0
            local totalCount = 0
            local col = DC.collections and (DC.collections.transmog or {}) or {}
            if set.items then
                totalCount = #set.items
                for _, itemId in ipairs(set.items) do
                    if col[itemId] then
                        collectedCount = collectedCount + 1
                    end
                end
            end

            local setComplete = totalCount > 0 and collectedCount == totalCount
            if setComplete then
                btn.icon:SetVertexColor(1, 1, 1)
                btn.notCollected:Hide()
                collectedSets = collectedSets + 1
            else
                btn.icon:SetVertexColor(0.4, 0.4, 0.4)
                btn.notCollected:Show()
            end

            btn:SetScript("OnEnter", function()
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:SetText(set.name or "Unknown Set")
                GameTooltip:AddLine(string.format("%d / %d pieces", collectedCount, totalCount), 0.6, 0.8, 1)
                GameTooltip:AddLine(" ")
                if set.items then
                    for _, itemId in ipairs(set.items) do
                        local name = GetItemInfo(itemId)
                        local isCollected = col[itemId]
                        if name then
                            if isCollected then
                                GameTooltip:AddLine(name, 0.1, 1, 0.1)
                            else
                                GameTooltip:AddLine(name, 0.5, 0.5, 0.5)
                            end
                        else
                            GameTooltip:AddLine("Item #" .. itemId, 0.5, 0.5, 0.5)
                        end
                    end
                end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            btn:Hide()
        end
    end

    if self.frame.collectedFrame then
        self.frame.collectedFrame.text:SetText(string.format("Sets: %d / %d", collectedSets, totalSets))
        local pct = totalSets > 0 and (collectedSets / totalSets) or 0
        self.frame.collectedFrame.bar:SetValue(pct)
    end

    local totalPages = math.max(1, math.ceil(#list / self.ITEMS_PER_PAGE))
    self.totalPages = totalPages
    if self.frame.pageText then
        self.frame.pageText:SetText(string.format("Page %d / %d", self.currentPage, totalPages))
    end

    if self.frame.prevBtn then
        if self.currentPage > 1 then
            self.frame.prevBtn:Enable()
        else
            self.frame.prevBtn:Disable()
        end
    end
    if self.frame.nextBtn then
        if self.currentPage < totalPages then
            self.frame.nextBtn:Enable()
        else
            self.frame.nextBtn:Disable()
        end
    end
end
