local f = CreateFrame("Frame", "HinterlandAffixHUD", UIParent)
f:SetSize(200, 50)
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetClampedToScreen(true)
local function SavePosition()
  local point, rel, relPoint, x, y = f:GetPoint()
  HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
  HinterlandAffixHUDDB.pos = { point = point, rel = rel and rel:GetName() or "UIParent", relPoint = relPoint, x = x, y = y }
end
f:SetScript("OnDragStart", function(self)
  if not (HinterlandAffixHUDDB and HinterlandAffixHUDDB.locked) then self:StartMoving() end
end)
f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing(); SavePosition()
end)

f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
f.text:SetPoint("CENTER")

f.icon = f:CreateTexture(nil, "OVERLAY")
f.icon:SetSize(32, 32)
f.icon:SetPoint("RIGHT", f.text, "LEFT", -5, 0)

local AFFIX_WS = 0xDD1010
local HIDE_DEFAULT_HUD = false

local affixNames = {}
local affixIcons = {}

local function applyHideHUD()
  if not HIDE_DEFAULT_HUD then return end
  local function hideFrame(fr)
    if not fr then return end
    if fr.Hide then fr:Hide() end
    if fr.HookedByHLAffixHUD then return end
    fr.HookedByHLAffixHUD = true
    if fr:HasScript("OnShow") then
      fr:HookScript("OnShow", function(self) self:Hide() end)
    end
  end
  hideFrame(_G["WorldStateAlwaysUpFrame"])  -- common in 3.3.5
  hideFrame(_G["AlwaysUpFrame"])            -- just in case
end

local function AnchorUnderAlwaysUp()
  HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
  if not HinterlandAffixHUDDB.anchorUnder then return end
  local line = _G["WorldStateAlwaysUpFrame1"] or _G["AlwaysUpFrame1"]
  local base = _G["WorldStateAlwaysUpFrame"] or _G["AlwaysUpFrame"]
  f:ClearAllPoints()
  if line then
    f:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -4)
  elseif base then
    f:SetPoint("TOPLEFT", base, "BOTTOMLEFT", 0, -4)
  else
    f:SetPoint("CENTER")
  end
end

local function ApplySavedPositionAndScale()
  HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
  f:ClearAllPoints()
  local p = HinterlandAffixHUDDB.pos
  if p and p.point and p.rel and p.relPoint and p.x and p.y and _G[p.rel] then
    f:SetPoint(p.point, _G[p.rel], p.relPoint, p.x, p.y)
  else
    f:SetPoint("CENTER")
  end
  local s = tonumber(HinterlandAffixHUDDB.scale or 1)
  if s and s > 0 then f:SetScale(s) end
end

local function setAffixByName(name)
  if not name or name == "" then return end
  local line = "Affix: "..name
  if HinterlandAffixHUDDB and HinterlandAffixHUDDB.lastWeather then
    line = line .. "  —  Weather: " .. HinterlandAffixHUDDB.lastWeather
  end
  f.text:SetText(line)
  -- persist last affix so we can show something even if worldstate is missing
  HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
  HinterlandAffixHUDDB.lastAffix = name
  for k,v in pairs(affixNames) do
    if v == name then
      local icon = affixIcons[k]
      if icon then f.icon:SetTexture(icon); f.icon:Show() else f.icon:Hide() end
      f:Show()
      return
    end
  end
  f.icon:Hide()
  f:Show()
end

local function update()
  local count = GetNumWorldStateUI() or 0
  local label = ""
  local icon  = nil
  for i=1,count do
    local txt, val, a, b, c, id = GetWorldStateUIInfo(i)
    if id == AFFIX_WS then
      local name = affixNames[val or 0] or ("Affix "..tostring(val or 0))
      label = "Affix: "..name
      icon = affixIcons[val or 0]
      break
    end
  end
  f.text:SetText(label)
  if label ~= "" and HinterlandAffixHUDDB and HinterlandAffixHUDDB.lastWeather then
    f.text:SetText(label .. "  —  Weather: " .. HinterlandAffixHUDDB.lastWeather)
  elseif label == "" and HinterlandAffixHUDDB and HinterlandAffixHUDDB.lastAffix then
    -- show last seen affix if no worldstate available
    local line = "Affix: " .. (HinterlandAffixHUDDB.lastAffix or "")
    if HinterlandAffixHUDDB.lastWeather then
      line = line .. "  —  Weather: " .. HinterlandAffixHUDDB.lastWeather
    end
    f.text:SetText(line)
  end
  if icon then
    f.icon:SetTexture(icon)
    f.icon:Show()
  else
    f.icon:Hide()
  end
  f:SetShown((label ~= "") or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.lastAffix))

  applyHideHUD()
  AnchorUnderAlwaysUp()
end

local function onEvent(self, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == "HinterlandAffixHUD" then
      HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
      if type(HinterlandAffixHUDDB.worldstateId) == "number" then
        AFFIX_WS = HinterlandAffixHUDDB.worldstateId
      end
      if type(HinterlandAffixHUDDB.hideDefault) == "boolean" then
        HIDE_DEFAULT_HUD = HinterlandAffixHUDDB.hideDefault
      end
      if HinterlandAffixHUDDB.anchorUnder == nil then HinterlandAffixHUDDB.anchorUnder = true end
      if HinterlandAffixHUDDB.anchorUnder then
        AnchorUnderAlwaysUp()
      else
        if ApplySavedPositionAndScale then ApplySavedPositionAndScale() end
      end
    end
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    update()
    return
  end
  if event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_SAY" or event == "CHAT_MSG_RAID_WARNING" or event == "CHAT_MSG_BATTLEGROUND" or event == "CHAT_MSG_BATTLEGROUND_LEADER" then
    local msg = ...
    if type(msg) == "string" then
      -- Broadly match affix lines from different prefixes
      local name = msg:match("[Aa]ffix%s*[Aa]ctive:%s*([%a%s]+)")
      if not name then name = msg:match("current%s+[Aa]ffix:%s*([%a%s]+)") end
      if not name then name = msg:match("[Aa]ffix:%s*([%a%s]+)") end
      if name then name = (name:gsub("^%s+", ""):gsub("%s+$", "")) end
      if name then
        setAffixByName(name)
        return
      end
      -- Weather line e.g. "Weather: Rain (60%)" or "weather: Snow 40%"
      local wname, wperc = msg:match("[Ww]eather:%s*([%a%s]+)%s*%(?(%d?%d?%d)%%%)?")
      if wname then
        local piece = wname
        if wperc and wperc ~= "" then piece = piece .. " " .. wperc .. "%" end
        HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
        HinterlandAffixHUDDB.lastWeather = piece
        update()
        return
      end
    end
  end
end

f:SetScript("OnEvent", onEvent)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:RegisterEvent("CHAT_MSG_YELL")
f:RegisterEvent("CHAT_MSG_SAY")
f:RegisterEvent("CHAT_MSG_RAID_WARNING")
f:RegisterEvent("CHAT_MSG_BATTLEGROUND")
f:RegisterEvent("CHAT_MSG_BATTLEGROUND_LEADER")
-- also listen to worldstate updates so the hide toggle can re-apply
f:RegisterEvent("UPDATE_WORLD_STATES")
f:RegisterEvent("WORLD_STATE_UI_TIMER_UPDATE")

-- slash command registration (needed for WotLK clients)
SLASH_HLAFFIX1 = "/hlaffix"

SlashCmdList["HLAFFIX"] = function(msg)
  msg = (msg or ""):lower()
  if msg:find("^id ") then
    local idStr = msg:match("^id%s+(.+)$")
    if idStr then
      local id
      if idStr:sub(1,2) == "0x" then
        id = tonumber(idStr)
      else
        id = tonumber(idStr)
      end
      if id then
        AFFIX_WS = id
        HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
        HinterlandAffixHUDDB.worldstateId = id
        print("HinterlandAffixHUD: worldstate id set to", id)
        update()
        return
      end
    end
    print("Usage: /hlaffix id <number|0xHEX>")
    return
  elseif msg == "hide on" or msg == "hide 1" then
    HIDE_DEFAULT_HUD = true
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.hideDefault = true
    applyHideHUD(); update()
    print("HinterlandAffixHUD: hiding default HUD")
    return
  elseif msg == "hide off" or msg == "hide 0" then
    HIDE_DEFAULT_HUD = false
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.hideDefault = false
    if WorldStateAlwaysUpFrame then WorldStateAlwaysUpFrame:Show() end
    if AlwaysUpFrame then AlwaysUpFrame:Show() end
    update()
    print("HinterlandAffixHUD: showing default HUD")
    return
  elseif msg:find("^anchor ") then
    local mode = msg:match("^anchor%s+(%w+)")
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    if mode == "under" then
      HinterlandAffixHUDDB.anchorUnder = true
      AnchorUnderAlwaysUp()
      print("HinterlandAffixHUD: anchored under WG HUD line 1")
    elseif mode == "free" then
      HinterlandAffixHUDDB.anchorUnder = false
      if ApplySavedPositionAndScale then ApplySavedPositionAndScale() end
      print("HinterlandAffixHUD: free positioning enabled (drag to move)")
    else
      print("Usage: /hlaffix anchor under|free")
    end
    return
  elseif msg == "dump" then
    local n = GetNumWorldStateUI() or 0
    print("HinterlandAffixHUD: worldstates:")
    print("count:", n)
    for i=1,n do
      local txt, val, a, b, c, id = GetWorldStateUIInfo(i)
      print(i, string.format("0x%X", id or 0), txt or "", val or 0)
    end
    return
  elseif msg:find("^test ") then
    local name = msg:match("^test%s+(.+)$")
    if name and name ~= "" then
      setAffixByName(name)
      print("HinterlandAffixHUD: test affix set to", name)
    else
      print("Usage: /hlaffix test <name>")
    end
    return
  end
  print("HinterlandAffixHUD commands:")
  print("/hlaffix id <number|0xHEX> - set worldstate id (default 0xDD1010)")
  print("/hlaffix hide on|off - hide Blizzard WG HUD")
  print("/hlaffix dump - list current worldstates")
  print("/hlaffix anchor under|free - anchor under WG HUD or use free drag position")
  print("/hlaffix scale <0.5..1.5> - set HUD scale")
  print("/hlaffix lock on|off - lock/unlock frame")
  print("/hlaffix resetpos - reset frame position")
end

-- minimal options panel
local function CreateOptionsPanel()
  if not InterfaceOptions_AddCategory then return end
  local panel = CreateFrame("Frame", "HLAffixHUDOptionsPanel", UIParent)
  panel.name = "Hinterland Affix HUD"
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Hinterland Affix HUD")

  local hide = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  hide:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  hide.Text:SetText("Hide Blizzard WG HUD")
  hide:SetScript("OnClick", function(self)
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.hideDefault = self:GetChecked() and true or false
    HIDE_DEFAULT_HUD = HinterlandAffixHUDDB.hideDefault
    update()
  end)

  local scale = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
  scale:SetPoint("TOPLEFT", hide, "BOTTOMLEFT", 0, -24)
  scale:SetMinMaxValues(0.5, 1.5)
  scale:SetValueStep(0.05)
  scale:SetObeyStepOnDrag(true)
  scale.Low:SetText("0.5")
  scale.High:SetText("1.5")
  scale.Text:SetText("Scale")
  scale:SetScript("OnValueChanged", function(self, val)
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.scale = tonumber(string.format("%.2f", val))
    f:SetScale(HinterlandAffixHUDDB.scale)
  end)

  local eb = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  eb:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", 0, -24)
  eb:SetAutoFocus(false)
  eb:SetWidth(200)
  eb:SetHeight(20)
  eb:SetScript("OnEnterPressed", function(self)
    local text = self:GetText() or ""
    local id = tonumber(text)
    if not id and text:match("^0x") then id = tonumber(text) end
    if id then
      AFFIX_WS = id
      HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
      HinterlandAffixHUDDB.worldstateId = id
      update()
    end
    self:ClearFocus()
  end)
  local ebLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ebLabel:SetPoint("BOTTOMLEFT", eb, "TOPLEFT", 0, 2)
  ebLabel:SetText("Worldstate ID (decimal or 0xHEX)")

  local lock = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  lock:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", 0, -24)
  lock.Text:SetText("Lock frame position")
  lock:SetScript("OnClick", function(self)
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.locked = self:GetChecked() and true or false
  end)

  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetPoint("TOPLEFT", lock, "BOTTOMLEFT", 0, -16)
  reset:SetSize(140, 22)
  reset:SetText("Reset Position")
  reset:SetScript("OnClick", function()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.pos = nil
    ApplySavedPositionAndScale()
  end)

  panel.refresh = function()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    hide:SetChecked(HinterlandAffixHUDDB.hideDefault or false)
    scale:SetValue(tonumber(HinterlandAffixHUDDB.scale or 1) or 1)
    eb:SetText(HinterlandAffixHUDDB.worldstateId and string.format("0x%X", HinterlandAffixHUDDB.worldstateId) or "0xDD1010")
    lock:SetChecked(HinterlandAffixHUDDB.locked or false)
  end

  InterfaceOptions_AddCategory(panel)
end

CreateOptionsPanel()