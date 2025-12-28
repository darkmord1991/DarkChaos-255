function AzerothAdmin:CreateDCSection()
  FrameLib:BuildFrame({
    name = "ma_dcframe",
    group = "dc",
    parent = ma_midframe,
    texture = {
      color = {0, 0, 0, 0}
    },
    size = {
      width = 750,
      height = 254
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 0,
      offY = 0
    },
    inherits = nil
  })

  -- Right-side panels (split DC functions)
  FrameLib:BuildFrame({
    name = "ma_dc_gps_panel",
    group = "dc",
    parent = ma_dcframe,
    texture = { color = {0, 0, 0, 0.2} },
    size = { width = 270, height = 130 },
    setpoint = { pos = "TOPLEFT", offX = 170, offY = -10 },
    inherits = nil
  })
  FrameLib:BuildFontString({
    name = "ma_dc_gps_title",
    group = "dc",
    parent = ma_dc_gps_panel,
    text = "GPS Coordinates",
    setpoint = { pos = "TOPLEFT", offX = 8, offY = -6 }
  })

  FrameLib:BuildFrame({
    name = "ma_dc_waypoints_panel",
    group = "dc",
    parent = ma_dcframe,
    texture = { color = {0, 0, 0, 0.2} },
    size = { width = 270, height = 130 },
    setpoint = { pos = "TOPLEFT", offX = 460, offY = -10 },
    inherits = nil
  })
  FrameLib:BuildFontString({
    name = "ma_dc_waypoints_title",
    group = "dc",
    parent = ma_dc_waypoints_panel,
    text = "Waypoints",
    setpoint = { pos = "TOPLEFT", offX = 8, offY = -6 }
  })

  FrameLib:BuildButton({
    name = "ma_dc_waypoints_open_btn",
    group = "dc",
    parent = ma_dc_waypoints_panel,
    texture = {
      name = "ma_dc_waypoints_open_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = { orientation = "vertical", min = {0.1, 0.1, 0.1, 1}, max = {0.2, 0.2, 0.2, 1} }
    },
    size = { width = 240, height = 25 },
    setpoint = { pos = "TOPLEFT", offX = 15, offY = -35 },
    text = "Open Waypoints UI"
  })
  AzerothAdmin:PrepareScript(ma_dc_waypoints_open_btn, "Open Waypoints UI", function()
    AzerothAdmin:OpenDCWaypoints()
    -- Close the main GM addon window when opening the dedicated Waypoints window.
    FrameLib:HandleGroup("popup", function(frame) frame:Hide() end)
    FrameLib:HandleGroup("bg", function(frame) frame:Hide() end)
  end)

  FrameLib:BuildFrame({
    name = "ma_dc_protocol_panel",
    group = "dc",
    parent = ma_dcframe,
    texture = { color = {0, 0, 0, 0.2} },
    size = { width = 270, height = 99 },
    setpoint = { pos = "TOPLEFT", offX = 170, offY = -145 },
    inherits = nil
  })
  FrameLib:BuildFontString({
    name = "ma_dc_protocol_title",
    group = "dc",
    parent = ma_dc_protocol_panel,
    text = "Addon Protocol Testing",
    setpoint = { pos = "TOPLEFT", offX = 8, offY = -6 }
  })

  FrameLib:BuildFrame({
    name = "ma_dc_teleports_panel",
    group = "dc",
    parent = ma_dcframe,
    texture = { color = {0, 0, 0, 0.2} },
    size = { width = 270, height = 99 },
    setpoint = { pos = "TOPLEFT", offX = 460, offY = -145 },
    inherits = nil
  })
  FrameLib:BuildFontString({
    name = "ma_dc_teleports_title",
    group = "dc",
    parent = ma_dc_teleports_panel,
    text = "Teleports",
    setpoint = { pos = "TOPLEFT", offX = 8, offY = -6 }
  })

  FrameLib:BuildButton({
    name = "ma_dc_gomove_btn",
    group = "dc",
    parent = ma_dcframe,
    texture = {
      name = "ma_dc_gomove_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = {
        orientation = "vertical",
        min = {0.1, 0.1, 0.1, 1},
        max = {0.2, 0.2, 0.2, 1}
      }
    },
    size = {
      width = 150,
      height = 25
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 10,
      offY = -10
    },
    text = "GOMove UI"
  })
  AzerothAdmin:PrepareScript(ma_dc_gomove_btn, "Open GOMove UI", function() SlashCmdList.GOMOVE("") end)

  FrameLib:BuildButton({
    name = "ma_dc_itemupgrade_btn",
    group = "dc",
    parent = ma_dcframe,
    texture = {
      name = "ma_dc_itemupgrade_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = {
        orientation = "vertical",
        min = {0.1, 0.1, 0.1, 1},
        max = {0.2, 0.2, 0.2, 1}
      }
    },
    size = {
      width = 150,
      height = 25
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 10,
      offY = -40
    },
    text = "Item Upgrade UI"
  })
  AzerothAdmin:PrepareScript(ma_dc_itemupgrade_btn, "Open Item Upgrade UI (/dcu)", function() SlashCmdList.DCUPGRADE("") end)

  FrameLib:BuildButton({
    name = "ma_dc_mplus_btn",
    group = "dc",
    parent = ma_dcframe,
    texture = {
      name = "ma_dc_mplus_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = {
        orientation = "vertical",
        min = {0.1, 0.1, 0.1, 1},
        max = {0.2, 0.2, 0.2, 1}
      }
    },
    size = {
      width = 150,
      height = 25
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 10,
      offY = -70
    },
    text = "Mythic+ Info"
  })
  AzerothAdmin:PrepareScript(ma_dc_mplus_btn, "Show Mythic+ Info (.mplus info)", function() AzerothAdmin:ChatMsg(".mplus info") end)

  FrameLib:BuildButton({
    name = "ma_dc_duel_btn",
    group = "dc",
    parent = ma_dcframe,
    texture = {
      name = "ma_dc_duel_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = {
        orientation = "vertical",
        min = {0.1, 0.1, 0.1, 1},
        max = {0.2, 0.2, 0.2, 1}
      }
    },
    size = {
      width = 150,
      height = 25
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 10,
      offY = -100
    },
    text = "Duel Stats"
  })
  AzerothAdmin:PrepareScript(ma_dc_duel_btn, "Show Duel Stats (.duel stats)", function() AzerothAdmin:ChatMsg(".duel stats") end)

  FrameLib:BuildButton({
    name = "ma_dc_prestige_btn",
    group = "dc",
    parent = ma_dcframe,
    texture = {
      name = "ma_dc_prestige_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = {
        orientation = "vertical",
        min = {0.1, 0.1, 0.1, 1},
        max = {0.2, 0.2, 0.2, 1}
      }
    },
    size = {
      width = 150,
      height = 25
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 10,
      offY = -130
    },
    text = "Prestige Info"
  })
  AzerothAdmin:PrepareScript(ma_dc_prestige_btn, "Show Prestige Info (.prestige info)", function() AzerothAdmin:ChatMsg(".prestige info") end)

  FrameLib:BuildButton({
    name = "ma_dc_gps_log_btn",
    group = "dc",
    parent = ma_dc_gps_panel,
    texture = {
      name = "ma_dc_gps_log_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = {
        orientation = "vertical",
        min = {0.1, 0.1, 0.1, 1},
        max = {0.2, 0.2, 0.2, 1}
      }
    },
    size = {
      width = 150,
      height = 25
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 10,
      offY = -25
    },
    text = "GPS Log Point"
  })
  AzerothAdmin:PrepareScript(ma_dc_gps_log_btn, "Log current GPS coordinates", function() AzerothAdmin:GPS_OnClick() end)

  FrameLib:BuildButton({
    name = "ma_dc_gps_finish_btn",
    group = "dc",
    parent = ma_dc_gps_panel,
    texture = {
      name = "ma_dc_gps_finish_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = {
        orientation = "vertical",
        min = {0.1, 0.1, 0.1, 1},
        max = {0.2, 0.2, 0.2, 1}
      }
    },
    size = {
      width = 150,
      height = 25
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 10,
      offY = -55
    },
    text = "GPS Collection Done"
  })
  AzerothAdmin:PrepareScript(ma_dc_gps_finish_btn, "Finish GPS collection and print results", function() AzerothAdmin:GPS_OnFinish() end)

  FrameLib:BuildButton({
    name = "ma_dc_tele_list_btn",
    group = "dc",
    parent = ma_dc_teleports_panel,
    texture = {
      name = "ma_dc_tele_list_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = {
        orientation = "vertical",
        min = {0.1, 0.1, 0.1, 1},
        max = {0.2, 0.2, 0.2, 1}
      }
    },
    size = {
      width = 150,
      height = 25
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 10,
      offY = -25
    },
    text = "DC Teleports List"
  })
  AzerothAdmin:PrepareScript(ma_dc_tele_list_btn, "Open DC Teleports List", function() 
      ma_dctele_window:Show() 
      AzerothAdmin:UpdateDCTeleList()
  end)
  FrameLib:BuildButton({
    name = "ma_dc_handlers_btn",
    group = "dc",
    parent = ma_dc_protocol_panel,
    texture = {
      name = "ma_dc_handlers_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = {
        orientation = "vertical",
        min = {0.1, 0.1, 0.1, 1},
        max = {0.2, 0.2, 0.2, 1}
      }
    },
    size = {
      width = 150,
      height = 25
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 10,
      offY = -25
    },
    text = "DC Handlers"
  })
  AzerothAdmin:PrepareScript(ma_dc_handlers_btn, "Open DC Handler Browser", function() AzerothAdmin:OpenDCHandlers() end)
  FrameLib:BuildButton({
    name = "ma_dc_gps_toolbar_btn",
    group = "dc",
    parent = ma_dc_gps_panel,
    texture = {
      name = "ma_dc_gps_toolbar_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = {
        orientation = "vertical",
        min = {0.1, 0.1, 0.1, 1},
        max = {0.2, 0.2, 0.2, 1}
      }
    },
    size = {
      width = 150,
      height = 25
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 10,
      offY = -85
    },
    text = "Open GPS Toolbar"
  })
  AzerothAdmin:PrepareScript(ma_dc_gps_toolbar_btn, "Open standalone GPS toolbar", function() AzerothAdmin:CreateGPSFrame() end)

end

-- Updates the DC->Waypoints header with target entry/spawn and waypoint count.
function AzerothAdmin:UpdateWaypointInfo()
  local targetTextFrame = _G["ma_dcwaypoints_info"] or _G["ma_dc_waypoints_info"]
  if not targetTextFrame then
    return
  end

  if not UnitExists("target") then
    targetTextFrame:SetText("Entry: -\nSpawn: -\nWPs: -\nWander: -")
    return
  end

  -- 3.3.5 UnitGUID formats vary (often hex-only), so don't parse it client-side.
  -- Always ask the server for authoritative entry/spawn/path/count.
  targetTextFrame:SetText("Entry: ?\nSpawn: ?\nWPs: ?\nWander: ?")
  self._dcWpInfoPending = true
  -- Also fetch the selected spawn's wander distance (spawndist) via `.npc info`.
  -- This helps detect random wandering which can interfere with waypoint movement.
  self._dcWpSpawnDistPending = true
  self._dcWpSpawnDistPendingUntil = (GetTime and (GetTime() + 2)) or nil
  self._dcWpLastSpawnDist = nil
  self:ChatMsg(".wp info")
  self:ChatMsg(".npc info")
end

-- Opens a dedicated Waypoints UI window (selection + favorites + buttons).
function AzerothAdmin:OpenDCWaypoints()
  if ma_dcwaypoints_window then
    ma_dcwaypoints_window:Show()
    AzerothAdmin:UpdateWaypointInfo()
    return
  end

  local color = { bg = AzerothAdmin.db.account.style.color.backgrounds, btn = AzerothAdmin.db.account.style.color.buttons }
  local transparency = { bg = AzerothAdmin.db.account.style.transparency.backgrounds, btn = AzerothAdmin.db.account.style.transparency.buttons }

  local windowW, windowH = 260, 195
  local pad = 10
  local btnH = 18
  local rowH = 18
  local listRows = 6
  local listH = (rowH * listRows) + 2
  local contentW = windowW - (pad * 2)
  local colGap = 6
  local btnW = math.floor((contentW - colGap) / 2)
  local col2X = pad + btnW + colGap

  FrameLib:BuildFrame({
    name = "ma_dcwaypoints_window",
    group = "dcwaypoints",
    parent = UIParent,
    texture = { color = {color.bg.r, color.bg.g, color.bg.b, transparency.bg} },
    size = { width = windowW, height = windowH },
    setpoint = { pos = "LEFT", relTo = "UIParent", relPos = "LEFT", offX = 0, offY = 85 },
    draggable = true,
    hidden = true
  })

  ma_dcwaypoints_window:SetClampedToScreen(true)

  ma_dcwaypoints_window:SetScript("OnShow", function()
    AzerothAdmin:UpdateWaypointInfo()
  end)

  FrameLib:BuildFontString({ name = "ma_dcwaypoints_title", parent = ma_dcwaypoints_window, text = "DC Waypoints", setpoint = { pos = "TOP", offY = -10 } })
  FrameLib:BuildButton({ name = "ma_dcwaypoints_close", parent = ma_dcwaypoints_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = 20, height = 20 }, setpoint = { pos = "TOPRIGHT", offX = -8, offY = -8 }, text = "X" })
  AzerothAdmin:PrepareScript(ma_dcwaypoints_close, "Close", function() ma_dcwaypoints_window:Hide() end)

  FrameLib:BuildFontString({ name = "ma_dcwaypoints_info", parent = ma_dcwaypoints_window, text = "Entry: -\nSpawn: -\nWPs: -\nWander: -", setpoint = { pos = "TOPLEFT", offX = pad, offY = -30 } })

  FrameLib:BuildButton({ name = "ma_dcwaypoints_refresh", parent = ma_dcwaypoints_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = 60, height = btnH }, setpoint = { pos = "TOPRIGHT", offX = -35, offY = -32 }, text = "Refresh" })
  AzerothAdmin:PrepareScript(ma_dcwaypoints_refresh, "Refresh waypoint info", function() AzerothAdmin:UpdateWaypointInfo() end)

  -- Waypoint action buttons
  local function WpBtn(name, text, x, y, tooltip, fn)
    FrameLib:BuildButton({ name = name, parent = ma_dcwaypoints_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = btnW, height = btnH }, setpoint = { pos = "TOPLEFT", offX = x, offY = y }, text = text })
    AzerothAdmin:PrepareScript(_G[name], tooltip, fn)
  end

  -- Compact 2-column layout (GOMove-like)
  local baseY = -85
  WpBtn("ma_dcwp_start", Locale["ma_WayAdd"], pad, baseY, Locale["tt_WayStart"], function() WayStart() end)
  WpBtn("ma_dcwp_add", Locale["ma_WayEndAdd"], col2X, baseY, Locale["tt_WayEndAdd"], function() WayEndAdd() end)
  WpBtn("ma_dcwp_showon", Locale["ma_WayShow1"], pad, baseY - (btnH + 2), Locale["tt_WayShow1"], function() WayShowOn() end)
  WpBtn("ma_dcwp_showoff", Locale["ma_WayShow0"], col2X, baseY - (btnH + 2), Locale["tt_WayShow0"], function() WayShowOff() end)
  WpBtn("ma_dcwp_insert", Locale["ma_WayMAdd"], pad, baseY - ((btnH + 2) * 2), Locale["tt_WayMAdd"], function() WayModifyAdd() end)
  WpBtn("ma_dcwp_del", Locale["ma_WayMDel"], col2X, baseY - ((btnH + 2) * 2), Locale["tt_WayModifyDel"], function() WayModifyDel() end)
  WpBtn("ma_dcwp_move", Locale["ma_WayMove"], pad, baseY - ((btnH + 2) * 3), Locale["tt_WayMove"], function() WayModifyMove() end)
  WpBtn("ma_dcwp_wipe", Locale["ma_WayWipe"], col2X, baseY - ((btnH + 2) * 3), Locale["tt_WayWipe"], function() WayWipe() end)

  -- Start creature movement along its waypoint path.
  local runY = baseY - ((btnH + 2) * 4)
  FrameLib:BuildButton({ name = "ma_dcwp_run", parent = ma_dcwaypoints_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = contentW, height = btnH }, setpoint = { pos = "TOPLEFT", offX = pad, offY = runY }, text = Locale["ma_WayRun"] or "Run Path" })
  AzerothAdmin:PrepareScript(ma_dcwp_run, Locale["tt_WayRun"] or "Start waypoint movement", function() WayRun() end)

  ma_dcwaypoints_window:Show()
end

-- Create a window to list DCAddonProtocol handlers and show details
function AzerothAdmin:OpenDCHandlers()
  if ma_dchandlers_window then
    ma_dchandlers_window:Show()
    AzerothAdmin:UpdateDCHandlersList()
    return
  end

  AzerothAdmin.DCHandlers = AzerothAdmin.DCHandlers or {}
  local color = { bg = AzerothAdmin.db.account.style.color.backgrounds, btn = AzerothAdmin.db.account.style.color.buttons }
  local transparency = { bg = AzerothAdmin.db.account.style.transparency.backgrounds, btn = AzerothAdmin.db.account.style.transparency.buttons }

  FrameLib:BuildFrame({
    name = "ma_dchandlers_window",
    group = "dchandlers",
    parent = UIParent,
    texture = { color = {color.bg.r, color.bg.g, color.bg.b, transparency.bg} },
    size = { width = 700, height = 500 },
    setpoint = { pos = "CENTER" },
    draggable = true,
    hidden = true
  })

  ma_dchandlers_window:SetScript("OnShow", function()
    AzerothAdmin:UpdateDCHandlersList()
  end)

  FrameLib:BuildFontString({ name = "ma_dchandlers_title", parent = ma_dchandlers_window, text = "DC Addon Handlers", setpoint = { pos = "TOP", offY = -10 } })

  FrameLib:BuildButton({ name = "ma_dchandlers_close", parent = ma_dchandlers_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { 20, 20 }, setpoint = { pos = "TOPRIGHT", offX = -5, offY = -5 }, text = "X" })
  AzerothAdmin:PrepareScript(ma_dchandlers_close, "Close", function() ma_dchandlers_window:Hide() end)

  FrameLib:BuildEditBox({ name = "ma_dchandlers_search", parent = ma_dchandlers_window, size = { width = 300, height = 20 }, setpoint = { pos = "TOPLEFT", offX = 10, offY = -30 }, text = "" })
  ma_dchandlers_search:SetScript("OnTextChanged", function(self) AzerothAdmin:UpdateDCHandlersList() end)

  FrameLib:BuildButton({ name = "ma_dchandlers_refresh", parent = ma_dchandlers_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { 80, 20 }, setpoint = { pos = "TOPLEFT", relTo = "ma_dchandlers_search", relPos = "TOPRIGHT", offX = 10, offY = 0 }, text = "Refresh" })
  AzerothAdmin:PrepareScript(ma_dchandlers_refresh, "Refresh", function() AzerothAdmin:UpdateDCHandlersList() end)

  -- Scroll frame for keys list (left side)
  FrameLib:BuildFrame({ type = "ScrollFrame", name = "ma_DCHandlersScrollBar", parent = ma_dchandlers_window, inherits = "FauxScrollFrameTemplate", size = { width = 300, height = 400 }, setpoint = { pos = "TOPLEFT", offX = 10, offY = -55 }, texture = { color = {0,0,0,0} } })
  ma_DCHandlersScrollBar:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, 20, function() AzerothAdmin:UpdateDCHandlersList() end) end)

  for i = 1, 20 do
    FrameLib:BuildButton({ name = "ma_DCHandlerEntry"..i, parent = ma_dchandlers_window, size = { width = 300, height = 20 }, setpoint = { pos = "TOPLEFT", relTo = (i==1 and "ma_DCHandlersScrollBar" or "ma_DCHandlerEntry"..(i-1)), relPos = (i==1 and "TOPLEFT" or "BOTTOMLEFT"), offY = 0 }, text = "", texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, hidden = true })
    _G["ma_DCHandlerEntry"..i]:SetScript("OnClick", function(self)
      local id = self:GetID()
      local key = AzerothAdmin.filteredDCHandlerKeys[id]
      if key then
        AzerothAdmin:SelectDCHandlerKey(key)
      end
    end)
  end

  -- Detail area (right side)
  FrameLib:BuildFrame({ name = "ma_DCHandlerDetailFrame", parent = ma_dchandlers_window, texture = { color = {color.bg.r, color.bg.g, color.bg.b, 0} }, size = { width = 360, height = 400 }, setpoint = { pos = "TOPLEFT", relTo = "ma_DCHandlersScrollBar", relPos = "TOPRIGHT", offX = 10, offY = 0 }, hidden = false })

  FrameLib:BuildFontString({ name = "ma_DCHandlerDetailTitle", parent = ma_DCHandlerDetailFrame, text = "Select a handler key to view details", setpoint = { pos = "TOPLEFT", offX = 8, offY = -6 } })

  FrameLib:BuildButton({ name = "ma_DCHandlerUnregisterKey", parent = ma_DCHandlerDetailFrame, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { 120, 20 }, setpoint = { pos = "TOPRIGHT", offX = -10, offY = -8 }, text = "UnregisterAll" })
  AzerothAdmin:PrepareScript(ma_DCHandlerUnregisterKey, "Unregister All", function() AzerothAdmin:UnregisterSelectedDCKey() end)
  FrameLib:BuildButton({ name = "ma_DCHandlerExport", parent = ma_DCHandlerDetailFrame, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { 80, 20 }, setpoint = { pos = "TOPRIGHT", relTo = "ma_DCHandlerUnregisterKey", relPos = "TOPLEFT", offX = -8, offY = 0 }, text = "Export" })
  AzerothAdmin:PrepareScript(ma_DCHandlerExport, "Export handler list", function() AzerothAdmin:ExportDCHandlers() end)

  -- Handler detail entries and per-function unregister
  for i = 1, 16 do
    FrameLib:BuildFontString({ name = "ma_DCHandlerDetailEntry"..i, parent = ma_DCHandlerDetailFrame, text = "", setpoint = { pos = "TOPLEFT", relTo = (i==1 and "ma_DCHandlerDetailTitle" or "ma_DCHandlerDetailEntry"..(i-1)), relPos = (i==1 and "BOTTOMLEFT" or "BOTTOMLEFT"), offX = 8, offY = (i==1 and -10 or -2) } })
    FrameLib:BuildButton({ name = "ma_DCHandlerDetailUnreg"..i, parent = ma_DCHandlerDetailFrame, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { 80, 18 }, setpoint = { pos = "TOPRIGHT", relTo = (i==1 and "ma_DCHandlerDetailTitle" or "ma_DCHandlerDetailEntry"..(i-1)), relPos = (i==1 and "BOTTOMRIGHT" or "BOTTOMRIGHT"), offY = (i==1 and -10 or -2) }, text = "Unregister" })
    _G["ma_DCHandlerDetailUnreg"..i]:SetScript("OnClick", function(self)
      local idx = self:GetID()
      AzerothAdmin:UnregisterSelectedDCHandlerFunction(idx)
    end)
  end

  ma_dchandlers_window:Show()
  AzerothAdmin:UpdateDCHandlersList()
end

function AzerothAdmin:SelectDCHandlerKey(key)
  local DC = rawget(_G, "DCAddonProtocol")
  if not DC then return end
  if not key then
    -- Clear detail entries
    for i = 1, 16 do
      local label = _G["ma_DCHandlerDetailEntry"..i]
      local btn = _G["ma_DCHandlerDetailUnreg"..i]
      label:SetText("")
      btn:Hide()
    end
    ma_DCHandlerDetailTitle:SetText("Select a handler key to view details")
    AzerothAdmin.selectedDCHandlerKey = nil
    return
  end
  AzerothAdmin.selectedDCHandlerKey = key
  ma_DCHandlerDetailTitle:SetText("Key: " .. tostring(key))
  local hlist = DC._handlers[key]
  if not hlist then hlist = {} end
  for i = 1, 16 do
    local label = _G["ma_DCHandlerDetailEntry"..i]
    local btn = _G["ma_DCHandlerDetailUnreg"..i]
    if hlist[i] then
      local fn = hlist[i]
      local desc = tostring(fn)
      local info = nil
      if type(fn) == 'function' and debug and debug.getinfo then
        local di = debug.getinfo(fn, 'Sln')
        info = string.format("%s:%d (%s)", di.short_src or "?", di.linedefined or 0, di.what or "?")
      end
      label:SetText(string.format("[%d] %s %s", i, desc, info and (" - "..info) or ""))
      btn:SetID(i)
      btn:Show()
    else
      label:SetText("")
      btn:Hide()
    end
  end
end

function AzerothAdmin:UpdateDCHandlersList()
  local DC = rawget(_G, "DCAddonProtocol")
  if not DC then
    AzerothAdmin:ChatMsg("DC addon protocol not loaded")
    return
  end
  local searchText = string.lower(ma_dchandlers_search:GetText() or "")
  local keys = {}
  for key, _ in pairs(DC._handlers) do
    if searchText == "" or string.find(string.lower(key), searchText) then
      table.insert(keys, key)
    end
  end
  table.sort(keys)
  AzerothAdmin.filteredDCHandlerKeys = keys
  local numItems = #keys
  FauxScrollFrame_Update(ma_DCHandlersScrollBar, numItems, 20, 20)
  local offset = FauxScrollFrame_GetOffset(ma_DCHandlersScrollBar)
  for i = 1, 20 do
    local index = offset + i
    local button = _G["ma_DCHandlerEntry"..i]
    if index <= numItems then
      local key = keys[index]
      local c = DC._handlers[key]
      local count = type(c) == 'table' and #c or 1
      button:SetText(key .. " (" .. tostring(count) .. ")")
      button:SetID(index)
      button:Show()
    else
      button:Hide()
    end
  end
end

function AzerothAdmin:UnregisterSelectedDCKey()
  local key = AzerothAdmin.selectedDCHandlerKey
  if not key then return end
  -- confirmation dialog
  local module, opcode, isJson = string.match(key, "^(.-)_(.-)(_json)?$")
  local action = (isJson and "JSON " or "") .. string.format("Unregister all handlers for %s:%s?", module or "?", tostring(opcode) or "?")
  StaticPopupDialogs["AZEROTHADMIN_DC_UNREG_KEY"] = StaticPopupDialogs["AZEROTHADMIN_DC_UNREG_KEY"] or {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(self, data)
      local module = data.module
      local opcode = data.opcode
      local isJson = data.isJson
      local DC = rawget(_G, "DCAddonProtocol")
      if DC then
        if isJson then DC:UnregisterJSONHandler(module, opcode) else DC:UnregisterHandler(module, opcode) end
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }
  StaticPopup_Show("AZEROTHADMIN_DC_UNREG_KEY", action, nil, { module = module, opcode = tonumber(opcode) or opcode, isJson = isJson })
  local DC = rawget(_G, "DCAddonProtocol")
  if not DC then return end
  local module, opcode, isJson = string.match(key, "^(.-)_(.-)(_json)?$")
  if isJson then
    DC:UnregisterJSONHandler(module, tonumber(opcode) or opcode)
  else
    DC:UnregisterHandler(module, tonumber(opcode) or opcode)
  end
  AzerothAdmin:UpdateDCHandlersList()
  AzerothAdmin:SelectDCHandlerKey(nil)
end

function AzerothAdmin:UnregisterSelectedDCHandlerFunction(idx)
  local key = AzerothAdmin.selectedDCHandlerKey
  if not key then return end
  local DC = rawget(_G, "DCAddonProtocol")
  if not DC then return end
  local h = DC._handlers[key]
  if not h then return end
  local fn = h[idx]
  if not fn then return end
  local module, opcode, isJson = string.match(key, "^(.-)_(.-)(_json)?$")
  -- Build text for confirmation
  local di = nil
  if type(fn) == 'function' and debug and debug.getinfo then di = debug.getinfo(fn, 'Sln') end
  local infoStr = di and string.format("%s:%d", di.short_src or "?", di.linedefined or 0) or tostring(fn)
  local action = string.format("Unregister handler #%d for %s?\n(%s)", idx, key, infoStr)
  StaticPopupDialogs["AZEROTHADMIN_DC_UNREG_FN"] = StaticPopupDialogs["AZEROTHADMIN_DC_UNREG_FN"] or {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(self, data)
      local module = data.module
      local opcode = data.opcode
      local isJson = data.isJson
      local fn = data.fn
      local DC = rawget(_G, "DCAddonProtocol")
      if DC then
        if isJson then DC:UnregisterJSONHandler(module, opcode, fn) else DC:UnregisterHandler(module, opcode, fn) end
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }
  StaticPopup_Show("AZEROTHADMIN_DC_UNREG_FN", action, nil, { module = module, opcode = tonumber(opcode) or opcode, isJson = isJson, fn = fn })
  AzerothAdmin:UpdateDCHandlersList()
  if AzerothAdmin.selectedDCHandlerKey then AzerothAdmin:SelectDCHandlerKey(AzerothAdmin.selectedDCHandlerKey) end
end

function AzerothAdmin:ExportDCHandlers()
  local DC = rawget(_G, "DCAddonProtocol")
  if not DC then
    AzerothAdmin:ChatMsg("DC addon protocol not available")
    return
  end
  local lines = {}
  for key, handlers in pairs(DC._handlers) do
    local count = type(handlers) == 'table' and #handlers or 1
    table.insert(lines, string.format("%s\tcount=%d", key, count))
    if type(handlers) == 'table' then
      for i, h in ipairs(handlers) do
        local fninfo = tostring(h)
        if type(h) == 'function' and debug and debug.getinfo then
          local di = debug.getinfo(h, 'Sln')
          if di then fninfo = string.format("%s:%d - %s", di.short_src or "?", di.linedefined or 0, tostring(h)) end
        end
        table.insert(lines, string.format("   [%d] %s", i, fninfo))
      end
    else
      local fninfo = tostring(handlers)
      if type(handlers) == 'function' and debug and debug.getinfo then
        local di = debug.getinfo(handlers, 'Sln')
        if di then fninfo = string.format("%s:%d - %s", di.short_src or "?", di.linedefined or 0, tostring(handlers)) end
      end
      table.insert(lines, string.format("   %s", fninfo))
    end
  end

  local text = table.concat(lines, "\n")

  -- Create a simple popup with an editbox to display/copy the exported handler list
  if ma_dchandlers_export_popup and ma_dchandlers_export_popup:IsVisible() then
    ma_dchandlers_export_popup:Hide()
  end
  ma_dchandlers_export_popup = ma_dchandlers_export_popup or CreateFrame("Frame", "ma_dchandlers_export_popup", UIParent)
  ma_dchandlers_export_popup:SetSize(600, 400)
  ma_dchandlers_export_popup:SetPoint("CENTER")
  ma_dchandlers_export_popup:SetFrameStrata("DIALOG")
  -- background
  if not ma_dchandlers_export_popup.bg then
    ma_dchandlers_export_popup.bg = ma_dchandlers_export_popup:CreateTexture(nil, "BACKGROUND")
    ma_dchandlers_export_popup.bg:SetAllPoints(true)
    ma_dchandlers_export_popup.bg:SetTexture(0, 0, 0, 0.8)
  end
  if not ma_dchandlers_export_popup.title then
    ma_dchandlers_export_popup.title = ma_dchandlers_export_popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ma_dchandlers_export_popup.title:SetPoint("TOP", 0, -6)
    ma_dchandlers_export_popup.title:SetText("DC Handlers Export")
  end
  if not ma_dchandlers_export_popup.editbox then
    local eb = CreateFrame("EditBox", nil, ma_dchandlers_export_popup, "InputScrollFrameTemplate")
    eb:SetFontObject(GameFontNormal)
    eb:SetMultiLine(true)
    eb:SetMaxLetters(32768)
    eb:SetSize(560, 320)
    eb:SetPoint("TOPLEFT", 20, -36)
    eb:SetScript("OnEscapePressed", function(self) ma_dchandlers_export_popup:Hide() end)
    ma_dchandlers_export_popup.editbox = eb
  end
  if not ma_dchandlers_export_popup.close then
    local b = CreateFrame("Button", nil, ma_dchandlers_export_popup, "UIPanelButtonTemplate")
    b:SetSize(80, 24)
    b:SetPoint("BOTTOMRIGHT", -10, 10)
    b:SetText("Close")
    b:SetScript("OnClick", function() ma_dchandlers_export_popup:Hide() end)
    ma_dchandlers_export_popup.close = b
  end
  ma_dchandlers_export_popup.editbox:SetText(text)
  if ma_dchandlers_export_popup.editbox.HighlightText then ma_dchandlers_export_popup.editbox:HighlightText() end
  ma_dchandlers_export_popup:Show()
end

local gps_points = {}
local gps_pending = false
local current_map = nil

function AzerothAdmin:CreateGPSFrame()
    if ma_gps_toolbar then
        ma_gps_toolbar:Show()
        return
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
        name = "ma_gps_toolbar",
        group = "gps",
        parent = UIParent,
        texture = {
            color = {color.bg.r, color.bg.g, color.bg.b, transparency.bg}
        },
        size = {
            width = 120,
            height = 80
        },
        setpoint = {
            pos = "CENTER"
        },
        draggable = true,
        hidden = false
    })

    FrameLib:BuildFontString({
        name = "ma_gps_title",
        group = "gps",
        parent = ma_gps_toolbar,
        text = "GPS Tool",
        setpoint = {
            pos = "TOP",
            offY = -5
        }
    })

    FrameLib:BuildButton({
        name = "ma_gps_close",
        group = "gps",
        parent = ma_gps_toolbar,
        texture = {
            color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn}
        },
        size = { width = 15, height = 15 },
        setpoint = { pos = "TOPRIGHT", offX = -2, offY = -2 },
        text = "X"
    })
    AzerothAdmin:PrepareScript(ma_gps_close, "Close", function() ma_gps_toolbar:Hide() end)

    FrameLib:BuildButton({
        name = "ma_gps_log_btn",
        group = "gps",
        parent = ma_gps_toolbar,
        texture = {
            color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn}
        },
        size = { width = 100, height = 20 },
        setpoint = { pos = "TOP", offY = -25 },
        text = "Log Point"
    })
    AzerothAdmin:PrepareScript(ma_gps_log_btn, "Log current GPS coordinates", function() AzerothAdmin:GPS_OnClick() end)

    FrameLib:BuildButton({
        name = "ma_gps_finish_btn",
        group = "gps",
        parent = ma_gps_toolbar,
        texture = {
            color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn}
        },
        size = { width = 100, height = 20 },
        setpoint = { pos = "TOP", offY = -50 },
        text = "Finish/Print"
    })
    AzerothAdmin:PrepareScript(ma_gps_finish_btn, "Finish GPS collection and print results", function() AzerothAdmin:GPS_OnFinish() end)
end

function AzerothAdmin:GPS_OnClick()
    gps_pending = true
    if not self:IsEventRegistered("CHAT_MSG_SYSTEM") then
        self:RegisterEvent("CHAT_MSG_SYSTEM", "GPS_OnSystemMessage")
    end
    SendChatMessage(".gps", "SAY")
end

function AzerothAdmin:GPS_OnFinish()
    self:Print("GPS Collection Result:")
    for i, p in ipairs(gps_points) do
        local line = string.format("Map: %s, X: %s, Y: %s, Z: %s, O: %s", p.map, p.x, p.y, p.z, p.o)
        self:Print(line)
    end
    gps_points = {}
    gps_pending = false
    current_map = nil
    if self:IsEventRegistered("CHAT_MSG_SYSTEM") then
        self:UnregisterEvent("CHAT_MSG_SYSTEM")
    end
end

function AzerothAdmin:GPS_OnSystemMessage(msg)
    if not gps_pending then return end
    
    local map = string.match(msg, "Map: (%d+)")
    if map then
        current_map = map
    end
    
    local x, y, z, o = string.match(msg, "X: ([%d%.%-]+)%s+Y: ([%d%.%-]+)%s+Z: ([%d%.%-]+)%s+Orientation: ([%d%.%-]+)")
    if x and y and z and o and current_map then
        table.insert(gps_points, {map=current_map, x=x, y=y, z=z, o=o})
        self:Print("Saved GPS: " .. current_map .. " " .. x .. " " .. y .. " " .. z .. " " .. o)
        gps_pending = false
        current_map = nil
        self:UnregisterEvent("CHAT_MSG_SYSTEM")
    end
end

if MangAdmin and MangAdmin ~= AzerothAdmin then
    MangAdmin.CreateDCSection = AzerothAdmin.CreateDCSection
end
