-------------------------------------------------------------------------------------------------------------
--
-- AzerothAdmin Version 3.x
--
-------------------------------------------------------------------------------------------------------------

function AzerothAdmin:CreateDCTeleSection()
  -- Initialize storage for dynamic teleports
  AzerothAdmin.DCTeleports = AzerothAdmin.DCTeleports or {}

  -- Register Protocol Handler for Teleport List (TELE module, opcode 0x10)
  if DC and DC.RegisterHandler then
      DC:RegisterHandler("TELE", 0x10, function(data)
          if data and data.list then
              AzerothAdmin.DCTeleports = data.list
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
  ma_dctele_search:SetAutoFocus(false)

  FrameLib:BuildFrame({
    type = "ScrollFrame",
    name = "ma_DCTeleScrollBar",
    parent = ma_dctele_window,
    inherits = "FauxScrollFrameTemplate",
    size = { width = 350, height = 400 },
    setpoint = { pos = "TOPLEFT", offX = 10, offY = -65 },
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
    
    local searchText = string.lower(ma_dctele_search:GetText())
    AzerothAdmin.filteredTeleports = {}
    
    for _, tele in ipairs(AzerothAdmin.DCTeleports) do
        if searchText == "" or string.find(string.lower(tele.name), searchText) then
            table.insert(AzerothAdmin.filteredTeleports, tele)
        end
    end
    
    local numItems = #AzerothAdmin.filteredTeleports
    FauxScrollFrame_Update(ma_DCTeleScrollBar, numItems, 20, 20)
    
    local offset = FauxScrollFrame_GetOffset(ma_DCTeleScrollBar)
    for i = 1, 20 do
        local index = offset + i
        local button = _G["ma_DCTeleEntry"..i]
        if index <= numItems then
            local tele = AzerothAdmin.filteredTeleports[index]
            button:SetText(tele.name .. " (Map: " .. tele.map .. ")")
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
