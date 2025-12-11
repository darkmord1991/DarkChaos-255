-------------------------------------------------------------------------------------------------------------
--
-- AzerothAdmin Version 3.x
--
-------------------------------------------------------------------------------------------------------------

function AzerothAdmin:CreateDCTeleSection()
  -- Initialize storage for dynamic teleports
    AzerothAdmin.DCTeleports = AzerothAdmin.DCTeleports or {}
    -- Keep the main teleport table ordered by id for consistency
    if type(AzerothAdmin.DCTeleports) == "table" and #AzerothAdmin.DCTeleports > 0 then
        local dir = AzerothAdmin.db and AzerothAdmin.db.account and AzerothAdmin.db.account.dctele and AzerothAdmin.db.account.dctele.sortDir or "asc"
        if AzerothAdmin.db and AzerothAdmin.db.account and AzerothAdmin.db.account.dctele and AzerothAdmin.db.account.dctele.sortBy == "name" then
          table.sort(AzerothAdmin.DCTeleports, function(a, b)
            local an = string.lower(a.name or "")
            local bn = string.lower(b.name or "")
            if an == bn then
              local aid = (a.id or a.ID or a.Id) or 0
              local bid = (b.id or b.ID or b.Id) or 0
              if dir == "asc" then return aid < bid else return aid > bid end
            end
            if dir == "asc" then return an < bn else return an > bn end
          end)
        else
          table.sort(AzerothAdmin.DCTeleports, function(a, b)
            local aid = (a.id or a.ID or a.Id) or 0
            local bid = (b.id or b.ID or b.Id) or 0
            if dir == "asc" then return aid < bid else return aid > bid end
          end)
        end
    end

  -- Register Protocol Handler for Teleport List (TELE module, opcode 0x10)
  if DC and DC.RegisterHandler then
      DC:RegisterHandler("TELE", 0x10, function(data)
            if data and data.list then
              AzerothAdmin.DCTeleports = data.list
              if type(AzerothAdmin.DCTeleports) == "table" and #AzerothAdmin.DCTeleports > 0 then
                local dir = (AzerothAdmin.db and AzerothAdmin.db.account and AzerothAdmin.db.account.dctele and AzerothAdmin.db.account.dctele.sortDir) or "asc"
                if AzerothAdmin.db and AzerothAdmin.db.account and AzerothAdmin.db.account.dctele and AzerothAdmin.db.account.dctele.sortBy == "name" then
                  table.sort(AzerothAdmin.DCTeleports, function(a, b)
                    local an = string.lower(a.name or "")
                    local bn = string.lower(b.name or "")
                    if an == bn then
                      local aid = (a.id or a.ID or a.Id) or 0
                      local bid = (b.id or b.ID or b.Id) or 0
                      if dir == "asc" then return aid < bid else return aid > bid end
                    end
                    if dir == "asc" then return an < bn else return an > bn end
                  end)
                else
                  table.sort(AzerothAdmin.DCTeleports, function(a, b)
                    local aid = (a.id or a.ID or a.Id) or 0
                    local bid = (b.id or b.ID or b.Id) or 0
                    if dir == "asc" then return aid < bid else return aid > bid end
                  end)
                end
              end
              AzerothAdmin:UpdateDCTeleList()
            end
      end)
  end

  local transparency = {
    bg = AzerothAdmin.db.account.style.transparency.backgrounds,
    btn = AzerothAdmin.db.account.style.transparency.buttons,
    frm = AzerothAdmin.db.account.style.transparency.frames
  }
  local color = {
    bg = AzerothAdmin.db.account.style.color.backgrounds,
    btn = AzerothAdmin.db.account.style.color.buttons,
    frm = AzerothAdmin.db.account.style.color.frames
  }

  FrameLib:BuildFrame({
    name = "ma_dctele_window",
    parent = UIParent,
    texture = {
      color = {color.bg.r, color.bg.g, color.bg.b, transparency.bg}
    },
    size = {
      width = 400,
      height = 500
    },
    setpoint = {
      pos = "CENTER"
    },
    draggable = true,
    hidden = true
  })
  
  -- Sorting default (persisted)
  AzerothAdmin.db.account.dctele = AzerothAdmin.db.account.dctele or {}
  AzerothAdmin.db.account.dctele.sortBy = AzerothAdmin.db.account.dctele.sortBy or "id"
  AzerothAdmin.db.account.dctele.sortDir = AzerothAdmin.db.account.dctele.sortDir or "asc"
  AzerothAdmin.DCTeleSortBy = AzerothAdmin.db.account.dctele.sortBy
  AzerothAdmin.DCTeleSortDir = AzerothAdmin.db.account.dctele.sortDir

  -- Request list when window opens
  ma_dctele_window:SetScript("OnShow", function()
      if DC and DC.Request then
          DC:Request("TELE", 0x01, {}) -- Request list (CMSG_REQUEST_LIST)
      end
      AzerothAdmin:UpdateDCTeleList()
  end)
  
  FrameLib:BuildFontString({
    name = "ma_dctele_title",
    parent = ma_dctele_window,
    text = "DC Teleports",
    setpoint = {
      pos = "TOP",
      offY = -10
    }
  })

  FrameLib:BuildButton({
    name = "ma_dctele_close",
    parent = ma_dctele_window,
    texture = {
      color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn}
    },
    size = { width = 20, height = 20 },
    setpoint = { pos = "TOPRIGHT", offX = -5, offY = -5 },
    text = "X"
  })
  AzerothAdmin:PrepareScript(ma_dctele_close, "Close", function() ma_dctele_window:Hide() end)

  FrameLib:BuildEditBox({
    name = "ma_dctele_search",
    parent = ma_dctele_window,
    size = { width = 350, height = 20 },
    setpoint = { pos = "TOPLEFT", offX = 10, offY = -35 },
    text = ""
  })
  ma_dctele_search:SetScript("OnTextChanged", function(self) AzerothAdmin:UpdateDCTeleList() end)

  -- Column headers for sorting
  FrameLib:BuildButton({
    name = "ma_dctele_col_name",
    parent = ma_dctele_window,
    size = { width = 270, height = 18 },
    setpoint = { pos = "TOPLEFT", relTo = "ma_dctele_search", relPos = "BOTTOMLEFT", offY = -4, offX = 0 },
    text = "Name (Map)" .. (AzerothAdmin.DCTeleSortBy == "name" and (AzerothAdmin.DCTeleSortDir == "asc" and " ▲" or " ▼") or ""),
    texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }
  })
        ma_dctele_col_name:SetScript("OnClick", function(self)
        if AzerothAdmin.DCTeleSortBy == "name" then
          -- Toggle direction
          AzerothAdmin.DCTeleSortDir = (AzerothAdmin.DCTeleSortDir == "asc") and "desc" or "asc"
        else
          AzerothAdmin.DCTeleSortBy = "name"
          AzerothAdmin.DCTeleSortDir = "asc"
        end
        AzerothAdmin.db.account.dctele.sortBy = AzerothAdmin.DCTeleSortBy
        AzerothAdmin.db.account.dctele.sortDir = AzerothAdmin.DCTeleSortDir
        AzerothAdmin:UpdateDCTeleList()
        end)
        ma_dctele_col_name:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText("Sort by Name (Map)")
          GameTooltip:AddLine("Click to toggle ascending/descending order.")
          GameTooltip:Show()
        end)
        ma_dctele_col_name:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

  FrameLib:BuildButton({
    name = "ma_dctele_col_id",
    parent = ma_dctele_window,
    size = { width = 70, height = 18 },
    setpoint = { pos = "TOPLEFT", relTo = "ma_dctele_col_name", relPos = "TOPRIGHT", offX = 6, offY = 0 },
    text = "ID" .. (AzerothAdmin.DCTeleSortBy == "id" and (AzerothAdmin.DCTeleSortDir == "asc" and " ▲" or " ▼") or ""),
    texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }
  })
        ma_dctele_col_id:SetScript("OnClick", function(self)
        if AzerothAdmin.DCTeleSortBy == "id" then
          AzerothAdmin.DCTeleSortDir = (AzerothAdmin.DCTeleSortDir == "asc") and "desc" or "asc"
        else
          AzerothAdmin.DCTeleSortBy = "id"
          AzerothAdmin.DCTeleSortDir = "asc"
        end
        AzerothAdmin.db.account.dctele.sortBy = AzerothAdmin.DCTeleSortBy
        AzerothAdmin.db.account.dctele.sortDir = AzerothAdmin.DCTeleSortDir
        AzerothAdmin:UpdateDCTeleList()
        end)
        ma_dctele_col_id:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText("Sort by ID")
          GameTooltip:AddLine("Click to toggle ascending/descending order.")
          GameTooltip:Show()
        end)
        ma_dctele_col_id:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

      -- Adjust font and alignment for clarity
      local fsn = ma_dctele_col_name:GetFontString()
      if fsn then
        fsn:SetJustifyH("LEFT")
        fsn:SetFontObject("GameFontNormalSmall")
      end
      local fsi = ma_dctele_col_id:GetFontString()
      if fsi then
        fsi:SetJustifyH("CENTER")
        fsi:SetFontObject("GameFontNormalSmall")
      end

  FrameLib:BuildFrame({
    type = "ScrollFrame",
    name = "ma_DCTeleScrollBar",
    parent = ma_dctele_window,
    inherits = "FauxScrollFrameTemplate",
    size = { width = 350, height = 400 },
    setpoint = { pos = "TOPLEFT", offX = 10, offY = -85 },
    texture = { color = {0,0,0,0} }
  })
  
  ma_DCTeleScrollBar:SetScript("OnVerticalScroll", function(self, offset)
      FauxScrollFrame_OnVerticalScroll(self, offset, 20, function() AzerothAdmin:UpdateDCTeleList() end)
  end)

  for i = 1, 20 do
    FrameLib:BuildButton({
      name = "ma_DCTeleEntry"..i,
      parent = ma_dctele_window,
      size = { width = 350, height = 20 },
      setpoint = { pos = "TOPLEFT", relTo = (i==1 and "ma_DCTeleScrollBar" or "ma_DCTeleEntry"..(i-1)), relPos = (i==1 and "TOPLEFT" or "BOTTOMLEFT"), offY = (i==1 and 0 or 0) },
      text = "",
      texture = {
        color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn}
      },
      hidden = true
    })
    _G["ma_DCTeleEntry"..i]:SetScript("OnClick", function(self) 
        local id = self:GetID()
        local tele = AzerothAdmin.filteredTeleports[id]
        if tele then
            AzerothAdmin:ChatMsg(".tele name " .. tele.name)
        end
    end)
  end
end

function AzerothAdmin:UpdateDCTeleList()
    if not AzerothAdmin.DCTeleports then return end
    
    local searchText = ""
    if ma_dctele_search and type(ma_dctele_search.GetText) == "function" then
        searchText = ma_dctele_search:GetText() or ""
    end
    searchText = string.lower(searchText)
    AzerothAdmin.filteredTeleports = {}
    
    for _, tele in ipairs(AzerothAdmin.DCTeleports) do
      if searchText == "" or string.find(string.lower(tele.name), searchText) then
        table.insert(AzerothAdmin.filteredTeleports, tele)
      end
    end

    -- Sort teleports by the selected sort mode
    local dir = AzerothAdmin.DCTeleSortDir or (AzerothAdmin.db and AzerothAdmin.db.account and AzerothAdmin.db.account.dctele and AzerothAdmin.db.account.dctele.sortDir) or "asc"
    if AzerothAdmin.DCTeleSortBy == "name" then
      table.sort(AzerothAdmin.filteredTeleports, function(a, b)
        local an = string.lower(a.name or "")
        local bn = string.lower(b.name or "")
        if an == bn then
          local aid = (a.id or a.ID or a.Id) or 0
          local bid = (b.id or b.ID or b.Id) or 0
          if dir == "asc" then return aid < bid else return aid > bid end
        end
        if dir == "asc" then return an < bn else return an > bn end
      end)
    else
      table.sort(AzerothAdmin.filteredTeleports, function(a, b)
        local aid = (a.id or a.ID or a.Id) or 0
        local bid = (b.id or b.ID or b.Id) or 0
        if dir == "asc" then return aid < bid else return aid > bid end
      end)
    end

    -- Update header indicators
    if ma_dctele_col_name then
      local arrow = ""
      if AzerothAdmin.DCTeleSortBy == "name" then arrow = (AzerothAdmin.DCTeleSortDir == "asc" and " ▲" or " ▼") end
      ma_dctele_col_name:SetText("Name (Map)" .. arrow)
    end
    if ma_dctele_col_id then
      local arrow = ""
      if AzerothAdmin.DCTeleSortBy == "id" then arrow = (AzerothAdmin.DCTeleSortDir == "asc" and " ▲" or " ▼") end
      ma_dctele_col_id:SetText("ID" .. arrow)
    end
    
    local numItems = #AzerothAdmin.filteredTeleports
    FauxScrollFrame_Update(ma_DCTeleScrollBar, numItems, 20, 20)
    
    local offset = FauxScrollFrame_GetOffset(ma_DCTeleScrollBar)
    for i = 1, 20 do
        local index = offset + i
        local button = _G["ma_DCTeleEntry"..i]
        if index <= numItems then
            local tele = AzerothAdmin.filteredTeleports[index]
            local tid = tele.id or tele.ID or tele.Id or 0
            button:SetText(string.format("%s (Map: %s)  [%d]", tele.name or "", tostring(tele.map or ""), tid))
            button:SetID(index)
            button:Show()
        else
            button:Hide()
        end
    end
end

if MangAdmin and MangAdmin ~= AzerothAdmin then
    MangAdmin.CreateDCTeleSection = AzerothAdmin.CreateDCTeleSection
end
