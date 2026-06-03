local function LocaleText(key, fallback)
  if type(Locale) == "table" then
    local value = rawget(Locale, key)
    if value ~= nil then
      return value
    end
  end

  return fallback
end

local function PrintDCGMStatus(message)
  if DEFAULT_CHAT_FRAME and message then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFCC00DC-GM:|r " .. message)
  end
end

local function InvokeSlashCommand(commandName, args, missingText)
  local slashCommands = rawget(_G, "SlashCmdList")
  local handler = slashCommands and slashCommands[commandName]

  if type(handler) ~= "function" then
    PrintDCGMStatus(missingText or ("Slash command " .. tostring(commandName) .. " is unavailable."))
    return false
  end

  local ok, err = pcall(handler, args or "")
  if ok then
    return true
  end

  PrintDCGMStatus((missingText or "Failed to open companion addon.") .. " " .. tostring(err))
  return false
end

local function OpenTransmutationUI()
  local showTransmutation = rawget(_G, "DarkChaos_Transmutation_Show")
  if type(showTransmutation) == "function" then
    showTransmutation()
    return true
  end

  local frame = rawget(_G, "DarkChaos_TransmutationFrame")
  if frame and type(frame.Show) == "function" then
    frame:Show()
    return true
  end

  PrintDCGMStatus("DC Transmutation UI is not loaded.")
  return false
end

local function OpenItemUpgradeUI(mode)
  local upgrade = rawget(_G, "DarkChaos_ItemUpgrade")
  local frame = rawget(_G, "DarkChaos_ItemUpgradeFrame")
  local resolvedMode = (mode == "HEIRLOOM") and "HEIRLOOM" or "STANDARD"

  if UnitAffectingCombat and UnitAffectingCombat("player") then
    PrintDCGMStatus("You cannot open Item Upgrade while in combat.")
    return false
  end

  if type(upgrade) == "table" then
    upgrade.uiMode = resolvedMode
  end

  if frame and type(frame.Show) == "function" then
    frame:Show()
    if frame.TitleText and type(frame.TitleText.SetText) == "function" then
      if resolvedMode == "HEIRLOOM" then
        frame.TitleText:SetText("Heirloom Upgrade")
      else
        frame.TitleText:SetText("Item Upgrade")
      end
    end
    return true
  end

  local args = (resolvedMode == "HEIRLOOM") and "heirloom" or ""
  return InvokeSlashCommand("DCUPGRADE", args, "DC Item Upgrade is not loaded.")
end

local function OpenGreatVaultUI()
  local mythicPlus = rawget(_G, "DCMythicPlusHUD")

  if type(mythicPlus) == "table" and type(mythicPlus.GreatVault) == "table"
    and type(mythicPlus.GreatVault.Toggle) == "function" then
    mythicPlus.GreatVault:Toggle()
    return true
  end

  return InvokeSlashCommand("DCM", "vault", "Great Vault UI is not loaded.")
end

local function OpenCollectionUI(tabName)
  local collection = rawget(_G, "DCCollection")

  if type(collection) == "table" then
    if tabName and type(collection.OpenTab) == "function" then
      collection:OpenTab(tabName)
      return true
    end

    if type(collection.Toggle) == "function" then
      collection:Toggle()
      return true
    end
  end

  return InvokeSlashCommand("DCCOLLECTION", tabName or "", "DC Collection is not loaded.")
end

local function OpenLeaderboardsUI(category)
  local leaderboards = rawget(_G, "LB")

  if type(leaderboards) == "table" then
    if category and type(leaderboards.Show) == "function"
      and type(leaderboards.SelectCategory) == "function" then
      leaderboards:Show()
      leaderboards:SelectCategory(category)
      return true
    end

    if type(leaderboards.Toggle) == "function" then
      leaderboards:Toggle()
      return true
    end
  end

  return InvokeSlashCommand("DCLEADERBOARDS", category or "", "DC Leaderboards is not loaded.")
end

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

  local function BuildDCPanelButton(name, parent, offsetY, text, tooltip, callback)
    FrameLib:BuildButton({
      name = name,
      group = "dc",
      parent = parent,
      texture = {
        name = name .. "_texture",
        color = {0.2, 0.2, 0.2, 1},
        gradient = {
          orientation = "vertical",
          min = {0.1, 0.1, 0.1, 1},
          max = {0.2, 0.2, 0.2, 1}
        }
      },
      size = {
        width = 240,
        height = 22
      },
      setpoint = {
        pos = "TOPLEFT",
        offX = 15,
        offY = offsetY
      },
      text = text
    })

    AzerothAdmin:PrepareScript(_G[name], tooltip, callback)
  end

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
  BuildDCPanelButton("ma_dc_collection_btn", ma_dc_waypoints_panel, -68, "Collection UI", "Open DC Collection UI (/dcc)", function()
    OpenCollectionUI()
  end)
  BuildDCPanelButton("ma_dc_darkmode_btn", ma_dc_waypoints_panel, -95, "Apply Dark Theme", "Apply a dark preset to the main DC-GM frames and reload the UI", function()
    if not (AzerothAdminCommands and AzerothAdminCommands.ApplyDarkModePreset) then
      PrintDCGMStatus("Dark mode preset is unavailable.")
      return
    end

    AzerothAdminCommands.ApplyDarkModePreset()
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

  local function BuildDCShortcutButton(name, offsetY, text, tooltip, callback)
    FrameLib:BuildButton({
      name = name,
      group = "dc",
      parent = ma_dcframe,
      texture = {
        name = name .. "_texture",
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
        offY = offsetY
      },
      text = text
    })

    AzerothAdmin:PrepareScript(_G[name], tooltip, callback)
  end

  BuildDCShortcutButton("ma_dc_gomove_btn", -10, "GOMove UI", "Open GOMove UI", function()
    InvokeSlashCommand("GOMOVE", "", "GOMove UI is not loaded.")
  end)

  BuildDCShortcutButton("ma_dc_itemupgrade_btn", -40, "Item Upgrade UI", "Open Item Upgrade UI (/dcu)", function()
    OpenItemUpgradeUI("STANDARD")
  end)

  BuildDCShortcutButton("ma_dc_heirloom_btn", -70, "Heirloom UI", "Open Heirloom Upgrade UI (/dcu heirloom)", function()
    OpenItemUpgradeUI("HEIRLOOM")
  end)

  BuildDCShortcutButton("ma_dc_transmute_btn", -100, "Transmute UI", "Open DC Transmutation UI", function()
    OpenTransmutationUI()
  end)

  BuildDCShortcutButton("ma_dc_groupfinder_btn", -130, "Group Finder", "Open Mythic+ Group Finder (/dcgf)", function()
    if not InvokeSlashCommand("DCGF", "", "Mythic+ Group Finder is not loaded.") then
      InvokeSlashCommand("DCM", "finder", "Mythic+ Group Finder is not loaded.")
    end
  end)

  BuildDCShortcutButton("ma_dc_mplus_btn", -160, "Mythic+ Info", "Show Mythic+ Info (.mplus info)", function()
    AzerothAdmin:ChatMsg(".mplus info")
  end)

  BuildDCShortcutButton("ma_dc_duel_btn", -190, "Duel Stats", "Show Duel Stats (.duel stats)", function()
    AzerothAdmin:ChatMsg(".duel stats")
  end)

  BuildDCShortcutButton("ma_dc_prestige_btn", -220, "Prestige Info", "Show Prestige Info (.prestige info)", function()
    AzerothAdmin:ChatMsg(".prestige info")
  end)

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
  BuildDCPanelButton("ma_dc_vault_btn", ma_dc_teleports_panel, -52, "Great Vault", "Open the Mythic+ Great Vault UI", function()
    OpenGreatVaultUI()
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
  BuildDCPanelButton("ma_dc_leaderboards_btn", ma_dc_protocol_panel, -52, "Leaderboards", "Open DC Leaderboards (/lb)", function()
    OpenLeaderboardsUI()
  end)
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
function AzerothAdmin:UpdateDCWaypointInfoDisplay(entry, spawn, count, wander)
  local targetTextFrame = _G["ma_dcwaypoints_info"] or _G["ma_dc_waypoints_info"]
  if not targetTextFrame then
    return
  end

  targetTextFrame:SetText(string.format(
    "Entry: %s\nSpawn: %s\nWPs: %s\nWander: %s",
    tostring(entry or "-"),
    tostring(spawn or "-"),
    tostring(count or "-"),
    tostring(wander or "n/a")
  ))
end

function AzerothAdmin:UpdateWaypointInfo()
  if not (_G["ma_dcwaypoints_info"] or _G["ma_dc_waypoints_info"]) then
    return
  end

  if not UnitExists("target") then
    self:UpdateDCWaypointInfoDisplay("-", "-", "-", "-")
    return
  end

  -- Ask the server for authoritative entry/spawn/path/count/wander distance.
  self:UpdateDCWaypointInfoDisplay("?", "?", "?", "?")
  self._dcWpInfoPending = true
  self._dcWpLastSpawnDist = nil
  self._dcWpLastEntry = nil
  self._dcWpLastSpawn = nil
  self._dcWpLastPath  = nil
  self._dcWpLastCount = nil
  self:ChatMsg(".wp info")
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

  local windowW, windowH = 260, 215
  local pad = 10
  local btnH = 18
  local rowH = 18
  local listRows = 6
  local listH = (rowH * listRows) + 2
  local contentW = windowW - (pad * 2)
  local colGap = 6
  local btnW = math.floor((contentW - colGap) / 2)
  local col2X = pad + btnW + colGap
  local dcWaypointsGroup = "dcwaypoints"

  FrameLib:BuildFrame({
    name = "ma_dcwaypoints_window",
    group = dcWaypointsGroup,
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

  FrameLib:BuildFontString({ name = "ma_dcwaypoints_title", group = dcWaypointsGroup, parent = ma_dcwaypoints_window, text = "DC Waypoints", setpoint = { pos = "TOP", offY = -10 } })
  FrameLib:BuildButton({ name = "ma_dcwaypoints_close", group = dcWaypointsGroup, parent = ma_dcwaypoints_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = 20, height = 20 }, setpoint = { pos = "TOPRIGHT", offX = -8, offY = -8 }, text = "X" })
  AzerothAdmin:PrepareScript(ma_dcwaypoints_close, "Close", function() ma_dcwaypoints_window:Hide() end)

  FrameLib:BuildFontString({ name = "ma_dcwaypoints_info", group = dcWaypointsGroup, parent = ma_dcwaypoints_window, text = "Entry: -\nSpawn: -\nWPs: -\nWander: -", setpoint = { pos = "TOPLEFT", offX = pad, offY = -30 } })

  FrameLib:BuildButton({ name = "ma_dcwaypoints_refresh", group = dcWaypointsGroup, parent = ma_dcwaypoints_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = 60, height = btnH }, setpoint = { pos = "TOPRIGHT", offX = -35, offY = -32 }, text = "Refresh" })
  AzerothAdmin:PrepareScript(ma_dcwaypoints_refresh, "Refresh waypoint info", function() AzerothAdmin:UpdateWaypointInfo() end)

  -- Waypoint action buttons
  local function WpBtn(name, text, x, y, tooltip, fn)
    FrameLib:BuildButton({ name = name, group = dcWaypointsGroup, parent = ma_dcwaypoints_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = btnW, height = btnH }, setpoint = { pos = "TOPLEFT", offX = x, offY = y }, text = text })
    AzerothAdmin:PrepareScript(_G[name], tooltip, fn)
  end

  -- Compact 2-column layout (GOMove-like)
  local baseY = -85
  WpBtn("ma_dcwp_start", "Add WP", pad, baseY, "Add waypoint at your position. Creates a new path if the creature has none; appends to the existing path otherwise. Use Wipe first to start over.", function() AzerothAdminCommands.WayStart() end)
  WpBtn("ma_dcwp_add", LocaleText("ma_WayEndAdd", "Add End"), col2X, baseY, LocaleText("tt_WayEndAdd", "Add a waypoint to the end of the existing stack."), function() AzerothAdminCommands.WayEndAdd() end)
  WpBtn("ma_dcwp_showon", LocaleText("ma_WayShow1", "Show On"), pad, baseY - (btnH + 2), LocaleText("tt_WayShow1", "Show waypoints for the selected creature."), function() AzerothAdminCommands.WayShowOn() end)
  WpBtn("ma_dcwp_showoff", LocaleText("ma_WayShow0", "Show Off"), col2X, baseY - (btnH + 2), LocaleText("tt_WayShow0", "Hide waypoints for the selected creature."), function() AzerothAdminCommands.WayShowOff() end)
  WpBtn("ma_dcwp_insert", LocaleText("ma_WayMAdd", "Insert"), pad, baseY - ((btnH + 2) * 2), LocaleText("tt_WayMAdd", "Insert a waypoint."), function() AzerothAdminCommands.WayModifyAdd() end)
  WpBtn("ma_dcwp_del", LocaleText("ma_WayMDel", "Delete"), col2X, baseY - ((btnH + 2) * 2), LocaleText("tt_WayModifyDel", "Delete the selected waypoint."), function() AzerothAdminCommands.WayModifyDel() end)
  WpBtn("ma_dcwp_move", LocaleText("ma_WayMove", "Move WP"), pad, baseY - ((btnH + 2) * 3), LocaleText("tt_WayMove", "Move the selected waypoint to your current position."), function() AzerothAdminCommands.WayModifyMove() end)
  WpBtn("ma_dcwp_wipe", LocaleText("ma_WayWipe", "Wipe"), col2X, baseY - ((btnH + 2) * 3), LocaleText("tt_WayWipe", "Delete all waypoints for the selected creature."), function() AzerothAdminCommands.WayWipe() end)

  -- Wander-distance controls (spawn random movement radius)
  WpBtn("ma_dcwp_wander30", LocaleText("ma_WayWander30", "Wander 30"), pad, baseY - ((btnH + 2) * 4), LocaleText("tt_WayWander30", "Set wander distance to 30"), function() AzerothAdminCommands.WayWander30() end)
  WpBtn("ma_dcwp_wanderoff", LocaleText("ma_WayWanderOff", "Wander Off"), col2X, baseY - ((btnH + 2) * 4), LocaleText("tt_WayWanderOff", "Disable wandering"), function() AzerothAdminCommands.WayWanderOff() end)

  -- Start creature movement along its waypoint path.
  local runY = baseY - ((btnH + 2) * 5)
  FrameLib:BuildButton({ name = "ma_dcwp_run", group = dcWaypointsGroup, parent = ma_dcwaypoints_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = contentW, height = btnH }, setpoint = { pos = "TOPLEFT", offX = pad, offY = runY }, text = LocaleText("ma_WayRun", "Run Path") })
  AzerothAdmin:PrepareScript(ma_dcwp_run, LocaleText("tt_WayRun", "Start waypoint movement"), function() AzerothAdminCommands.WayRun() end)

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
  local dcHandlersGroup = "dchandlers"
  local detailRowStartY = -36
  local detailRowHeight = 20
  local detailLabelWidth = 248

  FrameLib:BuildFrame({
    name = "ma_dchandlers_window",
    group = dcHandlersGroup,
    parent = UIParent,
    texture = { color = {color.bg.r, color.bg.g, color.bg.b, transparency.bg} },
    size = { width = 700, height = 500 },
    setpoint = { pos = "CENTER" },
    draggable = true,
    hidden = true
  })

  ma_dchandlers_window:SetClampedToScreen(true)

  ma_dchandlers_window:SetScript("OnShow", function()
    AzerothAdmin:UpdateDCHandlersList()
  end)

  FrameLib:BuildFontString({ name = "ma_dchandlers_title", group = dcHandlersGroup, parent = ma_dchandlers_window, text = "DC Addon Handlers", setpoint = { pos = "TOP", offY = -10 } })

  FrameLib:BuildButton({ name = "ma_dchandlers_close", group = dcHandlersGroup, parent = ma_dchandlers_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = 20, height = 20 }, setpoint = { pos = "TOPRIGHT", offX = -5, offY = -5 }, text = "X" })
  AzerothAdmin:PrepareScript(ma_dchandlers_close, "Close", function() ma_dchandlers_window:Hide() end)

  FrameLib:BuildEditBox({ name = "ma_dchandlers_search", group = dcHandlersGroup, parent = ma_dchandlers_window, size = { width = 300, height = 20 }, setpoint = { pos = "TOPLEFT", offX = 10, offY = -30 }, text = "" })
  ma_dchandlers_search:SetScript("OnTextChanged", function(self) AzerothAdmin:UpdateDCHandlersList() end)

  FrameLib:BuildButton({ name = "ma_dchandlers_refresh", group = dcHandlersGroup, parent = ma_dchandlers_window, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = 80, height = 20 }, setpoint = { pos = "TOPLEFT", relTo = "ma_dchandlers_search", relPos = "TOPRIGHT", offX = 10, offY = 0 }, text = "Refresh" })
  AzerothAdmin:PrepareScript(ma_dchandlers_refresh, "Refresh", function() AzerothAdmin:UpdateDCHandlersList() end)

  -- Scroll frame for keys list (left side)
  FrameLib:BuildFrame({ type = "ScrollFrame", name = "ma_DCHandlersScrollBar", group = dcHandlersGroup, parent = ma_dchandlers_window, inherits = "FauxScrollFrameTemplate", size = { width = 300, height = 400 }, setpoint = { pos = "TOPLEFT", offX = 10, offY = -55 }, texture = { color = {0,0,0,0} } })
  ma_DCHandlersScrollBar:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, 20, function() AzerothAdmin:UpdateDCHandlersList() end) end)

  for i = 1, 20 do
    FrameLib:BuildButton({ name = "ma_DCHandlerEntry"..i, group = dcHandlersGroup, parent = ma_dchandlers_window, size = { width = 300, height = 20 }, setpoint = { pos = "TOPLEFT", relTo = (i==1 and "ma_DCHandlersScrollBar" or "ma_DCHandlerEntry"..(i-1)), relPos = (i==1 and "TOPLEFT" or "BOTTOMLEFT"), offY = 0 }, text = "", texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, hidden = true })
    _G["ma_DCHandlerEntry"..i]:SetScript("OnClick", function(self)
      local id = self:GetID()
      local key = AzerothAdmin.filteredDCHandlerKeys[id]
      if key then
        AzerothAdmin:SelectDCHandlerKey(key)
      end
    end)
  end

  -- Detail area (right side)
  FrameLib:BuildFrame({ name = "ma_DCHandlerDetailFrame", group = dcHandlersGroup, parent = ma_dchandlers_window, texture = { color = {color.bg.r, color.bg.g, color.bg.b, 0} }, size = { width = 360, height = 400 }, setpoint = { pos = "TOPLEFT", relTo = "ma_DCHandlersScrollBar", relPos = "TOPRIGHT", offX = 10, offY = 0 }, hidden = false })

  FrameLib:BuildFontString({ name = "ma_DCHandlerDetailTitle", group = dcHandlersGroup, parent = ma_DCHandlerDetailFrame, text = "Select a handler key to view details", setpoint = { pos = "TOPLEFT", offX = 8, offY = -6 } })

  FrameLib:BuildButton({ name = "ma_DCHandlerUnregisterKey", group = dcHandlersGroup, parent = ma_DCHandlerDetailFrame, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = 120, height = 20 }, setpoint = { pos = "TOPRIGHT", offX = -10, offY = -8 }, text = "UnregisterAll" })
  AzerothAdmin:PrepareScript(ma_DCHandlerUnregisterKey, "Unregister All", function() AzerothAdmin:UnregisterSelectedDCKey() end)
  FrameLib:BuildButton({ name = "ma_DCHandlerExport", group = dcHandlersGroup, parent = ma_DCHandlerDetailFrame, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = 80, height = 20 }, setpoint = { pos = "TOPRIGHT", relTo = "ma_DCHandlerUnregisterKey", relPos = "TOPLEFT", offX = -8, offY = 0 }, text = "Export" })
  AzerothAdmin:PrepareScript(ma_DCHandlerExport, "Export handler list", function() AzerothAdmin:ExportDCHandlers() end)

  -- Handler detail entries and per-function unregister
  for i = 1, 16 do
    local rowOffY = detailRowStartY - ((i - 1) * detailRowHeight)
    FrameLib:BuildFontString({ name = "ma_DCHandlerDetailEntry"..i, group = dcHandlersGroup, parent = ma_DCHandlerDetailFrame, text = "", setpoint = { pos = "TOPLEFT", relTo = "ma_DCHandlerDetailFrame", relPos = "TOPLEFT", offX = 8, offY = rowOffY } })
    _G["ma_DCHandlerDetailEntry"..i]:SetWidth(detailLabelWidth)
    _G["ma_DCHandlerDetailEntry"..i]:SetJustifyH("LEFT")
    _G["ma_DCHandlerDetailEntry"..i]:SetJustifyV("TOP")
    FrameLib:BuildButton({ name = "ma_DCHandlerDetailUnreg"..i, group = dcHandlersGroup, parent = ma_DCHandlerDetailFrame, texture = { color = {color.btn.r, color.btn.g, color.btn.b, transparency.btn} }, size = { width = 80, height = 18 }, setpoint = { pos = "TOPRIGHT", relTo = "ma_DCHandlerDetailFrame", relPos = "TOPRIGHT", offX = -10, offY = rowOffY + 2 }, text = "Unregister" })
    _G["ma_DCHandlerDetailUnreg"..i]:SetScript("OnClick", function(self)
      local idx = self:GetID()
      AzerothAdmin:UnregisterSelectedDCHandlerFunction(idx)
    end)
    _G["ma_DCHandlerDetailUnreg"..i]:Hide()
  end

  AzerothAdmin:SelectDCHandlerKey(nil)

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
      AzerothAdmin:UpdateDCHandlersList()
      AzerothAdmin:SelectDCHandlerKey(nil)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }
  StaticPopup_Show("AZEROTHADMIN_DC_UNREG_KEY", action, nil, { module = module, opcode = tonumber(opcode) or opcode, isJson = isJson, key = key })
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
      AzerothAdmin:UpdateDCHandlersList()
      if DC and DC._handlers and DC._handlers[data.key] then
        AzerothAdmin:SelectDCHandlerKey(data.key)
      else
        AzerothAdmin:SelectDCHandlerKey(nil)
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }
  StaticPopup_Show("AZEROTHADMIN_DC_UNREG_FN", action, nil, { module = module, opcode = tonumber(opcode) or opcode, isJson = isJson, fn = fn, key = key })
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
    local sf = CreateFrame("ScrollFrame", "ma_dchandlers_export_scrollframe", ma_dchandlers_export_popup, "InputScrollFrameTemplate")
    sf:SetSize(560, 320)
    sf:SetPoint("TOPLEFT", 20, -36)

    local eb = _G[sf:GetName() .. "EditBox"]
    eb:SetFontObject(GameFontNormal)
    eb:SetMultiLine(true)
    eb:SetMaxLetters(32768)
    eb:SetWidth(sf:GetWidth())
    eb:SetScript("OnEscapePressed", function(self) ma_dchandlers_export_popup:Hide() end)

    ma_dchandlers_export_popup.scrollframe = sf
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
  if not self._gpsSystemMessageRegistered then
        self:RegisterEvent("CHAT_MSG_SYSTEM", "GPS_OnSystemMessage")
    self._gpsSystemMessageRegistered = true
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
    if self._gpsSystemMessageRegistered then
        self:UnregisterEvent("CHAT_MSG_SYSTEM")
      self._gpsSystemMessageRegistered = false
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
