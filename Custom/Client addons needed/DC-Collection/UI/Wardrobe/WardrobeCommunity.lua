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
    
    -- Reset pagination
    self.communityPage = 1
    self.communityTotalPages = 1
    
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
        
        -- Stats (upvotes/downloads)
        btn.stats = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        btn.stats:SetPoint("TOPLEFT", btn, "TOPLEFT", 5, -5)
        btn.stats:SetText("")
        
        btn:Hide()
        table.insert(buttons, btn)
    end
    
    self.frame.communityButtons = buttons
    
    -- Pagination
    local pageFrame = CreateFrame("Frame", nil, container)
    pageFrame:SetSize(200, 25)
    pageFrame:SetPoint("BOTTOM", container, "BOTTOM", 0, 8)
    
    local prevBtn = CreateFrame("Button", nil, pageFrame, "UIPanelButtonTemplate")
    prevBtn:SetSize(50, 22)
    prevBtn:SetPoint("LEFT", 0, 0)
    prevBtn:SetText("<")
    prevBtn:SetScript("OnClick", function()
        if self.communityPage > 1 then
            self.communityPage = self.communityPage - 1
            if DC.RequestCommunityList then
                DC:RequestCommunityList((self.communityPage - 1) * 6, 50, "all", "newest")
            end
            self:RefreshCommunityGrid()
        end
    end)
    self.frame.communityPrevBtn = prevBtn
    
    local nextBtn = CreateFrame("Button", nil, pageFrame, "UIPanelButtonTemplate")
    nextBtn:SetSize(50, 22)
    nextBtn:SetPoint("RIGHT", 0, 0)
    nextBtn:SetText(">")
    nextBtn:SetScript("OnClick", function()
        if self.communityPage < self.communityTotalPages then
            self.communityPage = self.communityPage + 1
            if DC.RequestCommunityList then
                DC:RequestCommunityList((self.communityPage - 1) * 6, 50, "all", "newest")
            end
            self:RefreshCommunityGrid()
        end
    end)
    self.frame.communityNextBtn = nextBtn
    
    local pageText = pageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageText:SetPoint("CENTER", 0, 0)
    pageText:SetText("Page 1 / 1")
    self.frame.communityPageText = pageText
    
    -- No outfits text
    local noOutfitsText = container:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    noOutfitsText:SetPoint("CENTER", 0, 0)
    noOutfitsText:SetText("No community outfits yet.\nBe the first to share yours!")
    noOutfitsText:Hide()
    self.frame.noCommunityText = noOutfitsText
end

function Wardrobe:RefreshCommunityGrid()
    local buttons = self.frame and self.frame.communityButtons
    if not buttons then return end
    
    -- Get community outfits from DC.db.communityOutfits (populated by OnMsg_CommunityList)
    local outfits = DC.db and DC.db.communityOutfits or {}
    local ITEMS_PER_PAGE = 6
    
    local totalOutfits = #outfits
    self.communityPage = self.communityPage or 1
    self.communityTotalPages = math.max(1, math.ceil(totalOutfits / ITEMS_PER_PAGE))
    
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
    
    -- Update pagination
    if self.frame.communityPageText then
        self.frame.communityPageText:SetText(string.format("Page %d / %d", self.communityPage, self.communityTotalPages))
    end
    if self.frame.communityPrevBtn then
        if type(self.frame.communityPrevBtn.SetEnabled) == "function" then
            self.frame.communityPrevBtn:SetEnabled(self.communityPage > 1)
        elseif self.communityPage > 1 then
            if type(self.frame.communityPrevBtn.Enable) == "function" then
                self.frame.communityPrevBtn:Enable()
            end
        else
            if type(self.frame.communityPrevBtn.Disable) == "function" then
                self.frame.communityPrevBtn:Disable()
            end
        end
    end
    if self.frame.communityNextBtn then
        if type(self.frame.communityNextBtn.SetEnabled) == "function" then
            self.frame.communityNextBtn:SetEnabled(self.communityPage < self.communityTotalPages)
        elseif self.communityPage < self.communityTotalPages then
            if type(self.frame.communityNextBtn.Enable) == "function" then
                self.frame.communityNextBtn:Enable()
            end
        else
            if type(self.frame.communityNextBtn.Disable) == "function" then
                self.frame.communityNextBtn:Disable()
            end
        end
    end
    
    local startIdx = (self.communityPage - 1) * ITEMS_PER_PAGE
    
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
            btn.stats:SetText(string.format("▲%d  ⬇%d", upvotes, downloads))
            
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
    
    if DC.Wardrobe and DC.Wardrobe.RefreshCommunityGrid then
        DC.Wardrobe:RefreshCommunityGrid()
    end
end
