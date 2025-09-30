-- HinterlandAffixHUD.lua
-- Minimal addon that reads the custom affix worldstate value and shows a small text near the WG HUD
-- Worldstate ID must match the server value (WORLD_STATE_HL_AFFIX_TEXT)
local DEFAULT_AFFIX_WS = 0xDD1010 -- custom server worldstate; may not appear in UI list on stock client
local AFFIX_WS = DEFAULT_AFFIX_WS
local affixNames = {
  [0] = "None",
  [1] = "Haste",
  [2] = "Slow",
  [3] = "Reduced Healing",
  [4] = "Reduced Armor",
  [5] = "Boss Enrage",
}

local affixIcons = {
  [1] = "Interface/Icons/Spell_Holy_BorrowedTime",   -- Haste
  [2] = "Interface/Icons/Spell_Frost_Frostbolt",     -- Slow
  [3] = "Interface/Icons/Spell_Shadow_DevouringPlague", -- Reduced Healing
  [4] = "Interface/Icons/Ability_Warrior_Sunder",    -- Reduced Armor
  [5] = "Interface/Icons/Spell_Shadow_UnholyFrenzy", -- Boss Enrage
}

local f = CreateFrame("Frame", "HinterlandAffixHUDFrame", UIParent)
f:SetSize(240, 24)
f:SetPoint("TOP", UIParent, "TOP", 0, -170) -- near WG HUD clock by default
f.icon = f:CreateTexture(nil, "OVERLAY")
f.icon:SetSize(20, 20)
f.icon:SetPoint("LEFT", f, "LEFT", 0, 0)
f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.text:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
f.text:SetPoint("RIGHT", f, "RIGHT", 0, 0)
f.text:SetText("")

-- Optional: hide Blizzard's AlwaysUpFrame lines (the default WG-style HUD) if you only want our overlay.
local HIDE_DEFAULT_HUD = false

local function setAffixByName(name)
  if not name or name == "" then return end
  local line = "Affix: "..name
  if HinterlandAffixHUDDB and HinterlandAffixHUDDB.lastWeather then
    line = line .. "  —  Weather: " .. HinterlandAffixHUDDB.lastWeather
  end
  f.text:SetText(line)
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
  end
  if icon then
    f.icon:SetTexture(icon)
    f.icon:Show()
  else
    f.icon:Hide()
  end
  f:SetShown(label ~= "")

  if HIDE_DEFAULT_HUD then
    if WorldStateAlwaysUpFrame then
      WorldStateAlwaysUpFrame:Hide()
    end
  end
end

-- Fallback: parse server announcements in chat (global/zone) to learn the current affix
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
    end
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    update()
    return
  end
  if event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_SAY" then
    local msg = ...
    if type(msg) == "string" then
      -- Match messages like:
      -- "[Hinterland BG] Affix active: Slow"
      -- "[Hinterland BG] Battle restarted — current affix: Haste"
      local name = msg:match("%[Hinterland BG%]%s+Affix active:%s+([%w%s]+)")
      if not name then
        name = msg:match("%[Hinterland BG%]%s+Battle restarted[^:]*:%s+([%w%s]+)")
      end
      if name then
        setAffixByName(name)
        return
      end
      -- Weather line e.g. "weather: Rain 30%" or "Weather: Heavy Snow (60%)"
      local wname, wperc = msg:match("[Ww]eather:%s*([%w%s]+)%s*%(?(%d?%d?%d)%%%)?")
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

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:RegisterEvent("CHAT_MSG_YELL")
f:RegisterEvent("CHAT_MSG_SAY")
f:RegisterEvent("CHAT_MSG_RAID_WARNING")
f:RegisterEvent("CHAT_MSG_BATTLEGROUND")
f:RegisterEvent("CHAT_MSG_BATTLEGROUND_LEADER")
f:SetScript("OnEvent", onEvent)

-- initial update will happen on PLAYER_ENTERING_WORLD

-- Slash commands:
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
    update()
    print("HinterlandAffixHUD: hiding default HUD")
    return
  elseif msg == "hide off" or msg == "hide 0" then
    HIDE_DEFAULT_HUD = false
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.hideDefault = false
    if WorldStateAlwaysUpFrame then WorldStateAlwaysUpFrame:Show() end
    update()
    print("HinterlandAffixHUD: showing default HUD")
    return
  elseif msg == "dump" then
    local n = GetNumWorldStateUI() or 0
    print("HinterlandAffixHUD: worldstates:")
    for i=1,n do
      local txt, val, a, b, c, id = GetWorldStateUIInfo(i)
      print(i, string.format("0x%X", id or 0), txt or "", val or 0)
    end
    return
  end
  print("HinterlandAffixHUD commands:")
  print("/hlaffix id <number|0xHEX> - set worldstate id (default 0xDD1010)")
  print("/hlaffix hide on|off - hide Blizzard WG HUD")
  print("/hlaffix dump - list current worldstates")
end
