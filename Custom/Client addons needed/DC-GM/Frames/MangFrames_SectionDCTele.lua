-------------------------------------------------------------------------------------------------------------
--
-- AzerothAdmin Version 3.x
--
-------------------------------------------------------------------------------------------------------------

local DCProto = rawget(_G, "DCAddonProtocol")

local function GetTimeSeconds()
  if type(GetTime) == "function" then
    return GetTime()
  end
  if type(time) == "function" then
    return time()
  end
  return 0
end

local function InvalidateDCTeleCache()
  if not AzerothAdmin then
    return
  end
  AzerothAdmin._dcteleCache = nil
  AzerothAdmin._dcteleLastComputed = nil
end

local function EnsureDCTelePrecomputed(list)
  if type(list) ~= "table" then
    return
  end
  for i = 1, #list do
    local tele = list[i]
    if type(tele) == "table" then
      if tele._id == nil then
        tele._id = (tele.id or tele.ID or tele.Id) or 0
      end
      if tele._lcName == nil then
        tele._lcName = string.lower(tele.name or "")
      end
    end
  end
end

local function CopyArray(src)
  local dst = {}
  for i = 1, #src do
    dst[i] = src[i]
  end
  return dst
end

local function GetSortedTeleports(sortBy, sortDir)
  local list = AzerothAdmin.DCTeleports
  if type(list) ~= "table" then
    return {}
  end

  AzerothAdmin._dcteleCache = AzerothAdmin._dcteleCache or {}
  local cache = AzerothAdmin._dcteleCache
  local key = tostring(sortBy or "id") .. ":" .. tostring(sortDir or "asc")

  local existing = cache[key]
  if existing and existing._src == list then
    return existing
  end

  EnsureDCTelePrecomputed(list)
  local arr = CopyArray(list)
  local dir = sortDir or "asc"

  if sortBy == "name" then
    table.sort(arr, function(a, b)
      local an = (type(a) == "table" and a._lcName) or ""
      local bn = (type(b) == "table" and b._lcName) or ""
      if an == bn then
        local aid = (type(a) == "table" and a._id) or 0
        local bid = (type(b) == "table" and b._id) or 0
        if dir == "asc" then return aid < bid else return aid > bid end
      end
      if dir == "asc" then return an < bn else return an > bn end
    end)
  else
    table.sort(arr, function(a, b)
      local aid = (type(a) == "table" and a._id) or 0
      local bid = (type(b) == "table" and b._id) or 0
      if dir == "asc" then return aid < bid else return aid > bid end
    end)
  end

  arr._src = list
  cache[key] = arr
  return arr
end

local function ScheduleDCTeleRequest(window, payload, delaySeconds)
  if not window then
    return
  end
  window._dcteleReq = {
    t = 0,
    delay = delaySeconds or 0,
    payload = payload,
  }
  window:SetScript("OnUpdate", function(self, elapsed)
    -- throttle UI refresh during sync (keeps scrolling/mouse input responsive)
    if AzerothAdmin and AzerothAdmin._dcteleNeedUIRefresh then
      self._dcteleUiT = (self._dcteleUiT or 0) + (elapsed or 0)
      if self._dcteleUiT >= 0.15 then
        self._dcteleUiT = 0
        AzerothAdmin._dcteleNeedUIRefresh = false
        AzerothAdmin:UpdateDCTeleList(true)
      end
    end

    if not self._dcteleReq then
      -- no pending request; keep OnUpdate only if we still need UI refresh
      if not (AzerothAdmin and AzerothAdmin._dcteleNeedUIRefresh) then
        self:SetScript("OnUpdate", nil)
      end
      return
    end

    self._dcteleReq.t = (self._dcteleReq.t or 0) + (elapsed or 0)
    if self._dcteleReq.t < (self._dcteleReq.delay or 0) then
      return
    end

    local req = self._dcteleReq
    self._dcteleReq = nil

    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.Request then
      DC:Request("TELE", 0x01, req.payload or {})
    end

    if not (AzerothAdmin and AzerothAdmin._dcteleNeedUIRefresh) then
      self:SetScript("OnUpdate", nil)
    end
  end)
end

local function NormalizeTeleportList(data)
  if type(data) ~= "table" then
    return nil
  end

  local list = data.list
  if list == nil then
    list = data.teleports
  end

  if type(list) == "string" then
    if DCProto and type(DCProto.DecodeJSON) == "function" then
      local decoded = DCProto:DecodeJSON(list)
      if type(decoded) == "table" then
        return decoded
      end
    end
    return nil
  end

  if type(list) == "table" then
    return list
  end

  return nil
end

function AzerothAdmin:CreateDCTeleSection()
  -- Initialize storage for dynamic teleports
    AzerothAdmin.DCTeleports = AzerothAdmin.DCTeleports or {}
    -- Precompute lowercase names / ids for fast filtering and cached sorting.
    EnsureDCTelePrecomputed(AzerothAdmin.DCTeleports)

  -- Register Protocol Handler for Teleport List (TELE module, opcode 0x10)
  local DC = rawget(_G, "DCAddonProtocol")
  if DC and DC.RegisterHandler then
      DC:RegisterHandler("TELE", 0x10, function(data)
            local list = NormalizeTeleportList(data)
            if not list then
              return
            end

            -- Backward compatibility: old server sends the entire list as one payload
            -- (typically under key 'list' as a JSON-string). That decode can still be heavy,
            -- but we must NOT copy it entry-by-entry or trigger paging follow-ups.
            local hasPagingFields = (data.offset ~= nil) or (data.total ~= nil) or (data.limit ~= nil) or (data.done ~= nil) or (data.reset ~= nil)
            if not hasPagingFields then
              EnsureDCTelePrecomputed(list)
              AzerothAdmin.DCTeleports = list
              AzerothAdmin._dcteleSync = { offset = #list, limit = 0, total = #list, done = true }
              InvalidateDCTeleCache()
              AzerothAdmin._dcteleNeedUIRefresh = true
              return
            end

            local offset = tonumber(data.offset or 0) or 0
            local total = tonumber(data.total or 0) or 0
            local reset = (data.reset == true) or (offset == 0)
            local done = (data.done == true)

            -- Another legacy-ish case: server returned a full snapshot but also included no meaningful paging.
            -- If total is missing/zero and the chunk is large, treat it as complete.
            local declaredLimit = tonumber(data.limit or 0) or 0
            if total == 0 and declaredLimit == 0 and #list > 200 then
              EnsureDCTelePrecomputed(list)
              AzerothAdmin.DCTeleports = list
              AzerothAdmin._dcteleSync = { offset = #list, limit = 0, total = #list, done = true }
              InvalidateDCTeleCache()
              AzerothAdmin._dcteleNeedUIRefresh = true
              return
            end

            -- Start/continue incremental sync without replacing the full list with only a chunk.
            if reset then
              AzerothAdmin.DCTeleports = {}
              AzerothAdmin._dcteleSync = { offset = 0, limit = tonumber(data.limit or 0) or 20, total = total, done = false }
              InvalidateDCTeleCache()
            end

            AzerothAdmin._dcteleSync = AzerothAdmin._dcteleSync or { offset = 0, limit = 20, total = total, done = false }
            AzerothAdmin._dcteleSync.total = total

            EnsureDCTelePrecomputed(list)
            -- Fast append without per-item overhead if server returns the full list.
            if reset and offset == 0 and total > 0 and #list >= total then
              AzerothAdmin.DCTeleports = list
            else
              for i = 1, #list do
                table.insert(AzerothAdmin.DCTeleports, list[i])
              end
            end
            EnsureDCTelePrecomputed(AzerothAdmin.DCTeleports)
            InvalidateDCTeleCache()

            AzerothAdmin._dcteleSync.offset = offset + #list
            AzerothAdmin._dcteleSync.done = done

            -- Throttle expensive UI refresh; schedule via OnUpdate.
            AzerothAdmin._dcteleNeedUIRefresh = true

            -- Request next page if needed and window is visible.
            if (not done) and ma_dctele_window and ma_dctele_window:IsShown() then
              local nextPayload = { offset = AzerothAdmin._dcteleSync.offset, limit = AzerothAdmin._dcteleSync.limit or 20, reset = false }
              ScheduleDCTeleRequest(ma_dctele_window, nextPayload, 0.05)
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
      -- Render immediately using cached/local data for smooth UX.
      AzerothAdmin:UpdateDCTeleList(true)

      -- Throttle requests so repeated opens don't re-sync constantly.
      local now = GetTimeSeconds()
      AzerothAdmin._dcteleLastRequest = AzerothAdmin._dcteleLastRequest or 0
      if (now - AzerothAdmin._dcteleLastRequest) < 30 then
        return
      end

      AzerothAdmin._dcteleLastRequest = now
      AzerothAdmin._dcteleSync = { offset = 0, limit = 20, total = nil, done = false }

      -- Kick off paged sync shortly after opening (lets the frame render first).
        ScheduleDCTeleRequest(ma_dctele_window, { offset = 0, limit = 20, reset = true }, 0.10)
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
  local _searchBox = rawget(_G, "ma_dctele_search")
  if _searchBox and _searchBox.SetScript then
    _searchBox:SetScript("OnTextChanged", function(self) AzerothAdmin:UpdateDCTeleList() end)
  end

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

  local _scrollBar = rawget(_G, "ma_DCTeleScrollBar")
  if _scrollBar and _scrollBar.SetScript then
    _scrollBar:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 20, function() AzerothAdmin:UpdateDCTeleList(false) end)
    end)
  end

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

function AzerothAdmin:UpdateDCTeleList(recompute)
    if not AzerothAdmin.DCTeleports then return end

    -- UI might not be created yet depending on load order.
    local scrollBar = rawget(_G, "ma_DCTeleScrollBar") or ma_DCTeleScrollBar
    if not scrollBar then
      return
    end
    
    local searchText = ""
    local searchBox = rawget(_G, "ma_dctele_search") or ma_dctele_search
    if searchBox and type(searchBox.GetText) == "function" then
      searchText = searchBox:GetText() or ""
    end
    searchText = string.lower(searchText)

    -- Recompute expensive filter/sort only when needed (open, search change, sort change, list change).
    if recompute == nil then recompute = true end
    local sortBy = AzerothAdmin.DCTeleSortBy or (AzerothAdmin.db and AzerothAdmin.db.account and AzerothAdmin.db.account.dctele and AzerothAdmin.db.account.dctele.sortBy) or "id"
    local sortDir = AzerothAdmin.DCTeleSortDir or (AzerothAdmin.db and AzerothAdmin.db.account and AzerothAdmin.db.account.dctele and AzerothAdmin.db.account.dctele.sortDir) or "asc"
    local last = AzerothAdmin._dcteleLastComputed

    if recompute or (not last) or last.list ~= AzerothAdmin.DCTeleports or last.search ~= searchText or last.sortBy ~= sortBy or last.sortDir ~= sortDir then
      EnsureDCTelePrecomputed(AzerothAdmin.DCTeleports)
      local sorted = GetSortedTeleports(sortBy, sortDir)

      if searchText == "" then
        AzerothAdmin.filteredTeleports = sorted
      else
        local filtered = {}
        for i = 1, #sorted do
          local tele = sorted[i]
          local name = (type(tele) == "table" and tele._lcName) or ""
          if string.find(name, searchText, 1, true) then
            table.insert(filtered, tele)
          end
        end
        AzerothAdmin.filteredTeleports = filtered
      end

      AzerothAdmin._dcteleLastComputed = {
        list = AzerothAdmin.DCTeleports,
        search = searchText,
        sortBy = sortBy,
        sortDir = sortDir,
      }
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
    
    local numItems = (AzerothAdmin.filteredTeleports and #AzerothAdmin.filteredTeleports) or 0
    FauxScrollFrame_Update(scrollBar, numItems, 20, 20)
    
    local offset = FauxScrollFrame_GetOffset(scrollBar)
    for i = 1, 20 do
        local index = offset + i
        local button = _G["ma_DCTeleEntry"..i]
        if not button then
          return
        end
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
