-- HinterlandAffixHUD.lua
-- Minimal addon that reads the custom affix worldstate value and shows a small text near the WG HUD
-- Worldstate ID must match the server value (WORLD_STATE_HL_AFFIX_TEXT)
local AFFIX_WS = 0xDD1010
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

local function update()
  local count = GetNumWorldStateUI() or 0
  local label = ""
  local icon  = nil
  for i=1,count do
    local txt, val, _, _, _, id = GetWorldStateUIInfo(i)
    if id == AFFIX_WS then
      local name = affixNames[val or 0] or ("Affix "..tostring(val or 0))
      label = "Affix: "..name
      icon = affixIcons[val or 0]
      break
    end
  end
  f.text:SetText(label)
  if icon then
    f.icon:SetTexture(icon)
    f.icon:Show()
  else
    f.icon:Hide()
  end
  f:SetShown(label ~= "")
end

f:RegisterEvent("WORLD_STATE_UI_TIMER_UPDATE")
f:RegisterEvent("UPDATE_WORLD_STATES")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", update)

-- initial
C_Timer.After(1.0, update)
