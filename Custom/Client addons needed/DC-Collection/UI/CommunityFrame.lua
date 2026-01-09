--[[
    DC-Collection UI/CommunityFrame.lua
    ===================================
    
    Community Outfits tab:
    - Browse "All", "My Favorites", "My Outfits"
    - Grid view of outfits with Author, Likes, Favorites
    - Import/Apply/Favorite actions
]]

local DC = DCCollection
if not DC then return end

DC.CommunityUI = DC.CommunityUI or {}
local UI = DC.CommunityUI

local function SafeApplyLeaderboardsStyle(frame)
    if type(ApplyLeaderboardsStyle) == "function" then
        ApplyLeaderboardsStyle(frame)
    end
end

local BUTTON_SIZE = 46  -- legacy; cards will auto-size
local BUTTON_GAP = 10
local COLS = 6
local ROWS = 3
local ITEMS_PER_PAGE = COLS * ROWS

UI.outfits = {}
UI.offset = 0
UI.limit = ITEMS_PER_PAGE
UI.filter = "all" -- "all", "favorites", "mine" (mine = implementation TODO via author_guid match)

function UI:Initialize(parent, options)
    if options and type(options.onPreview) == "function" then
        self.onPreview = options.onPreview
    end

    if self.frame then
        if parent and self.frame.GetParent and self.frame:GetParent() ~= parent then
            self.frame:SetParent(parent)
            self.frame:ClearAllPoints()
            self.frame:SetAllPoints()
        end
        return
    end

    local cols = (options and tonumber(options.cols)) or COLS
    local rows = (options and tonumber(options.rows)) or ROWS
    if cols < 1 then cols = 1 end
    if rows < 1 then rows = 1 end
    local itemsPerPage = cols * rows

    self.cols = cols
    self.rows = rows

    self.limit = itemsPerPage
    self.offset = self.offset or 0
    UI.limit = itemsPerPage
    
    self.frame = CreateFrame("Frame", "DCCommunityFrame", parent)
    self.frame:SetAllPoints()
    self.frame:Hide()
    
    -- Filter Dropdown/Buttons
    local filterFrame = CreateFrame("Frame", nil, self.frame)
    filterFrame:SetPoint("TOPLEFT", 10, -10)
    filterFrame:SetSize(420, 30)
    
    self.filterButtons = {}
    local function CreateFilterButton(text, value, anchorTo)
        local btn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
        btn:SetSize(80, 22)
        if anchorTo then
            btn:SetPoint("LEFT", anchorTo, "RIGHT", 5, 0)
        else
            btn:SetPoint("LEFT", 0, 0)
        end
        btn:SetText(text)
        btn:SetScript("OnClick", function()
            UI.offset = 0
            UI:RequestList(value)
            -- Update UI state (highlight selected)
            for _, b in ipairs(UI.filterButtons) do
                if b.value == value then b:LockHighlight() else b:UnlockHighlight() end
            end
        end)
        btn.value = value
        table.insert(UI.filterButtons, btn)
        return btn
    end

    local allBtn = CreateFilterButton("All", "all")
    local favBtn = CreateFilterButton("Favorites", "favorites", allBtn)
    local mineBtn = CreateFilterButton("My Outfits", "mine", favBtn)
    
    -- Tag Search Box
    local searchBox = CreateFrame("EditBox", "DCCommunitySearchBox", self.frame, "InputBoxTemplate")
    searchBox:SetSize(140, 20)
    searchBox:SetPoint("LEFT", mineBtn, "RIGHT", 10, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetText("Search Tags...")
    searchBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" and text ~= "Search Tags..." then
            UI.offset = 0
            UI.currentTag = text
            UI:RequestList("tag:" .. text)
        else
             UI.currentTag = nil
             UI:RequestList(UI.filter) -- Revert to base filter
        end
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == "Search Tags..." then self:SetText("") end
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then self:SetText("Search Tags...") end
    end)
    
    -- Refresh Button
    local refreshBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(70, 22)
    refreshBtn:SetPoint("TOPRIGHT", -10, -10)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function() UI:RequestList() end)
    
    -- Publish Button
    local publishBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    publishBtn:SetSize(70, 22)
    publishBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -5, 0)
    publishBtn:SetText("Publish")
    publishBtn:SetScript("OnClick", function() UI:ShowPublishPopup() end)
    
    -- Grid Container
    self.gridFrame = CreateFrame("Frame", nil, self.frame)
    self.gridFrame:SetPoint("TOPLEFT", 10, -50)
    self.gridFrame:SetPoint("BOTTOMRIGHT", -10, 40)
    
    local function ParseItemIds(itemsString)
        -- Extract item IDs from JSON-like string: {"ChestSlot":40495,"HeadSlot":51495,...}
        local ids = {}
        if type(itemsString) ~= "string" then
            return ids
        end
        -- Match slot:value pairs and extract the numeric values
        for id in string.gmatch(itemsString, ':%s*(%d+)') do
            local numId = tonumber(id)
            if numId and numId > 0 then
                table.insert(ids, numId)
            end
        end
        return ids
    end

    local function TryRenderOutfitOnModel(model, itemsString)
        if not model or type(model.SetUnit) ~= "function" then
            return
        end

        model:SetUnit("player")
        if model.Undress then
            model:Undress()
        end

        -- The itemsString contains item IDs (not displayIds), so use them directly for TryOn
        local itemIds = ParseItemIds(itemsString)
        for _, itemId in ipairs(itemIds) do
            if itemId and itemId > 0 and model.TryOn then
                pcall(function()
                    model:TryOn(itemId)
                end)
            end
        end

        if model.SetPosition then
            model:SetPosition(1.5, 0, 0)
        end
        if model.SetFacing then
            model:SetFacing(0)
        end
    end

    local function IsOutfitOwner(outfit)
        if not outfit then
            return false
        end

        -- Preferred: server provides account-wide ownership
        if outfit.is_owner ~= nil then
            return outfit.is_owner == true or outfit.is_owner == 1
        end

        -- Legacy fallback: compare character guid counter to author_guid
        local myGuid = UnitGUID("player")
        local authorGuid = outfit.author_guid
        if myGuid and authorGuid then
            local myGuidNum = tonumber(string.sub(myGuid, -8), 16)
            if myGuidNum and myGuidNum == authorGuid then
                return true
            end
        end
        return false
    end

    self.buttons = {}
    for i = 1, itemsPerPage do
        local btn = CreateFrame("Button", "DCCommunityOutfitButton"..i, self.gridFrame)
        btn:SetSize(200, 160) -- real size set by LayoutGrid()

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        btn:SetBackdropColor(0, 0, 0, 0)

        SafeApplyLeaderboardsStyle(btn)
        
        btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.highlight:SetAllPoints()
        btn.highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        btn.highlight:SetBlendMode("ADD")
        
        -- Name (top of box)
        btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.name:SetPoint("TOPLEFT", btn, "TOPLEFT", 10, -8)
        btn.name:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -10, -8)
        btn.name:SetJustifyH("CENTER")
        btn.name:SetWordWrap(false)
        btn.name:SetText("")

        -- 3D preview (fills the card under the name)
        btn.model = CreateFrame("DressUpModel", nil, btn)
        btn.model:SetPoint("TOPLEFT", btn, "TOPLEFT", 10, -26)
        btn.model:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -10, 10)
        btn.model:SetUnit("player")
        
        -- Favorite Icon (Overlay)
        btn.fav = CreateFrame("Button", nil, btn)
        btn.fav:SetSize(16, 16)
        btn.fav:SetPoint("TOPRIGHT", 4, 4)
        btn.fav.tex = btn.fav:CreateTexture(nil, "ARTWORK")
        btn.fav.tex:SetAllPoints()
        btn.fav.tex:SetTexture("Interface\\AddOns\\DC-Collection\\Textures\\star_empty.tga") -- Placeholder path? Use standard icons
        -- Use standard star
        btn.fav.tex:SetTexture("Interface\\Common\\ReputationStar")
        btn.fav.tex:SetTexCoord(0, 0.5, 0, 0.5) -- Half star or similar?
        -- Actually, use WorldMap\\TreasureChest_Open for now or similar.
        -- Let's use generic star or circle.
        -- "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" (Star)
        btn.fav.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
        
        btn.fav:SetScript("OnClick", function()
             if not btn.data then return end
             local newStatus = not btn.data.is_favorite
             UI:ToggleFavorite(btn.data.id, newStatus)
        end)
        
        -- Upvote button
        btn.upvoteBtn = CreateFrame("Button", nil, btn)
        btn.upvoteBtn:SetSize(16, 16)
        btn.upvoteBtn:SetPoint("TOPLEFT", 4, -4)
        btn.upvoteBtn.tex = btn.upvoteBtn:CreateTexture(nil, "ARTWORK")
        btn.upvoteBtn.tex:SetAllPoints()
        btn.upvoteBtn.tex:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
        btn.upvoteBtn.tex:SetVertexColor(0.2, 1.0, 0.2)
        btn.upvoteBtn:SetScript("OnClick", function()
            if not btn.data then return end
            DC:RequestCommunityRate(btn.data.id)
            DC:Print("Upvoted outfit: " .. (btn.data.name or "Unknown"))
            -- Update local count for immediate feedback
            btn.data.upvotes = (btn.data.upvotes or 0) + 1
            UI:UpdateGrid()
        end)
        btn.upvoteBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(btn.upvoteBtn, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Upvote this outfit", 1, 1, 1)
            GameTooltip:AddLine("Upvotes: " .. (btn.data and btn.data.upvotes or 0), 0.2, 1.0, 0.2)
            GameTooltip:Show()
        end)
        btn.upvoteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        -- Edit button (for owner only - visibility controlled in Render)
        btn.editBtn = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
        btn.editBtn:SetSize(40, 16)
        btn.editBtn:SetPoint("TOPRIGHT", -4, -4)
        btn.editBtn:SetText("Edit")
        btn.editBtn:SetScript("OnClick", function()
            if not btn.data then return end
            UI:ShowEditPopup(btn.data)
        end)
        btn.editBtn:Hide() -- Hidden by default, shown for owner
        
        -- Scripts
        btn:SetScript("OnEnter", function()
            if not btn.data then return end
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:AddLine(btn.data.name, 1, 1, 1)
            GameTooltip:AddLine("Author: " .. (btn.data.author or btn.data.author_name or "Unknown"), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("+" .. (btn.data.upvotes or 0) .. " upvotes", 0.2, 1.0, 0.2)
            GameTooltip:AddLine((btn.data.downloads or 0) .. " downloads", 0.7, 0.7, 1.0)
            GameTooltip:AddLine((btn.data.views or 0) .. " views", 0.7, 0.7, 0.7)
            if btn.data.created_at then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Created: " .. btn.data.created_at, 0.5, 0.5, 0.5)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to Preview", 1, 0.8, 0)
            GameTooltip:AddLine("Right-click to Apply", 0, 1, 0)
            if IsOutfitOwner(btn.data) then
                GameTooltip:AddLine("Shift+Right-click to Delete", 1, 0.3, 0.3)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        btn:SetScript("OnClick", function(self, button)
            if not self.data then return end

            if button == "RightButton" then
                -- Check for Shift+Right-click = Delete (owner only)
                if IsShiftKeyDown() then
                    if not IsOutfitOwner(self.data) then
                        DC:Print("You can only delete outfits published by your account.")
                        return
                    end

                    -- Confirm delete
                    if not StaticPopupDialogs["DC_COMMUNITY_DELETE_CONFIRM"] then
                        StaticPopupDialogs["DC_COMMUNITY_DELETE_CONFIRM"] = {
                            text = "Delete community outfit?",
                            button1 = "Delete",
                            button2 = "Cancel",
                            timeout = 0,
                            whileDead = true,
                            hideOnEscape = true,
                            preferredIndex = 3,
                        }
                    end
                    StaticPopupDialogs["DC_COMMUNITY_DELETE_CONFIRM"].text =
                        "Delete community outfit\n|cFFFFFF00" .. (self.data.name or "Unknown") .. "|r?"
                    StaticPopupDialogs["DC_COMMUNITY_DELETE_CONFIRM"].OnAccept = function()
                        if DC.RequestCommunityDelete then
                            DC:RequestCommunityDelete(self.data.id)
                        end
                    end
                    StaticPopup_Show("DC_COMMUNITY_DELETE_CONFIRM")
                    return
                end
                
                -- Regular right-click = Apply
                if DC.ApplyCommunityOutfit and self.data.items then
                    DC:ApplyCommunityOutfit(self.data.items)
                end
                return
            end

            -- Preview
            if UI.onPreview and self.data.items then
                UI.onPreview(self.data.name, self.data.items, self.data.id)
            elseif DC.PreviewCommunityOutfit and self.data.items then
                DC:PreviewCommunityOutfit(self.data.name, self.data.items, self.data.id)
            end
        end)

        btn.LayoutGrid = function(selfBtn, cellW, cellH, x, y)
            selfBtn:ClearAllPoints()
            selfBtn:SetPoint("TOPLEFT", x, y)
            selfBtn:SetSize(cellW, cellH)
        end

        btn.Render = function(selfBtn)
            if not selfBtn.data then
                if selfBtn.editBtn then selfBtn.editBtn:Hide() end
                return
            end

            local itemsString = selfBtn.data.items
            if itemsString and itemsString ~= selfBtn._lastItemsString then
                selfBtn._lastItemsString = itemsString
                TryRenderOutfitOnModel(selfBtn.model, itemsString)
            end
            
            -- Show edit button if this outfit belongs to the current player
            if selfBtn.editBtn then
                if IsOutfitOwner(selfBtn.data) then
                    selfBtn.editBtn:Show()
                else
                    selfBtn.editBtn:Hide()
                end
            end
        end
        
        table.insert(self.buttons, btn)
    end

    function UI:LayoutGrid()
        if not self.gridFrame or not self.buttons then
            return
        end

        local gridW = self.gridFrame:GetWidth() or 0
        local gridH = self.gridFrame:GetHeight() or 0
        local c = self.cols or cols
        local r = self.rows or rows
        if gridW <= 0 or gridH <= 0 or c < 1 or r < 1 then
            return
        end

        local gap = BUTTON_GAP
        local cellW = math.floor((gridW - (c - 1) * gap) / c)
        local cellH = math.floor((gridH - (r - 1) * gap) / r)
        if cellW < 120 then cellW = 120 end
        if cellH < 120 then cellH = 120 end

        for i, btn in ipairs(self.buttons) do
            local col = (i - 1) % c
            local row = math.floor((i - 1) / c)
            local x = col * (cellW + gap)
            local y = -row * (cellH + gap)
            if btn.LayoutGrid then
                btn:LayoutGrid(cellW, cellH, x, y)
            end
        end
    end

    self.gridFrame:SetScript("OnShow", function() UI:LayoutGrid() end)
    self.gridFrame:SetScript("OnSizeChanged", function() UI:LayoutGrid() end)
    
    -- Paging Controls
    local pagingFrame = CreateFrame("Frame", nil, self.frame)
    pagingFrame:SetSize(200, 30)
    pagingFrame:SetPoint("BOTTOM", 0, 10)
    
    self.prevBtn = CreateFrame("Button", nil, pagingFrame, "UIPanelButtonTemplate")
    self.prevBtn:SetSize(30, 22)
    self.prevBtn:SetPoint("LEFT", 0, 0)
    self.prevBtn:SetText("<")
    self.prevBtn:SetScript("OnClick", function()
        if UI.offset >= (UI.limit or itemsPerPage) then
            UI.offset = UI.offset - (UI.limit or itemsPerPage)
            UI:RequestList()
        end
    end)
    
    self.nextBtn = CreateFrame("Button", nil, pagingFrame, "UIPanelButtonTemplate")
    self.nextBtn:SetSize(30, 22)
    self.nextBtn:SetPoint("RIGHT", 0, 0)
    self.nextBtn:SetText(">")
    self.nextBtn:SetScript("OnClick", function()
        UI.offset = UI.offset + (UI.limit or itemsPerPage)
        UI:RequestList()
    end)
    
    self.pageText = pagingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.pageText:SetPoint("CENTER", pagingFrame, "CENTER")
    self.pageText:SetText("Page 1")
    
end

function UI:ToggleFavorite(outfitId, add)
    DC:RequestCommunityFavorite(outfitId, add)
end

function UI:RequestList(filter)
    local f = filter or self.filter
    -- If using search box, use that
    if self.currentTag then f = "tag:" .. self.currentTag end
    
    self.filter = f
    DC:RequestCommunityList(self.offset, self.limit, self.filter)
end

function UI:OnListReceived(outfits)
    self.outfits = outfits or {}
    self:UpdateGrid()
end

function UI:OnFavoriteResult(outfitId, isAdd)
    DC:Print("Favorite " .. (isAdd and "added" or "removed") .. ".")
    -- Update local state if found
    for _, outfit in ipairs(self.outfits) do
        if outfit.id == outfitId then
            outfit.is_favorite = isAdd -- Or handle "is_favorite" field from server?
            -- Wait, "is_favorite" isn't strictly in SMSG_COMMUNITY_LIST yet based on my C++ code?
            -- Actually C++ code sends "id, author_name, name, items, likes, time". 
            -- I need to update C++ to send "is_favorite" if filtering?
            -- Or handle it client side?
            -- It's better if server sends it.
            -- I updated C++ HandleCommunityGetList to JOIN favorites if filter="favorites".
            -- But if filter="all", I don't get is_favorite status unless I LEFT JOIN.
            -- For now, let's assume we toggle it locally for UI feedback.
            break
        end 
    end
    self:UpdateGrid()
    
    -- If we are in "favorites" view and removed one, we should probably refresh list
    if self.filter == "favorites" and not isAdd then
         self:RequestList()
    end
end

function UI:UpdateGrid()
    if not self.buttons then return end
    
    for i, btn in ipairs(self.buttons) do
        local outfit = self.outfits[i]
        if outfit then
            btn:Show()
            btn.data = outfit
            btn.name:SetText(outfit.name or "")

            -- Update Favorite Star
            -- If filter is favorites, all are favorites.
            -- If filter is all, we might not know unless server sends it.
            -- For this iteration, show Star if filter==favorites.
            -- To do it properly, I need to update C++ to always check favorite status.
            local isFav = (self.filter == "favorites") 
            if outfit.is_favorite ~= nil then isFav = outfit.is_favorite end 
            
            if isFav then
                 btn.fav:SetAlpha(1)
                 btn.fav.tex:SetVertexColor(1, 1, 0) -- Yellow
            else
                 btn.fav:SetAlpha(0.3)
                 btn.fav.tex:SetVertexColor(1, 1, 1) -- Grey
            end

            if btn.Render then
                btn:Render()
            end
            
        else
            btn:Hide()
            btn.data = nil
        end
    end
    
    local perPage = self.limit or UI.limit or ITEMS_PER_PAGE
    local page = math.floor((self.offset or 0) / perPage) + 1
    self.pageText:SetText("Page " .. page)
    
    if (self.offset or 0) == 0 then self.prevBtn:Disable() else self.prevBtn:Enable() end
    -- Next button logic depends on if we got full page
    if #self.outfits < perPage then self.nextBtn:Disable() else self.nextBtn:Enable() end

end

-- Helper to preview (requires Core.lua helper)
function DC:PreviewCommunityOutfit(name, itemsString, outfitId)
     -- Parse itemsString "123 456 789"
     local items = {}
     for id in string.gmatch(itemsString, "%d+") do
         table.insert(items, tonumber(id))
     end
     DC:PreviewOutfitRaw(items) -- Assumes this comes from existing logic, or I need to write it
     
     if outfitId and DC.RequestCommunityView then
         DC:RequestCommunityView(outfitId)
     end
end

function DC:ApplyCommunityOutfit(itemsString)
    DC:Print("Applying community outfit...")
    
    local items = {}
    for id in string.gmatch(itemsString, "%d+") do
        table.insert(items, tonumber(id))
    end
    
    local missing = {}
    local collected = {}
    
    for _, itemID in ipairs(items) do
        -- Check if item is collected (transmog)
        -- Assuming DC.collections.transmog[itemID] is true if collected
        -- This logic assumes itemID is the key. 
        if DC.collections and DC.collections.transmog and DC.collections.transmog[itemID] then
             table.insert(collected, itemID)
        else
             table.insert(missing, itemID)
        end
    end
    
    -- Apply collected (Placeholder for actual equip logic)
    if #collected > 0 then
         if DC.EquipOutfitRaw then
            DC:EquipOutfitRaw(collected)
            DC:Print("Applied " .. #collected .. " items.")
         else
            DC:Print("Would apply " .. #collected .. " items (Equip logic missing).")
         end
    end
    
    -- Report missing
    if #missing > 0 then
        DC:Print("You are missing " .. #missing .. " items:")
        for _, id in ipairs(missing) do
             local name, link = GetItemInfo(id)
             if not link then link = "Item " .. id end
             DC:Print("- " .. link .. "  |cff00ccff|Hdc:wishlist:" .. id .. "|h[Add to Wishlist]|h|r")
        end
    end
end

function UI:ShowPublishPopup()
    UI:ShowCustomPublishFrame()
end

function UI:ShowCustomPublishFrame()
    if not self.publishFrame then
        local f = CreateFrame("Frame", "DCPublishFrame", self.frame)
        f:SetSize(300, 180)
        f:SetPoint("CENTER")
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f:SetFrameStrata("DIALOG")
        
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -15)
        title:SetText("Publish Outfit")
        
        local lblName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lblName:SetPoint("TOPLEFT", 20, -40)
        lblName:SetText("Outfit Name:")
        
        local nameBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        nameBox:SetSize(250, 20)
        nameBox:SetPoint("TOPLEFT", lblName, "BOTTOMLEFT", 0, -5)
        nameBox:SetAutoFocus(true)
        f.nameBox = nameBox
        
        local lblTags = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lblTags:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -10)
        lblTags:SetText("Tags (comma separated):")
        
        local tagsBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        tagsBox:SetSize(250, 20)
        tagsBox:SetPoint("TOPLEFT", lblTags, "BOTTOMLEFT", 0, -5)
        f.tagsBox = tagsBox
        
        local btnPub = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btnPub:SetSize(100, 25)
        btnPub:SetPoint("BOTTOMLEFT", 30, 20)
        btnPub:SetText("Publish")
        btnPub:SetScript("OnClick", function()
             local name = nameBox:GetText()
             local tags = tagsBox:GetText()
             if name and name ~= "" then
                 -- Get current items
                 local items = DC:GetOutfitItems() -- Use existing helper
                 if items then
                     -- Convert to string "id,id,id"
                     local str = table.concat(items, ",")
                     DC:RequestCommunityPublish(name, str, tags)
                     f:Hide()
                 else
                     DC:Print("No items found to publish.")
                 end
             end
        end)
        
        local btnCancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btnCancel:SetSize(100, 25)
        btnCancel:SetPoint("BOTTOMRIGHT", -30, 20)
        btnCancel:SetText("Cancel")
        btnCancel:SetScript("OnClick", function() f:Hide() end)
        
        self.publishFrame = f
    end
    self.publishFrame:Show()
    self.publishFrame.nameBox:SetText("")
    self.publishFrame.tagsBox:SetText("")
    self.publishFrame.nameBox:SetFocus()
end

function UI:ShowEditPopup(outfit)
    if not outfit then return end
    
    if not self.editFrame then
        local f = CreateFrame("Frame", "DCEditOutfitFrame", UIParent)
        f:SetSize(320, 220)
        f:SetPoint("CENTER")
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -15)
        title:SetText("Edit Community Outfit")
        f.title = title
        
        local lblName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lblName:SetPoint("TOPLEFT", 20, -45)
        lblName:SetText("Outfit Name:")
        
        local nameBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        nameBox:SetSize(270, 20)
        nameBox:SetPoint("TOPLEFT", lblName, "BOTTOMLEFT", 0, -5)
        nameBox:SetAutoFocus(false)
        f.nameBox = nameBox
        
        local lblTags = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lblTags:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -10)
        lblTags:SetText("Tags (comma separated):")
        
        local tagsBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        tagsBox:SetSize(270, 20)
        tagsBox:SetPoint("TOPLEFT", lblTags, "BOTTOMLEFT", 0, -5)
        f.tagsBox = tagsBox
        
        local updateItemsCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        updateItemsCheck:SetPoint("TOPLEFT", tagsBox, "BOTTOMLEFT", -5, -10)
        updateItemsCheck.text = updateItemsCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        updateItemsCheck.text:SetPoint("LEFT", updateItemsCheck, "RIGHT", 0, 0)
        updateItemsCheck.text:SetText("Update items to current transmog")
        f.updateItemsCheck = updateItemsCheck
        
        local btnSave = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btnSave:SetSize(100, 25)
        btnSave:SetPoint("BOTTOMLEFT", 30, 20)
        btnSave:SetText("Save")
        btnSave:SetScript("OnClick", function()
            local name = nameBox:GetText()
            local tags = tagsBox:GetText()
            local updateItems = updateItemsCheck:GetChecked()
            
            if not name or name == "" then
                DC:Print("Please enter a name.")
                return
            end
            
            local itemsStr = f.originalItems
            if updateItems then
                local currentItems = DC:GetOutfitItems()
                if currentItems then
                    itemsStr = table.concat(currentItems, ",")
                end
            end
            
            DC:RequestCommunityUpdate(f.outfitId, name, itemsStr, tags)
            f:Hide()
        end)
        
        local btnCancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btnCancel:SetSize(100, 25)
        btnCancel:SetPoint("BOTTOMRIGHT", -30, 20)
        btnCancel:SetText("Cancel")
        btnCancel:SetScript("OnClick", function() f:Hide() end)
        
        self.editFrame = f
    end
    
    -- Populate with outfit data
    self.editFrame.outfitId = outfit.id
    self.editFrame.originalItems = outfit.items
    self.editFrame.nameBox:SetText(outfit.name or "")
    self.editFrame.tagsBox:SetText(outfit.tags or "")
    self.editFrame.updateItemsCheck:SetChecked(false)
    self.editFrame:Show()
    self.editFrame.nameBox:SetFocus()
end
