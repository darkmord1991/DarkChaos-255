--[[
    DC-Collection UI/Wardrobe/WardrobeCommunity.lua
    ================================================

    Community Outfits tab: Browse shared outfits and add to personal collection.
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

-- ============================================================================
-- COMMUNITY OUTFITS SYSTEM
-- ============================================================================

function Wardrobe:ShowCommunityContent()
    if self.frame then
        if self.frame.modelTitle then self.frame.modelTitle:SetText("Community Outfits") end
        
        -- Hide items/sets specific controls
        if self.frame.orderBtn then self.frame.orderBtn:Hide() end
        if self.frame.filterBtn then self.frame.filterBtn:Hide() end
        if self.frame.qualityDropdown then self.frame.qualityDropdown:Hide() end
        if self.frame.searchBox then self.frame.searchBox:Hide() end
        
        -- Hide slot filters
        for _, btn in ipairs(self.frame.slotFilterButtons or {}) do
            btn:Hide()
        end
        
        -- Hide standard grid container
        if self.frame.gridContainer then self.frame.gridContainer:Hide() end
        if self.frame.gridFrame then self.frame.gridFrame:Hide() end
        
        -- Hide outfit grid
        if self.frame.outfitGridContainer then self.frame.outfitGridContainer:Hide() end

        -- Hide outfits-only pager (Outfits tab)
        if self.frame.outfitsPageFrame then self.frame.outfitsPageFrame:Hide() end

        -- Ensure shared pager (used by Sets) is visible
        if self.frame.pageFrame then self.frame.pageFrame:Show() end

        -- Show community grid container (create if needed)
        if not self.frame.communityGridContainer then
            self:CreateCommunityGrid()
        end
        if self.frame.communityGridContainer then 
            self.frame.communityGridContainer:Show() 
        end

        -- Hide collected bar
        if self.frame.collectedFrame then self.frame.collectedFrame:Hide() end
        if self.frame.showUncollectedCheck then self.frame.showUncollectedCheck:Hide() end
        
        if self.frame.modelPanel then self.frame.modelPanel:Show() end
        if self.frame.previewModeFrame then self.frame.previewModeFrame:Show() end

        -- Hide Outfit Controls (for personal outfits tab)
        if self.frame.newOutfitBtn then self.frame.newOutfitBtn:Hide() end
        if self.frame.randomOutfitBtn then self.frame.randomOutfitBtn:Hide() end

        -- Request community list from server
        if DC.RequestCommunityList then
            -- Use newest so freshly published outfits show up immediately.
            DC:RequestCommunityList(0, 50, "all", "newest")
        end
    end
    
    -- Reset pagination (shared pager)
    self.currentPage = 1
    self.totalPages = 1
    
    self:RefreshCommunityGrid()
end

-- Called by Protocol.lua after SMSG_COMMUNITY_PUBLISH_RESULT
function Wardrobe:OnPublishResult(success)
    if not success then
        return
    end

    -- If the user is on (or later opens) the community tab, ensure we pull the newest list.
    if DC and DC.RequestCommunityList then
        DC:RequestCommunityList(0, 50, "all", "newest")
    end
end

function Wardrobe:CreateCommunityGrid()
    if not self.frame or not self.frame.rightPanel then return end
    
    local container = CreateFrame("Frame", nil, self.frame.rightPanel)
    container:SetPoint("TOPLEFT", self.frame.rightPanel, "TOPLEFT", 10, -35)
    container:SetPoint("BOTTOMRIGHT", self.frame.rightPanel, "BOTTOMRIGHT", -10, 50)
    container:Hide()
    
    self.frame.communityGridContainer = container
    
    -- Create grid of 6 outfit cards (3x2)
    local buttons = {}
    local CARD_WIDTH = 140
    local CARD_HEIGHT = 180
    local GAP_X = 10
    local GAP_Y = 10
    local COLS = 3
    
    for i = 1, 6 do
        local row = math.floor((i - 1) / COLS)
        local col = (i - 1) % COLS
        
        local btn = CreateFrame("Button", nil, container)
        btn:SetSize(CARD_WIDTH, CARD_HEIGHT)
        btn:SetPoint("TOPLEFT", col * (CARD_WIDTH + GAP_X), -row * (CARD_HEIGHT + GAP_Y))
        
        -- Background
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
        
        -- Border
        btn:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
        })
        btn:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        
        -- Model preview
        btn.model = CreateFrame("DressUpModel", nil, btn)
        btn.model:SetSize(120, 100)
        btn.model:SetPoint("TOP", 0, -10)
        btn.model:SetFacing(0)
        
        -- Outfit name
        btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.name:SetPoint("BOTTOM", btn, "BOTTOM", 0, 45)
        btn.name:SetWidth(CARD_WIDTH - 10)
        btn.name:SetJustifyH("CENTER")
        btn.name:SetWordWrap(false)
        btn.name:SetText("")
        
        -- Author name
        btn.author = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        btn.author:SetPoint("TOP", btn.name, "BOTTOM", 0, -2)
        btn.author:SetWidth(CARD_WIDTH - 10)
        btn.author:SetJustifyH("CENTER")
        btn.author:SetText("")
        
        -- Add to My Outfits button
        btn.addBtn = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
        btn.addBtn:SetSize(100, 20)
        btn.addBtn:SetPoint("BOTTOM", 0, 8)
        btn.addBtn:SetText("+ Add to Mine")
        btn.addBtn:SetScript("OnClick", function()
            if btn.outfit and btn.outfit.id then
                if DC.Protocol and DC.Protocol.CopyCommunityOutfitToAccount then
                    DC.Protocol:CopyCommunityOutfitToAccount(btn.outfit.id)
                    DC:Print("Outfit '" .. (btn.outfit.name or "Unknown") .. "' added to your collection!")
                end
            end
        end)
        
        -- Stats (upvotes/downloads) with icons
        btn.upIcon = btn:CreateTexture(nil, "OVERLAY")
        btn.upIcon:SetSize(12, 12)
        btn.upIcon:SetPoint("TOPLEFT", btn, "TOPLEFT", 5, -5)
        btn.upIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
        btn.upIcon:SetVertexColor(0.2, 1.0, 0.2)

        btn.upText = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        btn.upText:SetPoint("LEFT", btn.upIcon, "RIGHT", 2, 0)
        btn.upText:SetText("0")

        btn.downIcon = btn:CreateTexture(nil, "OVERLAY")
        btn.downIcon:SetSize(12, 12)
        btn.downIcon:SetPoint("LEFT", btn.upText, "RIGHT", 8, 0)
        btn.downIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
        btn.downIcon:SetVertexColor(1.0, 0.2, 0.2)

        btn.downText = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        btn.downText:SetPoint("LEFT", btn.downIcon, "RIGHT", 2, 0)
        btn.downText:SetText("0")
        
        btn:Hide()
        table.insert(buttons, btn)
    end
    
    self.frame.communityButtons = buttons
    
    -- No outfits text
    local noOutfitsText = container:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    noOutfitsText:SetPoint("CENTER", 0, 0)
    noOutfitsText:SetText("No community outfits yet.\nBe the first to share yours!")
    noOutfitsText:Hide()
    self.frame.noCommunityText = noOutfitsText
end

function Wardrobe:RefreshCommunityGrid()
    local buttons = self.frame and self.frame.communityButtons
    if not buttons then
        self._pendingCommunityRefresh = true

        if not self._communityRefreshRetryFrame then
            local f = CreateFrame("Frame")
            f.elapsed = 0
            f.tries = 0
            f:SetScript("OnUpdate", function(this, elapsed)
                this.elapsed = (this.elapsed or 0) + (elapsed or 0)
                if this.elapsed < 0.05 then return end
                this.elapsed = 0
                this.tries = (this.tries or 0) + 1

                if this.tries > 40 then
                    this:SetScript("OnUpdate", nil)
                    Wardrobe._communityRefreshRetryFrame = nil
                    return
                end

                if Wardrobe and Wardrobe._pendingCommunityRefresh and type(Wardrobe.RefreshCommunityGrid) == "function" then
                    Wardrobe:RefreshCommunityGrid()
                end
            end)
            self._communityRefreshRetryFrame = f
        end

        return
    end

    self._pendingCommunityRefresh = nil
    if self._communityRefreshRetryFrame then
        self._communityRefreshRetryFrame:SetScript("OnUpdate", nil)
        self._communityRefreshRetryFrame = nil
    end
    
    -- Get community outfits from DC.db.communityOutfits (populated by OnMsg_CommunityList)
    local outfits = DC.db and DC.db.communityOutfits or {}
    local ITEMS_PER_PAGE = 6
    
    local totalOutfits = #outfits
    self.currentPage = self.currentPage or 1
    self.totalPages = math.max(1, math.ceil(totalOutfits / ITEMS_PER_PAGE))
    
    -- Show/hide no outfits message
    if totalOutfits == 0 then
        if self.frame.noCommunityText then
            self.frame.noCommunityText:Show()
        end
    else
        if self.frame.noCommunityText then
            self.frame.noCommunityText:Hide()
        end
    end
    
    -- Update shared pager
    if self.frame and self.frame.pageText then
        self.frame.pageText:SetText(string.format("Page %d / %d", self.currentPage, self.totalPages))
    end
    if self.frame and self.frame.prevBtn then
        if self.currentPage > 1 then
            if type(self.frame.prevBtn.Enable) == "function" then self.frame.prevBtn:Enable() end
        else
            if type(self.frame.prevBtn.Disable) == "function" then self.frame.prevBtn:Disable() end
        end
    end
    if self.frame and self.frame.nextBtn then
        if self.currentPage < self.totalPages then
            if type(self.frame.nextBtn.Enable) == "function" then self.frame.nextBtn:Enable() end
        else
            if type(self.frame.nextBtn.Disable) == "function" then self.frame.nextBtn:Disable() end
        end
    end
    
    if self.currentPage > self.totalPages then self.currentPage = self.totalPages end

    local startIdx = (self.currentPage - 1) * ITEMS_PER_PAGE
    
    for i, btn in ipairs(buttons) do
        local idx = startIdx + i
        local outfit = outfits[idx]
        
        if outfit then
            btn:Show()
            btn.outfit = outfit
            btn.name:SetText(outfit.name or ("Outfit #" .. idx))
            btn.author:SetText("by " .. (outfit.author or outfit.author_name or "Unknown"))
            
            -- Stats
            local upvotes = outfit.upvotes or 0
            local downloads = outfit.downloads or 0
            if btn.upText then btn.upText:SetText(tostring(upvotes)) end
            if btn.downText then btn.downText:SetText(tostring(downloads)) end
            
            -- Setup Model Preview
            btn.model:Show()
            btn.model:Undress()
            btn.model:SetUnit("player")
            btn.model:SetFacing(0)
            
            -- Try on items from the outfit
            local items = outfit.items or outfit.items_string
            if type(items) == "string" then
                -- Parse JSON string
                -- Simple pattern matching for {SlotKey: itemId, ...}
                for slot, itemId in items:gmatch('"?([^":,{}]+)"?%s*:%s*(%d+)') do
                    local link = "item:" .. itemId .. ":0:0:0:0:0:0:0"
                    btn.model:TryOn(link)
                end
            elseif type(items) == "table" then
                for _, itemId in pairs(items) do
                    local link = "item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0"
                    btn.model:TryOn(link)
                end
            end
            
            -- Tooltip
            btn:SetScript("OnEnter", function(selfBtn)
                GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                GameTooltip:SetText(selfBtn.outfit.name or "Outfit")
                GameTooltip:AddLine("by " .. (selfBtn.outfit.author or selfBtn.outfit.author_name or "Unknown"), 0.7, 0.7, 0.7)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("▲ " .. (selfBtn.outfit.upvotes or 0) .. " upvotes", 0.2, 1, 0.2)
                GameTooltip:AddLine("⬇ " .. (selfBtn.outfit.downloads or 0) .. " downloads", 0.7, 0.7, 1)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to preview", 1, 1, 0)
                GameTooltip:AddLine("Click '+ Add to Mine' to copy to your collection", 0, 1, 0)
                GameTooltip:Show()
            end)
            
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            -- Preview on main model when clicked
            btn:SetScript("OnClick", function(selfBtn)
                if self.frame and self.frame.model and selfBtn.outfit then
                    self.frame.model:Undress()
                    
                    local outfitItems = selfBtn.outfit.items or selfBtn.outfit.items_string
                    if type(outfitItems) == "string" then
                        for _, itemId in outfitItems:gmatch('"?[^":,{}]+"?%s*:%s*(%d+)') do
                            local link = "item:" .. itemId .. ":0:0:0:0:0:0:0"
                            self.frame.model:TryOn(link)
                        end
                    elseif type(outfitItems) == "table" then
                        for _, itemId in pairs(outfitItems) do
                            local link = "item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0"
                            self.frame.model:TryOn(link)
                        end
                    end
                end
            end)
        else
            btn:Hide()
        end
    end
end

-- Handle community list response from server
function DC:OnMsg_CommunityList(data)
    if not data or not data.outfits then return end
    
    DC.db = DC.db or {}
    DC.db.communityOutfits = {}
    
    for _, outfit in ipairs(data.outfits) do
        table.insert(DC.db.communityOutfits, outfit)
    end
    
    self:Debug("Received " .. #DC.db.communityOutfits .. " community outfits from server.")

    if DC.Wardrobe then
        DC.Wardrobe._pendingCommunityRefresh = true
        if DC.Wardrobe.RefreshCommunityGrid then
            DC.Wardrobe:RefreshCommunityGrid()
        end
    end
end
