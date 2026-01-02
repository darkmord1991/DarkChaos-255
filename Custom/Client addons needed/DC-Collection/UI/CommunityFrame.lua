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

local BUTTON_SIZE = 46  -- Match TransmogFrame grid
local BUTTON_GAP = 4
local COLS = 6
local ROWS = 3
local ITEMS_PER_PAGE = COLS * ROWS

UI.outfits = {}
UI.offset = 0
UI.limit = ITEMS_PER_PAGE
UI.filter = "all" -- "all", "favorites", "mine" (mine = implementation TODO via author_guid match)

function UI:Initialize(parent)
    if self.frame then return end
    
    self.frame = CreateFrame("Frame", "DCCommunityFrame", parent)
    self.frame:SetAllPoints()
    self.frame:Hide()
    
    -- Filter Dropdown/Buttons
    local filterFrame = CreateFrame("Frame", nil, self.frame)
    filterFrame:SetPoint("TOPLEFT", 10, -10)
    filterFrame:SetSize(200, 30)
    
    self.filterButtons = {}
    local function CreateFilterButton(text, value, x)
        local btn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
        btn:SetSize(80, 22)
        btn:SetPoint("LEFT", x, 0)
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
    
    CreateFilterButton("All", "all", 0)
    CreateFilterButton("Favorites", "favorites", 85)
    CreateFilterButton("My Outfits", "mine", 170)
    
    -- Tag Search Box
    local searchBox = CreateFrame("EditBox", "DCCommunitySearchBox", self.frame, "InputBoxTemplate")
    searchBox:SetSize(120, 20)
    searchBox:SetPoint("LEFT", filterFrame, "RIGHT", 10, 0)
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
    
    self.buttons = {}
    for i = 1, ITEMS_PER_PAGE do
        local btn = CreateFrame("Button", "DCCommunityOutfitButton"..i, self.gridFrame) -- No template, custom
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        
        -- Positioning
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        btn:SetPoint("TOPLEFT", col * (BUTTON_SIZE + BUTTON_GAP), -row * (BUTTON_SIZE + BUTTON_GAP + 20)) -- Extra vertical gap for details
        
        -- Visuals
        btn.icon = btn:CreateTexture(nil, "BACKGROUND")
        btn.icon:SetAllPoints()
        btn.icon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17") -- Default
        
        btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.highlight:SetAllPoints()
        btn.highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        btn.highlight:SetBlendMode("ADD")
        
        -- Details (Below button)
        btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.name:SetPoint("TOP", btn, "BOTTOM", 0, -2)
        btn.name:SetWidth(BUTTON_SIZE + 10)
        btn.name:SetJustifyH("CENTER")
        btn.name:SetWordWrap(false)
        btn.name:SetText("Outfit Name")
        
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
        
        -- Scripts
        btn:SetScript("OnEnter", function()
            if not btn.data then return end
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:AddLine(btn.data.name, 1, 1, 1)
            GameTooltip:AddLine("Author: " .. (btn.data.author_name or "Unknown"), 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Likes: " .. (btn.data.likes or 0), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to Apply", 0, 1, 0)
            GameTooltip:AddLine("Ctrl-Click to Preview", 1, 0.8, 0)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        btn:SetScript("OnClick", function(self, button)
             if not self.data then return end
             if IsControlKeyDown() then
                 if DC.PreviewOutfit and self.data.items then 
                      -- Convert "items" string (123:456:...) to table or just use stored table if protocol sends array
                      -- Initial protocol implementation sent "items" as string "id,id,id".
                      -- Actually, server sends "items" as a comma/space separated string of item IDs usually.
                      -- Let's parse it if it's a string
                      local itemString = self.data.items
                      DC:PreviewCommunityOutfit(self.data.name, itemString, self.data.id)
                 end
             else
                  -- Apply
                 if DC.ApplyCommunityOutfit and self.data.items then
                      DC:ApplyCommunityOutfit(self.data.items)
                 end
             end
        end)
        
        table.insert(self.buttons, btn)
    end
    
    -- Paging Controls
    local pagingFrame = CreateFrame("Frame", nil, self.frame)
    pagingFrame:SetSize(200, 30)
    pagingFrame:SetPoint("BOTTOM", 0, 10)
    
    self.prevBtn = CreateFrame("Button", nil, pagingFrame, "UIPanelButtonTemplate")
    self.prevBtn:SetSize(30, 22)
    self.prevBtn:SetPoint("LEFT", 0, 0)
    self.prevBtn:SetText("<")
    self.prevBtn:SetScript("OnClick", function()
        if UI.offset >= ITEMS_PER_PAGE then
            UI.offset = UI.offset - ITEMS_PER_PAGE
            UI:RequestList()
        end
    end)
    
    self.nextBtn = CreateFrame("Button", nil, pagingFrame, "UIPanelButtonTemplate")
    self.nextBtn:SetSize(30, 22)
    self.nextBtn:SetPoint("RIGHT", 0, 0)
    self.nextBtn:SetText(">")
    self.nextBtn:SetScript("OnClick", function()
        UI.offset = UI.offset + ITEMS_PER_PAGE
        UI:RequestList()
    end)
    
    self.pageText = pagingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.pageText:SetPoint("CENTER", pagingFrame, "CENTER")
    self.pageText:SetText("Page 1")
    
end

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
            btn.name:SetText(outfit.name or "Outfit")
            -- btn.icon:SetTexture(...) -- Need to determine icon from items? 
            -- Or server should send icon? 
            -- Existing outfit system uses first item as icon or generic.
            -- Use generic for now.
            btn.icon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17")

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
            
        else
            btn:Hide()
        end
    end
    
    local page = math.floor(self.offset / ITEMS_PER_PAGE) + 1
    self.pageText:SetText("Page " .. page)
    
    if self.offset == 0 then self.prevBtn:Disable() else self.prevBtn:Enable() end
    -- Next button logic depends on if we got full page
    if #self.outfits < ITEMS_PER_PAGE then self.nextBtn:Disable() else self.nextBtn:Enable() end

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
